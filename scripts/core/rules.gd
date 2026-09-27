class_name Rules
extends RefCounted
## Game rules shared by all commands: validation helpers, the effect handlers that
## tile and title actions map to, combat, wounds and the Enemy Phase.
## Holds the game data and the RNG, never the state (R19).

const WON := "won"
const LOST := "lost"

var data: GameData
var rng: RandomNumberGenerator
## Set whenever random or hidden information comes out (a roll, a flip, a surge,
## the Enemy Phase). The engine uses it to mark undo checkpoints.
var revealed: bool = false

## effect id -> {"check": Callable, "apply": Callable}.
## check(state, player, origin, action, params) -> String (error, or "" if ok)
## apply(state, player, origin, action, params, ev) -> void
## origin is the tile the action is printed on, or the player's tile for title abilities.
var effects: Dictionary = {}


func _init(game_data: GameData, random: RandomNumberGenerator) -> void:
	data = game_data
	rng = random
	_register("flip_tile_and_spawn_d4_enemies", _check_expedition, _do_expedition)
	_register("gain_resources", _check_gain_resources, _do_gain_resources)
	_register("gain_title", _check_gain_title, _do_gain_title)
	_register("activate_die_from_pool", _check_activate_die, _do_activate_die)
	_register("add_warriors_at_player", _check_add_warriors, _do_add_warriors_at_player)
	_register("add_warriors_at_tile", _check_add_warriors, _do_add_warriors_at_tile)
	_register("win_if_ready", _check_win, _do_win)
	_register("flip_tile", _check_flip_tile, _do_flip_tile)
	_register("allow_leave_this_turn", _check_discover_path, _do_discover_path)
	_register("remove_enemies", _check_remove_enemies, _do_remove_enemies)
	_register("upgrade_die", _check_upgrade_die, _do_upgrade_die)
	_register("move_one_enemy", _check_move_enemy, _do_move_enemy)
	_register("swap_adjacent_tiles", _check_swap_tiles, _do_swap_tiles)


func _register(effect: String, check: Callable, apply: Callable) -> void:
	effects[effect] = {"check": check, "apply": apply}


func roll(sides: int) -> int:
	return rng.randi_range(1, sides)


static func event(type: String, fields: Dictionary = {}) -> Dictionary:
	var e := fields.duplicate()
	e["type"] = type
	return e


# --- Player-facing checks ---------------------------------------------------

## Error if the player can't act right now, else "".
func check_can_act(state: GameState, player: int) -> String:
	if state.is_over():
		return "The game is over."
	if state.phase != GameState.Phase.DWARF:
		return "Players can only act in the Dwarf Phase."
	if player < 0 or player >= state.players.size():
		return "No such player."
	var p := state.players[player]
	if not p.on_board:
		return "%s is wounded and off the board." % p.colour
	if p.done:
		return "%s has already finished this round." % p.colour
	return ""


func assist_max(p: PlayerState) -> int:
	if p.has_title("workmaster"):
		return int(data.title_ability_by_effect("workmaster", "worker_assistance_max_dice")["value"])
	return data.limit("worker_assistance_max_dice")


## Value a die contributes to an action on a tile (Master Miner adds +3 at a Mine).
func die_value_at(p: PlayerState, die: Dictionary, tile: TileState) -> int:
	var v := int(die["value"])
	if tile != null and tile.revealed and p.has_title("master_miner"):
		var bonus := data.title_ability_by_effect("master_miner", "die_bonus_at_tile")
		if tile.id == bonus["tile"]:
			v += int(bonus["value"])
	return v


## Checks the dice chosen for an action meet its minimum (§5.1, §5.2).
func check_dice(p: PlayerState, die_ids: Array, min_value: int, single_die: bool, tile: TileState) -> String:
	if die_ids.is_empty():
		return "Select at least one die."
	var seen := {}
	var total := 0
	for id in die_ids:
		if seen.has(id):
			return "The same die was chosen twice."
		seen[id] = true
		var d := p.die_by_id(int(id))
		if d.is_empty():
			return "That die isn't in your active pool."
		if d["used"]:
			return "That die has already been spent this round."
		total += die_value_at(p, d, tile)
	if single_die and die_ids.size() != 1:
		return "This needs a single die."
	if die_ids.size() > assist_max(p):
		return "You can combine at most %d dice." % assist_max(p)
	if total < min_value:
		return "Dice total %d, needs %d+." % [total, min_value]
	return ""


func spend_dice(p: PlayerState, die_ids: Array) -> void:
	for id in die_ids:
		var d := p.die_by_id(int(id))
		if not d.is_empty():
			d["used"] = true


func pay(state: GameState, p: PlayerState, cost: int) -> void:
	p.resources -= cost
	state.supply += cost


func movement_allowance(p: PlayerState) -> int:
	var n := 0
	for part in movement_parts(p):
		n += int(part[1])
	return n


## Where a player's movement comes from, as [label, amount] pairs.
func movement_parts(p: PlayerState) -> Array:
	var parts := [["base", data.limit("base_movement")]]
	if p.started_on_hearth:
		parts.append(["Hearth", int(data.tile("hearth")["passives"][0]["value"])])
	if p.has_title("messenger"):
		parts.append(["Messenger", int(data.title_ability_by_effect("messenger", "movement_bonus")["value"])])
	return parts


## What an action really needs from this player, after their titles:
## {"min": int, "cost": int, "notes": Array of short explanations}.
## tile is where the action is used (null for title abilities). Commands validate
## against these numbers and the UI shows them, so the two can't disagree.
func action_terms(p: PlayerState, a: Dictionary, tile: TileState) -> Dictionary:
	var terms := {"min": int(a.get("min", 0)), "cost": int(a.get("cost", 0)), "notes": []}
	if p.has_title("master_smith"):
		var o := data.title_ability_by_effect("master_smith", "action_min_override")
		if o["action"] == a.get("id", ""):
			terms["min"] = int(o["value"])
			terms["notes"].append("Master Smith")
	if a.get("effect", "") == "flip_tile_and_spawn_d4_enemies":
		var camp := int(data.tile("encampment")["on_flip"]["value"])
		if p.has_title("messenger"):
			terms["cost"] = 0
			var n := int(data.title_ability_by_effect("messenger", "expedition_spawns_fixed")["value"])
			terms["notes"].append("Messenger: spawns %d (%d on an Encampment)" % [n, camp])
		else:
			terms["notes"].append("spawns d4 enemies (%d on an Encampment)" % camp)
	if tile != null and p.has_title("master_miner"):
		var bonus := data.title_ability_by_effect("master_miner", "die_bonus_at_tile")
		if tile.revealed and tile.id == bonus["tile"]:
			terms["notes"].append("Master Miner: +%d per die" % int(bonus["value"]))
	if a.get("single_die", false):
		terms["notes"].append("single die")
	return terms


## Empty Halls' Lost passive: can't leave unless blocked (R10) or the path was found (R11).
func is_lost(state: GameState, p: PlayerState) -> bool:
	var t := state.tile_at(p.pos)
	return t.revealed and t.id == "empty_halls" and not t.is_blocked() and not p.halls_freed


func is_destructible(t: TileState) -> bool:
	return t.revealed and bool(data.tile(t.id)["destructible"])


func is_spawn_point(t: TileState) -> bool:
	if not t.revealed or t.flipped:
		return false
	return bool(data.tile(t.id)["spawn_point"])


# --- Effect handlers ----------------------------------------------------------

func _check_expedition(state: GameState, p: PlayerState, origin: Vector2i, _a: Dictionary, _params: Dictionary) -> String:
	if state.tile_at(origin).revealed:
		return "That tile has already been explored."
	return ""


func _do_expedition(state: GameState, p: PlayerState, origin: Vector2i, _a: Dictionary, _params: Dictionary, ev: Array) -> void:
	var t := state.tile_at(origin)
	t.revealed = true
	revealed = true
	ev.append(event("tile_flipped", {"pos": origin, "tile": t.id}))
	var n: int
	var on_flip: Dictionary = data.tile(t.id).get("on_flip", {})
	if on_flip.get("effect", "") == "spawn_enemies_here_fixed":
		n = int(on_flip["value"])  # R8: overrides Messenger
	elif p.has_title("messenger"):
		n = int(data.title_ability_by_effect("messenger", "expedition_spawns_fixed")["value"])
	else:
		n = roll(4)
		ev.append(event("enemy_die_rolled", {"value": n, "reason": "expedition"}))
	spawn_enemies(state, origin, n, ev)


func _check_gain_resources(state: GameState, _p: PlayerState, _o: Vector2i, _a: Dictionary, _params: Dictionary) -> String:
	if state.supply <= 0:
		return "The resource supply is empty."
	return ""


func _do_gain_resources(state: GameState, p: PlayerState, _o: Vector2i, a: Dictionary, _params: Dictionary, ev: Array) -> void:
	var n := mini(int(a["value"]), state.supply)
	state.supply -= n
	p.resources += n
	ev.append(event("resources_gained", {"player": p.index, "amount": n}))


func _check_gain_title(state: GameState, p: PlayerState, _o: Vector2i, a: Dictionary, params: Dictionary) -> String:
	var title_id: String = a["title"]
	if p.has_title(title_id):
		return "You already hold that title."
	var holder := state.title_holder(title_id)
	if holder >= 0 and not params.get("holder_agreed", false):
		return "%s holds that title and must agree to hand it over." % state.players[holder].colour
	var replace: String = params.get("replace_title", "")
	if replace != "" and not p.has_title(replace):
		return "You don't hold the title you chose to return."
	return ""


func _do_gain_title(state: GameState, p: PlayerState, _o: Vector2i, a: Dictionary, params: Dictionary, ev: Array) -> void:
	give_title(state, p, a["title"], params.get("replace_title", ""), ev)


## Gives a title to a player, taking it from its holder and returning one of the
## player's own titles if they're at the limit (R15).
func give_title(state: GameState, p: PlayerState, title_id: String, replace: String, ev: Array) -> void:
	var holder := state.title_holder(title_id)
	if holder >= 0:
		remove_title(state.players[holder], title_id, ev)
	if p.titles.size() >= data.titles_per_player(state.num_players):
		remove_title(p, replace if replace != "" else p.titles[0], ev)
	p.titles.append(title_id)
	for ab in data.title(title_id)["abilities"]:
		if ab["effect"] == "add_die":
			p.add_pending(ab["die"], title_id)
	ev.append(event("title_gained", {"player": p.index, "title": title_id}))


func remove_title(p: PlayerState, title_id: String, ev: Array) -> void:
	p.titles.erase(title_id)
	p.dice = p.dice.filter(func(d): return d["title"] != title_id)
	p.pending = p.pending.filter(func(d): return d["title"] != title_id)
	ev.append(event("title_returned", {"player": p.index, "title": title_id}))


func _check_activate_die(_s: GameState, p: PlayerState, _o: Vector2i, a: Dictionary, _params: Dictionary) -> String:
	if int(p.reserve.get(a["die"], 0)) <= 0:
		return "No %s left in your reserve." % a["die"]
	return ""


func _do_activate_die(_s: GameState, p: PlayerState, _o: Vector2i, a: Dictionary, _params: Dictionary, ev: Array) -> void:
	# R20: usable from next round.
	p.reserve[a["die"]] -= 1
	p.add_pending(a["die"])
	ev.append(event("die_recruited", {"player": p.index, "die": a["die"]}))


func _check_add_warriors(state: GameState, _p: PlayerState, _o: Vector2i, a: Dictionary, _params: Dictionary) -> String:
	if state.warriors_on_board() >= data.limit("max_warrior_tokens"):
		return "No warrior tokens left."
	if a.has("tile") and state.find_tile(a["tile"]) == PlayerState.NO_TILE:
		return "There is no %s on the map." % a["tile"]
	return ""


func _do_add_warriors_at_player(state: GameState, p: PlayerState, _o: Vector2i, a: Dictionary, _params: Dictionary, ev: Array) -> void:
	place_warriors(state, p.pos, int(a["value"]), ev)


func _do_add_warriors_at_tile(state: GameState, _p: PlayerState, _o: Vector2i, a: Dictionary, _params: Dictionary, ev: Array) -> void:
	place_warriors(state, state.find_tile(a["tile"]), int(a["value"]), ev)


func place_warriors(state: GameState, pos: Vector2i, n: int, ev: Array) -> void:
	n = mini(n, data.limit("max_warrior_tokens") - state.warriors_on_board())
	state.tile_at(pos).warriors += n
	ev.append(event("warriors_placed", {"pos": pos, "count": n}))
	resolve_board(state, ev)


func _check_win(state: GameState, _p: PlayerState, _o: Vector2i, _a: Dictionary, _params: Dictionary) -> String:
	if state.ruins_left() > 0:
		return "Explore every ruin first (%d left)." % state.ruins_left()
	if state.open_tunnels() > 0:
		return "Collapse every tunnel first (%d open)." % state.open_tunnels()
	return ""


func _do_win(state: GameState, _p: PlayerState, origin: Vector2i, _a: Dictionary, _params: Dictionary, ev: Array) -> void:
	state.tile_at(origin).flipped = true
	end_game(state, WON, "The City Gate is secured.", ev)


func _check_flip_tile(_s: GameState, _p: PlayerState, _o: Vector2i, _a: Dictionary, _params: Dictionary) -> String:
	return ""


func _do_flip_tile(state: GameState, _p: PlayerState, origin: Vector2i, _a: Dictionary, _params: Dictionary, ev: Array) -> void:
	var t := state.tile_at(origin)
	t.flipped = true
	ev.append(event("tunnel_collapsed", {"pos": origin}))


func _check_discover_path(_s: GameState, p: PlayerState, origin: Vector2i, _a: Dictionary, _params: Dictionary) -> String:
	if p.pos != origin:
		return "You must be standing on the Empty Halls."
	if p.halls_freed:
		return "You've already found the path."
	return ""


func _do_discover_path(_s: GameState, p: PlayerState, _o: Vector2i, _a: Dictionary, _params: Dictionary, ev: Array) -> void:
	p.halls_freed = true  # R11
	ev.append(event("path_discovered", {"player": p.index}))


func _check_remove_enemies(state: GameState, _p: PlayerState, origin: Vector2i, a: Dictionary, params: Dictionary) -> String:
	if not params.has("target"):
		return "Choose a tile to attack."
	var target: Vector2i = params["target"]
	if not state.in_bounds(target):
		return "That tile is off the map."
	var ok: bool
	if a.get("range", "own_or_adjacent") == "adjacent":
		ok = GameState.is_adjacent(origin, target)
	else:
		ok = GameState.is_own_or_adjacent(origin, target)
	if not ok:
		return "That tile is out of range."
	if state.tile_at(target).enemies <= 0:
		return "There are no enemies there."
	return ""


func _do_remove_enemies(state: GameState, _p: PlayerState, _o: Vector2i, a: Dictionary, params: Dictionary, ev: Array) -> void:
	var target: Vector2i = params["target"]
	var t := state.tile_at(target)
	var n := mini(int(a.get("value", 1)), t.enemies)
	t.enemies -= n
	ev.append(event("enemies_removed", {"pos": target, "count": n}))


func _check_upgrade_die(_s: GameState, p: PlayerState, _o: Vector2i, a: Dictionary, params: Dictionary) -> String:
	if not params.has("die"):
		return "Choose a die to promote."
	var d := p.die_by_id(int(params["die"]))
	if d.is_empty():
		return "That die isn't in your active pool."
	if not a["upgrades"].has(d["type"]):
		return "A %s can't be promoted." % d["type"]
	var new_type: String = a["upgrades"][d["type"]]
	if int(p.reserve.get(new_type, 0)) <= 0:
		return "No %s left in your reserve." % new_type
	return ""


func _do_upgrade_die(_s: GameState, p: PlayerState, _o: Vector2i, a: Dictionary, params: Dictionary, ev: Array) -> void:
	var d := p.die_by_id(int(params["die"]))
	var old_type: String = d["type"]
	var new_type: String = a["upgrades"][old_type]
	p.remove_die(int(d["id"]))
	p.reserve[old_type] = int(p.reserve.get(old_type, 0)) + 1
	p.reserve[new_type] -= 1
	p.add_pending(new_type)  # R14: usable from next round
	ev.append(event("die_promoted", {"player": p.index, "from": old_type, "to": new_type}))


func _check_move_enemy(state: GameState, _p: PlayerState, _o: Vector2i, a: Dictionary, params: Dictionary) -> String:
	if not params.has("from") or not params.has("to"):
		return "Choose an enemy and where to move it."
	var from: Vector2i = params["from"]
	var to: Vector2i = params["to"]
	if not state.in_bounds(from) or not state.in_bounds(to):
		return "That tile is off the map."
	if state.tile_at(from).enemies <= 0:
		return "There is no enemy there."
	var dist := absi(from.x - to.x) + absi(from.y - to.y)
	if dist < 1 or dist > int(a["range_tiles"]):
		return "An enemy can be moved up to %d tiles." % int(a["range_tiles"])
	return ""


func _do_move_enemy(state: GameState, _p: PlayerState, _o: Vector2i, _a: Dictionary, params: Dictionary, ev: Array) -> void:
	var from: Vector2i = params["from"]
	var to: Vector2i = params["to"]
	state.tile_at(from).enemies -= 1
	state.tile_at(to).enemies += 1
	ev.append(event("enemy_moved", {"from": from, "to": to, "count": 1}))
	resolve_board(state, ev)


func _check_swap_tiles(state: GameState, _p: PlayerState, _o: Vector2i, _a: Dictionary, params: Dictionary) -> String:
	if not params.has("a") or not params.has("b"):
		return "Choose two adjacent tiles."
	var a: Vector2i = params["a"]
	var b: Vector2i = params["b"]
	if not state.in_bounds(a) or not state.in_bounds(b) or not GameState.is_adjacent(a, b):
		return "The two tiles must be next to each other."
	return ""


func _do_swap_tiles(state: GameState, _p: PlayerState, _o: Vector2i, _a: Dictionary, params: Dictionary, ev: Array) -> void:
	# Tokens and nobles stay put; only tile identity and side move.
	var ta := state.tile_at(params["a"])
	var tb := state.tile_at(params["b"])
	var swap := [ta.id, ta.revealed, ta.flipped]
	ta.id = tb.id; ta.revealed = tb.revealed; ta.flipped = tb.flipped
	tb.id = swap[0]; tb.revealed = swap[1]; tb.flipped = swap[2]
	ev.append(event("tiles_swapped", {"a": params["a"], "b": params["b"]}))


# --- Enemies, combat and wounds -------------------------------------------------

## Places n enemies at pos. If the token pool runs out, the rest aren't placed and
## an Enemy Surge happens instead (§5.11, R13). Returns true if a surge happened.
func spawn_enemies(state: GameState, pos: Vector2i, n: int, ev: Array) -> bool:
	var pool := data.limit("max_enemy_tokens") - state.enemies_on_board()
	var placed := mini(n, pool)
	if placed > 0:
		state.tile_at(pos).enemies += placed
		ev.append(event("enemies_spawned", {"pos": pos, "count": placed}))
	if placed < n:
		surge(state, ev)
		return true
	resolve_board(state, ev)
	return false


func surge(state: GameState, ev: Array) -> void:
	revealed = true
	var r := roll(4)
	ev.append(event("enemy_surge", {"value": r, "direction": data.enemy_direction(r)}))
	move_all_enemies(state, r, ev)
	resolve_board(state, ev)


## Every enemy moves one tile in the rolled direction, or the opposite way at an edge.
func move_all_enemies(state: GameState, r: int, ev: Array) -> void:
	state.last_enemy_roll = r
	var dir: Vector2i = {"north": Vector2i.UP, "east": Vector2i.RIGHT, "south": Vector2i.DOWN, "west": Vector2i.LEFT}[data.enemy_direction(r)]
	var counts: Array[int] = []
	counts.resize(state.tiles.size())
	counts.fill(0)
	for i in state.tiles.size():
		var e := state.tiles[i].enemies
		if e == 0:
			continue
		var from := state.pos_of(i)
		var to := from + dir
		if not state.in_bounds(to):
			to = from - dir
		counts[to.y * state.size + to.x] += e
		ev.append(event("enemy_moved", {"from": from, "to": to, "count": e}))
	for i in state.tiles.size():
		state.tiles[i].enemies = counts[i]
	# Tough's protection is against the enemies that were already there.
	for p in state.players:
		p.tough_tile = PlayerState.NO_TILE


## Automatic combat (§5.6) then wounds (§5.8). Call after anything that moves or adds tokens.
func resolve_board(state: GameState, ev: Array) -> void:
	for i in state.tiles.size():
		var t := state.tiles[i]
		var k := mini(t.enemies, t.warriors)
		if k > 0:
			t.enemies -= k
			t.warriors -= k
			ev.append(event("combat", {"pos": state.pos_of(i), "count": k}))
	for p in state.players:
		if state.is_over():
			return
		if not p.on_board:
			continue
		var t := state.tile_at(p.pos)
		if t.enemies <= 0:
			continue
		if t.revealed and t.id == "watchtower":
			continue  # Garrison works even though the enemy blocks the tile (R21).
		if p.has_title("master_of_the_guard") and p.tough_tile == p.pos and t.enemies <= p.tough_count:
			continue
		wound(state, p, ev)


func wound(state: GameState, p: PlayerState, ev: Array) -> void:
	var tough := p.has_title("master_of_the_guard")
	ev.append(event("noble_wounded", {"player": p.index, "pos": p.pos, "tough": tough}))
	if tough:
		# R7: marker still moves; the Noble stays and isn't wounded again by these enemies.
		p.tough_tile = p.pos
		p.tough_count = state.tile_at(p.pos).enemies
	else:
		p.on_board = false
		p.wounded = true
		p.skip_phases = 1
		p.done = true
		p.pos = PlayerState.NO_TILE
	advance_track(state, ev)


func advance_track(state: GameState, ev: Array) -> void:
	if state.is_over():
		return
	state.turn_index += 1
	ev.append(event("track_advanced", {"index": state.turn_index}))
	if state.turn_index >= data.track_last_index():
		end_game(state, LOST, "The turn marker reached the end of the track.", ev)


func end_game(state: GameState, result: String, reason: String, ev: Array) -> void:
	if state.is_over():
		return
	state.phase = GameState.Phase.OVER
	state.result = result
	state.end_reason = reason
	ev.append(event("game_over", {"result": result, "reason": reason}))


# --- Round flow ------------------------------------------------------------------

## Enemy Phase (§4.2), then the next round's Dwarf Phase starts.
func run_enemy_phase(state: GameState, ev: Array) -> void:
	revealed = true
	state.phase = GameState.Phase.ENEMY
	ev.append(event("enemy_phase_started", {"round": state.round}))

	# 1. Tunnels.
	for i in state.tiles.size():
		var t := state.tiles[i]
		if t.enemies < data.limit("enemies_to_create_tunnel") or not is_destructible(t):
			continue
		var pos := state.pos_of(i)
		if t.id == "hearth":
			end_game(state, LOST, "Enemies turned the Hearth into a tunnel.", ev)
			return
		if state.tunnel_count() >= data.limit("max_tunnels"):
			end_game(state, LOST, "Enemies needed a sixth tunnel.", ev)
			return
		ev.append(event("tunnel_created", {"pos": pos, "was": t.id}))
		t.id = "tunnel"  # R12: enemies stay
		t.flipped = false

	# 2. Move.
	var r := roll(4)
	ev.append(event("enemy_die_rolled", {"value": r, "reason": "movement", "direction": data.enemy_direction(r)}))
	move_all_enemies(state, r, ev)
	resolve_board(state, ev)
	if state.is_over():
		return

	# 3. Spawn (R3: every spawn point gets the full amount).
	var n := int(data.spawn_per_cell()[state.turn_index])
	var points: Array[Vector2i] = []
	for i in state.tiles.size():
		if is_spawn_point(state.tiles[i]):
			points.append(state.pos_of(i))
	for pos in points:
		if spawn_enemies(state, pos, n, ev) or state.is_over():
			break  # R13: the surge replaces the rest of the spawn
	if state.is_over():
		return

	# 4. Track.
	advance_track(state, ev)
	if state.is_over():
		return
	begin_round(state, ev)


## Revive and Roll (§4.1). If nobody can act, the Enemy Phase follows at once.
func begin_round(state: GameState, ev: Array) -> void:
	state.round += 1
	state.phase = GameState.Phase.DWARF
	ev.append(event("round_started", {"round": state.round}))
	var hearth := state.find_tile("hearth")
	for p in state.players:
		p.moves_used = 0
		p.halls_freed = false
		p.tough_tile = PlayerState.NO_TILE
		if p.wounded:
			if p.skip_phases > 0:
				p.skip_phases -= 1
			elif hearth != PlayerState.NO_TILE and not state.tile_at(hearth).is_blocked():
				p.wounded = false
				p.on_board = true
				p.pos = hearth
				ev.append(event("noble_revived", {"player": p.index, "pos": hearth}))

	revealed = true
	for p in state.players:
		p.done = not p.on_board
		if not p.on_board:
			continue
		for pd in p.pending:
			var d := p.add_die(pd["type"], pd["title"])
			d["id"] = pd["id"]
		p.pending.clear()
		for d in p.dice:
			d["value"] = roll(GameData.die_sides(d["type"]))
			d["used"] = false
		var t := state.tile_at(p.pos)
		p.started_on_hearth = t.revealed and t.id == "hearth" and not t.is_blocked()
		ev.append(event("dice_rolled", {"player": p.index, "values": p.dice.map(func(d): return d["value"])}))

	if all_done(state):
		run_enemy_phase(state, ev)


func all_done(state: GameState) -> bool:
	for p in state.players:
		if not p.done:
			return false
	return true

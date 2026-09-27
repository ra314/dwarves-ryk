class_name MoveCommand
extends Command
## Move the Noble one tile (§5.3), optionally carrying warriors from the tile it
## leaves (§5.5). With via_minecart, jump between Mines for free (Master Miner).

var to: Vector2i
var carry: int
var via_minecart: bool


func _init(player_index: int, target: Vector2i, carry_warriors: int = 0, minecart: bool = false) -> void:
	player = player_index
	to = target
	carry = carry_warriors
	via_minecart = minecart


func can_apply(state: GameState, rules: Rules) -> String:
	var err := rules.check_can_act(state, player)
	if err != "":
		return err
	var p := state.players[player]
	if not state.in_bounds(to):
		return "That tile is off the map."
	if rules.is_lost(state, p):
		return "You're lost in the Empty Halls. Discover the Path first."
	if via_minecart:
		if not p.has_title("master_miner"):
			return "Only the Master Miner can ride the minecarts."
		var here := state.tile_at(p.pos)
		var there := state.tile_at(to)
		if not (here.revealed and here.id == "mine" and there.revealed and there.id == "mine") or to == p.pos:
			return "Minecarts only run between two different Mines."
	else:
		if not GameState.is_adjacent(p.pos, to):
			return "You can only move to an orthogonally adjacent tile."
		if p.moves_used >= rules.movement_allowance(p):
			return "No movement left this round."
	if carry < 0 or carry > state.tile_at(p.pos).warriors:
		return "There aren't that many warriors here."
	if carry > rules.data.carry_limit(state.num_players):
		return "You can carry at most %d warriors." % rules.data.carry_limit(state.num_players)
	return ""


func apply(state: GameState, rules: Rules) -> Array:
	var ev: Array = []
	var p := state.players[player]
	var from := p.pos
	state.tile_at(from).warriors -= carry
	state.tile_at(to).warriors += carry
	p.pos = to
	p.tough_tile = PlayerState.NO_TILE
	if not via_minecart:
		p.moves_used += 1
	var dest := state.tile_at(to)
	if dest.revealed and dest.id == "empty_halls":
		p.halls_freed = false
	ev.append(Rules.event("noble_moved", {"player": player, "from": from, "to": to, "carried": carry}))
	rules.resolve_board(state, ev)
	return ev


func describe(state: GameState, _rules: Rules) -> String:
	var s := "%s moves to %s" % [state.players[player].colour, _pos_name(to)]
	if carry > 0:
		s += " with %d warrior%s" % [carry, "" if carry == 1 else "s"]
	if via_minecart:
		s += " by minecart"
	return s


static func _pos_name(p: Vector2i) -> String:
	return "%s%d" % [char(65 + p.x), p.y + 1]

extends GutTest
## Shared helpers for engine tests. Tests may edit engine.state directly to build
## a scenario, then drive it through commands.

const HEARTH := Vector2i(1, 3)
const BARRACKS := Vector2i(1, 2)
const MINE := Vector2i(2, 2)
const LIVING := Vector2i(2, 3)
const TUNNEL_NW := Vector2i(0, 0)
const TUNNEL_SE := Vector2i(4, 4)
const GATE := Vector2i(4, 0)

var engine: GameEngine
var s: GameState:
	get:
		return engine.state


func new_game(players: int = 2, seed: int = 1) -> void:
	engine = GameEngine.new()
	engine.new_game(players, seed)


## Replaces a player's active pool with fresh unused dice, e.g. set_dice(0, {"d6": [4, 2]}).
## Returns the die ids in the order given.
func set_dice(player: int, by_type: Dictionary) -> Array:
	var p := s.players[player]
	p.dice.clear()
	var ids := []
	for t in by_type:
		for v in by_type[t]:
			var d := p.add_die(t)
			d["value"] = v
			ids.append(int(d["id"]))
	return ids


## Shorthand: one d12 per value, so any value up to 12 is possible.
func dice(player: int, values: Array) -> Array:
	return set_dice(player, {"d12": values})


func set_tile(pos: Vector2i, id: String, revealed: bool = true) -> TileState:
	var t := s.tile_at(pos)
	t.id = id
	t.revealed = revealed
	t.flipped = false
	return t


func place(player: int, pos: Vector2i) -> void:
	s.players[player].pos = pos


## Reveals every ruin as Empty Halls-free plain tiles, so tests aren't at the mercy of the shuffle.
func reveal_all_as(id: String) -> void:
	for t in s.tiles:
		if not t.revealed:
			t.id = id
			t.revealed = true


func run(cmd: Command) -> Dictionary:
	var r := engine.execute(cmd)
	assert_true(r["ok"], "command should succeed: %s" % r["error"])
	return r


func refuse(cmd: Command, why_contains: String = "") -> Dictionary:
	var r := engine.execute(cmd)
	assert_false(r["ok"], "command should be refused")
	if why_contains != "":
		assert_string_contains(r["error"], why_contains)
	return r


func has_event(events: Array, type: String) -> bool:
	return events.any(func(e): return e["type"] == type)


func finish_round() -> Dictionary:
	var last := {}
	for p in s.players:
		if not p.done:
			last = run(MarkDoneCommand.new(p.index))
	return last

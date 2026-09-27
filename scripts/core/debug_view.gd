class_name DebugView
extends RefCounted
## Plain-text dump of a GameState, for tests and debugging.
## Run a sample game from the command line:
##   godot --headless -s res://tools/debug_game.gd

const SHORT := {
	"hearth": "HRTH", "mine": "MINE", "living_quarters": "LIVQ", "barracks": "BARR",
	"city_gate": "GATE", "tunnel": "TUNL", "empty_halls": "HALL", "watchtower": "WTCH",
	"blacksmith": "SMTH", "encampment": "CAMP", "throne_room": "THRN", "aviary": "AVRY",
}


static func render(state: GameState, data: GameData) -> String:
	var lines: Array[String] = []
	var phase: String = GameState.Phase.keys()[state.phase]
	lines.append("Round %d  %s  track %d/%d (spawn %s)  supply %d  enemies %d/%d  warriors %d/%d" % [
		state.round, phase, state.turn_index, data.track_last_index(),
		str(data.spawn_per_cell()[state.turn_index]), state.supply,
		state.enemies_on_board(), data.limit("max_enemy_tokens"),
		state.warriors_on_board(), data.limit("max_warrior_tokens")])
	if state.result != "":
		lines.append("GAME %s: %s" % [state.result.to_upper(), state.end_reason])
	lines.append("      A          B          C          D          E")
	for y in state.size:
		var row := "%d " % (y + 1)
		for x in state.size:
			row += " " + cell(state, Vector2i(x, y))
		lines.append(row)
	for p in state.players:
		var where := "off board (skip %d)" % p.skip_phases if not p.on_board else "%s%d" % [char(65 + p.pos.x), p.pos.y + 1]
		var dice := ", ".join(p.dice.map(func(d): return "%s=%d%s" % [d["type"], d["value"], "x" if d["used"] else ""]))
		lines.append("%-7s %-18s res %-2d moves %d  titles %s  dice [%s]  pending %s  reserve %s%s" % [
			p.colour, where, p.resources, p.moves_used, str(p.titles), dice,
			str(p.pending.map(func(d): return d["type"])), str(p.reserve), "  DONE" if p.done else ""])
	return "\n".join(lines)


## e.g. "MINE E2W1*" : tile, enemies, warriors, * = a Noble is here.
static func cell(state: GameState, pos: Vector2i) -> String:
	var t := state.tile_at(pos)
	var name: String = "????" if not t.revealed else SHORT.get(t.id, t.id.substr(0, 4).to_upper())
	if t.revealed and t.flipped:
		name = name.to_lower()
	var tokens := ""
	if t.enemies > 0:
		tokens += "E%d" % t.enemies
	if t.warriors > 0:
		tokens += "W%d" % t.warriors
	if not state.nobles_at(pos).is_empty():
		tokens += "*"
	return "%-10s" % (name + " " + tokens)

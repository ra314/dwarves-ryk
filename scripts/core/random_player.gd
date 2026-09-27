class_name RandomPlayer
extends RefCounted
## Enumerates legal commands for the current state. Used by the debug script and
## by fuzz tests that play whole games with random moves.


static func legal_commands(engine: GameEngine) -> Array[Command]:
	var out: Array[Command] = []
	for p in engine.state.players:
		if engine.rules.check_can_act(engine.state, p.index) == "":
			out.append_array(commands_for(engine, p.index))
	return out


static func commands_for(engine: GameEngine, player: int) -> Array[Command]:
	var s := engine.state
	var p := s.players[player]
	var cands: Array[Command] = [MarkDoneCommand.new(player)]

	for n in s.neighbours(p.pos):
		cands.append(MoveCommand.new(player, n))
		if s.tile_at(p.pos).warriors > 0:
			cands.append(MoveCommand.new(player, n, 1))
	if p.has_title("master_miner"):
		for pos in s.all_positions():
			cands.append(MoveCommand.new(player, pos, 0, true))

	var combos := dice_combos(p, engine.rules.assist_max(p))
	var targets := s.all_positions()
	for pos in [p.pos] + s.neighbours(p.pos):
		var t := s.tile_at(pos)
		for a in engine.data.actions_for(t.id, t.revealed, t.flipped):
			for params in params_for(s, p, a["effect"], targets):
				for c in combos:
					cands.append(UseActionCommand.new(player, pos, a["id"], c, params))
	for d in p.unused_dice():
		for pos in [p.pos] + s.neighbours(p.pos):
			cands.append(NobleCombatCommand.new(player, int(d["id"]), pos))
	for title in p.titles:
		for a in engine.data.title(title)["abilities"]:
			if a["type"] != "action":
				continue
			for params in params_for(s, p, a["effect"], targets):
				for c in combos:
					cands.append(TitleActionCommand.new(player, a["id"], c, params))

	return cands.filter(func(c): return engine.check(c) == "")


## Every set of 1..max unused dice (by id).
static func dice_combos(p: PlayerState, max_dice: int) -> Array:
	var ids: Array = p.unused_dice().map(func(d): return int(d["id"]))
	var out: Array = []
	_combos(ids, 0, [], max_dice, out)
	return out


static func _combos(ids: Array, start: int, cur: Array, max_dice: int, out: Array) -> void:
	if not cur.is_empty():
		out.append(cur.duplicate())
	if cur.size() == max_dice:
		return
	for i in range(start, ids.size()):
		cur.append(ids[i])
		_combos(ids, i + 1, cur, max_dice, out)
		cur.pop_back()


static func params_for(s: GameState, p: PlayerState, effect: String, targets: Array[Vector2i]) -> Array:
	match effect:
		"gain_title":
			return [{"holder_agreed": true}]
		"remove_enemies":
			return targets.filter(func(t): return s.tile_at(t).enemies > 0).map(func(t): return {"target": t})
		"upgrade_die":
			return p.dice.map(func(d): return {"die": int(d["id"])})
		"move_one_enemy":
			var out := []
			for f in targets:
				if s.tile_at(f).enemies > 0:
					for t in targets:
						if absi(f.x - t.x) + absi(f.y - t.y) in [1, 2]:
							out.append({"from": f, "to": t})
			return out
		"swap_adjacent_tiles":
			var out := []
			for a in targets:
				for b in s.neighbours(a):
					if a < b:
						out.append({"a": a, "b": b})
			return out
	return [{}]

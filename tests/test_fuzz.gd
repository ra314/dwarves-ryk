extends "res://tests/engine_test_base.gd"
## Plays whole games with random legal commands and checks invariants after each one.

const GAMES_PER_COUNT := 3


func test_random_games_keep_invariants() -> void:
	var finished := 0
	for players in range(1, 7):
		for g in GAMES_PER_COUNT:
			var seed := players * 100 + g
			new_game(players, seed)
			var total_resources := engine.data.supply_for(players)
			var pick := RandomNumberGenerator.new()
			pick.seed = seed
			var steps := 0
			while not s.is_over() and steps < 3000:
				var cmds := RandomPlayer.legal_commands(engine)
				if cmds.is_empty():
					fail_test("no legal command in a live game (seed %d)" % seed)
					return
				var cmd: Command = cmds[pick.randi_range(0, cmds.size() - 1)]
				assert_true(engine.execute(cmd)["ok"])
				steps += 1
				var err := _invariant_error(total_resources)
				if err != "":
					fail_test("%s (players %d, seed %d, step %d)\n%s" % [err, players, seed, steps, DebugView.render(s, engine.data)])
					return
			if s.is_over():
				finished += 1
	assert_eq(finished, 6 * GAMES_PER_COUNT, "every game should end")


func _invariant_error(total_resources: int) -> String:
	var res := s.supply
	for p in s.players:
		res += p.resources
		if p.resources < 0:
			return "negative resources"
		if p.on_board and not s.in_bounds(p.pos):
			return "noble off the grid"
		var n := p.dice.size() + p.pending.size()
		for k in p.reserve:
			n += int(p.reserve[k])
			if int(p.reserve[k]) < 0:
				return "negative reserve"
		var title_dice := p.dice.filter(func(d): return d["title"] != "").size() + p.pending.filter(func(d): return d["title"] != "").size()
		if n - title_dice != 10:
			return "player owns %d normal dice, not 10" % (n - title_dice)
	if res != total_resources:
		return "resources not conserved: %d vs %d" % [res, total_resources]
	if s.supply < 0:
		return "negative supply"
	if s.enemies_on_board() > engine.data.limit("max_enemy_tokens"):
		return "too many enemies"
	if s.warriors_on_board() > engine.data.limit("max_warrior_tokens"):
		return "too many warriors"
	if s.tunnel_count() > engine.data.limit("max_tunnels"):
		return "too many tunnels"
	for t in s.tiles:
		if t.enemies < 0 or t.warriors < 0:
			return "negative tokens"
		if t.enemies > 0 and t.warriors > 0:
			return "combat not resolved"
	var holders := {}
	for p in s.players:
		for t in p.titles:
			if holders.has(t):
				return "title held twice"
			holders[t] = true
		if p.titles.size() > engine.data.titles_per_player(s.num_players):
			return "too many titles"
	return ""

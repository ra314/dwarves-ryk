extends GutTest
## The enemy turn replay steps a copy of the board through the events. When it
## ends, that copy must match the real state, or the replay showed a wrong board.

var main


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	main.recorder.dir = "user://test_replays"  # keep tests out of the real replays folder


func after_each() -> void:
	var d := DirAccess.open("user://test_replays")
	if d:
		for f in d.get_files():
			d.remove(f)


func _board_key(s: GameState) -> Array:
	var out := []
	for t in s.tiles:
		out.append([t.id, t.revealed, t.flipped, t.enemies, t.warriors])
	for p in s.players:
		out.append([p.on_board, p.pos if p.on_board else Vector2i(-1, -1)])
	out.append(s.turn_index)
	return out


func test_replay_ends_on_the_real_board_in_random_games() -> void:
	var engine: GameEngine = main.engine
	var phases := 0
	for seed in [3, 11, 29]:
		engine.new_game(1 + seed % 6, seed)
		var pick := RandomNumberGenerator.new()
		pick.seed = seed
		var steps := 0
		while not engine.state.is_over() and steps < 1500:
			var cmds := RandomPlayer.legal_commands(engine)
			var r := engine.execute(cmds[pick.randi_range(0, cmds.size() - 1)])
			steps += 1
			if not r["events"].any(func(e): return e["type"] == "enemy_phase_started"):
				continue
			var before: GameState = engine.history.peek()["state"].copy()
			await main.animator.play(before, r["events"], true)
			assert_eq(_board_key(main.animator.board), _board_key(engine.state),
				"seed %d step %d" % [seed, steps])
			phases += 1
	assert_gt(phases, 10)


func test_done_with_animation_blocks_input_then_finishes() -> void:
	main.animate_enemy_turn = true
	main._run(MarkDoneCommand.new(0))
	main._run(MarkDoneCommand.new(1))  # starts the replay; returns at its first pause
	assert_true(main.animating)
	assert_true(main.blocker.visible)
	main._run(MarkDoneCommand.new(0))  # ignored while replaying
	main.animator.skip = true
	var frames := 0
	while main.animating and frames < 600:
		await get_tree().process_frame
		frames += 1
	assert_false(main.animating)
	assert_false(main.blocker.visible)
	assert_eq(main.engine.state.round, 2)
	assert_eq(main.tile_views[0].tile, main.engine.state.tiles[0], "board redrawn from the real state")


func _mv(fx: int, tx: int, y: int = 2) -> Dictionary:
	return {"type": "enemy_moved", "from": Vector2i(fx, y), "to": Vector2i(tx, y), "count": 1}


func test_march_order_leading_group_first_bounces_last() -> void:
	# Moving west: x=1 leads, then 2, then 3; the x=0 group bounces east, last.
	var moves := [_mv(3, 2), _mv(0, 1), _mv(1, 0), _mv(2, 1)]
	var order := EnemyTurnAnimator._march_order(moves).map(func(m): return m["from"].x)
	assert_eq(order, [1, 2, 3, 0])


func test_march_order_south() -> void:
	var moves := [
		{"from": Vector2i(0, 1), "to": Vector2i(0, 2), "count": 1},
		{"from": Vector2i(0, 3), "to": Vector2i(0, 4), "count": 1},
		{"from": Vector2i(2, 2), "to": Vector2i(2, 3), "count": 1}]
	var order := EnemyTurnAnimator._march_order(moves).map(func(m): return m["from"].y)
	assert_eq(order, [3, 2, 1])

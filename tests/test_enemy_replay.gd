extends GutTest
## The enemy turn replay steps a copy of the board through the events. When it
## ends, that copy must match the real state, or the replay showed a wrong board.

var main


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)


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

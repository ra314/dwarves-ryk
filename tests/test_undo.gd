extends "res://tests/engine_test_base.gd"
## Milestone 5: undo snapshots, checkpoints and the unlimited setting (§6, R18, R19).

const RUIN := Vector2i(0, 3)


func before_each() -> void:
	new_game(2)


func test_nothing_to_undo_at_start() -> void:
	assert_false(engine.can_undo())
	assert_eq(engine.undo(), {})


func test_undo_move() -> void:
	var before := s.to_dict()
	run(MoveCommand.new(0, BARRACKS))
	assert_true(engine.can_undo())
	assert_eq(engine.undo_label(), "Green moves to B3")
	engine.undo()
	assert_eq(s.to_dict(), before)


func test_undo_action_restores_dice_and_resources() -> void:
	var ids := dice(0, [3])
	var before := s.to_dict()
	run(UseActionCommand.new(0, BARRACKS, "train_warrior", ids))
	engine.undo()
	assert_eq(s.to_dict(), before)


func test_undo_several_steps() -> void:
	var before := s.to_dict()
	run(MoveCommand.new(0, BARRACKS))
	run(MoveCommand.new(1, LIVING))
	run(MarkDoneCommand.new(1))
	engine.undo()
	engine.undo()
	engine.undo()
	assert_eq(s.to_dict(), before)
	assert_false(engine.can_undo())


func test_r18_history_is_shared() -> void:
	run(MoveCommand.new(0, BARRACKS))
	run(MoveCommand.new(1, LIVING))
	var entry := engine.undo()
	assert_eq(entry["player"], 1, "undo reverses the latest action, whoever took it")
	assert_eq(s.players[1].pos, HEARTH)
	assert_eq(s.players[0].pos, BARRACKS)
	assert_eq(engine.undo()["player"], 0)


func test_undo_mark_done() -> void:
	run(MarkDoneCommand.new(0))
	engine.undo()
	assert_false(s.players[0].done)


func test_expedition_is_a_checkpoint() -> void:
	set_tile(RUIN, "mine", false)
	run(MoveCommand.new(1, LIVING))
	run(UseActionCommand.new(0, RUIN, "expedition", dice(0, [3])))
	assert_false(engine.can_undo(), "can't take back a reveal in normal mode")
	run(MoveCommand.new(1, MINE))
	assert_true(engine.can_undo())
	engine.undo()
	assert_false(engine.can_undo())
	assert_true(s.tile_at(RUIN).revealed)


func test_enemy_phase_is_a_checkpoint() -> void:
	finish_round()
	assert_eq(s.round, 2)
	assert_false(engine.can_undo())


func test_unlimited_undo_goes_past_reveals() -> void:
	engine.unlimited_undo = true
	set_tile(RUIN, "mine", false)
	var ids := dice(0, [3])
	var before := s.to_dict()
	run(UseActionCommand.new(0, RUIN, "expedition", ids))
	finish_round()
	while engine.can_undo():
		engine.undo()
	assert_eq(s.to_dict(), before)


func test_r19_redo_after_undo_rolls_fresh() -> void:
	engine.unlimited_undo = true
	# Replay the same expedition many times; the RNG isn't rewound so results vary.
	set_tile(RUIN, "mine", false)
	var ids := dice(0, [3])
	var seen := {}
	for i in 20:
		run(UseActionCommand.new(0, RUIN, "expedition", ids))
		seen[s.tile_at(RUIN).enemies] = true
		engine.undo()
	assert_gt(seen.size(), 1)


func test_rng_is_not_part_of_state() -> void:
	engine.unlimited_undo = true
	run(MarkDoneCommand.new(0))
	var rng_state := engine.rng.state
	run(MarkDoneCommand.new(1))
	var after := engine.rng.state
	assert_ne(after, rng_state)
	engine.undo()
	assert_eq(engine.rng.state, after, "undo never rewinds the RNG")


func test_failed_command_not_recorded() -> void:
	refuse(MoveCommand.new(0, MINE))
	assert_false(engine.can_undo())

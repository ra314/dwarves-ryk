extends "res://tests/engine_test_base.gd"
## Recording games to .dwreplay files and reading them back.

const DIR := "user://test_replays"


func after_each() -> void:
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			d.remove(f)


func _record(players: int, seed: int, steps: int, undo_every: int = 0) -> ReplayLog:
	new_game(players, seed)
	var rec := ReplayLog.new()
	rec.dir = DIR
	rec.start(s)
	var pick := RandomNumberGenerator.new()
	pick.seed = seed
	var n := 0
	while not s.is_over() and n < steps:
		var cmds := RandomPlayer.legal_commands(engine)
		var cmd: Command = cmds[pick.randi_range(0, cmds.size() - 1)]
		var r := engine.execute(cmd)
		rec.step(engine.undo_label(), cmd.player, r["events"], s)
		n += 1
		if undo_every > 0 and n % undo_every == 0 and engine.can_undo():
			engine.undo()
			rec.undo()
	return rec


func test_no_file_until_something_happens() -> void:
	new_game(2)
	var rec := ReplayLog.new()
	rec.dir = DIR
	rec.start(s)
	assert_eq(rec.path, "")
	var r := engine.execute(MoveCommand.new(0, BARRACKS))
	rec.step(engine.undo_label(), 0, r["events"], s)
	assert_ne(rec.path, "")
	assert_true(FileAccess.file_exists(rec.path))
	assert_eq(rec.path.get_extension(), "dwreplay")


func test_replay_ends_on_the_final_state() -> void:
	for seed in [1, 2, 3]:
		var rec := _record(1 + seed, seed, 400)
		var r := ReplayLog.read(rec.path)
		assert_eq(r["error"], "")
		assert_eq(r["frames"].back()["state"].to_dict(), s.to_dict(), "seed %d" % seed)
		assert_eq(r["players"].size(), s.num_players)


func test_undone_steps_are_dropped() -> void:
	var rec := _record(2, 5, 200, 7)
	var r := ReplayLog.read(rec.path)
	assert_eq(r["frames"].back()["state"].to_dict(), s.to_dict())
	# Every frame's state is the one after its step: frames line up with history.
	assert_eq(r["frames"][0]["label"], "Game start")


func test_events_keep_positions_and_ints() -> void:
	new_game(2)
	var rec := ReplayLog.new()
	rec.dir = DIR
	rec.start(s)
	var r := engine.execute(MoveCommand.new(0, BARRACKS))
	rec.step(engine.undo_label(), 0, r["events"], s)
	var e: Dictionary = ReplayLog.read(rec.path)["frames"][1]["events"][0]
	assert_eq(e["type"], "noble_moved")
	assert_eq(e["to"], BARRACKS)
	assert_typeof(e["player"], TYPE_INT)


func test_half_written_last_line_is_ignored() -> void:
	var rec := _record(2, 9, 30)
	var f := FileAccess.open(rec.path, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string("{\"t\": \"step\", \"label\": \"cut off")
	f = null
	var r := ReplayLog.read(rec.path)
	assert_eq(r["error"], "")
	assert_eq(r["frames"].back()["state"].to_dict(), s.to_dict())


func test_resume_appends_to_same_file() -> void:
	var rec := _record(2, 4, 10)
	var first := rec.path
	var again := ReplayLog.new()
	assert_true(again.resume(first))
	var r := engine.execute(MarkDoneCommand.new(0)) if engine.check(MarkDoneCommand.new(0)) == "" else {"events": []}
	again.step("more", 0, r["events"], s)
	assert_eq(again.path, first)
	assert_eq(ReplayLog.read(first)["frames"].back()["label"], "more")

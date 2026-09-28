extends GutTest
## The Files window: listing replays, watching and deleting them, and moving
## saves in and out.

const DIR := "user://test_replays"
var main


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.settings_path = "user://test_settings.cfg"
	add_child_autofree(main)
	main.recorder.dir = DIR
	main.animate_enemy_turn = false


func after_each() -> void:
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			d.remove(f)
	for p in ["user://test_settings.cfg", "user://save.json.test_backup"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _play_two_moves() -> void:
	main._run(MoveCommand.new(0, Vector2i(1, 2)))
	main._run(MoveCommand.new(1, Vector2i(2, 3)))


func _rows() -> Array:
	# Rows are the HBoxes holding a Watch button.
	return main.files_window._list.get_children().filter(func(c):
		return c is HBoxContainer and c.get_children().any(func(b): return b is Button and b.text == "Watch"))


func test_summary_counts_steps_after_undo() -> void:
	_play_two_moves()
	main._undo()
	var info := ReplayLog.summary(main.recorder.path)
	assert_eq(info["steps"], 1)
	assert_eq(info["players"], ["Green", "Red"])
	assert_ne(info["started"], "")


func test_list_is_newest_first() -> void:
	_play_two_moves()
	var first: String = main.recorder.path
	main._new_game()
	main.recorder.dir = DIR
	main._run(MoveCommand.new(0, Vector2i(1, 2)))
	var files := ReplayLog.list([DIR])
	assert_eq(files.size(), 2)
	assert_eq(files[1], first)


func test_window_lists_this_game_and_protects_it() -> void:
	_play_two_moves()
	main.files_window.open()
	await get_tree().process_frame
	var rows := _rows()
	assert_eq(rows.size(), 1)
	var label: Label = rows[0].get_child(0)
	assert_string_contains(label.text, "(this game)")
	assert_string_contains(label.text, "2 steps")
	var delete: Button = rows[0].get_children().filter(func(b): return b is Button and b.text == "Delete")[0]
	assert_true(delete.disabled)
	main.files_window.hide()


func test_watch_and_delete_from_the_window() -> void:
	_play_two_moves()
	var old: String = main.recorder.path
	main._new_game()  # the first game's replay is no longer "this game"
	main.recorder.dir = DIR
	main.files_window.open()
	await get_tree().process_frame
	var rows := _rows()
	assert_eq(rows.size(), 1)
	var buttons: Array = rows[0].get_children().filter(func(b): return b is Button)
	var watch: Button = buttons.filter(func(b): return b.text == "Watch")[0]
	watch.pressed.emit()
	assert_true(main.replay_mode)
	assert_eq(main.replay_bar.frames.size(), 3)
	main.exit_replay()
	main.files_window.open()
	await get_tree().process_frame
	var del: Button = _rows()[0].get_children().filter(func(b): return b is Button and b.text == "Delete")[0]
	assert_false(del.disabled)
	del.pressed.emit()
	assert_false(FileAccess.file_exists(old))
	main.files_window.hide()


func test_load_game_from_file_text() -> void:
	# Keep whatever real save exists safe during the test.
	var real := ProjectSettings.globalize_path(main.SAVE_PATH)
	var had_save := FileAccess.file_exists(main.SAVE_PATH)
	if had_save:
		DirAccess.copy_absolute(real, ProjectSettings.globalize_path("user://save.json.test_backup"))
	var e := GameEngine.new()
	e.new_game(3, 5)
	e.state.players[0].resources = 17
	var tmp := "user://test_export.json"
	e.save_to(tmp)
	var text := FileAccess.get_file_as_string(tmp)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

	main._on_save_file_loaded("bad.json", "not a save")
	assert_string_contains(main.prompt_label.text, "isn't a Dwarves save file")
	main._on_save_file_loaded("game.json", text)
	assert_eq(main.engine.state.num_players, 3)
	assert_eq(main.engine.state.players[0].resources, 17)

	if had_save:
		DirAccess.copy_absolute(ProjectSettings.globalize_path("user://save.json.test_backup"), real)
	else:
		DirAccess.remove_absolute(real)

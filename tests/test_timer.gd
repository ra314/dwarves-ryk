extends GutTest
## The game clock in the top bar.

var main


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.settings_path = "user://test_settings.cfg"
	add_child_autofree(main)
	main.recorder.dir = "user://test_replays"


func after_each() -> void:
	var d := DirAccess.open("user://test_replays")
	if d:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))


func test_format() -> void:
	assert_eq(main.format_time(0), "0:00")
	assert_eq(main.format_time(5.9), "0:05")
	assert_eq(main.format_time(754), "12:34")
	assert_eq(main.format_time(3723), "1:02:03")


func test_counts_up_and_shows_it() -> void:
	main._process(61.5)
	assert_almost_eq(main.elapsed, 61.5, 0.2)
	assert_eq(main.timer_label.text, "1:01")


func test_new_game_resets() -> void:
	main._process(125.0)
	main._new_game()
	assert_eq(main.elapsed, 0.0)
	assert_eq(main.timer_label.text, "0:00")


func test_paused_while_watching_a_replay() -> void:
	main._run(MoveCommand.new(0, Vector2i(1, 2)))
	main._process(10.0)
	var before: float = main.elapsed
	main.enter_replay(main.recorder.path)
	main._process(30.0)
	assert_eq(main.elapsed, before)
	main.exit_replay()
	main._process(1.0)
	assert_almost_eq(main.elapsed, before + 1.0, 0.2)


func test_stops_when_the_game_is_over() -> void:
	main._process(5.0)
	main.engine.state.phase = GameState.Phase.OVER
	main._process(100.0)
	assert_almost_eq(main.elapsed, 5.0, 0.2)


func test_saved_and_loaded_with_the_game() -> void:
	var real := ProjectSettings.globalize_path(main.SAVE_PATH)
	var backup := ProjectSettings.globalize_path("user://save.json.timer_backup")
	var had := FileAccess.file_exists(main.SAVE_PATH)
	if had:
		DirAccess.copy_absolute(real, backup)
	main._process(90.0)
	main._save()
	main._new_game()
	assert_eq(main.elapsed, 0.0)
	main._load()
	assert_almost_eq(main.elapsed, 90.0, 0.2)
	assert_eq(main.timer_label.text, "1:30")
	if had:
		DirAccess.copy_absolute(backup, real)
		DirAccess.remove_absolute(backup)
	else:
		DirAccess.remove_absolute(real)

extends GutTest
## Milestone 6: the main scene loads and drives the engine through its own handlers.

var main


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)


func test_scene_builds_board_and_trays() -> void:
	assert_eq(main.tile_views.size(), 25)
	assert_eq(main.engine.state.players.size(), 2)


func test_tile_menu_lists_moves_and_actions() -> void:
	main._on_tile_clicked(Vector2i(1, 2))  # Barracks, next to the Hearth
	var items := []
	for i in main.menu.item_count:
		items.append(main.menu.get_item_text(i))
	assert_true(items.any(func(t): return t.begins_with("Move here")))
	assert_true(items.any(func(t): return t.begins_with("Train Warrior")))
	main.menu.hide()


func test_run_and_undo_through_ui() -> void:
	var s: GameState = main.engine.state
	main._run(MoveCommand.new(0, Vector2i(1, 2)))
	assert_eq(s.players[0].pos, Vector2i(1, 2))
	assert_true(main.undo_button.text.begins_with("Undo: Green moves"))
	main._undo()
	assert_eq(main.engine.state.players[0].pos, Vector2i(1, 3))


func test_target_mode_waits_for_a_tile() -> void:
	var s: GameState = main.engine.state
	s.players[0].titles.append("master_smith")
	var d = s.players[0].dice[0]
	d["value"] = 6
	main.selected = [int(d["id"])]
	var make := func(params): return TitleActionCommand.new(0, "architect", [int(d["id"])], params)
	main._collect_params({"effect": "swap_adjacent_tiles"}, Vector2i(1, 2), make)
	assert_true(main.target_step.is_valid())
	main._on_tile_clicked(Vector2i(2, 2))
	assert_eq(main.engine.state.tile_at(Vector2i(1, 2)).id, "mine")

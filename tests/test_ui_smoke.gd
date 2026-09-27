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


## Presses the item whose text starts with prefix, as Godot does: by the item's id.
func _press(prefix: String) -> void:
	for i in main.menu.item_count:
		if main.menu.get_item_text(i).begins_with(prefix):
			assert_false(main.menu.is_item_disabled(i), prefix)
			main.menu.id_pressed.emit(main.menu.get_item_id(i))
			return
	fail_test("no menu item starting '%s'" % prefix)


func test_pressing_a_menu_item_runs_that_item() -> void:
	var s: GameState = main.engine.state
	s.tile_at(Vector2i(1, 3)).warriors = 2
	main._on_tile_clicked(Vector2i(1, 2))  # Barracks: heading, Move, Move carrying 1, Move carrying 2, ...
	_press("Move here carrying 2")
	assert_eq(main.engine.state.players[0].pos, Vector2i(1, 2))
	assert_eq(main.engine.state.tile_at(Vector2i(1, 2)).warriors, 2)


func test_choice_popup_runs_chosen_option() -> void:
	var s: GameState = main.engine.state
	var smith := Vector2i(0, 3)
	s.tile_at(smith).id = "blacksmith"
	s.tile_at(smith).revealed = true
	var p := s.players[0]
	p.dice.clear()
	var spend := p.add_die("d8")
	spend["value"] = 5
	var d4 := p.add_die("d4")
	d4["value"] = 1
	var d6 := p.add_die("d6")
	d6["value"] = 1
	main.selected = [int(spend["id"])]
	main._on_tile_clicked(smith)
	_press("Promote Worker")
	_press("d6")  # second option in "Promote which die?"
	assert_eq(main.engine.state.players[0].pending.map(func(d): return d["type"]), ["d8"])

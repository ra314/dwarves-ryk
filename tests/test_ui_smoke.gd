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


func _menu_texts() -> Array:
	var out := []
	for i in main.menu.item_count:
		out.append(main.menu.get_item_text(i))
	main.menu.hide()
	return out


func test_expedition_text_follows_messenger() -> void:
	var s: GameState = main.engine.state
	var ruin := Vector2i(0, 3)
	s.tile_at(ruin).revealed = false
	main._refresh()
	main._on_tile_clicked(ruin)
	assert_true(_menu_texts().any(func(t): return t.begins_with("Expedition (3+, 2 res) · spawns d4")))
	assert_string_contains(main.tile_views[3 * 5].tooltip_text, "Expedition (3+, 2 res)")
	s.players[0].titles.append("messenger")
	main._refresh()
	main._on_tile_clicked(ruin)
	assert_true(_menu_texts().any(func(t): return t.begins_with("Expedition (3+, free) · Messenger: spawns 1")))
	assert_string_contains(main.tile_views[3 * 5].tooltip_text, "Expedition (3+, free)")
	# Another player's hover still shows their own numbers.
	main._set_acting(1)
	assert_string_contains(main.tile_views[3 * 5].tooltip_text, "Expedition (3+, 2 res)")


func test_promote_text_follows_master_smith() -> void:
	var s: GameState = main.engine.state
	var smith := Vector2i(0, 3)
	s.tile_at(smith).id = "blacksmith"
	s.tile_at(smith).revealed = true
	s.players[0].titles.append("master_smith")
	main._refresh()
	assert_string_contains(main.tile_views[3 * 5].tooltip_text, "Promote Worker (1+, 3 res) · Master Smith")


func test_blocked_tile_hover_says_passives_are_off() -> void:
	var s: GameState = main.engine.state
	s.tile_at(Vector2i(1, 3)).enemies = 1
	var tower := Vector2i(0, 3)
	s.tile_at(tower).id = "watchtower"
	s.tile_at(tower).revealed = true
	s.tile_at(tower).enemies = 1
	main._refresh()
	assert_string_contains(main.tile_views[3 * 5 + 1].tooltip_text, "Motivated: When you start your turn here you gain +1 movement this turn  (off while blocked)")
	var tower_tip: String = main.tile_views[3 * 5].tooltip_text
	assert_string_contains(tower_tip, "Garrison")
	assert_false(tower_tip.contains("Garrison: Dwarf nobles can't be wounded here  (off"), "Garrison stays on (R21)")


func test_title_hover_is_from_acting_players_view() -> void:
	var s: GameState = main.engine.state
	s.players[1].titles.append("regent")
	s.players[0].titles.append("workmaster")
	main._refresh()
	var tip: String = main._title_tip("regent")
	assert_string_contains(tip, "Held by Red")
	assert_string_contains(tip, "Red must agree")
	assert_string_contains(tip, "Taking it returns your Workmaster")
	assert_string_contains(tip, "Bodyguard (7+) · single die")

extends GutTest
## Milestone 6: the main scene loads and drives the engine through its own handlers.

var main


func before_each() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.settings_path = "user://test_settings.cfg"  # never touch the player's settings
	add_child_autofree(main)
	main.recorder.dir = "user://test_replays"  # keep tests out of the real replays folder


func after_each() -> void:
	var d := DirAccess.open("user://test_replays")
	if d:
		for f in d.get_files():
			d.remove(f)


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


## Presses the item whose text starts with prefix the way Godot does: emits
## id_pressed with the item's id, then hides the menu (hide_on_item_selection).
func _press(prefix: String, m: PopupMenu = null) -> void:
	if m == null:
		m = main.menu
	for i in m.item_count:
		if m.get_item_text(i).begins_with(prefix):
			assert_false(m.is_item_disabled(i), prefix)
			m.id_pressed.emit(m.get_item_id(i))
			if m.hide_on_item_selection:
				m.hide()
			await get_tree().process_frame  # deferred popups open here
			return
	fail_test("no menu item starting '%s' in %s" % [prefix, range(m.item_count).map(func(j): return m.get_item_text(j))])


func test_pressing_a_menu_item_runs_that_item() -> void:
	var s: GameState = main.engine.state
	s.tile_at(Vector2i(1, 3)).warriors = 2
	main._on_tile_clicked(Vector2i(1, 2))  # Barracks: heading, Move, Move carrying 1, Move carrying 2, ...
	await _press("Move here carrying 2")
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
	await _press("Promote Worker")
	assert_true(main.choice_menu.visible, "the die list must still be open after the tile menu closes")
	await _press("d6", main.choice_menu)
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


func test_record_then_watch_replay_and_exit() -> void:
	main.recorder.dir = "user://test_replays"
	main.animate_enemy_turn = false
	main._run(MoveCommand.new(0, Vector2i(1, 2)))
	main._run(MoveCommand.new(1, Vector2i(2, 3)))
	main._undo()
	main._run(MoveCommand.new(1, Vector2i(1, 2)))
	var live: Dictionary = main.engine.state.to_dict()
	var path: String = main.recorder.path
	assert_ne(path, "")
	main.enter_replay(path)
	assert_true(main.replay_mode)
	assert_eq(main.replay_bar.frames.size(), 3, "start + 2 moves; the undone move is gone")
	assert_eq(main.engine.state.players[0].pos, Vector2i(1, 3), "frame 0 is the setup")
	main._run(MoveCommand.new(0, Vector2i(1, 2)))  # ignored while watching
	assert_eq(main.engine.state.players[0].pos, Vector2i(1, 3))
	main.replay_bar.go_to(1)
	assert_eq(main.engine.state.players[0].pos, Vector2i(1, 2))
	main.replay_bar.go_to(2)
	assert_eq(main.engine.state.players[1].pos, Vector2i(1, 2))
	main.exit_replay()
	assert_false(main.replay_mode)
	assert_eq(main.engine.state.to_dict(), live, "your game is back as it was")
	assert_true(main.engine.can_undo(), "and so is its undo history")
	DirAccess.remove_absolute(path)


func test_animation_speed_scales_delays_and_is_saved() -> void:
	main.set_anim_speed(2.0)
	assert_almost_eq(main.scaled(EnemyTurnAnimator.STEP_SECONDS), 0.1, 0.0001)
	assert_almost_eq(main.scaled(ReplayViewer.PLAY_DELAY), 0.4, 0.0001)
	assert_string_starts_with(main.speed_label.text, "2×  (0.10 s per tile)")
	main.set_anim_speed(99.0)
	assert_eq(main.anim_speed, main.SPEED_MAX, "clamped")
	main.set_anim_speed(0.5)
	# A fresh screen reads the saved speed back.
	var other = load("res://scenes/main.tscn").instantiate()
	other.settings_path = "user://test_settings.cfg"
	add_child_autofree(other)
	assert_eq(other.anim_speed, 0.5)
	assert_almost_eq(other.scaled(EnemyTurnAnimator.STEP_SECONDS), 0.4, 0.0001)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))


func _give_all_dice(p: PlayerState) -> void:
	p.dice.clear()
	for t in ["d4", "d4", "d4", "d6", "d6", "d6", "d6", "d8", "d8", "d8", "d10", "d12"]:
		var d := p.add_die(t)
		d["value"] = 3
	for k in p.reserve:
		p.reserve[k] = 0


func test_dice_keep_full_size_when_they_fit() -> void:
	assert_eq(main.dice_side(5, false), main.DIE_MAX)


func test_every_die_fits_in_the_tray() -> void:
	var p: PlayerState = main.engine.state.players[0]
	_give_all_dice(p)
	for showing_total in [false, true]:
		main.selected = [int(p.dice[0]["id"])] if showing_total else []
		main._refresh()
		await get_tree().process_frame
		var tray: HBoxContainer = null
		for n in main.players_box.get_child(0).find_children("*", "HBoxContainer", true, false):
			if n.get_children().any(func(c): return c is DiceView):
				tray = n
		assert_not_null(tray)
		assert_eq(tray.get_children().filter(func(c): return c is DiceView).size(), 12)
		assert_lte(tray.get_combined_minimum_size().x, float(main.TRAY_WIDTH), "selected total shown: %s" % showing_total)

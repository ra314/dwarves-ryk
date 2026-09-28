extends Control
## Hot-seat game screen. Draws GameState and turns clicks into commands; it never
## edits state directly. Pick whose dice to use by clicking in that player's tray,
## then click a tile for the moves and actions available there.

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.cfg"
const MARGIN := 10
const TILE_GAP := 4
## Tiles fill the full height of the 960px-tall layout.
const TILE := (960 - 2 * MARGIN - 4 * TILE_GAP) / 5
const PHASE_NAMES := ["Dwarf Phase", "Enemy Phase", "Game over"]

var engine := GameEngine.new()
var acting: int = 0
var selected: Array = []           # die ids of the acting player
var target_step: Callable          # set while waiting for a tile click: func(pos)
var textures := {}
var _shown_round := -1             # dice tumble when a new round's roll is first shown

var tile_views: Array[TileView] = []
var board: GridContainer
var status_flow: HFlowContainer
var prompt_label: Label
var cancel_button: Button
var undo_button: Button
var unlimited_check: CheckBox
var players_spin: SpinBox
var players_box: VBoxContainer
var track_view: TrackView
var titles_grid: GridContainer
var log_view: RichTextLabel
## Every game is recorded to a replay file as it's played (see ReplayLog).
var recorder := ReplayLog.new()
## Watching a replay: the live game is set aside and restored on exit.
var replay_mode := false
var replay_bar: ReplayViewer
var file_bridge: FileBridge
var files_window: FilesWindow
var _stashed_state: GameState
var _stashed_history: Array[Dictionary] = []
var undo_row: HBoxContainer

## Enemy turn replay (optional, remembered in SETTINGS_PATH).
var animate_enemy_turn := true
var animating := false
var animator: EnemyTurnAnimator
var animate_check: CheckBox
## Animation speed multiplier: every enemy-turn and replay delay is divided by it.
var anim_speed := 1.0
const SPEED_MIN := 0.25
const SPEED_MAX := 4.0
var speed_label: Label
## Where settings are kept; tests point this at a scratch file before _ready.
var settings_path := SETTINGS_PATH
var fx_layer: Control
var blocker: Control
var banner: PanelContainer
var banner_label: Label
var menu: PopupMenu
## Follow-up picks (which die, which title) get their own popup: Godot hides a
## PopupMenu after running the picked item's action, so reusing `menu` would
## close the new list as soon as it opened.
var choice_menu: PopupMenu
var choice_actions: Array[Callable] = []
var menu_actions: Array[Callable] = []
var confirm: ConfirmationDialog
var confirm_action: Callable


func _ready() -> void:
	_load_settings()
	animator = EnemyTurnAnimator.new(self)
	_build_ui()
	_new_game()
	# In the browser, ?replay=<url> opens a shared replay straight away.
	file_bridge.open_from_url_param(_on_replay_opened)


# --- Files ------------------------------------------------------------------------

## Saves to the slot, then hands the player a copy of the file.
func download_game() -> void:
	if replay_mode:
		_error("Exit the replay first.")
		return
	_save()
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	file_bridge.export_file(SAVE_PATH, "dwarves_save_%s.json" % stamp)


func load_game_from_file() -> void:
	file_bridge.pick("Load a game", "json", _on_save_file_loaded)


## A save file from outside: checked before it replaces the save slot.
func _on_save_file_loaded(file_name: String, text: String) -> void:
	var d = JSON.parse_string(text)
	if not (d is Dictionary) or not d.has("state"):
		_error("%s isn't a Dwarves save file." % file_name)
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(text)
	f = null
	files_window.hide()
	_load()


func open_replay_file() -> void:
	file_bridge.pick("Watch a replay", ReplayLog.EXTENSION, _on_replay_opened)


func open_replays_folder() -> void:
	DirAccess.make_dir_recursive_absolute(recorder.dir)
	OS.shell_open(ProjectSettings.globalize_path(recorder.dir))


## A replay picked from a file or fetched from a ?replay= link: keep a copy and watch it.
func _on_replay_opened(file_name: String, text: String) -> void:
	var path := FileBridge.store_opened(file_name, text)
	if path == "":
		_error("Couldn't open %s." % file_name)
		return
	files_window.hide()
	enter_replay(path)


# --- Layout ---------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1e1b18")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	# Board on the left, as tall as the screen; every control in one column on the right.
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	board = GridContainer.new()
	board.columns = 5
	board.add_theme_constant_override("h_separation", TILE_GAP)
	board.add_theme_constant_override("v_separation", TILE_GAP)
	root.add_child(board)

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(side)

	var top := HBoxContainer.new()
	side.add_child(top)
	top.add_child(_label("Players"))
	players_spin = SpinBox.new()
	players_spin.min_value = 1
	players_spin.max_value = 6
	players_spin.value = 2
	top.add_child(players_spin)
	top.add_child(_button("New game", _new_game))
	top.add_child(_button("Save", _save))
	top.add_child(_button("Load", _load))
	top.add_child(_button("Fullscreen (F11)", _toggle_fullscreen))
	var files := _button("Files", func(): files_window.open())
	files.tooltip_text = "Saves and replays: download them, load them from a file, watch or delete replays."
	top.add_child(files)

	replay_bar = ReplayViewer.new(self)
	replay_bar.visible = false
	side.add_child(replay_bar)

	undo_row = HBoxContainer.new()
	side.add_child(undo_row)
	undo_button = _button("Undo", _undo)
	undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	undo_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	undo_row.add_child(undo_button)
	unlimited_check = CheckBox.new()
	unlimited_check.text = "Unlimited undo"
	unlimited_check.toggled.connect(func(on): engine.unlimited_undo = on; _refresh())
	undo_row.add_child(unlimited_check)
	animate_check = CheckBox.new()
	animate_check.text = "Animate enemy turn"
	animate_check.button_pressed = animate_enemy_turn
	animate_check.tooltip_text = "Replay the Enemy Phase step by step. Space or Esc skips."
	animate_check.toggled.connect(func(on): animate_enemy_turn = on; _save_settings())
	var anim_row := HBoxContainer.new()
	anim_row.add_theme_constant_override("separation", 8)
	side.add_child(anim_row)
	anim_row.add_child(animate_check)
	anim_row.add_child(_label("Speed"))
	var speed := HSlider.new()
	speed.min_value = SPEED_MIN
	speed.max_value = SPEED_MAX
	speed.step = 0.25
	speed.value = anim_speed
	speed.custom_minimum_size = Vector2(160, 0)
	speed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ReplayViewer.style_slider(speed)
	speed.value_changed.connect(set_anim_speed)
	anim_row.add_child(speed)
	speed_label = _label("")
	anim_row.add_child(speed_label)
	_update_speed_label()

	# Turn track art on the left; status, prompts and the title cards beside it.
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 10)
	side.add_child(info_row)
	track_view = TrackView.new(_cached_texture(engine.data.raw["turn_track"]["image"]), 170)
	info_row.add_child(track_view)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(info)
	status_flow = HFlowContainer.new()
	status_flow.add_theme_constant_override("h_separation", 12)
	info.add_child(status_flow)

	var prompt_row := HBoxContainer.new()
	info.add_child(prompt_row)
	prompt_label = _label("")
	prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_row.add_child(prompt_label)
	cancel_button = _button("Cancel", _cancel_target)
	cancel_button.visible = false
	prompt_row.add_child(cancel_button)

	titles_grid = GridContainer.new()
	titles_grid.columns = 3
	titles_grid.add_theme_constant_override("h_separation", 8)
	titles_grid.add_theme_constant_override("v_separation", 8)
	titles_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	titles_grid.size_flags_vertical = Control.SIZE_SHRINK_END
	info.add_child(titles_grid)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	players_box = VBoxContainer.new()
	players_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(players_box)
	side.add_child(_label("Log"))
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.scroll_following = true
	log_view.custom_minimum_size = Vector2(0, 180)
	side.add_child(log_view)

	menu = PopupMenu.new()
	menu.id_pressed.connect(func(id): menu_actions[id].call())
	add_child(menu)
	choice_menu = PopupMenu.new()
	choice_menu.id_pressed.connect(func(id): choice_actions[id].call())
	add_child(choice_menu)
	confirm = ConfirmationDialog.new()
	confirm.confirmed.connect(func(): confirm_action.call())
	add_child(confirm)
	file_bridge = FileBridge.new()
	add_child(file_bridge)
	files_window = FilesWindow.new(self)
	add_child(files_window)

	# Enemy turn replay: flying tokens, an input blocker with Skip, and a banner.
	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	blocker = Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	add_child(blocker)
	var skip_button := _button("Skip >>  (Space)", func(): animator.skip = true)
	skip_button.position = Vector2(MARGIN + 8, 960 - MARGIN - 48)
	blocker.add_child(skip_button)
	banner = PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.08, 0.06, 0.05, 0.9)
	bs.border_color = Color("b02020")
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(6)
	bs.set_content_margin_all(14)
	banner.add_theme_stylebox_override("panel", bs)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	banner_label = Label.new()
	banner_label.add_theme_font_size_override("font_size", 26)
	banner_label.add_theme_color_override("font_color", Color("f2ead8"))
	banner.add_child(banner_label)
	add_child(banner)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	return b


func _build_board() -> void:
	for c in board.get_children():
		c.queue_free()
	tile_views.clear()
	for pos in engine.state.all_positions():
		var tv := TileView.new(pos)
		tv.custom_minimum_size = Vector2(TILE, TILE)
		tv.clicked.connect(_on_tile_clicked)
		tv.enemy_icon = _cached_texture("tokens/enemy.png")
		tv.warrior_icon = _cached_texture("tokens/warrior.png")
		board.add_child(tv)
		tile_views.append(tv)


# --- Game flow --------------------------------------------------------------------

func _new_game() -> void:
	var ev := engine.new_game(int(players_spin.value))
	acting = 0
	selected.clear()
	_cancel_target()
	log_view.clear()
	_shown_round = -1
	_build_board()
	_log_events(ev)
	_start_recording()
	_refresh()


func _start_recording() -> void:
	recorder.start(engine.state)
	engine.meta["replay"] = ""


func _undo() -> void:
	if animating or replay_mode:
		return
	var entry := engine.undo()
	if entry.is_empty():
		return
	recorder.undo()
	selected.clear()
	_cancel_target()
	_log("[color=gray]Undone: %s[/color]" % entry["label"])
	_refresh()


func _save() -> void:
	if replay_mode:
		return
	engine.meta["replay"] = recorder.path
	var err := engine.save_to(SAVE_PATH)
	_log("Saved." if err == OK else "[color=red]Save failed (%s).[/color]" % error_string(err))


func _load() -> void:
	if replay_mode:
		exit_replay()
	var err := engine.load_from(SAVE_PATH)
	if err != OK:
		_log("[color=red]Load failed (%s).[/color]" % error_string(err))
		return
	unlimited_check.set_pressed_no_signal(engine.unlimited_undo)
	players_spin.value = engine.state.num_players
	acting = 0
	selected.clear()
	_build_board()
	_log("Loaded.")
	# Carry on the same replay if it's still there, else start one from here.
	if not recorder.resume(engine.meta.get("replay", "")):
		_start_recording()
	_refresh()


func _run(cmd: Command) -> void:
	if animating or replay_mode:
		return
	_cancel_target()
	var r := engine.execute(cmd)
	if not r["ok"]:
		_error(r["error"])
		return
	prompt_label.text = ""
	_log("[b]%s[/b]" % engine.undo_label())
	selected.clear()
	var events: Array = r["events"]
	recorder.step(engine.undo_label(), cmd.player, events, engine.state)
	if animate_enemy_turn and events.any(func(e): return e["type"] == "enemy_phase_started"):
		_log_events(events, false)
		await _replay_enemy_turn(engine.history.peek()["state"].copy(), events)
	else:
		_log_events(events)
	_refresh()


func _replay_enemy_turn(before: GameState, events: Array) -> void:
	animating = true
	blocker.visible = true
	await animator.play(before, events)
	blocker.visible = false
	animating = false


func _error(msg: String) -> void:
	prompt_label.text = msg
	prompt_label.modulate = Color("ff7070")


func _unhandled_input(e: InputEvent) -> void:
	if animating:
		if e is InputEventKey and e.pressed and e.keycode in [KEY_SPACE, KEY_ESCAPE]:
			animator.skip = true
		return
	if e is InputEventKey and e.pressed and e.keycode == KEY_Z and e.ctrl_pressed:
		_undo()
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		_cancel_target()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F11:
		_toggle_fullscreen()


## The layout is fixed at 1600x960 and scaled to fit the window (project stretch
## settings: canvas_items + keep), so fullscreen just makes everything bigger.
func _toggle_fullscreen() -> void:
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


# --- Drawing ----------------------------------------------------------------------

func _refresh() -> void:
	var s := engine.state
	var d := engine.data
	draw_board(s)

	var spawn = d.spawn_per_cell()[s.turn_index]
	for c in status_flow.get_children():
		c.queue_free()
	var phase := _label("Round %d · %s" % [s.round, PHASE_NAMES[s.phase]])
	phase.add_theme_color_override("font_color", Color("e0c080"))
	status_flow.add_child(phase)
	var spawn_label := _label("Next spawn: %s each" % ("—" if spawn == null else str(spawn)))
	spawn_label.tooltip_text = "Enemies placed on every spawn point in the next Enemy Phase"
	spawn_label.mouse_filter = Control.MOUSE_FILTER_PASS
	for chip in [
		StatChip.make("resource", str(s.supply), "Resources left in the shared supply"),
		StatChip.make(_cached_texture("tokens/enemy.png"), "%d/%d" % [s.enemies_on_board(), d.limit("max_enemy_tokens")], "Enemies on the board / token pool"),
		StatChip.make(_cached_texture("tokens/warrior.png"), "%d/%d" % [s.warriors_on_board(), d.limit("max_warrior_tokens")], "Warriors on the board / token pool"),
		StatChip.make(_cached_texture(d.ruins_back()["image"]), str(s.ruins_left()), "Ruins still to explore"),
		StatChip.make(_cached_texture(d.tile("tunnel")["image"]), str(s.open_tunnels()), "Open tunnels"),
	]:
		status_flow.add_child(chip)
	status_flow.add_child(spawn_label)
	if s.result != "":
		_error("%s %s" % ["You win!" if s.result == "won" else "You lose.", s.end_reason])
	_refresh_titles()

	undo_button.disabled = not engine.can_undo()
	if engine.can_undo():
		undo_button.text = "Undo: %s" % engine.undo_label()
	else:
		undo_button.text = "Undo" if engine.undo_label() == "" else "Undo (locked after a reveal)"
	_refresh_players()


# --- Watching replays ------------------------------------------------------------

func enter_replay(file: String) -> void:
	var r := ReplayLog.read(file)
	if r["error"] != "":
		_error(r["error"])
		return
	if not replay_mode:
		_stashed_state = engine.state
		_stashed_history = engine.history.entries.duplicate()
	replay_mode = true
	_cancel_target()
	selected.clear()
	undo_row.visible = false
	replay_bar.visible = true
	log_view.clear()
	_log("[color=#e0c080]Watching %s (%s)[/color]" % [file.get_file(), ", ".join(r["players"])])
	_shown_round = -1
	replay_bar.open(r["frames"])


func exit_replay() -> void:
	if not replay_mode:
		return
	replay_bar.playing = false
	replay_mode = false
	engine.state = _stashed_state
	engine.history.entries = _stashed_history
	replay_bar.visible = false
	undo_row.visible = true
	acting = 0
	selected.clear()
	log_view.clear()
	_log("[color=gray]Back to your game.[/color]")
	_shown_round = -1
	_refresh()


## Shows one recorded frame. append_log: add just this step's lines to the log;
## otherwise rebuild the log from the start up to this frame.
func show_replay_frame(frames: Array, i: int, append_log: bool) -> void:
	var f: Dictionary = frames[i]
	engine.state = f["state"].copy()
	if f["player"] >= 0:
		acting = f["player"]
	if not append_log:
		log_view.clear()
		for j in range(1, i + 1):
			_log_frame(frames[j])
	elif i > 0:
		_log_frame(f)
	_refresh()


func _log_frame(f: Dictionary) -> void:
	_log("[b]%s[/b]" % f["label"])
	_log_events(f["events"], false)


## Plays the enemy turn inside a recorded step, if there is one and animation is on.
func show_replay_step(from: Dictionary, to: Dictionary) -> void:
	if animate_enemy_turn and to["events"].any(func(e): return e["type"] == "enemy_phase_started"):
		await _replay_enemy_turn(from["state"].copy(), to["events"])


## Draws the tiles and turn track from a state: the real one, or the enemy turn
## replay's display copy.
func draw_board(s: GameState) -> void:
	for tv in tile_views:
		var t := s.tile_at(tv.pos)
		var nobles := s.nobles_at(tv.pos).map(func(p): return p.colour)
		tv.details = _tile_details(t, tv.pos)
		tv.show_state(t, _tile_name(t), _texture_for(t), nobles)
		var me := s.players[acting]
		tv.highlight = TileView.NOBLE_COLOURS[me.colour] if me.on_board and me.pos == tv.pos else Color(0, 0, 0, 0)
		tv.queue_redraw()
	track_view.show_index(s.turn_index, engine.data.spawn_per_cell()[s.turn_index])


## Shows a step of the enemy turn over the board, at the top or bottom edge,
## whichever is further from the tile the step is about.
func show_banner(text: String, focus: Vector2i = PlayerState.NO_TILE) -> void:
	banner_label.text = text
	banner.visible = true
	banner.reset_size()
	var r := board.get_global_rect()
	var at_bottom := focus != PlayerState.NO_TILE and focus.y <= 1
	var y := r.end.y - banner.size.y - 24 if at_bottom else r.position.y + 24
	banner.position = Vector2(r.get_center().x - banner.size.x / 2, y)


func hide_banner() -> void:
	banner.visible = false


## Flies enemy tokens from tile to tile, all at once. moves: enemy_moved events.
func fly_enemies(moves: Array, seconds: float) -> void:
	var icon := _cached_texture("tokens/enemy.png")
	var tween := create_tween().set_parallel(true)
	var sprites := []
	for m in moves:
		var from: TileView = tile_views[m["from"].y * 5 + m["from"].x]
		var to: TileView = tile_views[m["to"].y * 5 + m["to"].x]
		# Drawn by the same function as the board's tokens, and slid from exactly
		# where the stack was drawn to where it will be drawn: no jumps.
		var token := Control.new()
		token.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var count := int(m["count"])
		token.draw.connect(func(): TileView.draw_token(token, Vector2.ZERO, TileView.ENEMY_COLOUR, "E", count, icon))
		token.position = fx_layer.get_global_transform().affine_inverse() * from.enemy_anchor()
		var end := fx_layer.get_global_transform().affine_inverse() * to.enemy_anchor()
		fx_layer.add_child(token)
		sprites.append(token)
		tween.tween_property(token, "position", end, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	for t in sprites:
		t.queue_free()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		animate_enemy_turn = bool(cfg.get_value("ui", "animate_enemy_turn", true))
		anim_speed = clampf(float(cfg.get_value("ui", "animation_speed", 1.0)), SPEED_MIN, SPEED_MAX)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("ui", "animate_enemy_turn", animate_enemy_turn)
	cfg.set_value("ui", "animation_speed", anim_speed)
	cfg.save(settings_path)


func set_anim_speed(v: float) -> void:
	anim_speed = clampf(v, SPEED_MIN, SPEED_MAX)
	_update_speed_label()
	_save_settings()


func _update_speed_label() -> void:
	speed_label.text = "%s×  (%.2f s per tile)" % [str(anim_speed), scaled(EnemyTurnAnimator.STEP_SECONDS)]
	var tip := "Animation speed %s×: %.2f s per tile of enemy movement; every other pause in the enemy turn and replays scales the same way." % [
		str(anim_speed), scaled(EnemyTurnAnimator.STEP_SECONDS)]
	speed_label.tooltip_text = tip
	speed_label.mouse_filter = Control.MOUSE_FILTER_PASS
	for c in speed_label.get_parent().get_children():
		if c is HSlider:
			c.tooltip_text = tip


## A delay in seconds at the chosen animation speed.
func scaled(seconds: float) -> float:
	return seconds / anim_speed


## Hover text for a tile: its passives as they stand now, and each action with the
## acting player's real numbers.
func _tile_details(t: TileState, pos: Vector2i) -> String:
	var lines := []
	var p := engine.state.players[acting]
	if t.revealed:
		var info := engine.data.tile(t.id)
		var passives: Array = info.get("back_side", {}).get("passives", []) if t.flipped else info["passives"]
		for ps in passives:
			var off: bool = t.is_blocked() and ps["id"] != "garrison"  # R10, R21
			lines.append("%s: %s%s" % [ps["name"], ps["text"], "  (off while blocked)" if off else ""])
	if t.is_blocked():
		lines.append("Blocked by enemies: no actions here.")
	var actions := engine.data.actions_for(t.id, t.revealed, t.flipped)
	if not actions.is_empty():
		lines.append("For %s:" % p.colour)
		for a in actions:
			lines.append("  " + _action_text(p, a, t))
	return "\n".join(lines)


func _tile_name(t: TileState) -> String:
	if not t.revealed:
		return "Ruins"
	var info := engine.data.tile(t.id)
	if t.flipped:
		return info.get("back_side", {}).get("name", "Gate Secured!" if t.id == "city_gate" else info["name"])
	return info["name"]


func _texture_for(t: TileState) -> Texture2D:
	var rel: String
	if not t.revealed:
		rel = engine.data.ruins_back()["image"]
	else:
		var info := engine.data.tile(t.id)
		rel = info["back"] if t.flipped else info["image"]
	return _cached_texture(rel)


func _cached_texture(rel: String) -> Texture2D:
	if not textures.has(rel):
		textures[rel] = _load_texture("res://assets/" + rel)
	return textures[rel]


## Uses the imported resource if there is one, else reads the raw file. Null if missing.
static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			return ImageTexture.create_from_image(img)
	return null


func _refresh_players() -> void:
	for c in players_box.get_children():
		c.queue_free()
	var s := engine.state
	var new_roll := s.round != _shown_round
	_shown_round = s.round
	for p in s.players:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("2c2824") if p.index != acting else Color("3d3630")
		style.border_color = TileView.NOBLE_COLOURS[p.colour]
		style.set_border_width_all(3 if p.index == acting else 1)
		style.set_content_margin_all(8)
		panel.add_theme_stylebox_override("panel", style)
		players_box.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)

		var head := HBoxContainer.new()
		box.add_child(head)
		var name_button := Button.new()
		name_button.text = p.colour + ("  (acting)" if p.index == acting else "")
		name_button.flat = true
		name_button.add_theme_color_override("font_color", TileView.NOBLE_COLOURS[p.colour])
		name_button.pressed.connect(_set_acting.bind(p.index))
		head.add_child(name_button)
		var stats := HFlowContainer.new()
		stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_theme_constant_override("h_separation", 12)
		head.add_child(stats)
		_fill_player_stats(stats, p)
		for t in p.titles:
			var thumb := CardThumb.make(_cached_texture(engine.data.title(t)["image"]), 34, _title_tip(t))
			head.add_child(thumb)
		var done := Button.new()
		done.text = "Done" if not p.done else "(done)"
		done.disabled = replay_mode or engine.check(MarkDoneCommand.new(p.index)) != ""
		done.pressed.connect(func(): _run(MarkDoneCommand.new(p.index)))
		head.add_child(done)

		var tray := HBoxContainer.new()
		box.add_child(tray)
		if not p.on_board:
			tray.add_child(_label("Wounded: misses this Dwarf Phase" if p.skip_phases == 0 else "Wounded: misses the next Dwarf Phase"))
			continue
		for i in p.dice.size():
			var die: Dictionary = p.dice[i]
			var dv := DiceView.new()
			dv.setup(die["type"], int(die["value"]), die["used"] or p.done,
				p.index == acting and selected.has(int(die["id"])),
				TileView.NOBLE_COLOURS[p.colour], hash([p.index, die["id"], s.round]))
			dv.picked.connect(_toggle_die.bind(p.index, int(die["id"])))
			if p.has_title("master_miner"):
				var bonus := engine.data.title_ability_by_effect("master_miner", "die_bonus_at_tile")
				dv.tooltip_text += "; counts as %d at a Mine (Master Miner)" % (int(die["value"]) + int(bonus["value"]))
			tray.add_child(dv)
			if new_roll:
				dv.roll_in(0.05 * i + 0.1 * p.index)
		if p.index == acting and not selected.is_empty():
			var total := 0
			for id in selected:
				total += int(p.die_by_id(id)["value"])
			tray.add_child(_label("  selected: %d" % total))


## Resources, moves, reserve dice and next-round dice as icon chips.
func _fill_player_stats(stats: HFlowContainer, p: PlayerState) -> void:
	var colour: Color = TileView.NOBLE_COLOURS[p.colour]
	stats.add_child(StatChip.make("resource", str(p.resources), "Resources"))
	if p.on_board:
		var allowance := engine.rules.movement_allowance(p)
		var parts := engine.rules.movement_parts(p).map(func(x): return "%d %s" % [x[1], x[0]])
		var tip := "Moves left: %d of %d this round (%s)" % [allowance - p.moves_used, allowance, " + ".join(parts)]
		if engine.rules.is_lost(engine.state, p):
			tip += ". Lost in the Empty Halls: use Discover the Path to leave"
		stats.add_child(StatChip.make("moves", "%d/%d" % [allowance - p.moves_used, allowance], tip))
	var reserve := HBoxContainer.new()
	reserve.add_theme_constant_override("separation", 6)
	reserve.tooltip_text = "Reserve: dice not in your active pool yet"
	reserve.mouse_filter = Control.MOUSE_FILTER_PASS
	for t in ["d4", "d6", "d8"]:
		var n := int(p.reserve.get(t, 0))
		if n > 0:
			reserve.add_child(StatChip.make(_mini_die(t, colour.darkened(0.25), p.index), "×%d" % n, "%d %s in reserve" % [n, t]))
	if reserve.get_child_count() > 0:
		stats.add_child(reserve)
	for d in p.pending:
		stats.add_child(StatChip.make(_mini_die(d["type"], colour, p.index), "+", "%s joins your pool next round" % d["type"]))


func _mini_die(type: String, colour: Color, seed_key: int) -> DiceView:
	var dv := DiceView.new(32)
	dv.setup_blank(type, colour, hash([type, seed_key]))
	return dv


## Hover text for a title card, from the acting player's point of view.
func _title_tip(id: String) -> String:
	var s := engine.state
	var info := engine.data.title(id)
	var me := s.players[acting]
	var holder := s.title_holder(id)
	var lines := [info["name"]]
	var claim := {}
	for a in engine.data.tile(info["claimed_at"])["actions"]:
		if a["effect"] == "gain_title" and a["title"] == id:
			claim = a
	var where := "Claimed at the %s (%d+)" % [engine.data.tile(info["claimed_at"])["name"],
		engine.rules.action_terms(me, claim, null)["min"]]
	if holder == acting:
		lines.append("Held by you (%s)." % me.colour)
	elif holder >= 0:
		lines.append("Held by %s. %s. %s must agree to hand it over." % [s.players[holder].colour, where, s.players[holder].colour])
	else:
		lines.append(where + ".")
	if holder != acting and me.titles.size() >= engine.data.titles_per_player(s.num_players):
		lines.append("Taking it returns your %s." % " or ".join(me.titles.map(func(t): return engine.data.title(t)["name"])))
	var holder_p: PlayerState = me if holder < 0 else s.players[holder]
	for ab in info["abilities"]:
		if ab["type"] == "action":
			lines.append("  " + _action_text(holder_p, ab.merged({"name": String(ab["id"]).capitalize()}), null))
	return "\n".join(lines)


## The six title cards: unclaimed ones bright, held ones dimmed with the holder's colour.
func _refresh_titles() -> void:
	for c in titles_grid.get_children():
		c.queue_free()
	var s := engine.state
	for id in engine.data.title_ids():
		var info := engine.data.title(id)
		var holder := s.title_holder(id)
		var thumb := CardThumb.make(_cached_texture(info["image"]), 90, _title_tip(id))
		if holder >= 0:
			thumb.modulate = Color(1, 1, 1, 0.55)
			thumb.border = TileView.NOBLE_COLOURS[s.players[holder].colour]
			thumb.caption = s.players[holder].colour
		titles_grid.add_child(thumb)


func _set_acting(i: int) -> void:
	if i != acting:
		acting = i
		selected.clear()
	_refresh()


func _toggle_die(on: bool, player: int, id: int) -> void:
	if replay_mode:
		_refresh()
		return
	if player != acting:
		acting = player
		selected.clear()
	if on and not selected.has(id):
		selected.append(id)
	elif not on:
		selected.erase(id)
	_refresh()


# --- Tile menu ------------------------------------------------------------------------

func _on_tile_clicked(pos: Vector2i) -> void:
	if animating or replay_mode:
		return
	if target_step.is_valid():
		var step := target_step
		target_step = Callable()
		step.call(pos)
		return
	var s := engine.state
	if s.is_over():
		return
	var p := s.players[acting]
	menu.clear()
	menu_actions.clear()
	menu.add_separator("%s at %s: %s" % [p.colour, MoveCommand._pos_name(pos), _tile_name(s.tile_at(pos))])

	if p.on_board and GameState.is_adjacent(p.pos, pos):
		var max_carry := mini(s.tile_at(p.pos).warriors, engine.data.carry_limit(s.num_players))
		for n in range(0, max_carry + 1):
			_menu_item("Move here" if n == 0 else "Move here carrying %d warrior%s" % [n, "" if n == 1 else "s"],
				MoveCommand.new(acting, pos, n))
	if p.has_title("master_miner") and p.on_board and pos != p.pos:
		_menu_item("Ride the minecart here", MoveCommand.new(acting, pos, 0, true))

	if p.on_board and GameState.is_own_or_adjacent(p.pos, pos):
		var t := s.tile_at(pos)
		for a in engine.data.actions_for(t.id, t.revealed, t.flipped):
			_action_item(pos, a)
		if t.enemies > 0:
			if selected.size() == 1:
				_menu_item("Noble Combat (single die 6+)", NobleCombatCommand.new(acting, selected[0], pos))
			else:
				_add_entry("Noble Combat (single die 6+) — select exactly one die", true, func(): pass)
		for title in p.titles:
			for a in engine.data.title(title)["abilities"]:
				if a["type"] == "action":
					_title_item(pos, a)

	if menu.item_count <= 1:
		_add_entry("Nothing to do here for %s" % p.colour, true, func(): pass)
	menu.reset_size()
	menu.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i.ZERO))


## "Expedition (3+, free) · Messenger: spawns 1 (6 on an Encampment)": the numbers
## this player really needs, from Rules.action_terms, with why they differ from the card.
func _action_text(p: PlayerState, a: Dictionary, tile: TileState) -> String:
	var terms := engine.rules.action_terms(p, a, tile)
	var t := "%s (%d+" % [a.get("name", String(a["id"]).capitalize()), terms["min"]]
	if terms["cost"] > 0:
		t += ", %d res" % terms["cost"]
	elif int(a.get("cost", 0)) > 0:
		t += ", free"
	t += ")"
	if not terms["notes"].is_empty():
		t += " · " + "; ".join(terms["notes"])
	return t


## Adds a menu entry; disabled with the reason if the command isn't legal.
## Errors starting "Choose" are about follow-up picks, which come after the menu.
func _menu_item(text: String, cmd: Command, on_pick: Callable = Callable()) -> void:
	var err := engine.check(cmd)
	var blocked := err != "" and not err.begins_with("Choose")
	_add_entry(text if not blocked else "%s — %s" % [text, err], blocked,
		on_pick if on_pick.is_valid() else func(): _run(cmd))


## Adds a menu item whose id is its index in menu_actions. Separators take ids of
## their own, so ids must be set explicitly rather than left to Godot.
func _add_entry(text: String, disabled: bool, action: Callable) -> void:
	menu.add_item(text, menu_actions.size())
	menu.set_item_disabled(menu.item_count - 1, disabled)
	menu_actions.append(action)


func _action_item(pos: Vector2i, a: Dictionary) -> void:
	var dice := selected.duplicate()
	# Check a title claim as if the holder agrees; the dialog asks them afterwards.
	var probe := {"holder_agreed": true} if a["effect"] == "gain_title" else {}
	var cmd := UseActionCommand.new(acting, pos, a["id"], dice, probe)
	var make := func(params: Dictionary) -> Command: return UseActionCommand.new(acting, pos, a["id"], dice, params)
	_menu_item(_action_text(engine.state.players[acting], a, engine.state.tile_at(pos)), cmd,
		func(): _collect_params(a, pos, make))


func _title_item(pos: Vector2i, a: Dictionary) -> void:
	var dice := selected.duplicate()
	var make := func(params: Dictionary) -> Command: return TitleActionCommand.new(acting, a["id"], dice, params)
	var params := {"target": pos} if a["effect"] == "remove_enemies" else {}
	_menu_item(_action_text(engine.state.players[acting], a, null), make.call(params),
		func(): _collect_params(a, pos, make))


## Gathers whatever extra choices an effect needs (targets, dice, agreement), then runs it.
func _collect_params(a: Dictionary, pos: Vector2i, make: Callable) -> void:
	var s := engine.state
	var p := s.players[acting]
	match a["effect"]:
		"remove_enemies":
			if a.has("range") and a["range"] == "adjacent":
				_ask_tile("Click the tile to throw axes at.", func(t): _run(make.call({"target": t})))
			else:
				_run(make.call({"target": pos}))
		"move_one_enemy":
			_ask_tile("Click the tile to move an enemy from.", func(from):
				_ask_tile("Click where it goes (up to %d tiles)." % int(a["range_tiles"]),
					func(to): _run(make.call({"from": from, "to": to}))))
		"swap_adjacent_tiles":
			_ask_tile("Click a tile next to %s to swap with it." % MoveCommand._pos_name(pos),
				func(b): _run(make.call({"a": pos, "b": b})))
		"upgrade_die":
			var options := p.dice.filter(func(d): return a["upgrades"].has(d["type"]))
			_choose("Promote which die?", options.map(func(d): return "%s (showing %d)" % [d["type"], d["value"]]),
				func(i): _run(make.call({"die": int(options[i]["id"])})))
		"gain_title":
			_claim_title(a, make)
		_:
			_run(make.call({}))


func _claim_title(a: Dictionary, make: Callable) -> void:
	var s := engine.state
	var p := s.players[acting]
	var params := {}
	var finish := func():
		if p.titles.size() >= engine.data.titles_per_player(s.num_players) and p.titles.size() > 1:
			_choose("Return which title?", p.titles.map(func(t): return engine.data.title(t)["name"]),
				func(i): params["replace_title"] = p.titles[i]; _run(make.call(params)))
		else:
			_run(make.call(params))
	var holder := s.title_holder(a["title"])
	if holder >= 0 and holder != acting:
		confirm.dialog_text = "%s holds %s. Do they agree to hand it over?" % [
			s.players[holder].colour, engine.data.title(a["title"])["name"]]
		confirm_action = func(): params["holder_agreed"] = true; finish.call()
		confirm.popup_centered()
	else:
		finish.call()


func _ask_tile(text: String, then: Callable) -> void:
	prompt_label.text = text
	prompt_label.modulate = Color("ffe08a")
	cancel_button.visible = true
	target_step = func(pos):
		cancel_button.visible = false
		then.call(pos)


func _cancel_target() -> void:
	target_step = Callable()
	if cancel_button:
		cancel_button.visible = false
	if prompt_label:
		prompt_label.text = ""


func _choose(title: String, options: Array, then: Callable) -> void:
	choice_menu.clear()
	choice_actions.clear()
	choice_menu.add_separator(title)
	for i in options.size():
		choice_menu.add_item(options[i], choice_actions.size())
		choice_actions.append(then.bind(i))
	choice_menu.reset_size()
	# Open once the menu that led here has finished closing.
	choice_menu.popup_centered.call_deferred()


# --- Log ----------------------------------------------------------------------------------

func _log(line: String) -> void:
	log_view.append_text(line + "\n")


func _colour(i: int) -> String:
	return engine.state.players[i].colour


func _log_events(events: Array, pulse: bool = true) -> void:
	for e in events:
		var line := _event_text(e)
		if line != "":
			_log("  " + line)
		if not pulse:
			continue
		for key in ["pos", "to"]:
			if e.has(key) and e[key] is Vector2i and engine.state.in_bounds(e[key]):
				tile_views[e[key].y * engine.state.size + e[key].x].pulse()


func _event_text(e: Dictionary) -> String:
	var at := func(k): return MoveCommand._pos_name(e[k])
	match e["type"]:
		"round_started": return "[color=#e0c080]— Round %d —[/color]" % e["round"]
		"dice_rolled": return "%s rolls %s" % [_colour(e["player"]), str(e["values"])]
		"enemy_phase_started": return "[color=#e08080]Enemy Phase[/color]"
		"enemy_die_rolled":
			return "Enemy die: %d%s" % [e["value"], "" if not e.has("direction") else " (%s)" % e["direction"]]
		"enemy_surge": return "[color=red]ENEMY SURGE! Everything moves %s[/color]" % e["direction"]
		"enemies_spawned": return "%d enem%s appear at %s" % [e["count"], "y" if e["count"] == 1 else "ies", at.call("pos")]
		"enemies_removed": return "%d enem%s removed at %s" % [e["count"], "y" if e["count"] == 1 else "ies", at.call("pos")]
		"tunnel_created": return "[color=red]Enemies turn the %s at %s into a tunnel[/color]" % [engine.data.tile(e["was"])["name"], at.call("pos")]
		"tile_flipped": return "Ruins at %s: %s" % [at.call("pos"), engine.data.tile(e["tile"])["name"]]
		"tunnel_collapsed": return "Tunnel at %s collapsed" % at.call("pos")
		"combat": return "Warriors fight at %s (%d each side fall)" % [at.call("pos"), e["count"]]
		"noble_wounded":
			return "[color=red]%s is wounded%s[/color]" % [_colour(e["player"]), " but Tough" if e["tough"] else ""]
		"noble_revived": return "%s returns to the Hearth" % _colour(e["player"])
		"track_advanced": return "Turn marker moves to %d" % e["index"]
		"title_gained": return "%s becomes %s" % [_colour(e["player"]), engine.data.title(e["title"])["name"]]
		"title_returned": return "%s returns %s" % [_colour(e["player"]), engine.data.title(e["title"])["name"]]
		"resources_gained": return "%s gains %d resource%s" % [_colour(e["player"]), e["amount"], "" if e["amount"] == 1 else "s"]
		"warriors_placed": return "%d warrior%s at %s" % [e["count"], "" if e["count"] == 1 else "s", at.call("pos")]
		"die_recruited": return "%s recruits a %s (from next round)" % [_colour(e["player"]), e["die"]]
		"die_promoted": return "%s promotes a %s to a %s (from next round)" % [_colour(e["player"]), e["from"], e["to"]]
		"path_discovered": return "%s finds the path" % _colour(e["player"])
		"tiles_swapped": return "Tiles %s and %s swapped" % [at.call("a"), at.call("b")]
		"game_over": return "[b][color=%s]%s[/color][/b]" % ["#80ff80" if e["result"] == "won" else "red", e["reason"]]
	return ""

extends Control
## Hot-seat game screen. Draws GameState and turns clicks into commands; it never
## edits state directly. Pick whose dice to use by clicking in that player's tray,
## then click a tile for the moves and actions available there.

const SAVE_PATH := "user://save.json"
const PHASE_NAMES := ["Dwarf Phase", "Enemy Phase", "Game over"]

var engine := GameEngine.new()
var acting: int = 0
var selected: Array = []           # die ids of the acting player
var target_step: Callable          # set while waiting for a tile click: func(pos)
var textures := {}
var _shown_round := -1             # dice tumble when a new round's roll is first shown

var tile_views: Array[TileView] = []
var board: GridContainer
var status_label: Label
var prompt_label: Label
var cancel_button: Button
var undo_button: Button
var unlimited_check: CheckBox
var players_spin: SpinBox
var players_box: VBoxContainer
var track_label: RichTextLabel
var log_view: RichTextLabel
var menu: PopupMenu
var menu_actions: Array[Callable] = []
var confirm: ConfirmationDialog
var confirm_action: Callable


func _ready() -> void:
	_build_ui()
	_new_game()


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
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	top.add_child(_label("Players"))
	players_spin = SpinBox.new()
	players_spin.min_value = 1
	players_spin.max_value = 6
	players_spin.value = 2
	top.add_child(players_spin)
	top.add_child(_button("New game", _new_game))
	undo_button = _button("Undo", _undo)
	top.add_child(undo_button)
	unlimited_check = CheckBox.new()
	unlimited_check.text = "Unlimited undo"
	unlimited_check.toggled.connect(func(on): engine.unlimited_undo = on; _refresh())
	top.add_child(unlimited_check)
	top.add_child(_button("Save", _save))
	top.add_child(_button("Load", _load))
	top.add_child(_button("Fullscreen (F11)", _toggle_fullscreen))
	status_label = _label("")
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(status_label)

	var prompt_row := HBoxContainer.new()
	root.add_child(prompt_row)
	prompt_label = _label("")
	prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_row.add_child(prompt_label)
	cancel_button = _button("Cancel", _cancel_target)
	cancel_button.visible = false
	prompt_row.add_child(cancel_button)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	board = GridContainer.new()
	board.columns = 5
	board.add_theme_constant_override("h_separation", 4)
	board.add_theme_constant_override("v_separation", 4)
	main.add_child(board)

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(side)
	track_label = RichTextLabel.new()
	track_label.bbcode_enabled = true
	track_label.fit_content = true
	track_label.scroll_active = false
	side.add_child(track_label)
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
	log_view.custom_minimum_size = Vector2(0, 220)
	side.add_child(log_view)

	menu = PopupMenu.new()
	menu.id_pressed.connect(func(id): menu_actions[id].call())
	add_child(menu)
	confirm = ConfirmationDialog.new()
	confirm.confirmed.connect(func(): confirm_action.call())
	add_child(confirm)


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
	_refresh()


func _undo() -> void:
	var entry := engine.undo()
	if entry.is_empty():
		return
	selected.clear()
	_cancel_target()
	_log("[color=gray]Undone: %s[/color]" % entry["label"])
	_refresh()


func _save() -> void:
	var err := engine.save_to(SAVE_PATH)
	_log("Saved." if err == OK else "[color=red]Save failed (%s).[/color]" % error_string(err))


func _load() -> void:
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
	_refresh()


func _run(cmd: Command) -> void:
	_cancel_target()
	var r := engine.execute(cmd)
	if not r["ok"]:
		_error(r["error"])
		return
	prompt_label.text = ""
	_log("[b]%s[/b]" % engine.undo_label())
	_log_events(r["events"])
	selected.clear()
	_refresh()


func _error(msg: String) -> void:
	prompt_label.text = msg
	prompt_label.modulate = Color("ff7070")


func _unhandled_input(e: InputEvent) -> void:
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
	for tv in tile_views:
		var t := s.tile_at(tv.pos)
		var nobles := s.nobles_at(tv.pos).map(func(p): return p.colour)
		tv.show_state(t, _tile_name(t), _texture_for(t), nobles)
		var me := s.players[acting]
		tv.highlight = TileView.NOBLE_COLOURS[me.colour] if me.on_board and me.pos == tv.pos else Color(0, 0, 0, 0)
		tv.queue_redraw()

	var spawn = d.spawn_per_cell()[s.turn_index]
	status_label.text = "Round %d · %s · supply %d · enemies %d/%d · warriors %d/%d · ruins left %d · open tunnels %d" % [
		s.round, PHASE_NAMES[s.phase], s.supply, s.enemies_on_board(), d.limit("max_enemy_tokens"),
		s.warriors_on_board(), d.limit("max_warrior_tokens"), s.ruins_left(), s.open_tunnels()]
	if s.result != "":
		_error("%s %s" % ["You win!" if s.result == "won" else "You lose.", s.end_reason])

	var cells := []
	for i in d.spawn_per_cell().size():
		var v = d.spawn_per_cell()[i]
		var txt := "☠" if v == null else str(v)
		cells.append("[b][bgcolor=#a0302a] %s [/bgcolor][/b]" % txt if i == s.turn_index else " %s " % txt)
	track_label.text = "Turn track (enemies per spawn point):  " + "".join(cells) + \
		("" if spawn == null else "   next spawn: %d each" % spawn)

	undo_button.disabled = not engine.can_undo()
	if engine.can_undo():
		undo_button.text = "Undo: %s" % engine.undo_label()
	else:
		undo_button.text = "Undo" if engine.undo_label() == "" else "Undo (locked after a reveal)"
	_refresh_players()


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
		var info := _label(_player_summary(p))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(info)
		var done := Button.new()
		done.text = "Done" if not p.done else "✓ done"
		done.disabled = engine.check(MarkDoneCommand.new(p.index)) != ""
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
			tray.add_child(dv)
			if new_roll:
				dv.roll_in(0.05 * i + 0.1 * p.index)
		if p.index == acting and not selected.is_empty():
			var total := 0
			for id in selected:
				total += int(p.die_by_id(id)["value"])
			tray.add_child(_label("  selected: %d" % total))


func _player_summary(p: PlayerState) -> String:
	var parts := ["res %d" % p.resources]
	if p.on_board:
		parts.append("moves %d/%d" % [p.moves_used, engine.rules.movement_allowance(p)])
	if not p.titles.is_empty():
		parts.append(", ".join(p.titles.map(func(t): return engine.data.title(t)["name"])))
	parts.append("reserve " + " ".join(p.reserve.keys().map(func(k): return "%s×%d" % [k, p.reserve[k]])))
	if not p.pending.is_empty():
		parts.append("next round +" + ",".join(p.pending.map(func(d): return d["type"])))
	return " · ".join(parts)


func _set_acting(i: int) -> void:
	if i != acting:
		acting = i
		selected.clear()
	_refresh()


func _toggle_die(on: bool, player: int, id: int) -> void:
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
				menu.add_item("Noble Combat (single die 6+) — select exactly one die")
				menu.set_item_disabled(menu.item_count - 1, true)
				menu_actions.append(func(): pass)
		for title in p.titles:
			for a in engine.data.title(title)["abilities"]:
				if a["type"] == "action":
					_title_item(pos, a)

	if menu.item_count <= 1:
		menu.add_item("Nothing to do here for %s" % p.colour)
		menu.set_item_disabled(menu.item_count - 1, true)
		menu_actions.append(func(): pass)
	menu.reset_size()
	menu.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i.ZERO))


func _action_text(a: Dictionary) -> String:
	var t := "%s (%d+" % [a["name"], int(a["min"])]
	if int(a.get("cost", 0)) > 0:
		t += ", %d res" % int(a["cost"])
	return t + ")"


## Adds a menu entry; disabled with the reason if the command isn't legal.
## Errors starting "Choose" are about follow-up picks, which come after the menu.
func _menu_item(text: String, cmd: Command, on_pick: Callable = Callable()) -> void:
	var err := engine.check(cmd)
	var blocked := err != "" and not err.begins_with("Choose")
	menu.add_item(text if not blocked else "%s — %s" % [text, err])
	menu.set_item_disabled(menu.item_count - 1, blocked)
	menu_actions.append(on_pick if on_pick.is_valid() else func(): _run(cmd))


func _action_item(pos: Vector2i, a: Dictionary) -> void:
	var dice := selected.duplicate()
	# Check a title claim as if the holder agrees; the dialog asks them afterwards.
	var probe := {"holder_agreed": true} if a["effect"] == "gain_title" else {}
	var cmd := UseActionCommand.new(acting, pos, a["id"], dice, probe)
	var make := func(params: Dictionary) -> Command: return UseActionCommand.new(acting, pos, a["id"], dice, params)
	_menu_item(_action_text(a), cmd, func(): _collect_params(a, pos, make))


func _title_item(pos: Vector2i, a: Dictionary) -> void:
	var dice := selected.duplicate()
	var make := func(params: Dictionary) -> Command: return TitleActionCommand.new(acting, a["id"], dice, params)
	var params := {"target": pos} if a["effect"] == "remove_enemies" else {}
	_menu_item(_action_text({"name": a["id"].capitalize(), "min": a["min"]}), make.call(params),
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
	menu.clear()
	menu_actions.clear()
	menu.add_separator(title)
	for i in options.size():
		menu.add_item(options[i])
		menu_actions.append(then.bind(i))
	menu.reset_size()
	menu.popup_centered()


# --- Log ----------------------------------------------------------------------------------

func _log(line: String) -> void:
	log_view.append_text(line + "\n")


func _colour(i: int) -> String:
	return engine.state.players[i].colour


func _log_events(events: Array) -> void:
	for e in events:
		var line := _event_text(e)
		if line != "":
			_log("  " + line)
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
		"track_advanced": return "Turn marker → %d" % e["index"]
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

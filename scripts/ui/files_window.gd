class_name FilesWindow
extends AcceptDialog
## Everything the game keeps, in one place, and ways to get it in and out:
## the current game (save and download, load from a file) and every recorded
## replay (watch, download, delete). Works the same in the browser, where
## there's no folder to open.

var main  # the main screen (untyped: main.gd has no class_name)
var _list: VBoxContainer


func _init(screen) -> void:
	main = screen
	title = "Files"
	ok_button_text = "Close"
	min_size = Vector2i(760, 560)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)


func open() -> void:
	refresh()
	popup_centered()


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()

	_heading("This game")
	var game := HBoxContainer.new()
	_list.add_child(game)
	game.add_child(_button("Save and download", main.download_game,
		"Saves the game in this %s and gives you a copy of the file." % ("browser" if FileBridge.is_web() else "computer")))
	game.add_child(_button("Load a game from file...", main.load_game_from_file,
		"Continue a game saved with \"Save and download\", e.g. from another device."))
	_note("Save and Load in the top bar use a single slot kept %s." % (
		"in this browser's storage" if FileBridge.is_web() else "in the game's user folder"))

	_list.add_child(HSeparator.new())
	_heading("Replays")
	var top := HBoxContainer.new()
	_list.add_child(top)
	top.add_child(_button("Open a replay from file...", main.open_replay_file,
		"Watch a .%s file someone shared with you." % ReplayLog.EXTENSION))
	if not FileBridge.is_web():
		top.add_child(_button("Open the replays folder", main.open_replays_folder, ""))

	var files := ReplayLog.list([main.recorder.dir, FileBridge.OPENED_DIR])
	if files.is_empty():
		_note("No replays yet. Every game is recorded as soon as someone takes an action.")
	for path in files:
		_replay_row(path)


func _replay_row(path: String) -> void:
	var info := ReplayLog.summary(path)
	var current: bool = path == main.recorder.path
	var row := HBoxContainer.new()
	_list.add_child(row)
	var text := "%s · %s · %d step%s" % [_when(info["started"], path), ", ".join(info["players"]),
		info["steps"], "" if info["steps"] == 1 else "s"]
	if current:
		text += "  (this game)"
	elif path.begins_with(FileBridge.OPENED_DIR):
		text += "  (opened)"
	var label := Label.new()
	label.text = text
	label.tooltip_text = path.get_file()
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	row.add_child(label)
	row.add_child(_button("Watch", func(): hide(); main.enter_replay(path), ""))
	row.add_child(_button("Download", func(): main.file_bridge.export_file(path, path.get_file()), ""))
	var del := _button("Delete", func(): _delete(path), "Can't delete the replay of the game in progress." if current else "")
	del.disabled = current
	row.add_child(del)


func _delete(path: String) -> void:
	DirAccess.remove_absolute(path)
	refresh()


## "2026-09-27 16:34" from the header, or from the file name for old files.
static func _when(started: String, path: String) -> String:
	if started != "":
		return started.replace("T", " ").substr(0, 16)
	return path.get_file().get_basename().replace("_", " ")


func _heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("e0c080"))
	l.add_theme_font_size_override("font_size", 18)
	_list.add_child(l)


func _note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = Color(1, 1, 1, 0.65)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(l)


func _button(text: String, on_press: Callable, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(on_press)
	return b

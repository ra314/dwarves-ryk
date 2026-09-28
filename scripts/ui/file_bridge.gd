class_name FileBridge
extends Node
## Moving files in and out of the game, the same way on desktop and in the browser.
## Desktop: Godot file dialogs. Browser (no file system): the browser's file
## picker to open, a download to save, and ?replay=<url> links.

## Replays opened from outside are copied here so they can be read like any other.
const OPENED_DIR := "user://replays/opened"

var _dialog: FileDialog
var _on_picked: Callable      # desktop: (file_name, text) after an open
var _export_from: String = "" # desktop: the user:// file a save-as copies
## JavaScript callbacks must stay referenced or the browser drops them.
static var _js_callback: JavaScriptObject


func _ready() -> void:
	_dialog = FileDialog.new()
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.file_selected.connect(_on_dialog_file)
	add_child(_dialog)


static func is_web() -> bool:
	return OS.has_feature("web")


## Lets the player choose a file ending in .<extension>; calls on_loaded(file_name, text).
func pick(title: String, extension: String, on_loaded: Callable) -> void:
	if is_web():
		_expose(on_loaded)
		JavaScriptBridge.eval("""
			(() => {
				const input = document.createElement('input');
				input.type = 'file';
				input.accept = '.%s';
				input.onchange = () => {
					const f = input.files[0];
					if (f) f.text().then(t => window.godotFileLoaded(f.name, t));
				};
				input.click();
			})();
		""" % extension, true)
		return
	_on_picked = on_loaded
	_export_from = ""
	_dialog.title = title
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.filters = PackedStringArray(["*.%s" % extension])
	_dialog.popup_centered_ratio(0.7)


## Gives the player a copy of a user:// file: a download in the browser, a
## save-as dialog on desktop.
func export_file(path: String, suggested_name: String) -> void:
	if is_web():
		JavaScriptBridge.download_buffer(FileAccess.get_file_as_bytes(path), suggested_name, "application/octet-stream")
		return
	_on_picked = Callable()
	_export_from = path
	_dialog.title = "Save a copy"
	_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_dialog.filters = PackedStringArray(["*.%s" % suggested_name.get_extension()])
	_dialog.current_file = suggested_name
	_dialog.popup_centered_ratio(0.7)


func _on_dialog_file(chosen: String) -> void:
	if _export_from != "":
		var out := FileAccess.open(chosen, FileAccess.WRITE)
		if out:
			out.store_buffer(FileAccess.get_file_as_bytes(_export_from))
		_export_from = ""
	elif _on_picked.is_valid():
		_on_picked.call(chosen.get_file(), FileAccess.get_file_as_string(chosen))


## Browser only: if the page was opened with ?replay=<url>, fetches it.
func open_from_url_param(on_loaded: Callable) -> void:
	if not is_web():
		return
	var url = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('replay')", true)
	if url == null or str(url) == "":
		return
	_expose(on_loaded)
	JavaScriptBridge.eval("""
		(() => {
			const url = new URLSearchParams(window.location.search).get('replay');
			fetch(url).then(r => r.ok ? r.text() : Promise.reject(r.status))
				.then(t => window.godotFileLoaded(url.split('/').pop() || 'shared.dwreplay', t))
				.catch(e => console.error('Could not load replay', url, e));
		})();
	""", true)


## Keeps a copy of a replay opened from outside, so it's listed and can be read.
static func store_opened(file_name: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(OPENED_DIR)
	var safe := file_name.get_file().validate_filename()
	if not safe.ends_with("." + ReplayLog.EXTENSION):
		safe += "." + ReplayLog.EXTENSION
	var path := "%s/%s" % [OPENED_DIR, safe]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	return path


static func _expose(on_loaded: Callable) -> void:
	_js_callback = JavaScriptBridge.create_callback(func(args): on_loaded.call(str(args[0]), str(args[1])))
	JavaScriptBridge.get_interface("window").godotFileLoaded = _js_callback

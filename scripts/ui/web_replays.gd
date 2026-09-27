class_name WebReplays
extends RefCounted
## Browser-only replay helpers. On the web there's no file dialog or folder to
## open, so replays are picked with the browser's file input, saved with a
## download, and can be opened from a link: index.html?replay=<url>.

const IMPORTED_DIR := "user://replays/opened"

## JavaScript callbacks must stay referenced or the browser drops them.
static var _callback: JavaScriptObject


## Asks the browser for a .dwreplay file. on_loaded(file_name, text) runs when read.
static func pick_file(on_loaded: Callable) -> void:
	_expose(on_loaded)
	JavaScriptBridge.eval("""
		(() => {
			const input = document.createElement('input');
			input.type = 'file';
			input.accept = '.dwreplay';
			input.onchange = () => {
				const f = input.files[0];
				if (f) f.text().then(t => window.godotReplayLoaded(f.name, t));
			};
			input.click();
		})();
	""", true)


## If the page was opened with ?replay=<url>, fetches it and calls on_loaded.
static func open_from_url_param(on_loaded: Callable) -> void:
	var url = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('replay')", true)
	if url == null or str(url) == "":
		return
	_expose(on_loaded)
	JavaScriptBridge.eval("""
		(() => {
			const url = new URLSearchParams(window.location.search).get('replay');
			fetch(url).then(r => r.ok ? r.text() : Promise.reject(r.status))
				.then(t => window.godotReplayLoaded(url.split('/').pop() || 'shared.dwreplay', t))
				.catch(e => console.error('Could not load replay', url, e));
		})();
	""", true)


## Saves a recorded replay to the player's downloads.
static func download(path: String) -> void:
	JavaScriptBridge.download_buffer(FileAccess.get_file_as_bytes(path), path.get_file(), "application/x-ndjson")


## Keeps a copy of an opened replay in user:// so it can be read like any other.
static func store(file_name: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(IMPORTED_DIR)
	var safe := file_name.get_file().validate_filename()
	if not safe.ends_with("." + ReplayLog.EXTENSION):
		safe += "." + ReplayLog.EXTENSION
	var path := "%s/%s" % [IMPORTED_DIR, safe]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	return path


static func _expose(on_loaded: Callable) -> void:
	_callback = JavaScriptBridge.create_callback(func(args): on_loaded.call(str(args[0]), str(args[1])))
	JavaScriptBridge.get_interface("window").godotReplayLoaded = _callback

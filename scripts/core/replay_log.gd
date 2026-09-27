class_name ReplayLog
extends RefCounted
## Records a game as it's played, for sharing and watching back.
##
## A replay file (.dwreplay) is JSON Lines, appended as the game goes:
##   {"t": "header", "version": 1, "players": [...colours], "started": "..."}
##   {"t": "start", "state": {...}}                       the board after setup
##   {"t": "step", "label": "Red: Dig (Mine)", "player": 1, "events": [...], "state": {...}}
##   {"t": "undo"}                                        drops the latest step
## Each step stores the state after it, so a replay never re-runs the rules and
## keeps working if the engine changes. Appending keeps saves cheap and a crash
## loses at most the last line.

const VERSION := 1
const DIR := "user://replays"
const EXTENSION := "dwreplay"

var path: String = ""
## Folder new replays go in.
var dir: String = DIR
## Header and setup lines, written with the first step so games nobody played
## (e.g. the one shown at launch) leave no file behind.
var _pending: Array = []


## Begins recording a game whose setup is `state`. The file is created by the
## first step(); until then path is "".
func start(state: GameState) -> void:
	path = ""
	_pending = [
		{"t": "header", "version": VERSION, "started": Time.get_datetime_string_from_system(),
			"players": state.players.map(func(p): return p.colour)},
		{"t": "start", "state": state.to_dict()},
	]


func _create_file(players: int) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	path = "%s/%s_%dp.%s" % [dir, stamp, players, EXTENSION]
	var n := 2
	while FileAccess.file_exists(path):
		path = "%s/%s_%dp_%d.%s" % [dir, stamp, players, n, EXTENSION]
		n += 1
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		path = ""
		return false
	for line in _pending:
		f.store_line(JSON.stringify(line))
	_pending = []
	return true


## Carries on appending to an existing replay (e.g. after loading a save).
func resume(existing: String) -> bool:
	if existing == "" or not FileAccess.file_exists(existing):
		return false
	path = existing
	_pending = []
	return true


func step(label: String, player: int, events: Array, state: GameState) -> void:
	if path == "" and not _pending.is_empty() and not _create_file(state.num_players):
		return
	_append({"t": "step", "label": label, "player": player, "events": encode(events), "state": state.to_dict()})


func undo() -> void:
	_append({"t": "undo"})


func _append(entry: Dictionary) -> void:
	if path == "":
		return
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(entry))


## Reads a replay into frames, with undone steps removed. Frame 0 is the setup.
## Each frame: {"label": String, "player": int, "events": Array, "state": GameState}.
## Returns {"frames": [...], "players": [...], "error": ""}.
static func read(file: String) -> Dictionary:
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null:
		return {"frames": [], "players": [], "error": "Can't open %s" % file}
	var frames := []
	var players := []
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var e = JSON.parse_string(line)
		if not (e is Dictionary):
			continue  # a half-written last line from a crash
		e = decode(e)
		match e.get("t", ""):
			"header":
				players = e.get("players", [])
				if int(e.get("version", 0)) > VERSION:
					return {"frames": [], "players": players, "error": "This replay needs a newer version of the game."}
			"start":
				frames = [{"label": "Game start", "player": -1, "events": [], "state": GameState.from_dict(e["state"])}]
			"step":
				frames.append({"label": e["label"], "player": int(e["player"]), "events": e["events"],
					"state": GameState.from_dict(e["state"])})
			"undo":
				if frames.size() > 1:
					frames.pop_back()
	if frames.is_empty():
		return {"frames": [], "players": players, "error": "No game in %s" % file}
	return {"frames": frames, "players": players, "error": ""}


# --- JSON encoding of events (Vector2i and ints) -------------------------------

static func encode(v):
	if v is Vector2i:
		return {"v2": [v.x, v.y]}
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = encode(v[k])
		return out
	if v is Array:
		return v.map(func(x): return encode(x))
	return v


## Undoes encode(), and turns JSON's floats back into ints.
static func decode(v):
	if v is Dictionary:
		if v.size() == 1 and v.has("v2"):
			return Vector2i(int(v["v2"][0]), int(v["v2"][1]))
		var out := {}
		for k in v:
			out[k] = decode(v[k])
		return out
	if v is Array:
		return v.map(func(x): return decode(x))
	if v is float and v == floorf(v):
		return int(v)
	return v

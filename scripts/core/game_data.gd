class_name GameData
extends RefCounted
## Read-only view of data/game_data.json. Load once and share.

const DEFAULT_PATH := "res://data/game_data.json"

var raw: Dictionary
var limits: Dictionary
var tiles_by_id: Dictionary = {}   # tile id -> tile dictionary
var titles_by_id: Dictionary = {}  # title id -> title dictionary
var rule_decisions: Dictionary
var settings: Dictionary

static var _cached: GameData


static func load_default() -> GameData:
	if _cached == null:
		_cached = GameData.load_from_file(DEFAULT_PATH)
	return _cached


static func load_from_file(path: String) -> GameData:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "Could not read %s" % path)
	var parsed = JSON.parse_string(text)
	assert(parsed is Dictionary, "Bad JSON in %s" % path)
	var data := GameData.new()
	data._init_from(parsed)
	return data


func _init_from(d: Dictionary) -> void:
	d = _ints(d)
	raw = d
	limits = d["limits"]
	rule_decisions = d["rule_decisions"]
	settings = d["settings"]
	for t in d["tiles"]:
		tiles_by_id[t["id"]] = t
	for t in d["titles"]:
		titles_by_id[t["id"]] = t


## JSON has no integer type, so Godot parses every number as a float and it
## prints as "1.0". Every number in the data is a whole number; make them ints.
static func _ints(v):
	if v is float and v == floorf(v):
		return int(v)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _ints(v[k])
		return out
	if v is Array:
		return v.map(func(x): return _ints(x))
	return v


func limit(key: String) -> int:
	return int(limits[key])


func grid_size() -> int:
	return limit("grid_size")


func tile(id: String) -> Dictionary:
	return tiles_by_id[id]


func title(id: String) -> Dictionary:
	return titles_by_id[id]


func title_ids() -> Array:
	return titles_by_id.keys()


func setup_layout() -> Array:
	return raw["setup_grid"]["layout"]


## Tile ids for the ruin stack, one entry per tile, unshuffled.
func ruin_stack() -> Array[String]:
	var stack: Array[String] = []
	for t in raw["tiles"]:
		for i in int(t["in_ruins"]):
			stack.append(t["id"])
	return stack


func ruins_back() -> Dictionary:
	return raw["ruins_back"]


func player_colours() -> Array:
	return raw["players"]["colours"]


func dice_owned() -> Dictionary:
	return raw["players"]["dice_owned"]


func dice_active_at_start() -> Dictionary:
	return raw["players"]["dice_active_at_start"]


func extra_d6_if_players_at_most() -> int:
	return int(raw["players"]["extra_active_d6_if_players_at_most"])


func spawn_per_cell() -> Array:
	return raw["turn_track"]["spawn_per_cell"]


func track_last_index() -> int:
	return spawn_per_cell().size() - 1


func track_start_index(players: int) -> int:
	return int(raw["turn_track"]["start_index_by_players"][str(players)])


func enemy_direction(roll: int) -> String:
	return raw["enemy_movement_die"]["directions"][str(roll)]


func carry_limit(players: int) -> int:
	return int(limits["warrior_carry_limit"][str(players)])


func supply_for(players: int) -> int:
	if players == 1:
		return limit("solo_supply")
	return limit("resources_per_player_in_supply") * players


func starting_resources(players: int) -> int:
	return limit("solo_starting_resources") if players == 1 else limit("starting_resources")


func titles_per_player(players: int) -> int:
	return limit("solo_titles_per_player") if players == 1 else limit("titles_per_player")


## Actions available on a tile in its current state (ruins back, front, or flipped back side).
func actions_for(tile_id: String, revealed: bool, flipped: bool) -> Array:
	if not revealed:
		return ruins_back()["actions"]
	var t := tile(tile_id)
	if flipped:
		return t.get("back_side", {}).get("actions", [])
	return t["actions"]


func find_action(tile_id: String, revealed: bool, flipped: bool, action_id: String) -> Dictionary:
	for a in actions_for(tile_id, revealed, flipped):
		if a["id"] == action_id:
			return a
	return {}


func title_ability(title_id: String, ability_id: String) -> Dictionary:
	for a in title(title_id)["abilities"]:
		if a["id"] == ability_id:
			return a
	return {}


## First title-ability dictionary with the given effect, or {}.
func title_ability_by_effect(title_id: String, effect: String) -> Dictionary:
	for a in title(title_id)["abilities"]:
		if a["effect"] == effect:
			return a
	return {}


static func die_sides(die_type: String) -> int:
	return int(die_type.substr(1))

class_name GameEngine
extends RefCounted
## Owns the game state, validates and applies commands, runs the Enemy Phase when
## every player is done, and keeps the undo history. No Node dependencies.

var data: GameData
## Lives outside GameState so undo never rewinds it (R19).
var rng := RandomNumberGenerator.new()
var rules: Rules
var state: GameState
var history := UndoHistory.new()
var unlimited_undo: bool
## Saved and loaded with the game; the UI keeps the replay file's path here.
var meta: Dictionary = {}


func _init(game_data: GameData = null) -> void:
	data = game_data if game_data != null else GameData.load_default()
	rules = Rules.new(data, rng)
	unlimited_undo = bool(data.settings.get("unlimited_undo", false))


## Sets up a new game and rolls the first Dwarf Phase. seed < 0 picks a random seed.
func new_game(players: int, seed: int = -1) -> Array:
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	history.clear()
	meta = {}
	state = GameState.create(data, players, rng)
	var ev: Array = [Rules.event("game_started", {"players": players})]
	rules.begin_round(state, ev)
	return ev


## Applies a command. Returns {"ok": bool, "error": String, "events": Array}.
func execute(cmd: Command) -> Dictionary:
	var err := cmd.can_apply(state, rules)
	if err != "":
		return {"ok": false, "error": err, "events": []}
	var before := state.copy()
	var label := cmd.describe(state, rules)
	rules.revealed = false
	var ev := cmd.apply(state, rules)
	if state.phase == GameState.Phase.DWARF and rules.all_done(state):
		rules.run_enemy_phase(state, ev)
	history.push(before, rules.revealed, cmd.player, label)
	return {"ok": true, "error": "", "events": ev}


## Error for a command without running it, "" if legal.
func check(cmd: Command) -> String:
	return cmd.can_apply(state, rules)


func can_undo() -> bool:
	return history.can_undo(unlimited_undo)


## Describes what undo would reverse, e.g. "Red: Dig (Mine)", or "".
func undo_label() -> String:
	return history.peek().get("label", "")


## Reverses the most recent command, whoever took it. Returns its history entry, or {}.
func undo() -> Dictionary:
	if not can_undo():
		return {}
	var entry := history.pop()
	state = entry["state"]
	return entry


# --- Save / load -------------------------------------------------------------

func save_to(path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var d := {"version": 1, "state": state.to_dict(), "rng_state": str(rng.state), "rng_seed": str(rng.seed),
		"unlimited_undo": unlimited_undo, "meta": meta}
	f.store_string(JSON.stringify(d))
	return OK


func load_from(path: String) -> Error:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return ERR_FILE_CANT_READ
	var d = JSON.parse_string(text)
	if not (d is Dictionary) or not d.has("state"):
		return ERR_PARSE_ERROR
	state = GameState.from_dict(d["state"])
	rng.seed = int(d["rng_seed"])
	rng.state = int(d["rng_state"])
	unlimited_undo = bool(d.get("unlimited_undo", false))
	meta = d.get("meta", {})
	history.clear()
	return OK


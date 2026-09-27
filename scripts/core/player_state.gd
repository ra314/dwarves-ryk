class_name PlayerState
extends RefCounted
## One player: their Noble, dice, resources and titles.

const NO_TILE := Vector2i(-1, -1)

var index: int
var colour: String
var pos: Vector2i = NO_TILE
var on_board: bool = true

## Wounded Nobles are off the board. skip_phases counts Dwarf Phases still to miss.
var wounded: bool = false
var skip_phases: int = 0

## Active pool. Each die: {"id": int, "type": "d6", "value": int, "used": bool, "title": String}.
## "title" is the title that granted the die, or "".
var dice: Array = []
## Dice that join the active pool at the next roll. Each: {"id", "type", "title"}.
var pending: Array = []
## Dice in reserve, by type: {"d4": 1, "d6": 3, "d8": 2}.
var reserve: Dictionary = {}
var next_die_id: int = 0

var resources: int = 0
var titles: Array = []

## Per-round state.
var moves_used: int = 0
var started_on_hearth: bool = false
var halls_freed: bool = false
var done: bool = false
## Tough (Master of the Guard): enemies already here that wounded this Noble this round.
var tough_tile: Vector2i = NO_TILE
var tough_count: int = 0


func _init(player_index: int = 0, player_colour: String = "") -> void:
	index = player_index
	colour = player_colour


func has_title(title_id: String) -> bool:
	return titles.has(title_id)


func is_out() -> bool:
	return not on_board


func add_die(die_type: String, title_id: String = "") -> Dictionary:
	var die := {"id": next_die_id, "type": die_type, "value": 0, "used": false, "title": title_id}
	next_die_id += 1
	dice.append(die)
	return die


func add_pending(die_type: String, title_id: String = "") -> void:
	pending.append({"id": next_die_id, "type": die_type, "title": title_id})
	next_die_id += 1


func die_by_id(die_id: int) -> Dictionary:
	for d in dice:
		if int(d["id"]) == die_id:
			return d
	return {}


func remove_die(die_id: int) -> void:
	for i in dice.size():
		if int(dice[i]["id"]) == die_id:
			dice.remove_at(i)
			return


func unused_dice() -> Array:
	return dice.filter(func(d): return not d["used"])


func to_dict() -> Dictionary:
	return {
		"index": index, "colour": colour, "pos": [pos.x, pos.y], "on_board": on_board,
		"wounded": wounded, "skip_phases": skip_phases,
		"dice": dice.duplicate(true), "pending": pending.duplicate(true), "reserve": reserve.duplicate(),
		"next_die_id": next_die_id, "resources": resources, "titles": titles.duplicate(),
		"moves_used": moves_used, "started_on_hearth": started_on_hearth, "halls_freed": halls_freed,
		"done": done, "tough_tile": [tough_tile.x, tough_tile.y], "tough_count": tough_count,
	}


static func from_dict(d: Dictionary) -> PlayerState:
	var p := PlayerState.new(int(d["index"]), d["colour"])
	p.pos = Vector2i(int(d["pos"][0]), int(d["pos"][1]))
	p.on_board = d["on_board"]
	p.wounded = d["wounded"]
	p.skip_phases = int(d["skip_phases"])
	p.dice = _int_fields(d["dice"].duplicate(true), ["id", "value"])
	p.pending = _int_fields(d["pending"].duplicate(true), ["id"])
	for k in d["reserve"]:
		p.reserve[k] = int(d["reserve"][k])
	p.next_die_id = int(d["next_die_id"])
	p.resources = int(d["resources"])
	p.titles = d["titles"].duplicate()
	p.moves_used = int(d["moves_used"])
	p.started_on_hearth = d["started_on_hearth"]
	p.halls_freed = d["halls_freed"]
	p.done = d["done"]
	p.tough_tile = Vector2i(int(d["tough_tile"][0]), int(d["tough_tile"][1]))
	p.tough_count = int(d["tough_count"])
	return p


## JSON turns ints into floats; put them back.
static func _int_fields(items: Array, keys: Array) -> Array:
	for item in items:
		for k in keys:
			if item.has(k):
				item[k] = int(item[k])
	return items

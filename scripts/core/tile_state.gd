class_name TileState
extends RefCounted
## One grid space: which tile is there, which side is up, and the tokens on it.

## Tile id from game_data.json. For a face-down ruin this is the hidden tile underneath.
var id: String
## False while the Ruins back is showing.
var revealed: bool = true
## Back side of a revealed tile: Collapsed Tunnel, or Gate Secured.
var flipped: bool = false
var enemies: int = 0
var warriors: int = 0


func _init(tile_id: String = "", is_revealed: bool = true) -> void:
	id = tile_id
	revealed = is_revealed


func is_ruin() -> bool:
	return not revealed


func is_open_tunnel() -> bool:
	return revealed and id == "tunnel" and not flipped


func is_blocked() -> bool:
	return enemies > 0


## The id the players can see: "ruins" for a face-down tile.
func visible_id() -> String:
	return id if revealed else "ruins"


func to_dict() -> Dictionary:
	return {"id": id, "revealed": revealed, "flipped": flipped, "enemies": enemies, "warriors": warriors}


static func from_dict(d: Dictionary) -> TileState:
	var t := TileState.new(d["id"], d["revealed"])
	t.flipped = d["flipped"]
	t.enemies = int(d["enemies"])
	t.warriors = int(d["warriors"])
	return t

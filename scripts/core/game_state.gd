class_name GameState
extends RefCounted
## All mutable game state. Deep-copies via copy(); undo relies on that.
## The random number generator is deliberately not in here (R19).

enum Phase { DWARF, ENEMY, OVER }

var num_players: int
var round: int = 0
var phase: Phase = Phase.DWARF
var turn_index: int = 0
var supply: int = 0
var players: Array[PlayerState] = []
## Row-major, index = y * size + x. Row 0 is north.
var tiles: Array[TileState] = []
var size: int = 5
## "", "won" or "lost".
var result: String = ""
var end_reason: String = ""
var last_enemy_roll: int = 0


## Builds the starting state for a new game (RULES.md §3).
static func create(data: GameData, player_count: int, rng: RandomNumberGenerator) -> GameState:
	assert(player_count >= 1 and player_count <= 6)
	var s := GameState.new()
	s.num_players = player_count
	s.size = data.grid_size()

	# 1. Grid: fixed tiles plus the shuffled ruin stack.
	var stack := data.ruin_stack()
	_shuffle(stack, rng)
	for row in data.setup_layout():
		for id in row:
			if id == "ruins":
				s.tiles.append(TileState.new(stack.pop_back(), false))
			else:
				s.tiles.append(TileState.new(id, true))
	assert(stack.is_empty(), "setup_grid and ruin stack sizes disagree")

	# 4. Supply, before players take their share (R2).
	s.supply = data.supply_for(player_count)

	# 2-4. Nobles, dice, resources.
	var hearth := s.find_tile("hearth")
	var colours := data.player_colours()
	for i in player_count:
		var p := PlayerState.new(i, colours[i])
		p.pos = hearth
		var active: Dictionary = data.dice_active_at_start().duplicate()
		if player_count <= data.extra_d6_if_players_at_most():
			active["d6"] = int(active["d6"]) + 1
		var owned := data.dice_owned()
		for t in owned:
			var n_active := int(active.get(t, 0))
			for k in n_active:
				p.add_die(t)
			p.reserve[t] = int(owned[t]) - n_active
		var take := mini(data.starting_resources(player_count), s.supply)
		p.resources = take
		s.supply -= take
		s.players.append(p)

	# 6. Turn track (R1).
	s.turn_index = data.track_start_index(player_count)
	return s


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	# Fisher-Yates with our own RNG so seeded games are reproducible.
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func copy() -> GameState:
	return GameState.from_dict(to_dict())


# --- Grid helpers ---------------------------------------------------------

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < size and p.y < size


func tile_at(p: Vector2i) -> TileState:
	return tiles[p.y * size + p.x]


func pos_of(index: int) -> Vector2i:
	return Vector2i(index % size, index / size)


func all_positions() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in tiles.size():
		out.append(pos_of(i))
	return out


## Position of the first revealed tile with this id, or NO_TILE.
func find_tile(id: String) -> Vector2i:
	for i in tiles.size():
		if tiles[i].revealed and tiles[i].id == id:
			return pos_of(i)
	return PlayerState.NO_TILE


static func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


static func is_own_or_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) <= 1


func neighbours(p: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		if in_bounds(p + d):
			out.append(p + d)
	return out


func enemies_on_board() -> int:
	var n := 0
	for t in tiles:
		n += t.enemies
	return n


func warriors_on_board() -> int:
	var n := 0
	for t in tiles:
		n += t.warriors
	return n


## Tunnels on the map, open or collapsed.
func tunnel_count() -> int:
	return tiles.filter(func(t): return t.revealed and t.id == "tunnel").size()


func ruins_left() -> int:
	return tiles.filter(func(t): return not t.revealed).size()


func open_tunnels() -> int:
	return tiles.filter(func(t): return t.is_open_tunnel()).size()


func nobles_at(p: Vector2i) -> Array[PlayerState]:
	var out: Array[PlayerState] = []
	for pl in players:
		if pl.on_board and pl.pos == p:
			out.append(pl)
	return out


func title_holder(title_id: String) -> int:
	for p in players:
		if p.has_title(title_id):
			return p.index
	return -1


func is_over() -> bool:
	return phase == Phase.OVER


# --- Serialisation (copying, save/load) -----------------------------------

func to_dict() -> Dictionary:
	return {
		"num_players": num_players, "round": round, "phase": phase, "turn_index": turn_index,
		"supply": supply, "size": size, "result": result, "end_reason": end_reason,
		"last_enemy_roll": last_enemy_roll,
		"players": players.map(func(p): return p.to_dict()),
		"tiles": tiles.map(func(t): return t.to_dict()),
	}


static func from_dict(d: Dictionary) -> GameState:
	var s := GameState.new()
	s.num_players = int(d["num_players"])
	s.round = int(d["round"])
	s.phase = int(d["phase"]) as Phase
	s.turn_index = int(d["turn_index"])
	s.supply = int(d["supply"])
	s.size = int(d["size"])
	s.result = d["result"]
	s.end_reason = d["end_reason"]
	s.last_enemy_roll = int(d["last_enemy_roll"])
	for p in d["players"]:
		s.players.append(PlayerState.from_dict(p))
	for t in d["tiles"]:
		s.tiles.append(TileState.from_dict(t))
	return s

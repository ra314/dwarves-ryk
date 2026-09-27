extends "res://tests/engine_test_base.gd"
## Milestone 3: Enemy Phase, combat, wounds, blocking, surges (§4.2, §5.6, §5.8, §5.10, §5.11).

const MIDDLE := Vector2i(2, 1)
const EMPTY_SPOT := Vector2i(3, 1)


func before_each() -> void:
	new_game(2)


func _enemy_phase() -> Array:
	var ev := []
	engine.rules.run_enemy_phase(s, ev)
	return ev


func _moved_dir(ev: Array) -> String:
	for e in ev:
		if e["type"] == "enemy_die_rolled" and e["reason"] == "movement":
			return e["direction"]
	return ""


# --- Movement -----------------------------------------------------------------

func test_enemies_move_in_rolled_direction() -> void:
	var expect := {1: Vector2i(2, 0), 2: Vector2i(3, 1), 3: Vector2i(2, 2), 4: Vector2i(1, 1)}
	for r in expect:
		new_game(2)
		s.tile_at(MIDDLE).enemies = 2
		engine.rules.move_all_enemies(s, r, [])
		assert_eq(s.tile_at(expect[r]).enemies, 2, "roll %d" % r)
		assert_eq(s.tile_at(MIDDLE).enemies, 0)


func test_enemy_at_edge_moves_opposite_way() -> void:
	s.tile_at(Vector2i(2, 0)).enemies = 1
	engine.rules.move_all_enemies(s, 1, [])  # north, but already on the top row
	assert_eq(s.tile_at(Vector2i(2, 1)).enemies, 1)


# --- Spawning, tunnels, track ---------------------------------------------------

func test_r3_every_spawn_point_gets_full_amount() -> void:
	s.turn_index = 6  # spawn 2
	_enemy_phase()
	assert_eq(s.tile_at(TUNNEL_NW).enemies, 2)
	assert_eq(s.tile_at(TUNNEL_SE).enemies, 2)
	assert_eq(s.tile_at(GATE).enemies, 2)
	assert_eq(s.turn_index, 7)
	assert_eq(s.round, 2)
	assert_eq(s.phase, GameState.Phase.DWARF)


func test_collapsed_tunnel_does_not_spawn() -> void:
	s.tile_at(TUNNEL_NW).flipped = true
	_enemy_phase()
	assert_eq(s.tile_at(TUNNEL_NW).enemies, 0)
	assert_eq(s.enemies_on_board(), 2)


func test_r12_building_becomes_tunnel_and_enemies_stay() -> void:
	s.tile_at(BARRACKS).enemies = 6
	var ev := _enemy_phase()
	assert_eq(s.tile_at(BARRACKS).id, "tunnel")
	assert_true(has_event(ev, "tunnel_created"))
	# 6 kept + 1 at each of 4 spawn points (the new tunnel spawns too).
	assert_eq(s.enemies_on_board(), 6 + 4)


func test_fewer_than_six_enemies_no_tunnel() -> void:
	s.tile_at(BARRACKS).enemies = 5
	_enemy_phase()
	assert_eq(s.tile_at(BARRACKS).id, "barracks")


func test_indestructible_tiles_dont_become_tunnels() -> void:
	s.tile_at(GATE).enemies = 6
	s.tile_at(EMPTY_SPOT).enemies = 6  # face-down ruin
	assert_false(s.tile_at(EMPTY_SPOT).revealed)
	_enemy_phase()
	assert_eq(s.tile_at(GATE).id, "city_gate")
	assert_false(s.tile_at(EMPTY_SPOT).revealed)
	assert_eq(s.tunnel_count(), 2)


func test_sixth_tunnel_loses() -> void:
	for pos in [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4)]:
		set_tile(pos, "tunnel")
	assert_eq(s.tunnel_count(), 5)
	s.tile_at(BARRACKS).enemies = 6
	_enemy_phase()
	assert_eq(s.result, "lost")
	assert_string_contains(s.end_reason, "sixth tunnel")


func test_tunnel_on_hearth_loses() -> void:
	for p in s.players:
		place(p.index, LIVING)
	s.tile_at(HEARTH).enemies = 6
	_enemy_phase()
	assert_eq(s.result, "lost")
	assert_string_contains(s.end_reason, "Hearth")


func test_track_end_loses() -> void:
	s.turn_index = 30
	_enemy_phase()
	assert_eq(s.turn_index, 31)
	assert_eq(s.result, "lost")
	assert_true(s.is_over())


func test_lost_game_refuses_commands() -> void:
	s.turn_index = 30
	_enemy_phase()
	refuse(MarkDoneCommand.new(0), "over")


# --- Combat and wounds --------------------------------------------------------

func test_r5_combat_is_one_for_one_leftovers_stay() -> void:
	s.tile_at(MIDDLE).enemies = 3
	s.tile_at(MIDDLE).warriors = 1
	engine.rules.resolve_board(s, [])
	assert_eq(s.tile_at(MIDDLE).enemies, 2)
	assert_eq(s.tile_at(MIDDLE).warriors, 0)
	s.tile_at(MIDDLE).warriors = 4
	engine.rules.resolve_board(s, [])
	assert_eq(s.tile_at(MIDDLE).enemies, 0)
	assert_eq(s.tile_at(MIDDLE).warriors, 2)


func test_combat_happens_when_enemies_move_in() -> void:
	s.tile_at(MIDDLE).enemies = 1
	s.tile_at(Vector2i(2, 0)).warriors = 1
	engine.rules.move_all_enemies(s, 1, [])
	engine.rules.resolve_board(s, [])
	assert_eq(s.tile_at(Vector2i(2, 0)).enemies, 0)
	assert_eq(s.tile_at(Vector2i(2, 0)).warriors, 0)


func test_warriors_protect_noble() -> void:
	s.tile_at(BARRACKS).enemies = 1
	s.tile_at(HEARTH).warriors = 1
	run(MoveCommand.new(0, BARRACKS, 1))
	assert_true(s.players[0].on_board)
	assert_eq(s.tile_at(BARRACKS).enemies, 0)


func test_moving_onto_enemy_wounds() -> void:
	s.tile_at(BARRACKS).enemies = 1
	var track := s.turn_index
	var r := run(MoveCommand.new(0, BARRACKS))
	assert_true(has_event(r["events"], "noble_wounded"))
	var p := s.players[0]
	assert_false(p.on_board)
	assert_true(p.done)
	assert_eq(s.turn_index, track + 1)
	assert_eq(s.tile_at(BARRACKS).enemies, 1, "the enemy stays")


func test_wounded_noble_skips_next_phase_then_returns_to_hearth() -> void:
	s.tile_at(BARRACKS).enemies = 1
	run(MoveCommand.new(0, BARRACKS))
	var ev := []
	# Round 2: still out.
	engine.rules.begin_round(s, ev)
	assert_false(s.players[0].on_board)
	assert_true(s.players[0].done)
	# Round 3: back on the Hearth.
	engine.rules.begin_round(s, ev)
	assert_true(s.players[0].on_board)
	assert_eq(s.players[0].pos, HEARTH)
	assert_false(s.players[0].done)


func test_revive_waits_while_hearth_has_enemies() -> void:
	s.tile_at(BARRACKS).enemies = 1
	run(MoveCommand.new(0, BARRACKS))
	var ev := []
	engine.rules.begin_round(s, ev)
	place(1, LIVING)
	s.tile_at(HEARTH).enemies = 1
	engine.rules.begin_round(s, ev)
	assert_false(s.players[0].on_board)
	s.tile_at(HEARTH).enemies = 0
	engine.rules.begin_round(s, ev)
	assert_true(s.players[0].on_board)


func test_enemy_phase_wounds_nobles() -> void:
	# Enemies on every tile around the Hearth: whichever way they move, one lands on it.
	for n in s.neighbours(HEARTH):
		s.tile_at(n).enemies = 1
	var ev := _enemy_phase()
	var wounded := ev.filter(func(e): return e["type"] == "noble_wounded")
	assert_eq(wounded.size(), 2)
	assert_eq(wounded.map(func(e): return e["player"]), [0, 1])


func test_everyone_out_runs_next_enemy_phase_immediately() -> void:
	for n in s.neighbours(HEARTH):
		s.tile_at(n).enemies = 1
	var ev := _enemy_phase()
	# Round 2 had nobody on the board, so its Enemy Phase ran too.
	assert_gte(s.round, 3)
	assert_gte(ev.filter(func(e): return e["type"] == "enemy_phase_started").size(), 2)


func test_r7_tough_noble_stays_and_marker_moves() -> void:
	var p := s.players[0]
	p.titles.append("master_of_the_guard")
	s.tile_at(BARRACKS).enemies = 1
	var track := s.turn_index
	run(MoveCommand.new(0, BARRACKS))
	assert_true(p.on_board)
	assert_eq(p.pos, BARRACKS)
	assert_false(p.done)
	assert_eq(s.turn_index, track + 1)
	# The same enemy doesn't wound again this round.
	engine.rules.resolve_board(s, [])
	assert_eq(s.turn_index, track + 1)
	# A new enemy does.
	s.tile_at(BARRACKS).enemies += 1
	engine.rules.resolve_board(s, [])
	assert_eq(s.turn_index, track + 2)
	assert_true(p.on_board)


# --- Surge --------------------------------------------------------------------

func test_r13_surge_replaces_spawn() -> void:
	s.tile_at(EMPTY_SPOT).enemies = 39
	var ev := []
	var surged := engine.rules.spawn_enemies(s, TUNNEL_NW, 3, ev)
	assert_true(surged)
	assert_true(has_event(ev, "enemy_surge"))
	assert_eq(s.enemies_on_board(), 40, "only the one token that fit was placed")


func test_surge_in_enemy_phase_stops_spawning() -> void:
	# 39 on the board: the first spawn point takes the last token, the second triggers a surge.
	s.tile_at(EMPTY_SPOT).enemies = 39
	var ev := _enemy_phase()
	assert_eq(ev.filter(func(e): return e["type"] == "enemy_surge").size(), 1)
	assert_eq(s.enemies_on_board(), 40)


func test_surge_is_a_reveal() -> void:
	s.tile_at(EMPTY_SPOT).enemies = 40
	engine.rules.revealed = false
	engine.rules.spawn_enemies(s, TUNNEL_NW, 1, [])
	assert_true(engine.rules.revealed)


func test_enemy_pool_never_exceeds_forty() -> void:
	s.tile_at(EMPTY_SPOT).enemies = 38
	engine.rules.spawn_enemies(s, TUNNEL_NW, 5, [])
	assert_eq(s.enemies_on_board(), 40)

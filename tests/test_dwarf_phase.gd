extends "res://tests/engine_test_base.gd"
## Milestone 2: dice, worker assistance, movement, resources, simple actions (§4.1, §5.1-5.5, §5.7).


func before_each() -> void:
	new_game(2)


# --- Dice and actions ---------------------------------------------------------

func test_dig_small_and_big() -> void:
	place(0, MINE)
	var ids := dice(0, [1, 4])
	var supply := s.supply
	run(UseActionCommand.new(0, MINE, "dig_small", [ids[0]]))
	run(UseActionCommand.new(0, MINE, "dig_big", [ids[1]]))
	assert_eq(s.players[0].resources, 3 + 1 + 3)
	assert_eq(s.supply, supply - 4)


func test_action_needs_minimum() -> void:
	place(0, MINE)
	var ids := dice(0, [3])
	refuse(UseActionCommand.new(0, MINE, "dig_big", ids), "needs 4+")


func test_worker_assistance_two_dice() -> void:
	place(0, MINE)
	var ids := dice(0, [2, 2])
	run(UseActionCommand.new(0, MINE, "dig_big", ids))
	assert_eq(s.players[0].resources, 6)


func test_worker_assistance_max_two_dice() -> void:
	place(0, MINE)
	var ids := dice(0, [1, 1, 2])
	refuse(UseActionCommand.new(0, MINE, "dig_big", ids), "at most 2")


func test_workmaster_allows_three_dice() -> void:
	place(0, MINE)
	s.players[0].titles.append("workmaster")
	var ids := dice(0, [1, 1, 2])
	run(UseActionCommand.new(0, MINE, "dig_big", ids))


func test_die_spent_once() -> void:
	place(0, MINE)
	var ids := dice(0, [6])
	run(UseActionCommand.new(0, MINE, "dig_big", ids))
	refuse(UseActionCommand.new(0, MINE, "dig_small", ids), "already been spent")


func test_same_die_twice_in_one_action() -> void:
	place(0, MINE)
	var ids := dice(0, [2])
	refuse(UseActionCommand.new(0, MINE, "dig_big", [ids[0], ids[0]]), "twice")


func test_adjacent_ok_diagonal_not() -> void:
	# From the Hearth (B4): the Mine (C3) is diagonal, Living Quarters (C4) is adjacent.
	var ids := dice(0, [6, 6])
	s.players[0].resources = 5
	refuse(UseActionCommand.new(0, MINE, "dig_big", [ids[0]]), "adjacent")
	run(UseActionCommand.new(0, LIVING, "recruit_worker", [ids[1]]))


func test_r10_blocked_tile_actions_dont_work() -> void:
	place(0, MINE)
	s.tile_at(MINE).enemies = 1
	s.tile_at(MINE).warriors = 0
	var ids := dice(0, [6])
	refuse(UseActionCommand.new(0, MINE, "dig_big", ids), "blocked")


func test_resource_cost_must_be_paid() -> void:
	var ids := dice(0, [6])
	s.players[0].resources = 1
	refuse(UseActionCommand.new(0, LIVING, "recruit_worker", ids), "Needs 2")
	s.players[0].resources = 2
	var supply := s.supply
	run(UseActionCommand.new(0, LIVING, "recruit_worker", ids))
	assert_eq(s.players[0].resources, 0)
	assert_eq(s.supply, supply + 2, "spent resources return to the supply")


func test_supply_empty_blocks_gains() -> void:
	s.supply = 0
	place(0, MINE)
	var ids := dice(0, [6])
	refuse(UseActionCommand.new(0, MINE, "dig_big", ids), "supply is empty")


func test_gain_is_capped_by_supply() -> void:
	s.supply = 2
	place(0, MINE)
	var ids := dice(0, [6])
	run(UseActionCommand.new(0, MINE, "dig_big", ids))
	assert_eq(s.players[0].resources, 5)
	assert_eq(s.supply, 0)


func test_train_warrior_places_on_your_tile() -> void:
	# From the Hearth, using the adjacent Barracks.
	var ids := dice(0, [3])
	run(UseActionCommand.new(0, BARRACKS, "train_warrior", ids))
	assert_eq(s.tile_at(HEARTH).warriors, 1)
	assert_eq(s.tile_at(BARRACKS).warriors, 0)
	assert_eq(s.players[0].resources, 0)


func test_train_warrior_fails_when_no_tokens_left() -> void:
	s.tile_at(TUNNEL_SE).warriors = 20
	var ids := dice(0, [3])
	refuse(UseActionCommand.new(0, BARRACKS, "train_warrior", ids), "No warrior tokens")


func test_r20_recruited_die_usable_next_round() -> void:
	var ids := dice(0, [4])
	run(UseActionCommand.new(0, LIVING, "recruit_worker", ids))
	var p := s.players[0]
	assert_eq(p.dice.size(), 1, "not in the active pool yet")
	assert_eq(p.pending.size(), 1)
	assert_eq(int(p.reserve["d4"]), 0)
	refuse(UseActionCommand.new(0, LIVING, "recruit_worker", [ids[0]]))
	finish_round()
	p = s.players[0]
	if p.on_board:
		assert_eq(p.dice.size(), 2)
		assert_eq(p.pending.size(), 0)
		assert_eq(p.dice.back()["type"], "d4")


func test_recruit_needs_d4_in_reserve() -> void:
	s.players[0].reserve["d4"] = 0
	var ids := dice(0, [6])
	refuse(UseActionCommand.new(0, LIVING, "recruit_worker", ids), "No d4")


# --- Movement -----------------------------------------------------------------

func test_move_one_tile_orthogonally() -> void:
	s.players[0].started_on_hearth = false
	run(MoveCommand.new(0, BARRACKS))
	assert_eq(s.players[0].pos, BARRACKS)
	refuse(MoveCommand.new(0, MINE), "No movement left")


func test_no_diagonal_move() -> void:
	refuse(MoveCommand.new(0, MINE), "orthogonally adjacent")


func test_hearth_gives_extra_move() -> void:
	assert_true(s.players[0].started_on_hearth)
	run(MoveCommand.new(0, BARRACKS))
	run(MoveCommand.new(0, MINE))
	refuse(MoveCommand.new(0, Vector2i(2, 1)), "No movement left")


func test_blocked_hearth_gives_no_bonus() -> void:
	# The bonus is decided at the Roll. A Tough Noble can stand on a blocked Hearth.
	var p := s.players[0]
	p.titles.append("master_of_the_guard")
	s.players[1].pos = LIVING
	s.tile_at(HEARTH).enemies = 1
	var ev := []
	engine.rules.begin_round(s, ev)
	assert_false(s.players[0].started_on_hearth)


func test_messenger_moves_further() -> void:
	s.players[0].titles.append("messenger")
	assert_eq(engine.rules.movement_allowance(s.players[0]), 3)


func test_r4_nobles_can_enter_ruins() -> void:
	var ruin := Vector2i(0, 3)
	assert_false(s.tile_at(ruin).revealed)
	run(MoveCommand.new(0, ruin))
	assert_eq(s.players[0].pos, ruin)


func test_empty_halls_lost_until_path_discovered() -> void:
	var halls := Vector2i(0, 3)
	set_tile(halls, "empty_halls")
	run(MoveCommand.new(0, halls))
	refuse(MoveCommand.new(0, HEARTH), "lost")
	var ids := dice(0, [5])
	run(UseActionCommand.new(0, halls, "discover_the_path", ids))
	run(MoveCommand.new(0, HEARTH))


func test_r11_discover_path_frees_all_remaining_movement() -> void:
	var halls := Vector2i(0, 3)
	set_tile(halls, "empty_halls")
	s.players[0].titles.append("messenger")  # 1 + 1 (Hearth) + 1 = 3 moves
	run(MoveCommand.new(0, halls))
	run(UseActionCommand.new(0, halls, "discover_the_path", dice(0, [5])))
	run(MoveCommand.new(0, Vector2i(0, 2)))
	run(MoveCommand.new(0, Vector2i(0, 1)))
	refuse(MoveCommand.new(0, Vector2i(0, 0)), "No movement left")


func test_discover_path_only_from_on_the_halls() -> void:
	var halls := Vector2i(0, 3)
	set_tile(halls, "empty_halls")
	refuse(UseActionCommand.new(0, halls, "discover_the_path", dice(0, [5])), "standing on")


func test_r10_blocked_empty_halls_lets_you_leave() -> void:
	var halls := Vector2i(0, 3)
	set_tile(halls, "empty_halls")
	place(0, halls)
	s.tile_at(halls).enemies = 1
	s.tile_at(halls).warriors = 0
	# Tough keeps the Noble on the tile despite the enemy.
	s.players[0].titles.append("master_of_the_guard")
	s.players[0].tough_tile = halls
	s.players[0].tough_count = 1
	run(MoveCommand.new(0, HEARTH))


func test_carry_warriors() -> void:
	s.tile_at(HEARTH).warriors = 5
	run(MoveCommand.new(0, BARRACKS, 3))
	assert_eq(s.tile_at(HEARTH).warriors, 2)
	assert_eq(s.tile_at(BARRACKS).warriors, 3)


func test_carry_limit_by_player_count() -> void:
	s.tile_at(HEARTH).warriors = 6
	refuse(MoveCommand.new(0, BARRACKS, 5), "at most 4")
	new_game(6)
	s.tile_at(HEARTH).warriors = 6
	refuse(MoveCommand.new(0, BARRACKS, 3), "at most 2")
	new_game(1)
	s.tile_at(HEARTH).warriors = 6
	run(MoveCommand.new(0, BARRACKS, 5))


func test_cant_carry_more_than_are_there() -> void:
	s.tile_at(HEARTH).warriors = 1
	refuse(MoveCommand.new(0, BARRACKS, 2), "aren't that many")


# --- Noble combat -------------------------------------------------------------

func test_noble_combat_removes_adjacent_enemy() -> void:
	s.tile_at(BARRACKS).enemies = 2
	var ids := dice(0, [6])
	run(NobleCombatCommand.new(0, ids[0], BARRACKS))
	assert_eq(s.tile_at(BARRACKS).enemies, 1)


func test_noble_combat_needs_single_die_six() -> void:
	s.tile_at(BARRACKS).enemies = 1
	var ids := dice(0, [5, 1])
	refuse(NobleCombatCommand.new(0, ids[0], BARRACKS), "needs 6+")


func test_noble_combat_range() -> void:
	s.tile_at(MINE).enemies = 1
	var ids := dice(0, [6])
	refuse(NobleCombatCommand.new(0, ids[0], MINE), "out of range")


func test_r6_noble_combat_only_in_dwarf_phase() -> void:
	s.tile_at(BARRACKS).enemies = 1
	var ids := dice(0, [6])
	s.phase = GameState.Phase.ENEMY
	refuse(NobleCombatCommand.new(0, ids[0], BARRACKS), "Dwarf Phase")


# --- Concurrency and done -----------------------------------------------------

func test_r9_players_act_in_any_order() -> void:
	var a := dice(0, [6, 6])
	var b := dice(1, [6, 6])
	place(0, MINE)
	place(1, MINE)
	run(UseActionCommand.new(1, MINE, "dig_small", [b[0]]))
	run(UseActionCommand.new(0, MINE, "dig_small", [a[0]]))
	run(UseActionCommand.new(1, MINE, "dig_small", [b[1]]))
	run(MarkDoneCommand.new(1))
	assert_eq(s.round, 1, "Enemy Phase waits for everyone")
	run(UseActionCommand.new(0, MINE, "dig_small", [a[1]]))
	var r := run(MarkDoneCommand.new(0))
	assert_true(has_event(r["events"], "enemy_phase_started"))


func test_done_player_cant_act() -> void:
	run(MarkDoneCommand.new(0))
	refuse(MoveCommand.new(0, BARRACKS), "already finished")


func test_dice_reroll_each_round() -> void:
	var ids := dice(0, [6])
	run(UseActionCommand.new(0, BARRACKS, "train_warrior", ids))
	assert_true(s.players[0].dice[0]["used"])
	var ev := []
	engine.rules.begin_round(s, ev)
	assert_false(s.players[0].dice[0]["used"])
	assert_true(has_event(ev, "dice_rolled"))

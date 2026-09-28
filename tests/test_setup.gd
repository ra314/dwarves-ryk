extends "res://tests/engine_test_base.gd"
## Milestone 1: data loading and setup (RULES.md §2-3).


func test_game_data_loads() -> void:
	var d := GameData.load_default()
	assert_eq(d.grid_size(), 5)
	assert_eq(d.ruin_stack().size(), 18)
	assert_eq(d.title_ids().size(), 6)
	assert_eq(d.spawn_per_cell().size(), 32)
	assert_null(d.spawn_per_cell()[31])


func test_every_ruling_has_a_flag() -> void:
	var r := GameData.load_default().rule_decisions
	for key in ["spawn_full_amount_at_each_spawn_point", "starting_resources_come_from_supply",
			"nobles_can_enter_ruins", "warrior_enemy_combat", "noble_combat_only_in_dwarf_phase",
			"tough_still_advances_turn_track", "tough_noble_stays_on_tile",
			"encampment_spawn_overrides_messenger", "blocked_tiles_disable_passives",
			"discover_path_restores_all_movement", "enemies_stay_on_new_tunnel", "surge_replaces_spawn",
			"promoted_die_usable_from", "title_dice_return_with_title", "recruited_die_usable_from",
			"undo_history", "unlimited_undo_rerolls_are_random", "garrison_works_when_blocked",
			"title_die_usable_from", "tough_new_enemies_still_wound", "discover_path_only_on_tile",
			"solo_choose_title_to_return", "minecart_ignores_blocked_mines",
			"pending_dice_can_be_promoted"]:
		assert_true(r.has(key), key)


func test_r17_titles_named_as_on_cards() -> void:
	var d := GameData.load_default()
	assert_eq(d.find_action("mine", true, false, "claim_master_miner")["name"], "Master Miner")
	assert_eq(d.find_action("living_quarters", true, false, "claim_workmaster")["name"], "Workmaster")


func test_grid_layout() -> void:
	new_game(4)
	assert_eq(s.tiles.size(), 25)
	assert_eq(s.tile_at(TUNNEL_NW).id, "tunnel")
	assert_eq(s.tile_at(TUNNEL_SE).id, "tunnel")
	assert_eq(s.tile_at(GATE).id, "city_gate")
	assert_eq(s.tile_at(HEARTH).id, "hearth")
	assert_eq(s.tile_at(BARRACKS).id, "barracks")
	assert_eq(s.tile_at(MINE).id, "mine")
	assert_eq(s.tile_at(LIVING).id, "living_quarters")
	assert_eq(s.ruins_left(), 18)


func test_ruins_hold_the_ruin_stack() -> void:
	new_game(2)
	var hidden := []
	for t in s.tiles:
		if not t.revealed:
			hidden.append(t.id)
	hidden.sort()
	var expected := GameData.load_default().ruin_stack()
	expected.sort()
	assert_eq(hidden, expected)


func test_same_seed_same_setup() -> void:
	new_game(3, 42)
	var a := s.to_dict()
	new_game(3, 42)
	assert_eq(s.to_dict(), a)


func test_ruins_are_shuffled() -> void:
	var layouts := {}
	for seed in 5:
		new_game(2, seed)
		layouts[str(s.tiles.map(func(t): return t.id))] = true
	assert_gt(layouts.size(), 1)


func test_nobles_start_on_hearth() -> void:
	new_game(6)
	for p in s.players:
		assert_eq(p.pos, HEARTH)
		assert_true(p.on_board)
	assert_eq(s.players.map(func(p): return p.colour), ["Green", "Red", "Purple", "Blue", "Yellow", "White"])


func _count(p: PlayerState, type: String) -> int:
	return p.dice.filter(func(d): return d["type"] == type).size()


func test_dice_pool_three_plus_players() -> void:
	new_game(3)
	var p := s.players[0]
	assert_eq([_count(p, "d4"), _count(p, "d6"), _count(p, "d8")], [2, 1, 1])
	assert_eq(p.reserve, {"d4": 1, "d6": 3, "d8": 2})


func test_dice_pool_extra_d6_for_one_or_two_players() -> void:
	for n in [1, 2]:
		new_game(n)
		var p := s.players[0]
		assert_eq([_count(p, "d4"), _count(p, "d6"), _count(p, "d8")], [2, 2, 1])
		assert_eq(p.reserve, {"d4": 1, "d6": 2, "d8": 2})


func test_first_roll_happens() -> void:
	new_game(2)
	assert_eq(s.round, 1)
	assert_eq(s.phase, GameState.Phase.DWARF)
	for p in s.players:
		for d in p.dice:
			assert_between(int(d["value"]), 1, GameData.die_sides(d["type"]))
			assert_false(d["used"])


func test_r2_starting_resources_come_from_supply() -> void:
	new_game(3)
	assert_eq(s.supply, 30 - 9)
	for p in s.players:
		assert_eq(p.resources, 3)
	new_game(1)
	assert_eq(s.supply, 20 - 5)
	assert_eq(s.players[0].resources, 5)


func test_r1_turn_track_start() -> void:
	var expected := {1: 0, 2: 0, 3: 1, 4: 2, 5: 3, 6: 4}
	for n in expected:
		new_game(n)
		assert_eq(s.turn_index, expected[n], "%d players" % n)


func test_copy_is_deep() -> void:
	new_game(2)
	var c := s.copy()
	c.tile_at(HEARTH).enemies = 5
	c.players[0].dice[0]["value"] = 99
	c.players[0].reserve["d4"] = 9
	c.players[0].titles.append("regent")
	assert_eq(s.tile_at(HEARTH).enemies, 0)
	assert_ne(int(s.players[0].dice[0]["value"]), 99)
	assert_eq(int(s.players[0].reserve["d4"]), 1)
	assert_eq(s.players[0].titles, [])
	assert_eq(c.to_dict(), GameState.from_dict(c.to_dict()).to_dict())


func test_save_and_load() -> void:
	new_game(2, 7)
	run(MoveCommand.new(0, BARRACKS))
	var path := "user://test_save.json"
	assert_eq(engine.save_to(path), OK)
	var before := s.to_dict()
	var other := GameEngine.new()
	assert_eq(other.load_from(path), OK)
	assert_eq(other.state.to_dict(), before)
	# The RNG continues where it left off.
	assert_eq(other.rng.randi(), engine.rng.randi())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

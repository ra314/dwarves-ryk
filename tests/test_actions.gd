extends "res://tests/engine_test_base.gd"
## Milestone 4: Expedition, remaining tile actions, titles, win (§5.9, §5.12, §7, §8).

const RUIN := Vector2i(0, 3)  # face-down, west of the Hearth
const FAR := Vector2i(3, 1)


func before_each() -> void:
	new_game(2)


# --- Expedition -----------------------------------------------------------------

func test_expedition_flips_pays_and_spawns_d4() -> void:
	set_tile(RUIN, "mine", false)
	var ids := dice(0, [3])
	var r := run(UseActionCommand.new(0, RUIN, "expedition", ids))
	assert_true(s.tile_at(RUIN).revealed)
	assert_eq(s.players[0].resources, 1)
	var rolled: Array = r["events"].filter(func(e): return e["type"] == "enemy_die_rolled")
	assert_eq(rolled.size(), 1)
	assert_eq(s.tile_at(RUIN).enemies, int(rolled[0]["value"]))


func test_expedition_on_revealed_tile_refused() -> void:
	var ids := dice(0, [3])
	refuse(UseActionCommand.new(0, BARRACKS, "expedition", ids), "isn't on this tile")


func test_expedition_from_the_ruin_wounds_you() -> void:
	set_tile(RUIN, "mine", false)
	place(0, RUIN)
	run(UseActionCommand.new(0, RUIN, "expedition", dice(0, [3])))
	assert_false(s.players[0].on_board)


func test_encampment_spawns_six_without_roll() -> void:
	set_tile(RUIN, "encampment", false)
	var r := run(UseActionCommand.new(0, RUIN, "expedition", dice(0, [3])))
	assert_eq(s.tile_at(RUIN).enemies, 6)
	assert_false(has_event(r["events"], "enemy_die_rolled"))


func test_messenger_expedition_free_and_one_enemy() -> void:
	s.players[0].titles.append("messenger")
	set_tile(RUIN, "mine", false)
	run(UseActionCommand.new(0, RUIN, "expedition", dice(0, [3])))
	assert_eq(s.players[0].resources, 3)
	assert_eq(s.tile_at(RUIN).enemies, 1)


func test_r8_encampment_overrides_messenger() -> void:
	s.players[0].titles.append("messenger")
	set_tile(RUIN, "encampment", false)
	run(UseActionCommand.new(0, RUIN, "expedition", dice(0, [3])))
	assert_eq(s.tile_at(RUIN).enemies, 6)


# --- Tile actions ---------------------------------------------------------------

func test_collapse_tunnel() -> void:
	place(0, Vector2i(0, 1))
	run(UseActionCommand.new(0, TUNNEL_NW, "collapse_tunnel", dice(0, [6, 6])))
	assert_true(s.tile_at(TUNNEL_NW).flipped)
	assert_false(s.tile_at(TUNNEL_NW).is_open_tunnel())
	assert_eq(s.open_tunnels(), 1)


func test_r10_blocked_tunnel_cant_be_collapsed() -> void:
	place(0, Vector2i(0, 1))
	s.tile_at(TUNNEL_NW).enemies = 1
	refuse(UseActionCommand.new(0, TUNNEL_NW, "collapse_tunnel", dice(0, [6, 6])), "blocked")


func test_collapsed_tunnel_has_no_actions() -> void:
	place(0, Vector2i(0, 1))
	s.tile_at(TUNNEL_NW).flipped = true
	refuse(UseActionCommand.new(0, TUNNEL_NW, "collapse_tunnel", dice(0, [6, 6])), "isn't on this tile")


func test_secure_gate_needs_ruins_and_tunnels_done() -> void:
	place(0, Vector2i(4, 1))
	var ids := dice(0, [7, 7])
	refuse(UseActionCommand.new(0, GATE, "secure_the_gate", ids), "Explore every ruin")
	reveal_all_as("barracks")
	refuse(UseActionCommand.new(0, GATE, "secure_the_gate", ids), "Collapse every tunnel")
	s.tile_at(TUNNEL_NW).flipped = true
	s.tile_at(TUNNEL_SE).flipped = true
	var r := run(UseActionCommand.new(0, GATE, "secure_the_gate", ids))
	assert_eq(s.result, "won")
	assert_true(has_event(r["events"], "game_over"))
	assert_true(s.tile_at(GATE).flipped)
	refuse(MarkDoneCommand.new(1), "over")


func test_axe_throwers_hit_tile_next_to_watchtower() -> void:
	var tower := Vector2i(0, 3)
	set_tile(tower, "watchtower")
	s.tile_at(Vector2i(0, 4)).enemies = 2
	s.tile_at(Vector2i(0, 1)).enemies = 1
	var ids := dice(0, [4, 4, 4])
	refuse(UseActionCommand.new(0, tower, "axe_throwers", [ids[0]], {"target": Vector2i(0, 1)}), "out of range")
	refuse(UseActionCommand.new(0, tower, "axe_throwers", [ids[0]], {"target": tower}), "out of range")
	run(UseActionCommand.new(0, tower, "axe_throwers", [ids[0]], {"target": Vector2i(0, 4)}))
	assert_eq(s.tile_at(Vector2i(0, 4)).enemies, 1)


func test_false_commands_move_enemy_up_to_two() -> void:
	var camp := Vector2i(0, 3)
	set_tile(camp, "encampment")
	s.tile_at(FAR).enemies = 2
	var ids := dice(0, [3, 3])
	refuse(UseActionCommand.new(0, camp, "false_commands", [ids[0]], {"from": FAR, "to": Vector2i(0, 1)}), "up to 2")
	run(UseActionCommand.new(0, camp, "false_commands", [ids[0]], {"from": FAR, "to": Vector2i(4, 2)}))
	assert_eq(s.tile_at(FAR).enemies, 1)
	assert_eq(s.tile_at(Vector2i(4, 2)).enemies, 1)


func test_false_commands_into_warriors_fights() -> void:
	var camp := Vector2i(0, 3)
	set_tile(camp, "encampment")
	s.tile_at(FAR).enemies = 1
	s.tile_at(Vector2i(3, 2)).warriors = 1
	run(UseActionCommand.new(0, camp, "false_commands", dice(0, [3]), {"from": FAR, "to": Vector2i(3, 2)}))
	assert_eq(s.enemies_on_board(), 0)
	assert_eq(s.warriors_on_board(), 0)


func test_reinforcements_add_three_warriors_to_hearth() -> void:
	var aviary := Vector2i(0, 3)
	set_tile(aviary, "aviary")
	run(UseActionCommand.new(0, aviary, "reinforcements", dice(0, [7, 6])))
	assert_eq(s.tile_at(HEARTH).warriors, 3)
	assert_eq(s.players[0].resources, 0)


func test_promote_worker() -> void:
	var smith := Vector2i(0, 3)
	set_tile(smith, "blacksmith")
	var p := s.players[0]
	var ids := set_dice(0, {"d4": [3], "d8": [5]})
	run(UseActionCommand.new(0, smith, "promote_worker", [ids[1]], {"die": ids[0]}))
	assert_eq(p.dice.size(), 1, "old d4 left the active pool")
	assert_eq(p.pending.map(func(d): return d["type"]), ["d6"])
	assert_eq(int(p.reserve["d4"]), 2)
	assert_eq(int(p.reserve["d6"]), 1)
	assert_eq(p.resources, 0)


func test_r14_promoted_die_usable_next_round() -> void:
	var smith := Vector2i(0, 3)
	set_tile(smith, "blacksmith")
	var ids := set_dice(0, {"d6": [3], "d8": [5]})
	run(UseActionCommand.new(0, smith, "promote_worker", [ids[1]], {"die": ids[0]}))
	var p := s.players[0]
	assert_true(p.dice.all(func(d): return d["type"] != "d8" or d["used"]), "no new unused d8 this round")
	engine.rules.begin_round(s, [])
	assert_eq(p.dice.map(func(d): return d["type"]), ["d8", "d8"])


func test_promote_needs_bigger_die_in_reserve() -> void:
	var smith := Vector2i(0, 3)
	set_tile(smith, "blacksmith")
	s.players[0].reserve["d8"] = 0
	var ids := set_dice(0, {"d6": [5], "d8": [5]})
	refuse(UseActionCommand.new(0, smith, "promote_worker", [ids[1]], {"die": ids[0]}), "No d8")
	refuse(UseActionCommand.new(0, smith, "promote_worker", [ids[0]], {"die": ids[1]}), "can't be promoted")


func test_master_smith_promotes_at_one() -> void:
	var smith := Vector2i(0, 3)
	set_tile(smith, "blacksmith")
	var ids := set_dice(0, {"d4": [1, 2]})
	refuse(UseActionCommand.new(0, smith, "promote_worker", [ids[0]], {"die": ids[1]}), "needs 5+")
	s.players[0].titles.append("master_smith")
	run(UseActionCommand.new(0, smith, "promote_worker", [ids[0]], {"die": ids[1]}))


# --- Titles -----------------------------------------------------------------------

func test_claim_master_miner() -> void:
	place(0, MINE)
	var r := run(UseActionCommand.new(0, MINE, "claim_master_miner", dice(0, [6, 6])))
	assert_eq(s.players[0].titles, ["master_miner"])
	assert_true(has_event(r["events"], "title_gained"))


func test_master_miner_bonus_and_minecart() -> void:
	place(0, MINE)
	s.players[0].titles.append("master_miner")
	var ids := dice(0, [1])
	run(UseActionCommand.new(0, MINE, "dig_big", ids))  # 1 + 3 = 4
	var other := Vector2i(4, 2)
	set_tile(other, "mine")
	s.players[0].moves_used = 99
	run(MoveCommand.new(0, other, 0, true))
	assert_eq(s.players[0].pos, other)
	refuse(MoveCommand.new(0, HEARTH, 0, true), "between two different Mines")


func test_one_title_limit_returns_old_title() -> void:
	var p := s.players[0]
	place(0, MINE)
	run(UseActionCommand.new(0, MINE, "claim_master_miner", dice(0, [6, 6])))
	run(UseActionCommand.new(0, LIVING, "claim_workmaster", dice(0, [7, 7])))
	assert_eq(p.titles, ["workmaster"])
	assert_eq(s.title_holder("master_miner"), -1)


func test_solo_holds_two_titles() -> void:
	new_game(1)
	place(0, MINE)
	run(UseActionCommand.new(0, MINE, "claim_master_miner", dice(0, [6, 6])))
	run(UseActionCommand.new(0, LIVING, "claim_workmaster", dice(0, [7, 7])))
	assert_eq(s.players[0].titles, ["master_miner", "workmaster"])


func test_workmaster_d10_joins_next_round() -> void:
	var p := s.players[0]
	run(UseActionCommand.new(0, LIVING, "claim_workmaster", dice(0, [7, 7])))
	assert_eq(p.pending.map(func(d): return d["type"]), ["d10"])
	assert_false(p.dice.any(func(d): return d["type"] == "d10"))
	engine.rules.begin_round(s, [])
	assert_true(p.dice.any(func(d): return d["type"] == "d10"))


func test_r15_title_die_returns_with_title() -> void:
	var p := s.players[0]
	run(UseActionCommand.new(0, LIVING, "claim_workmaster", dice(0, [7, 7])))
	engine.rules.begin_round(s, [])
	assert_true(p.dice.any(func(d): return d["type"] == "d10"))
	place(0, MINE)
	for d in p.dice:
		d["value"] = 6
		d["used"] = false
	var ids := p.dice.slice(0, 2).map(func(d): return int(d["id"]))
	run(UseActionCommand.new(0, MINE, "claim_master_miner", ids))
	assert_false(p.dice.any(func(d): return d["type"] == "d10"))
	assert_false(p.pending.any(func(d): return d["type"] == "d10"))


func test_taking_a_title_needs_holder_agreement() -> void:
	s.players[1].titles.append("workmaster")
	s.players[1].add_die("d10", "workmaster")
	var ids := dice(0, [7, 7])
	refuse(UseActionCommand.new(0, LIVING, "claim_workmaster", ids), "must agree")
	run(UseActionCommand.new(0, LIVING, "claim_workmaster", ids, {"holder_agreed": true}))
	assert_eq(s.players[0].titles, ["workmaster"])
	assert_eq(s.players[1].titles, [])
	assert_false(s.players[1].dice.any(func(d): return d["type"] == "d10"))


func test_personal_guard() -> void:
	s.players[0].titles.append("master_of_the_guard")
	s.tile_at(BARRACKS).enemies = 1
	run(TitleActionCommand.new(0, "personal_guard", dice(0, [4]), {"target": BARRACKS}))
	assert_eq(s.tile_at(BARRACKS).enemies, 0)


func test_title_ability_needs_title() -> void:
	s.tile_at(BARRACKS).enemies = 1
	refuse(TitleActionCommand.new(0, "personal_guard", dice(0, [4]), {"target": BARRACKS}), "don't hold")


func test_r16_bodyguard_removes_two_own_or_adjacent_single_die() -> void:
	s.players[0].titles.append("regent")
	s.tile_at(BARRACKS).enemies = 3
	s.tile_at(FAR).enemies = 3
	var ids := dice(0, [4, 4, 7])
	refuse(TitleActionCommand.new(0, "bodyguard", [ids[0], ids[1]], {"target": BARRACKS}), "single die")
	refuse(TitleActionCommand.new(0, "bodyguard", [ids[2]], {"target": FAR}), "out of range")
	run(TitleActionCommand.new(0, "bodyguard", [ids[2]], {"target": BARRACKS}))
	assert_eq(s.tile_at(BARRACKS).enemies, 1)


func test_regent_gets_d12() -> void:
	var room := Vector2i(0, 3)
	set_tile(room, "throne_room")
	run(UseActionCommand.new(0, room, "coronation", dice(0, [7, 7])))
	assert_eq(s.players[0].pending.map(func(d): return d["type"]), ["d12"])


func test_architect_swaps_tiles_tokens_stay() -> void:
	s.players[0].titles.append("master_smith")
	s.tile_at(BARRACKS).warriors = 2
	var r := run(TitleActionCommand.new(0, "architect", dice(0, [6]), {"a": BARRACKS, "b": MINE}))
	assert_eq(s.tile_at(BARRACKS).id, "mine")
	assert_eq(s.tile_at(MINE).id, "barracks")
	assert_eq(s.tile_at(BARRACKS).warriors, 2)
	assert_eq(s.players[0].pos, HEARTH)
	assert_true(has_event(r["events"], "tiles_swapped"))


func test_architect_needs_adjacent_tiles() -> void:
	s.players[0].titles.append("master_smith")
	refuse(TitleActionCommand.new(0, "architect", dice(0, [6]), {"a": BARRACKS, "b": FAR}), "next to each other")

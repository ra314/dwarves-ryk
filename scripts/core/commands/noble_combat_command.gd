class_name NobleCombatCommand
extends Command
## Spend a single die of 6+ to remove an enemy on your tile or an adjacent one (§5.7).

var die: int
var target: Vector2i


func _init(player_index: int, die_id: int, at: Vector2i) -> void:
	player = player_index
	die = die_id
	target = at


func can_apply(state: GameState, rules: Rules) -> String:
	var err := rules.check_can_act(state, player)
	if err != "":
		return err
	var p := state.players[player]
	err = rules.check_dice(p, [die], rules.data.limit("noble_combat_min_single_die"), true, null)
	if err != "":
		return err
	return rules.effects["remove_enemies"]["check"].call(state, p, p.pos, {"range": "own_or_adjacent"}, {"target": target})


func apply(state: GameState, rules: Rules) -> Array:
	var ev: Array = []
	var p := state.players[player]
	rules.spend_dice(p, [die])
	rules.effects["remove_enemies"]["apply"].call(state, p, p.pos, {"value": 1}, {"target": target}, ev)
	return ev


func describe(state: GameState, _rules: Rules) -> String:
	return "%s: Noble Combat" % state.players[player].colour

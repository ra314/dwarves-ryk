class_name MarkDoneCommand
extends Command
## The player has finished their Dwarf Phase. When everyone is done, the engine
## runs the Enemy Phase (R9). Unspent dice are lost.

func _init(player_index: int) -> void:
	player = player_index


func can_apply(state: GameState, rules: Rules) -> String:
	return rules.check_can_act(state, player)


func apply(state: GameState, _rules: Rules) -> Array:
	state.players[player].done = true
	return [Rules.event("player_done", {"player": player})]


func describe(state: GameState, _rules: Rules) -> String:
	return "%s is done" % state.players[player].colour

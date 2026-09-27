class_name UseActionCommand
extends Command
## Spend dice (and resources) on an action printed on a tile (§5.1). The tile is
## the player's own or orthogonally adjacent, and must not be blocked.
## params depend on the effect: see the _check_* handlers in rules.gd.

var tile_pos: Vector2i
var action_id: String
var dice: Array
var params: Dictionary


func _init(player_index: int, at: Vector2i, action: String, die_ids: Array, extra: Dictionary = {}) -> void:
	player = player_index
	tile_pos = at
	action_id = action
	dice = die_ids
	params = extra


func action(state: GameState, rules: Rules) -> Dictionary:
	var t := state.tile_at(tile_pos)
	return rules.data.find_action(t.id, t.revealed, t.flipped, action_id)


func can_apply(state: GameState, rules: Rules) -> String:
	var err := rules.check_can_act(state, player)
	if err != "":
		return err
	if not state.in_bounds(tile_pos):
		return "That tile is off the map."
	var p := state.players[player]
	if not GameState.is_own_or_adjacent(p.pos, tile_pos):
		return "You can only use actions on your tile or an adjacent one."
	var t := state.tile_at(tile_pos)
	if t.is_blocked():
		return "That tile is blocked by enemies."
	var a := action(state, rules)
	if a.is_empty():
		return "That action isn't on this tile."
	var terms := rules.action_terms(p, a, t)
	err = rules.check_dice(p, dice, terms["min"], bool(a.get("single_die", false)), t)
	if err != "":
		return err
	if p.resources < terms["cost"]:
		return "Needs %d resources." % terms["cost"]
	return rules.effects[a["effect"]]["check"].call(state, p, tile_pos, a, params)


func apply(state: GameState, rules: Rules) -> Array:
	var ev: Array = []
	var p := state.players[player]
	var a := action(state, rules)
	rules.spend_dice(p, dice)
	rules.pay(state, p, rules.action_terms(p, a, state.tile_at(tile_pos))["cost"])
	ev.append(Rules.event("action_used", {"player": player, "action": action_id, "pos": tile_pos}))
	rules.effects[a["effect"]]["apply"].call(state, p, tile_pos, a, params, ev)
	return ev


func describe(state: GameState, rules: Rules) -> String:
	var t := state.tile_at(tile_pos)
	var name: String = rules.data.ruins_back()["actions"][0]["name"] if not t.revealed else action(state, rules).get("name", action_id)
	var tile_name: String = "Ruins" if not t.revealed else rules.data.tile(t.id)["name"]
	return "%s: %s (%s)" % [state.players[player].colour, name, tile_name]

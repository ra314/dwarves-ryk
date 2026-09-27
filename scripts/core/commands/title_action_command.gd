class_name TitleActionCommand
extends Command
## Use an action ability of a held title: Personal Guard, Architect or Bodyguard.

var ability_id: String
var dice: Array
var params: Dictionary


func _init(player_index: int, ability: String, die_ids: Array, extra: Dictionary = {}) -> void:
	player = player_index
	ability_id = ability
	dice = die_ids
	params = extra


## [title_id, ability dict] for this ability among the player's titles, or ["", {}].
func find(p: PlayerState, rules: Rules) -> Array:
	for t in p.titles:
		var a := rules.data.title_ability(t, ability_id)
		if not a.is_empty() and a["type"] == "action":
			return [t, a]
	return ["", {}]


func can_apply(state: GameState, rules: Rules) -> String:
	var err := rules.check_can_act(state, player)
	if err != "":
		return err
	var p := state.players[player]
	var a: Dictionary = find(p, rules)[1]
	if a.is_empty():
		return "You don't hold a title with that ability."
	err = rules.check_dice(p, dice, int(a["min"]), bool(a.get("single_die", false)), null)
	if err != "":
		return err
	if p.resources < int(a.get("cost", 0)):
		return "Needs %d resources." % int(a["cost"])
	return rules.effects[a["effect"]]["check"].call(state, p, p.pos, a, params)


func apply(state: GameState, rules: Rules) -> Array:
	var ev: Array = []
	var p := state.players[player]
	var a: Dictionary = find(p, rules)[1]
	rules.spend_dice(p, dice)
	rules.pay(state, p, int(a.get("cost", 0)))
	ev.append(Rules.event("action_used", {"player": player, "action": ability_id, "pos": p.pos}))
	rules.effects[a["effect"]]["apply"].call(state, p, p.pos, a, params, ev)
	return ev


func describe(state: GameState, rules: Rules) -> String:
	var p := state.players[player]
	var f := find(p, rules)
	var name: String = ability_id.capitalize() if f[0] == "" else rules.data.title(f[0])["name"]
	return "%s: %s (%s)" % [p.colour, ability_id.capitalize(), name]

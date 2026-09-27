class_name Command
extends RefCounted
## Base class for every player action. The UI builds commands and hands them to
## GameEngine.execute(); it never edits GameState itself.

var player: int


## Returns "" if the command is legal, otherwise a reason to show the player.
func can_apply(_state: GameState, _rules: Rules) -> String:
	return "Not implemented."


## Changes the state and returns a list of events for the UI to animate.
## Only called after can_apply() returned "".
func apply(_state: GameState, _rules: Rules) -> Array:
	return []


## Short log line, e.g. "Red: Dig (Mine)". Called before apply().
func describe(state: GameState, _rules: Rules) -> String:
	return state.players[player].colour

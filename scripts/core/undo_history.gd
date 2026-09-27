class_name UndoHistory
extends RefCounted
## Snapshots of GameState taken before each command (RULES.md §6).
## A snapshot taken just before a reveal is a checkpoint; in normal mode undo
## can't restore it, so reveals can't be taken back. History is shared (R18).

## Each entry: {"state": GameState, "checkpoint": bool, "player": int, "label": String}
var entries: Array[Dictionary] = []


func push(state_before: GameState, checkpoint: bool, player: int, label: String) -> void:
	entries.append({"state": state_before, "checkpoint": checkpoint, "player": player, "label": label})


func can_undo(unlimited: bool) -> bool:
	if entries.is_empty():
		return false
	return unlimited or not entries.back()["checkpoint"]


## The entry undo() would reverse, or {}.
func peek() -> Dictionary:
	return {} if entries.is_empty() else entries.back()


## Removes and returns the latest entry. Its "state" is the state to restore.
func pop() -> Dictionary:
	return entries.pop_back()


func clear() -> void:
	entries.clear()

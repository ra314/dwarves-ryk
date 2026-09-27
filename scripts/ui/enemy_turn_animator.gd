class_name EnemyTurnAnimator
extends RefCounted
## Replays the Enemy Phase step by step from its events, so players can follow it:
## a banner names each step, enemy tokens fly between tiles, spawns and fights
## flash. It works on a display copy of the board from just before the command;
## the real state is already final and is drawn again when the replay ends.

## Flight time for one tile's group of enemies.
const STEP_SECONDS := 0.2
const DIR_ARROWS := {"north": "↑", "east": "→", "south": "↓", "west": "←"}

var main  # the main screen (untyped: main.gd has no class_name)
var skip := false
## The display copy being replayed; after play() it matches the real board.
var board: GameState


func _init(screen) -> void:
	main = screen


## Plays everything from the first enemy_phase_started on. Earlier events (the
## command that ended the Dwarf Phase) are applied at once.
func play(before: GameState, events: Array, instant: bool = false) -> void:
	skip = instant
	board = before
	var started := false
	var i := 0
	while i < events.size():
		var e: Dictionary = events[i]
		if not started and e["type"] != "enemy_phase_started":
			_apply(e)
			i += 1
			continue
		started = true
		# Enemies moving together (the movement roll, a surge) fly as one group.
		if e["type"] in ["enemy_surge", "enemy_die_rolled"] and e.has("direction"):
			var group := []
			var j := i + 1
			while j < events.size() and events[j]["type"] == "enemy_moved":
				group.append(events[j])
				j += 1
			await _move_step(e, group)
			i = j
			continue
		await _step(e)
		i += 1
	main.hide_banner()


func _step(e: Dictionary) -> void:
	var at := func(k): return MoveCommand._pos_name(e[k])
	match e["type"]:
		"enemy_phase_started":
			await _show("Enemy Phase", 0.8)
		"tunnel_created":
			_apply(e)
			_pulse(e["pos"])
			await _show("Enemies overrun the %s at %s: it becomes a Tunnel" % [
				main.engine.data.tile(e["was"])["name"], at.call("pos")], 1.1, e["pos"])
		"enemies_spawned":
			_apply(e)
			_pulse(e["pos"])
			await _show("%d enem%s appear at %s" % [e["count"], "y" if e["count"] == 1 else "ies", at.call("pos")], 0.45, e["pos"])
		"combat":
			_apply(e)
			_pulse(e["pos"])
			await _show("Warriors fight at %s: %d fall on each side" % [at.call("pos"), e["count"]], 0.8, e["pos"])
		"noble_wounded":
			_apply(e)
			_pulse(e["pos"])
			var who: String = main.engine.data.player_colours()[e["player"]]
			await _show("%s is wounded%s" % [who, " but stays (Tough)" if e["tough"] else "!"], 1.0, e["pos"])
		"track_advanced":
			_apply(e)
			await _show("Turn marker moves to %d" % (int(e["index"]) + 1), 0.6)
		"round_started":
			_apply(e)
			await _show("Round %d" % e["round"], 0.6)
		"game_over":
			await _show(e["reason"], 1.5)
		"enemy_moved":  # a lone move outside a group
			await _move_step({}, [e])
		_:
			_apply(e)


func _move_step(roll: Dictionary, moves: Array) -> void:
	if roll.has("direction"):
		var arrow: String = DIR_ARROWS.get(roll["direction"], "")
		var title := "ENEMY SURGE! " if roll["type"] == "enemy_surge" else "Enemy die: %d. " % roll["value"]
		await _show("%sEnemies move %s %s" % [title, roll["direction"], arrow], 0.9)
	if moves.is_empty():
		return
	# One tile's group at a time, front of the march first, so a group has left
	# its tile before the one behind it arrives. Edge bounces go last.
	for m in _march_order(moves):
		board.tile_at(m["from"]).enemies -= int(m["count"])
		main.draw_board(board)
		if not skip:
			await main.fly_enemies([m], STEP_SECONDS)
		board.tile_at(m["to"]).enemies += int(m["count"])
		main.draw_board(board)
	await _wait(0.2)


## Sorts moves so the leading tiles in the direction of travel go first.
static func _march_order(moves: Array) -> Array:
	if moves.size() < 2:
		return moves
	# The shared direction is the most common from->to step (bounces go the other way).
	var votes := {}
	for m in moves:
		var d: Vector2i = m["to"] - m["from"]
		votes[d] = int(votes.get(d, 0)) + 1
	var dir: Vector2i = votes.keys()[0]
	for d in votes:
		if votes[d] > votes[dir]:
			dir = d
	var ahead := func(m) -> int: return -(m["from"].x * dir.x + m["from"].y * dir.y)
	var forward := moves.filter(func(m): return m["to"] - m["from"] == dir)
	var bounced := moves.filter(func(m): return m["to"] - m["from"] != dir)
	forward.sort_custom(func(a, b): return ahead.call(a) < ahead.call(b))
	bounced.sort_custom(func(a, b): return ahead.call(a) > ahead.call(b))
	return forward + bounced


func _show(text: String, seconds: float, focus: Vector2i = PlayerState.NO_TILE) -> void:
	main.show_banner(text, focus)
	main.draw_board(board)
	await _wait(seconds)


func _wait(seconds: float) -> void:
	if skip:
		return
	await main.get_tree().create_timer(seconds).timeout


func _pulse(pos: Vector2i) -> void:
	if not skip:
		main.tile_views[pos.y * board.size + pos.x].pulse()


## Moves the display board one event forward.
func _apply(e: Dictionary) -> void:
	var b := board
	match e["type"]:
		"noble_moved":
			var p := b.players[e["player"]]
			b.tile_at(e["from"]).warriors -= int(e["carried"])
			b.tile_at(e["to"]).warriors += int(e["carried"])
			p.pos = e["to"]
		"enemy_moved":
			b.tile_at(e["from"]).enemies -= int(e["count"])
			b.tile_at(e["to"]).enemies += int(e["count"])
		"enemies_spawned":
			b.tile_at(e["pos"]).enemies += int(e["count"])
		"enemies_removed":
			b.tile_at(e["pos"]).enemies -= int(e["count"])
		"combat":
			b.tile_at(e["pos"]).enemies -= int(e["count"])
			b.tile_at(e["pos"]).warriors -= int(e["count"])
		"warriors_placed":
			b.tile_at(e["pos"]).warriors += int(e["count"])
		"tunnel_created":
			b.tile_at(e["pos"]).id = "tunnel"
			b.tile_at(e["pos"]).flipped = false
		"tile_flipped":
			b.tile_at(e["pos"]).revealed = true
		"tunnel_collapsed":
			b.tile_at(e["pos"]).flipped = true
		"tiles_swapped":
			var ta := b.tile_at(e["a"])
			var tb := b.tile_at(e["b"])
			var keep := [ta.id, ta.revealed, ta.flipped]
			ta.id = tb.id; ta.revealed = tb.revealed; ta.flipped = tb.flipped
			tb.id = keep[0]; tb.revealed = keep[1]; tb.flipped = keep[2]
		"noble_wounded":
			if not e["tough"]:
				b.players[e["player"]].on_board = false
		"noble_revived":
			b.players[e["player"]].on_board = true
			b.players[e["player"]].pos = e["pos"]
		"track_advanced":
			b.turn_index = int(e["index"])
		"round_started":
			b.round = int(e["round"])

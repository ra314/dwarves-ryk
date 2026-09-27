extends SceneTree
## Plays a game with random legal moves and prints the board each round.
## Usage: godot --headless -s res://tools/debug_game.gd -- [players] [seed]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var players := int(args[0]) if args.size() > 0 else 2
	var seed := int(args[1]) if args.size() > 1 else 1
	var engine := GameEngine.new()
	engine.new_game(players, seed)
	var pick := RandomNumberGenerator.new()
	pick.seed = seed
	var last_round := -1
	while not engine.state.is_over() and engine.state.round < 60:
		if engine.state.round != last_round:
			last_round = engine.state.round
			print("\n", DebugView.render(engine.state, engine.data))
		var cmds := RandomPlayer.legal_commands(engine)
		var cmd: Command = cmds[pick.randi_range(0, cmds.size() - 1)]
		var res := engine.execute(cmd)
		print("  ", engine.undo_label() if res["ok"] else res["error"])
	print("\n", DebugView.render(engine.state, engine.data))
	quit()

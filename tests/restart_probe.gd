extends SceneTree
## Invoked in two distinct processes to verify scene-level persistent progress.
var game: MainGameController

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or not args[1].is_valid_int() or not args[0] in ["write", "read"]:
		quit(2)
		return
	var path: String = "user://restart-probe-" + args[1] + ".json"
	var scene: PackedScene = load("res://src/features/stream/scenes/main_game.tscn") as PackedScene
	game = scene.instantiate() as MainGameController
	(game.get_node("AppBootstrap") as AppBootstrap).repository_override = FileSaveRepository.new(path)
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	var valid: bool = true
	if args[0] == "write":
		game._start_content("irl")
		for i: int in range(55):
			game.app.stream.click()
		for i: int in range(50):
			game.app.stream.tick()
		game.app.stream.set_reduced_motion(true)
		game.app.stream.finish()
		game.app.stream.continue_to_room()
		valid = game.app.queue.flush().success
	else:
		var state: PlayerState = game.app.stream.state
		valid = state.total_clicks == 55 and state.total_streams == 1 and state.level == 1 and state.xp == 55 and state.money >= 10 and state.settings["reduced_motion"] and not state.is_streaming and state.current_stream_type_id == "irl"
	game.queue_free()
	await process_frame
	if args[0] == "read":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESTART " + args[0] + ": " + ("PASS" if valid else "FAIL"))
	quit(0 if valid else 1)

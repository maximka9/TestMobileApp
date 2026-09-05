extends SceneTree
## Real renderer smoke test: isolated progress, layout assertions, PNG evidence.
var failures: int = 0
var game: MainGameController

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://src/features/stream/scenes/main_game.tscn") as PackedScene
	game = scene.instantiate() as MainGameController
	(game.get_node("AppBootstrap") as AppBootstrap).repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/checks"))
	for resolution: Vector2i in [Vector2i(360, 640), Vector2i(360, 800), Vector2i(540, 960), Vector2i(720, 1280)]:
		root.size = resolution
		await process_frame
		await process_frame
		_check_layout(resolution)
		await _capture("room-%dx%d" % [resolution.x, resolution.y])
	root.size = Vector2i(360, 640)
	await process_frame
	game._show_games()
	await _capture("games")
	game._start_content("irl")
	# Feed a real input event through the viewport rather than calling ClickHandler.
	var before: int = game.app.stream.state.total_clicks
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.room.get_global_rect().get_center()
	root.push_input(click)
	click = click.duplicate() as InputEventMouseButton
	click.pressed = false
	root.push_input(click)
	if game.app.stream.state.total_clicks != before + 1:
		failures += 1
		printerr("FAIL: viewport input should produce exactly one click")
	for second: int in range(150):
		for i: int in range(3):
			game.app.stream.click()
		game.app.stream.tick()
		if game.app.events.pending != null:
			game.app.stream.resolve_event(false)
	game.modal_layer.hide()
	game.modal_kind = ""
	await _capture("live")
	game._show_upgrades()
	await _capture("upgrades")
	game._close_modal()
	game.app.events.pending = game.app.catalog.events["clip"]
	game._show_event(game.app.events.pending)
	await _capture("event")
	game._resolve_event(true)
	game._primary_pressed()
	await _capture("summary")
	game._close_modal()
	game.queue_free()
	await process_frame
	print("VISUAL SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _check_layout(resolution: Vector2i) -> void:
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, game.size)
	for node: Control in [game.primary, game.room, game.save_status, game.debug_label]:
		if not viewport_rect.encloses(node.get_global_rect()):
			failures += 1
			printerr("FAIL: control outside viewport at %s: %s %s viewport %s" % [resolution, node.name, node.get_global_rect(), viewport_rect])

func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var captured: Image = root.get_texture().get_image()
	var result: Error = captured.save_png("res://build/checks/" + filename + ".png")
	if result != OK:
		failures += 1
	print("CAPTURE: " + filename)

extends SceneTree
## Real renderer smoke: nine mobile ratios, safe insets, input and bounded effects.
const OUTPUT: String = "res://build/checks/v0.2/"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(360, 640), Vector2i(360, 800), Vector2i(375, 812), Vector2i(390, 844), Vector2i(393, 852), Vector2i(412, 915), Vector2i(540, 960), Vector2i(720, 1280), Vector2i(1080, 2400)]
var failures: int = 0
var game: MainGameController
var measurements: Array[Dictionary] = []

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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for resolution: Vector2i in RESOLUTIONS:
		root.size = resolution
		await process_frame
		await process_frame
		_check_layout(resolution)
		await _capture("aspect_%dx%d" % [resolution.x, resolution.y])
		game._show_games()
		await process_frame
		await process_frame
		_check_modal(resolution)
		game._close_modal()
	root.size = Vector2i(360, 640)
	await process_frame
	await _capture("room_offline")
	game.safe_insets_override = Vector4i(0, 24, 0, 20)
	game._safe_area()
	await process_frame
	await process_frame
	_check_layout(root.size)
	game._show_games()
	await process_frame
	await process_frame
	_check_modal(root.size)
	await _capture("safe_area_simulated")
	game._close_modal()
	game.safe_insets_override = Vector4i(-1, -1, -1, -1)
	game._safe_area()
	game._show_games()
	await _capture("games_modal")
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
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = game.room.get_global_rect().get_center()
	before = game.app.stream.state.total_clicks
	root.push_input(touch)
	var emulated: InputEventMouseButton = InputEventMouseButton.new()
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.position = touch.position
	root.push_input(emulated)
	_check(game.app.stream.state.total_clicks == before + 1, "Touch plus emulated mouse gives one gameplay click")
	touch = touch.duplicate() as InputEventScreenTouch
	touch.pressed = false
	root.push_input(touch)
	await _capture("room_live")
	for second: int in range(150):
		for i: int in range(3):
			game.app.stream.click()
		game.app.stream.tick()
		if game.app.events.pending != null:
			game.app.stream.resolve_event(false)
	game.modal_layer.hide()
	game.modal_kind = ""
	await _capture("room_high_hype")
	game._show_upgrades()
	await _capture("upgrades_modal")
	game._close_modal()
	game.app.events.pending = game.app.catalog.events["clip"]
	game._show_event(game.app.events.pending)
	await _capture("event_modal")
	game._resolve_event(true)
	game._primary_pressed()
	await _capture("summary")
	game._close_modal()
	# Run ordinary frame updates long enough to sample FPS and expire pooled feedback.
	game._start_content("just_chatting")
	var node_count: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i: int in range(500):
		game._room_tapped(game.room.size / 2.0)
	_check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == node_count, "500 click reactions do not allocate nodes")
	await create_timer(3.0).timeout
	_check(game.room.floating_pool.active_count() == 0, "Floating feedback expires under real frame updates")
	game.app.metrics.sample(1.0, game.app.queue, game.app.events)
	measurements.append({"renderer_metrics": game.app.metrics.snapshot, "pool_capacity": game.room.floating_pool.CAPACITY, "pool_active_after_expiry": game.room.floating_pool.active_count()})
	var report: FileAccess = FileAccess.open(OUTPUT + "visual_report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures": failures, "measurements": measurements}, "\t"))
	report.close()
	game.queue_free()
	await process_frame
	print("VISUAL SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _check_layout(resolution: Vector2i) -> void:
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, game.size)
	for node: Control in [game.header, game.primary, game.room, game.save_status, game.get_node("%Navigation") as Control]:
		_check(viewport_rect.grow(0.5).encloses(node.get_global_rect()), "Control inside viewport %s: %s" % [resolution, node.name])
	_check(game.room.size.y >= 190.0, "Room retains useful height at " + str(resolution))
	_check((game.get_node("%Backdrop") as Control).get_global_rect().is_equal_approx(viewport_rect), "Backdrop fills viewport at " + str(resolution))
	var projected_size: Vector2 = root.get_screen_transform().get_scale() * game.size
	_check(projected_size.distance_to(Vector2(root.size)) < 3.0, "Viewport fills physical window without letterbox at " + str(resolution))
	for button_name: String in ["PrimaryButton", "GamesButton", "CollabButton", "MovesButton", "UpgradesButton", "SettingsButton"]:
		var button: Button = game.get_node("%" + button_name) as Button
		_check(button.size.x >= 48.0 and button.size.y >= 48.0, "48-unit target: " + button_name)
	if game.safe_insets_override.x >= 0:
		_check(game.header.get_global_rect().position.y >= game.safe_insets_override.y, "Header avoids simulated top inset")
		_check(game.save_status.get_global_rect().end.y <= game.size.y - game.safe_insets_override.w, "Footer avoids simulated bottom inset")
	measurements.append({"requested_window": str(resolution), "actual_window": str(root.size), "logical_viewport": str(game.size), "projected_pixels": str(projected_size), "room_height": game.room.size.y})

func _check_modal(resolution: Vector2i) -> void:
	var bounds: Rect2 = Rect2(Vector2.ZERO, game.size)
	_check(bounds.encloses((game.get_node("%ModalPanel") as Control).get_global_rect()), "Modal fits " + str(resolution))
	_check(bounds.encloses(game.modal_close.get_global_rect()), "Modal close accessible " + str(resolution))
	_check(game.modal_close.size.y >= 48.0, "Modal close touch target")
	for child: Node in game.modal_body.get_children():
		if child is Button:
			_check(child.size.y >= 48.0, "Modal action touch target")

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var captured: Image = root.get_texture().get_image()
	var result: Error = captured.save_png(OUTPUT + filename + ".png")
	if result != OK:
		failures += 1
	print("CAPTURE: " + filename)

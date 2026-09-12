extends "res://tests/v07_ui_smoke.gd"
const V09_OUTPUT: String = "res://docs/v0.9-screenshots/"

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = load("res://src/features/stream/scenes/main_game.tscn").instantiate()
	game.get_node("AppBootstrap").repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(V09_OUTPUT))
	game._start_content("just_chatting")
	game.app.events.next_at = 100000
	game.app.stream.state.hype = 85
	game.app.stream.state.viewers = 100
	game._refresh()
	var monitor: Node = game.room.get_node("Stage/Desk/RightMonitor")
	_check(game.get_node("%LocationContainer").is_ancestor_of(monitor), "Monitor remains in location hierarchy")
	_check(game.get_node("ModalCanvas").layer > 0, "Modal canvas above gameplay")
	_check(game.primary.z_index > monitor.z_index, "Regular UI above location visuals on gameplay canvas")
	for kind: String in ["content", "collab", "collab_offer", "moves", "upgrades", "achievements", "options", "start", "event", "summary"]:
		match kind:
			"content":
				game.app.stream.finish()
				game._close_modal()
				game._show_short_forms()
			"collab":
				game._start_content("just_chatting")
				game._show_collaborations()
			"collab_offer":
				var id: String = game.app.collaborations.directory.profiles().keys()[0]
				game._show_collab_offer(id, game.app.collaborations.formats(id)[0])
			"moves": game._show_moves(false)
			"upgrades": game._show_upgrades()
			"achievements": game._show_achievements()
			"options": game._show_settings()
			"start": game._show_games()
			"event": game._show_event(game.app.catalog.events.values()[0])
			"summary": game.app.stream.finish()
		await _capture(kind + "_modal")
		var clicks: int = game.app.stream.state.total_clicks
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = game.room.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
		await process_frame
		_check(game.app.stream.state.total_clicks == clicks, "Modal blocks gameplay input: " + kind)
		game._close_modal()
	game.app.stream.state.fatigue = 0
	game._start_content("cooking")
	game.app.stream.tick()
	game.app.stream.finish()
	game._close_modal()
	game.app.stream.state.fatigue = 97
	game._show_short_forms()
	await _capture("cooking_ready_97")
	for child: Node in game.modal_body.get_children():
		if child is Button:
			_check(not child.disabled, "Cooking source publish enabled at 97 fatigue after summary")
			child.pressed.emit()
			break
	_check(game.modal_kind == "short_result" and game.app.stream.state.fatigue == 100, "UI publishes cooking and displays result")
	_check(_contains_label("100%") and _contains_label("подписчики: +"), "UI result exposes fatigue and follower gain")
	await _capture("cooking_published_100")
	game.queue_free()
	await process_frame
	print("V09 UI SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _capture(filename: String) -> void:
	if OS.get_environment("SASA_NO_SCREENSHOTS") == "1":
		await process_frame
		await process_frame
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_check(Rect2(Vector2.ZERO, game.size).encloses(game.get_node("%ModalPanel").get_global_rect()), "Modal fits " + filename)
	_check(game.room.visible and game.get_node("ModalCanvas").layer == 100, "World visible behind modal canvas")
	_check(root.get_texture().get_image().save_png(V09_OUTPUT + filename + ".png") == OK, "Capture " + filename)

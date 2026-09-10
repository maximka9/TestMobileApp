extends "res://tests/typography_smoke.gd"
const V010_OUTPUT: String = "res://docs/v0.10-screenshots/"

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = load("res://src/features/stream/scenes/main_game.tscn").instantiate()
	game.get_node("AppBootstrap").repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(V010_OUTPUT))
	game._show_achievements()
	await process_frame
	await process_frame
	var pan: AchievementPan = game.achievement_pan
	pan.set_zoom(0)
	_check(pan.zoom == 0.6, "Zoom lower bound")
	pan.set_zoom(3)
	_check(pan.zoom == 1.8, "Zoom upper bound")
	pan.set_zoom(1)
	pan.set_zoom(pan.zoom + pan.ZOOM_STEP)
	_check(is_equal_approx(pan.zoom, 1.1), "Plus step")
	pan.set_zoom(pan.zoom - pan.ZOOM_STEP)
	_check(is_equal_approx(pan.zoom, 1), "Minus step")
	for value: float in [0.6, 1, 1.8]:
		pan.set_zoom(value)
		await process_frame
		for button: Button in game.achievement_tree.buttons.values():
			pan.focus_node(button)
			await process_frame
			_check(pan.get_global_rect().grow(2).encloses(button.get_global_rect()), "Every node fully reachable at " + str(value) + " " + button.text)
		pan.focus_node(game.achievement_tree.buttons["first_collab"])
		pan._begin(pan.global_position + pan.size / 2, true)
		pan._drag(pan.previous - Vector2(12, 12))
		_check(pan.dragged, "Drag at every zoom")
		pan._begin(Vector2.ZERO, false)
		_check(game.modal_title.scale == Vector2.ONE and game.modal_close.scale == Vector2.ONE, "Header and back fixed")
		await _capture("achievements_zoom_%d" % roundi(value * 100))
	pan.fit()
	_check(pan.zoom >= 0.6 and pan.zoom <= 1.8, "Fit clamped")
	await _capture("achievements_fit")
	pan.set_zoom(1.2)
	await process_frame
	await process_frame
	pan.scroll_horizontal = 300
	pan.scroll_vertical = 300
	var pivot: Vector2 = pan.size / 2
	var world: Vector2 = (Vector2(pan.scroll_horizontal, pan.scroll_vertical) + pivot) / pan.zoom
	pan.set_zoom(1.3, pivot)
	await process_frame
	await process_frame
	_check(world.distance_to((Vector2(pan.scroll_horizontal, pan.scroll_vertical) + pivot) / pan.zoom) < 2, "Zoom preserves point under cursor")
	pan.set_zoom(1.2)
	pan.scroll_horizontal = 110
	game._close_modal()
	game._show_achievements()
	await process_frame
	await process_frame
	_check(is_equal_approx(game.achievement_pan.zoom, 1.2) and game.achievement_pan.scroll_horizontal == 110, "Session view restored")
	var gesture: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
	gesture.position = game.achievement_pan.get_global_rect().get_center()
	gesture.factor = 1.1
	game.achievement_pan._input(gesture)
	_check(is_equal_approx(game.achievement_pan.zoom, 1.32), "Pinch magnification")
	var state: PlayerState = game.app.stream.state
	state.completed_collabs = 1
	state.completed_irl_collab_creator_ids.append("rostikfacekid")
	game._refresh()
	await process_frame
	await process_frame
	game.achievement_pan.focus_node(game.achievement_tree.buttons["irl_collab_rostikfacekid"])
	await _capture("achievement_special_irl")
	var notifications: AchievementNotificationQueue = game.achievement_notifications
	_check(not notifications.pending.is_empty() and not notifications.visible, "Unlock queued behind modal")
	game._close_modal()
	game.set_process(false)
	notifications.pending.clear()
	notifications.active_id = ""
	notifications.seen.clear()
	for id: String in ["first_cooking", "first_irl", "first_collab"]:
		notifications.enqueue(id)
		notifications.enqueue(id)
	_check(notifications.pending.size() == 3, "Unique sequential queue")
	var area: Rect2 = Rect2(12, 12, 336, 510)
	notifications.advance(0.4, false, false, area)
	await process_frame
	await process_frame
	notifications.advance(0, false, false, area)
	await _capture("achievement_unlocked_toast")
	_check(notifications.active_id == "first_cooking" and notifications.mouse_filter == Control.MOUSE_FILTER_IGNORE, "First toast does not intercept taps")
	notifications.advance(4, false, false, area)
	notifications.advance(0.4, false, true, area)
	_check(notifications.active_id == "first_irl" and notifications.reduced_motion and notifications.card.scale == Vector2.ONE, "Next toast respects reduced motion")
	notifications.advance(4, false, true, area)
	notifications.advance(0.4, false, true, area)
	_check(notifications.active_id == "first_collab", "Third notification follows second")
	notifications.hide()
	game.app.collaborations.clock = func() -> int: return 1000
	for featured: String in ["rostikfacekid", "iceicell"]:
		state.collab_cooldowns.clear()
		for id: String in game.app.config.featured_collab_creator_ids:
			if id != featured:
				state.collab_cooldowns[id] = 2000
		game.app.collaborations.refresh_candidates(state)
		game._show_collaborations()
		await process_frame
		game.modal_scroll.scroll_vertical = 100000
		await _capture("collabs_featured_" + ("rostik" if featured == "rostikfacekid" else "other"))
		_check(game._shown_candidate_ids.back() == featured, "Featured card last")
	await _capture("collab_card_compact")
	for id: String in game.app.config.featured_collab_creator_ids:
		state.collab_cooldowns[id] = 2000
	game.app.collaborations.refresh_candidates(state)
	game._show_collaborations()
	_check((game.modal_body.get_child(game.modal_body.get_child_count() - 1) as Button).disabled, "Featured cooldown disables action")
	for child: Node in game.modal_body.get_children():
		if child is Label:
			_check(not "отношения:" in child.text and not "Данные:" in child.text, "Cards omit internal fields")
	state.collab_cooldowns.clear()
	state.pending_outbound_collab = {}
	state.level = 10
	game.app.collaborations.random = ScriptedRandomProvider.new([0])
	game.app.collaborations.request(state, "rostikfacekid", "irl")
	game._close_modal()
	game._start_content("irl")
	game.app.events.next_at = 100000
	for i: int in range(30):
		game.app.stream.tick()
	game.app.stream.finish()
	_check(state.pending_outbound_collab.is_empty(), "Actual stream completes special collaboration")
	await _capture("special_irl_result")
	game._close_modal()
	game._show_settings()
	await process_frame
	game.modal_scroll.scroll_vertical = 100000
	await _capture("options_reset_button")
	game._confirm_reset()
	await _capture("reset_confirmation_1")
	game._confirm_reset_text()
	var input: LineEdit = game.modal_body.get_node("ResetConfirmation")
	var confirm: Button = game.modal_body.get_child(game.modal_body.get_child_count() - 1)
	_check(confirm.disabled, "Reset disabled without exact text")
	input.text = "СБРОСИТЬ "
	input.text_changed.emit(input.text)
	_check(confirm.disabled, "Near match rejected")
	input.text = "СБРОСИТЬ"
	input.text_changed.emit(input.text)
	_check(not confirm.disabled, "Exact confirmation enables reset")
	await _capture("reset_confirmation_2")
	var repository: FakeSaveRepository = game.app.repository_override
	game.app.saves.logger = FakeLogger.new()
	repository.failures_left = 1
	game._reset_progress()
	_check(not game.reset_busy and game.modal_kind == "reset_confirmation_2", "Write failure keeps confirmation and game")
	game.app.set_process(false)
	game._reset_progress()
	await process_frame
	await process_frame
	for child: Node in root.get_children():
		if child is MainGameController:
			game = child
	await process_frame
	game.app.set_process(false)
	_check(game.app.stream.state.level == 1 and game.app.stream.state.unlocked_achievements.is_empty(), "Reload after reset is fresh game")
	await _capture("after_reset_main")
	game.app.queue.cancel()
	game.queue_free()
	await process_frame
	print("V010 UI SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(V010_OUTPUT + name + ".png") == OK, "Screenshot " + name)

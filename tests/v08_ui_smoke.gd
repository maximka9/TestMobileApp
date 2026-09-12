extends "res://tests/v07_ui_smoke.gd"
const V08_OUTPUT: String = "res://build/checks/v0.8/"

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = load("res://src/features/stream/scenes/main_game.tscn").instantiate()
	game.get_node("AppBootstrap").repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(V08_OUTPUT))
	var state: PlayerState = game.app.stream.state
	game._start_content("just_chatting")
	game.app.events.next_at = 100000
	await _capture("xp_level1")
	state.xp = 99
	state.hype = 0
	game._room_tapped(game.room.size / 2)
	_check(state.level == 2 and "LEVEL UP" in game.toast.text and not game.modal_layer.visible, "Nonblocking level feedback")
	await _capture("xp_level_up")
	state.hype = 100
	game.room.floating_pool._process(1)
	# Use the domain result directly; physical rate limiting is covered by existing input tests.
	var result: OperationResult = game.app.stream.click()
	game.room.react(game.room.size / 2, result.context["hype"], result.context["xp"])
	var pool: FloatingTextPool = game.room.floating_pool
	var active: Label = pool._labels[(pool._next + pool.CAPACITY - 1) % pool.CAPACITY]
	_check("XP" in active.text and active.text.count("+") == 1, "MAX feedback contains XP only")
	_check(pool.get_child_count() == 16, "Click feedback reuses one existing label per click")
	await _capture("hype_max_click")
	game.app.stream.finish()
	game._close_modal()
	game.room.floating_pool._process(1)
	game._process(6.1)
	state.fatigue = 56
	for i: int in range(6):
		game.app.stream.tick()
	_check(is_equal_approx(state.fatigue, 55), "Fatigue displayed without reopening menu")
	await _capture("fatigue_recovery")
	state.money = 100
	state.fatigue = 0
	game._start_content("cooking")
	_check(state.is_streaming and game.modal_kind != "cosplay", "Cooking starts without pre-stream costume selection")
	game._show_moves(false)
	await _capture("moves_cosplay_available")
	_check(game.app.moves.active_cosplay == null, "Cosplay starts unused")
	game.app.stream.perform_move("cosplay:basic_cosplay")
	game._show_moves(false)
	_check(game.app.moves.active_cosplay != null, "Cosplay active in Moves")
	for button: Node in game.modal_body.get_children():
		if button is Button and str(button.get_meta("move_id", "")).begins_with("cosplay:"):
			_check(button.disabled, "Used cosplay disabled")
	await _capture("moves_cosplay_used")
	game._close_modal()
	var stats: StreamSessionStats = StreamSessionStats.new()
	for viewers: int in [2, 4, 10, 6]:
		stats.observe(viewers, 24.1)
	stats.game_minutes = 4
	game.app.stream.elapsed = 4
	game.app.stream.session_stats = stats
	state.average_online = 24.1
	game.app.stream.finish()
	var before: Dictionary = game.app.stream.summary.duplicate(true)
	var followers: int = state.followers
	game._show_summary(before)
	_check(_contains_label("5.5") and not _contains_label("24.1"), "Summary shows session average 5.5, never unrelated 24.1")
	_check(game.app.stream.summary == before and state.followers == followers, "Reopening summary does not recalculate rewards")
	await _capture("stream_summary_stats")
	game.queue_free()
	await process_frame
	print("V08 UI SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _capture(filename: String) -> void:
	if OS.get_environment("SASA_NO_SCREENSHOTS") == "1":
		await process_frame
		await process_frame
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_check(Rect2(Vector2.ZERO, game.size).encloses(game.primary.get_global_rect()), "Main UI fits")
	if game.modal_layer.visible:
		_check(Rect2(Vector2.ZERO, game.size).encloses(game.get_node("%ModalPanel").get_global_rect()), "Modal fits " + filename)
	_check(root.get_texture().get_image().save_png(V08_OUTPUT + filename + ".png") == OK, "Capture " + filename)

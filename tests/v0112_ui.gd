extends "res://tests/typography_smoke.gd"

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = load("res://src/features/stream/scenes/main_game.tscn").instantiate()
	game.get_node("AppBootstrap").repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	_check(not game.room.has_node("Stage/Desk/RightMonitor/ChatClip"), "Legacy chat nodes removed")
	_check(game.room.monitor_status.text.ends_with("OFFLINE"), "Offline status")
	for dimensions: Vector2 in [Vector2(336, 210), Vector2(336, 320)]:
		game.room.size = dimensions
		game.room._fit_stage()
		_check(is_equal_approx(game.room._stage.scale.x * RoomView.DESIGN_SIZE.x, dimensions.x), "Background covers full viewport width")
		_check(game.room.get_node("Stage/AdaptiveBackdrop/LeftWall").size.y >= 181, "Left transparent cutout covered")
	await _preview()
	game._show_achievements()
	await process_frame
	await process_frame
	var before: int = get_processed_tweens().size()
	game._achievement_selected("first_collab")
	_check(get_processed_tweens().size() <= before, "Selection does not restart availability animations")
	_check("Заблокировано" in game.achievement_detail.text, "Popup uses public locked status")
	game._achievement_selected("irl_collab_iceicell")
	_check("iceicell" in game.achievement_detail.text and "0 / 1" in game.achievement_detail.text, "Creator-specific popup progress")
	await _preview()
	game._close_modal()
	game._show_short_forms()
	for item: ShortFormDefinition in game.app.catalog.short_forms.values():
		_check(item.icon != null or SasaUI.DEFAULT_CONTENT != null, "Short-form icon fallback")
	game._show_moves(false)
	await _preview()
	game._close_modal()
	_check(game.app.stream.start().success, "Stream starts")
	game.room.present(game.app.stream.state)
	_check(game.room.monitor_status.text.ends_with("LIVE"), "Live status")
	var original: int = game.app.stream.state.followers
	var result: OperationResult = game.app.stream.click()
	_check(game.app.stream.state.followers == original + result.context.xp, "XP updates followers in UI path")
	# Optional status node removal must not crash any presentation callback.
	game.room.monitor_status.free()
	game.room.monitor_status = null
	game.room.present(game.app.stream.state)
	game.room._process(0.1)
	game.app.queue.cancel()
	game.queue_free()
	await process_frame
	print("V0112 UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _preview() -> void:
	await process_frame
	await process_frame
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		# In-memory inspection only: never persist screenshot evidence.
		print("PREVIEW:" + Marshalls.raw_to_base64(root.get_texture().get_image().save_jpg_to_buffer(0.85)))

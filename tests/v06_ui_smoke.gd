extends "res://tests/typography_smoke.gd"
var now: int = 1000

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = (load("res://src/features/stream/scenes/main_game.tscn") as PackedScene).instantiate()
	(game.get_node("AppBootstrap") as AppBootstrap).repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	game.app.collaborations.clock = func() -> int: return now
	game.app.collaborations.random = RandomProvider.new(42)
	game.app.inbound.clock = func() -> int: return now
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_check(game.get_node_or_null("%GamesButton") == null, "Duplicate Games navigation removed")
	game._primary_pressed()
	_check(game.modal_kind == "games", "Primary button opens sole stream selector")
	game._close_modal()
	var state: PlayerState = game.app.stream.state
	for followers: int in [100, 2000000]:
		state.followers = followers
		state.fatigue = 0
		state.last_stream_types.clear()
		game.app.stream.start()
		game.app.stream.stream_variance = 1
		for i: int in range(80):
			state.hype = 50
			game.app.stream.tick()
		game._close_modal()
		await _capture("main_100_followers" if followers == 100 else "main_2m_followers_debug")
		game.app.stream.finish()
		game._close_modal()
	state.followers = 1000
	state.average_online = 25
	state.fatigue = 0
	game._show_collaborations()
	await _capture("collabs_initial")
	var before: Array[String] = game._shown_candidate_ids.duplicate()
	var creator: String = before[0]
	game._show_collab_formats(creator)
	now = 1120
	game._refresh()
	_check(game.modal_kind == "collab_formats" and game.modal_title.text == game.app.catalog.streamers[creator].display_name, "Profile survives rotation boundary")
	game._close_modal()
	_check(game.modal_kind == "collaborations" and game._shown_candidate_ids != before, "Returning applies candidate refresh")
	await _capture("collabs_after_refresh")
	state.incoming_collab_queue = [{"creator_id": creator, "format": "just_chatting", "created_at": now, "expires_at": now + 1200, "accepted": false}]
	game._show_incoming()
	await _capture("incoming_collab")
	game._close_modal()
	for resolution: Vector2i in [Vector2i(360, 640), Vector2i(390, 844)]:
		state.unlocked_achievements.erase("slay_king")
		root.size = resolution
		await process_frame
		await process_frame
		game._show_achievements()
		await process_frame
		await process_frame
		var pan: AchievementPan = game.achievement_tree.get_parent()
		_check(not pan.get_h_scroll_bar().visible and not pan.get_v_scroll_bar().visible and not game.modal_scroll.get_v_scroll_bar().visible, "No visible default achievement scrollbars")
		await _capture("achievements_start")
		pan.scroll_horizontal = int((game.achievement_tree.size.x - pan.size.x) / 2)
		pan.scroll_vertical = int((game.achievement_tree.size.y - pan.size.y) / 2)
		await _capture("achievements_center")
		for button: Button in game.achievement_tree.buttons.values():
			pan.focus_node(button)
			await process_frame
			_check(pan.get_global_rect().grow(2).encloses(button.get_global_rect()), "All graph nodes fully reachable")
		var right: Button = game.achievement_tree.buttons["room_complete"]
		pan.focus_node(right)
		await _capture("achievements_right")
		await _capture("achievements_far_right")
		pan.focus_node(game.achievement_tree.buttons["slay_king"])
		await _capture("achievements_bottom")
		state.unlocked_achievements.append("slay_king")
		game.achievement_tree.refresh(true)
		(pan.get_parent().get_node("Progress") as Label).text = "%d / %d" % [state.unlocked_achievements.size(), game.app.catalog.achievements.size()]
		await _capture("achievements_completed")
		pan.scroll_horizontal = 100
		pan.scroll_vertical = 100
		var at: Vector2 = pan.get_global_rect().get_center()
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.position = at
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = true
		pan._input(mouse)
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = at - Vector2(30, 30)
		pan._input(motion)
		mouse.pressed = false
		pan._input(mouse)
		_check(pan.scroll_horizontal > 100 and pan.scroll_vertical > 100, "Mouse pan moves both axes")
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.position = at
		touch.pressed = true
		pan._input(touch)
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.position = at - Vector2(30, 30)
		pan._input(drag)
		touch.pressed = false
		pan._input(touch)
		_check(pan.scroll_horizontal > 130, "Touch pan works")
		var horizontal: int = pan.scroll_horizontal
		mouse.button_index = MOUSE_BUTTON_WHEEL_DOWN
		mouse.shift_pressed = true
		mouse.pressed = true
		pan._input(mouse)
		_check(pan.scroll_horizontal > horizontal, "Shift wheel scrolls horizontally")
		game._achievement_selected("followers_100")
		_check(game.achievement_popup.visible and "Награда" in game.achievement_detail.text, "Achievement details popup includes reward")
		game._close_modal()
	game.queue_free()
	await process_frame
	print("V06 UI SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)

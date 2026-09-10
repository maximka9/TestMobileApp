extends "res://tests/typography_smoke.gd"

var now: int = 0
var mono: int = 1000
const V07_OUTPUT: String = "res://build/checks/v0.7/"

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = load("res://src/features/stream/scenes/main_game.tscn").instantiate()
	game.get_node("AppBootstrap").repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	game.app.collaborations.clock = func() -> int: return now
	game.app.collaborations.random = RandomProvider.new(42)
	game.app.inbound.clock = func() -> int: return now
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(V07_OUTPUT))
	game.room.set_process(false)
	var state: PlayerState = game.app.stream.state
	state.followers = 100
	await _capture("chat_offline")
	_check(game.room.chat.generated == 0, "Offline room starts empty")
	game._show_settings()
	for child: Node in game.modal_body.get_children():
		_check(not child is Button or child.text != "Локации", "No manual location UI")
	game._close_modal()
	game.app._tick_accumulator = 0.99
	game._start_content("dota_2")
	_check(game.app._tick_accumulator == 0, "New stream starts with a fresh monotonic tick")
	game.room.set_process(false)
	for online: int in [5, 100, 1000]:
		state.viewers = online
		state.hype = 60
		game._refresh()
		for i: int in range(1000):
			game.room._process(0.1)
		game.room._process(0.3)
		var clip: Control = game.room.get_node("Stage/Desk/RightMonitor/ScreenClip")
		_check(clip.clip_contents and clip.get_global_rect().encloses(game.room._chat_content.get_global_rect()), "Chat content contained by physical monitor screen")
		_check(game.room._chat_rows.size() == 5 and game.room._chat_lines.size() == 5, "Five reused chat rows")
		await _capture("chat_%d_viewers" % online)
	game.app.monotonic_clock = func() -> int: return mono
	game.app._last_tick_msec = mono
	game.app._tick_accumulator = 0
	game.app.events.next_at = 100000
	mono += 30000
	game.app._process(0.001)
	_check(game.app.stream.elapsed == 30 and game.status.text.ends_with("00:30"), "Monotonic foreground clock drives game time independently of frame delta")
	await _capture("stream_30_game_minutes")
	mono += 60000
	game.app._process(0.001)
	_check(game.app.stream.elapsed == 90 and game.status.text.ends_with("01:30"), "Ninety seconds becomes 1h30")
	await _capture("stream_1h30_game_time")
	game.app.stream.finish()
	_check(_contains_label("1 ч 30 мин"), "Summary explicitly renders hours and minutes")
	game._close_modal()
	for id: String in ["dota_2", "just_chatting", "cooking", "irl"]:
		state.fatigue = 0
		game._start_content(id)
		_check(game.app.stream.state.is_streaming, "UI starts " + id)
		_check(game.get_node("%LocationContainer").get_child_count() == 1, "One active location scene")
		await _capture({"dota_2": "dota_room", "just_chatting": "just_chatting_room", "cooking": "cooking_kitchen", "irl": "irl_city"}[id])
		game.app.stream.finish()
		game._close_modal()
		_check(state.current_location_id == "streamer_room" and game._location_id == "streamer_room", "Continue returns scene home")
	game._show_collaborations()
	var initial: Array[String] = game._shown_candidate_ids.duplicate()
	await _capture("collabs_before_refresh")
	now = 59
	game._process(0.1)
	_check(game._shown_candidate_ids == initial and game.collab_timer_label.text.ends_with("00:01"), "Visible list countdown 119")
	now = 60
	game._process(0.1)
	_check(game._shown_candidate_ids != initial and game._shown_candidate_ids.size() == 10 and game.collab_timer_label.text.ends_with("01:00"), "Visible cards refresh immediately at 120 without stream tick")
	await _capture("collabs_after_refresh")
	var generation: int = game.app.collaborations.candidate_generation
	game._show_collab_formats(game._shown_candidate_ids[0])
	now = 120
	game._process(0.1)
	_check(game.refresh_pending and game.modal_kind == "collab_formats" and game.app.collaborations.candidate_generation == generation, "Details retained with pending refresh")
	game._close_modal()
	_check(not game.refresh_pending and game.app.collaborations.candidate_generation == generation + 1, "Return immediately refreshes list")
	game._close_modal()
	now = 500
	game._process(0.1)
	_check(game.app.collaborations.candidate_generation == generation + 1, "Closed screen has no polling")
	game._show_collaborations()
	_check(game.app.collaborations.candidate_generation == generation + 2, "Reopen refreshes expired list")
	game.queue_free()
	await process_frame
	print("V07 UI SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _contains_label(value: String) -> bool:
	for label: Node in game.modal_body.find_children("*", "Label", true, false):
		if value in label.text:
			return true
	return false

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_check(Rect2(Vector2.ZERO, game.size).encloses(game.primary.get_global_rect()), "Main UI fits")
	if game.modal_layer.visible:
		_check(Rect2(Vector2.ZERO, game.size).encloses(game.get_node("%ModalPanel").get_global_rect()), "Modal fits " + filename)
	_check(root.get_texture().get_image().save_png(V07_OUTPUT + filename + ".png") == OK, "Capture " + filename)

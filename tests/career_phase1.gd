extends "res://tests/test_runner.gd"
## Phase-scoped fixtures reuse the existing harness; no renderer or real save files.

func _run() -> void:
	_test_fatigue_and_reach()
	_test_history_and_novelty()
	_test_career_save()
	_test_stream()
	_test_moves()
	_test_save()
	_test_flow()
	print("CAREER PHASE 1: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_fatigue_and_reach() -> void:
	_fixture()
	config.starting_followers = 45
	config.starting_fatigue = 12
	var initial: PlayerState = stream.career.new_player()
	check(initial.followers == 45 and initial.fatigue == 12, "Configured starting state")
	stream.start()
	stream.tick()
	check(is_equal_approx(state.fatigue, config.fatigue_rate * 0.8), "Fatigue grows by content multiplier")
	state.fatigue = 99.99
	stream.tick()
	check(state.fatigue == 100 and state.energy == 0, "Fatigue caps; energy is inverse view")
	stream.finish()
	stream.continue_to_room()
	check(stream.start().error_code == &"EXHAUSTED" and not state.is_streaming, "Exhaustion blocks starting atomically")
	state.fatigue = config.exhaustion_threshold - 0.1
	check(stream.start().success, "Below exhaustion threshold permits start")
	state.fatigue = 0
	var fresh: float = stream.career.efficiency(state)
	state.fatigue = 90
	check(stream.career.efficiency(state) < fresh, "High fatigue reduces efficiency")
	state.followers = 100
	var small: float = stream.career.audience(state, 1)
	state.followers = 10000
	var large: float = stream.career.audience(state, 1)
	check(large > small and large < small * 100, "Audience growth is sublinear")
	state.followers = 1000000000000
	check(stream.career.audience(state, 100000) < config.audience_soft_cap, "Audience soft cap bounds huge channels")
	_fixture()
	stream.start()
	for i: int in range(180):
		stream.click()
		stream.tick()
	stream.finish()
	check(state.followers < 50 and state.lifetime_peak_viewers < 100, "Three beginner minutes do not create a top streamer")

func _test_history_and_novelty() -> void:
	_fixture()
	check(stream.career.novelty(state, "dota_2") == 1, "First format has full novelty")
	state.last_stream_types = ["dota_2"]
	var second: float = stream.career.novelty(state, "dota_2")
	state.last_stream_types.append("dota_2")
	check(second < 1 and stream.career.novelty(state, "dota_2") < second, "Repeated formats progressively lose novelty")
	state.last_stream_types.append("irl")
	state.last_stream_types.append("just_chatting")
	check(stream.career.novelty(state, "dota_2") == 1, "Variety restores novelty")
	config.history_limit = 3
	config.average_window = 2
	config.novelty_window = 2
	for i: int in range(1, 5):
		stream.career.complete(state, {"average": i * 10.0, "seconds": 100, "peak": i * 20, "money": i}, 1.0, i)
	check(state.stream_history.size() == 3 and state.last_stream_types.size() == 2, "History and novelty memory are bounded")
	check(state.average_online == 35 and state.lifetime_peak_viewers == 80, "Rolling average uses recent completed streams")
	check(state.followers > 30 and state.lifetime_followers_gained == state.followers - 30, "Followers accumulate persistently")
	_fixture()
	stream.start()
	stream.tick()
	stream.finish()
	var count: int = state.stream_history.size()
	check(not stream.finish().success and state.stream_history.size() == count, "Finishing twice cannot duplicate career rewards")
	check(state.streams_completed == state.total_streams and state.streams_completed == 1, "Completed stream count has one source")

func _test_career_save() -> void:
	_fixture()
	saves.clock = func() -> int: return 1000
	state.followers = 123
	state.fatigue = 60
	stream.career.complete(state, {"average": 12.5, "seconds": 100, "peak": 20, "money": 3}, 0.85, 900)
	var document: Dictionary = saves.serialize(state)
	var result: OperationResult = saves.deserialize(JSON.parse_string(JSON.stringify(document)))
	check(result.success, "Career JSON loads")
	var restored: PlayerState = result.context["state"]
	check(restored.followers == state.followers and restored.fatigue == 60 and restored.stream_history.size() == 1 and restored.stream_history[0]["average_viewers"] == 12.5 and restored.stream_history[0]["duration"] == 100, "Followers fatigue and history survive JSON")
	check(restored.average_online == 12.5 and restored.last_stream_types == state.last_stream_types, "Average and novelty persist")
	check(not document["player"].has("energy"), "New save has only one fatigue meter")
	repo.document = document
	saves.clock = func() -> int: return 1100
	check(is_equal_approx(saves.load_player().fatigue, 50), "Offline recovery applies on load")
	saves.clock = func() -> int: return 900
	check(saves.load_player().fatigue == 60, "Backward clock grants no recovery")
	config.offline_recovery_cap = 10
	saves.clock = func() -> int: return 100000
	check(saves.load_player().fatigue == 59, "Offline recovery window is capped")
	repo.document["player"]["was_streaming"] = true
	check(saves.load_player().fatigue == 60, "Saved active streams receive no offline recovery")
	var legacy: Dictionary = {"version": 1, "timestamp": 1000, "player": {"level": 2, "xp": 3, "money": 99, "energy": 40.0, "current_stream_type_id": "irl", "total_clicks": 10, "total_streams": 4, "upgrades": {}, "settings": {"reduced_motion": true}}}
	result = saves.deserialize(legacy)
	check(result.success, "Actual v0.3 schema migrates explicitly")
	restored = result.context["state"]
	check(restored.money == 99 and restored.fatigue == 60 and restored.followers == config.starting_followers and restored.total_streams == 4, "Migration preserves old progress and derives fatigue")
	for invalid: Variant in [-1, "123", 0.5, INF]:
		var bad: Dictionary = document.duplicate(true)
		bad["player"]["followers"] = invalid
		check(not saves.deserialize(bad).success, "Reject invalid follower field")
	var malformed: Dictionary = document.duplicate(true)
	malformed["player"]["stream_history"][0]["average_viewers"] = -1
	check(not saves.deserialize(malformed).success, "Reject malformed history")

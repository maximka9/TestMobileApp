extends "res://tests/test_runner.gd"

var now: int = 0

func _run() -> void:
	_test_time_and_locations()
	_test_organic()
	_test_chat()
	_test_rotation_and_events()
	_test_simulation()
	print("V07 SYSTEMS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_time_and_locations() -> void:
	_fixture()
	var seconds: Array[int] = [0, 1, 30, 59, 60, 90, 360]
	var labels: Array[String] = ["00:00", "00:01", "00:30", "00:59", "01:00", "01:30", "06:00"]
	for i: int in range(seconds.size()):
		check(StreamTime.format_live(seconds[i]) == labels[i], "Game HH:MM " + str(seconds[i]))
	check(StreamTime.format_summary(30) == "30 мин" and StreamTime.format_summary(90) == "1 ч 30 мин", "Explicit summary units")
	for id: String in ["dota_2", "just_chatting", "cooking", "irl"]:
		state.fatigue = 0
		stream.select_content(id)
		check(stream.start().success, "Automatic start " + id)
		check(state.current_location_id == {"dota_2": "streamer_room", "just_chatting": "streamer_room", "cooking": "kitchen", "irl": "city"}[id], "Mapped location " + id)
		check(not stream.select_location("kitchen").success, "Manual switch rejected")
		for i: int in range(30):
			stream.tick()
		check(state.fatigue < 10, "Thirty game minutes not exhausting " + id)
		stream.finish()
		check(stream.summary["game_minutes"] == 30, "Summary game minutes")
		stream.continue_to_room()
		check(state.current_location_id == "streamer_room", "Summary returns home")
	state.fatigue = 50
	state.fatigue_recovery_seconds = 0
	for i: int in range(59):
		stream.tick()
	check(is_equal_approx(state.fatigue, 50 - 59 * 10.0 / 60), "Rest progresses before minute boundary")
	stream.tick()
	check(is_equal_approx(state.fatigue, 40), "Ten fatigue restored at 60 real seconds")
	var document: Dictionary = saves.serialize(state)
	check(document["version"] == SaveService.VERSION and saves.deserialize(document).success, "v0.6 save schema retained and readable")
	check(Engine.time_scale == 1.0, "Global time scale unchanged")

func _test_organic() -> void:
	_fixture()
	var growth: FollowerGrowthService = FollowerGrowthService.new(config)
	growth.random = RandomProvider.new(7)
	var normal: float = growth.expected_stream_gain(5, 30, 60, 1, 50)
	check(normal > 2 and normal < 3, "Early ordinary stream has meaningful chance")
	check(growth.expected_stream_gain(7, 30, 90, 1, 50) > 4 and growth.expected_stream_gain(7, 30, 90, 1, 50) < 5, "Good early stream yields 4 to 5")
	check(growth.expected_stream_gain(10, 30, 60, 1, 50) > normal, "Online improves expected gain")
	check(growth.expected_stream_gain(5, 60, 60, 1, 50) > normal, "Duration improves expected gain")
	check(growth.expected_stream_gain(5, 30, 90, 1, 50) > normal, "Hype improves expected gain")
	check(growth.expected_stream_gain(5, 30, 60, 0.45, 50) < normal, "Novelty penalizes repeats")
	check(growth.expected_stream_gain(5, 30, 60, 1, 100) > normal, "Reputation modifier")
	growth.career_tier = 3
	check(growth.expected_stream_gain(5, 30, 60, 1, 50) < normal, "Career tier modifier")
	growth.career_tier = 0
	check(growth.expected_stream_gain(5, 100000, 0, 1, 50) == 0, "Idle time alone never grows followers")
	check(growth.expected_stream_gain(0, 120, 100, 1, 50) == 0, "No viewers no followers")
	check(growth.expected_stream_gain(5, 100000, 80, 1, 50) == growth.expected_stream_gain(5, 120, 80, 1, 50), "Exposure duration capped")
	check(growth.calculate_tiktok_gain(1, 100, 50) > growth.expected_stream_gain(7, 30, 90, 1, 50), "Normal TikTok stronger than good ordinary stream")
	check(growth.calculate_collab_gain(catalog.streamers["fixture_01"], 100) > normal * 5, "Successful collab remains stronger")
	var zeros: int = 0
	var total: int = 0
	for i: int in range(500):
		zeros += 1 if growth.calculate_stream_gain(5, 1, 50, 1, 50) == 0 else 0
		total += growth.calculate_stream_gain(5, 30, 60, 1, 50)
	check(zeros > 450 and total > 950 and total < 1100, "Seeded stochastic gain, no short-stream guarantee")
	state.followers = 100
	stream.start()
	for i: int in range(100):
		stream.click()
	check(state.followers == 100 and state.hype <= 100, "Clicks never directly award followers")
	state.hype = 0
	state.level = 10000
	stream.click()
	check(state.hype <= StreamService.BASE_HYPE_PER_CLICK, "High level single click remains bounded")

func _test_chat() -> void:
	_fixture()
	var counts: Array[int] = []
	for viewers: int in [0, 5, 100, 1000]:
		var chat: ChatActivityService = ChatActivityService.new(config, RandomProvider.new(42))
		for frame: int in range(6000):
			chat.advance(0.01, true, viewers, 50)
		counts.append(chat.generated)
		check(chat.participants.size() == 12, "Bounded session participants " + str(viewers))
		var names: PackedStringArray = chat.participants.duplicate()
		chat.advance(1, true, viewers, 50)
		check(chat.participants == names, "Session nicknames reused")
		var before: int = chat.generated
		chat.advance(10000, false, viewers, 100)
		check(chat.generated == before, "Offline never generates messages")
	check(counts[0] == 0 and counts[1] >= 8 and counts[1] <= 15, "Zero viewers silent; five viewers slow")
	check(counts[1] < counts[2] and counts[2] < counts[3] and counts[3] <= 120, "Chat scales with viewers and is bounded")
	var chat: ChatActivityService = ChatActivityService.new(config)
	check(chat.interval(100, 100) < chat.interval(100, 50) and chat.interval(100000, 100) >= 0.25, "Hype cadence and absolute cap")

func _test_rotation_and_events() -> void:
	_fixture()
	var service: CollaborationService = CollaborationService.new(catalog, config, ScriptedRandomProvider.new([0]))
	service.clock = func() -> int: return now
	now = 0
	var first: Array[String] = service.candidates(state)
	check(service.candidate_generation == 1 and state.collab_candidate_refresh_at == 60, "First generation at zero")
	now = 59
	check(service.candidates(state) == first and service.candidate_generation == 1, "No refresh at 59")
	now = 60
	check(service.candidates(state) != first and service.candidate_generation == 2 and state.collab_candidate_refresh_at == 120, "Refresh at 60, next 120")
	for i: int in range(10):
		var before: Array[String] = service.candidates(state)
		state.recent_candidate_ids.clear()
		var after: Array[String] = service.refresh_candidates(state)
		before.sort()
		after.sort()
		check(before != after and after.size() == 10, "Anti-repeat even with fixed RNG")
	var inbound: InboundCollabService = InboundCollabService.new(service, config, ScriptedRandomProvider.new([0]))
	inbound.clock = func() -> int: return now
	var generation: int = service.candidate_generation
	var before_invite: Array[String] = state.collab_candidate_ids.duplicate()
	now += 60
	state.inbound_next_check_at = now
	inbound.poll(state)
	check(service.candidate_generation == generation and state.collab_candidate_ids == before_invite, "Incoming poll never rotates open creator details")
	var production: ContentCatalog = ContentCatalog.new()
	check(production.validate_event_creators().is_empty() and production.events.size() == 14, "Production event creator validation")
	var invalid: ActionDefinition = ActionDefinition.new()
	invalid.id = "invalid"
	invalid.creator_id = "unknown_creator_55"
	production.events[invalid.id] = invalid
	check(not production.validate_event_creators().is_empty(), "Unknown creator fails validation")
	invalid.creator_id = str(production.streamers.keys()[0])
	check(production.validate_event_creators().is_empty(), "Known creator accepted")
	invalid.reputation_delta = -1
	check(not production.validate_event_creators().is_empty(), "Negative named creator rejected")

func _test_simulation() -> void:
	_fixture()
	var clicks_to_growth: Array[int] = []
	var observed_online: float = 0
	for seed_value: int in range(100):
		state = PlayerState.new()
		state.followers = 100
		state.current_stream_type_id = "dota_2"
		stream.state = state
		stream.random = RandomProvider.new(seed_value)
		var clicks: int = 0
		for session: int in range(20):
			state.fatigue = 0 # Full rest between sessions, no direct growth reward.
			stream.start()
			for second: int in range(30):
				stream.click()
				stream.click()
				clicks += 2
				stream.tick()
			stream.finish()
			observed_online += float(stream.summary["average"])
			var followers: int = state.followers
			check(not stream.finish().success and state.followers == followers, "Finish cannot reward twice")
			stream.continue_to_room()
			if state.followers > 100:
				break
		clicks_to_growth.append(clicks if state.followers > 100 else 100000)
	clicks_to_growth.sort()
	var median: int = clicks_to_growth[50]
	check(median == 100000, "Short low-hype streams do not guarantee growth")
	print("SIMULATION: 100 seeds, 2 clicks/sec, 30 game-minute Dota sessions; median first organic growth = %d physical clicks" % median)
	# v0.6 has no ordinary organic path; its ordinary-only first-growth median is censored.
	_fixture()
	config.organic_exposure_conversion = 0
	stream.start()
	for i: int in range(1200):
		stream.click()
		if i % 2 == 0:
			stream.tick()
	stream.finish()
	check(stream.summary["organic_followers"] == 0, "v0.6 ordinary-only baseline has no growth after 1200 clicks")

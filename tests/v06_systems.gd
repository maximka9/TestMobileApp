extends "res://tests/test_runner.gd"

func _run() -> void:
	_test_curve()
	_test_growth()
	_test_collabs()
	_test_rotation()
	_test_distribution_and_variance()
	print("V06 SYSTEMS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_curve() -> void:
	_fixture()
	check(is_equal_approx(AudienceCurve.baseline(100, config), 4), "100 followers baseline four")
	check(is_equal_approx(AudienceCurve.baseline(2000000, config), 12000), "2M followers baseline 12K")
	check(AudienceCurve.baseline(85, config) < 7, "85 follower regression")
	var previous: float = 0
	for i: int in range(1, 201):
		var value: float = AudienceCurve.baseline(int(pow(1.1, i)), config)
		check(value >= previous, "Monotone audience curve " + str(i))
		previous = value
	check(absf(AudienceCurve.baseline(999999, config) - AudienceCurve.baseline(1000001, config)) < 1, "Anchor continuity")
	state.followers = 1000
	stream.start()
	stream.stream_variance = 1
	state.hype = 50
	var neutral: float = stream.target_viewers()
	state.hype = 100
	check(is_equal_approx(stream.target_viewers(), neutral * 1.5), "Hype applied once")
	state.hype = 50
	state.fatigue = 90
	check(is_equal_approx(stream.target_viewers(), neutral * 0.7), "Viewer fatigue applied once")
	state.fatigue = 0
	stream.stream_novelty = 0.85
	check(is_equal_approx(stream.target_viewers(), neutral * 0.85), "Novelty applied once")
	stream.stream_novelty = 1
	state.collab_momentum = 0.3
	state.collab_momentum_streams = 3
	check(is_equal_approx(stream.target_viewers(), neutral * 1.3), "Collab boost applied once")
	stream.tick()
	check(state.viewers > 0 and state.viewers < stream.target_viewers(), "Online smoothing preserved")
	stream.finish()
	check(state.average_online == stream.summary["average"], "Average uses observed session viewers")
	check(state.collab_momentum_streams == 2 and state.collab_momentum < 0.3, "Collab boost decays per completed stream")

func _test_growth() -> void:
	_fixture()
	var original: int = state.followers
	progression.add_xp(state, 500)
	check(state.followers == original, "XP alone never awards followers")
	stream.start()
	stream.click()
	stream.finish()
	check(state.followers == original, "Click and ordinary stream only create material")
	var growth: FollowerGrowthService = FollowerGrowthService.new(config)
	var previous: int = -1
	for outcome: int in range(5):
		var gain: int = growth.calculate_tiktok_gain(outcome, 80, 50)
		check(gain > previous, "Distinct ordered TikTok outcome " + str(outcome))
		previous = gain
	check(growth.calculate_tiktok_gain(0, 80, 50) == 0, "Flop gives zero followers")
	check(growth.calculate_tiktok_gain(2, 80, 50) >= 10 and growth.calculate_tiktok_gain(3, 80, 50) >= 40, "Early good and viral gains meaningful")
	check(growth.calculate_tiktok_gain(4, 1000000000, 100) <= config.follower_gain_cap, "Growth soft cap")
	stream.continue_to_room()
	var shorts: ShortFormService = ShortFormService.new(catalog, config, ScriptedRandomProvider.new([0]))
	var result: OperationResult = shorts.publish(state, "meme")
	check(result.success and result.context["followers"] > 0 and result.context["views"] > result.context["followers"], "Successful short reports followers and views")

func _test_collabs() -> void:
	_fixture()
	var service: CollaborationService = CollaborationService.new(catalog, config, ScriptedRandomProvider.new([0]))
	service.clock = func() -> int: return 1000
	state.money = 0
	var before: int = state.followers
	var result: OperationResult = service.request(state, "fixture_01", "just_chatting")
	check(result.success and result.context["accepted"] and state.money == 0 and state.followers > before, "Outbound accepted at zero coins and grants followers")
	check(state.collab_momentum_streams == 3 and state.collab_momentum > 0, "Successful collab grants separate viewer boost")
	check(not service.request(state, "fixture_01", "just_chatting").success, "Cooldown blocks repeat")
	_fixture()
	service = CollaborationService.new(catalog, config, ScriptedRandomProvider.new([999999]))
	service.clock = func() -> int: return 1000
	state.money = 77
	result = service.request(state, "fixture_01", "just_chatting")
	check(result.success and not result.context["accepted"] and state.money == 77, "Rejection never changes coins")
	check(service.request(state, "fixture_01", "just_chatting").error_code == &"ON_COOLDOWN", "Rejected request cooldown")
	var inbound: InboundCollabService = InboundCollabService.new(service, config, ScriptedRandomProvider.new([0]))
	inbound.clock = func() -> int: return 1000
	state.inbound_next_check_at = 1000
	inbound.poll(state)
	check(not inbound.current(state).is_empty(), "Inbound invite generated with injected RNG")
	var invite: Dictionary = inbound.current(state).duplicate()
	before = state.followers
	check(inbound.respond(state, true).success and state.money == 77 and state.followers == before, "Accepting invite is free and does not duplicate completion reward")
	saves.clock = func() -> int: return 1000
	var loaded: OperationResult = saves.deserialize(saves.serialize(state))
	check(loaded.success and loaded.context["state"].incoming_collab_queue[0]["accepted"], "Accepted inbound persists")
	state = loaded.context["state"]
	check(inbound.complete(state, invite["format"], 29) == 0, "Short stream cannot complete incoming collab")
	check(inbound.complete(state, invite["format"], 30) > 0 and state.followers > before and state.money == 77, "Incoming completion awards followers without coins")
	check(inbound.complete(state, invite["format"], 30) == 0, "Incoming reward exactly once")
	state.incoming_collab_queue = [invite]
	inbound.clock = func() -> int: return 100000
	check(inbound.current(state).is_empty(), "Incoming invitation expires")

func _test_rotation() -> void:
	_fixture()
	var service: CollaborationService = CollaborationService.new(catalog, config, RandomProvider.new(42))
	service.clock = func() -> int: return 1000
	var first: Array[String] = service.candidates(state)
	service.clock = func() -> int: return 1119
	check(service.candidates(state) == first, "119 seconds keeps candidate set")
	service.clock = func() -> int: return 1120
	var second: Array[String] = service.candidates(state)
	check(second != first and second.size() == 10, "120 seconds rotates ten candidates")
	service.clock = func() -> int: return 1240
	check(service.candidates(state) != second and state.recent_candidate_ids.size() <= 30, "240 seconds rotates with bounded recent history")
	service.clock = func() -> int: return 999999
	service.candidates(state)
	check(state.collab_candidate_refresh_at == 1000119, "Long absence triggers one refresh only")
	saves.clock = func() -> int: return 1000
	var loaded: OperationResult = saves.deserialize(saves.serialize(state))
	check(loaded.success and loaded.context["state"].collab_candidate_ids == state.collab_candidate_ids, "Rotation state persists")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save_v05.json"))
	loaded = saves.deserialize(old)
	check(loaded.success and loaded.context["state"].money == 99 and loaded.context["state"].content_sources.size() == 1 and loaded.context["state"].collab_candidate_ids.is_empty(), "0.5.1 schema 9 migrates without losing career content")

func _test_distribution_and_variance() -> void:
	_fixture()
	catalog.streamers.clear()
	for i: int in range(40):
		var author: StreamerDefinition = StreamerDefinition.new()
		author.id = "distribution_%d" % i
		author.reference_avg_viewers = 10 if i < 10 else 40 if i < 20 else 200 + i * 100
		author.collab_formats = ["just_chatting"]
		catalog.streamers[author.id] = author
	state.average_online = 40
	var service: CollaborationService = CollaborationService.new(catalog, config, RandomProvider.new(77))
	var counts: Array[int] = [0, 0, 0, 0]
	for id: String in service.candidates(state):
		var reach: int = service.profile(id).reference_avg_viewers
		counts[0 if reach < 20 else 1 if reach <= 80 else 2 if reach < 4000 else 3] += 1
	check(counts == [2, 4, 3, 1], "Deterministic candidate distribution 2/4/3/1")
	_fixture()
	stream.random = RandomProvider.new(123)
	stream.start()
	var variance: float = stream.stream_variance
	check(variance >= 0.85 and variance <= 1.15, "Per-stream variance stays inside configured bounds")
	_fixture()
	stream.random = RandomProvider.new(123)
	stream.start()
	check(is_equal_approx(variance, stream.stream_variance), "Injected seed reproduces stream variance")
	_fixture()
	service = CollaborationService.new(catalog, config, RandomProvider.new(77))
	var inbound: InboundCollabService = InboundCollabService.new(service, config, RandomProvider.new(77))
	inbound.clock = func() -> int: return 1000
	stream.inbound = inbound
	state.incoming_collab_queue = [{"creator_id": "fixture_01", "format": "just_chatting", "created_at": 1000, "expires_at": 2200, "accepted": true}]
	var before: int = state.followers
	stream.start()
	for i: int in range(30):
		stream.tick()
	stream.finish()
	check(state.followers > before and state.completed_collabs == 1 and state.incoming_collab_queue.is_empty(), "Real stream finish completes accepted inbound exactly once")

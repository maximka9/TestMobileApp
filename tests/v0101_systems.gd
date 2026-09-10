extends "res://tests/test_runner.gd"
var collabs: CollaborationService
var inbound: InboundCollabService

func _run() -> void:
	_test_parents()
	_test_conflicts()
	_test_atomic_requests()
	print("V0101 SYSTEMS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _setup() -> void:
	_fixture()
	catalog = ContentCatalog.new()
	upgrades = UpgradeService.new(catalog, config)
	saves = SaveService.new(repo, logger, catalog, upgrades)
	saves.clock = func() -> int: return 1000
	collabs = CollaborationService.new(catalog, config, ScriptedRandomProvider.new([0]))
	collabs.clock = func() -> int: return 1000
	inbound = InboundCollabService.new(collabs, config, ScriptedRandomProvider.new([0]))
	inbound.clock = func() -> int: return 1000

func _invite(id: String, accepted: bool = true) -> Dictionary:
	return {"creator_id": id, "format": "irl", "created_at": 900, "expires_at": 2000, "accepted": accepted}

func _test_parents() -> void:
	_setup()
	var service: AchievementService = AchievementService.new(catalog)
	state.stream_history.append({"stream_type": "cooking"})
	state.completed_collabs = 1
	state.completed_irl_collab_creator_ids.append("rostikfacekid")
	var signals: Array[String] = []
	service.achievement_unlocked.connect(func(id: String) -> void: signals.append(id))
	service.evaluate(state)
	check(not "first_cooking" in state.unlocked_achievements, "P1 cooking waits for viral_10")
	check(not "first_collab" in state.unlocked_achievements, "P1 first collab waits for 100 followers")
	check(not "irl_collab_rostikfacekid" in state.unlocked_achievements, "Legendary waits for first_collab")
	state.followers = 100
	state.viral_posts = 10
	# Child-first insertion deliberately differs from resource directory order.
	var reversed: Dictionary = {}
	var ids: Array = catalog.achievements.keys()
	ids.reverse()
	for id: String in ids:
		reversed[id] = catalog.achievements[id]
	catalog.achievements = reversed
	service.evaluate(state)
	check("first_cooking" in state.unlocked_achievements and "irl_collab_rostikfacekid" in state.unlocked_achievements, "Multi-level chain stabilizes in one evaluation")
	for pair: Array in [["followers_100", "first_collab"], ["first_collab", "irl_collab_rostikfacekid"], ["viral_post", "viral_10"], ["viral_10", "first_cooking"]]:
		check(signals.find(pair[0]) < signals.find(pair[1]), "Parent signal precedes child " + pair[1])
	var count: int = signals.size()
	service.evaluate(state)
	check(signals.size() == count, "No repeated unlock notification")
	state = PlayerState.new()
	state.unlocked_achievements.append("first_cooking")
	var old: Dictionary = saves.serialize(state)
	check(old.version == 12, "Schema unchanged")
	state = saves.deserialize(old).context["state"]
	service.evaluate(state)
	check("first_cooking" in state.unlocked_achievements, "Legacy inconsistent unlock retained")

func _test_conflicts() -> void:
	_setup()
	state.incoming_collab_queue = [_invite("iceicell")]
	var before: Dictionary = saves.serialize(state)
	check(collabs.request(state, "rostikfacekid", "irl").error_code == &"COLLAB_PENDING", "Accepted inbound blocks outbound")
	check(saves.serialize(state) == before, "Inbound guard is atomic")
	_setup()
	state.pending_outbound_collab = {"creator_id": "rostikfacekid", "format": "irl"}
	state.incoming_collab_queue = [_invite("iceicell", false)]
	before = saves.serialize(state)
	check(inbound.respond(state, true).error_code == &"COLLAB_PENDING", "Outbound blocks inbound acceptance")
	check(saves.serialize(state) == before, "Outbound guard is atomic")
	state.incoming_collab_queue.clear()
	state.inbound_next_check_at = 1
	inbound.poll(state)
	check(state.incoming_collab_queue.is_empty(), "No invite generated during outbound plan")
	for same: bool in [false, true]:
		_setup()
		state.level = 10
		state.incoming_collab_queue = [_invite("rostikfacekid" if same else "iceicell")]
		state.pending_outbound_collab = {"creator_id": "rostikfacekid", "format": "irl"}
		state = saves.deserialize(saves.serialize(state)).context["state"]
		stream = StreamService.new(state, catalog, config, progression, economy, upgrades, moves, events, logger)
		stream.inbound = inbound
		stream.select_content("irl")
		stream.start()
		events.next_at = 100000
		for i: int in range(29):
			stream.tick()
		stream.finish()
		check(state.completed_collabs == 0, "29 seconds cannot complete conflicting plans")
		stream.continue_to_room()
		stream.start()
		for i: int in range(30):
			stream.tick()
		stream.finish()
		check(state.completed_collabs == 1, "P1 one stream completes exactly one collab; same=" + str(same))
		check(state.incoming_collab_queue.is_empty() and not state.pending_outbound_collab.is_empty(), "Legacy inbound priority retains outbound")
		var followers: int = state.followers
		stream.finish()
		check(state.completed_collabs == 1 and state.followers == followers, "Repeated finish cannot reward")
		stream.continue_to_room()
		stream.start()
		for i: int in range(30):
			stream.tick()
		stream.finish()
		check(state.completed_collabs == 2 and state.pending_outbound_collab.is_empty(), "Next stream completes preserved outbound")

func _test_atomic_requests() -> void:
	for path: String in ["invalid", "streaming", "pending", "cooldown", "fatigue", "capacity", "clock"]:
		_setup()
		state.social_requests["rostikfacekid"] = {"start": 900, "last": 990, "count": config.social_spam_allowance + 1}
		var format: String = "irl"
		match path:
			"invalid": format = "missing"
			"streaming": state.is_streaming = true
			"pending": state.pending_outbound_collab = {"creator_id": "iceicell", "format": "irl"}
			"cooldown": state.collab_cooldowns["rostikfacekid"] = 2000
			"fatigue": state.fatigue = 100
			"capacity": config.social_profile_limit = 0
			"clock": collabs.clock = func() -> int: return 800
		var before: Dictionary = saves.serialize(state)
		check(not collabs.request(state, "rostikfacekid", format).success, "Blocked path " + path)
		check(saves.serialize(state) == before, "Failed request has no mutation " + path)

extends "res://tests/test_runner.gd"
var collabs: CollaborationService

func _setup(sequence: Array[int] = [999999]) -> void:
	_fixture()
	collabs = CollaborationService.new(catalog, config, ScriptedRandomProvider.new(sequence))
	collabs.clock = func() -> int: return 1000
	state.average_online = 40

func _run() -> void:
	_test_candidates()
	_test_chances()
	_test_requests()
	_test_collab_save()
	_test_events()
	_test_save()
	print("CAREER PHASE 4A: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_candidates() -> void:
	_setup()
	check(catalog.streamers.size() >= 20, "Fixture profiles remain available in production catalog")
	var selected: Array[String] = collabs.candidates(state)
	check(selected.size() == 10 and selected.any(func(id: String) -> bool: return int(catalog.streamers[id].reference_avg_viewers) >= 80000), "Ten candidates include aspirational author")
	var small: int = 0
	var near: int = 0
	for id: String in selected:
		var reach: int = catalog.streamers[id].reference_avg_viewers
		if reach < 20:
			small += 1
		elif reach <= 80:
			near += 1
	check(small == 2 and near == 4, "Selection fulfills smaller/peer quotas")
	state.viewers = 999999
	check(collabs.candidates(state) == selected, "Selection ignores instantaneous viewers")
	for id: String in catalog.streamers.keys():
		if id != "fixture_01":
			catalog.streamers.erase(id)
	check(collabs.candidates(state).size() == 1, "Small dataset degrades gracefully without duplicates")
	check(not "cooking" in collabs.formats("fixture_01"), "Unavailable formats excluded")

func _test_chances() -> void:
	_setup()
	var common: float = collabs.chance(state, "fixture_01", "just_chatting")
	check(common > collabs.chance(state, "fixture_01", "dota_2"), "Shared interest improves chance")
	var distant: float = collabs.chance(state, "fixture_20", "just_chatting")
	check(distant > 0 and distant < 0.01 and distant < common, "Huge audience gap is very unlikely but nonzero")
	state.reputation = 0
	var low: float = collabs.chance(state, "fixture_10", "just_chatting")
	state.reputation = 100
	check(collabs.chance(state, "fixture_10", "just_chatting") > low, "Reputation affects acceptance")
	state.relationships["fixture_10"] = -50
	low = collabs.chance(state, "fixture_10", "just_chatting")
	state.relationships["fixture_10"] = 50
	check(collabs.chance(state, "fixture_10", "just_chatting") > low, "Relationships affect acceptance")
	low = collabs.chance(state, "fixture_10", "just_chatting")
	state.growth_momentum = 50
	check(collabs.chance(state, "fixture_10", "just_chatting") > low, "Temporary momentum improves opportunity")
	check(collabs.chance(state, "fixture_10", "unknown") == 0, "Incompatible format has no chance")
	check(collabs.label(distant) == "ОЧЕНЬ НИЗКИЙ" and not collabs.reasons(state, "fixture_20", "just_chatting").is_empty(), "Qualitative chance and reasons available")

func _test_requests() -> void:
	_setup()
	var result: OperationResult = collabs.request(state, "fixture_01", "just_chatting")
	check(result.success and not result.context["accepted"] and state.relationships["fixture_01"] == -1, "Rejection changes relationship slightly")
	check(collabs.remaining(state, "fixture_01") == config.collab_cooldown_seconds, "Rejection starts cooldown")
	var before: float = state.reputation
	check(collabs.request(state, "fixture_01", "just_chatting").error_code == &"ON_COOLDOWN", "Cannot request during cooldown")
	collabs.request(state, "fixture_01", "just_chatting")
	check(state.reputation < before and state.relationships["fixture_01"] == -1, "Cooldown spam harms reputation without rerolling rejection")
	collabs.clock = func() -> int: return 1600
	check(collabs.remaining(state, "fixture_01") == 0 and collabs.request(state, "fixture_01", "just_chatting").success, "Cooldown expires at exact boundary")
	_setup([0])
	before = state.followers
	result = collabs.request(state, "fixture_20", "just_chatting")
	check(result.context["accepted"] and state.followers > before and state.completed_collabs == 1, "Successful collab grants followers once")
	check(state.followers - before <= config.collab_follower_cap and state.followers - before < 80000, "Success does not transfer creator audience")
	check(state.reputation > 50 and state.relationships["fixture_20"] > 0 and state.growth_momentum > 0, "Success grants social growth and momentum")
	before = state.followers
	collabs.request(state, "fixture_20", "just_chatting")
	check(state.followers == before and state.completed_collabs == 1, "Rapid duplicate success blocked")
	var boost: float = state.growth_momentum
	stream.start()
	check(collabs.request(state, "fixture_01", "just_chatting").error_code == &"BUSY_STREAMING", "Requests restricted to offline")
	stream.tick()
	stream.finish()
	check(state.growth_momentum < boost, "Collab momentum decays through existing stream lifecycle")
	_setup()
	var a: CollaborationService = CollaborationService.new(catalog, config, RandomProvider.new(88))
	var b: CollaborationService = CollaborationService.new(catalog, config, RandomProvider.new(88))
	a.clock = collabs.clock
	b.clock = collabs.clock
	var x: PlayerState = PlayerState.new()
	var y: PlayerState = PlayerState.new()
	var same: bool = true
	for id: String in catalog.streamers:
		same = same and a.request(x, id, "just_chatting").context["accepted"] == b.request(y, id, "just_chatting").context["accepted"]
	check(same and x.followers == y.followers, "Seeded request sequence deterministic")

func _test_collab_save() -> void:
	_setup([0])
	collabs.request(state, "fixture_01", "just_chatting")
	var document: Dictionary = saves.serialize(state)
	var result: OperationResult = saves.deserialize(JSON.parse_string(JSON.stringify(document)))
	check(result.success, "Collaboration save roundtrip")
	var loaded: PlayerState = result.context["state"]
	check(loaded.completed_collabs == 1 and collabs.remaining(loaded, "fixture_01") == 600, "Completion count and cooldown persist")
	check(collabs.request(loaded, "fixture_01", "just_chatting").error_code == &"ON_COOLDOWN", "Reload cannot bypass cooldown")
	var old: Dictionary = document.duplicate(true)
	old["version"] = 4
	old["player"].erase("collab_cooldowns")
	old["player"].erase("completed_collabs")
	result = saves.deserialize(old)
	loaded = result.context["state"]
	check(result.success and loaded.completed_collabs == 0 and loaded.collab_cooldowns.is_empty(), "Phase 3 migration preserves neutral collaboration state")
	for invalid: Variant in [-1, "tomorrow", 1.5]:
		var bad: Dictionary = document.duplicate(true)
		bad["player"]["collab_cooldowns"]["fixture_01"] = invalid
		check(not saves.deserialize(bad).success, "Malformed cooldown rejected")

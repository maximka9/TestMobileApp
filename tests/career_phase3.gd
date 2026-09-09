extends "res://tests/test_runner.gd"

func _run() -> void:
	_test_social()
	_test_social_events()
	_test_social_saves()
	_test_events()
	_test_save()
	print("CAREER PHASE 3: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_social() -> void:
	_fixture()
	var social: SocialService = events.social
	check(state.reputation == 50 and social.relationship(state, "a") == 0, "Neutral social defaults")
	config.starting_reputation = 65
	check(stream.career.new_player().reputation == 65, "Starting reputation configurable")
	social.change(state, "a", 2, 5)
	check(state.reputation == 52 and social.relationship(state, "a") == 5 and social.relationship(state, "b") == 0, "Relationships belong to individual authors")
	social.rejected(state, "a")
	check(state.reputation == 52 and social.relationship(state, "a") == 4, "Ordinary rejection only has small relationship penalty")
	var before: int = state.followers
	social.change(state, "a", -1000, -1000)
	check(state.reputation == 0 and social.relationship(state, "a") == -100 and state.followers == before, "Negative social effects bounded and do not destroy followers")
	var low: float = social.reputation_factor(state)
	social.change(state, "a", 1000, 1000)
	check(state.reputation == 100 and social.relationship(state, "a") == 100, "Positive social effects bounded")
	check(social.reputation_factor(state) > low and low > 0, "Reputation hook exposes bounded collab factor")
	check(not social.change(state, "", 0, 1).success and not social.change(state, "a", NAN, 0).success, "Invalid social changes rejected")
	social.record_request(state, "a", 100)
	social.record_request(state, "a", 101)
	check(state.reputation == 100, "Ordinary requests do not hurt reputation")
	var spam: OperationResult = social.record_request(state, "a", 102)
	check(spam.context["spam"] and state.reputation == 98, "Repeated requests trigger configured spam penalty")
	social.record_request(state, "b", 102)
	check(state.reputation == 98, "Request windows isolated per author")
	check(not social.record_request(state, "a", 99).success and state.reputation == 98, "Backward time cannot reset spam window")
	social.record_request(state, "a", 100 + config.social_spam_window)
	check(state.reputation == 98 and state.social_requests["a"]["count"] == 1, "Spam window expires at boundary")
	config.social_profile_limit = 2
	check(not social.record_request(state, "c", 500).success, "Request history bounded")

func _test_social_events() -> void:
	_fixture()
	stream.start()
	events.pending = catalog.events["community_help"]
	check(stream.resolve_event(true).success and state.reputation == 52 and state.relationships.is_empty(), "Accepted help event updates social state")
	check(not stream.resolve_event(true).success and state.reputation == 52, "Consumed event cannot reward twice")
	events.pending = catalog.events["community_taunt"]
	stream.resolve_event(false)
	check(state.reputation == 52 and state.relationships.is_empty(), "Skipping event leaves social state unchanged")
	events.pending = catalog.events["community_taunt"]
	stream.resolve_event(true)
	check(state.reputation == 49 and state.relationships.is_empty(), "Anonymous toxic choice reduces reputation without inventing a creator")
	state.fatigue = 100
	events.pending = catalog.events["community_help"]
	check(not stream.resolve_event(true).success and state.reputation == 49 and events.pending != null, "Failed action cannot grant social reward")

func _test_social_saves() -> void:
	_fixture()
	events.social.change(state, "a", 4, 12)
	events.social.change(state, "b", 0, -7)
	events.social.record_request(state, "a", 100)
	events.social.record_request(state, "a", 101)
	var document: Dictionary = saves.serialize(state)
	var result: OperationResult = saves.deserialize(JSON.parse_string(JSON.stringify(document)))
	check(result.success, "Social JSON roundtrip loads")
	var loaded: PlayerState = result.context["state"]
	check(loaded.reputation == 54 and loaded.relationships["a"] == 12 and loaded.relationships["b"] == -7, "Reputation and independent relationships persist")
	events.social.record_request(loaded, "a", 102)
	check(loaded.reputation == 52, "Reload cannot clear spam tracking")
	for version: int in [2, 3]:
		var old: Dictionary = document.duplicate(true)
		old["version"] = version
		for key: String in ["reputation", "relationships", "social_requests"]:
			old["player"].erase(key)
		result = saves.deserialize(old)
		loaded = result.context["state"]
		check(result.success and loaded.reputation == config.starting_reputation and loaded.relationships.is_empty(), "Earlier phase migrates social defaults %d" % version)
	for invalid: Variant in [-1, 101, NAN, "50"]:
		var bad: Dictionary = document.duplicate(true)
		bad["player"]["reputation"] = invalid
		check(not saves.deserialize(bad).success, "Invalid reputation rejected")
	var bad: Dictionary = document.duplicate(true)
	bad["player"]["relationships"]["a"] = 101
	check(not saves.deserialize(bad).success, "Out-of-range relationship rejected")
	bad = document.duplicate(true)
	bad["player"]["social_requests"]["a"]["last"] = 0
	check(not saves.deserialize(bad).success, "Invalid request timestamps rejected")
	bad = document.duplicate(true)
	bad["player"].erase("relationships")
	check(not saves.deserialize(bad).success, "New schema requires social fields")

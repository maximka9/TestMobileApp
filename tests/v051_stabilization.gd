extends "res://tests/test_runner.gd"

func _run() -> void:
	_fixture()
	_test_graph()
	_test_identities()
	_test_clocks()
	_test_historical_saves()
	print("V051 STABILIZATION: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_graph() -> void:
	check(ContentCatalog.validate_achievement_graph(catalog.achievements).is_empty(), "Production achievement graph valid")
	var a: AchievementDefinition = AchievementDefinition.new()
	var b: AchievementDefinition = AchievementDefinition.new()
	var graph: Dictionary = {"a": a, "b": b}
	a.parent_ids = ["a"]
	check(not ContentCatalog.validate_achievement_graph(graph).is_empty(), "Self cycle rejected")
	a.parent_ids = ["b"]
	b.parent_ids = ["a"]
	check(not ContentCatalog.validate_achievement_graph(graph).is_empty(), "Two-node cycle rejected")
	b.parent_ids = ["missing"]
	check(not ContentCatalog.validate_achievement_graph(graph).is_empty(), "Missing parent rejected")
	b.parent_ids = []
	check(ContentCatalog.validate_achievement_graph(graph).is_empty(), "Acyclic graph accepted")

func _test_identities() -> void:
	var profiles: Array = JSON.parse_string(FileAccess.get_file_as_string(ContentCatalog.STREAMER_CATALOG_PATH))["profiles"]
	check(profiles.size() >= 400, "Production requirement is 400+ verified profiles")
	check(ContentCatalog.validate_streamer_identities(profiles).is_empty(), "Production identity and date validation")
	var real: ContentCatalog = ContentCatalog.new()
	check(real.streamers.size() == profiles.size(), "Entire production snapshot loads offline")
	for profile: StreamerDefinition in real.streamers.values():
		check(not profile.is_placeholder and not profile.source.is_empty() and not profile.display_name.is_empty() and not profile.id.begins_with("fixture_") and not profile.id.begins_with("catalog_") and not profile.display_name.begins_with("CIS Creator"), "Public profile " + profile.id)
	for spelling: String in ["Streamer", "streamer", "STREAMER"]:
		check(not ContentCatalog.validate_streamer_identities([{"id": "a", "login": "streamer"}, {"id": "b", "login": spelling}]).is_empty(), "Case-insensitive login collision " + spelling)
	check(not ContentCatalog.validate_streamer_identities([{"id": "same"}, {"id": "same"}]).is_empty(), "Duplicate game ID rejected")
	check(not ContentCatalog.validate_streamer_identities([{"id": "a", "platform_user_id": "123"}, {"id": "b", "platform_user_id": "123"}]).is_empty(), "Duplicate external ID rejected")
	for date: String in ["2026-02-29", "2026-13-01", "2026-01-00", "2026-9-09", "garbage"]:
		check(not ContentCatalog.valid_date(date), "Invalid observation date " + date)
	check(ContentCatalog.valid_date("2024-02-29"), "Leap date accepted")

func _test_clocks() -> void:
	for seconds: int in [59, 60, 119, 120]:
		_fixture()
		state.fatigue = 80
		stream.career.recover(state, seconds)
		check(state.fatigue == 80 - int(seconds / 60.0) * 2, "Minute boundary " + str(seconds))
	for seconds: int in [86400, 2592000, 31536000]:
		_fixture()
		state.fatigue = 80
		stream.career.recover_offline(state, 1000, 1000 + seconds)
		check(state.fatigue >= 0 and state.fatigue <= 80, "Bounded long absence " + str(seconds))
	_fixture()
	state.fatigue = 80
	stream.career.recover_offline(state, 2000, 1000)
	check(state.fatigue == 80, "Clock rollback leaves fatigue unchanged")
	stream.start()
	state.hype = 94.99
	stream.click()
	check(state.xp == 1 and stream._xp_fraction == 0, "94.99 XP boundary remains normal")

func _test_historical_saves() -> void:
	_fixture()
	saves.clock = func() -> int: return 1000
	for version: String in ["03", "04", "05"]:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save_v" + version + ".json"))
		var loaded: OperationResult = saves.deserialize(doc)
		check(loaded.success, "Historical writer schema " + version)
		if not loaded.success:
			continue
		var restored: PlayerState = loaded.context["state"]
		check(restored.money == 99 and restored.level == 2 and restored.xp == 3 and restored.fatigue == 60 and restored.upgrades["microphone"] == 1, "Historical progress preserved " + version)
		var canonical: String = JSON.stringify(saves.serialize(restored))
		for i: int in range(3):
			restored = saves.deserialize(JSON.parse_string(canonical)).context["state"]
			check(JSON.stringify(saves.serialize(restored)) == canonical, "Idempotent migration " + version + "/" + str(i))
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save_v05.json"))
	for bad: Variant in [-1, 101, "bad"]:
		var doc: Dictionary = valid.duplicate(true)
		doc["player"]["fatigue"] = bad
		check(not saves.deserialize(doc).success, "Corrupt fatigue rejected")
	var bad_time: Dictionary = valid.duplicate(true)
	bad_time["player"]["fatigue_updated_at"] = -1
	check(not saves.deserialize(bad_time).success, "Corrupt recovery timestamp rejected")
	var duplicate: Dictionary = valid.duplicate(true)
	duplicate["player"]["content_sources"].append(duplicate["player"]["content_sources"][0].duplicate())
	check(not saves.deserialize(duplicate).success, "Duplicate persisted source rejected")
	valid["player"]["current_location_id"] = "retired_location"
	valid["player"]["unlocked_achievements"].append("retired_achievement")
	valid["player"]["relationships"]["retired_streamer"] = 7
	var migrated: PlayerState = saves.deserialize(valid).context["state"]
	check(migrated.current_location_id == "streamer_room" and migrated.relationships["retired_streamer"] == 7 and "retired_achievement" in migrated.unlocked_achievements, "Unknown identifiers safely preserve progress and fall back location")
	ContentSourceService.create(migrated, "fail", 1000)
	ContentSourceService.create(migrated, "fail", 1000)
	check(migrated.content_sources[-1]["id"] != migrated.content_sources[-2]["id"], "Same-second sources have unique persistent sequence IDs")

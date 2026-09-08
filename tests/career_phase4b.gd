extends "res://tests/test_runner.gd"

func _run() -> void:
	_test_production_catalog()
	_test_candidate_use()
	print("CAREER PHASE 4B: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_production_catalog() -> void:
	_fixture()
	check(catalog.streamers.size() == 500, "Historical test fixture loads all 500 profiles")
	check(catalog.streamers.has("fixture_01") and catalog.streamers.has("pixel_neighbor") and catalog.streamers.has("catalog_500"), "Fixture and extended profile IDs coexist")
	var unique_names: Dictionary = {}
	var all_valid: bool = true
	for id: String in catalog.streamers:
		var profile: StreamerDefinition = catalog.streamers[id]
		all_valid = all_valid and not id.is_empty() and not profile.display_name.is_empty() and profile.reference_avg_viewers >= 0 and profile.base_acceptance >= 0 and profile.base_acceptance <= 1 and not profile.collab_formats.is_empty()
		unique_names[profile.display_name] = true
	check(all_valid and unique_names.size() == 500, "Every bundled profile is complete and uniquely named")
	check(catalog.streamers["catalog_500"].reference_avg_viewers > catalog.streamers["fixture_01"].reference_avg_viewers, "Catalog spans multiple channel scales")

func _test_candidate_use() -> void:
	_fixture()
	var service: CollaborationService = CollaborationService.new(catalog, config, ScriptedRandomProvider.new([0]))
	state.average_online = 40
	var first: Array[String] = service.candidates(state)
	state.average_online = 100000
	state.collab_candidate_refresh_at = 0
	var later: Array[String] = service.candidates(state)
	check(first.size() == 10 and later.size() == 10 and first != later, "Large catalog selects candidates relative to career scale")
	var completed: int = 0
	for id: String in first:
		var formats: Array[String] = service.formats(id)
		check(not formats.is_empty() and service.chance(state, id, formats[0]) > 0, "Candidate %s has an offline-compatible request" % id)
		completed += 1
	check(completed == 10, "All visible candidates are usable without network access")

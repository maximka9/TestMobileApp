extends "res://tests/test_runner.gd"

func _run() -> void:
	_fixture()
	state.fatigue = 50
	stream.career.recover(state, 59)
	check(is_equal_approx(state.fatigue, 50 - 59 * 10.0 / 60), "Partial minute recovery")
	stream.career.recover(state, 1)
	check(is_equal_approx(state.fatigue, 40), "Recovery on full minute")
	stream.career.recover(state, 120)
	check(is_equal_approx(state.fatigue, 20), "Multiple recovery minutes")
	_fixture()
	stream.start()
	for boundary: float in [94.9, 95.0, 100.0]:
		state.xp = 0
		stream._xp_fraction = 0
		for i: int in range(20):
			state.hype = boundary
			stream.click()
		check(state.xp == (24 if boundary < 95 else 26 if boundary < 100 else 27), "XP boundary %s applied once" % boundary)
	state.fatigue = 85
	check(is_equal_approx(stream.career.efficiency(state), 0.6), "Fatigue hype curve")
	check(is_equal_approx(stream.career.viewer_efficiency(state), 0.85), "Separate viewer curve")
	stream.finish()
	stream.continue_to_room()
	var short_forms: ShortFormService = ShortFormService.new(catalog, config, ScriptedRandomProvider.new([0]))
	state.fatigue = 0
	check(not short_forms.publish(state, "dota").success, "Unrelated stream cannot unlock Dota")
	check(not short_forms.publish(state, "fail").success, "Normal stream cannot unlock fail")
	stream.select_content("dota_2")
	stream.start()
	state.hype = 0
	events.pending = catalog.events["stream_fail"]
	stream.resolve_event(true)
	check(is_equal_approx(state.hype, 7 * stream.current_content().event_multiplier), "FAIL small hype reward")
	check(ContentSourceService.find(state, ["fail"]) >= 0, "FAIL source created")
	stream.finish()
	stream.continue_to_room()
	check(short_forms.publish(state, "fail").success, "FAIL source survives stream end")
	check(not short_forms.publish(state, "fail").success, "FAIL source consumed once")
	check(short_forms.publish(state, "dota").success, "Dota topic uses its stream")
	check(not short_forms.publish(state, "dota").success, "Dota source consumed once")
	var result: OperationResult = saves.deserialize(JSON.parse_string(JSON.stringify(saves.serialize(state))))
	check(result.success, "v0.5 save loads")
	if result.success:
		check(result.context["state"].content_sources.size() == state.content_sources.size(), "Spent and available sources persist")
	check(not stream.select_location("kitchen").success, "Manual kitchen selection retired")
	check(not stream.select_location("irl").success, "City placeholder cannot be selected")
	_test_recovery_restart()
	_test_source_migration()
	_test_fatigue_effects()
	_test_topic_sources()
	print("V05 SYSTEMS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_recovery_restart() -> void:
	_fixture()
	saves.clock = func() -> int: return 1000
	state.fatigue = 50
	stream.career.recover(state, 59)
	repo.document = saves.serialize(state)
	saves.clock = func() -> int: return 1001
	var restored: PlayerState = saves.load_player()
	check(is_equal_approx(restored.fatigue, 40) and restored.fatigue_recovery_seconds == 0, "Saved 59 seconds plus offline second earns one tick")
	repo.document = saves.serialize(restored)
	check(is_equal_approx(saves.load_player().fatigue, 40), "Save and reload cannot duplicate recovery")
	saves.clock = func() -> int: return 999
	check(is_equal_approx(saves.load_player().fatigue, 40), "Backward clock cannot grant fatigue recovery")
	config.offline_recovery_cap = 120
	saves.clock = func() -> int: return 999999
	check(is_equal_approx(saves.load_player().fatigue, 20), "Long absence is capped to two recovery ticks")
	repo.document["player"]["was_streaming"] = true
	check(is_equal_approx(saves.load_player().fatigue, 40), "No offline recovery for interrupted live stream")
	state.is_streaming = true
	stream.career.recover(state, 120)
	check(is_equal_approx(state.fatigue, 50 - 59 * 10.0 / 60), "Live recovery forbidden")
	state.is_streaming = false
	stream.career.recover(state, 999999)
	check(state.fatigue == 0, "Recovery never creates negative fatigue")

func _test_source_migration() -> void:
	_fixture()
	var legacy: Dictionary = saves.serialize(state)
	legacy["version"] = 8
	for key: String in ["content_sources", "source_sequence", "fatigue_updated_at", "fatigue_recovery_seconds"]:
		legacy["player"].erase(key)
	var migrated: OperationResult = saves.deserialize(legacy)
	check(migrated.success and migrated.context["state"].content_sources.is_empty(), "Schema 8 migrates without inventing sources")
	events.pending = catalog.events["stream_fail"]
	check(not stream.resolve_event(true).success and state.content_sources.is_empty(), "Offline FAIL cannot grant material")
	stream.start()
	events.pending = catalog.events["stream_fail"]
	stream.resolve_event(true)
	check(not stream.resolve_event(true).success and state.content_sources.size() == 1, "Double event resolve cannot duplicate material")
	stream.finish()
	stream.continue_to_room()
	var restored: PlayerState = saves.deserialize(saves.serialize(state)).context["state"]
	var publisher: ShortFormService = ShortFormService.new(catalog, config, ScriptedRandomProvider.new([0]))
	check(publisher.publish(restored, "fail").success, "Available FAIL survives save and reload")
	restored = saves.deserialize(saves.serialize(restored)).context["state"]
	check(publisher.publish(restored, "fail").error_code == &"SOURCE_ALREADY_USED", "Spent FAIL stays spent after reload")
	var malformed: Dictionary = saves.serialize(restored)
	malformed["player"]["content_sources"].append(malformed["player"]["content_sources"][0].duplicate())
	check(not saves.deserialize(malformed).success, "Duplicate source IDs rejected")

func _test_fatigue_effects() -> void:
	_fixture()
	stream.start()
	state.hype = 95
	progression.add_xp(state, 10)
	check(state.xp == 10, "Non-gameplay XP reward is not multiplied")
	state.followers = 10000
	state.hype = 0
	for i: int in range(90):
		stream.tick()
	var fresh_online: int = state.viewers
	state.fatigue = 90
	stream.tick()
	check(state.viewers > int(fresh_online * 0.7) and state.viewers <= fresh_online, "High fatigue smoothly approaches reduced target")
	for i: int in range(90):
		stream.tick()
	check(state.viewers > 0 and state.viewers < fresh_online, "High fatigue reduces sustained online without zeroing it")
	state.fatigue = 0
	state.hype = 0
	var action: ActionDefinition = catalog.moves["beer"]
	var raw: float = action.hype_gain
	moves.apply_action(state, action, 0)
	check(is_equal_approx(state.hype, raw), "Low fatigue leaves base hype unchanged")
	state.fatigue = 85
	state.hype = 0
	moves.apply_action(state, action, 30)
	check(is_equal_approx(state.hype, raw * 0.6) and action.hype_gain == raw, "Tired fractional hype does not mutate action resource")

func _test_topic_sources() -> void:
	_fixture()
	var publisher: ShortFormService = ShortFormService.new(catalog, config, ScriptedRandomProvider.new([0]))
	check(publisher.publish(state, "cooking").error_code == &"NO_SOURCE", "Cooking requires its own source")
	check(publisher.publish(state, "irl").error_code == &"NO_SOURCE", "IRL requires its own source")
	stream.select_location("kitchen")
	stream.select_content("cooking")
	check(stream.start().success, "Cooking starts in kitchen")
	stream.finish()
	stream.continue_to_room()
	check(publisher.publish(state, "cooking").success, "Completed cooking supplies cooking topic")
	check(publisher.publish(state, "cooking").error_code == &"SOURCE_ALREADY_USED", "Cooking material consumed once")
	ContentSourceService.create(state, "irl", 1000)
	state.money = 0
	check(not publisher.publish(state, "irl").success and ContentSourceService.find(state, ["irl"]) >= 0, "Rejected publication preserves source")

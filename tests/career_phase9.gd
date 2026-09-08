extends "res://tests/test_runner.gd"

func _run() -> void:
	_test_career_save()
	_test_integration_save()
	print("CAREER PHASE 9: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_career_save() -> void:
	_fixture()
	# Schema emitted by base commit 71f7d04 (application v0.3).
	var legacy: Dictionary = {"version": 1, "timestamp": 1000, "player": {"level": 2, "xp": 3, "money": 99, "energy": 40.0, "current_stream_type_id": "irl", "total_clicks": 10, "total_streams": 4, "upgrades": {"microphone": 1}, "settings": {"reduced_motion": true}}}
	var result: OperationResult = saves.deserialize(legacy)
	check(result.success, "Actual v0.3 schema loads")
	if not result.success:
		return
	var restored: PlayerState = result.context["state"]
	check(restored.money == 99 and restored.fatigue == 60 and restored.total_streams == 4 and restored.upgrades["microphone"] == 1, "Legacy economy upgrades and fatigue migrate")
	check(restored.followers == config.starting_followers and restored.reputation == config.starting_reputation and restored.owned_room_items.is_empty() and restored.unlocked_achievements.is_empty(), "New systems receive safe defaults")
	check(saves.deserialize(saves.serialize(restored)).success, "Migrated save loads again in current schema")

func _test_integration_save() -> void:
	_fixture()
	saves.clock = func() -> int: return 1000
	state.money = 10000
	state.followers = 1500
	state.career_tier = 2
	state.current_location_id = "kitchen"
	check(stream.select_content("cooking").success and stream.select_cosplay("basic_cosplay").success and stream.start().success, "Cooking and cosplay start together")
	stream.tick()
	stream.finish()
	stream.continue_to_room()
	check(state.stream_history[0]["novelty"] > 1, "Real cosplay session produces bonus novelty")
	var interior: RoomCustomizationService = RoomCustomizationService.new(catalog)
	check(interior.purchase_item(state, "aquarium").success and interior.purchase_home(state, "new_apartment").success, "Purchase inventory and relocate")
	var social: SocialService = SocialService.new(config)
	social.change(state, "fixture_01", 2, 5)
	var collabs: CollaborationService = CollaborationService.new(catalog, config, ScriptedRandomProvider.new([0]))
	check(collabs.request(state, "fixture_01", collabs.formats("fixture_01")[0]).success, "Collaboration before save")
	var short_forms: ShortFormService = ShortFormService.new(catalog, config, ScriptedRandomProvider.new([0]))
	check(short_forms.publish(state, catalog.short_forms.keys()[0]).success, "Short-form publication before save")
	var achievements: AchievementService = AchievementService.new(catalog)
	achievements.evaluate(state)
	state.fatigue = 42.0
	var expected: Dictionary = saves.serialize(state)["player"]
	for i: int in range(5):
		var result: OperationResult = saves.deserialize(JSON.parse_string(JSON.stringify(saves.serialize(state))))
		check(result.success, "Integrated JSON reload %d" % i)
		if not result.success:
			return
		state = result.context["state"]
		var actual: Dictionary = saves.serialize(state)["player"]
		for key: String in expected:
			check(JSON.parse_string(JSON.stringify(actual[key])) == JSON.parse_string(JSON.stringify(expected[key])), "Persistent field %s reload %d" % [key, i])
	check(state.owned_homes.count("starter_home") == 1 and state.current_location_id == "kitchen" and state.current_home_id == "new_apartment", "Home inventory is stable and separate from location")
	check(achievements.evaluate(state).is_empty(), "Reload does not unlock achievements twice")
	for key: String in ["owned_homes", "owned_room_items", "unlocked_achievements"]:
		var bad: Dictionary = saves.serialize(state)
		bad["player"][key] = [""]
		check(not saves.deserialize(bad).success, "Reject empty inventory identifier: " + key)
	var old: Dictionary = saves.serialize(state)
	old["version"] = 5
	for key: String in ["selected_cosplay_id", "cosplay_streams", "viral_posts", "high_tier_collabs", "career_tier", "unlocked_achievements", "owned_room_items", "owned_homes"]:
		old["player"].erase(key)
	check(saves.deserialize(old).success, "Pre-inventory career schema still loads")

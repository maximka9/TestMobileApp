extends "res://tests/test_runner.gd"

func _run() -> void:
	_test_hype()
	_test_gates()
	_test_content()
	_test_calculator()
	_test_session_quality()
	print("V09 SYSTEMS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_hype() -> void:
	for level: int in [1, 50]:
		for power: int in [1, 31]:
			_fixture()
			state.level = level
			state.click_power = power
			state.upgrades["camera"] = 10
			stream.start()
			for boundary: Vector2 in [Vector2(0, 0.7), Vector2(50, 0.7), Vector2(99.6, 0.4), Vector2(100, 0)]:
				state.hype = boundary.x
				var result: OperationResult = stream.click()
				check(is_equal_approx(result.context["hype"], boundary.y) and result.context["xp"] > 0, "Actual hype independent of level/equipment")
	_fixture()
	check(progression.click_xp(10, 1, 0, 1.1) > progression.click_xp(10, 1, 0), "Camera bonus improves XP")
	check(is_equal_approx(progression.click_xp(10, 31, 100, 2), 10 * 1.75 * 1.35), "Combined equipment XP obeys cap")
	var previous: Dictionary = AudienceCurve.get_hype_modifiers(0, config)
	var monotone: bool = true
	for i: int in range(1, 1001):
		var current: Dictionary = AudienceCurve.get_hype_modifiers(i / 10.0, config)
		monotone = monotone and current.viewers >= previous.viewers and current.followers >= previous.followers and current.xp >= previous.xp
		previous = current
	check(monotone, "All hype modifiers monotone")
	check(previous.viewers == 2 and is_equal_approx(previous.followers, 2.4) and is_equal_approx(previous.xp, 1.35), "Maximum modifiers")
	for point: Vector2 in config.hype_anchors:
		check(is_equal_approx(AudienceCurve.hype_multiplier(point.x, config), point.y), "Viewer anchor")

func _test_gates() -> void:
	_fixture()
	state.money = 1000000
	state.level = 10
	state.upgrades["microphone"] = 4
	check(upgrades.purchase(state, "microphone").success, "Level ten buys five")
	var money: int = state.money
	check(upgrades.purchase(state, "microphone").error_code == &"LEVEL_LOCKED" and state.money == money, "Level ten cannot buy six atomically")
	state.level = 12
	check(upgrades.purchase(state, "microphone").success, "Level twelve buys six")
	state.level = 10
	state.upgrades["microphone"] = 8
	state.xp = 552
	state.followers = 1234
	state.relationships["pixel_neighbor"] = 15.0
	ContentSourceService.create(state, "cooking", 100)
	state.content_sources[0].erase("source_stream_average_hype") # Genuine pre-0.9 source shape.
	var document: Dictionary = saves.serialize(state)
	check(document.version == SaveService.VERSION, "Current schema written")
	var loaded: PlayerState = saves.deserialize(document).context["state"]
	check(loaded.upgrades.microphone == 8 and not upgrades.purchase(loaded, "microphone").success, "Over-level equipment preserved and gated")
	check(loaded.level == 10 and loaded.xp == 552 and loaded.followers == 1234 and loaded.relationships == state.relationships and loaded.content_sources == state.content_sources and loaded.current_home_id == state.current_home_id, "v0.8 progress preserved")
	var homes: RoomCustomizationService = RoomCustomizationService.new(catalog)
	state.career_tier = 3
	state.level = 9
	check(not homes.purchase_home(state, "new_apartment").success, "Home needs level despite coins")
	state.level = 10
	state.money = 0
	check(not homes.purchase_home(state, "new_apartment").success, "Home needs coins despite level")
	state.money = catalog.homes["new_apartment"].price
	check(homes.purchase_home(state, "new_apartment").success and state.money == 0, "Home exact price and level")

func _test_content() -> void:
	for format: String in ["cooking", "dota_2", "irl", "just_chatting"]:
		_fixture()
		stream.select_content(format)
		stream.start()
		stream.session_stats.observe(7, 85)
		state.current_stream_type_id = "just_chatting"
		stream.finish()
		stream.continue_to_room()
		var loaded: PlayerState = saves.deserialize(saves.serialize(state)).context["state"]
		check(loaded.content_sources.size() == 1 and format in loaded.content_sources[0].tags and loaded.content_sources[0].source_stream_average_hype == 85, "Session format and hype survive summary/save")
		check(ContentSourceService.find(loaded, PackedStringArray(["fail"])) == -1, "Ordinary stream never makes FAIL")
	_fixture()
	var shorts: ShortFormService = ShortFormService.new(catalog, config, ScriptedRandomProvider.new([9999, 800000]))
	check(shorts.publish(state, "cooking").error_code == &"NO_SOURCE", "Missing cooking source")
	ContentSourceService.create(state, "cooking", 100, 100)
	state.fatigue = 97
	var result: OperationResult = shorts.publish(state, "cooking")
	check(result.success and state.fatigue == 100 and state.content_sources[0].consumed and result.context.followers > 0, "97 plus 8 publishes, clamps, consumes and awards")
	check(shorts.publish(state, "cooking").error_code == &"SOURCE_ALREADY_USED", "Cannot publish twice")
	check(not stream.start().success, "Exhaustion blocks new stream")
	check(is_equal_approx(shorts._viral_chance(state, catalog.short_forms["cooking"], 1, 100) / shorts._viral_chance(state, catalog.short_forms["cooking"], 1, 0), 1.5), "Source hype boosts viral chance")
	state.content_sources[0].source_stream_average_hype = 101
	check(not saves.deserialize(saves.serialize(state)).success, "Invalid source hype rejected")

func _test_calculator() -> void:
	_fixture()
	var growth: FollowerGrowthService = FollowerGrowthService.new(config)
	for scenario: Array in [[5.0, 30, 40.0, 1.253681451], [7.0, 30, 85.0, 4.211826263], [450.0, 60, 85.0, 171.953048459]]:
		var expected: float = growth.expected_stream_gain(scenario[0], scenario[1], scenario[2], 1, 50)
		check(absf(expected - float(scenario[3])) < 0.00001, "Fixed calculator expectation")
		print("CALCULATOR: %s => %.9f, range %d..%d" % [scenario, expected, floori(expected), ceili(expected)])
		growth.random = ScriptedRandomProvider.new([0])
		check(growth.calculate_stream_gain(scenario[0], scenario[1], scenario[2], 1, 50) == ceili(expected), "Stochastic round up")
		growth.random = ScriptedRandomProvider.new([999999])
		check(growth.calculate_stream_gain(scenario[0], scenario[1], scenario[2], 1, 50) == floori(expected), "Stochastic round down")
	check(growth.expected_stream_gain(1000, 120, 20, 1, 50) == 0, "Low average hype means zero organic growth")

func _test_session_quality() -> void:
	_fixture()
	state.followers = 100
	stream.random = ScriptedRandomProvider.new([0])
	stream.start()
	for second: int in range(90):
		for click_index: int in range(4):
			stream.click()
		stream.tick()
	stream.finish()
	check(stream.summary.average_hype > 70 and stream.summary.organic_followers > 0, "Sustained active stream earns organic followers")
	print("ACTIVE SESSION: 360 clicks, 90 minutes, average hype %.3f, organic %d" % [stream.summary.average_hype, stream.summary.organic_followers])
	_fixture()
	state.followers = 1000
	stream.start()
	for second: int in range(30):
		stream.tick()
	state.hype = 100
	stream.finish()
	check(stream.summary.average_hype == 0 and stream.summary.organic_followers == 0, "Final hype spike cannot replace session average")

extends "res://tests/test_runner.gd"

func _run() -> void:
	_test_balance()
	_test_click_feedback()
	_test_recovery()
	_test_cosplay_move()
	_test_statistics()
	_test_migration()
	print("V08 SYSTEMS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_balance() -> void:
	_fixture()
	for level: int in [1, 5, 10, 20]:
		for power: int in [1, 4, 31]:
			var xp: float = progression.click_xp(level, power, 0)
			var high: float = progression.click_xp(level, power, 95)
			var clicks: int = int(ceil(progression.required_xp(level) / xp))
			print("BALANCE | %d | %d | %d | %.2f | %d | %d" % [level, power, progression.required_xp(level), xp, clicks, int(ceil(progression.required_xp(level) / high))])
			check(clicks == 100 if power == 1 else clicks >= 20 and clicks < 100, "Configured clicks per level")
			check(high <= level * config.click_xp_multiplier_cap * 1.30, "Late game XP cap")
			var measured: int = _simulate_clicks(level, power, 0)
			var measured_high: int = _simulate_clicks(level, power, 95)
			check(measured == clicks and measured_high == int(ceil(progression.required_xp(level) / high)), "Physical simulation matches normal and high-hype budget")
			print("MEASURED | %d | %d | %d | %d" % [level, power, measured, measured_high])
		_fixture()
		state.level = level
		stream.start()
		for i: int in range(99):
			state.hype = 0
			stream.click()
		check(state.level == level and state.xp == level * 99, "99 physical base clicks keep level")
		state.hype = 0
		stream.click()
		check(state.level == level + 1 and state.xp == 0, "100th physical click levels up")
	check(progression.hype_mastery(10) == progression.hype_mastery(1), "Level does not increase hype mastery")
	check(progression.hype_mastery(1000) <= 1.0, "Mastery bounded")
	check(progression.click_xp(5, 3, 0) > progression.click_xp(5, 1, 0), "Equipment increases XP")
	check(is_equal_approx(progression.click_xp(7, 1, 94.99), 8.4), "94.99 XP tier")
	check(is_equal_approx(progression.click_xp(7, 1, 95), 9.1), "95 XP bonus")
	check(is_equal_approx(progression.click_xp(7, 1, 100), 9.45), "100 XP bonus")

func _test_click_feedback() -> void:
	_fixture()
	state.level = 7
	state.click_power = 3
	stream.start()
	state.hype = 99.6
	var result: OperationResult = stream.click()
	check(is_equal_approx(result.context["hype"], 0.4) and result.context["xp"] > 0, "Clamped click reports only actual hype plus XP")
	var before: int = state.xp
	result = stream.click()
	check(result.context["hype"] == 0 and state.hype == 100 and state.xp > before, "MAX hype has no fake gain but still awards XP")
	check(state.followers == 30, "Clicks do not award followers")
	state.level = 5
	state.xp = 499
	result = stream.click()
	check(result.context["old_level"] == 5 and result.context["level"] == 6 and result.context["mastery_gain"] == 0, "Level up feedback does not increase hype mastery")

func _test_recovery() -> void:
	_fixture()
	state.fatigue = 56
	stream.career.recover(state, 5)
	check(is_equal_approx(state.fatigue, 56 - 10.0 / 12), "Five seconds visible fractional recovery")
	stream.career.recover(state, 55)
	check(is_equal_approx(state.fatigue, 46), "Ten fatigue per minute")
	var other: PlayerState = PlayerState.new()
	other.fatigue = 56
	for i: int in range(600):
		stream.career.recover(other, 0.1)
	check(is_equal_approx(other.fatigue, state.fatigue), "Recovery independent of call frequency")
	other.fatigue = 56
	stream.career.recover_offline(other, 1000, 1060)
	check(is_equal_approx(other.fatigue, state.fatigue), "Offline uses identical elapsed rate")
	state.is_streaming = true
	stream.career.recover(state, 60)
	check(is_equal_approx(state.fatigue, 46), "No live recovery")

func _test_cosplay_move() -> void:
	_fixture()
	state.money = 100
	check(not stream.perform_move("cosplay:basic_cosplay").success, "Offline cosplay unavailable")
	stream.select_content("cooking")
	stream.start()
	check(state.money == 100 and state.selected_cosplay_id.is_empty(), "Starting content has no cosplay charge")
	check(stream.perform_move("cosplay:basic_cosplay").success and state.money == 85 and state.cosplay_streams == 1, "Cosplay first live use charges existing data once")
	check(state.hype == config.cosplay_hype_gain and moves.novelty_multiplier() == 1.25, "Cosplay hype and novelty applied")
	check(not stream.perform_move("cosplay:basic_cosplay").success and state.money == 85, "Cosplay once per stream")
	stream.finish()
	check(state.selected_cosplay_id.is_empty() and moves.active_cosplay == null, "End clears costume and effect")
	stream.continue_to_room()
	stream.start()
	check(stream.perform_move("cosplay:basic_cosplay").success, "New stream restores use")
	_fixture()
	catalog.streams["cooking"].required_level = 3
	stream.select_content("cooking")
	check(not stream.start().success, "Content required level enforced")
	catalog.streams["cooking"].required_level = 1
	catalog.upgrades["microphone"].required_level = 3
	state.money = 1000
	check(not upgrades.purchase(state, "microphone").success, "Upgrade required level enforced")
	catalog.upgrades["microphone"].required_level = 1
	stream.start()
	catalog.moves["beer"].required_level = 7
	check(not moves.perform(state, "beer", 0).success, "Move required level enforced")
	catalog.moves["beer"].required_level = 1
	catalog.cosplays["basic_cosplay"].required_level = 3
	check(not stream.perform_move("cosplay:basic_cosplay").success, "Cosplay required level enforced")
	catalog.cosplays["basic_cosplay"].required_level = 1

func _test_statistics() -> void:
	var stats: StreamSessionStats = StreamSessionStats.new()
	check(stats.average_viewers() == 0 and stats.peak_viewers == 0, "Empty statistics")
	for value: int in [2, 4, 8, 6]:
		stats.observe(value, 24.1)
	check(stats.average_viewers() == 5 and stats.peak_viewers == 8, "Shared samples average five peak eight")
	stats.observe(10, 24.1)
	stats.game_minutes = 30
	_fixture()
	stream.start()
	state.average_online = 24.1
	for i: int in range(30):
		stream.tick()
	stream.session_stats = stats
	stream.random = ScriptedRandomProvider.new([0])
	stream.finish()
	check(stream.summary["average"] == stats.average_viewers() and stream.summary["average"] <= stream.summary["peak"], "Summary uses samples, never career average or hype")
	var growth: FollowerGrowthService = FollowerGrowthService.new(config)
	growth.random = ScriptedRandomProvider.new([0])
	check(stream.summary["organic_followers"] == growth.calculate_stream_gain(stats.average_viewers(), stats.game_minutes, stats.average_hype(), 1, 50), "Organic followers use identical average")
	var snapshot: Dictionary = stream.summary.duplicate(true)
	var followers: int = state.followers
	stream.finish()
	check(stream.summary == snapshot and state.followers == followers, "Finish is idempotent")
	for i: int in range(101):
		stats.observe(i % 11, 24.1)
		check(stats.average_viewers() >= 0 and stats.average_viewers() <= stats.peak_viewers, "Average never exceeds sampled peak")

func _test_migration() -> void:
	_fixture()
	for level: int in [1, 7, 20, 100]:
		for ratio: float in [0.0, 0.25, 0.63, 0.999]:
			state.level = level
			var old_required: int = int(ceil(50 * pow(level, 1.5)))
			state.xp = int(old_required * ratio)
			var old: Dictionary = saves.serialize(state)
			old["version"] = 10
			var loaded: PlayerState = saves.deserialize(old).context["state"]
			check(loaded.level == level and loaded.xp == progression.migrate_xp(level, state.xp), "Legacy XP preserves level and ratio")
			check(saves.deserialize(saves.serialize(loaded)).context["state"].xp == loaded.xp, "New save never migrates twice")

func _simulate_clicks(level: int, power: int, hype: float) -> int:
	_fixture()
	state.level = level
	state.click_power = power
	stream.start()
	var count: int = 0
	while state.level == level and count < 200:
		state.hype = hype
		stream.click()
		count += 1
	return count

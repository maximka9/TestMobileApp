extends "res://tests/test_runner.gd"
## Targeted Phase 2 coverage: definitions, deterministic outcomes, fatigue, cap and persistence.
var shorts: ShortFormService

func _run() -> void:
	_test_short_forms()
	_test_short_save()
	_test_stream()
	_test_save()
	print("CAREER PHASE 2: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _service(sequence: Array[int]) -> void:
	shorts = ShortFormService.new(catalog, config, ScriptedRandomProvider.new(sequence))

func _test_short_forms() -> void:
	_fixture()
	_service([9999, 0])
	check(catalog.short_forms.size() == 8 and catalog.short_forms["stream_clip"] is ShortFormDefinition, "Eight data-driven short-form definitions load")
	ContentSourceService.create(state, "just_chatting", 1000)
	ContentSourceService.create(state, "just_chatting", 1001)
	ContentSourceService.create(state, "irl", 1002)
	state.fatigue = 10
	var before: int = state.followers
	var result: OperationResult = shorts.publish(state, "meme")
	check(result.success and result.message == "Не залетел" and state.fatigue == 15 and state.followers == before, "Failed post consumes fatigue without followers")
	check(state.short_form_history == ["meme"], "Published short is remembered")
	state.is_streaming = true
	check(shorts.publish(state, "dota").error_code == &"BUSY_STREAMING", "Cannot publish during stream")
	state.is_streaming = false
	state.fatigue = 98
	check(shorts.publish(state, "meme").error_code == &"TOO_TIRED" and state.fatigue == 98, "Too-tired publish is atomic")
	state.money = 0
	check(shorts.publish(state, "irl").error_code == &"NOT_ENOUGH_MONEY", "Money cost is enforced")
	state.money = 100
	state.fatigue = 0
	_service([0])
	before = state.followers
	result = shorts.publish(state, "stream_clip")
	check(result.message == "МЕГА-ВИРУСНЫЙ" and state.followers > before and state.growth_momentum > 0, "Viral post grants followers and momentum")
	var viral_gain: float = state.growth_momentum
	stream.start()
	stream.tick()
	stream.finish()
	check(state.growth_momentum < viral_gain, "Momentum decays after a completed stream")
	_fixture()
	config.short_viral_cap = 3
	state.followers = 1000000000
	state.growth_momentum = 100
	_service([9999])
	ContentSourceService.create(state, "just_chatting", 1000)
	result = shorts.publish(state, "stream_clip")
	check(float(result.context["viral_chance"]) <= 3 and float(result.context["viral_chance"]) < 100, "Configurable viral cap prevents guaranteed outcomes")
	_fixture()
	var a: ShortFormService = ShortFormService.new(catalog, config, RandomProvider.new(42))
	var b: ShortFormService = ShortFormService.new(catalog, config, RandomProvider.new(42))
	var one: PlayerState = PlayerState.new()
	var two: PlayerState = PlayerState.new()
	for i: int in range(8):
		ContentSourceService.create(one, "just_chatting", 1000 + i)
		ContentSourceService.create(two, "just_chatting", 1000 + i)
		check(a.publish(one, "reaction").context["outcome"] == b.publish(two, "reaction").context["outcome"], "Seeded short outcomes reproducible %d" % i)

func _test_short_save() -> void:
	_fixture()
	_service([0])
	ContentSourceService.create(state, "just_chatting", 1000)
	shorts.publish(state, "meme")
	var document: Dictionary = saves.serialize(state)
	var result: OperationResult = saves.deserialize(JSON.parse_string(JSON.stringify(document)))
	var restored: PlayerState = result.context["state"] as PlayerState
	check(result.success and restored.growth_momentum == state.growth_momentum and restored.short_form_history == state.short_form_history, "Momentum and short history persist")
	var v2: Dictionary = document.duplicate(true)
	v2["version"] = 2
	v2["player"].erase("growth_momentum")
	v2["player"].erase("short_form_history")
	result = saves.deserialize(v2)
	restored = result.context["state"] as PlayerState
	check(result.success and restored.growth_momentum == 0 and restored.short_form_history.is_empty(), "Phase 1 saves migrate to short-form defaults")
	var malformed: Dictionary = document.duplicate(true)
	malformed["player"]["short_form_history"] = ["missing"]
	check(not saves.deserialize(malformed).success, "Reject unknown short history ID")

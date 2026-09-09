extends SceneTree
## Dependency-free Godot 4 test runner, with explicit failure exit status.
var passed: int = 0
var failed: int = 0
var config: GameConfig
var catalog: ContentCatalog
var logger: FakeLogger
var state: PlayerState
var upgrades: UpgradeService
var progression: ProgressionService
var economy: EconomyService
var moves: MoveService
var events: EventService
var stream: StreamService
var repo: FakeSaveRepository
var saves: SaveService

func _initialize() -> void:
	_run.call_deferred()

func _fixture(rng: RandomProvider = null) -> void:
	config = GameConfig.new()
	catalog = ContentCatalog.new("res://tests/fixtures/streamers.json")
	logger = FakeLogger.new()
	state = PlayerState.new()
	upgrades = UpgradeService.new(catalog, config)
	progression = ProgressionService.new(config)
	economy = EconomyService.new(config, logger)
	moves = MoveService.new(catalog, upgrades, config)
	events = EventService.new(catalog, rng if rng != null else FakeRandomProvider.new(), config, moves)
	stream = StreamService.new(state, catalog, config, progression, economy, upgrades, moves, events, logger)
	repo = FakeSaveRepository.new()
	saves = SaveService.new(repo, logger, catalog, upgrades)

func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + description)
	else:
		failed += 1
		printerr("FAIL: " + description)

func _run() -> void:
	_test_catalog()
	_test_progression()
	_test_economy()
	_test_stream()
	_test_upgrades()
	_test_moves()
	_test_events()
	_test_save()
	_test_retry()
	_test_file_repository()
	_test_flow()
	_test_bootstrap_failures()
	await _test_scene()
	await _test_room_scene()
	print("TEST RESULTS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_catalog() -> void:
	_fixture()
	check(catalog.streams.size() == 4 and catalog.upgrades.size() == 5 and catalog.events.size() == 14 and catalog.moves.size() == 2, "All content resources discovered")
	check(catalog.moves["beer"].title == "Взять пиво", "Resources preserve Cyrillic")
	check(catalog.streams["irl"].viewer_multiplier == 1.5, "IRL data coefficients")

func _test_progression() -> void:
	_fixture()
	check(progression.required_xp(1) == 100, "Level 1 needs 100 XP")
	progression.add_xp(state, 99)
	check(state.level == 1 and state.xp == 99, "Below level threshold")
	progression.add_xp(state, 4)
	check(state.level == 2 and state.xp == 3, "Level up retains remainder")
	progression.add_xp(state, progression.required_xp(2) + progression.required_xp(3))
	check(state.level == 4 and state.xp == 3, "Multiple level ups")
	check(not progression.add_xp(state, -1).success and not progression.add_xp(null, 1).success, "XP argument validation")

func _test_economy() -> void:
	_fixture()
	var content: StreamType = catalog.streams["just_chatting"]
	check(economy.calculate_income(state, content) == 0, "Offline income is zero")
	state.is_streaming = true
	check(economy.calculate_income(state, content) == 1, "Minimum live income")
	state.viewers = 1000
	check(economy.calculate_income(state, content) == 20, "Base income formula")
	check(economy.calculate_income(state, catalog.streams["dota_2"]) == 18, "Content income multiplier")
	check(economy.calculate_income(state, content, 1.5) == 30, "Upgrade income multiplier")
	check(not economy.credit(state, -10).success and state.money == 0, "Negative credit rejected")
	check(economy.calculate_income(null, content) == 0 and economy.calculate_income(state, null) == 0, "Income null validation")
	economy.credit(state, 20)
	check(state.money == 20, "Income credits balance")

func _test_stream() -> void:
	_fixture()
	check(not stream.click().success and state.total_clicks == 0, "Offline clicks rejected")
	check(not stream.select_content("missing").success, "Unknown content rejected")
	check(stream.select_content("dota_2").success and stream.start().success, "Select and start stream")
	check(not stream.start().success and not stream.select_content("irl").success, "Streaming state guards")
	stream.click()
	check(state.hype == 1.75 and state.xp == 1 and state.total_clicks == 1, "Click grants hype and XP")
	for i: int in range(150):
		stream.click()
	check(state.hype == 100.0, "Hype maximum")
	for i: int in range(4):
		stream.tick()
	check(state.money == 0 and state.viewers > 0, "No income before fifth second; online grows")
	stream.tick()
	check(state.money >= 1 and state.hype == 97.5, "Timed income and hype decay")
	stream.finish()
	check(stream.phase == StreamService.Phase.SUMMARY and not state.is_streaming and state.total_streams == 1, "Finish transitions to summary")
	check(stream.summary["clicks"] == 151 and stream.summary["xp"] == state.xp + progression.required_xp(1) and stream.summary["seconds"] == 5, "Summary counts session activity including high-hype XP")
	check(stream.summary["peak"] >= stream.summary["average"] and stream.summary["average"] > 0, "Summary viewer statistics")
	check(not stream.finish().success and not stream.start().success, "Summary state guards")
	stream.continue_to_room()
	check(state.viewers == 0 and state.hype == 0.0 and stream.phase == StreamService.Phase.OFFLINE, "Continue resets room counters")
	state.energy = 50.0
	stream.tick()
	check(is_equal_approx(state.fatigue, 50 - 10.0 / 60), "Offline fatigue recovers each real second")
	stream.start()
	for i: int in range(205):
		stream.tick()
	check(state.hype == 0.0, "Hype minimum")
	_fixture()
	stream.start()
	for i: int in range(200):
		stream.tick()
	check(absf(state.viewers - stream.target_viewers()) <= 1, "Float viewer accumulator converges without integer stalling")

func _test_upgrades() -> void:
	_fixture()
	check(not upgrades.purchase(state, "missing").success, "Unknown upgrade rejected")
	check(upgrades.purchase(state, "microphone").error_code == &"NOT_ENOUGH_MONEY", "Unaffordable upgrade rejected")
	state.money = 10
	check(upgrades.purchase(state, "microphone").success and state.money == 0 and state.click_power == 2, "Exact-cost microphone purchase")
	check(upgrades.cost(state, "microphone") == 15, "Geometric upgrade cost")
	state.money = 1000
	for id: String in ["monitor", "camera", "chair", "internet"]:
		check(upgrades.purchase(state, id).success, "Generic purchase: " + id)
	var values: Dictionary = upgrades.stats(state)
	check(is_equal_approx(values["income"], 1.1) and is_equal_approx(values["hype_gain"], 1.1) and values["max_energy"] == 110.0 and is_equal_approx(values["viewers"], 1.05), "All generic stat bonuses")
	state.upgrades["microphone"] = 30
	check(upgrades.purchase(state, "microphone").error_code == &"MAX_LEVEL", "Upgrade level cap")

func _test_moves() -> void:
	_fixture()
	check(moves.perform(state, "beer", 0).error_code == &"NOT_STREAMING", "Offline moves rejected")
	stream.start()
	state.energy = 9.0
	check(moves.perform(state, "beer", 0).error_code == &"NOT_ENOUGH_ENERGY" and state.energy == 9.0 and state.hype == 0.0, "Insufficient energy is atomic")
	state.energy = 10.0
	check(moves.perform(state, "beer", 0).success and state.energy == 0.0 and is_equal_approx(state.hype, 6.0), "Exact energy cost accepted with tired hype gain")
	check(moves.perform(state, "beer", 1).error_code == &"ON_COOLDOWN", "Move cooldown enforced")
	check(is_equal_approx(moves.multiplier(19), 1.15) and moves.multiplier(20) == 1.0, "Temporary effect expiry boundary")
	check(moves.remaining("beer", 29) == 1 and moves.remaining("beer", 30) == 0, "Cooldown boundary")
	check(moves.perform(state, "collab", 0).error_code == &"NOT_ENOUGH_MONEY", "Unaffordable collab rejected")
	state.money = 100
	check(moves.perform(state, "collab", 0).success and state.money == 0, "Exact collab payment")
	state.energy = 100.0
	state.hype = 99.0
	moves.perform(state, "beer", 30)
	check(state.hype == 100.0, "Move hype clamped")
	check(not moves.perform(state, "unknown", 0).success and not moves.perform(state, "beer", -1).success, "Move input validation")
	moves.reset()
	state.upgrades["chair"] = 1
	state.energy = 100.0
	moves.perform(state, "beer", 0)
	check(is_equal_approx(state.energy, 100.0 - 1000.0 / 110.0), "Chair capacity reduces percentage consumption")

func _test_events() -> void:
	_fixture()
	stream.start()
	check(events.next_at == 20 and events.poll(19, stream.current_content()) == null, "Injected RNG controls event interval")
	check(events.poll(20, stream.current_content()) != null, "Event appears on deadline")
	check(events.poll(21, stream.current_content()) == null, "Only one pending event")
	check(events.resolve(state, false, 20, stream.current_content()).success and state.hype == 0 and events.pending == null, "Skip event without reward")
	events.pending = catalog.events["clip"]
	stream.resolve_event(true)
	check(state.money == 15 and state.hype == 24.0, "Event reward with content multiplier")
	check(is_equal_approx(moves.multiplier(0), 1.36), "Event viewer bonus scales with content")
	events.pending = catalog.events["beer_offer"]
	stream.resolve_event(true)
	events.pending = catalog.events["beer_offer"]
	check(stream.resolve_event(true).error_code == &"ON_COOLDOWN" and events.pending != null, "Event cannot bypass move cooldown")
	stream.resolve_event(false)
	stream.finish()
	check(stream.summary["money"] == 15 and stream.summary["best_event"] == "Клип залетел", "Summary includes event income and strongest event")
	var rng_a: RandomProvider = RandomProvider.new(42)
	var rng_b: RandomProvider = RandomProvider.new(42)
	var same: bool = true
	for i: int in range(100):
		same = same and rng_a.between(20, 45) == rng_b.between(20, 45)
	check(same, "Seeded RNG reproducibility")
	var a: EventService = EventService.new(catalog, RandomProvider.new(99), config, moves)
	var b: EventService = EventService.new(catalog, RandomProvider.new(99), config, moves)
	same = true
	for now: int in range(0, 500, 50):
		a.schedule(now)
		b.schedule(now)
		same = same and a.next_at == b.next_at and a.poll(a.next_at, catalog.streams["irl"]).id == b.poll(b.next_at, catalog.streams["irl"]).id
	check(same, "Seeded event sequence reproducibility")

func _test_save() -> void:
	_fixture()
	check(saves.load_player().level == 1 and not saves.recovered, "First launch defaults")
	state.money = 200
	upgrades.purchase(state, "microphone")
	state.total_clicks = 42
	state.energy = 70.5
	state.settings["reduced_motion"] = true
	state.is_streaming = true
	var document: Dictionary = saves.serialize(state)
	var result: OperationResult = saves.deserialize(JSON.parse_string(JSON.stringify(document)))
	var restored: PlayerState = result.context["state"]
	check(result.success and restored.money == 190 and restored.click_power == 2 and restored.total_clicks == 42 and restored.energy == 70.5, "Save JSON round trip")
	check(restored.settings["reduced_motion"] and not restored.is_streaming and restored.viewers == 0, "Settings persist; transient session resets")
	for bad: Variant in [-1, "100", null, 1.5, INF]:
		var invalid: Dictionary = document.duplicate(true)
		invalid["player"]["money"] = bad
		check(not saves.deserialize(invalid).success, "Reject invalid money: " + str(bad))
	var malformed: Dictionary = document.duplicate(true)
	malformed["player"]["upgrades"] = {"microphone": -1}
	check(not saves.deserialize(malformed).success, "Reject malformed upgrades")
	var definition: UpgradeDefinition = (catalog.upgrades["microphone"] as UpgradeDefinition).duplicate() as UpgradeDefinition
	catalog.upgrades["microphone"] = definition
	definition.max_level = 2
	malformed["player"]["upgrades"] = {"microphone": 3}
	check(saves.deserialize(malformed).error_code == &"CORRUPT_SAVE", "Reject known upgrade above its own definition cap, even below 30")
	malformed["player"]["upgrades"] = {"microphone": 2}
	check(saves.deserialize(malformed).success, "Accept known upgrade exactly at its definition cap")
	definition.max_level = 40
	malformed["player"]["upgrades"] = {"microphone": 35}
	check(saves.deserialize(malformed).success, "Upgrade validation uses the definition instead of a global 30 cap")
	malformed["player"]["upgrades"] = {"microphone": 2.5}
	check(saves.deserialize(malformed).error_code == &"CORRUPT_SAVE", "Reject fractional upgrade levels")
	malformed["player"]["upgrades"] = {"retired_upgrade": 1}
	var retired: OperationResult = saves.deserialize(malformed)
	check(retired.success and not (retired.context["state"] as PlayerState).upgrades.has("retired_upgrade"), "Unknown upgrade IDs preserve the v1 ignore policy")
	malformed = document.duplicate(true)
	malformed["version"] = 999
	check(not saves.deserialize(malformed).success, "Reject unsupported save version")
	repo.document = {"broken": true}
	check(saves.load_player().money == 0 and repo.quarantined and saves.recovered, "Corrupt save backed up and defaults restored")
	state.hype = -50.0
	state.energy = 200.0
	state.money = -1
	state.normalize()
	check(state.hype == 0 and state.energy == 100 and state.money == 0, "State invariant normalization")

func _test_retry() -> void:
	_fixture()
	var queue: SaveJobQueue = SaveJobQueue.new(saves, state, config)
	for i: int in range(100):
		queue.request_save()
	queue.tick(0.24)
	check(repo.calls == 0 and queue.pending, "Debounce batches requests")
	state.money = 17
	queue.tick(0.02)
	check(repo.calls == 1 and not queue.pending and repo.document["player"]["money"] == 17, "Coalesced save takes latest state")
	repo.failures_left = 5
	queue.request_save()
	queue.tick(0.25)
	check(repo.calls == 2 and queue.attempts == 1, "Initial attempt after 250 ms")
	queue.tick(0.49)
	check(repo.calls == 2, "Retry waits 500 ms")
	queue.tick(0.02)
	check(repo.calls == 3 and queue.attempts == 2, "Second attempt")
	queue.tick(0.99)
	check(repo.calls == 3, "Last retry waits 1000 ms")
	queue.tick(0.02)
	check(repo.calls == 4 and queue.exhausted and not queue.pending, "Three errors exhaust job")
	queue.request_save()
	queue.tick(20)
	queue.flush()
	check(repo.calls == 4, "Clicks and lifecycle do not restart exhausted retry loop")
	repo.failures_left = 0
	queue.retry_manually()
	check(queue.flush().success and not queue.exhausted and repo.calls == 5, "Explicit user retry recovers")
	repo.failures_left = 1
	queue.request_save()
	queue.tick(0.25)
	queue.tick(0.5)
	check(not queue.pending and repo.calls == 7, "Retry succeeds after transient failure")

func _test_file_repository() -> void:
	_fixture()
	var path: String = "user://sasa-test-" + str(Time.get_ticks_usec()) + ".json"
	var file_repo: FileSaveRepository = FileSaveRepository.new(path)
	var file_service: SaveService = SaveService.new(file_repo, logger, catalog, upgrades)
	state.money = 91
	check(file_service.save(state).success, "Real filesystem write")
	state.money = 92
	check(file_service.save(state).success and file_service.load_player().money == 92, "Atomic replacement and reload")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken json")
	file.close()
	check(file_service.load_player().money == 0 and file_service.recovered, "Malformed JSON recovers without crash")
	var found_backup: bool = false
	for name: String in DirAccess.get_files_at("user://"):
		if name.begins_with(path.get_file() + ".damaged-"):
			found_backup = true
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + name))
	check(found_backup, "Damaged file backup exists")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var impossible: FileSaveRepository = FileSaveRepository.new("user://missing-test-dir/save.json")
	check(not impossible.write_save(saves.serialize(state)).success, "Write failure returns result instead of crash")

func _test_flow() -> void:
	_fixture()
	stream.select_content("irl")
	stream.start()
	var beer_worked: bool = stream.perform_move("beer").success
	for second: int in range(500):
		for click_index: int in range(3):
			stream.click()
		stream.tick()
		if events.pending != null:
			stream.resolve_event(false)
	check(state.money >= 100 and state.level > 1 and state.viewers > 0, "New player earns enough for collab")
	check(beer_worked and stream.perform_move("collab").error_code == &"RETIRED_MOVE", "Flow: beer works while fresh; legacy collab routes to new engine")
	# Career growth deliberately no longer grants the old level-based income spike.
	# Earn the next purchase normally instead of assuming spare money after a collab.
	for second: int in range(config.income_seconds * upgrades.cost(state, "microphone")):
		if state.money >= upgrades.cost(state, "microphone"):
			break
		stream.tick()
	check(stream.purchase_upgrade("microphone").success, "Flow: buy upgrade from earnings")
	stream.finish()
	stream.continue_to_room()
	saves.save(state)
	var loaded: PlayerState = saves.load_player()
	check(loaded.money == state.money and loaded.total_streams == 1 and loaded.total_clicks == 1500 and loaded.click_power == 2 and loaded.level == state.level, "Full gameplay flow survives save/load")

func _test_scene() -> void:
	var scene: PackedScene = load("res://src/features/stream/scenes/main_game.tscn") as PackedScene
	var game: MainGameController = scene.instantiate() as MainGameController
	(game.get_node("AppBootstrap") as AppBootstrap).repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.app != null and game.room != null and game.room.is_inside_tree(), "MainGame composition and room mounted")
	game.app.set_process(false)
	game._show_games()
	check(game.modal_kind == "games" and game.modal_layer.visible, "Games modal opens")
	game._start_content("just_chatting")
	game._room_tapped(Vector2(100, 100))
	check(game.app.stream.state.total_clicks > 0 and game.app.stream.state.is_streaming, "UI click dispatch reaches domain")
	_test_room_input(game)
	game._primary_pressed()
	check(game.modal_kind == "summary", "UI finish displays summary")
	game._close_modal()
	check(game.app.stream.phase == StreamService.Phase.OFFLINE, "UI continue returns to room")
	game.queue_free()
	await process_frame

func _test_room_input(game: MainGameController) -> void:
	var before: int = game.app.stream.state.total_clicks
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = game.room.size * 0.5
	touch.index = 0
	touch.pressed = true
	game.room._gui_input(touch)
	check(game.app.stream.state.total_clicks == before + 1, "One native ScreenTouch press produces exactly one gameplay click")
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.position = touch.position
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	game.room._gui_input(mouse)
	check(game.app.stream.state.total_clicks == before + 1, "Touch plus emulated mouse does not double the gameplay click")
	touch.pressed = false
	game.room._gui_input(touch)
	mouse.pressed = false
	game.room._gui_input(mouse)
	mouse.device = 0
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_RIGHT
	game.room._gui_input(mouse)
	check(game.app.stream.state.total_clicks == before + 1, "Touch and mouse release and right-click produce no gameplay clicks")
	mouse.button_index = MOUSE_BUTTON_LEFT
	game.room._gui_input(mouse)
	check(game.app.stream.state.total_clicks == before + 2, "Physical left mouse remains a single gameplay click")
	touch.pressed = true
	touch.index = 1
	game.room._gui_input(touch)
	touch.index = 2
	game.room._gui_input(touch)
	check(game.app.stream.state.total_clicks == before + 4, "Independent native touch presses each produce one click")

func _test_room_scene() -> void:
	var scene: PackedScene = load("res://src/features/stream/scenes/room_view.tscn") as PackedScene
	check(scene != null, "Standalone room scene loads")
	if scene == null:
		return
	var room: RoomView = scene.instantiate() as RoomView
	check(room != null, "Standalone room scene instantiates as a typed RoomView")
	if room == null:
		return
	room.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	room.size = Vector2(336, 280)
	root.add_child(room)
	await process_frame
	await process_frame
	var pool: FloatingTextPool = room.floating_pool
	var labels_before: Array[int] = _label_ids(pool)
	var nodes_before: int = room.find_children("*", "", true, false).size()
	check(labels_before.size() >= 12 and labels_before.size() <= 16, "Room preallocates a bounded 12-16 floating Label pool")
	for index: int in range(1000):
		room.react(Vector2(170, 160), 1.0)
	check(_label_ids(pool) == labels_before and room.find_children("*", "", true, false).size() == nodes_before, "1000 click reactions reuse the same Labels without growing room nodes")
	check(pool.active_count() <= 16 and pool.total_emitted == 1000, "Rapid click feedback stays bounded and accounts for every reaction")
	pool._process(1.0)
	check(pool.active_count() == 0 and _label_ids(pool) == labels_before, "Expired feedback returns to the pool without freeing Labels")
	room.queue_free()
	await process_frame

func _label_ids(parent: Node) -> Array[int]:
	var ids: Array[int] = []
	for node: Node in parent.find_children("*", "Label", true, false):
		ids.append(node.get_instance_id())
	return ids

func _test_bootstrap_failures() -> void:
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/bootstrap_failure_smoke.gd"]), output, true)
	var captured: String = "\n".join(output)
	var expected: PackedStringArray = [
		"ERROR: SASAclicker bootstrap failed: MainGameController parent is required",
		"ERROR: SASAclicker bootstrap failed: GameConfig resource is missing or could not be loaded",
		"ERROR: SASAclicker bootstrap failed: Config resource must be a GameConfig",
	]
	for diagnostic: String in expected:
		check(captured.count(diagnostic) == 1, "Bootstrap reports invalid dependency: " + diagnostic.get_slice("failed: ", 1))
	var only_expected: bool = true
	for line: String in captured.split("\n"):
		var stripped: String = line.strip_edges()
		if (stripped.contains("ERROR:") and not expected.has(stripped)) or stripped.contains("WARNING:") or stripped.contains("FAIL:"):
			only_expected = false
	check(exit_code == 0 and only_expected and captured.contains("BOOTSTRAP_FAILURE_SMOKE_PASS"), "Bootstrap failures stop processing, leave services uninitialized and log without unrelated errors")
	if exit_code != 0 or not only_expected or not captured.contains("BOOTSTRAP_FAILURE_SMOKE_PASS"):
		printerr(captured)

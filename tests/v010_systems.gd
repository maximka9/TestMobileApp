extends "res://tests/test_runner.gd"
var now: int = 0

func _run() -> void:
	_test_featured()
	_test_special()
	_test_reset()
	print("V010 SYSTEMS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_featured() -> void:
	_fixture()
	var production: ContentCatalog = ContentCatalog.new()
	var service: CollaborationService = CollaborationService.new(production, config, RandomProvider.new(42))
	service.clock = func() -> int: return now
	var previous: String = ""
	for moment: int in [0, 59, 60, 119, 120]:
		now = moment
		var candidates: Array[String] = service.candidates(state)
		check(candidates.size() == 10, "Exactly ten candidates")
		check(service.candidate_generation == moment / 60 + 1, "Sixty-second generation")
		check(candidates.back() in config.featured_collab_creator_ids, "Last slot featured")
		for id: String in candidates.slice(0, 9):
			check(not id in config.featured_collab_creator_ids, "Ordinary slot excludes featured")
		if moment % 60 == 0:
			check(previous != candidates.back(), "Avoid immediate featured repeat")
		previous = candidates.back()
	for id: String in config.featured_collab_creator_ids:
		state.collab_cooldowns[id] = now + 1000
		check(service.profile(id) != null and not service.profile(id).platform_user_id.is_empty(), "Verified stable external identity")
	var cooling: Array[String] = service.refresh_candidates(state)
	check(cooling.size() == 10 and service.remaining(state, cooling.back()) > 0, "All cooling retains featured slot")
	state.collab_cooldowns.erase("helin139")
	check(service.refresh_candidates(state).back() == "helin139", "Prefer available featured")
	var invalid: Dictionary = {"followers": -2}
	check(production._streamer_from(invalid) == null, "Invalid follower data rejected")

func _test_special() -> void:
	_fixture()
	catalog = ContentCatalog.new()
	var service: CollaborationService = CollaborationService.new(catalog, config, ScriptedRandomProvider.new([0]))
	service.clock = func() -> int: return 1000
	var achievements: AchievementService = AchievementService.new(catalog)
	var signals: Array[String] = []
	achievements.achievement_unlocked.connect(func(id: String) -> void: signals.append(id))
	for id: String in config.featured_collab_creator_ids:
		state = CareerService.new(config).new_player()
		state.level = 10
		var achievement_id: String = "irl_collab_" + id
		for format: String in ["dota_2", "just_chatting", "cooking"]:
			service.complete_success(state, id, 1, format)
			achievements.evaluate(state)
			check(not achievement_id in state.unlocked_achievements, "Other format never unlocks " + id)
		var result: OperationResult = service.request(state, id, "irl")
		check(result.success and result.context["accepted"], "IRL accepted " + id)
		achievements.evaluate(state)
		check(not achievement_id in state.unlocked_achievements, "Accepted is not completed")
		check(service.complete_pending(state, "just_chatting", 60) == 0 and service.complete_pending(state, "irl", 29) == 0, "Wrong format / short stream cannot complete")
		check(service.complete_pending(state, "irl", 30) > 0, "Completed IRL awards once")
		achievements.evaluate(state)
		check(achievement_id in state.unlocked_achievements, "Matching legendary unlocked " + id)
		var count: int = signals.size()
		achievements.evaluate(state)
		check(signals.size() == count and service.complete_pending(state, "irl", 60) == 0, "No duplicate completion or signal")
		var codec: SaveService = SaveService.new(repo, logger, catalog, UpgradeService.new(catalog, config))
		var restored: PlayerState = codec.deserialize(codec.serialize(state)).context["state"]
		check(restored.completed_irl_collab_creator_ids == state.completed_irl_collab_creator_ids, "IRL completion survives save")
		state = CareerService.new(config).new_player()
		service.random = ScriptedRandomProvider.new([999999])
		service.request(state, id, "irl")
		achievements.evaluate(state)
		check(not achievement_id in state.unlocked_achievements, "Rejected request stays locked")
		service.random = ScriptedRandomProvider.new([0])

func _test_reset() -> void:
	_fixture()
	state.followers = 100000
	state.level = 30
	state.xp = 100
	state.money = 90000
	state.upgrades["camera"] = 4
	state.unlocked_achievements.append("first_collab")
	state.relationships["pixel_neighbor"] = 30.0
	state.current_home_id = "new_apartment"
	state.total_streams = 50
	state.total_clicks = 1000
	ContentSourceService.create(state, "cooking", 100)
	state.settings = {"reduced_motion": true, "volume": 0.4, "show_debug_metrics": true, "language": "ru"}
	var queue: SaveJobQueue = SaveJobQueue.new(saves, state, config)
	queue.request_save()
	repo.failures_left = 1
	check(not ResetProgressService.new().reset(queue).success and queue.state == state, "Failed reset keeps current state")
	var result: OperationResult = ResetProgressService.new().reset(queue)
	check(result.success and not queue.pending, "Successful reset cancels pending autosave")
	var fresh: PlayerState = CareerService.new(config).new_player()
	for key: String in ["followers", "level", "xp", "money", "upgrades", "unlocked_achievements", "relationships", "content_sources", "current_home_id", "owned_room_items", "total_streams", "total_clicks", "stream_history", "completed_irl_collab_creator_ids"]:
		check(queue.state.get(key) == fresh.get(key), "Reset defaults: " + key)
	check(queue.state.settings == state.settings, "All user settings preserved")
	queue.tick(1)
	queue.request_save()
	queue.tick(1)
	var restarted: PlayerState = saves.load_player()
	check(restarted.followers == fresh.followers and restarted.settings == state.settings and restarted.level == 1, "Queued old state cannot return after restart")
	var legacy: Dictionary = saves.serialize(restarted)
	legacy.version = 11
	legacy.player.erase("completed_irl_collab_creator_ids")
	legacy.player.erase("pending_outbound_collab")
	check(saves.deserialize(legacy).success, "Schema 11 migration")
	var path: String = "res://build/checks/v010-reset.json"
	var disk: FileSaveRepository = FileSaveRepository.new(path)
	var codec: SaveService = SaveService.new(disk, logger, catalog, upgrades)
	var disk_queue: SaveJobQueue = SaveJobQueue.new(codec, state, config)
	check(ResetProgressService.new().reset(disk_queue).success, "Atomic disk reset")
	check(codec.load_player().followers == fresh.followers, "Disk restart loads defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

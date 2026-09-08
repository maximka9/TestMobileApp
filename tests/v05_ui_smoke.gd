extends "res://tests/typography_smoke.gd"

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = (load("res://src/features/stream/scenes/main_game.tscn") as PackedScene).instantiate() as MainGameController
	(game.get_node("AppBootstrap") as AppBootstrap).repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for i: int in range(10):
		game._show_locations()
		game._select_location("kitchen" if i % 2 == 0 else "streamer_room")
		await process_frame
		_check(not game.modal_layer.visible, "Selection closes modal")
		_check(game.get_node("%LocationContainer").get_child_count() == 1, "Exactly one location scene")
		_check(not game.modal_layer.is_ancestor_of(game.room), "Location never descends from modal")
		_check(game.get_node("%LocationContainer").get_global_rect().grow(1).encloses(game.room.get_global_rect()), "Location stays inside gameplay area")
	for tier: int in range(3):
		game.app.stream.state.career_tier = tier
		game._refresh()
		await _capture(["main_room_young", "main_room_current", "main_room_successful"][tier])
		if tier < 2:
			game._select_location("kitchen")
			await _capture("kitchen_young" if tier == 0 else "kitchen_current")
			game._select_location("streamer_room")
	game._show_locations()
	await _capture("locations_modal")
	game._show_achievements()
	await _capture("achievements_locked")
	_check(not game.achievement_tree.buttons["followers_100"].get_meta("completed"), "Incomplete node muted")
	game.app.stream.state.followers = 1000
	game._refresh()
	_check(game.achievement_tree.buttons["followers_100"].get_meta("completed"), "Tree refreshes on unlock")
	_check(not game.app.catalog.achievements["followers_1000"].parent_ids.is_empty(), "Parent edges are configured")
	await _capture("achievements_partial")
	game.app.stream.state.followers = 1000000
	game._refresh()
	await _capture("achievements_completed_branch")
	game._show_collaborations()
	await _capture("collabs")
	game._show_short_forms()
	await _capture("content_no_sources")
	ContentSourceService.create(game.app.stream.state, "fail", 1000)
	game._show_short_forms()
	await process_frame
	await process_frame
	var fail_visible: bool = false
	for child: Node in game.modal_body.get_children():
		if child is Label and child.text == game.app.catalog.short_forms["fail"].display_name:
			game.modal_scroll.scroll_vertical = int(child.position.y)
			fail_visible = true
		elif fail_visible and child is Button:
			_check(not child.disabled, "FAIL source enables publication button")
			break
	_check(fail_visible, "FAIL topic available in modal")
	await _capture("content_fail_available")
	_check(game.app.catalog.streamers.size() >= 400, "Public snapshot near 500 profiles")
	for profile: StreamerDefinition in game.app.catalog.streamers.values():
		_check(not profile.source.is_empty() and not profile.is_placeholder, "Public provenance")
	game.queue_free()
	await process_frame
	print("V05 UI SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)

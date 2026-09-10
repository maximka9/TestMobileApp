extends "res://tests/typography_smoke.gd"

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = (load("res://src/features/stream/scenes/main_game.tscn") as PackedScene).instantiate()
	(game.get_node("AppBootstrap") as AppBootstrap).repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var initial_nodes: int = game.get_node("%LocationContainer").find_children("*", "", true, false).size()
	var initial_timers: int = game.find_children("*", "Timer", true, false).size()
	var initial_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for iteration: int in range(20):
		for location: String in ["kitchen", "city"]:
			var old: WeakRef = weakref(game.room)
			game.app.stream.state.fatigue = 0
			game._start_content("cooking" if location == "kitchen" else "irl")
			await process_frame
			await process_frame
			_check(old.get_ref() == null, "Old location freed")
			_check(not game.modal_layer.visible and game.get_node("%LocationContainer").get_child_count() == 1, "One scene and closed selector")
			_check(game.room.tapped.get_connections().size() == 1, "Single gameplay tap connection")
			_check(game.room.find_children("SasavotSprite", "Sprite2D", true, false).size() == 1, "Exactly one character")
			_check(game.app.stream.state.is_streaming, "Content starts its automatic location")
			var clicks: int = game.app.stream.state.total_clicks
			var tap: InputEventScreenTouch = InputEventScreenTouch.new()
			tap.index = 0
			tap.pressed = true
			tap.position = game.room.size / 2
			game.room._gui_input(tap)
			tap.pressed = false
			game.room._gui_input(tap)
			_check(game.app.stream.state.total_clicks == clicks + 1, "One input always yields one click")
			game.app.stream.finish()
			game._close_modal()
	await process_frame
	await process_frame
	_check(game.get_node("%LocationContainer").find_children("*", "", true, false).size() == initial_nodes, "No retained scene or chat nodes after 20 round trips")
	_check(game.find_children("*", "Timer", true, false).size() == initial_timers, "No duplicated timers after switching")
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == initial_orphans, "No orphan nodes after switching")
	var textures: Array[Texture2D] = []
	game._close_modal()
	for tier: int in range(3):
		game.app.stream.state.career_tier = tier
		game._refresh()
		var texture: Texture2D = game.room.sasavot_sprite.texture
		textures.append(texture)
		_check(texture.get_image().detect_alpha() != Image.ALPHA_NONE, "Career sprite has real alpha")
		await _capture(["main_room_young", "main_room_current", "main_room_successful"][tier])
		game._start_content("cooking")
		_check(game.room.sasavot_sprite.texture == texture, "Same tier and identity in Kitchen")
		await _capture(["kitchen_young", "kitchen_current", "kitchen_successful"][tier])
		game.app.stream.finish()
		game._close_modal()
	_check(textures[0] != textures[1] and textures[1] != textures[2] and textures[0] != textures[2], "Three distinct career assets")
	for resolution: Vector2i in [Vector2i(360, 640), Vector2i(390, 844)]:
		root.size = resolution
		await process_frame
		await process_frame
		game._show_achievements()
		game.app.stream.state.unlocked_achievements = ["followers_100"]
		game.achievement_tree.refresh(true)
		_check(game.achievement_tree.buttons["followers_100"].get_meta("state") == "completed", "Completed state")
		_check(game.achievement_tree.buttons["followers_1000"].get_meta("state") == "available", "Child available after parent")
		_check(game.achievement_tree.buttons["followers_10000"].get_meta("state") == "locked", "Grandchild locked until middle parent")
		_check(game.achievement_tree.buttons["slay_king"].text.ends_with("?"), "Secret identity stays hidden")
		await _capture("tree_states_" + str(resolution.x))
		var scroller: ScrollContainer = game.achievement_pan
		for button: Button in game.achievement_tree.buttons.values():
			game.modal_scroll.ensure_control_visible(scroller)
			scroller.ensure_control_visible(button)
			await process_frame
			await process_frame
			_check(scroller.get_global_rect().grow(2).encloses(button.get_global_rect()), "Every graph node reachable " + button.text)
		game.app.stream.state.unlocked_achievements.append("slay_king")
		game.achievement_tree.refresh(true)
		var legendary: Button = game.achievement_tree.buttons["slay_king"]
		scroller.ensure_control_visible(legendary)
		_check(legendary.text.begins_with("✓") and legendary.get_theme_stylebox("normal").border_color == AchievementTree.COLORS[3], "Legendary completion distinct")
		await _capture("tree_legendary_" + str(resolution.x))
	game.queue_free()
	await process_frame
	print("V051 UI SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)

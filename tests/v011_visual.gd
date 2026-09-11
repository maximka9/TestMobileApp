extends "res://tests/typography_smoke.gd"
const SHOTS := "res://docs/v0.11-screenshots/"

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = load("res://src/features/stream/scenes/main_game.tscn").instantiate()
	game.get_node("AppBootstrap").repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	_check(SasaUI.avatar("missing_creator") == SasaUI.DEFAULT_AVATAR, "Missing avatar fallback")
	SasaUI.avatar_paths["invalid_path_fixture"] = "res://assets/ui/avatars/absent.png"
	_check(SasaUI.avatar("invalid_path_fixture") == SasaUI.DEFAULT_AVATAR, "Missing file fallback")
	SasaUI.avatar_paths.erase("invalid_path_fixture")
	for id: String in SasaUI.avatar_paths:
		var path: String = SasaUI.avatar_paths[id]
		_check(path.is_empty() or ResourceLoader.exists(path, "Texture2D"), "Avatar resource " + id)
		_check(SasaUI.avatar(id) != null, "Avatar resolves " + id)
	for definition: AchievementDefinition in game.app.catalog.achievements.values():
		_check(definition.icon != null, "Achievement artwork " + definition.id)
	for definition: ActionDefinition in game.app.catalog.events.values():
		_check(definition.image != null, "Event artwork " + definition.id)
	for pair: Array in [["AccentButton", "Button"], ["Button", "NavButton"], ["NavButton", "DangerButton"], ["DangerButton", "AccentButton"], ["CompactButton", "AccentButton"]]:
		_check(SasaUI.THEME.get_stylebox("normal", pair[0]) != SasaUI.THEME.get_stylebox("normal", pair[1]), "Distinct variants " + str(pair))
	for variant: String in ["AccentButton", "Button", "NavButton", "DangerButton", "CompactButton"]:
		_check(SasaUI.THEME.get_stylebox("normal", variant) != SasaUI.THEME.get_stylebox("disabled", variant), "Disabled variant " + variant)
		_check(SasaUI.THEME.get_stylebox("normal", variant) != SasaUI.THEME.get_stylebox("pressed", variant), "Pressed variant " + variant)
	await _capture("main_room_workstation")
	await _capture("main_room_offline")
	await _capture("buttons_main")
	game._show_collaborations()
	await process_frame
	_check_avatars()
	await _capture("collabs_with_avatars")
	await _capture("buttons_collabs")
	game.modal_scroll.scroll_vertical = 99999
	await _capture("collabs_featured_avatar")
	await _capture("collabs_scrolled")
	game._close_modal()
	game._show_collaborations()
	_check_avatars()
	var creator: String = game._shown_candidate_ids[0]
	var saved_path: String = SasaUI.avatar_paths.get(creator, "")
	SasaUI.avatar_paths[creator] = ""
	game._show_collaborations()
	_check_avatars()
	await _capture("collabs_placeholder_avatar")
	SasaUI.avatar_paths[creator] = saved_path
	var profile: StreamerDefinition = game.app.catalog.streamers[creator]
	var original_name: String = profile.display_name
	profile.display_name = "Длинное имя стримера для проверки ширины карточки"
	game._show_collaborations()
	await process_frame
	_check_avatars()
	await _capture("collabs_long_name")
	profile.display_name = original_name
	game._show_settings()
	await _capture("buttons_options")
	game._confirm_reset()
	await _capture("buttons_reset_danger")
	game._confirm_reset_text()
	await _capture("buttons_reset_confirmation_2")
	var event: ActionDefinition = game.app.catalog.events["clip"].duplicate()
	game._show_event(event)
	await process_frame
	_check(game.modal_body.get_node("EventImage").texture == event.image, "Event uses definition artwork")
	await _capture("event_with_image")
	event.description = "Длинное описание события. ".repeat(35)
	game._show_event(event)
	await _capture("event_with_long_text")
	event.image = null
	game._show_event(event)
	_check(game.modal_body.get_node("EventImage").texture != null, "Event fallback")
	await _capture("event_fallback_image")
	game._show_achievements()
	await process_frame
	for zoom: float in [0.6, 1.0, 1.8]:
		game.achievement_pan.set_zoom(zoom)
		game.achievement_pan.focus_node(game.achievement_tree.buttons["first_collab"])
		await _capture("achievements_icons_%d" % roundi(zoom * 100))
	_check(game.achievement_tree.buttons["first_collab"].get_meta("state") == "locked", "Prerequisite remains locked")
	await _capture("achievement_locked_icon")
	game._achievement_selected("first_collab")
	_check("Заблокировано" in game.achievement_detail.text and "Сначала:" in game.achievement_detail.text, "Detail explains locked prerequisite")
	game.achievement_popup.hide()
	game.achievement_pan.fit()
	await _capture("achievements_icons_fit")
	game.app.stream.state.unlocked_achievements.append("followers_100")
	game.achievement_tree.refresh()
	game.achievement_pan.focus_node(game.achievement_tree.buttons["followers_100"])
	await _capture("achievement_completed_icon")
	game._achievement_selected("followers_100")
	await _capture("achievement_selected_icon")
	game.achievement_popup.hide()
	game._close_modal()
	game.achievement_notifications.enqueue("first_cooking")
	game.achievement_notifications.advance(0.5, false, true, Rect2(0, 0, 500, 850))
	_check(game.achievement_notifications.artwork.texture == game.app.catalog.achievements["first_cooking"].icon, "Toast matching artwork")
	await _capture("achievement_toast_with_icon")
	game.achievement_notifications.advance(4.0, false, true, Rect2(0, 0, 500, 850))
	_check(game.app.stream.start().success, "Room stream starts")
	for second: int in range(30):
		game.app.stream.tick()
	game.room.present(game.app.stream.state)
	await _capture("main_room_live")
	_check(game.app.stream.finish().success, "Room stream finishes")
	await _capture("buttons_stream_result")
	game.app.queue.cancel()
	game.queue_free()
	await process_frame
	print("V011 VISUAL: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _check_avatars() -> void:
	var count: int = 0
	for child: Node in game.modal_body.get_children():
		if child.has_node("AvatarFrame/Avatar"):
			count += 1
			var label: Label = child.get_child(1)
			_check(not label.text.is_empty() and label.custom_minimum_size.y >= 24, "Creator name has readable height")
			var picture: TextureRect = child.get_node("AvatarFrame/Avatar")
			_check(picture.texture == SasaUI.avatar(picture.get_meta("creator_id")), "Card identity survives reopen")
	_check(count == game._shown_candidate_ids.size(), "Every candidate has an avatar")

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(SHOTS + name + ".png") == OK, "Screenshot " + name)

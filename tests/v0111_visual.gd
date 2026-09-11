extends "res://tests/typography_smoke.gd"
const SHOTS := "res://docs/v0.11.1-screenshots/"

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = load("res://src/features/stream/scenes/main_game.tscn").instantiate()
	game.get_node("AppBootstrap").repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	_check(not game.room._chat_content.visible, "No monitor chat")
	await _capture("room_workstation_offline")
	await _capture("main_bottom_nav")
	var nav: Button = game.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.theme_type_variation == &"BottomNavButton")[0]
	nav.toggle_mode = true
	nav.button_pressed = true
	await _capture("main_bottom_nav_pressed")
	nav.button_pressed = false
	for variant: String in ["BottomNavButton"]:
		_check(SasaUI.THEME.get_stylebox("normal", variant) != SasaUI.THEME.get_stylebox("disabled", variant), "Distinct disabled navigation")
		_check(SasaUI.THEME.get_stylebox("normal", variant) != SasaUI.THEME.get_stylebox("pressed", variant), "Distinct pressed navigation")
	var fallback := SasaUI.icon_heading("Fallback", null)
	_check(fallback.get_child(0).texture != null, "Missing icon fallback")
	fallback.free()
	game._show_games()
	await _capture("stream_type_icons")
	game._show_short_forms()
	await _capture("content_icons")
	game.modal_scroll.scroll_vertical = 99999
	await _capture("content_icons_scrolled")
	game._show_moves(false)
	await _capture("moves_icons")
	game.modal_scroll.scroll_vertical = 99999
	await _capture("moves_icons_scrolled")
	game._show_achievements()
	await process_frame
	await process_frame
	game.achievement_pan.fit()
	await _capture("achievements_tree_fit")
	for zoom: float in [0.6, 1.0, 1.8]:
		game.achievement_pan.set_zoom(zoom)
		for button: Button in game.achievement_tree.buttons.values():
			_check(button.size.x <= 80 and button.size.y <= 80, "Compact square node")
			game.achievement_pan.focus_node(button)
			await process_frame
			_check(game.achievement_pan.get_global_rect().intersects(button.get_global_rect()), "Node reachable at zoom " + str(zoom))
		game.achievement_pan.focus_node(game.achievement_tree.buttons["followers_100"])
		await _capture("achievements_tree_%d" % roundi(zoom * 100))
	game.achievement_pan.set_zoom(1.0)
	for pair: Array in [["followers_1000", "followers"], ["first_collab", "collabs"]]:
		game.achievement_pan.focus_node(game.achievement_tree.buttons[pair[0]])
		await _capture("achievements_branch_" + pair[1])
	game._achievement_selected("first_collab")
	await _capture("achievement_locked")
	game.achievement_popup.hide()
	game._achievement_selected("followers_100")
	await _capture("achievement_available")
	game.app.stream.state.unlocked_achievements.append("followers_100")
	game.achievement_tree.refresh()
	game._achievement_selected("followers_100")
	await _capture("achievement_completed")
	await _capture("achievement_selected")
	game._close_modal()
	_check(game.app.stream.start().success, "Stream starts")
	game.room.present(game.app.stream.state)
	await _capture("room_workstation_live")
	_check(not game.room._chat_content.visible, "Live monitor remains status only")
	game.app.queue.cancel()
	game.queue_free()
	await process_frame
	print("V0111 VISUAL: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(SHOTS + name + ".png") == OK, "Screenshot " + name)

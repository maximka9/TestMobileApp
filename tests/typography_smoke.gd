extends SceneTree
## Focused presentation checks and native 540x960 screenshots; no user save data.
const OUTPUT: String = "res://build/checks/typography/"
var game: MainGameController
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = (load("res://src/features/stream/scenes/main_game.tscn") as PackedScene).instantiate() as MainGameController
	(game.get_node("AppBootstrap") as AppBootstrap).repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	game.app.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_check(game.theme.default_font.has_char("Ж".unicode_at(0)), "UI font supports Cyrillic")
	_check(game.theme.get_font("font", "TitleLabel") != game.theme.default_font, "Display and UI fonts differ")
	_check(root.get_texture().get_image().get_size() == Vector2i(540, 960), "Text renders at native debug resolution")
	_check(game.room.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Pixel art retains nearest filtering")
	_check((game.room.get_node("Stage/Desk/RightMonitor/ScreenClip/ChatStatus") as Label).get_theme_font_size("font_size") == 8, "Monitor typography resolves through clipped screen")
	_check(game.primary.get_theme_stylebox("normal") != game.primary.get_theme_stylebox("hover"), "Hover distinct from normal")
	_check(game.primary.get_theme_stylebox("pressed") != game.primary.get_theme_stylebox("normal"), "Pressed distinct from normal")
	_check(game.primary.get_theme_stylebox("disabled") != game.primary.get_theme_stylebox("normal"), "Disabled distinct from normal")
	await _capture("main_offline")
	game._show_moves(false)
	_check(_buttons_disabled(), "Offline moves disabled")
	_check(_has_text("НЕДОСТУПНО") and not _has_text("Готово"), "Offline move status is honest")
	game._refresh()
	_check(not _has_text("Готово"), "Refresh preserves offline status")
	await _capture("moves_offline")
	game._show_games()
	await _capture("games")
	game._start_content("just_chatting")
	await _capture("main_live")
	game._show_moves(false)
	await _capture("moves_live")
	game.app.stream.state.money = 0
	game.app.stream.state.energy = 0
	game._refresh()
	_check(_buttons_disabled(), "Unaffordable moves disabled after refresh")
	game._show_upgrades()
	_check(_buttons_disabled(), "Unaffordable upgrades disabled")
	await _capture("upgrades")
	game.app.events.pending = game.app.catalog.events["clip"]
	game._show_event(game.app.events.pending)
	var skips: int = int("Пропустить" in game.modal_close.text)
	for child: Node in game.modal_body.get_children():
		if child is Button and "Пропустить" in child.text:
			skips += 1
	_check(skips == 1, "One event skip action")
	await _capture("event")
	game._resolve_event(true)
	var money: int = game.app.stream.state.money
	game._resolve_event(true)
	_check(game.app.events.pending == null and not game.modal_layer.visible, "Event dismissed after resolution")
	_check(game.app.stream.state.money == money, "Repeated event action has no effect")
	game._show_settings()
	await _capture("options")
	game.app.events.social.change(game.app.stream.state, "pixel_neighbor", 2, 5)
	game._show_social_profile()
	_check(_has_text("pixel_neighbor: +5"), "Profile renders relationship score")
	await _capture("social_profile")
	game._close_modal()
	game._primary_pressed()
	await _capture("summary")
	game.queue_free()
	await process_frame
	print("TYPOGRAPHY SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _buttons_disabled() -> bool:
	var count: int = 0
	for child: Node in game.modal_body.get_children():
		if child is Button:
			count += 1
			if not child.disabled:
				return false
	return count > 0

func _has_text(value: String) -> bool:
	for child: Node in game.modal_body.get_children():
		if child is Label and child.text == value:
			return true
	return false

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_check(Rect2(Vector2.ZERO, game.size).encloses(game.primary.get_global_rect()), "Main UI fits")
	if game.modal_layer.visible:
		_check(Rect2(Vector2.ZERO, game.size).encloses((game.get_node("%ModalPanel") as Control).get_global_rect()), "Modal fits: " + filename)
	_check(root.get_texture().get_image().save_png(OUTPUT + filename + ".png") == OK, "Capture " + filename)

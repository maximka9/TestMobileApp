class_name MainGameController
extends Control
## Presentation only: renders domain state and dispatches validated commands.
const INK: Color = Color("e7e7ee")
const MUTED: Color = Color("929ab4")
const GREEN: Color = Color("c4ef91")
const PURPLE: Color = Color("baa0ef")
var app: AppBootstrap
var room: RoomView
var header: Label
var counters: Label
var status: Label
var hype_label: Label
var energy_label: Label
var hype_bar: ProgressBar
var energy_bar: ProgressBar
var xp_bar: ProgressBar
var primary: Button
var toast: Label
var save_status: Label
var debug_label: Label
var safe_margin: MarginContainer
var modal_layer: Control
var modal_body: VBoxContainer
var modal_title: Label
var modal_kind: String = ""
var modal_scroll: ScrollContainer
var _toast_time: float = 0.0
var _debug_clock: float = 0.0

func configure(bootstrap: AppBootstrap) -> void:
	app = bootstrap
	_build()
	app.stream.changed.connect(_refresh)
	app.stream.event_available.connect(_event_arrived)
	app.stream.stream_finished.connect(_show_summary)
	app.queue.completed.connect(_save_completed)
	_refresh()
	if app.saves.recovered:
		_feedback(app.saves.notice)

func _panel(color: Color, border: Color = Color("41455f")) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _label(text_value: String, font_size: int = 14, color: Color = INK) -> Label:
	var node: Label = Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _button(text_value: String, callback: Callable, accent: bool = false) -> Button:
	var node: Button = Button.new()
	node.text = text_value
	node.custom_minimum_size.y = 44
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", 13)
	node.add_theme_color_override("font_color", Color("202637") if accent else INK)
	node.add_theme_color_override("font_hover_color", Color("202637") if accent else INK)
	node.add_theme_color_override("font_pressed_color", Color("202637") if accent else INK)
	node.add_theme_stylebox_override("normal", _panel(GREEN if accent else Color("282c43")))
	node.add_theme_stylebox_override("hover", _panel(Color("d6ffa5") if accent else Color("393b57"), PURPLE))
	node.add_theme_stylebox_override("pressed", _panel(Color("a7cf79") if accent else Color("1d2036")))
	node.add_theme_stylebox_override("disabled", _panel(Color("1d2031")))
	node.pressed.connect(callback)
	return node

func _bar(color: Color) -> ProgressBar:
	var node: ProgressBar = ProgressBar.new()
	node.custom_minimum_size.y = 8
	node.show_percentage = false
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color("282d42")
	node.add_theme_stylebox_override("background", background)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	node.add_theme_stylebox_override("fill", fill)
	return node

func _build() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("131727")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	safe_margin = MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe_margin)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	safe_margin.add_child(layout)
	var brand: HBoxContainer = HBoxContainer.new()
	layout.add_child(brand)
	var name_label: Label = _label("SASA", 27, GREEN)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_child(name_label)
	var version_label: Label = _label("CLICKER / 0.1", 11, MUTED)
	version_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand.add_child(version_label)
	var top: PanelContainer = PanelContainer.new()
	top.add_theme_stylebox_override("panel", _panel(Color("1c2135")))
	layout.add_child(top)
	var stats: VBoxContainer = VBoxContainer.new()
	stats.add_theme_constant_override("separation", 5)
	top.add_child(stats)
	header = _label("")
	stats.add_child(header)
	xp_bar = _bar(PURPLE)
	xp_bar.custom_minimum_size.y = 4
	stats.add_child(xp_bar)
	counters = _label("", 17)
	stats.add_child(counters)
	var meters: HBoxContainer = HBoxContainer.new()
	meters.add_theme_constant_override("separation", 16)
	stats.add_child(meters)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meters.add_child(left)
	hype_label = _label("", 11, Color("f1ba8a"))
	left.add_child(hype_label)
	hype_bar = _bar(Color("edac82"))
	left.add_child(hype_bar)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meters.add_child(right)
	energy_label = _label("", 11, GREEN)
	right.add_child(energy_label)
	energy_bar = _bar(GREEN)
	right.add_child(energy_bar)
	status = _label("", 12, PURPLE)
	layout.add_child(status)
	room = RoomView.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(room)
	room.tapped.connect(_room_tapped)
	var hint: Label = _label("Жми на SASAVOT — разгоняй эфир", 11, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(hint)
	primary = _button("Начать эфир", _primary_pressed, true)
	layout.add_child(primary)
	var nav: HBoxContainer = HBoxContainer.new()
	nav.add_theme_constant_override("separation", 4)
	layout.add_child(nav)
	nav.add_child(_button("Игры", _show_games))
	nav.add_child(_button("Коллаб", func() -> void: _show_moves(true)))
	nav.add_child(_button("Мувы", func() -> void: _show_moves(false)))
	nav.add_child(_button("Улучшения", _show_upgrades))
	toast = _label("Готов к первому эфиру? Выбери игру.", 11, MUTED)
	toast.custom_minimum_size.y = 26
	layout.add_child(toast)
	var footer: HBoxContainer = HBoxContainer.new()
	layout.add_child(footer)
	save_status = _label("Прогресс сохраняется автоматически", 9, MUTED)
	save_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(save_status)
	var settings_button: Button = _button("Опции", _show_settings)
	settings_button.custom_minimum_size.y = 28
	settings_button.add_theme_font_size_override("font_size", 10)
	footer.add_child(settings_button)
	debug_label = _label("", 8, MUTED)
	debug_label.visible = app.config.debug_metrics
	layout.add_child(debug_label)
	_build_modal()
	resized.connect(_safe_area)
	_safe_area()

func _build_modal() -> void:
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal_layer)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.08, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dim)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	modal_layer.add_child(margin)
	var center: VBoxContainer = VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel(Color("1c2135"), PURPLE))
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	modal_title = _label("", 22, GREEN)
	box.add_child(modal_title)
	modal_scroll = ScrollContainer.new()
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.custom_minimum_size.y = 320
	box.add_child(modal_scroll)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation", 10)
	modal_scroll.add_child(modal_body)
	box.add_child(_button("Вернуться в комнату", _close_modal))
	modal_layer.hide()

func _safe_area() -> void:
	if safe_margin == null:
		return
	var padding: Vector4i = Vector4i(12, 12, 12, 10)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var screen: Vector2i = DisplayServer.screen_get_size()
		if screen.x > 0 and screen.y > 0 and safe.size.x > 0:
			padding.x += int(safe.position.x * size.x / screen.x)
			padding.y += int(safe.position.y * size.y / screen.y)
			padding.z += int((screen.x - safe.end.x) * size.x / screen.x)
			padding.w += int((screen.y - safe.end.y) * size.y / screen.y)
	for i: int in range(4):
		safe_margin.add_theme_constant_override("margin_" + ["left", "top", "right", "bottom"][i], padding[i])
	if modal_scroll != null:
		modal_scroll.custom_minimum_size.y = clampf(size.y - 230.0, 180.0, 410.0)

func _refresh() -> void:
	var state: PlayerState = app.stream.state
	var required: int = app.progression.required_xp(state.level)
	header.text = "SASAVOT  /  ур. %d     XP %d / %d" % [state.level, state.xp, required]
	xp_bar.max_value = required
	xp_bar.value = state.xp
	counters.text = "ОНЛАЙН  %d       МОНЕТЫ  %d" % [state.viewers, state.money]
	hype_label.text = "ХАЙП  %d / 100" % int(state.hype)
	energy_label.text = "ЭНЕРГИЯ  %d%%" % int(state.energy)
	hype_bar.value = state.hype
	energy_bar.value = state.energy
	var content: StreamType = app.stream.current_content()
	status.text = "%s  /  %s  /  %s" % ["● LIVE" if state.is_streaming else "OFFLINE", content.title, _time(app.stream.elapsed)]
	primary.text = "Завершить эфир" if state.is_streaming else "Выбрать игру и начать эфир"
	primary.disabled = app.stream.phase == StreamService.Phase.SUMMARY
	room.live = state.is_streaming
	room.reduced_motion = bool(state.settings.get("reduced_motion", false))
	room.queue_redraw()
	if modal_kind == "moves" or modal_kind == "collab":
		for child: Node in modal_body.get_children():
			if child is Label and child.has_meta("cooldown_id"):
				var remaining: int = app.moves.remaining(str(child.get_meta("cooldown_id")), app.stream.elapsed)
				child.text = "Восстановление: %d с" % remaining if remaining > 0 else "Готово"

func _time(seconds: int) -> String:
	return "%02d:%02d" % [int(seconds / 60.0), seconds % 60]

func _room_tapped(at: Vector2) -> void:
	var result: OperationResult = app.clicks.handle()
	if result.success:
		room.react(at, float(result.context["hype"]))
	else:
		_feedback(result.message)

func _primary_pressed() -> void:
	if app.stream.state.is_streaming:
		app.stream.finish()
		app.queue.flush()
	else:
		_show_games()

func _open_modal(kind: String, title_text: String) -> void:
	modal_kind = kind
	modal_title.text = title_text
	for child: Node in modal_body.get_children():
		modal_body.remove_child(child)
		child.queue_free()
	modal_scroll.scroll_vertical = 0
	modal_layer.show()

func _close_modal() -> void:
	if modal_kind == "summary":
		app.stream.continue_to_room()
	elif modal_kind == "event" and app.events.pending != null:
		app.stream.resolve_event(false)
	modal_kind = ""
	modal_layer.hide()
	if app.events.pending != null:
		_show_event(app.events.pending)

func _show_games() -> void:
	if app.stream.phase == StreamService.Phase.SUMMARY:
		_show_summary(app.stream.summary)
		return
	_open_modal("games", "ЧТО СТРИМИМ?")
	if app.stream.state.is_streaming:
		modal_body.add_child(_label("Завершите эфир, чтобы сменить контент.", 14, MUTED))
	for id: String in app.catalog.streams:
		var content: StreamType = app.catalog.streams[id]
		modal_body.add_child(_label(content.title, 18, PURPLE))
		modal_body.add_child(_label("%s\nОнлайн ×%.2f · доход ×%.2f\nСобытия ×%.1f" % [content.description, content.viewer_multiplier, content.income_multiplier, content.event_multiplier], 12, MUTED))
		var button: Button = _button("Начать: " + content.title, func() -> void: _start_content(id), true)
		button.disabled = app.stream.state.is_streaming
		modal_body.add_child(button)

func _start_content(id: String) -> void:
	var result: OperationResult = app.stream.select_content(id)
	if result.success:
		result = app.stream.start()
	if result.success:
		_close_modal()
		_feedback("Ты в эфире! Жми на рабочее место.")
	else:
		_feedback(result.message)

func _show_moves(collab_only: bool) -> void:
	if app.stream.phase == StreamService.Phase.SUMMARY:
		return
	_open_modal("collab" if collab_only else "moves", "КОЛЛАБ" if collab_only else "МУВЫ")
	for id: String in app.catalog.moves:
		if collab_only and id != "collab":
			continue
		var definition: ActionDefinition = app.catalog.moves[id]
		modal_body.add_child(_label(definition.title, 18, PURPLE))
		modal_body.add_child(_label(definition.description, 13, MUTED))
		var left: int = app.moves.remaining(id, app.stream.elapsed)
		var cooldown_label: Label = _label("Восстановление: %d с" % left if left > 0 else "Готово", 12, GREEN)
		cooldown_label.set_meta("cooldown_id", id)
		modal_body.add_child(cooldown_label)
		modal_body.add_child(_button("Использовать", func() -> void:
			var result: OperationResult = app.stream.perform_move(id)
			_show_moves(collab_only)
			_modal_feedback(result)
		))
	modal_body.add_child(_label("Энергия восстанавливается между эфирами. Вместимость: %d." % int(app.upgrades.stats(app.stream.state)["max_energy"]), 12, MUTED))

func _show_upgrades() -> void:
	if app.stream.phase == StreamService.Phase.SUMMARY:
		return
	_open_modal("upgrades", "АПГРЕЙД КОМНАТЫ")
	modal_body.add_child(_label("Баланс: %d монет" % app.stream.state.money, 16, GREEN))
	for id: String in app.catalog.upgrades:
		var definition: UpgradeDefinition = app.catalog.upgrades[id]
		var level: int = int(app.stream.state.upgrades.get(id, 0))
		modal_body.add_child(_label("%s  /  ур. %d" % [definition.title, level], 16, PURPLE))
		modal_body.add_child(_label(definition.description, 12, MUTED))
		var button: Button = _button("Купить · %d монет" % app.upgrades.cost(app.stream.state, id), func() -> void:
			var scroll: int = modal_scroll.scroll_vertical
			var result: OperationResult = app.stream.purchase_upgrade(id)
			_show_upgrades()
			modal_scroll.set_deferred("scroll_vertical", scroll)
			_modal_feedback(result)
		)
		button.disabled = level >= definition.max_level
		modal_body.add_child(button)

func _event_arrived(definition: ActionDefinition) -> void:
	if not modal_layer.visible:
		_show_event(definition)
	else:
		_feedback("Новое событие ждёт в комнате")

func _show_event(definition: ActionDefinition) -> void:
	_open_modal("event", "СОБЫТИЕ ЭФИРА")
	modal_body.add_child(_label(definition.title, 24, PURPLE))
	modal_body.add_child(_label(definition.description, 15))
	modal_body.add_child(_label("Бонусы обычных событий зависят от выбранного контента. Эфир продолжается.", 12, MUTED))
	modal_body.add_child(_button("Принять", func() -> void: _resolve_event(true), true))
	modal_body.add_child(_button("Пропустить", func() -> void: _resolve_event(false)))

func _resolve_event(accept: bool) -> void:
	var result: OperationResult = app.stream.resolve_event(accept)
	if result.success:
		_close_modal()
		_feedback(result.message)
	else:
		_modal_feedback(result)

func _show_summary(summary: Dictionary) -> void:
	_open_modal("summary", "СТРИМ ЗАВЕРШЁН")
	modal_body.add_child(_label("Хороший эфир. Чат ждёт продолжения!", 14, MUTED))
	for row: Array in [["Время эфира", _time(int(summary["seconds"]))], ["Пиковый онлайн", summary["peak"]], ["Средний онлайн", "%.1f" % summary["average"]], ["Заработано", "%d монет" % summary["money"]], ["Получено XP", summary["xp"]], ["Клики", summary["clicks"]], ["Лучший ивент", summary["best_event"]]]:
		modal_body.add_child(_label("%s\n%s" % [row[0], row[1]], 15))
	modal_body.add_child(_button("Продолжить", _close_modal, true))

func _show_settings() -> void:
	if app.stream.phase == StreamService.Phase.SUMMARY:
		return
	_open_modal("settings", "НАСТРОЙКИ")
	var motion: CheckButton = CheckButton.new()
	motion.text = "Уменьшить анимацию"
	motion.button_pressed = bool(app.stream.state.settings["reduced_motion"])
	motion.custom_minimum_size.y = 44
	motion.toggled.connect(app.stream.set_reduced_motion)
	modal_body.add_child(motion)
	modal_body.add_child(_label("Всего кликов: %d\nЗавершено эфиров: %d\nПрогресс хранится на этом устройстве." % [app.stream.state.total_clicks, app.stream.state.total_streams], 14, MUTED))
	modal_body.add_child(_button("Сохранить сейчас", func() -> void:
		app.queue.retry_manually()
		_modal_feedback(app.queue.flush())
	))

func _modal_feedback(result: OperationResult) -> void:
	var message: String = result.message if not result.message.is_empty() else str(result.error_code)
	var feedback: Label = _label(message, 13, GREEN if result.success else Color("f5a0a0"))
	modal_body.add_child(feedback)
	modal_body.move_child(feedback, 0)
	_feedback(message)

func _feedback(message: String) -> void:
	toast.text = message
	_toast_time = 6.0

func _save_completed(result: OperationResult) -> void:
	save_status.text = "Прогресс сохранён" if result.success else "Ошибка сохранения · повтор в Опциях"
	save_status.modulate = INK if result.success else Color("f5a0a0")

func _process(delta: float) -> void:
	if app == null:
		return
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			toast.text = "Жми, прокачивай комнату, собирай свой онлайн."
	_debug_clock += delta
	if _debug_clock >= 1.0 and app.config.debug_metrics:
		_debug_clock = 0.0
		var data: Dictionary = app.metrics.snapshot
		debug_label.text = "FPS %d · кадр %.1f ms · save %.1f ms · очередь %d · event %.2f ms" % [int(data.get("fps", 0)), float(data.get("frame_ms", 0)), float(data.get("save_ms", 0)), int(data.get("queue_size", 0)), float(data.get("event_ms", 0))]

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and modal_layer.visible:
		_close_modal()
		get_viewport().set_input_as_handled()

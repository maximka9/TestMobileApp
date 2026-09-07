class_name MainGameController
extends Control
## Presentation only: renders domain state and dispatches validated commands.
var app: AppBootstrap
@onready var room: RoomView = %RoomView
@onready var header: Label = %Header
@onready var viewers_label: Label = %ViewersValue
@onready var money_label: Label = %MoneyValue
@onready var status: Label = %Status
@onready var hype_label: Label = %HypeLabel
@onready var energy_label: Label = %EnergyLabel
@onready var hype_bar: ProgressBar = %HypeBar
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var xp_bar: ProgressBar = %XPBar
@onready var primary: Button = %PrimaryButton
@onready var toast: Label = %Toast
@onready var save_status: Label = %SaveStatus
@onready var debug_label: Label = %DebugLabel
@onready var safe_margin: MarginContainer = %SafeMargin
@onready var modal_layer: Control = %ModalLayer
@onready var modal_body: VBoxContainer = %ModalBody
@onready var modal_title: Label = %ModalTitle
@onready var modal_scroll: ScrollContainer = %ModalScroll
@onready var modal_margin: MarginContainer = %ModalMargin
@onready var modal_close: Button = %ModalClose
var modal_kind: String = ""
## Optional logical insets for desktop safe-area smoke tests; mobile uses the OS.
var safe_insets_override: Vector4i = Vector4i(-1, -1, -1, -1)
var _toast_time: float = 0.0
var _save_notice_time: float = 0.0
var _debug_clock: float = 0.0

func configure(bootstrap: AppBootstrap) -> void:
	app = bootstrap
	(%Backdrop as ColorRect).color = SasaUI.color(&"background")
	(%Dim as ColorRect).color = SasaUI.color(&"overlay")
	app.stream.changed.connect(_refresh)
	app.stream.event_available.connect(_event_arrived)
	app.stream.stream_finished.connect(_show_summary)
	app.queue.completed.connect(_save_completed)
	room.tapped.connect(_room_tapped)
	primary.pressed.connect(_primary_pressed)
	(%GamesButton as Button).pressed.connect(_show_games)
	(%CollabButton as Button).pressed.connect(func() -> void: _show_moves(true))
	(%MovesButton as Button).pressed.connect(func() -> void: _show_moves(false))
	(%UpgradesButton as Button).pressed.connect(_show_upgrades)
	(%SettingsButton as Button).pressed.connect(_show_settings)
	modal_close.pressed.connect(_close_modal)
	resized.connect(_safe_area)
	_safe_area()
	_refresh()
	if app.saves.recovered:
		_feedback(app.saves.notice)

func _safe_area() -> void:
	if safe_margin == null:
		return
	var insets: Vector4i = Vector4i.ZERO
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var screen: Vector2i = DisplayServer.screen_get_size()
		if screen.x > 0 and screen.y > 0 and safe.size.x > 0:
			insets.x = maxi(0, int(ceil(safe.position.x * size.x / screen.x)))
			insets.y = maxi(0, int(ceil(safe.position.y * size.y / screen.y)))
			insets.z = maxi(0, int(ceil((screen.x - safe.end.x) * size.x / screen.x)))
			insets.w = maxi(0, int(ceil((screen.y - safe.end.y) * size.y / screen.y)))
	if safe_insets_override.x >= 0:
		insets = safe_insets_override
	var padding: Vector4i = insets + Vector4i(12, 8, 12, 8)
	for i: int in range(4):
		safe_margin.add_theme_constant_override("margin_" + ["left", "top", "right", "bottom"][i], padding[i])
		modal_margin.add_theme_constant_override("margin_" + ["left", "top", "right", "bottom"][i], insets[i] + 16)
	if modal_scroll != null:
		modal_scroll.custom_minimum_size.y = clampf(size.y - insets.y - insets.w - 225.0, 140.0, 440.0)

func _refresh() -> void:
	var state: PlayerState = app.stream.state
	var required: int = app.progression.required_xp(state.level)
	header.text = "ПОДПИСЧИКИ %d · XP %d / %d" % [state.followers, state.xp, required]
	xp_bar.max_value = required
	xp_bar.value = state.xp
	viewers_label.text = str(state.viewers)
	money_label.text = str(state.money)
	hype_label.text = "ХАЙП  %d / 100" % int(state.hype)
	energy_label.text = "УСТАЛОСТЬ  %d%%" % int(state.fatigue)
	hype_bar.value = state.hype
	energy_bar.value = state.fatigue
	var content: StreamType = app.stream.current_content()
	status.text = "%s  /  %s  /  %s" % ["● LIVE" if state.is_streaming else "OFFLINE", content.title, _time(app.stream.elapsed)]
	primary.text = "Завершить эфир" if state.is_streaming else "НАЧАТЬ ЭФИР"
	primary.disabled = app.stream.phase == StreamService.Phase.SUMMARY
	room.present(state)
	if modal_kind == "moves" or modal_kind == "collab":
		for child: Node in modal_body.get_children():
			if child is Label and child.has_meta("cooldown_id"):
				child.text = _move_status(str(child.get_meta("cooldown_id")))
				child.theme_type_variation = &"SuccessLabel" if child.text == "Готово" else &"MutedLabel"
			elif child is Button and child.has_meta("move_id"):
				child.disabled = _move_status(str(child.get_meta("move_id"))) != "Готово"

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
	modal_close.text = "Продолжить" if kind == "summary" else "Пропустить событие" if kind == "event" else "Вернуться в комнату"
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
		modal_body.add_child(SasaUI.label("Завершите эфир, чтобы сменить контент.", &"body", &"MutedLabel"))
	for id: String in app.catalog.streams:
		var content: StreamType = app.catalog.streams[id]
		modal_body.add_child(SasaUI.label(content.title, &"heading", &"AccentLabel"))
		modal_body.add_child(SasaUI.label("Свежесть формата: %d%%" % int(app.stream.career.novelty(app.stream.state, id) * 100), &"small", &"MutedLabel"))
		modal_body.add_child(SasaUI.label("%s\nОнлайн ×%.2f · доход ×%.2f\nСобытия ×%.1f" % [content.description, content.viewer_multiplier, content.income_multiplier, content.event_multiplier], &"small", &"MutedLabel"))
		var button: Button = SasaUI.button("Начать: " + content.title, func() -> void: _start_content(id), true)
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
	if not app.stream.state.is_streaming:
		modal_body.add_child(SasaUI.label("Сначала начните эфир"))
	for id: String in app.catalog.moves:
		if collab_only and id != "collab":
			continue
		var definition: ActionDefinition = app.catalog.moves[id]
		modal_body.add_child(SasaUI.label(definition.title, &"heading", &"AccentLabel"))
		modal_body.add_child(SasaUI.label(definition.description, &"body", &"MutedLabel"))
		if not app.stream.state.is_streaming:
			modal_body.add_child(SasaUI.label("Только во время эфира", &"small", &"MutedLabel"))
		var cooldown_label: Label = SasaUI.label(_move_status(id), &"small", &"SuccessLabel")
		cooldown_label.theme_type_variation = &"SuccessLabel" if cooldown_label.text == "Готово" else &"MutedLabel"
		cooldown_label.set_meta("cooldown_id", id)
		modal_body.add_child(cooldown_label)
		var move_button: Button = SasaUI.button("Использовать", func() -> void:
			var result: OperationResult = app.stream.perform_move(id)
			_show_moves(collab_only)
			_modal_feedback(result)
		)
		move_button.set_meta("move_id", id)
		move_button.disabled = _move_status(id) != "Готово"
		modal_body.add_child(move_button)
	modal_body.add_child(SasaUI.label("Мувы увеличивают усталость. Отдых между эфирами восстанавливает силы.", &"small", &"MutedLabel"))

func _move_status(id: String) -> String:
	if not app.stream.state.is_streaming:
		return "НЕДОСТУПНО"
	var remaining: int = app.moves.remaining(id, app.stream.elapsed)
	if remaining > 0:
		return "Восстановление: %d с" % remaining
	var definition: ActionDefinition = app.catalog.moves[id]
	if app.stream.state.money < definition.money_cost:
		return "Не хватает монет"
	var energy_cost: float = definition.energy_cost / float(app.upgrades.stats(app.stream.state)["max_energy"]) * app.config.base_energy
	if app.stream.state.energy < energy_cost:
		return "Не хватает энергии"
	return "Готово"

func _show_upgrades() -> void:
	if app.stream.phase == StreamService.Phase.SUMMARY:
		return
	_open_modal("upgrades", "АПГРЕЙД КОМНАТЫ")
	modal_body.add_child(SasaUI.label("Баланс: %d монет" % app.stream.state.money, &"heading", &"SuccessLabel"))
	for id: String in app.catalog.upgrades:
		var definition: UpgradeDefinition = app.catalog.upgrades[id]
		var level: int = int(app.stream.state.upgrades.get(id, 0))
		modal_body.add_child(SasaUI.label("%s  /  ур. %d" % [definition.title, level], &"heading", &"AccentLabel"))
		modal_body.add_child(SasaUI.label(definition.description, &"small", &"MutedLabel"))
		var button: Button = SasaUI.button("Купить · %d монет" % app.upgrades.cost(app.stream.state, id), func() -> void:
			var scroll: int = modal_scroll.scroll_vertical
			var result: OperationResult = app.stream.purchase_upgrade(id)
			_show_upgrades()
			modal_scroll.set_deferred("scroll_vertical", scroll)
			_modal_feedback(result)
		)
		button.disabled = level >= definition.max_level or app.stream.state.money < app.upgrades.cost(app.stream.state, id)
		modal_body.add_child(button)

func _event_arrived(definition: ActionDefinition) -> void:
	if not modal_layer.visible:
		_show_event(definition)
	else:
		_feedback("Новое событие ждёт в комнате")

func _show_event(definition: ActionDefinition) -> void:
	_open_modal("event", "СОБЫТИЕ ЭФИРА")
	modal_body.add_child(SasaUI.label(definition.title, &"heading", &"AccentLabel"))
	modal_body.add_child(SasaUI.label(definition.description, &"body"))
	modal_body.add_child(SasaUI.label("Бонусы обычных событий зависят от выбранного контента. Эфир продолжается.", &"small", &"MutedLabel"))
	modal_body.add_child(SasaUI.button("Принять", func() -> void: _resolve_event(true), true))

func _resolve_event(accept: bool) -> void:
	if modal_kind != "event" or app.events.pending == null:
		return
	var result: OperationResult = app.stream.resolve_event(accept)
	if result.success:
		_close_modal()
		_feedback(result.message)
	else:
		_modal_feedback(result)

func _show_summary(summary: Dictionary) -> void:
	_open_modal("summary", "СТРИМ ЗАВЕРШЁН")
	modal_body.add_child(SasaUI.label("Новых подписчиков: +%d · средний онлайн: %.1f" % [int(summary.get("followers", 0)), app.stream.state.average_online], &"body", &"SuccessLabel"))
	modal_body.add_child(SasaUI.label("Хороший эфир. Чат ждёт продолжения!", &"body", &"MutedLabel"))
	for row: Array in [["Время эфира", _time(int(summary["seconds"]))], ["Пиковый онлайн", summary["peak"]], ["Средний онлайн", "%.1f" % summary["average"]], ["Заработано", "%d монет" % summary["money"]], ["Получено XP", summary["xp"]], ["Клики", summary["clicks"]], ["Лучший ивент", summary["best_event"]]]:
		modal_body.add_child(SasaUI.label("%s\n%s" % [row[0], row[1]], &"body"))
	modal_body.add_child(SasaUI.button("Продолжить", _close_modal, true))

func _show_settings() -> void:
	if app.stream.phase == StreamService.Phase.SUMMARY:
		return
	_open_modal("settings", "НАСТРОЙКИ")
	var motion: CheckButton = CheckButton.new()
	motion.text = "Уменьшить анимацию"
	motion.button_pressed = bool(app.stream.state.settings["reduced_motion"])
	motion.custom_minimum_size.y = SasaUI.TOUCH_TARGET
	motion.toggled.connect(app.stream.set_reduced_motion)
	modal_body.add_child(motion)
	modal_body.add_child(SasaUI.label("Всего кликов: %d\nЗавершено эфиров: %d\nПрогресс хранится на этом устройстве." % [app.stream.state.total_clicks, app.stream.state.total_streams], &"body", &"MutedLabel"))
	if app.config.debug_metrics:
		var metrics_toggle: CheckButton = CheckButton.new()
		metrics_toggle.text = "Показывать FPS и метрики"
		metrics_toggle.custom_minimum_size.y = SasaUI.TOUCH_TARGET
		metrics_toggle.button_pressed = debug_label.visible
		metrics_toggle.toggled.connect(func(enabled: bool) -> void: debug_label.visible = enabled)
		modal_body.add_child(metrics_toggle)
	modal_body.add_child(SasaUI.button("Сохранить сейчас", func() -> void:
		app.queue.retry_manually()
		_modal_feedback(app.queue.flush())
	))

func _modal_feedback(result: OperationResult) -> void:
	var message: String = result.message if not result.message.is_empty() else str(result.error_code)
	var feedback: Label = SasaUI.label(message, &"body", &"SuccessLabel" if result.success else &"ErrorLabel")
	modal_body.add_child(feedback)
	modal_body.move_child(feedback, 0)
	_feedback(message)

func _feedback(message: String) -> void:
	toast.text = message
	toast.tooltip_text = message
	_toast_time = 6.0

func _save_completed(result: OperationResult) -> void:
	save_status.text = "Сохранено ✓" if result.success else "Ошибка сохранения · повтор в Опциях"
	save_status.theme_type_variation = &"MutedLabel" if result.success else &"ErrorLabel"
	_save_notice_time = 3.0 if result.success else 0.0

func _process(delta: float) -> void:
	if app == null:
		return
	if _save_notice_time > 0.0:
		_save_notice_time -= delta
		if _save_notice_time <= 0.0:
			save_status.text = ""
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			toast.text = "Твой стрим. Твои правила."
	_debug_clock += delta
	if _debug_clock >= 1.0 and app.config.debug_metrics:
		_debug_clock = 0.0
		var data: Dictionary = app.metrics.snapshot
		debug_label.text = "FPS %d · кадр %.1f ms · save %.1f ms · очередь %d · event %.2f ms" % [int(data.get("fps", 0)), float(data.get("frame_ms", 0)), float(data.get("save_ms", 0)), int(data.get("queue_size", 0)), float(data.get("event_ms", 0))]

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and modal_layer.visible:
		_close_modal()
		get_viewport().set_input_as_handled()

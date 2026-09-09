class_name MainGameController
extends Control
## Presentation only: renders domain state and dispatches validated commands.
var app: AppBootstrap
@onready var room: RoomView = %RoomView
var _location_id: String = "streamer_room"
var achievement_tree: AchievementTree
var achievement_detail: Label
var achievement_popup: PopupPanel
var collab_timer_label: Label
var refresh_pending: bool = false
var _shown_generation: int = -1
var _shown_candidate_ids: Array[String] = []
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
var _collab_waiting: bool = false

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
	(%ContentButton as Button).pressed.connect(_show_short_forms)
	(%CollabButton as Button).pressed.connect(_show_collaborations)
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
	if not app.achievements.evaluate(state).is_empty():
		app.queue.request_save()
	if is_instance_valid(achievement_tree):
		achievement_tree.refresh()
	_poll_collab_rotation()
	var required: int = app.progression.required_xp(state.level)
	header.text = "ПОДПИСЧИКИ %d\nУР. %d · XP %d / %d" % [state.followers, state.level, state.xp, required]
	xp_bar.max_value = required
	xp_bar.value = state.xp
	viewers_label.text = str(state.viewers)
	money_label.text = str(state.money)
	hype_label.text = "ХАЙП  %d / 100" % int(state.hype)
	energy_label.text = "УСТАЛОСТЬ  %d%%" % int(state.fatigue)
	hype_bar.value = state.hype
	energy_bar.value = state.fatigue
	var content: StreamType = app.stream.current_content()
	status.text = "%s  /  %s  /  %s" % ["● LIVE" if state.is_streaming else "OFFLINE", content.title, StreamTime.format_live(app.stream.elapsed)]
	primary.text = "Завершить эфир" if state.is_streaming else "НАЧАТЬ ЭФИР"
	primary.disabled = app.stream.phase == StreamService.Phase.SUMMARY
	_present_location(state)
	(%CollabButton as Button).text = "Коллаб !" if not app.inbound.current(state).is_empty() else "Коллаб"
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
		room.react(at, float(result.context["hype"]), int(result.context["xp"]))
		if result.context["level"] > result.context["old_level"]:
			_feedback("LEVEL UP! %d → %d · Улучшения до ур. %d" % [result.context["old_level"], result.context["level"], maxi(1, int(result.context["level"]) / 2)])
			if not app.stream.state.settings.get("reduced_motion", false):
				toast.modulate = Color(1.0, 0.65, 0.4)
				create_tween().tween_property(toast, "modulate", Color.WHITE, 0.6)
	else:
		_feedback(result.message)

func _primary_pressed() -> void:
	if app.stream.state.is_streaming:
		app.stream.finish()
		app.queue.flush()
	else:
		_show_games()

func _open_modal(kind: String, title_text: String) -> void:
	modal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	modal_kind = kind
	modal_title.text = title_text
	for child: Node in modal_body.get_children():
		modal_body.remove_child(child)
		child.queue_free()
	modal_scroll.scroll_vertical = 0
	modal_close.text = "Продолжить" if kind == "summary" else "Пропустить событие" if kind == "event" else "Вернуться в комнату"
	modal_layer.show()

func _close_modal() -> void:
	if _collab_waiting:
		return
	if is_instance_valid(achievement_popup):
		achievement_popup.hide()
	if modal_kind in ["collab_formats", "collab_offer"]:
		_show_collaborations()
		return
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
		button.disabled = app.stream.state.is_streaming or app.stream.state.level < content.required_level
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

func _show_short_forms() -> void:
	if app.stream.phase != StreamService.Phase.OFFLINE:
		_feedback("Ролики можно публиковать между эфирами")
		return
	_open_modal("short_forms", "КОНТЕНТ")
	modal_body.add_child(SasaUI.label("📱 Короткие ролики", &"heading", &"AccentLabel"))
	modal_body.add_child(SasaUI.label("Усталость: %d%% · ускорение: %d%%" % [int(app.stream.state.fatigue), int(app.stream.state.growth_momentum)], &"small", &"MutedLabel"))
	for id: String in app.catalog.short_forms:
		var definition: ShortFormDefinition = app.catalog.short_forms[id] as ShortFormDefinition
		modal_body.add_child(SasaUI.label(definition.display_name, &"heading", &"AccentLabel"))
		var available: OperationResult = app.short_forms.availability(app.stream.state, id)
		if not available.success:
			modal_body.add_child(SasaUI.label(available.message, &"body", &"MutedLabel"))
		modal_body.add_child(SasaUI.label("Усталость +%d%% · базовый шанс вирусности %.1f%%" % [int(definition.fatigue_cost), definition.base_viral_chance], &"small", &"MutedLabel"))
		var publish: Button = SasaUI.button("Опубликовать", func() -> void:
			var result: OperationResult = app.short_forms.publish(app.stream.state, id)
			if result.success:
				app.queue.request_save()
				_refresh()
				_open_modal("short_result", "РОЛИК ЗАЛЕТЕЛ" if int(result.context["outcome"]) > 0 else "НЕ ЗАЛЕТЕЛ")
				modal_body.add_child(SasaUI.label("%s\nПросмотры: %d\nНовые подписчики: +%d\nУсталость: %d%%" % [result.message, result.context["views"], result.context["followers"], int(result.context["final_fatigue"])], &"body"))
				modal_body.add_child(SasaUI.button("К контенту", _show_short_forms))
			else:
				_modal_feedback(result)
		)
		publish.disabled = not available.success
		modal_body.add_child(publish)

func _show_moves(collab_only: bool) -> void:
	if collab_only:
		_show_collaborations()
		return
	if app.stream.phase == StreamService.Phase.SUMMARY:
		return
	_open_modal("collab" if collab_only else "moves", "КОЛЛАБ" if collab_only else "МУВЫ")
	if not app.stream.state.is_streaming:
		modal_body.add_child(SasaUI.label("Сначала начните эфир"))
	for id: String in app.catalog.moves:
		if id == "collab":
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
	for id: String in app.catalog.cosplays:
		var definition: CosplayDefinition = app.catalog.cosplays[id]
		modal_body.add_child(SasaUI.label("Косплей · " + definition.display_name, &"heading", &"AccentLabel"))
		modal_body.add_child(SasaUI.label("Переодеться прямо во время эфира. +%d хайпа · +%d%% свежести · больше специальных событий\n%d монет · +%.0f%% усталости" % [app.config.cosplay_hype_gain, definition.novelty_bonus * 100, definition.money_cost, definition.fatigue_cost], &"body", &"MutedLabel"))
		var status: Label = SasaUI.label(app.moves.cosplay_status(app.stream.state, id), &"small", &"MutedLabel")
		status.set_meta("cooldown_id", "cosplay:" + id)
		modal_body.add_child(status)
		var button: Button = SasaUI.button("Использовать", func() -> void:
			var result: OperationResult = app.stream.perform_move("cosplay:" + id)
			_show_moves(false)
			_modal_feedback(result))
		button.set_meta("move_id", "cosplay:" + id)
		button.disabled = status.text != "Готово"
		modal_body.add_child(button)
	modal_body.add_child(SasaUI.label("Мувы увеличивают усталость. Отдых между эфирами восстанавливает силы.", &"small", &"MutedLabel"))

func _show_collaborations() -> void:
	if app.stream.phase == StreamService.Phase.SUMMARY:
		return
	_open_modal("collaborations", "КОЛЛАБОРАЦИИ")
	modal_body.add_child(SasaUI.label("Шансы и отношения являются игровыми. Размер канала основан на сохранённом снимке данных.", &"small", &"MutedLabel"))
	collab_timer_label = SasaUI.label("Новые предложения через " + _time(app.config.collab_refresh_seconds), &"small", &"MutedLabel")
	modal_body.add_child(collab_timer_label)
	if not app.inbound.current(app.stream.state).is_empty():
		modal_body.add_child(SasaUI.button("Входящее приглашение", _show_incoming))
	if app.stream.state.is_streaming:
		modal_body.add_child(SasaUI.label("Предлагайте коллаб между эфирами."))
	_shown_candidate_ids = app.collaborations.candidates(app.stream.state)
	_shown_generation = app.collaborations.candidate_generation
	refresh_pending = false
	collab_timer_label.text = "Новые предложения через " + _time(maxi(0, app.stream.state.collab_candidate_refresh_at - int(app.collaborations.clock.call())))
	app.queue.request_save()
	for id: String in _shown_candidate_ids:
		var author: StreamerDefinition = app.collaborations.profile(id)
		modal_body.add_child(SasaUI.label(author.display_name, &"heading", &"AccentLabel"))
		modal_body.add_child(SasaUI.label("Размер по онлайну: %s · отношения: %+.0f\nСредний онлайн снимка: ≈%d\nДанные: %s" % [app.collaborations.size_label(id), app.collaborations.social.relationship(app.stream.state, id), author.reference_avg_viewers, author.source_checked_at], &"small", &"MutedLabel"))
		var button: Button = SasaUI.button("Выбрать формат", func() -> void: _show_collab_formats(id))
		button.disabled = app.stream.state.is_streaming
		modal_body.add_child(button)

func _show_incoming() -> void:
	var invite: Dictionary = app.inbound.current(app.stream.state)
	if invite.is_empty():
		_show_collaborations()
		return
	var id: String = invite["creator_id"]
	_open_modal("incoming", "ПРЕДЛОЖЕНИЕ КОЛЛАБА")
	modal_body.add_child(SasaUI.label("%s предлагает %s\nРазмер по онлайну: %s\nОтношения: %+.0f" % [app.collaborations.profile(id).display_name, app.catalog.streams[invite["format"]].title, app.collaborations.size_label(id), app.collaborations.social.relationship(app.stream.state, id)], &"body"))
	if invite["accepted"]:
		modal_body.add_child(SasaUI.label("Принято. Проведите эфир этого формата не менее %d с. Осталось: %s" % [app.config.inbound_min_stream_seconds, _time(maxi(0, int(invite["expires_at"]) - int(app.inbound.clock.call())))], &"body"))
	else:
		for accept: bool in [true, false]:
			var button: Button = SasaUI.button("Принять" if accept else "Отказаться", func() -> void:
				var result: OperationResult = app.inbound.respond(app.stream.state, accept)
				app.queue.request_save()
				_show_incoming() if result.success and accept else _show_collaborations()
				_modal_feedback(result))
			button.disabled = app.stream.state.is_streaming
			modal_body.add_child(button)

func _show_collab_formats(id: String) -> void:
	var author: StreamerDefinition = app.collaborations.profile(id)
	_open_modal("collab_formats", author.display_name)
	for format: String in app.collaborations.formats(id):
		modal_body.add_child(SasaUI.button(app.catalog.streams[format].title, func() -> void: _show_collab_offer(id, format)))

func _show_collab_offer(id: String, format: String) -> void:
	_open_modal("collab_offer", app.collaborations.profile(id).display_name)
	modal_body.add_child(SasaUI.label(app.catalog.streams[format].title, &"heading", &"AccentLabel"))
	modal_body.add_child(SasaUI.label("Шанс: " + app.collaborations.label(app.collaborations.chance(app.stream.state, id, format))))
	modal_body.add_child(SasaUI.label(app.collaborations.reasons(app.stream.state, id, format), &"small", &"MutedLabel"))
	var remaining: int = app.collaborations.remaining(app.stream.state, id)
	if remaining > 0:
		modal_body.add_child(SasaUI.label("Попробуйте позже: %d с" % remaining, &"small", &"MutedLabel"))
	var button: Button = SasaUI.button("Предложить коллаб", func() -> void: _send_collab(id, format), true)
	button.disabled = remaining > 0 or app.stream.state.is_streaming
	modal_body.add_child(button)

func _send_collab(id: String, format: String) -> void:
	if _collab_waiting or modal_kind != "collab_offer":
		return
	_collab_waiting = true
	var result: OperationResult = app.collaborations.request(app.stream.state, id, format)
	app.queue.request_save()
	app.queue.flush()
	_refresh()
	_open_modal("collab_wait", "Написали…")
	modal_close.disabled = true
	await get_tree().create_timer(app.config.collab_response_delay).timeout
	_collab_waiting = false
	modal_close.disabled = false
	_show_collab_offer(id, format)
	_modal_feedback(result)

func _move_status(id: String) -> String:
	if id.begins_with("cosplay:"):
		return app.moves.cosplay_status(app.stream.state, id.trim_prefix("cosplay:"))
	if not app.stream.state.is_streaming:
		return "НЕДОСТУПНО"
	var remaining: int = app.moves.remaining(id, app.stream.elapsed)
	if remaining > 0:
		return "Восстановление: %d с" % remaining
	var definition: ActionDefinition = app.catalog.moves[id]
	if app.stream.state.level < definition.required_level:
		return "Требуется уровень %d" % definition.required_level
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
		var available: OperationResult = app.upgrades.availability(app.stream.state, id)
		button.disabled = not available.success
		modal_body.add_child(SasaUI.label("Следующий: %d · Нужен УР. %d" % [level + 1, app.upgrades.required_player_level(app.stream.state, id)], &"small", &"MutedLabel"))
		if not available.success:
			modal_body.add_child(SasaUI.label(available.message, &"small", &"MutedLabel"))
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
	modal_body.add_child(SasaUI.label("Новых подписчиков: +%d" % int(summary.get("followers", 0)), &"body", &"SuccessLabel"))
	modal_body.add_child(SasaUI.label("Хороший эфир. Чат ждёт продолжения!", &"body", &"MutedLabel"))
	for row: Array in [["Время эфира", StreamTime.format_summary(float(summary["seconds"]))], ["Пиковый онлайн", summary["peak"]], ["Средний онлайн", "%.1f" % summary["average"]], ["Заработано", "%d монет" % summary["money"]], ["Получено XP", summary["xp"]], ["Клики", summary["clicks"]], ["Лучший ивент", summary["best_event"]]]:
		modal_body.add_child(SasaUI.label("%s\n%s" % [row[0], row[1]], &"body"))
	modal_body.add_child(SasaUI.button("Продолжить", _close_modal, true))

func _show_settings() -> void:
	if app.stream.phase == StreamService.Phase.SUMMARY:
		return
	_open_modal("settings", "НАСТРОЙКИ")
	modal_body.add_child(SasaUI.button("Достижения", _show_achievements))
	modal_body.add_child(SasaUI.button("Интерьер", _show_interior))
	modal_body.add_child(SasaUI.button("Профиль и отношения", _show_social_profile))
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

func _present_location(state: PlayerState) -> void:
	if state.current_location_id != _location_id:
		var definition: LocationDefinition = app.catalog.locations.get(state.current_location_id)
		if definition != null and definition.scene != null:
			var container: Control = %LocationContainer
			container.remove_child(room)
			room.queue_free()
			room = definition.scene.instantiate() as RoomView
			container.add_child(room)
			room.tapped.connect(_room_tapped)
			_location_id = state.current_location_id
	room.chat.config = app.config
	var cosplay: CosplayDefinition = app.catalog.cosplays.get(state.selected_cosplay_id)
	room.cosplay_variant = cosplay.sprite_variant if state.is_streaming and cosplay != null else ""
	room.present(state)

func _show_achievements() -> void:
	app.achievements.evaluate(app.stream.state)
	_open_modal("achievements", "ДОСТИЖЕНИЯ")
	modal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var screen: VBoxContainer = preload("res://src/features/stream/scenes/achievement_screen.tscn").instantiate()
	screen.custom_minimum_size.y = modal_scroll.custom_minimum_size.y
	modal_body.add_child(screen)
	(screen.get_node("Progress") as Label).text = "%d / %d" % [app.stream.state.unlocked_achievements.size(), app.catalog.achievements.size()]
	var scroll: AchievementPan = screen.get_node("Pan")
	achievement_tree = AchievementTree.new()
	scroll.add_child(achievement_tree)
	achievement_tree.setup(app.catalog, app.stream.state)
	achievement_tree.selected.connect(_achievement_selected)
	var focus: String = app.stream.state.unlocked_achievements.back() if not app.stream.state.unlocked_achievements.is_empty() else "followers_100"
	if not achievement_tree.buttons.has(focus):
		focus = "followers_100"
	scroll.focus_node.call_deferred(achievement_tree.buttons[focus])

func _achievement_selected(id: String) -> void:
	if is_instance_valid(achievement_popup):
		achievement_popup.queue_free()
	achievement_popup = PopupPanel.new()
	add_child(achievement_popup)
	var card: VBoxContainer = VBoxContainer.new()
	achievement_popup.add_child(card)
	achievement_detail = SasaUI.label("", &"body")
	achievement_detail.custom_minimum_size = Vector2(240, 0)
	card.add_child(achievement_detail)
	card.add_child(SasaUI.button("Закрыть", func() -> void: achievement_popup.hide()))
	var item: AchievementDefinition = app.catalog.achievements[id]
	var unlocked: bool = id in app.stream.state.unlocked_achievements
	if item.secret and not unlocked:
		achievement_detail.text = "? — Секретное достижение"
	else:
		achievement_detail.text = "%s\n%s\n%s" % [item.display_name, item.description, "Выполнено ✓" if unlocked else "%d / %d" % [mini(item.threshold, app.achievements._value(app.stream.state, item.metric)), item.threshold]]
	achievement_detail.text += "\nНаграда: отметка достижения (без XP и монет)"
	achievement_popup.popup_centered(Vector2i(280, 240))

func _show_interior() -> void:
	_open_modal("interior", "ИНТЕРЬЕР")
	modal_body.add_child(SasaUI.label("Тир карьеры: %d · Монеты: %d" % [app.stream.state.career_tier, app.stream.state.money], &"body", &"MutedLabel"))
	for id: String in app.catalog.room_items:
		var item: RoomItemDefinition = app.catalog.room_items[id] as RoomItemDefinition
		modal_body.add_child(SasaUI.label("%s · %s · %d монет" % [item.display_name, item.category, item.price], &"body", &"AccentLabel"))
		var button: Button = SasaUI.button("Купить" if not id in app.stream.state.owned_room_items else "Куплено", func() -> void:
			var result: OperationResult = app.room_customization.purchase_item(app.stream.state, id)
			_show_interior()
			_modal_feedback(result))
		button.disabled = id in app.stream.state.owned_room_items or app.stream.state.money < item.price or app.stream.state.career_tier < item.required_tier
		modal_body.add_child(button)
	modal_body.add_child(SasaUI.label("ПЕРЕЕЗД", &"heading", &"AccentLabel"))
	for id: String in app.catalog.homes:
		var home: HomeDefinition = app.catalog.homes[id] as HomeDefinition
		modal_body.add_child(SasaUI.label("%s · %d монет · тир %d" % [home.display_name, home.price, home.required_career_tier], &"small", &"MutedLabel"))
		modal_body.add_child(SasaUI.label("Нужен УР. %d · Ваш УР. %d" % [home.required_player_level, app.stream.state.level], &"small", &"MutedLabel"))
		var move: Button = SasaUI.button("Переехать", func() -> void:
			var result: OperationResult = app.room_customization.purchase_home(app.stream.state, id)
			_show_interior()
			_modal_feedback(result))
		var available: OperationResult = app.room_customization.home_availability(app.stream.state, id)
		move.disabled = app.stream.state.current_home_id == id or not available.success
		if not available.success:
			modal_body.add_child(SasaUI.label(available.message, &"small", &"MutedLabel"))
		modal_body.add_child(move)

func _show_social_profile() -> void:
	_open_modal("social_profile", "ПРОФИЛЬ")
	modal_body.add_child(SasaUI.label("Репутация: %.0f / 100" % app.stream.state.reputation, &"heading", &"AccentLabel"))
	modal_body.add_child(SasaUI.label("Отношения", &"heading"))
	if app.stream.state.relationships.is_empty():
		modal_body.add_child(SasaUI.label("Пока нет знакомств. Участвуйте в событиях сообщества.", &"body", &"MutedLabel"))
	for id: String in app.stream.state.relationships:
		modal_body.add_child(SasaUI.label("%s: %+.0f" % [id, float(app.stream.state.relationships[id])]))
	modal_body.add_child(SasaUI.label("Отношения, совместимость и шансы — вымышленные игровые механики. Они не описывают реальных людей и не предсказывают их поведение.", &"small", &"MutedLabel"))

func _modal_feedback(result: OperationResult) -> void:
	if result.success:
		_refresh()
		app.queue.request_save()
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

func _poll_collab_rotation() -> void:
	if modal_kind not in ["collaborations", "collab_formats", "collab_offer"]:
		return
	var state: PlayerState = app.stream.state
	var remaining: int = maxi(0, state.collab_candidate_refresh_at - int(app.collaborations.clock.call()))
	if modal_kind != "collaborations":
		refresh_pending = refresh_pending or remaining == 0
		return
	app.collaborations.candidates(state)
	if _shown_generation != app.collaborations.candidate_generation or _shown_candidate_ids != state.collab_candidate_ids:
		_show_collaborations()
	elif is_instance_valid(collab_timer_label):
		collab_timer_label.text = "Новые предложения через " + _time(remaining)

func _process(delta: float) -> void:
	if app == null:
		return
	_poll_collab_rotation()
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

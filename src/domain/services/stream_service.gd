class_name StreamService
extends RefCounted
## Session state machine; UI observes signals and sends commands only.
signal changed
signal event_available(definition: ActionDefinition)
signal stream_finished(summary: Dictionary)
enum Phase { OFFLINE, STREAMING, SUMMARY }

var state: PlayerState
var phase: Phase = Phase.OFFLINE
var elapsed: int = 0
var summary: Dictionary = {}
var catalog: ContentCatalog
var config: GameConfig
var progression: ProgressionService
var economy: EconomyService
var upgrades: UpgradeService
var moves: MoveService
var events: EventService
var logger: ILogger
var career: CareerService
var stream_novelty: float = 1.0
var _viewers_float: float = 0.0
var _viewer_sum: int = 0
var _peak: int = 0
var _earned: int = 0
var _clicks: int = 0
var _xp_fraction: float = 0.0
var _session_xp: int = 0
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
var random: RandomProvider = RandomProvider.new()
var stream_variance: float = 1.0
var inbound: InboundCollabService
var _best_event: String = "—"
var _best_score: float = -1.0

func _init(player: PlayerState, content: ContentCatalog, game_config: GameConfig, progression_service: ProgressionService, economy_service: EconomyService, upgrade_service: UpgradeService, move_service: MoveService, event_service: EventService, game_logger: ILogger) -> void:
	state = player
	catalog = content
	config = game_config
	progression = progression_service
	economy = economy_service
	upgrades = upgrade_service
	moves = move_service
	events = event_service
	logger = game_logger
	career = CareerService.new(config)

func select_content(id: String) -> OperationResult:
	if phase != Phase.OFFLINE:
		return OperationResult.fail(&"INVALID_STATE", "Контент выбирается перед эфиром")
	if not catalog.streams.has(id):
		return OperationResult.fail(&"INVALID_ARGUMENT")
	state.current_stream_type_id = id
	changed.emit()
	return OperationResult.new()

func current_content() -> StreamType:
	return catalog.streams.get(state.current_stream_type_id) as StreamType

func select_location(id: String) -> OperationResult:
	var location: LocationDefinition = catalog.locations.get(id) as LocationDefinition
	if phase != Phase.OFFLINE or location == null or location.scene == null or state.level < location.required_level:
		return OperationResult.fail(&"LOCATION_UNAVAILABLE", "Локация пока недоступна")
	state.current_location_id = id
	changed.emit()
	return OperationResult.new()

func select_cosplay(id: String) -> OperationResult:
	if phase != Phase.OFFLINE or (not id.is_empty() and not catalog.cosplays.has(id)):
		return OperationResult.fail(&"INVALID_ARGUMENT")
	state.selected_cosplay_id = id
	changed.emit()
	return OperationResult.new()

func start() -> OperationResult:
	if phase != Phase.OFFLINE or current_content() == null:
		return OperationResult.fail(&"INVALID_STATE")
	if state.fatigue >= config.exhaustion_threshold:
		return OperationResult.fail(&"EXHAUSTED", "Вы устали. Отдохните перед следующим эфиром.")
	var content: StreamType = current_content()
	var location: LocationDefinition = catalog.locations.get(state.current_location_id)
	if location == null or not state.current_stream_type_id in location.allowed_stream_types:
		return OperationResult.fail(&"LOCATION_REQUIRED", "Смените локацию для этого формата")
	if not content.required_location_id.is_empty() and state.current_location_id != content.required_location_id:
		return OperationResult.fail(&"LOCATION_REQUIRED", "Для этого формата нужна локация: Кухня")
	var cosplay: CosplayDefinition = catalog.cosplays.get(state.selected_cosplay_id) as CosplayDefinition
	if cosplay != null:
		if not state.current_stream_type_id in cosplay.stream_tags or state.money < cosplay.money_cost or state.fatigue + cosplay.fatigue_cost > 100.0:
			return OperationResult.fail(&"COSPLAY_UNAVAILABLE", "Косплей пока недоступен")
		state.money -= cosplay.money_cost
		state.fatigue += cosplay.fatigue_cost
		state.cosplay_streams += 1
	stream_novelty = career.novelty(state, state.current_stream_type_id)
	if cosplay != null:
		stream_novelty *= 1.0 + cosplay.novelty_bonus
	phase = Phase.STREAMING
	stream_variance = lerpf(config.stream_variance_min, config.stream_variance_max, random.between(0, 10000) / 10000.0)
	state.is_streaming = true
	state.viewers = 0
	state.hype = 0.0
	elapsed = 0
	_viewers_float = 0.0
	_viewer_sum = 0
	_peak = 0
	_earned = 0
	_clicks = 0
	_xp_fraction = 0.0
	_session_xp = 0
	state.fatigue_recovery_seconds = 0
	_best_event = "—"
	_best_score = -1.0
	summary.clear()
	moves.reset()
	events.schedule(0)
	logger.write("INFO", "STREAM", "stream_started", {"type": state.current_stream_type_id})
	changed.emit()
	return OperationResult.new()

func click() -> OperationResult:
	if phase != Phase.STREAMING:
		return OperationResult.fail(&"NOT_STREAMING", "Выберите игру и начните эфир")
	var gain: float = state.click_power * float(upgrades.stats(state)["hype_gain"]) * career.efficiency(state)
	_xp_fraction += config.high_hype_xp_multiplier if state.hype >= config.high_hype_xp_threshold else 1.0
	var awarded: int = int(floor(_xp_fraction + 0.000001))
	_xp_fraction -= awarded
	_session_xp += awarded
	state.hype = minf(config.hype_max, state.hype + gain)
	progression.add_xp(state, awarded)
	state.total_clicks += 1
	_clicks += 1
	changed.emit()
	return OperationResult.new(true, &"SUCCESS", "", {"hype": gain})

func tick() -> void:
	if phase != Phase.STREAMING:
		career.recover(state, config.tick_seconds)
		changed.emit()
		return
	elapsed += 1
	career.exert(state, state.current_stream_type_id, config.tick_seconds)
	state.hype = maxf(0.0, state.hype - config.hype_decay)
	var values: Dictionary = upgrades.stats(state)
	var target: float = target_viewers()
	_viewers_float = lerpf(_viewers_float, target, config.viewer_smoothing)
	state.viewers = maxi(0, int(round(_viewers_float)))
	_peak = maxi(_peak, state.viewers)
	_viewer_sum += state.viewers
	if elapsed % config.income_seconds == 0:
		var income: int = economy.calculate_income(state, current_content(), float(values["income"]))
		economy.credit(state, income)
		_earned += income
	var event: ActionDefinition = events.poll(elapsed, current_content())
	if event != null:
		event_available.emit(event)
	changed.emit()

func perform_move(id: String) -> OperationResult:
	if id == "collab":
		return OperationResult.fail(&"RETIRED_MOVE", "Коллабы доступны через экран коллабораций")
	var result: OperationResult = moves.perform(state, id, elapsed)
	if result.success:
		changed.emit()
	return result

func target_viewers() -> float:
	var boost: float = 1.0 + state.collab_momentum if state.collab_momentum_streams > 0 else 1.0
	return career.audience(state, current_content().viewer_multiplier * AudienceCurve.hype_multiplier(state.hype, config) * moves.multiplier(elapsed) * float(upgrades.stats(state)["viewers"]) * stream_novelty * career.viewer_efficiency(state) * boost * (1.0 + state.growth_momentum * config.momentum_audience_factor) * stream_variance)

func resolve_event(accept: bool) -> OperationResult:
	var definition: ActionDefinition = events.pending
	var result: OperationResult = events.resolve(state, accept, elapsed, current_content())
	if result.success:
		if accept and definition != null:
			_earned += int(result.context.get("money_gain", 0))
			var score: float = definition.hype_gain + definition.money_gain + definition.viewer_multiplier * 10.0
			if score > _best_score:
				_best_score = score
				_best_event = definition.title
		changed.emit()
	return result

func purchase_upgrade(id: String) -> OperationResult:
	var result: OperationResult = upgrades.purchase(state, id)
	if result.success:
		changed.emit()
	return result

func finish() -> OperationResult:
	if phase != Phase.STREAMING:
		return OperationResult.fail(&"INVALID_STATE")
	state.is_streaming = false
	state.total_streams += 1
	phase = Phase.SUMMARY
	summary = {"seconds": elapsed, "peak": _peak, "average": float(_viewer_sum) / maxi(1, elapsed), "money": _earned, "xp": _session_xp, "clicks": _clicks, "best_event": _best_event}
	ContentSourceService.create(state, state.current_stream_type_id, int(clock.call()))
	if state.collab_momentum_streams > 0:
		state.collab_momentum_streams -= 1
		state.collab_momentum *= 0.7
		if state.collab_momentum_streams == 0:
			state.collab_momentum = 0
	summary["followers"] = inbound.complete(state, state.current_stream_type_id, elapsed) if inbound != null else 0
	career.complete(state, summary, stream_novelty, int(clock.call()))
	state.growth_momentum *= config.momentum_stream_decay
	events.pending = null
	moves.reset()
	logger.write("INFO", "STREAM", "stream_finished", summary)
	changed.emit()
	stream_finished.emit(summary.duplicate())
	return OperationResult.new()

func continue_to_room() -> OperationResult:
	if phase != Phase.SUMMARY:
		return OperationResult.fail(&"INVALID_STATE")
	phase = Phase.OFFLINE
	state.hype = 0.0
	state.viewers = 0
	changed.emit()
	return OperationResult.new()

func set_reduced_motion(enabled: bool) -> void:
	state.settings["reduced_motion"] = enabled
	changed.emit()

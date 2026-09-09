class_name AppBootstrap
extends Node
## Composition root and application lifecycle. No global service locator.
@export_file("*.tres") var config_path: String = ""
var config: GameConfig
var logger: ILogger
var catalog: ContentCatalog
var progression: ProgressionService
var upgrades: UpgradeService
var moves: MoveService
var events: EventService
var short_forms: ShortFormService
var collaborations: CollaborationService
var inbound: InboundCollabService
var achievements: AchievementService
var room_customization: RoomCustomizationService
var saves: SaveService
var queue: SaveJobQueue
var stream: StreamService
var clicks: ClickHandler
var metrics: GameMetrics
var repository_override: SaveRepository
var _tick_accumulator: float = 0.0
var _save_accumulator: float = 0.0
var _metric_accumulator: float = 0.0
var _background: bool = false
var monotonic_clock: Callable = func() -> int: return Time.get_ticks_msec()
var _last_tick_msec: int = -1
var _tick_streaming: bool = false

func _ready() -> void:
	set_process(false)
	var controller: MainGameController = get_parent() as MainGameController
	if controller == null:
		_abort_startup("MainGameController parent is required")
		return
	var loaded_config: Resource = _load_config_resource()
	if loaded_config == null:
		_abort_startup("GameConfig resource is missing or could not be loaded")
		return
	if not loaded_config is GameConfig:
		_abort_startup("Config resource must be a GameConfig")
		return
	config = loaded_config as GameConfig
	logger = GameLogger.new(config.debug_metrics)
	catalog = ContentCatalog.new()
	progression = ProgressionService.new(config)
	upgrades = UpgradeService.new(catalog, config)
	moves = MoveService.new(catalog, upgrades, config)
	events = EventService.new(catalog, RandomProvider.new(), config, moves)
	short_forms = ShortFormService.new(catalog, config, RandomProvider.new())
	collaborations = CollaborationService.new(catalog, config, RandomProvider.new())
	inbound = InboundCollabService.new(collaborations, config, RandomProvider.new())
	achievements = AchievementService.new(catalog)
	room_customization = RoomCustomizationService.new(catalog)
	saves = SaveService.new(repository_override if repository_override != null else FileSaveRepository.new(), logger, catalog, upgrades)
	var state: PlayerState = saves.load_player()
	queue = SaveJobQueue.new(saves, state, config)
	stream = StreamService.new(state, catalog, config, progression, EconomyService.new(config, logger), upgrades, moves, events, logger)
	stream.inbound = inbound
	clicks = ClickHandler.new(stream)
	metrics = GameMetrics.new(logger, config)
	stream.changed.connect(queue.request_save)
	stream.changed.connect(_sync_session_clock)
	Engine.max_fps = config.target_fps
	get_tree().auto_accept_quit = false
	controller.configure.call_deferred(self)
	queue.request_save()
	set_process(true)
	logger.write("INFO", "APP", "game_started", {"version": ProjectSettings.get_setting("application/config/version")})

func _load_config_resource() -> Resource:
	var path: String = config_path
	if path.is_empty():
		path = "res://config/dev/game_config.tres" if OS.is_debug_build() else "res://config/prod/game_config.tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path)

func _abort_startup(reason: String) -> void:
	set_process(false)
	if logger != null:
		logger.write("ERROR", "APP", "bootstrap_failed", {"reason": reason})
	push_error("SASAclicker bootstrap failed: " + reason)

func _sync_session_clock() -> void:
	if stream.state.is_streaming != _tick_streaming:
		_tick_streaming = stream.state.is_streaming
		_tick_accumulator = 0.0
		_last_tick_msec = int(monotonic_clock.call())

func _process(delta: float) -> void:
	if stream == null or _background:
		return
	var now_msec: int = int(monotonic_clock.call())
	var real_delta: float = maxf(0, (now_msec - _last_tick_msec) / 1000.0) if _last_tick_msec >= 0 else 0.0
	_last_tick_msec = now_msec
	_tick_accumulator += real_delta
	_save_accumulator += delta
	_metric_accumulator += delta
	# Monotonic foreground time only; pause/resume discards background time.
	while _tick_accumulator >= config.tick_seconds:
		_tick_accumulator -= config.tick_seconds
		stream.tick()
		inbound.poll(stream.state)
	if _save_accumulator >= config.autosave_seconds:
		_save_accumulator = 0.0
		queue.request_save()
	queue.tick(delta)
	if _metric_accumulator >= 1.0:
		metrics.sample(_metric_accumulator, queue, events)
		_metric_accumulator = 0.0

func _notification(what: int) -> void:
	if queue == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_background = true
		queue.flush()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_background = false
		_last_tick_msec = -1
		_tick_accumulator = 0.0
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		queue.flush()
		get_tree().quit()

func _exit_tree() -> void:
	if queue != null and queue.pending:
		queue.flush()

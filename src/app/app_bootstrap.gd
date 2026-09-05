class_name AppBootstrap
extends Node
## Composition root and application lifecycle. No global service locator.
var config: GameConfig
var logger: ILogger
var catalog: ContentCatalog
var progression: ProgressionService
var upgrades: UpgradeService
var moves: MoveService
var events: EventService
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

func _ready() -> void:
	config = load("res://config/dev/game_config.tres" if OS.is_debug_build() else "res://config/prod/game_config.tres") as GameConfig
	logger = GameLogger.new(config.debug_metrics)
	catalog = ContentCatalog.new()
	progression = ProgressionService.new(config)
	upgrades = UpgradeService.new(catalog, config)
	moves = MoveService.new(catalog, upgrades, config)
	events = EventService.new(catalog, RandomProvider.new(), config, moves)
	saves = SaveService.new(repository_override if repository_override != null else FileSaveRepository.new(), logger, catalog, upgrades)
	var state: PlayerState = saves.load_player()
	queue = SaveJobQueue.new(saves, state, config)
	stream = StreamService.new(state, catalog, config, progression, EconomyService.new(config, logger), upgrades, moves, events, logger)
	clicks = ClickHandler.new(stream)
	metrics = GameMetrics.new(logger, config)
	stream.changed.connect(queue.request_save)
	get_tree().auto_accept_quit = false
	var controller: MainGameController = get_parent() as MainGameController
	controller.configure.call_deferred(self)
	queue.request_save()
	logger.write("INFO", "APP", "game_started", {"version": "0.1.0"})

func _process(delta: float) -> void:
	if stream == null or _background:
		return
	_tick_accumulator += delta
	_save_accumulator += delta
	_metric_accumulator += delta
	# Foreground stalls are capped; no offline income or background catch-up.
	if _tick_accumulator >= config.tick_seconds:
		_tick_accumulator = fmod(_tick_accumulator, config.tick_seconds)
		stream.tick()
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
		_tick_accumulator = 0.0
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		queue.flush()
		get_tree().quit()

func _exit_tree() -> void:
	if queue != null and queue.pending:
		queue.flush()

class_name GameMetrics
extends RefCounted
## Debug-only metrics port: later adapters can observe snapshot without UI changes.
var snapshot: Dictionary = {}
var low_fps_seconds: float = 0.0
var logger: ILogger
var config: GameConfig

func _init(game_logger: ILogger, game_config: GameConfig) -> void:
	logger = game_logger
	config = game_config

func sample(delta: float, queue: SaveJobQueue, events: EventService) -> void:
	if not config.debug_metrics:
		return
	var fps: float = Engine.get_frames_per_second()
	snapshot = {"fps": fps, "frame_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, "save_ms": queue.service.last_duration_ms, "queue_size": int(queue.pending), "event_ms": events.processing_ms, "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC))}
	low_fps_seconds = low_fps_seconds + delta if fps < config.warning_fps else 0.0
	if low_fps_seconds >= config.warning_duration:
		logger.write("WARNING", "PERFORMANCE", "sustained_low_fps", snapshot)
		low_fps_seconds = 0.0

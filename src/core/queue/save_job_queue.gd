class_name SaveJobQueue
extends RefCounted
## Coalesces requests without starvation. Three total attempts at .25/.5/1 seconds.
signal completed(result: OperationResult)
var service: SaveService
var state: PlayerState
var config: GameConfig
var pending: bool = false
var attempts: int = 0
var wait_left: float = 0.0
var exhausted: bool = false

func _init(save_service: SaveService, player: PlayerState, game_config: GameConfig) -> void:
	service = save_service
	state = player
	config = game_config

func request_save() -> void:
	if pending or exhausted:
		return
	pending = true
	attempts = 0
	wait_left = config.save_debounce

func tick(delta: float) -> void:
	if not pending or delta < 0.0 or not is_finite(delta):
		return
	wait_left -= delta
	if wait_left <= 0.0:
		_attempt()

## Lifecycle flush makes one immediate attempt; scheduled retries never block gameplay.
func flush() -> OperationResult:
	if exhausted:
		return OperationResult.fail(&"RETRY_EXHAUSTED")
	if not pending:
		request_save()
	return _attempt()

## Explicit retry after the user has seen a failure starts a new bounded job.
func retry_manually() -> void:
	exhausted = false
	request_save()

func _attempt() -> OperationResult:
	attempts += 1
	var result: OperationResult = service.save(state)
	if result.success:
		pending = false
		completed.emit(result)
	elif attempts >= config.retry_delays.size():
		pending = false
		exhausted = true
		service.logger.write("ERROR", "SAVE", "retry_exhausted", {"attempts": attempts})
		completed.emit(result)
	else:
		pending = true
		wait_left = config.retry_delays[attempts]
	return result

func cancel() -> void:
	pending = false
	attempts = 0
	wait_left = 0
	exhausted = false

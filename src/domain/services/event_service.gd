class_name EventService
extends RefCounted
## One pending choice at a time. All event rewards pass through domain services.
var catalog: ContentCatalog
var random: RandomProvider
var config: GameConfig
var moves: MoveService
var social: SocialService
var pending: ActionDefinition
var next_at: int = 0
var processing_ms: float = 0.0
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())

func _init(content: ContentCatalog, rng: RandomProvider, game_config: GameConfig, move_service: MoveService) -> void:
	catalog = content
	random = rng
	config = game_config
	moves = move_service
	social = SocialService.new(config)

func schedule(now: int) -> void:
	pending = null
	next_at = maxi(0, now) + random.between(config.event_min_seconds, config.event_max_seconds)

func poll(now: int, stream: StreamType) -> ActionDefinition:
	if now < 0 or stream == null or pending != null or now < next_at or catalog.events.is_empty():
		return null
	var started: int = Time.get_ticks_usec()
	var ids: Array = []
	for id: String in catalog.events:
		var candidate: ActionDefinition = catalog.events[id] as ActionDefinition
		if candidate.required_stream_type_id.is_empty() or candidate.required_stream_type_id == stream.id:
			ids.append(id)
	if ids.is_empty():
		schedule(now)
		return null
	pending = catalog.events[ids[random.between(0, ids.size() - 1)]]
	processing_ms = (Time.get_ticks_usec() - started) / 1000.0
	return pending

## Content event_multiplier scales positive event hype and viewer bonus, not costs.
func resolve(state: PlayerState, accept: bool, now: int, stream: StreamType) -> OperationResult:
	if state == null or stream == null or now < 0 or pending == null:
		return OperationResult.fail(&"INVALID_ARGUMENT")
	if not state.is_streaming:
		return OperationResult.fail(&"NOT_STREAMING")
	var result: OperationResult = OperationResult.new(true, &"SUCCESS", "Событие пропущено")
	if accept:
		if not social.can_change(state, pending.creator_reference(), pending.reputation_delta, pending.relationship_delta):
			return OperationResult.fail(&"INVALID_ARGUMENT")
		if not pending.move_id.is_empty():
			result = moves.perform(state, pending.move_id, now)
		else:
			var scaled: ActionDefinition = pending.duplicate() as ActionDefinition
			scaled.hype_gain *= stream.event_multiplier
			scaled.viewer_multiplier = 1.0 + (scaled.viewer_multiplier - 1.0) * stream.event_multiplier
			result = moves.apply_action(state, scaled, now)
		if result.success:
			social.change(state, pending.creator_reference(), pending.reputation_delta, pending.relationship_delta)
			if not pending.content_source_tag.is_empty():
				ContentSourceService.create(state, pending.content_source_tag, int(clock.call()))
	if result.success:
		schedule(now)
	return result

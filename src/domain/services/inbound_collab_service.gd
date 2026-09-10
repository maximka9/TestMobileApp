class_name InboundCollabService
extends RefCounted
var collaborations: CollaborationService
var config: GameConfig
var random: RandomProvider
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())

func _init(service: CollaborationService, settings: GameConfig, rng: RandomProvider) -> void:
	collaborations = service
	config = settings
	random = rng

func current(state: PlayerState) -> Dictionary:
	if not state.incoming_collab_queue.is_empty() and int(state.incoming_collab_queue[0]["expires_at"]) <= int(clock.call()):
		state.incoming_collab_queue.clear()
	return state.incoming_collab_queue[0] if not state.incoming_collab_queue.is_empty() else {}

func probability(state: PlayerState, id: String, format: String) -> float:
	var audience: float = maxf(AudienceCurve.baseline(state.followers, config), state.average_online)
	var author: StreamerDefinition = collaborations.profile(id)
	var gap: float = minf(1, maxf(1, audience) / maxf(1, author.reference_avg_viewers))
	var overlap: float = 1.4 if format in author.interests else 1.0
	var relation: float = maxf(0.1, 1 + collaborations.social.relationship(state, id) * 0.01)
	return clampf(config.inbound_base_chance * sqrt(gap) * overlap * relation * collaborations.social.reputation_factor(state) * (1 + state.career_tier * 0.1) * (1 + state.growth_momentum * 0.05 + state.hype / 100.0), 0, config.inbound_chance_cap)

func poll(state: PlayerState) -> void:
	if not current(state).is_empty():
		return
	var now: int = int(clock.call())
	if state.inbound_next_check_at == 0:
		state.inbound_next_check_at = now + config.inbound_check_seconds
		return
	if now < state.inbound_next_check_at:
		return
	state.inbound_next_check_at = now + config.inbound_check_seconds
	# Invite checks must not rotate the user's list while a profile is open.
	var ids: Array[String] = []
	for id: String in collaborations.directory.profiles():
		if not collaborations.formats(id).is_empty() and collaborations.remaining(state, id) == 0:
			ids.append(id)
	if ids.is_empty():
		return
	var id: String = ids[random.between(0, ids.size() - 1)]
	var formats: Array[String] = collaborations.formats(id)
	var format: String = formats[random.between(0, formats.size() - 1)]
	if collaborations.remaining(state, id) == 0 and random.between(0, 999999) / 1000000.0 < probability(state, id, format):
		state.incoming_collab_queue = [{"creator_id": id, "format": format, "created_at": now, "expires_at": now + config.inbound_expiry_seconds, "accepted": false}]

func respond(state: PlayerState, accept: bool) -> OperationResult:
	var invite: Dictionary = current(state)
	if invite.is_empty() or invite["accepted"] or state.is_streaming:
		return OperationResult.fail(&"INVALID_STATE")
	if accept and state.fatigue + config.collab_fatigue_cost > 100:
		return OperationResult.fail(&"TOO_TIRED", "Сначала отдохните")
	if accept:
		state.fatigue += config.collab_fatigue_cost
		invite["accepted"] = true
	else:
		state.collab_cooldowns[invite["creator_id"]] = int(clock.call()) + config.collab_cooldown_seconds
		state.incoming_collab_queue.clear()
	return OperationResult.new(true, &"SUCCESS", "Проведите эфир выбранного формата не менее %d с" % config.inbound_min_stream_seconds if accept else "Приглашение отклонено")

func complete(state: PlayerState, format: String, seconds: int) -> int:
	var outbound: int = collaborations.complete_pending(state, format, seconds)
	var invite: Dictionary = current(state)
	if invite.is_empty() or not invite["accepted"] or invite["format"] != format or seconds < config.inbound_min_stream_seconds:
		return outbound
	var id: String = invite["creator_id"]
	state.incoming_collab_queue.clear()
	state.collab_cooldowns[id] = int(clock.call()) + config.collab_cooldown_seconds
	return outbound + collaborations.complete_success(state, id, 1.0, format)

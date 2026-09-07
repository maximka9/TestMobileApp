class_name SocialService
extends RefCounted
## Fictional game scores only. Request hooks are consumed by the later collab engine.
var config: GameConfig

func _init(game_config: GameConfig) -> void:
	config = game_config

func relationship(state: PlayerState, author: String) -> float:
	return float(state.relationships.get(author, 0.0))

func reputation_factor(state: PlayerState) -> float:
	return lerpf(config.social_reputation_factor_min, config.social_reputation_factor_max, clampf(state.reputation / 100.0, 0.0, 1.0))

func can_change(state: PlayerState, author: String, reputation_delta: float, relationship_delta: float) -> bool:
	return state != null and is_finite(reputation_delta) and is_finite(relationship_delta) and (author.is_empty() and relationship_delta == 0.0 or _valid_author(author) and (state.relationships.has(author) or state.relationships.size() < config.social_profile_limit))

func change(state: PlayerState, author: String, reputation_delta: float, relationship_delta: float) -> OperationResult:
	if not can_change(state, author, reputation_delta, relationship_delta):
		return OperationResult.fail(&"INVALID_ARGUMENT")
	state.reputation = clampf(state.reputation + reputation_delta, 0.0, 100.0)
	if not author.is_empty():
		state.relationships[author] = clampf(relationship(state, author) + relationship_delta, -100.0, 100.0)
	return OperationResult.new()

func rejected(state: PlayerState, author: String) -> OperationResult:
	return change(state, author, 0.0, -config.social_rejection_penalty)

func record_request(state: PlayerState, author: String, now: int) -> OperationResult:
	if state == null or not _valid_author(author) or now < 0 or (not state.social_requests.has(author) and state.social_requests.size() >= config.social_profile_limit):
		return OperationResult.fail(&"INVALID_ARGUMENT")
	var window: Dictionary = state.social_requests.get(author, {"start": now, "last": now, "count": 0}).duplicate()
	if now < int(window["last"]):
		return OperationResult.fail(&"INVALID_ARGUMENT")
	if now - int(window["start"]) >= config.social_spam_window:
		window = {"start": now, "last": now, "count": 0}
	window["last"] = now
	window["count"] = mini(1000000, int(window["count"]) + 1)
	var spam: bool = int(window["count"]) > config.social_spam_allowance
	if spam:
		state.reputation = clampf(state.reputation - config.social_spam_penalty, 0.0, 100.0)
	state.social_requests[author] = window
	return OperationResult.new(true, &"SUCCESS", "", {"spam": spam})

func _valid_author(author: String) -> bool:
	return not author.strip_edges().is_empty() and author.length() <= 64

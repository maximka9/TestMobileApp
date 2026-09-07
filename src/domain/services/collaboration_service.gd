class_name CollaborationService
extends RefCounted
## Resolves requests locally; injected RNG/clock make outcomes and cooldown tests reproducible.
const LABELS: PackedStringArray = ["ОЧЕНЬ НИЗКИЙ", "НИЗКИЙ", "СРЕДНИЙ", "ВЫСОКИЙ"]
var catalog: ContentCatalog
var config: GameConfig
var social: SocialService
var random: RandomProvider
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())

func _init(content: ContentCatalog, game_config: GameConfig, rng: RandomProvider) -> void:
	catalog = content
	config = game_config
	random = rng
	social = SocialService.new(config)

func formats(id: String) -> Array[String]:
	var result: Array[String] = []
	var author: StreamerDefinition = catalog.streamers.get(id) as StreamerDefinition
	if author != null:
		for format: String in author.collab_formats:
			if catalog.streams.has(format):
				result.append(format)
	return result

func candidates(state: PlayerState) -> Array[String]:
	var ids: Array = catalog.streamers.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var x: int = catalog.streamers[a].reference_avg_viewers
		var y: int = catalog.streamers[b].reference_avg_viewers
		return x < y if x != y else a < b)
	var groups: Array = [[], [], [], []]
	var audience: float = maxf(1.0, state.average_online)
	for id: String in ids:
		if formats(id).is_empty():
			continue
		var reach: float = catalog.streamers[id].reference_avg_viewers
		var group: int = 0 if reach < audience * config.collab_near_min else 1 if reach <= audience * config.collab_near_max else 2
		groups[group].append(id)
	if not groups[2].is_empty():
		groups[3].append(groups[2].pop_back())
	var result: Array[String] = []
	var wanted: int = 0
	for i: int in range(4):
		wanted += config.collab_candidate_quotas[i]
		for j: int in range(mini(groups[i].size(), config.collab_candidate_quotas[i])):
			result.append(groups[i][j])
	for id: String in ids:
		if result.size() >= wanted:
			break
		if not id in result and not formats(id).is_empty():
			result.append(id)
	return result

func chance(state: PlayerState, id: String, format: String) -> float:
	if not format in formats(id):
		return 0.0
	var author: StreamerDefinition = catalog.streamers[id]
	var ratio: float = minf(1.0, maxf(1.0, state.average_online) / maxf(1.0, author.reference_avg_viewers))
	var interest: float = 1.0 + (config.collab_interest_bonus if format in author.interests else 0.0)
	var relation: float = maxf(0.0, 1.0 + social.relationship(state, id) * config.collab_relationship_weight)
	var window: Dictionary = state.social_requests.get(id, {})
	var repeats: int = int(window.get("count", 0)) if int(clock.call()) - int(window.get("start", 0)) < config.social_spam_window else 0
	var score: float = author.base_acceptance * pow(ratio, config.collab_gap_exponent) * interest * relation * social.reputation_factor(state) / (1.0 + repeats * config.collab_repeat_penalty)
	score *= 1.0 + state.growth_momentum * config.collab_momentum_weight
	return clampf(score, config.collab_chance_min, config.collab_chance_max)

func label(score: float) -> String:
	var band: int = 0
	for threshold: float in config.collab_chance_bands:
		if score >= threshold:
			band += 1
	return LABELS[mini(band, LABELS.size() - 1)]

func reasons(state: PlayerState, id: String, format: String) -> String:
	var author: StreamerDefinition = catalog.streamers[id]
	return "%s\n%s\n%s\n%s" % ["− Ваш канал пока меньше" if state.average_online < author.reference_avg_viewers else "+ Сопоставимая аудитория", "+ Общий интерес к формату" if format in author.interests else "± Формат поддерживается, но не входит в интересы", "± Вы ещё не знакомы" if social.relationship(state, id) == 0 else "Отношения: %+.0f" % social.relationship(state, id), "Репутация: %.0f / 100" % state.reputation]

func remaining(state: PlayerState, id: String) -> int:
	return maxi(0, int(state.collab_cooldowns.get(id, 0)) - int(clock.call()))

func request(state: PlayerState, id: String, format: String) -> OperationResult:
	if state == null or not format in formats(id):
		return OperationResult.fail(&"INVALID_ARGUMENT", "Формат недоступен")
	if state.is_streaming:
		return OperationResult.fail(&"BUSY_STREAMING", "Предлагайте коллаб между эфирами")
	if not social.can_change(state, id, 0, 0) or (not state.collab_cooldowns.has(id) and state.collab_cooldowns.size() >= config.social_profile_limit):
		return OperationResult.fail(&"INVALID_ARGUMENT")
	var probability: float = chance(state, id, format)
	var now: int = int(clock.call())
	var tracked: OperationResult = social.record_request(state, id, now)
	if not tracked.success:
		return tracked
	if remaining(state, id) > 0:
		return OperationResult.fail(&"ON_COOLDOWN", "Повторно предложить нельзя. Попробуйте позже.")
	var author: StreamerDefinition = catalog.streamers[id]
	var accepted: bool = float(random.between(0, 999999)) / 1000000.0 < probability
	state.collab_cooldowns[id] = now + config.collab_cooldown_seconds + author.reach_tier * config.collab_tier_cooldown_seconds
	if not accepted:
		social.rejected(state, id)
		return OperationResult.new(true, &"SUCCESS", "Ответ пришёл: отказ. Попробуйте позже.", {"accepted": false, "followers": 0})
	var reach: float = minf(float(author.reference_avg_viewers), maxf(1.0, float(state.followers)))
	var gained: int = clampi(int(sqrt(reach) * config.collab_follower_scale), 1, config.collab_follower_cap)
	state.followers += gained
	state.lifetime_followers_gained += gained
	state.completed_collabs += 1
	state.growth_momentum = minf(100.0, state.growth_momentum + config.collab_momentum_gain)
	social.change(state, id, config.collab_reputation_gain, config.collab_relationship_gain)
	return OperationResult.new(true, &"SUCCESS", "Ответ пришёл: коллаб состоялся! +%d подписчиков, временное ускорение аудитории." % gained, {"accepted": true, "followers": gained})

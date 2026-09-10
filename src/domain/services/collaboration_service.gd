class_name CollaborationService
extends RefCounted
## Resolves requests locally; injected RNG/clock make outcomes and cooldown tests reproducible.
const LABELS: PackedStringArray = ["ОЧЕНЬ НИЗКИЙ", "НИЗКИЙ", "СРЕДНИЙ", "ВЫСОКИЙ"]
var catalog: ContentCatalog
var config: GameConfig
var social: SocialService
var random: RandomProvider
var directory: StreamerDirectoryRepository
var candidate_generation: int = 0
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())

func _init(content: ContentCatalog, game_config: GameConfig, rng: RandomProvider) -> void:
	catalog = content
	config = game_config
	random = rng
	directory = LocalStreamerDirectoryRepository.new(content)
	social = SocialService.new(config)

func formats(id: String) -> Array[String]:
	var result: Array[String] = []
	var author: StreamerDefinition = profile(id)
	if author != null:
		for format: String in author.collab_formats:
			if catalog.streams.has(format):
				result.append(format)
	return result

func candidates(state: PlayerState) -> Array[String]:
	var now: int = int(clock.call())
	if not state.collab_candidate_ids.is_empty() and now < state.collab_candidate_refresh_at:
		return state.collab_candidate_ids.duplicate()
	return refresh_candidates(state)

func refresh_candidates(state: PlayerState) -> Array[String]:
	var now: int = int(clock.call())
	var previous: Array[String] = state.collab_candidate_ids.duplicate()
	var selected: Array[String] = _select_candidates(state)
	var old_set: Array[String] = previous.duplicate()
	var new_set: Array[String] = selected.duplicate()
	old_set.sort()
	new_set.sort()
	if old_set == new_set and not selected.is_empty():
		for id: String in directory.profiles():
			if not id in selected and not id in config.featured_collab_creator_ids and not formats(id).is_empty():
				selected[0] = id
				break
	state.collab_candidate_ids = selected
	candidate_generation += 1
	state.collab_candidate_refresh_at = now + config.collab_refresh_seconds
	for id: String in state.collab_candidate_ids:
		state.recent_candidate_ids.erase(id)
		state.recent_candidate_ids.append(id)
	while state.recent_candidate_ids.size() > config.collab_recent_limit:
		state.recent_candidate_ids.pop_front()
	return state.collab_candidate_ids.duplicate()

func _select_candidates(state: PlayerState) -> Array[String]:
	var ids: Array = directory.profiles().keys().filter(func(id: String) -> bool: return not id in config.featured_collab_creator_ids)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var x: int = profile(a).reference_avg_viewers
		var y: int = profile(b).reference_avg_viewers
		return x < y if x != y else a < b)
	var groups: Array = [[], [], [], []]
	var audience: float = maxf(AudienceCurve.baseline(state.followers, config), maxf(1.0, state.average_online))
	for id: String in ids:
		if formats(id).is_empty():
			continue
		var reach: float = profile(id).reference_avg_viewers
		var group: int = 0 if reach < audience * config.collab_near_min else 1 if reach <= audience * config.collab_near_max else 2
		groups[group].append(id)
	for i: int in range(maxi(1, int(groups[2].size() / 10.0))):
		if groups[2].is_empty():
			break
		groups[3].append(groups[2].pop_back())
	for group: Array in groups:
		for i: int in range(group.size() - 1, 0, -1):
			var j: int = random.between(0, i)
			var swap: String = group[i]
			group[i] = group[j]
			group[j] = swap
		group.sort_custom(func(a: String, b: String) -> bool: return (0 if not a in state.recent_candidate_ids else 1) < (0 if not b in state.recent_candidate_ids else 1))
	var result: Array[String] = []
	var wanted: int = 0
	var has_featured: bool = false
	for id: String in config.featured_collab_creator_ids:
		has_featured = has_featured or (profile(id) != null and not formats(id).is_empty())
	for i: int in range(4):
		var quota: int = maxi(0, config.collab_candidate_quotas[i] - (1 if has_featured and i == 1 else 0))
		wanted += quota
		for j: int in range(mini(groups[i].size(), quota)):
			result.append(groups[i][j])
	for id: String in ids:
		if result.size() >= wanted:
			break
		if not id in result and not formats(id).is_empty():
			result.append(id)
	var featured: Array[String] = []
	for id: String in config.featured_collab_creator_ids:
		if profile(id) != null and not formats(id).is_empty():
			featured.append(id)
	if not featured.is_empty():
		result.resize(mini(9, result.size()))
		var available: Array[String] = featured.filter(func(id: String) -> bool: return remaining(state, id) == 0)
		if not available.is_empty():
			featured = available
		if featured.size() > 1 and not state.collab_candidate_ids.is_empty():
			featured.erase(state.collab_candidate_ids.back())
		result.append(featured[random.between(0, featured.size() - 1)])
	return result

func chance(state: PlayerState, id: String, format: String) -> float:
	if not format in formats(id):
		return 0.0
	var author: StreamerDefinition = profile(id)
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
	var author: StreamerDefinition = profile(id)
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
	if not state.pending_outbound_collab.is_empty():
		return OperationResult.fail(&"COLLAB_PENDING", "Сначала завершите запланированный IRL-коллаб")
	var probability: float = chance(state, id, format)
	var now: int = int(clock.call())
	var tracked: OperationResult = social.record_request(state, id, now)
	if not tracked.success:
		return tracked
	if remaining(state, id) > 0:
		return OperationResult.fail(&"ON_COOLDOWN", "Повторно предложить нельзя. Попробуйте позже.")
	if state.fatigue + config.collab_fatigue_cost > 100:
		return OperationResult.fail(&"TOO_TIRED", "Сначала отдохните")
	var author: StreamerDefinition = profile(id)
	var accepted: bool = float(random.between(0, 999999)) / 1000000.0 < probability
	state.collab_cooldowns[id] = now + config.collab_cooldown_seconds + author.reach_tier * config.collab_tier_cooldown_seconds
	if not accepted:
		social.rejected(state, id)
		return OperationResult.new(true, &"SUCCESS", "Ответ пришёл: отказ. Попробуйте позже.", {"accepted": false, "followers": 0})
	state.fatigue += config.collab_fatigue_cost
	if id in config.featured_collab_creator_ids and format == "irl":
		state.pending_outbound_collab = {"creator_id": id, "format": format}
		return OperationResult.new(true, &"SUCCESS", "Автор согласился! Проведите IRL-эфир не короче 30 секунд, чтобы завершить коллаб.", {"accepted": true, "followers": 0})
	var gained: int = complete_success(state, id, 1.0, format)
	return OperationResult.new(true, &"SUCCESS", "Коллаб состоялся! +%d подписчиков. Онлайн следующих эфиров усилен." % gained, {"accepted": true, "followers": gained})

func complete_success(state: PlayerState, id: String, performance: float = 1.0, format: String = "") -> int:
	var author: StreamerDefinition = profile(id)
	var growth: FollowerGrowthService = FollowerGrowthService.new(config)
	var gained: int = growth.calculate_collab_gain(author, state.followers, performance)
	growth.award(state, gained)
	state.completed_collabs += 1
	if format == "irl" and not id in state.completed_irl_collab_creator_ids:
		state.completed_irl_collab_creator_ids.append(id)
	if author.reach_tier >= 3:
		state.high_tier_collabs += 1
	state.collab_momentum = config.collab_viewer_boost
	state.collab_momentum_streams = config.collab_boost_streams
	social.change(state, id, config.collab_reputation_gain, config.collab_relationship_gain)
	return gained

func size_label(id: String) -> String:
	var reach: int = profile(id).reference_avg_viewers
	return "НЕБОЛЬШОЙ" if reach < 100 else "СРЕДНИЙ" if reach < 1000 else "КРУПНЫЙ" if reach < 5000 else "ТОПОВЫЙ"

func profile(id: String) -> StreamerDefinition:
	return directory.profiles().get(id) as StreamerDefinition

func complete_pending(state: PlayerState, format: String, seconds: int) -> int:
	var pending: Dictionary = state.pending_outbound_collab
	if pending.is_empty() or pending["format"] != format or seconds < config.inbound_min_stream_seconds:
		return 0
	state.pending_outbound_collab = {}
	return complete_success(state, pending["creator_id"], 1.0, format)

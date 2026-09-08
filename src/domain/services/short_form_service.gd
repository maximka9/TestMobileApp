class_name ShortFormService
extends RefCounted
## Deterministic through injected RandomProvider; no platform API or UI randomness.
const OUTCOMES: PackedStringArray = ["Не залетел", "Нормально", "Хорошо залетел", "Вирусный", "МЕГА-ВИРУСНЫЙ"]
var catalog: ContentCatalog
var config: GameConfig
var random: RandomProvider

func _init(content: ContentCatalog, game_config: GameConfig, rng: RandomProvider) -> void:
	catalog = content
	config = game_config
	random = rng

func publish(state: PlayerState, id: String) -> OperationResult:
	if state == null or not catalog.short_forms.has(id):
		return OperationResult.fail(&"INVALID_ARGUMENT")
	if state.is_streaming:
		return OperationResult.fail(&"BUSY_STREAMING", "Сначала завершите эфир")
	var definition: ShortFormDefinition = catalog.short_forms[id] as ShortFormDefinition
	if definition == null or definition.fatigue_cost < 0 or definition.money_cost < 0:
		return OperationResult.fail(&"INVALID_ARGUMENT")
	var source_index: int = ContentSourceService.find(state, definition.source_tags)
	if source_index < 0:
		return OperationResult.fail(&"NO_SOURCE", "Нет материала. " + definition.source_hint)
	if state.money < definition.money_cost:
		return OperationResult.fail(&"NOT_ENOUGH_MONEY", "Не хватает монет")
	if state.fatigue + definition.fatigue_cost > 100.0:
		return OperationResult.fail(&"TOO_TIRED", "Слишком высокая усталость для ролика")
	state.money -= definition.money_cost
	state.content_sources[source_index]["consumed"] = true
	state.fatigue = minf(100.0, state.fatigue + definition.fatigue_cost)
	var novelty: float = _novelty(state, id)
	var viral: float = _viral_chance(state, definition, novelty)
	var outcome: int = _outcome(viral)
	var followers: int = _followers(state, definition, outcome, novelty)
	state.followers += followers
	if outcome >= 3:
		state.viral_posts += 1
	state.lifetime_followers_gained += followers
	state.growth_momentum = clampf(state.growth_momentum + config.short_momentum_gains[outcome], 0.0, 100.0)
	state.short_form_history.append(id)
	while state.short_form_history.size() > config.short_history_limit:
		state.short_form_history.pop_front()
	return OperationResult.new(true, &"SUCCESS", OUTCOMES[outcome], {"outcome": outcome, "followers": followers, "viral_chance": viral, "novelty": novelty, "momentum": state.growth_momentum})

func _viral_chance(state: PlayerState, definition: ShortFormDefinition, novelty: float) -> float:
	var baseline: float = maxf(1.0, float(config.starting_followers))
	var follower_factor: float = pow(float(maxi(0, state.followers)) / baseline, config.short_follower_factor_exponent)
	return clampf(definition.base_viral_chance * follower_factor * novelty * (1.0 + state.growth_momentum * config.short_momentum_factor), 0.0, config.short_viral_cap)

func _novelty(state: PlayerState, id: String) -> float:
	var repeats: int = 0
	for recent: String in state.short_form_history:
		if recent == id:
			repeats += 1
	return config.novelty_penalties[clampi(repeats, 0, config.novelty_penalties.size() - 1)]

func _outcome(viral: float) -> int:
	var roll: float = float(random.between(0, 9999)) / 100.0
	var mega: float = viral * config.short_mega_share
	if roll < mega:
		return 4
	if roll < viral:
		return 3
	var total: float = 0.0
	for weight: float in config.short_nonviral_weights:
		total += weight
	var weighted: float = float(random.between(0, 999999)) / 1000000.0 * total
	var cumulative: float = 0.0
	for i: int in range(config.short_nonviral_weights.size()):
		cumulative += config.short_nonviral_weights[i]
		if weighted < cumulative:
			return i
	return 2

func _followers(state: PlayerState, definition: ShortFormDefinition, outcome: int, novelty: float) -> int:
	var base: float = maxf(1.0, pow(float(maxi(0, state.followers)), 0.55) * definition.follower_multiplier)
	return mini(config.follower_gain_cap, maxi(0, int(round(base * config.short_outcome_multipliers[outcome] * novelty))))

class_name MoveService
extends RefCounted
## Owns temporary effects and cooldowns in elapsed foreground stream seconds.
var catalog: ContentCatalog
var upgrades: UpgradeService
var config: GameConfig
var cooldowns: Dictionary = {}
var effects: Dictionary = {}
var active_cosplay: CosplayDefinition

func cosplay_status(state: PlayerState, id: String) -> String:
	if not state.is_streaming:
		return "Только во время эфира"
	if active_cosplay != null:
		return "Уже использовано в этом эфире"
	var definition: CosplayDefinition = catalog.cosplays.get(id)
	if definition == null or not state.current_stream_type_id in definition.stream_tags:
		return "Недоступно для этого формата"
	if state.level < definition.required_level:
		return "Требуется уровень %d" % definition.required_level
	if state.money < definition.money_cost:
		return "Не хватает монет"
	if state.fatigue + definition.fatigue_cost > 100:
		return "Сначала отдохните"
	return "Готово"

func perform_cosplay(state: PlayerState, id: String) -> OperationResult:
	if state == null:
		return OperationResult.fail(&"INVALID_ARGUMENT")
	var status: String = cosplay_status(state, id)
	if status != "Готово":
		return OperationResult.fail(&"COSPLAY_UNAVAILABLE", status)
	active_cosplay = catalog.cosplays[id]
	state.money -= active_cosplay.money_cost
	state.fatigue += active_cosplay.fatigue_cost
	state.hype = minf(config.hype_max, state.hype + config.cosplay_hype_gain)
	state.selected_cosplay_id = id
	state.cosplay_streams += 1
	return OperationResult.new(true, &"SUCCESS", "Образ активирован до конца эфира")

func novelty_multiplier() -> float:
	return 1.0 + active_cosplay.novelty_bonus if active_cosplay != null else 1.0

func _init(content: ContentCatalog, upgrade_service: UpgradeService, game_config: GameConfig) -> void:
	catalog = content
	upgrades = upgrade_service
	config = game_config

func perform(state: PlayerState, id: String, now: int) -> OperationResult:
	if id.begins_with("cosplay:") and now >= 0:
		return perform_cosplay(state, id.trim_prefix("cosplay:"))
	if state == null or now < 0 or not catalog.moves.has(id):
		return OperationResult.fail(&"INVALID_ARGUMENT")
	if not state.is_streaming:
		return OperationResult.fail(&"NOT_STREAMING", "Сначала начните эфир")
	if remaining(id, now) > 0:
		return OperationResult.fail(&"ON_COOLDOWN", "Мув ещё восстанавливается")
	var definition: ActionDefinition = catalog.moves[id]
	if state.level < definition.required_level:
		return OperationResult.fail(&"LEVEL_LOCKED")
	var result: OperationResult = apply_action(state, definition, now)
	if result.success:
		cooldowns[id] = now + definition.cooldown
	return result

func apply_action(state: PlayerState, definition: ActionDefinition, now: int) -> OperationResult:
	if state == null or definition == null or now < 0:
		return OperationResult.fail(&"INVALID_ARGUMENT")
	if definition.id.is_empty() or definition.money_cost < 0 or definition.money_gain < 0 or definition.duration < 0 or definition.cooldown < 0:
		return OperationResult.fail(&"INVALID_ARGUMENT")
	if not is_finite(definition.energy_cost) or definition.energy_cost < 0 or not is_finite(definition.hype_gain) or not is_finite(definition.viewer_multiplier) or definition.viewer_multiplier <= 0:
		return OperationResult.fail(&"INVALID_ARGUMENT")
	if not state.is_streaming:
		return OperationResult.fail(&"NOT_STREAMING")
	var energy_cost: float = definition.energy_cost / float(upgrades.stats(state)["max_energy"]) * config.base_energy
	if state.money < definition.money_cost:
		return OperationResult.fail(&"NOT_ENOUGH_MONEY", "Не хватает денег")
	if state.energy < energy_cost:
		return OperationResult.fail(&"NOT_ENOUGH_ENERGY", "Не хватает энергии. Отдохните между эфирами")
	state.money += definition.money_gain - definition.money_cost
	var effective_hype: float = definition.hype_gain * CareerService.new(config).efficiency(state)
	state.energy -= energy_cost
	state.hype = clampf(state.hype + effective_hype, 0.0, config.hype_max)
	if definition.duration > 0:
		effects[definition.id] = {"until": now + definition.duration, "multiplier": definition.viewer_multiplier}
	return OperationResult.new(true, &"SUCCESS", definition.title, {"money_gain": definition.money_gain})

func remaining(id: String, now: int) -> int:
	return maxi(0, int(cooldowns.get(id, 0)) - maxi(0, now))

func multiplier(now: int) -> float:
	var value: float = 1.0
	for id: String in effects.keys():
		if now >= int(effects[id]["until"]):
			effects.erase(id)
		else:
			value *= float(effects[id]["multiplier"])
	return value

func reset() -> void:
	active_cosplay = null
	cooldowns.clear()
	effects.clear()

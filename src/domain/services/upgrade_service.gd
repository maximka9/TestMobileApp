class_name UpgradeService
extends RefCounted
## Applies every upgrade via its stat field, without per-item handlers.
var catalog: ContentCatalog
var config: GameConfig

func _init(content: ContentCatalog, game_config: GameConfig) -> void:
	catalog = content
	config = game_config

func stats(state: PlayerState) -> Dictionary:
	var values: Dictionary = {"click_power": 1.0, "income": 1.0, "click_xp_multiplier": 1.0, "max_energy": config.base_energy, "viewers": 1.0}
	if state == null:
		return values
	for id: String in catalog.upgrades:
		var definition: UpgradeDefinition = catalog.upgrades[id]
		values[definition.stat] += definition.amount * int(state.upgrades.get(id, 0))
	return values

func cost(state: PlayerState, id: String) -> int:
	if state == null or not catalog.upgrades.has(id):
		return -1
	var definition: UpgradeDefinition = catalog.upgrades[id]
	return int(ceil(definition.base_cost * pow(config.upgrade_growth, int(state.upgrades.get(id, 0)))))

func availability(state: PlayerState, id: String) -> OperationResult:
	if state == null or not catalog.upgrades.has(id):
		return OperationResult.fail(&"INVALID_ARGUMENT")
	var definition: UpgradeDefinition = catalog.upgrades[id]
	if int(state.upgrades.get(id, 0)) >= definition.max_level:
		return OperationResult.fail(&"MAX_LEVEL", "Достигнут максимальный уровень")
	if state.level < required_player_level(state, id):
		return OperationResult.fail(&"LEVEL_LOCKED", "Следующий уровень откроется на УР. %d" % required_player_level(state, id))
	var price: int = cost(state, id)
	if state.money < price:
		return OperationResult.fail(&"NOT_ENOUGH_MONEY", "Не хватает денег")
	return OperationResult.new()

func required_player_level(state: PlayerState, id: String) -> int:
	var next: int = int(state.upgrades.get(id, 0)) + 1
	return maxi(catalog.upgrades[id].required_level, 1 if next == 1 else next * 2)

func effective_max_level(state: PlayerState, id: String) -> int:
	return mini(catalog.upgrades[id].max_level, maxi(1, state.level / 2))

func purchase(state: PlayerState, id: String) -> OperationResult:
	var result: OperationResult = availability(state, id)
	if not result.success:
		return result
	state.money -= cost(state, id)
	state.upgrades[id] = int(state.upgrades.get(id, 0)) + 1
	state.click_power = int(stats(state)["click_power"])
	return OperationResult.new(true, &"SUCCESS", "Улучшение куплено")

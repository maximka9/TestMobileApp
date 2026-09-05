class_name ProgressionService
extends RefCounted
## Carries XP remainder through every level crossed by a reward.
var config: GameConfig

func _init(game_config: GameConfig) -> void:
	config = game_config

func required_xp(level: int) -> int:
	return int(ceil(config.xp_base * pow(maxi(1, level), config.xp_exponent)))

func add_xp(state: PlayerState, amount: int) -> OperationResult:
	if state == null or amount < 0 or amount > 1000000:
		return OperationResult.fail(&"INVALID_ARGUMENT")
	state.xp += amount
	while state.xp >= required_xp(state.level):
		state.xp -= required_xp(state.level)
		state.level += 1
	return OperationResult.new()

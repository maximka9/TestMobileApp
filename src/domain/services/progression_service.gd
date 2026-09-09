class_name ProgressionService
extends RefCounted
## Carries XP remainder through every level crossed by a reward.
var config: GameConfig

func _init(game_config: GameConfig) -> void:
	config = game_config

func required_xp(level: int) -> int:
	return config.xp_base * maxi(1, level)

func add_xp(state: PlayerState, amount: int) -> OperationResult:
	if state == null or amount < 0 or amount > 1000000:
		return OperationResult.fail(&"INVALID_ARGUMENT")
	state.xp += amount
	while state.xp >= required_xp(state.level):
		state.xp -= required_xp(state.level)
		state.level += 1
	return OperationResult.new()

func click_xp(level: int, click_power: float, hype: float) -> float:
	var multiplier: float = minf(config.click_xp_multiplier_cap, 1.0 + maxf(0, click_power - 1) * config.click_xp_power_factor)
	return maxi(1, level) * multiplier * (config.high_hype_xp_multiplier if hype >= config.high_hype_xp_threshold else 1.0)

func hype_mastery(level: int) -> float:
	return 1.0 + minf(maxi(0, level - 1) * config.level_hype_factor, config.level_hype_bonus_cap)

func migrate_xp(level: int, old_xp: int) -> int:
	var old_required: float = ceil(50.0 * pow(maxi(1, level), 1.5))
	return clampi(int(round(old_xp / old_required * required_xp(level))), 0, required_xp(level) - 1)

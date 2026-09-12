class_name ProgressionService
extends RefCounted
## Carries XP remainder through every level crossed by a reward.
var config: GameConfig

func _init(game_config: GameConfig) -> void:
	config = game_config

func required_xp(_level: int) -> int:
	return 100

func add_xp(state: PlayerState, amount: int) -> OperationResult:
	if state == null or amount < 0 or amount > PlayerState.MAX_LEVEL:
		return OperationResult.fail(&"INVALID_ARGUMENT")
	state.xp += amount
	FollowerGrowthService.new(config).award(state, amount)
	@warning_ignore("integer_division")
	var levels: int = state.xp / required_xp(state.level)
	state.level += levels
	state.xp %= required_xp(state.level)
	return OperationResult.new()

func click_xp(level: int, click_power: float, hype: float, equipment_multiplier: float = 1.0) -> float:
	var multiplier: float = minf(config.click_xp_multiplier_cap, (1.0 + maxf(0, click_power - 1) * config.click_xp_power_factor) * equipment_multiplier)
	return maxi(1, level) * multiplier * float(AudienceCurve.get_hype_modifiers(hype, config)["xp"])

func hype_mastery(_level: int) -> float:
	return 1.0

func migrate_xp(level: int, old_xp: int) -> int:
	var old_required: float = ceil(50.0 * pow(maxi(1, level), 1.5))
	return clampi(int(round(old_xp / old_required * required_xp(level))), 0, required_xp(level) - 1)

class_name EconomyService
extends RefCounted
## Income is credited by StreamService only at complete income intervals.
var config: GameConfig
var logger: ILogger

func _init(game_config: GameConfig, game_logger: ILogger) -> void:
	config = game_config
	logger = game_logger

func calculate_income(state: PlayerState, stream: StreamType, multiplier: float = 1.0) -> int:
	if state == null or stream == null or not state.is_streaming or not is_finite(multiplier) or multiplier <= 0:
		return 0
	return maxi(1, int(floor(state.viewers * config.income_rate * stream.income_multiplier * multiplier)))

func credit(state: PlayerState, amount: int) -> OperationResult:
	if state == null or amount < 0:
		return OperationResult.fail(&"INVALID_ARGUMENT")
	state.money += amount
	logger.write("DEBUG", "ECONOMY", "money_added", {"amount": amount, "balance": state.money})
	return OperationResult.new()

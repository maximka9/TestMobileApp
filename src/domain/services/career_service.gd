class_name CareerService
extends RefCounted
## Bounded career state; energy remains a compatibility view of fatigue, not a second resource.
var config: GameConfig

func _init(game_config: GameConfig) -> void:
	config = game_config

func new_player() -> PlayerState:
	var player: PlayerState = PlayerState.new()
	player.followers = clampi(config.starting_followers, 20, 50)
	player.fatigue = clampf(config.starting_fatigue, 0.0, 100.0)
	player.reputation = clampf(config.starting_reputation, 0.0, 100.0)
	return player

func recover(player: PlayerState, seconds: float) -> void:
	player.fatigue = clampf(player.fatigue - maxf(0.0, seconds) * config.fatigue_recovery, 0.0, 100.0)

func recover_offline(player: PlayerState, saved_at: int, now: int) -> void:
	recover(player, clampi(now - saved_at, 0, config.offline_recovery_cap))

func exert(player: PlayerState, content_id: String, seconds: float) -> void:
	player.fatigue = clampf(player.fatigue + config.fatigue_rate * float(config.fatigue_multipliers.get(content_id, 1.0)) * maxf(0.0, seconds), 0.0, 100.0)

func efficiency(player: PlayerState) -> float:
	var band: int = 0
	for threshold: float in config.fatigue_steps:
		if player.fatigue >= threshold:
			band += 1
	return config.fatigue_efficiency[mini(band, config.fatigue_efficiency.size() - 1)]

func novelty(player: PlayerState, content_id: String) -> float:
	# Recency-weighted repeats: each intervening different format restores one step.
	var repeats: int = 0
	var variety: int = 0
	for i: int in range(player.last_stream_types.size() - 1, maxi(-1, player.last_stream_types.size() - config.novelty_window - 1), -1):
		if player.last_stream_types[i] == content_id:
			repeats += 1
		else:
			variety += 1
	return config.novelty_penalties[clampi(repeats - variety, 0, config.novelty_penalties.size() - 1)]

func audience(player: PlayerState, multiplier: float) -> float:
	var reach: float = config.audience_scale * pow(float(maxi(0, player.followers)), config.audience_exponent)
	var bounded: float = reach * clampf(multiplier, 0.0, config.audience_multiplier_cap)
	return config.audience_soft_cap * bounded / (config.audience_soft_cap + bounded)

func complete(player: PlayerState, summary: Dictionary, stream_novelty: float, timestamp: int) -> int:
	var gain: int = mini(config.follower_gain_cap, maxi(0, int(float(summary["average"]) * int(summary["seconds"]) * config.follower_conversion * stream_novelty)))
	player.followers += gain
	player.lifetime_followers_gained += gain
	player.lifetime_peak_viewers = maxi(player.lifetime_peak_viewers, int(summary["peak"]))
	player.stream_history.append({"stream_type": player.current_stream_type_id, "location": player.current_location_id, "duration": int(summary["seconds"]), "average_viewers": float(summary["average"]), "peak_viewers": int(summary["peak"]), "followers_gained": gain, "money_gained": int(summary["money"]), "novelty": stream_novelty, "timestamp": timestamp})
	while player.stream_history.size() > config.history_limit:
		player.stream_history.pop_front()
	player.last_stream_types.append(player.current_stream_type_id)
	while player.last_stream_types.size() > config.novelty_window:
		player.last_stream_types.pop_front()
	var count: int = mini(player.stream_history.size(), config.average_window)
	var total: float = 0.0
	for i: int in range(player.stream_history.size() - count, player.stream_history.size()):
		total += float(player.stream_history[i]["average_viewers"])
	player.average_online = total / maxi(1, count)
	player.career_tier = 0 if player.followers < 100 else 1 if player.followers < 1000 else 2 if player.followers < 10000 else 3
	return gain

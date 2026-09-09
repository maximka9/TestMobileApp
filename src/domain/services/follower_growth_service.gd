class_name FollowerGrowthService
extends RefCounted
enum TikTokOutcome { FLOP, NORMAL, GOOD, VIRAL, MEGA_VIRAL }
var config: GameConfig
var random: RandomProvider = RandomProvider.new()
var career_tier: int = 0

func _init(settings: GameConfig) -> void:
	config = settings

func expected_stream_gain(average_viewers: float, game_minutes: int, average_hype: float, novelty_multiplier: float, reputation: float) -> float:
	var quality: float = float(AudienceCurve.get_hype_modifiers(average_hype, config)["followers"])
	var exposure: float = maxf(0, average_viewers) * clampi(game_minutes, 0, config.organic_duration_cap_minutes)
	var reputation_factor: float = lerpf(config.social_reputation_factor_min, config.social_reputation_factor_max, clampf(reputation / 100.0, 0, 1))
	var tier_factor: float = config.organic_tier_multipliers[clampi(career_tier, 0, config.organic_tier_multipliers.size() - 1)]
	var raw: float = exposure * quality * clampf(novelty_multiplier, 0, 1.5) * reputation_factor * tier_factor * config.organic_exposure_conversion
	return config.organic_gain_cap * raw / (config.organic_gain_cap + raw)

func calculate_stream_gain(average_viewers: float, game_minutes: int, average_hype: float, novelty_multiplier: float, reputation: float) -> int:
	var expected: float = expected_stream_gain(average_viewers, game_minutes, average_hype, novelty_multiplier, reputation)
	var whole: int = floori(expected)
	return whole + (1 if random.between(0, 999999) / 1000000.0 < expected - whole else 0)

func calculate_tiktok_gain(outcome: int, followers: int, reputation: float, novelty: float = 1.0, quality: float = 1.0) -> int:
	var base: float = maxf(config.short_minimum_gains[outcome], followers * config.short_follower_percentages[outcome])
	var reputation_factor: float = lerpf(config.social_reputation_factor_min, config.social_reputation_factor_max, clampf(reputation / 100.0, 0, 1))
	return _bounded(base * maxf(0, novelty) * maxf(0, quality) * reputation_factor, config.follower_gain_cap)

func calculate_collab_gain(creator: StreamerDefinition, followers: int, performance: float = 1.0) -> int:
	var reach: float = sqrt(maxf(1, creator.reference_avg_viewers)) * config.collab_follower_scale
	return _bounded(maxf(config.collab_minimum_gain, reach + followers * config.collab_follower_percentage) * clampf(performance, 0, 2), config.collab_follower_cap)

func _bounded(raw: float, cap: float) -> int:
	return maxi(0, int(round(cap * raw / (cap + raw))))

func award(state: PlayerState, gain: int) -> void:
	state.followers += maxi(0, gain)
	state.lifetime_followers_gained += maxi(0, gain)

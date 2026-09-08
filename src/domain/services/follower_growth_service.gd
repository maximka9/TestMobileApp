class_name FollowerGrowthService
extends RefCounted
enum TikTokOutcome { FLOP, NORMAL, GOOD, VIRAL, MEGA_VIRAL }
var config: GameConfig

func _init(settings: GameConfig) -> void:
	config = settings

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

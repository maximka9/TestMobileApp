class_name GameConfig
extends Resource
## All economy and timing coefficients; dev/prod resources select diagnostics.

@export var debug_metrics: bool = false
@export var tick_seconds: float = 1.0
@export var income_seconds: int = 5
@export var income_rate: float = 0.02
@export var xp_base: int = 100
@export var viewer_base: float = 10.0
@export var viewer_per_level: float = 5.0
@export var viewer_per_power: float = 2.0
@export var viewer_smoothing: float = 0.1
@export var hype_divisor: float = 50.0
@export var hype_decay: float = 0.5
@export var hype_max: float = 100.0
@export var base_energy: float = 100.0
@export var energy_recovery: float = 2.0
@export var upgrade_growth: float = 1.5
@export var event_min_seconds: int = 20
@export var event_max_seconds: int = 45
@export var save_debounce: float = 0.25
@export var retry_delays: PackedFloat32Array = PackedFloat32Array([0.25, 0.5, 1.0])
@export var autosave_seconds: float = 15.0
@export var target_fps: int = 60
@export var warning_fps: int = 40
@export var warning_duration: float = 5.0

@export_group("Career phase 1")
@export_range(20, 50) var starting_followers: int = 30
@export_range(0, 100) var starting_fatigue: float = 0.0
@export var fatigue_rate: float = 0.04
@export var fatigue_per_minute: Dictionary = {"just_chatting": 0.20, "dota_2": 0.24, "cooking": 0.30, "irl": 0.32}
@export var fatigue_viewer_steps: PackedFloat32Array = [60, 80, 90]
@export var fatigue_viewer_efficiency: PackedFloat32Array = [1.0, 0.95, 0.85, 0.7]
@export var exhaustion_threshold: float = 95.0
@export var offline_recovery_cap: int = 28800
@export var fatigue_multipliers: Dictionary = {"just_chatting": 0.8, "dota_2": 1.0, "cooking": 1.25, "irl": 1.4}
@export var fatigue_steps: PackedFloat32Array = PackedFloat32Array([40, 60, 80, 90])
@export var fatigue_efficiency: PackedFloat32Array = PackedFloat32Array([1.0, 0.9, 0.75, 0.6, 0.4])
@export var audience_exponent: float = 0.6
@export var audience_scale: float = 2.2
@export var audience_soft_cap: float = 100000.0
@export var audience_multiplier_cap: float = 8.0
@export var follower_conversion: float = 0.0005
@export var follower_gain_cap: int = 10000
@export var history_limit: int = 50
@export var average_window: int = 10
@export var novelty_window: int = 5
@export var novelty_penalties: PackedFloat32Array = PackedFloat32Array([1.0, 0.85, 0.7, 0.55, 0.45])

@export_group("Career phase 2")
@export var short_viral_cap: float = 25.0
@export var short_mega_share: float = 0.1
@export var short_follower_factor_exponent: float = 0.12
@export var short_momentum_factor: float = 0.01
@export var short_history_limit: int = 10
@export var short_nonviral_weights: PackedFloat32Array = PackedFloat32Array([70.0, 22.0, 6.0])
@export var short_outcome_multipliers: PackedFloat32Array = PackedFloat32Array([0.0, 1.0, 3.0, 10.0, 30.0])
@export var short_momentum_gains: PackedFloat32Array = PackedFloat32Array([0.0, 0.5, 2.0, 8.0, 20.0])
@export var momentum_stream_decay: float = 0.8
@export var momentum_audience_factor: float = 0.01

@export_group("Career phase 3")
@export_range(0, 100) var starting_reputation: float = 50.0
@export var social_profile_limit: int = 500
@export var social_spam_window: int = 300
@export var social_spam_allowance: int = 2
@export var social_spam_penalty: float = 2.0
@export var social_rejection_penalty: float = 1.0
@export var social_reputation_factor_min: float = 0.75
@export var social_reputation_factor_max: float = 1.25

@export_group("Career phase 4A")
@export var collab_candidate_quotas: PackedInt32Array = PackedInt32Array([2, 4, 3, 1])
@export var collab_near_min: float = 0.5
@export var collab_near_max: float = 2.0
@export var collab_gap_exponent: float = 0.7
@export var collab_interest_bonus: float = 0.4
@export var collab_relationship_weight: float = 0.005
@export var collab_repeat_penalty: float = 0.2
@export var collab_momentum_weight: float = 0.01
@export var collab_chance_min: float = 0.0001
@export var collab_chance_max: float = 0.9
@export var collab_chance_bands: PackedFloat32Array = PackedFloat32Array([0.05, 0.25, 0.6])
@export var collab_cooldown_seconds: int = 600
@export var collab_tier_cooldown_seconds: int = 300
@export var collab_follower_scale: float = 0.5
@export var collab_follower_cap: int = 2000
@export var collab_reputation_gain: float = 2.0
@export var collab_relationship_gain: float = 5.0
@export var collab_momentum_gain: float = 10.0
@export var collab_response_delay: float = 0.8

@export_group("Audience and collaborations 0.6")
@export var audience_anchors: PackedVector2Array = [Vector2(100, 4), Vector2(1000, 25), Vector2(10000, 120), Vector2(100000, 700), Vector2(500000, 3500), Vector2(1000000, 6500), Vector2(2000000, 12000), Vector2(5000000, 28000)]
@export var audience_tail_exponent: float = 0.65
@export var hype_anchors: PackedVector2Array = [Vector2(0, 0.60), Vector2(25, 0.75), Vector2(50, 1), Vector2(70, 1.20), Vector2(85, 1.45), Vector2(95, 1.70), Vector2(100, 2.0)]
@export var stream_variance_min: float = 0.85
@export var stream_variance_max: float = 1.15
@export var short_minimum_gains: PackedFloat32Array = [0, 5, 15, 50, 150]
@export var short_follower_percentages: PackedFloat32Array = [0, 0.01, 0.03, 0.1, 0.3]
@export var short_views_per_follower: PackedInt32Array = [0, 70, 120, 250, 400]
@export var collab_minimum_gain: float = 12
@export var collab_follower_percentage: float = 0.02
@export var collab_fatigue_cost: float = 8
@export var collab_viewer_boost: float = 0.3
@export var collab_boost_streams: int = 3
@export var collab_refresh_seconds: int = 120
@export var collab_recent_limit: int = 30
@export var inbound_check_seconds: int = 120
@export var inbound_expiry_seconds: int = 1200
@export var inbound_base_chance: float = 0.04
@export var inbound_chance_cap: float = 0.6
@export var inbound_min_stream_seconds: int = 30

@export_group("Stream simulation 0.7")
@export var organic_exposure_conversion: float = 0.012
@export var organic_duration_cap_minutes: int = 120
@export var organic_gain_cap: float = 250.0
@export var organic_tier_multipliers: PackedFloat32Array = [1.0, 1.0, 0.9, 0.8]
@export var chat_viewer_thresholds: PackedInt32Array = [3, 10, 30, 100, 500, 2000]
@export var chat_interval_min: PackedFloat32Array = [7, 4, 2.5, 1.5, 0.8, 0.5, 0.25]
@export var chat_interval_max: PackedFloat32Array = [12, 7, 4, 2.5, 1.5, 1, 0.7]
@export var chat_hype_thresholds: PackedFloat32Array = [30, 70, 95]
@export var chat_hype_multipliers: PackedFloat32Array = [0.8, 1.0, 1.25, 1.5]
@export var chat_min_interval: float = 0.25

@export_group("Progression 0.8")
@export var click_xp_power_factor: float = 0.08
@export var click_xp_multiplier_cap: float = 1.75
@export var fatigue_recovery_per_real_minute: float = 10.0
@export var cosplay_hype_gain: float = 12.0
@export var cosplay_special_event_weight: int = 2

@export var follower_hype_anchors: PackedVector2Array = [Vector2(0, 0), Vector2(20, 0), Vector2(30, 0.4), Vector2(50, 1), Vector2(70, 1.3), Vector2(85, 1.7), Vector2(95, 2.1), Vector2(100, 2.4)]
@export var source_hype_viral_factor: float = 0.005

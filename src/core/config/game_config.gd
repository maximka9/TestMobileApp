class_name GameConfig
extends Resource
## All economy and timing coefficients; dev/prod resources select diagnostics.

@export var debug_metrics: bool = false
@export var tick_seconds: float = 1.0
@export var income_seconds: int = 5
@export var income_rate: float = 0.02
@export var xp_base: int = 50
@export var xp_exponent: float = 1.5
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
@export var fatigue_recovery: float = 0.1
@export var exhaustion_threshold: float = 95.0
@export var offline_recovery_cap: int = 28800
@export var fatigue_multipliers: Dictionary = {"just_chatting": 0.8, "dota_2": 1.0, "irl": 1.4}
@export var fatigue_steps: PackedFloat32Array = PackedFloat32Array([40, 60, 75, 90])
@export var fatigue_efficiency: PackedFloat32Array = PackedFloat32Array([1.0, 0.95, 0.85, 0.7, 0.5])
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

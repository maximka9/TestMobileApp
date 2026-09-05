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

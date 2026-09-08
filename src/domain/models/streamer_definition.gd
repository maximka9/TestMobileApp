class_name StreamerDefinition
extends Resource
## Bundled offline profile. Reference audience is a game balance value, not analytics.
@export var id: String = ""
@export var display_name: String = ""
@export var reach_tier: int = 0
@export var reference_avg_viewers: int = 10
@export var interests: PackedStringArray = []
@export var collab_formats: PackedStringArray = []
@export var base_acceptance: float = 0.5
@export var region: String = "fictional"
@export var language: String = "ru"
@export var source: String = ""
@export var source_checked_at: String = ""
@export var is_placeholder: bool = false

class_name ShortFormDefinition
extends Resource
@export var icon: Texture2D
## Data-only definition for a short-form post. The label may say TikTok, the system is platform-neutral.
@export var id: String = ""
@export var display_name: String = ""
@export_range(0.0, 100.0) var base_viral_chance: float = 1.0
@export_range(0.0, 100.0) var fatigue_cost: float = 5.0
@export var money_cost: int = 0
@export_range(0.0, 1000.0) var follower_multiplier: float = 1.0
@export var tags: PackedStringArray = []
@export var source_tags: PackedStringArray = ["just_chatting"]
@export var source_hint: String = "Сначала проведите разговорный эфир."

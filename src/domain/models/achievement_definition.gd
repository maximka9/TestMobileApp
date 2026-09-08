class_name AchievementDefinition
extends Resource
enum AchievementTier { NORMAL, GOAL, CHALLENGE, LEGENDARY }

@export var id: String = ""
@export var display_name: String = ""
@export var category: String = ""
@export var description: String = ""
@export var metric: String = ""
@export var threshold: int = 1
@export var secret: bool = false
@export var requirements: Dictionary = {}
@export var parent_ids: PackedStringArray = []
@export var tier: AchievementTier = AchievementTier.NORMAL
@export var icon: Texture2D
@export var graph_position: Vector2 = Vector2.ZERO

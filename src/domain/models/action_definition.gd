class_name ActionDefinition
extends Resource
## Shared data for moves and event choices; an event may delegate to a move.
@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var money_cost: int = 0
@export var energy_cost: float = 0.0
@export var hype_gain: float = 0.0
@export var money_gain: int = 0
@export var viewer_multiplier: float = 1.0
@export var duration: int = 20
@export var cooldown: int = 0
@export var move_id: String = ""
## Fictional event effects, not statements about public figures.
@export var social_author_id: String = ""
@export var reputation_delta: float = 0.0
@export var relationship_delta: float = 0.0

class_name UpgradeDefinition
extends Resource
## Generic additive upgrade effects, keyed by domain stat name.
@export var required_level: int = 1
@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var base_cost: int = 10
@export var stat: String = "click_power"
@export var amount: float = 1.0
@export var max_level: int = 30

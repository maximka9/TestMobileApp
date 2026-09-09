class_name CharacterAppearance
extends Resource

@export var tier_steps: PackedInt32Array = [0, 1, 2]
@export var variants: Array[Texture2D] = []
@export var frame_counts: PackedInt32Array = [1, 4, 1]
## Optional existing costume textures, keyed by CosplayDefinition.sprite_variant.
@export var cosplay_variants: Dictionary[String, Texture2D] = {}

func index_for(tier: int) -> int:
	var selected: int = 0
	for i: int in range(tier_steps.size()):
		if tier >= tier_steps[i]:
			selected = i
	return selected

func apply(sprite: Sprite2D, tier: int) -> Vector2:
	var index: int = index_for(tier)
	sprite.frame = 0
	sprite.hframes = frame_counts[index]
	sprite.texture = variants[index]
	var ratio: float = 128.0 / sprite.texture.get_height()
	sprite.scale = Vector2.ONE * ratio
	return sprite.scale

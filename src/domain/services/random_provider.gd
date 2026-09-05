class_name RandomProvider
extends RefCounted
## Injectable random source. Explicit seeds reproduce event choices and intervals.
var generator: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(seed_value: int = -1) -> void:
	if seed_value < 0:
		generator.randomize()
	else:
		generator.seed = seed_value

func between(minimum: int, maximum: int) -> int:
	return generator.randi_range(minimum, maxi(minimum, maximum))

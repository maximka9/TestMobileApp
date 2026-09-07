class_name ScriptedRandomProvider
extends RandomProvider
## Replays supplied values, allowing outcome boundaries to be tested without probability.
var values: Array[int] = []
var index: int = 0

func _init(sequence: Array[int]) -> void:
	values = sequence

func between(minimum: int, maximum: int) -> int:
	if values.is_empty():
		return minimum
	var value: int = values[mini(index, values.size() - 1)]
	index += 1
	return clampi(value, minimum, maximum)

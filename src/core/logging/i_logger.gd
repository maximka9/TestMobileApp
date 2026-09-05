class_name ILogger
extends RefCounted
## Logging adapter contract. Implementations may forward structured context.
func write(_severity: String, _category: String, _event: String, _context: Dictionary = {}) -> void:
	pass

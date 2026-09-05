class_name GameLogger
extends ILogger
## Local logging only; debug messages are disabled in production.
var debug_enabled: bool

func _init(enable_debug: bool = false) -> void:
	debug_enabled = enable_debug

func write(severity: String, category: String, event: String, context: Dictionary = {}) -> void:
	if severity == "DEBUG" and not debug_enabled:
		return
	print("[SASA][%s][%s] %s %s" % [category, severity, event, JSON.stringify(context)])

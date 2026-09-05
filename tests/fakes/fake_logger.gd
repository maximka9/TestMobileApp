class_name FakeLogger
extends ILogger
## Captures structured messages for assertions without console noise.
var entries: Array[Dictionary] = []

func write(severity: String, category: String, event: String, context: Dictionary = {}) -> void:
	entries.append({"severity": severity, "category": category, "event": event, "context": context.duplicate(true)})

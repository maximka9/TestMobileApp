class_name OperationResult
extends RefCounted
## Explicit outcome shared by application commands and infrastructure adapters.

var success: bool
var error_code: StringName
var message: String
var context: Dictionary

func _init(ok: bool = true, code: StringName = &"SUCCESS", text: String = "", data: Dictionary = {}) -> void:
	success = ok
	error_code = code
	message = text
	context = data

static func fail(code: StringName, text: String = "") -> OperationResult:
	return OperationResult.new(false, code, text)

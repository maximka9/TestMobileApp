class_name FakeSaveRepository
extends SaveRepository
## Fault-injecting in-memory persistence adapter.
var document: Dictionary = {}
var calls: int = 0
var failures_left: int = 0
var quarantined: bool = false
var read_error: StringName = &""

func read_save() -> OperationResult:
	if read_error != &"":
		return OperationResult.fail(read_error)
	if document.is_empty():
		return OperationResult.fail(&"NOT_FOUND")
	return OperationResult.new(true, &"SUCCESS", "", {"document": document.duplicate(true)})

func write_save(data: Dictionary) -> OperationResult:
	calls += 1
	if failures_left > 0:
		failures_left -= 1
		return OperationResult.fail(&"WRITE_FAILED")
	document = data.duplicate(true)
	return OperationResult.new()

func quarantine() -> OperationResult:
	quarantined = true
	return OperationResult.new()

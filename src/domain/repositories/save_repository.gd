class_name SaveRepository
extends RefCounted
## Persistence port. Successful reads carry a document in context.document.
func read_save() -> OperationResult:
	return OperationResult.fail(&"NOT_IMPLEMENTED")

func write_save(_document: Dictionary) -> OperationResult:
	return OperationResult.fail(&"NOT_IMPLEMENTED")

func quarantine() -> OperationResult:
	return OperationResult.new()

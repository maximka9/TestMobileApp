class_name FileSaveRepository
extends SaveRepository
## Temp-file replacement retains the previous valid save if writing fails.
var path: String

func _init(save_path: String = "user://save.json") -> void:
	path = save_path

func read_save() -> OperationResult:
	if not FileAccess.file_exists(path):
		return OperationResult.fail(&"NOT_FOUND")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return OperationResult.fail(&"READ_FAILED", error_string(FileAccess.get_open_error()))
	if file.get_length() > 1048576:
		return OperationResult.fail(&"CORRUPT_SAVE", "Save exceeds size limit")
	var parser: JSON = JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary:
		return OperationResult.fail(&"CORRUPT_SAVE", "Invalid JSON document")
	return OperationResult.new(true, &"SUCCESS", "", {"document": parser.data})

func write_save(document: Dictionary) -> OperationResult:
	if document.is_empty():
		return OperationResult.fail(&"INVALID_ARGUMENT")
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return OperationResult.fail(&"WRITE_FAILED", error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(document, "\t"))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return OperationResult.fail(&"WRITE_FAILED", error_string(error))
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if error != OK:
		return OperationResult.fail(&"WRITE_FAILED", error_string(error))
	return OperationResult.new()

func quarantine() -> OperationResult:
	if not FileAccess.file_exists(path):
		return OperationResult.new()
	var backup: String = path + ".damaged-" + str(Time.get_unix_time_from_system()).replace(".", "-") + ".bak"
	var error: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup))
	return OperationResult.new(error == OK, &"SUCCESS" if error == OK else &"BACKUP_FAILED", error_string(error))

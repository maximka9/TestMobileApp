class_name SaveService
extends RefCounted
## Versioned codec with strict field validation and safe defaults on corruption.
const VERSION: int = 1
const MAX_COUNTER: int = 1000000000000
var repository: SaveRepository
var logger: ILogger
var catalog: ContentCatalog
var upgrades: UpgradeService
var last_duration_ms: float = 0.0
var recovered: bool = false
var notice: String = ""

func _init(save_repository: SaveRepository, game_logger: ILogger, content: ContentCatalog, upgrade_service: UpgradeService) -> void:
	repository = save_repository
	logger = game_logger
	catalog = content
	upgrades = upgrade_service

func serialize(state: PlayerState) -> Dictionary:
	if state == null:
		return {}
	return {"version": VERSION, "timestamp": int(Time.get_unix_time_from_system()), "player": {"level": state.level, "xp": state.xp, "money": state.money, "energy": state.energy, "current_stream_type_id": state.current_stream_type_id, "total_clicks": state.total_clicks, "total_streams": state.total_streams, "upgrades": state.upgrades.duplicate(true), "settings": state.settings.duplicate(true)}}

func deserialize(document: Dictionary) -> OperationResult:
	if not _integer(document.get("version"), VERSION, VERSION) or not _integer(document.get("timestamp"), 0, MAX_COUNTER) or not document.get("player") is Dictionary:
		return OperationResult.fail(&"CORRUPT_SAVE")
	var data: Dictionary = document["player"]
	for key: String in ["level", "xp", "money", "total_clicks", "total_streams"]:
		if not _integer(data.get(key), 1 if key == "level" else 0, 100000 if key == "level" else MAX_COUNTER):
			return OperationResult.fail(&"CORRUPT_SAVE")
	if not _number(data.get("energy"), 0.0, 100.0) or not data.get("current_stream_type_id") is String:
		return OperationResult.fail(&"CORRUPT_SAVE")
	if not data.get("upgrades") is Dictionary or not data.get("settings") is Dictionary:
		return OperationResult.fail(&"CORRUPT_SAVE")
	var state: PlayerState = PlayerState.new()
	for key: String in ["level", "xp", "money", "total_clicks", "total_streams"]:
		state.set(key, int(data[key]))
	state.energy = float(data["energy"])
	state.current_stream_type_id = data["current_stream_type_id"] if catalog.streams.has(data["current_stream_type_id"]) else "just_chatting"
	for id: Variant in data["upgrades"]:
		if not id is String:
			return OperationResult.fail(&"CORRUPT_SAVE")
		if catalog.upgrades.has(id):
			var definition: UpgradeDefinition = catalog.upgrades[id] as UpgradeDefinition
			if definition == null or not _integer(data["upgrades"][id], 0, definition.max_level):
				return OperationResult.fail(&"CORRUPT_SAVE")
			state.upgrades[id] = int(data["upgrades"][id])
		elif not _integer(data["upgrades"][id], 0, 30):
			# Preserve the v1 policy for unknown/retired IDs: validate, then ignore.
			return OperationResult.fail(&"CORRUPT_SAVE")
	if data["settings"].has("reduced_motion"):
		if not data["settings"]["reduced_motion"] is bool:
			return OperationResult.fail(&"CORRUPT_SAVE")
		state.settings["reduced_motion"] = data["settings"]["reduced_motion"]
	state.click_power = int(upgrades.stats(state)["click_power"])
	state.normalize()
	return OperationResult.new(true, &"SUCCESS", "", {"state": state})

func load_player() -> PlayerState:
	var result: OperationResult = repository.read_save()
	if result.success:
		result = deserialize(result.context["document"])
	if result.success:
		return result.context["state"] as PlayerState
	if result.error_code != &"NOT_FOUND":
		recovered = true
		notice = "Сохранение не удалось загрузить. Создан новый прогресс; повреждённый файл сохранён, если это возможно."
		logger.write("ERROR", "SAVE", "load_failed", {"code": result.error_code})
		if result.error_code == &"CORRUPT_SAVE":
			var backup: OperationResult = repository.quarantine()
			if not backup.success:
				logger.write("ERROR", "SAVE", "backup_failed", {"code": backup.error_code})
	return PlayerState.new()

func save(state: PlayerState) -> OperationResult:
	if state == null:
		return OperationResult.fail(&"INVALID_ARGUMENT")
	var started: int = Time.get_ticks_usec()
	var result: OperationResult = repository.write_save(serialize(state))
	last_duration_ms = (Time.get_ticks_usec() - started) / 1000.0
	logger.write("DEBUG" if result.success else "ERROR", "SAVE", "save_completed" if result.success else "save_failed", {"duration_ms": last_duration_ms, "code": result.error_code})
	return result

func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and float(value) == floor(float(value))

func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

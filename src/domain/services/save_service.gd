class_name SaveService
extends RefCounted
## Versioned codec with strict field validation and safe defaults on corruption.
const VERSION: int = 9
const MAX_COUNTER: int = 1000000000000
var repository: SaveRepository
var logger: ILogger
var catalog: ContentCatalog
var upgrades: UpgradeService
var last_duration_ms: float = 0.0
var recovered: bool = false
var notice: String = ""
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())

func _init(save_repository: SaveRepository, game_logger: ILogger, content: ContentCatalog, upgrade_service: UpgradeService) -> void:
	repository = save_repository
	logger = game_logger
	catalog = content
	upgrades = upgrade_service

func serialize(state: PlayerState) -> Dictionary:
	var document: Dictionary = _serialize_base(state)
	if document.is_empty():
		return document
	document["player"].merge({"fatigue_updated_at": document["timestamp"], "fatigue_recovery_seconds": state.fatigue_recovery_seconds, "content_sources": state.content_sources.duplicate(true), "source_sequence": state.source_sequence})
	return document

func _serialize_base(state: PlayerState) -> Dictionary:
	if state == null:
		return {}
	return {"version": VERSION, "timestamp": int(clock.call()), "player": {"selected_cosplay_id": state.selected_cosplay_id, "cosplay_streams": state.cosplay_streams, "viral_posts": state.viral_posts, "high_tier_collabs": state.high_tier_collabs, "career_tier": state.career_tier, "unlocked_achievements": state.unlocked_achievements.duplicate(), "owned_room_items": state.owned_room_items.duplicate(), "owned_homes": state.owned_homes.duplicate(), "completed_collabs": state.completed_collabs, "collab_cooldowns": state.collab_cooldowns.duplicate(), "reputation": state.reputation, "relationships": state.relationships.duplicate(true), "social_requests": state.social_requests.duplicate(true), "level": state.level, "xp": state.xp, "money": state.money, "fatigue": state.fatigue, "followers": state.followers, "average_online": state.average_online, "lifetime_peak_viewers": state.lifetime_peak_viewers, "lifetime_followers_gained": state.lifetime_followers_gained, "stream_history": state.stream_history.duplicate(true), "last_stream_types": state.last_stream_types.duplicate(), "growth_momentum": state.growth_momentum, "short_form_history": state.short_form_history.duplicate(), "current_location_id": state.current_location_id, "current_home_id": state.current_home_id, "was_streaming": state.is_streaming, "current_stream_type_id": state.current_stream_type_id, "total_clicks": state.total_clicks, "total_streams": state.total_streams, "upgrades": state.upgrades.duplicate(true), "settings": state.settings.duplicate(true)}}

func deserialize(document: Dictionary) -> OperationResult:
	if not _integer(document.get("version"), 1, VERSION) or not _integer(document.get("timestamp"), 0, MAX_COUNTER) or not document.get("player") is Dictionary:
		return OperationResult.fail(&"CORRUPT_SAVE")
	var data: Dictionary = document["player"]
	for key: String in ["level", "xp", "money", "total_clicks", "total_streams"]:
		if not _integer(data.get(key), 1 if key == "level" else 0, 100000 if key == "level" else MAX_COUNTER):
			return OperationResult.fail(&"CORRUPT_SAVE")
	var version: int = int(document["version"])
	var legacy: bool = version == 1
	if not _number(data.get("energy" if legacy else "fatigue"), 0.0, 100.0) or not data.get("current_stream_type_id") is String:
		return OperationResult.fail(&"CORRUPT_SAVE")
	if not data.get("upgrades") is Dictionary or not data.get("settings") is Dictionary:
		return OperationResult.fail(&"CORRUPT_SAVE")
	var state: PlayerState = CareerService.new(upgrades.config).new_player()
	for key: String in ["level", "xp", "money", "total_clicks", "total_streams"]:
		state.set(key, int(data[key]))
	state.fatigue = 100.0 - float(data["energy"]) if legacy else float(data["fatigue"])
	if not legacy and not _read_career(data, state):
		return OperationResult.fail(&"CORRUPT_SAVE")
	if version >= 3 and not _read_short_form(data, state):
		return OperationResult.fail(&"CORRUPT_SAVE")
	if version >= 4 and not _read_social(data, state):
		return OperationResult.fail(&"CORRUPT_SAVE")
	if version >= 5 and not _read_collabs(data, state):
		return OperationResult.fail(&"CORRUPT_SAVE")
	if version >= 6 and not _read_v04(data, state):
		return OperationResult.fail(&"CORRUPT_SAVE")
	state.fatigue_updated_at = int(document["timestamp"])
	if version >= 9 and not _read_v05(data, state):
		return OperationResult.fail(&"CORRUPT_SAVE")
	var location: LocationDefinition = catalog.locations.get(state.current_location_id)
	if location == null or location.scene == null:
		state.current_location_id = "streamer_room"
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
	return OperationResult.new(true, &"SUCCESS", "", {"state": state, "saved_at": int(document["timestamp"]), "was_streaming": bool(data.get("was_streaming", false))})

func _read_collabs(data: Dictionary, state: PlayerState) -> bool:
	if not _integer(data.get("completed_collabs"), 0, MAX_COUNTER) or not data.get("collab_cooldowns") is Dictionary or data["collab_cooldowns"].size() > upgrades.config.social_profile_limit:
		return false
	for id: Variant in data["collab_cooldowns"]:
		if not id is String or id.strip_edges().is_empty() or id.length() > 64 or not _integer(data["collab_cooldowns"][id], 0, MAX_COUNTER):
			return false
		state.collab_cooldowns[id] = int(data["collab_cooldowns"][id])
	state.completed_collabs = int(data["completed_collabs"])
	return true

func _read_v05(data: Dictionary, state: PlayerState) -> bool:
	if not _integer(data.get("fatigue_updated_at"), 0, MAX_COUNTER) or not _integer(data.get("source_sequence"), 0, MAX_COUNTER) or not _number(data.get("fatigue_recovery_seconds"), 0, 59.999999):
		return false
	if not data.get("content_sources") is Array or data["content_sources"].size() > 4096:
		return false
	var ids: Dictionary = {}
	for source: Variant in data["content_sources"]:
		if not source is Dictionary or not _integer(source.get("id"), 1, int(data["source_sequence"])) or not _integer(source.get("created_at"), 0, MAX_COUNTER):
			return false
		if ids.has(source["id"]) or not source.get("consumed") is bool or not source.get("source_stream_id") is String or not source.get("tags") is Array:
			return false
		if source["tags"].is_empty() or source["tags"].size() > 8 or source["source_stream_id"].length() > 64:
			return false
		for tag: Variant in source["tags"]:
			if not tag is String or tag.is_empty() or tag.length() > 64:
				return false
		ids[source["id"]] = true
		state.content_sources.append(source.duplicate(true))
	state.source_sequence = int(data["source_sequence"])
	state.fatigue_updated_at = int(data["fatigue_updated_at"])
	state.fatigue_recovery_seconds = float(data["fatigue_recovery_seconds"])
	return true

func _read_v04(data: Dictionary, state: PlayerState) -> bool:
	for key: String in ["cosplay_streams", "viral_posts", "high_tier_collabs", "career_tier"]:
		if not _integer(data.get(key), 0, MAX_COUNTER):
			return false
		state.set(key, int(data[key]))
	if not data.get("selected_cosplay_id") is String:
		return false
	state.selected_cosplay_id = str(data["selected_cosplay_id"]) if catalog.cosplays.has(data["selected_cosplay_id"]) else ""
	for key: String in ["unlocked_achievements", "owned_room_items", "owned_homes"]:
		if not data.get(key) is Array or data[key].size() > 10000:
			return false
		state.get(key).clear()
		for id: Variant in data[key]:
			if not id is String or id.strip_edges().is_empty() or id.length() > 64:
				return false
			if not id in state.get(key):
				state.get(key).append(id)
	if not "starter_home" in state.owned_homes:
		state.owned_homes.append("starter_home")
	return true

func _read_social(data: Dictionary, state: PlayerState) -> bool:
	if not _number(data.get("reputation"), 0, 100):
		return false
	for key: String in ["relationships", "social_requests"]:
		if not data.get(key) is Dictionary or data[key].size() > upgrades.config.social_profile_limit:
			return false
		for id: Variant in data[key]:
			if not id is String or id.strip_edges().is_empty() or id.length() > 64:
				return false
	for id: String in data["relationships"]:
		if not _number(data["relationships"][id], -100, 100):
			return false
		state.relationships[id] = float(data["relationships"][id])
	for id: String in data["social_requests"]:
		var window: Variant = data["social_requests"][id]
		if not window is Dictionary or not _integer(window.get("start"), 0, MAX_COUNTER) or not _integer(window.get("last"), 0, MAX_COUNTER) or not _integer(window.get("count"), 1, 1000000):
			return false
		if int(window["last"]) < int(window["start"]):
			return false
		state.social_requests[id] = {"start": int(window["start"]), "last": int(window["last"]), "count": int(window["count"])}
	state.reputation = float(data["reputation"])
	return true

func _read_career(data: Dictionary, state: PlayerState) -> bool:
	for key: String in ["followers", "lifetime_peak_viewers", "lifetime_followers_gained"]:
		if not _integer(data.get(key), 0, MAX_COUNTER):
			return false
		state.set(key, int(data[key]))
	if not _number(data.get("average_online"), 0, MAX_COUNTER) or not data.get("was_streaming") is bool:
		return false
	state.average_online = float(data["average_online"])
	for key: String in ["current_location_id", "current_home_id"]:
		if not data.get(key) is String or data[key].is_empty() or data[key].length() > 64:
			return false
		state.set(key, data[key])
	if not data.get("last_stream_types") is Array or data["last_stream_types"].size() > upgrades.config.novelty_window:
		return false
	for value: Variant in data["last_stream_types"]:
		if not value is String or value.length() > 64:
			return false
		state.last_stream_types.append(value)
	if not data.get("stream_history") is Array or data["stream_history"].size() > upgrades.config.history_limit:
		return false
	for entry: Variant in data["stream_history"]:
		if not entry is Dictionary:
			return false
		for key: String in ["stream_type", "location"]:
			if not entry.get(key) is String or entry[key].length() > 64:
				return false
		for key: String in ["duration", "peak_viewers", "followers_gained", "money_gained", "timestamp"]:
			if not _integer(entry.get(key), 0, MAX_COUNTER):
				return false
		if not _number(entry.get("average_viewers"), 0, float(entry["peak_viewers"])) or not _number(entry.get("novelty"), 0, upgrades.config.audience_multiplier_cap):
			return false
		state.stream_history.append(entry.duplicate(true))
	return true

func _read_short_form(data: Dictionary, state: PlayerState) -> bool:
	if not _number(data.get("growth_momentum"), 0.0, 100.0) or not data.get("short_form_history") is Array or data["short_form_history"].size() > upgrades.config.short_history_limit:
		return false
	state.growth_momentum = float(data["growth_momentum"])
	for id: Variant in data["short_form_history"]:
		if not id is String or not catalog.short_forms.has(id):
			return false
		state.short_form_history.append(id)
	return true

func load_player() -> PlayerState:
	var result: OperationResult = repository.read_save()
	if result.success:
		result = deserialize(result.context["document"])
	if result.success:
		var player: PlayerState = result.context["state"] as PlayerState
		if not bool(result.context["was_streaming"]):
			CareerService.new(upgrades.config).recover_offline(player, player.fatigue_updated_at, int(clock.call()))
		return player
	if result.error_code != &"NOT_FOUND":
		recovered = true
		notice = "Сохранение не удалось загрузить. Создан новый прогресс; повреждённый файл сохранён, если это возможно."
		logger.write("ERROR", "SAVE", "load_failed", {"code": result.error_code})
		if result.error_code == &"CORRUPT_SAVE":
			var backup: OperationResult = repository.quarantine()
			if not backup.success:
				logger.write("ERROR", "SAVE", "backup_failed", {"code": backup.error_code})
	return CareerService.new(upgrades.config).new_player()

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

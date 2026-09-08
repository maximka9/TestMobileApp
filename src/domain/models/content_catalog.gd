class_name ContentCatalog
extends RefCounted
## Loads static definitions once, including in exported PCKs.
var streams: Dictionary = {}
var upgrades: Dictionary = {}
var moves: Dictionary = {}
var events: Dictionary = {}
var short_forms: Dictionary = {}
var streamers: Dictionary = {}
var cosplays: Dictionary = {}
var locations: Dictionary = {}
var achievements: Dictionary = {}
var room_items: Dictionary = {}
var homes: Dictionary = {}
const STREAMER_CATALOG_PATH: String = "res://resources/streamers/streamers.json"
const MAX_STREAMERS: int = 500
var streamer_path: String

func _init(snapshot_path: String = STREAMER_CATALOG_PATH) -> void:
	streamer_path = snapshot_path
	_load_folder("res://resources/stream_types", streams)
	_load_folder("res://resources/upgrades", upgrades)
	_load_folder("res://resources/moves", moves)
	_load_folder("res://resources/events", events)
	_load_folder("res://resources/short_forms", short_forms)
	_load_folder("res://resources/cosplays", cosplays)
	_load_folder("res://resources/locations", locations)
	_load_folder("res://resources/achievements", achievements)
	_load_folder("res://resources/room_items", room_items)
	_load_folder("res://resources/homes", homes)
	_load_streamer_catalog()
	var graph_error: String = validate_achievement_graph(achievements)
	if not graph_error.is_empty():
		push_error(graph_error)
		achievements.clear()

func _load_folder(path: String, target: Dictionary) -> void:
	for file_name: String in ResourceLoader.list_directory(path):
		if file_name.ends_with(".tres"):
			var resource: Resource = load(path.path_join(file_name))
			if resource != null and not str(resource.get("id")).is_empty():
				target[resource.get("id")] = resource

func _load_streamer_catalog() -> void:
	streamers.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(streamer_path))
	if not parsed is Dictionary or not parsed.get("profiles") is Array:
		push_error("SASAclicker streamer catalog is invalid")
		return
	var profiles: Array = parsed["profiles"]
	var identity_error: String = validate_streamer_identities(profiles)
	if not identity_error.is_empty():
		push_error(identity_error)
		return
	if profiles.size() > MAX_STREAMERS:
		push_error("SASAclicker streamer catalog exceeds profile limit")
		return
	for value: Variant in profiles:
		var profile: StreamerDefinition = _streamer_from(value)
		if profile == null or streamers.has(profile.id):
			push_error("SASAclicker streamer catalog contains an invalid or duplicate profile")
			streamers.clear()
			return
		streamers[profile.id] = profile

func _streamer_from(value: Variant) -> StreamerDefinition:
	if not value is Dictionary:
		return null
	if streamer_path == STREAMER_CATALOG_PATH:
		if not value.get("source") is String or not str(value["source"]).begins_with("https://") or not value.get("source_checked_at") is String or str(value["source_checked_at"]).length() != 10 or value.get("is_placeholder") != false:
			return null
		if str(value.get("id", "")).begins_with("fixture_") or str(value.get("id", "")).begins_with("catalog_") or value.get("region") == "fictional":
			return null
	for key: String in ["id", "display_name", "region", "language"]:
		if not value.get(key) is String or str(value[key]).strip_edges().is_empty() or str(value[key]).length() > 64:
			return null
	for key: String in ["reach_tier", "reference_avg_viewers"]:
		if not _whole(value.get(key), 0, 1000000000):
			return null
	if not _number(value.get("base_acceptance"), 0.0, 1.0) or not value.get("interests") is Array or not value.get("collab_formats") is Array:
		return null
	var profile: StreamerDefinition = StreamerDefinition.new()
	profile.id = value["id"]
	profile.platform = str(value.get("platform", "twitch"))
	profile.platform_user_id = str(value.get("platform_user_id", ""))
	profile.login = str(value.get("login", value["id"]))
	profile.source = str(value.get("source", "test fixture"))
	profile.source_checked_at = str(value.get("source_checked_at", ""))
	profile.is_placeholder = bool(value.get("is_placeholder", streamer_path != STREAMER_CATALOG_PATH))
	profile.display_name = value["display_name"]
	profile.reach_tier = int(value["reach_tier"])
	profile.reference_avg_viewers = int(value["reference_avg_viewers"])
	profile.base_acceptance = float(value["base_acceptance"])
	profile.region = value["region"]
	profile.language = value["language"]
	for key: String in ["interests", "collab_formats"]:
		var names: PackedStringArray = []
		for entry: Variant in value[key]:
			if not entry is String or entry.is_empty() or entry.length() > 32:
				return null
			names.append(entry)
		profile.set(key, names)
	return profile

func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func validate_streamer_identities(profiles: Array) -> String:
	var ids: Dictionary = {}
	var logins: Dictionary = {}
	var external_ids: Dictionary = {}
	for entry: Variant in profiles:
		if not entry is Dictionary:
			return "Invalid streamer record"
		var id: String = str(entry.get("id", ""))
		var login: String = str(entry.get("login", id)).to_lower()
		var platform: String = str(entry.get("platform", "twitch"))
		var external: Variant = entry.get("platform_user_id", "")
		if id.is_empty() or login.is_empty() or ids.has(id) or logins.has(platform + ":" + login):
			return "Duplicate or empty streamer identity"
		if not external is String:
			return "Invalid platform user ID"
		if not external.is_empty():
			if not external.is_valid_int() or int(external) <= 0 or external_ids.has(platform + ":" + external):
				return "Duplicate or invalid platform user ID"
			external_ids[platform + ":" + external] = true
		if entry.has("source_checked_at") and not valid_date(str(entry["source_checked_at"])):
			return "Invalid source observation date"
		ids[id] = true
		logins[platform + ":" + login] = true
	return ""

static func valid_date(value: String) -> bool:
	var parts: PackedStringArray = value.split("-")
	if value.length() != 10 or parts.size() != 3 or parts[0].length() != 4 or parts[1].length() != 2 or parts[2].length() != 2:
		return false
	for part: String in parts:
		if not part.is_valid_int():
			return false
	var year: int = int(parts[0])
	var month: int = int(parts[1])
	var day: int = int(parts[2])
	if year < 2000 or month < 1 or month > 12:
		return false
	var days: Array[int] = [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return day >= 1 and day <= days[month - 1]

static func validate_achievement_graph(graph: Dictionary) -> String:
	var marks: Dictionary = {}
	for id: String in graph:
		var error: String = _visit_achievement(id, graph, marks)
		if not error.is_empty():
			return error
	return ""

static func _visit_achievement(id: String, graph: Dictionary, marks: Dictionary) -> String:
	if not graph.has(id):
		return "Missing achievement parent: " + id
	if marks.get(id, 0) == 1:
		return "Achievement cycle: " + id
	if marks.get(id, 0) == 2:
		return ""
	marks[id] = 1
	for parent: String in (graph[id] as AchievementDefinition).parent_ids:
		var error: String = _visit_achievement(parent, graph, marks)
		if not error.is_empty():
			return error
	marks[id] = 2
	return ""

func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and float(value) == floor(float(value))

class_name ContentCatalog
extends RefCounted
## Loads static definitions once, including in exported PCKs.
var streams: Dictionary = {}
var upgrades: Dictionary = {}
var moves: Dictionary = {}
var events: Dictionary = {}
var short_forms: Dictionary = {}
var streamers: Dictionary = {}
const STREAMER_CATALOG_PATH: String = "res://resources/streamers/streamers.json"
const MAX_STREAMERS: int = 500

func _init() -> void:
	_load_folder("res://resources/stream_types", streams)
	_load_folder("res://resources/upgrades", upgrades)
	_load_folder("res://resources/moves", moves)
	_load_folder("res://resources/events", events)
	_load_folder("res://resources/short_forms", short_forms)
	_load_streamer_catalog()

func _load_folder(path: String, target: Dictionary) -> void:
	for file_name: String in ResourceLoader.list_directory(path):
		if file_name.ends_with(".tres"):
			var resource: Resource = load(path.path_join(file_name))
			if resource != null and not str(resource.get("id")).is_empty():
				target[resource.get("id")] = resource

func _load_streamer_catalog() -> void:
	streamers.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STREAMER_CATALOG_PATH))
	if not parsed is Dictionary or not parsed.get("profiles") is Array:
		push_error("SASAclicker streamer catalog is invalid")
		return
	var profiles: Array = parsed["profiles"]
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

func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and float(value) == floor(float(value))

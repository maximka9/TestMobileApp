class_name ContentCatalog
extends RefCounted
## Loads static definitions once, including in exported PCKs.
var streams: Dictionary = {}
var upgrades: Dictionary = {}
var moves: Dictionary = {}
var events: Dictionary = {}
var short_forms: Dictionary = {}
var streamers: Dictionary = {}

func _init() -> void:
	_load_folder("res://resources/stream_types", streams)
	_load_folder("res://resources/upgrades", upgrades)
	_load_folder("res://resources/moves", moves)
	_load_folder("res://resources/events", events)
	_load_folder("res://resources/short_forms", short_forms)
	_load_folder("res://resources/streamers", streamers)

func _load_folder(path: String, target: Dictionary) -> void:
	for file_name: String in ResourceLoader.list_directory(path):
		if file_name.ends_with(".tres"):
			var resource: Resource = load(path.path_join(file_name))
			if resource != null and not str(resource.get("id")).is_empty():
				target[resource.get("id")] = resource

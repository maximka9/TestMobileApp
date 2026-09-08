class_name LocalStreamerDirectoryRepository
extends StreamerDirectoryRepository
var catalog: ContentCatalog

func _init(content: ContentCatalog) -> void:
	catalog = content

func profiles() -> Dictionary:
	return catalog.streamers

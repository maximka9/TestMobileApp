class_name LocationService
extends RefCounted

var catalog: ContentCatalog

func _init(content: ContentCatalog) -> void:
	catalog = content

func resolve(stream: StreamType) -> LocationDefinition:
	if stream == null:
		return null
	var location: LocationDefinition = catalog.locations.get(stream.location_id)
	if location == null or location.scene == null or not stream.id in location.allowed_stream_types:
		return null
	return location

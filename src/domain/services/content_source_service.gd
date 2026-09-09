class_name ContentSourceService
extends RefCounted

static func create(state: PlayerState, tag: String, timestamp: int, average_hype: float = 0.0) -> void:
	state.source_sequence += 1
	state.content_sources.append({"id": state.source_sequence, "source_stream_id": str(state.total_streams + (1 if state.is_streaming else 0)), "tags": [tag], "created_at": timestamp, "consumed": false, "source_stream_average_hype": clampf(average_hype, 0, 100)})
	# Bounded archive: spent entries are removed before any usable material.
	if state.content_sources.size() > 4096:
		for i: int in range(state.content_sources.size()):
			if state.content_sources[i]["consumed"]:
				state.content_sources.remove_at(i)
				return
		state.content_sources.pop_front()

static func find(state: PlayerState, tags: PackedStringArray) -> int:
	for i: int in range(state.content_sources.size()):
		var source: Dictionary = state.content_sources[i]
		if not source["consumed"]:
			for tag: String in tags:
				if tag in source["tags"]:
					return i
	return -1

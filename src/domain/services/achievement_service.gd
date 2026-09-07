class_name AchievementService
extends RefCounted

var catalog: ContentCatalog

func _init(content: ContentCatalog) -> void:
	catalog = content

func evaluate(state: PlayerState) -> Array[String]:
	var unlocked: Array[String] = []
	for id: String in catalog.achievements:
		if id in state.unlocked_achievements:
			continue
		var definition: AchievementDefinition = catalog.achievements[id] as AchievementDefinition
		if definition != null and _value(state, definition.metric) >= definition.threshold:
			state.unlocked_achievements.append(id)
			unlocked.append(id)
	return unlocked

func _value(state: PlayerState, metric: String) -> int:
	match metric:
		"followers": return state.followers
		"peak": return state.lifetime_peak_viewers
		"collabs": return state.completed_collabs
		"high_tier_collabs": return state.high_tier_collabs
		"viral_posts": return state.viral_posts
		"cooking": return _stream_count(state, "cooking")
		"irl": return _stream_count(state, "irl")
		"cosplay": return state.cosplay_streams
		"aquarium": return 1 if "aquarium" in state.owned_room_items else 0
		"room_items": return state.owned_room_items.size()
		"moved_home": return 1 if state.current_home_id != "starter_home" else 0
		"slay": return 1 if state.followers >= 1000000 and state.lifetime_peak_viewers >= 50000 and state.reputation >= 80.0 and state.high_tier_collabs >= 3 and state.unlocked_achievements.size() >= 12 else 0
	return 0

func _stream_count(state: PlayerState, stream_id: String) -> int:
	var count: int = 0
	for item: Dictionary in state.stream_history:
		if item.get("stream_type", "") == stream_id:
			count += 1
	return count

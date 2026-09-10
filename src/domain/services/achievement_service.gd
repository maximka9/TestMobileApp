class_name AchievementService
extends RefCounted

signal achievement_unlocked(id: String)

var catalog: ContentCatalog

func _init(content: ContentCatalog) -> void:
	catalog = content

func evaluate(state: PlayerState) -> Array[String]:
	var unlocked: Array[String] = []
	for id: String in catalog.achievements:
		if id in state.unlocked_achievements:
			continue
		var definition: AchievementDefinition = catalog.achievements[id] as AchievementDefinition
		if definition != null and _qualifies(state, definition):
			state.unlocked_achievements.append(id)
			unlocked.append(id)
			achievement_unlocked.emit(id)
	return unlocked

func _qualifies(state: PlayerState, definition: AchievementDefinition) -> bool:
	if not definition.required_creator_id.is_empty():
		return definition.required_creator_id in state.completed_irl_collab_creator_ids
	if not definition.requirements.is_empty():
		for metric: String in definition.requirements:
			if _value(state, metric) < int(definition.requirements[metric]):
				return false
		return true
	return _value(state, definition.metric) >= definition.threshold

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
		"reputation": return int(state.reputation)
		"achievements": return state.unlocked_achievements.size()
	return 0

func _stream_count(state: PlayerState, stream_id: String) -> int:
	var count: int = 0
	for item: Dictionary in state.stream_history:
		if item.get("stream_type", "") == stream_id:
			count += 1
	return count

class_name AchievementService
extends RefCounted

signal achievement_unlocked(id: String)

var catalog: ContentCatalog

func _init(content: ContentCatalog) -> void:
	catalog = content

func evaluate(state: PlayerState) -> Array[String]:
	var unlocked: Array[String] = []
	var changed: bool = true
	while changed:
		changed = false
		for id: String in catalog.achievements:
			if id in state.unlocked_achievements:
				continue
			var definition: AchievementDefinition = catalog.achievements[id] as AchievementDefinition
			if definition != null and _qualifies(state, definition):
				state.unlocked_achievements.append(id)
				unlocked.append(id)
				achievement_unlocked.emit(id)
				changed = true
	return unlocked

func _qualifies(state: PlayerState, definition: AchievementDefinition) -> bool:
	for parent: String in definition.parent_ids:
		if not parent in state.unlocked_achievements:
			return false
	if not definition.required_creator_id.is_empty():
		return definition.required_creator_id in state.completed_irl_collab_creator_ids
	if not definition.requirements.is_empty():
		for metric: String in definition.requirements:
			if _value(state, metric) < int(definition.requirements[metric]):
				return false
		return true
	return _value(state, definition.metric) >= definition.threshold

## Read-only presentation API. Unlock evaluation remains in evaluate().
func progress(state: PlayerState, id: String) -> Dictionary:
	var definition: AchievementDefinition = catalog.achievements.get(id)
	if definition == null or state == null:
		return {}
	var completed: bool = id in state.unlocked_achievements
	var missing: PackedStringArray = []
	for parent: String in definition.parent_ids:
		if not parent in state.unlocked_achievements:
			var prerequisite: AchievementDefinition = catalog.achievements.get(parent)
			missing.append(prerequisite.display_name if prerequisite != null else parent)
	var conditions: PackedStringArray = []
	var current: int = 0
	var target: int = definition.threshold
	if not definition.required_creator_id.is_empty():
		current = 1 if definition.required_creator_id in state.completed_irl_collab_creator_ids else 0
		target = 1
		conditions.append("IRL-коллаб с %s: %d / 1" % [definition.required_creator_id, current])
	elif not definition.requirements.is_empty():
		target = definition.requirements.size()
		var metrics: Array = definition.requirements.keys()
		metrics.sort()
		for metric: String in metrics:
			var goal: int = int(definition.requirements[metric])
			var value: int = _value(state, metric)
			current += 1 if value >= goal else 0
			conditions.append("%s: %d / %d" % [_metric_label(metric), mini(value, goal), goal])
	else:
		current = mini(_value(state, definition.metric), target)
		conditions.append("%d / %d" % [current, target])
	return {"completed": completed, "available": not completed and missing.is_empty(),
		"locked": not completed and not missing.is_empty(), "current": current,
		"target": target, "conditions": conditions, "missing_prerequisites": missing,
		"status_text": "Выполнено ✓" if completed else "Доступно" if missing.is_empty() else "Заблокировано"}

func _metric_label(metric: String) -> String:
	return {"followers": "Подписчики", "peak": "Пиковый онлайн", "collabs": "Коллабы",
		"high_tier_collabs": "Крупные коллабы", "viral_posts": "Вирусные ролики",
		"cooking": "Кулинарные эфиры", "irl": "IRL-эфиры", "cosplay": "Косплеи",
		"aquarium": "Аквариум", "room_items": "Предметы интерьера", "moved_home": "Переезд",
		"reputation": "Репутация", "achievements": "Достижения"}.get(metric, metric)

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

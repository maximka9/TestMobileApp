extends "res://tests/test_runner.gd"

func _run() -> void:
	_fixture()
	for level: int in [1, 2, 5, 20, 1000]:
		check(progression.required_xp(level) == 100, "Every level requires 100 XP")
	var followers: int = state.followers
	progression.add_xp(state, 251)
	check(state.level == 3 and state.xp == 51, "Multi-level XP remainder")
	check(state.followers == followers + 251 and state.lifetime_followers_gained == 251, "Each awarded XP grants exactly one follower")
	var copy: PlayerState = saves.deserialize(saves.serialize(state)).context.state
	check(copy.level == 3 and copy.xp == 51 and copy.followers == state.followers, "Level-up save roundtrip")
	progression.add_xp(copy, -1)
	check(copy.followers == state.followers and copy.xp == 51, "Rejected XP never awards followers")
	state.level = 5
	state.xp = 499
	copy = saves.deserialize(saves.serialize(state)).context.state
	check(copy.level == 9 and copy.xp == 99 and copy.followers == state.followers, "Schema 12 old carried XP normalized without retroactive followers")
	copy = saves.deserialize(saves.serialize(copy)).context.state
	check(copy.level == 9 and copy.xp == 99, "Old save normalization idempotent")
	_test_progress_api()
	for graph: Dictionary in [
		{"A": [], "B": [], "C": ["A", "B"], "D": ["C"]},
		{"A": [], "B": [], "C": ["A", "B"], "D": [], "E": ["C", "D"], "F": ["E"]},
		{"A": [], "B": ["A"], "C": ["A", "B"], "D": ["C"], "E": ["B", "D"], "F": ["E"], "G": ["C"]}]:
		_test_dag(graph)
	var special: Dictionary = {}
	for item: AchievementDefinition in catalog.achievements.values():
		check(item.icon != null or SasaUI.DEFAULT_ACHIEVEMENT != null, "Achievement icon resolves")
		if not item.required_creator_id.is_empty():
			check(not special.has(item.icon.resource_path), "Unique special IRL icon")
			special[item.icon.resource_path] = true
	check(special.size() == 6, "Six unique IRL icons")
	check(catalog.moves["beer"].icon.resource_path.ends_with("beer.svg"), "Beer has a beer icon")
	for item: ActionDefinition in catalog.moves.values():
		check(item.icon != null or SasaUI.DEFAULT_MOVE != null, "Move icon resolves")
	check(SasaUI.DEFAULT_CONTENT != SasaUI.DEFAULT_MOVE and SasaUI.DEFAULT_MOVE != SasaUI.DEFAULT_ACHIEVEMENT and SasaUI.DEFAULT_EVENT != SasaUI.DEFAULT_ACHIEVEMENT, "Thematic fallbacks distinct")
	for path: String in OS.get_cmdline_user_args():
		if path.ends_with(".json"):
			var raw: String = FileAccess.get_file_as_string(path)
			var document: Dictionary = JSON.parse_string(raw)
			var result: OperationResult = saves.deserialize(document)
			check(result.success, "Historical schema-12 save loads: " + path.get_file())
			if result.success:
				var restored: PlayerState = result.context.state
				for field: String in ["money", "followers", "unlocked_achievements", "completed_collabs", "relationships", "owned_room_items", "owned_homes", "upgrades"]:
					check(restored.get(field) == document.player[field], "Historical progress preserved: " + field)
	print("V0112 SYSTEMS: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_progress_api() -> void:
	_fixture()
	var service := AchievementService.new(catalog)
	var p: Dictionary = service.progress(state, "followers_100")
	check(p.available and not p.completed and p.current == 30 and p.target == 100, "Metric-based available progress")
	p = service.progress(state, "followers_1000")
	check(p.locked and p.missing_prerequisites.size() == 1, "Parent prerequisite explained")
	state.unlocked_achievements.append("followers_100")
	check(service.progress(state, "followers_100").completed, "Completed progress independent of current counters")
	var definition := AchievementDefinition.new()
	definition.id = "requirements_fixture"
	definition.requirements = {"followers": 30, "collabs": 2}
	catalog.achievements[definition.id] = definition
	p = service.progress(state, definition.id)
	check(p.current == 1 and p.target == 2 and p.conditions.size() == 2, "All requirement conditions presented")
	p = service.progress(state, "irl_collab_iceicell")
	check(p.current == 0 and p.target == 1 and "iceicell" in p.conditions[0], "Creator-specific condition presented")
	state.completed_irl_collab_creator_ids.append("iceicell")
	check(service.progress(state, "irl_collab_iceicell").current == 1, "Creator completion counted")
	check(state.unlocked_achievements == ["followers_100"], "Progress API never mutates unlocks")

func _test_dag(graph: Dictionary) -> void:
	var definitions: Dictionary = {}
	for id: String in graph:
		var item := AchievementDefinition.new()
		item.id = id
		item.parent_ids = PackedStringArray(graph[id])
		definitions[id] = item
	var layout := AchievementLayout.new()
	layout.build(definitions)
	check(layout.positions.size() == graph.size(), "Every DAG node placed")
	for id: String in graph:
		var expected_depth: int = 0
		for parent: String in graph[id]:
			expected_depth = maxi(expected_depth, layout.depths[parent] + 1)
		check(layout.depths[id] == expected_depth, "Topological depth")
		var rect := Rect2(layout.positions[id], AchievementLayout.NODE)
		check(Rect2(Vector2.ZERO, layout.bounds).encloses(rect), "DAG node in bounds")
		for other: String in graph:
			if id != other:
				check(not rect.intersects(Rect2(layout.positions[other], AchievementLayout.NODE)), "DAG nodes never overlap")
	for edge: Dictionary in layout.connections:
		check(not layout._hits_node(edge.points, edge.parent, edge.child), "DAG edges avoid foreign nodes")
	var reversed: Dictionary = {}
	var ids: Array = definitions.keys()
	ids.reverse()
	for id: String in ids:
		reversed[id] = definitions[id]
	var again := AchievementLayout.new()
	again.build(reversed)
	check(layout.positions == again.positions and layout.connections == again.connections, "Insertion-order independent DAG layout")

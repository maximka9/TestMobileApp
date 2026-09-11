class_name AchievementLayout
extends RefCounted
## Stable subtree layout. Single-parent branches occupy disjoint column intervals;
## multi-parent sinks join below the deepest prerequisite, never through siblings.
const NODE := Vector2(64, 64)
const STEP := Vector2(80, 104)
const MARGIN := Vector2(24, 100)
var positions: Dictionary = {}
var depths: Dictionary = {}
var connections: Array[Dictionary] = []
var bounds := Vector2.ZERO
var _children: Dictionary = {}
var _column: int = 0

func build(definitions: Dictionary) -> void:
	positions.clear()
	depths.clear()
	connections.clear()
	_children.clear()
	_column = 0
	var ids: Array = definitions.keys()
	ids.sort()
	for id: String in ids:
		_children[id] = []
	var pending: Array = ids.duplicate()
	while not pending.is_empty():
		var progressed := false
		for id: String in pending.duplicate():
			var ready := true
			var depth: int = 0
			for parent: String in definitions[id].parent_ids:
				ready = ready and depths.has(parent)
				depth = maxi(depth, int(depths.get(parent, -1)) + 1)
			if ready:
				depths[id] = depth
				pending.erase(id)
				progressed = true
		if not progressed:
			push_error("Invalid achievement graph for layout")
			return
	for id: String in ids:
		if definitions[id].parent_ids.size() == 1:
			_children[definitions[id].parent_ids[0]].append(id)
	for id: String in ids:
		if definitions[id].parent_ids.is_empty():
			_place(id)
	for id: String in ids:
		if definitions[id].parent_ids.size() > 1:
			var left := INF
			var right := -INF
			for parent: String in definitions[id].parent_ids:
				left = minf(left, positions[parent].x)
				right = maxf(right, positions[parent].x)
			positions[id] = Vector2((left + right) / 2, MARGIN.y + int(depths[id]) * STEP.y)
	bounds = Vector2.ZERO
	for id: String in ids:
		bounds = bounds.max(positions[id] + NODE + Vector2(24, 24))
		for parent: String in definitions[id].parent_ids:
			var start: Vector2 = positions[parent] + Vector2(NODE.x / 2, NODE.y)
			var end: Vector2 = positions[id] + Vector2(NODE.x / 2, 0)
			var bus_y: float = end.y - (STEP.y - NODE.y) / 2
			connections.append({"parent": parent, "child": id, "points": PackedVector2Array([start, Vector2(start.x, bus_y), Vector2(end.x, bus_y), end])})

func _place(id: String) -> void:
	var children: Array = _children[id]
	var x: float
	if children.is_empty():
		x = MARGIN.x + _column * STEP.x
		_column += 1
	else:
		for child: String in children:
			_place(child)
		x = (positions[children.front()].x + positions[children.back()].x) / 2
	positions[id] = Vector2(x, MARGIN.y + int(depths[id]) * STEP.y)

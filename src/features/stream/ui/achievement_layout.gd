class_name AchievementLayout
extends RefCounted
## Deterministic topological layout of single-parent forests joined as a DAG.
## Join roots may have arbitrary descendants, including further join roots.
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
	bounds = Vector2.ZERO
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
		if definitions[id].parent_ids.size() != 1:
			_place(id)
	var ordered: Array = ids.duplicate()
	ordered.sort_custom(func(a: String, b: String) -> bool: return depths[a] < depths[b] if depths[a] != depths[b] else a < b)
	for id: String in ordered:
		if definitions[id].parent_ids.size() > 1:
			var left := INF
			var right := -INF
			for parent: String in definitions[id].parent_ids:
				left = minf(left, positions[parent].x)
				right = maxf(right, positions[parent].x)
			var group: Array[String] = []
			_collect(id, group)
			var shift: float = (left + right) / 2 - positions[id].x
			for member: String in group:
				shift = maxf(shift, MARGIN.x - positions[member].x)
			while _overlaps(group, shift):
				shift += STEP.x
			for member: String in group:
				positions[member].x += shift
	bounds = Vector2.ZERO
	for id: String in ids:
		bounds = bounds.max(positions[id] + NODE + Vector2(24, 24))
		for parent: String in definitions[id].parent_ids:
			var start: Vector2 = positions[parent] + Vector2(NODE.x / 2, NODE.y)
			var end: Vector2 = positions[id] + Vector2(NODE.x / 2, 0)
			var bus_y: float = end.y - (STEP.y - NODE.y) / 2
			var points := PackedVector2Array([start, Vector2(start.x, bus_y), Vector2(end.x, bus_y), end])
			if _hits_node(points, parent, id):
				# Reserve an exterior lane for a long edge obstructed by another rank.
				var lane: float = 0
				for at: Vector2 in positions.values():
					lane = maxf(lane, at.x + NODE.x + 12)
				points = PackedVector2Array([start, start + Vector2(0, 12), Vector2(lane, start.y + 12), Vector2(lane, bus_y), Vector2(end.x, bus_y), end])
			connections.append({"parent": parent, "child": id, "points": points})
			for point: Vector2 in points:
				bounds = bounds.max(point + Vector2(24, 24))

func _collect(id: String, group: Array[String]) -> void:
	group.append(id)
	for child: String in _children[id]:
		_collect(child, group)

func _overlaps(group: Array[String], shift: float) -> bool:
	for id: String in group:
		var rect := Rect2(positions[id] + Vector2(shift, 0), NODE).grow(4)
		for other: String in positions:
			if not other in group and rect.intersects(Rect2(positions[other], NODE)):
				return true
	return false

func _hits_node(points: PackedVector2Array, parent: String, child: String) -> bool:
	for id: String in positions:
		if id in [parent, child]:
			continue
		var rect := Rect2(positions[id], NODE).grow(-0.01)
		for index: int in range(points.size() - 1):
			var a: Vector2 = points[index]
			var b: Vector2 = points[index + 1]
			if a.x == b.x:
				if a.x > rect.position.x and a.x < rect.end.x and maxf(a.y, b.y) > rect.position.y and minf(a.y, b.y) < rect.end.y:
					return true
			elif a.y > rect.position.y and a.y < rect.end.y and maxf(a.x, b.x) > rect.position.x and minf(a.x, b.x) < rect.end.x:
				return true
	return false

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

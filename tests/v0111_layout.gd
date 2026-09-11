extends SceneTree
var failures := 0

func _initialize() -> void:
	var catalog := ContentCatalog.new()
	var layout := AchievementLayout.new()
	layout.build(catalog.achievements)
	_check(layout.positions.size() == 27, "All nodes placed")
	var segments: Array = []
	for id: String in layout.positions:
		var rect := Rect2(layout.positions[id], AchievementLayout.NODE)
		_check(Rect2(Vector2.ZERO, layout.bounds).encloses(rect), "Node in bounds")
		for other: String in layout.positions:
			if other != id:
				_check(not rect.intersects(Rect2(layout.positions[other], AchievementLayout.NODE)), "No node overlap")
	for edge: Dictionary in layout.connections:
		var points: PackedVector2Array = edge.points
		for i: int in range(points.size() - 1):
			var a := points[i]
			var b := points[i + 1]
			_check(a.x == b.x or a.y == b.y, "Orthogonal connection")
			_check(Rect2(Vector2.ZERO, layout.bounds).has_point(a), "Connection in bounds")
			segments.append([a, b])
			for id: String in layout.positions:
				if id in [edge.parent, edge.child]:
					continue
				var r := Rect2(layout.positions[id], AchievementLayout.NODE).grow(-0.01)
				var hits: bool = (a.x > r.position.x and a.x < r.end.x and maxf(a.y, b.y) > r.position.y and minf(a.y, b.y) < r.end.y) if a.x == b.x else (a.y > r.position.y and a.y < r.end.y and maxf(a.x, b.x) > r.position.x and minf(a.x, b.x) < r.end.x)
				_check(not hits, "No connection through " + id)
	var crossings := 0
	for first: Array in segments:
		for second: Array in segments:
			if first[0].x == first[1].x and second[0].y == second[1].y:
				if first[0].x > minf(second[0].x, second[1].x) and first[0].x < maxf(second[0].x, second[1].x) and second[0].y > minf(first[0].y, first[1].y) and second[0].y < maxf(first[0].y, first[1].y):
					crossings += 1
	_check(crossings == 0, "Zero avoidable crossings: " + str(crossings))
	print("V0111 LAYOUT: %d failures; %d crossings" % [failures, crossings])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

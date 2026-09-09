class_name AudienceCurve
extends RefCounted

static func baseline(followers: int, config: GameConfig) -> float:
	var x: float = maxf(0, followers)
	var points: PackedVector2Array = config.audience_anchors
	if x <= points[0].x:
		return points[0].y * x / points[0].x
	for i: int in range(1, points.size()):
		if x <= points[i].x:
			var ratio: float = log(x / points[i - 1].x) / log(points[i].x / points[i - 1].x)
			return exp(lerpf(log(points[i - 1].y), log(points[i].y), ratio))
	var last: Vector2 = points[-1]
	return minf(config.audience_soft_cap, last.y * pow(x / last.x, config.audience_tail_exponent))

static func hype_multiplier(hype: float, config: GameConfig) -> float:
	return get_hype_modifiers(hype, config)["viewers"]

static func get_hype_modifiers(hype: float, config: GameConfig) -> Dictionary:
	var value: float = clampf(hype, 0, 100)
	var xp: float = 1.0
	for step: Vector2 in [Vector2(50, 1.05), Vector2(70, 1.10), Vector2(85, 1.20), Vector2(95, 1.30), Vector2(100, 1.35)]:
		if value >= step.x:
			xp = step.y
	return {"viewers": _interpolate(value, config.hype_anchors), "followers": _interpolate(value, config.follower_hype_anchors), "xp": xp, "viral": 1.0 + value * config.source_hype_viral_factor}

static func _interpolate(value: float, points: PackedVector2Array) -> float:
	for i: int in range(1, points.size()):
		if value <= points[i].x:
			return lerpf(points[i - 1].y, points[i].y, clampf((value - points[i - 1].x) / (points[i].x - points[i - 1].x), 0, 1))
	return points[-1].y

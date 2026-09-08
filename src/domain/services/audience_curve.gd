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
	var points: PackedVector2Array = config.hype_anchors
	for i: int in range(1, points.size()):
		if hype <= points[i].x:
			return lerpf(points[i - 1].y, points[i].y, clampf((hype - points[i - 1].x) / (points[i].x - points[i - 1].x), 0, 1))
	return points[-1].y

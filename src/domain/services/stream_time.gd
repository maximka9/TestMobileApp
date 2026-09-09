class_name StreamTime
extends RefCounted

const GAME_MINUTES_PER_REAL_SECOND: float = 1.0

static func game_minutes_from_real_seconds(seconds: float) -> int:
	return floori(maxf(0, seconds) * GAME_MINUTES_PER_REAL_SECOND)

static func format_live(seconds: float) -> String:
	var minutes: int = game_minutes_from_real_seconds(seconds)
	return "%02d:%02d" % [minutes / 60, minutes % 60]

static func format_summary(seconds: float) -> String:
	var minutes: int = game_minutes_from_real_seconds(seconds)
	return "%d ч %d мин" % [minutes / 60, minutes % 60] if minutes >= 60 else "%d мин" % minutes

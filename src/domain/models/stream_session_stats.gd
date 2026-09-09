class_name StreamSessionStats
extends RefCounted
var viewer_sample_sum: float = 0
var viewer_sample_count: int = 0
var peak_viewers: int = 0
var hype_sample_sum: float = 0
var hype_sample_count: int = 0
var clicks: int = 0
var game_minutes: int = 0

func observe(viewers: int, hype: float) -> void:
	var value: int = maxi(0, viewers)
	viewer_sample_sum += value
	viewer_sample_count += 1
	peak_viewers = maxi(peak_viewers, value)
	hype_sample_sum += clampf(hype, 0, 100)
	hype_sample_count += 1

func average_viewers() -> float:
	return viewer_sample_sum / viewer_sample_count if viewer_sample_count > 0 else 0.0

func average_hype() -> float:
	return hype_sample_sum / hype_sample_count if hype_sample_count > 0 else 0.0

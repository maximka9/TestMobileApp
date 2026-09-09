class_name ChatActivityService
extends RefCounted

var config: GameConfig
var random: RandomProvider
var participants: PackedStringArray = []
var elapsed: float = 0.0
var generated: int = 0
var _live: bool = false
var _sample: float = 0.5

func _init(settings: GameConfig, rng: RandomProvider = null) -> void:
	config = settings
	random = rng if rng != null else RandomProvider.new()

func interval(viewers: int, hype: float) -> float:
	if viewers <= 0:
		return INF
	var band: int = 0
	for threshold: int in config.chat_viewer_thresholds:
		if viewers > threshold:
			band += 1
	var hype_band: int = 0
	for threshold: float in config.chat_hype_thresholds:
		if hype >= threshold:
			hype_band += 1
	return maxf(config.chat_min_interval, lerpf(config.chat_interval_min[band], config.chat_interval_max[band], _sample) / config.chat_hype_multipliers[hype_band])

func advance(delta: float, live: bool, viewers: int, hype: float) -> String:
	if live and not _live:
		participants.clear()
		var offset: int = random.between(1, 700)
		for i: int in range(12):
			participants.append(["anon", "viewer", "chat", "user"][i % 4] + "_" + str(offset + i))
		generated = 0
		elapsed = 0
	_live = live
	if not live or viewers <= 0:
		elapsed = 0
		return ""
	elapsed += maxf(0, delta)
	if elapsed < interval(viewers, hype):
		return ""
	# At most one message per frame; never replay a backlog after a stall.
	elapsed = 0
	_sample = random.between(0, 10000) / 10000.0
	generated += 1
	return participants[random.between(0, participants.size() - 1)]

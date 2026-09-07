class_name PlayerState
extends RefCounted
## Persistent player data. Only domain services mutate it; sessions are transient.

var level: int = 1
var xp: int = 0
var money: int = 0
var viewers: int = 0
var hype: float = 0.0
var fatigue: float = 0.0
## Compatibility view for existing move costs; fatigue is the only stored meter.
var energy: float:
	get:
		return 100.0 - fatigue
	set(value):
		fatigue = 100.0 - value
var followers: int = 30
var average_online: float = 0.0
var lifetime_peak_viewers: int = 0
var lifetime_followers_gained: int = 0
var stream_history: Array[Dictionary] = []
var last_stream_types: Array[String] = []
var current_location_id: String = "streamer_room"
var current_home_id: String = "starter_home"
var growth_momentum: float = 0.0
var reputation: float = 50.0
var relationships: Dictionary = {}
## Per-author request window persists so reload cannot reset spam protection.
var social_requests: Dictionary = {}
var collab_cooldowns: Dictionary = {}
var completed_collabs: int = 0
var short_form_history: Array[String] = []
var click_power: int = 1
var current_stream_type_id: String = "just_chatting"
var is_streaming: bool = false
var total_clicks: int = 0
var total_streams: int = 0
var streams_completed: int:
	get:
		return total_streams
	set(value):
		total_streams = value
var upgrades: Dictionary = {}
var settings: Dictionary = {"reduced_motion": false}

## Energy is stored as 0..100 percent. Chair capacity makes each move cost less percent.
func normalize() -> void:
	level = clampi(level, 1, 100000)
	xp = maxi(0, xp)
	money = maxi(0, money)
	viewers = maxi(0, viewers)
	hype = clampf(hype, 0.0, 100.0) if is_finite(hype) else 0.0
	energy = clampf(energy, 0.0, 100.0) if is_finite(energy) else 100.0
	click_power = maxi(1, click_power)
	total_clicks = maxi(0, total_clicks)
	total_streams = maxi(0, total_streams)
	followers = maxi(0, followers)
	average_online = maxf(0.0, average_online) if is_finite(average_online) else 0.0
	lifetime_peak_viewers = maxi(0, lifetime_peak_viewers)
	lifetime_followers_gained = maxi(0, lifetime_followers_gained)
	growth_momentum = clampf(growth_momentum, 0.0, 100.0) if is_finite(growth_momentum) else 0.0

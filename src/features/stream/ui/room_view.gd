class_name RoomView
extends Control
## Layered original sprite scene. All animation is bounded and presentation-only.
signal tapped(position: Vector2)

const DESIGN_SIZE := Vector2(336, 250)
const STARTER_TEXTURE: Texture2D = preload("res://assets/characters/sasavot_frames.png")
const APPEARANCE: CharacterAppearance = preload("res://resources/characters/appearance.tres")

var live: bool = false
var viewers: int = 0
var reduced_motion: bool = false
var hype: float = 0.0
var pulse: float = 0.0
var floating_pool: FloatingTextPool
var _idle_clock: float = 0.0
var _category: String = ""
var _touches: Dictionary[int, bool] = {}
var _shown_live: bool = false
var _appearance_tier: int = -1
var cosplay_variant: String = ""
var _shown_cosplay_variant: String = ""
var _appearance_scale: Vector2 = Vector2.ONE

@onready var _stage: Control = $Stage
@onready var sasavot_sprite: Sprite2D = $Stage/Character/SasavotSprite
@onready var monitor_status: Label = get_node_or_null("Stage/Desk/RightMonitor/ScreenClip/Status")
@onready var _hype_light: TextureRect = get_node_or_null("Stage/AmbientLighting/HypeLight")

func _ready() -> void:
	custom_minimum_size = Vector2(0, 210)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	_ignore_child_input(self)
	$Stage/Desk/LeftMonitor.rotation_degrees = 3.0
	var details := Node2D.new()
	details.set_script(preload("res://src/features/stream/ui/workstation_details.gd"))
	$Stage/Foreground/DesktopKeyboardMouse.add_child(details)
	$Stage/Desk/RightMonitor.transform = Transform2D(Vector2(0.28, 0.24), Vector2(0, 1), Vector2(245, 92))
	$Stage/Desk/RightMonitor.z_index = 1 # Foreground monitor must not lose text behind the character's arm.
	$Stage/Desk/RightMonitor/Bezel.scale = Vector2(1.15, 1.3)
	floating_pool = $Effects/FloatingTextPool as FloatingTextPool
	resized.connect(_fit_stage)
	_fit_stage()
	_set_category("just_chatting")
	_refresh_live()

func present(state: PlayerState) -> void:
	live = state.is_streaming
	viewers = state.viewers
	reduced_motion = bool(state.settings.get("reduced_motion", false))
	hype = state.hype
	if not is_node_ready():
		return
	_set_category(state.current_stream_type_id)
	_set_appearance(state.career_tier)
	$Stage/Aquarium.visible = "aquarium" in state.owned_room_items
	$Stage/Wall.modulate = Color(0.65, 0.75, 0.85) if "dark_wood_wall" in state.owned_room_items else Color.WHITE
	$Stage/FurnitureBack/Floor.modulate = Color(0.6, 0.7, 0.85) if "industrial_floor" in state.owned_room_items else Color.WHITE
	$Stage/AdaptiveBackdrop/LeftLED.modulate = Color(1, 0.5, 0.7) if "neon_light" in state.owned_room_items else Color.WHITE
	$Stage/AdaptiveBackdrop/RightLED.modulate = $Stage/AdaptiveBackdrop/LeftLED.modulate
	_refresh_live()
	if reduced_motion:
		pulse = 0.0
		sasavot_sprite.frame = 0
		sasavot_sprite.scale = _appearance_scale

func _process(delta: float) -> void:
	if not is_node_ready():
		return
	_idle_clock += delta
	pulse = maxf(0.0, pulse - delta * 5.0)
	if reduced_motion:
		sasavot_sprite.frame = 0
		sasavot_sprite.scale = _appearance_scale
	elif pulse > 0.0:
		sasavot_sprite.frame = 3 if sasavot_sprite.hframes >= 4 else 0
		sasavot_sprite.scale = _appearance_scale * (1.0 + pulse * 0.025)
	else:
		var phase: float = fmod(_idle_clock, 4.8)
		sasavot_sprite.frame = 2 if sasavot_sprite.hframes >= 4 and phase > 4.60 else (1 if sasavot_sprite.hframes >= 4 and phase > 2.3 else 0)
		sasavot_sprite.scale = _appearance_scale
	if _hype_light != null:
		_hype_light.modulate.a = 0.30 if live and hype >= 80.0 else 0.0
	_refresh_live()
	if $Stage/Aquarium.visible and not reduced_motion:
		$Stage/Aquarium/Fish.position.x = 9.0 + fposmod(_idle_clock * 8.0, 34.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and not touch.canceled:
			if not _touches.has(touch.index):
				_touches[touch.index] = true
				tapped.emit(touch.position)
		else:
			_touches.erase(touch.index)
		accept_event()
	elif event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.device == InputEvent.DEVICE_ID_EMULATION:
			accept_event()
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			tapped.emit(mouse.position)
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_touches.clear()

func _input(event: InputEvent) -> void:
	# A finger may leave the room before release or be covered by a modal.
	# Observe global releases without consuming input owned by other controls.
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if not touch.pressed or touch.canceled:
			_touches.erase(touch.index)

func react(position_clicked: Vector2, amount: float, xp: int = 0) -> void:
	pulse = 0.0 if reduced_motion else 1.0
	if is_instance_valid(floating_pool):
		floating_pool.emit_amount(position_clicked, amount, size, reduced_motion, xp)

func _fit_stage() -> void:
	if not is_instance_valid(_stage) or size.x <= 0.0 or size.y <= 0.0:
		return
	# Cover the width; crop vertically on short viewports instead of side bands.
	var ratio: float = size.x / DESIGN_SIZE.x
	_stage.scale = Vector2.ONE * ratio
	_stage.position = Vector2(roundf((size.x - DESIGN_SIZE.x * ratio) * 0.5), 0.0)
	var extra: float = maxf(0.0, size.y / ratio - DESIGN_SIZE.y)
	var wall_extra: float = roundf(extra * 0.65)
	var wall_height: float = 181.0 + wall_extra
	$Stage/AdaptiveBackdrop/WallExtension.size = Vector2(336, wall_height)
	$Stage/AdaptiveBackdrop/LeftWall.size.y = wall_height
	$Stage/AdaptiveBackdrop/RightWall.size.y = wall_height
	$Stage/AdaptiveBackdrop/LeftLED.size.y = wall_height
	$Stage/AdaptiveBackdrop/RightLED.size.y = wall_height
	$Stage/FurnitureBack/Shelf.position.y = 49.0 + wall_extra
	$Stage/FurnitureBack/PC.position.y = 83.0 + wall_extra
	$Stage/FurnitureBack/Floor.position.y = wall_height
	$Stage/FurnitureBack/Floor.scale.y = (69.0 + extra - wall_extra) / 39.0
	$Stage/Wall/FridayReference.position.y = 26.0 + roundf(extra * 0.18)
	$Stage/Wall/FirefighterReference.position.y = 29.0 + roundf(extra * 0.18)
	$Stage/Wall/FirefighterCaption.position.y = 69.0 + roundf(extra * 0.18)
	$Stage/Desk.position.y = wall_extra
	$Stage/Character.position.y = wall_extra
	$Stage/Foreground.position.y = wall_extra
	$Stage/AmbientLighting.position.y = wall_extra

func _set_appearance(career_tier: int) -> void:
	var target: int = APPEARANCE.index_for(career_tier)
	if target == _appearance_tier and cosplay_variant == _shown_cosplay_variant:
		return
	_appearance_tier = target
	_shown_cosplay_variant = cosplay_variant
	_appearance_scale = APPEARANCE.apply(sasavot_sprite, career_tier)
	if APPEARANCE.cosplay_variants.has(cosplay_variant):
		sasavot_sprite.hframes = 1
		sasavot_sprite.texture = APPEARANCE.cosplay_variants[cosplay_variant]
		_appearance_scale = Vector2.ONE * (128.0 / sasavot_sprite.texture.get_height())
	sasavot_sprite.frame = 0
	sasavot_sprite.scale = _appearance_scale

func _set_category(category: String) -> void:
	if category == _category:
		return
	_category = category
	$Stage/Desk/LeftMonitor/CategoryVisual/Moba.visible = category == "dota_2"
	$Stage/Desk/LeftMonitor/CategoryVisual/Camera.visible = category == "irl"

func _refresh_live() -> void:
	if monitor_status == null or (_shown_live == live and not monitor_status.text.is_empty()):
		return
	_shown_live = live
	monitor_status.text = "● LIVE" if live else "○ OFFLINE"
	$Stage/Desk/LeftMonitor/CategoryVisual.modulate.a = 1.0 if live else 0.65

func _ignore_child_input(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_child_input(child)

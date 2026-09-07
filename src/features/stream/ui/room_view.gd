class_name RoomView
extends Control
## Layered original sprite scene. All animation is bounded and presentation-only.
signal tapped(position: Vector2)

const DESIGN_SIZE := Vector2(336, 250)
const CHAT_LIMIT: int = 4
const CHAT_NAMES: PackedStringArray = ["kot", "user52", "masha", "anon", "sanya", "viewer", "omlet", "pixel"]
const CHAT_MESSAGES: PackedStringArray = ["жми жми", "ХАХАХ", "+", "КЛИП!", "погнали", "хорош", "KEKW", "это база"]
const CHAT_COLORS: PackedStringArray = ["#e78f91", "#b9cbed", "#edb879", "#cdadc5"]

var live: bool = false
var reduced_motion: bool = false
var hype: float = 0.0
var pulse: float = 0.0
var chat_clock: float = 0.0
var chat_index: int = 0
var floating_pool: FloatingTextPool
var _idle_clock: float = 0.0
var _chat_slide: float = 0.0
var _category: String = ""
var _chat_lines: PackedStringArray = []
var _chat_rows: Array[RichTextLabel] = []
var _touches: Dictionary[int, bool] = {}
var _shown_live: bool = false

@onready var _stage: Control = $Stage
@onready var sasavot_sprite: Sprite2D = $Stage/Character/SasavotSprite
@onready var _main_content: RichTextLabel = $Stage/Desk/LeftMonitor/Content
@onready var _chat_content: Control = $Stage/Desk/RightMonitor/ChatClip
@onready var _chat_status: Label = $Stage/Desk/RightMonitor/ChatStatus
@onready var _hype_light: TextureRect = $Stage/AmbientLighting/HypeLight

func _ready() -> void:
	custom_minimum_size = Vector2(0, 210)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	_ignore_child_input(self)
	for child: Node in _chat_content.get_children():
		_chat_rows.append(child as RichTextLabel)
	floating_pool = $Effects/FloatingTextPool as FloatingTextPool
	resized.connect(_fit_stage)
	_fit_stage()
	for i: int in range(CHAT_LIMIT):
		_push_chat()
	_set_category("just_chatting")
	_refresh_live()

func present(state: PlayerState) -> void:
	live = state.is_streaming
	reduced_motion = bool(state.settings.get("reduced_motion", false))
	hype = state.hype
	if not is_node_ready():
		return
	_set_category(state.current_stream_type_id)
	_refresh_live()
	if reduced_motion:
		pulse = 0.0
		sasavot_sprite.frame = 0
		sasavot_sprite.scale = Vector2.ONE
		_chat_slide = 0.0

func _process(delta: float) -> void:
	if not is_node_ready():
		return
	_idle_clock += delta
	pulse = maxf(0.0, pulse - delta * 5.0)
	if reduced_motion:
		sasavot_sprite.frame = 0
		sasavot_sprite.scale = Vector2.ONE
	elif pulse > 0.0:
		sasavot_sprite.frame = 3
		sasavot_sprite.scale = Vector2.ONE * (1.0 + pulse * 0.025)
	else:
		var phase: float = fmod(_idle_clock, 4.8)
		sasavot_sprite.frame = 2 if phase > 4.60 else (1 if phase > 2.3 else 0)
		sasavot_sprite.scale = Vector2.ONE
	_hype_light.modulate.a = 0.30 if live and hype >= 80.0 else 0.0
	_refresh_live()
	if live:
		chat_clock += delta
		if chat_clock >= chat_interval():
			chat_clock = 0.0
			_push_chat()
			_chat_slide = 0.0 if reduced_motion else 11.0
	_chat_slide = 0.0 if reduced_motion else maxf(0.0, _chat_slide - delta * 40.0)
	for i: int in range(_chat_rows.size()):
		_chat_rows[i].position.y = float(i * 11) + roundf(_chat_slide)

func chat_interval() -> float:
	return 0.65 if hype > 70.0 else (3.8 if hype < 20.0 else 1.8)

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

func react(position_clicked: Vector2, amount: float) -> void:
	pulse = 0.0 if reduced_motion else 1.0
	if is_instance_valid(floating_pool):
		floating_pool.emit_amount(position_clicked, amount, size, reduced_motion)

func _fit_stage() -> void:
	if not is_instance_valid(_stage) or size.x <= 0.0 or size.y <= 0.0:
		return
	var ratio: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_stage.scale = Vector2.ONE * ratio
	_stage.position = Vector2(roundf((size.x - DESIGN_SIZE.x * ratio) * 0.5), 0.0)
	var extra: float = maxf(0.0, size.y / ratio - DESIGN_SIZE.y)
	var wall_extra: float = roundf(extra * 0.65)
	var wall_height: float = 181.0 + wall_extra
	$Stage/AdaptiveBackdrop/WallExtension.size = Vector2(336, wall_height)
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

func _set_category(category: String) -> void:
	if category == _category:
		return
	_category = category
	$Stage/Desk/LeftMonitor/CategoryVisual/Moba.visible = category == "dota_2"
	$Stage/Desk/LeftMonitor/CategoryVisual/Camera.visible = category == "irl"
	match category:
		"dota_2":
			_main_content.text = "[color=#d9e6ee]DOTA 2 / 12 : 8[/color]"
		"irl":
			_main_content.text = "[color=#d9e6ee]IRL / CAMERA[/color]"
		_:
			_main_content.text = "[color=#d9e6ee]JUST CHATTING[/color]\n[color=#96b0c7]  ●  SASAVOT[/color]\n[color=#cbd5df]  Привет, чат!\n  Как настроение?[/color]\n[color=#e4999d]  ♥   ♥   ♥[/color]"

func _refresh_live() -> void:
	if _shown_live == live and not _chat_status.text.is_empty():
		return
	_shown_live = live
	_chat_status.text = "● LIVE / CHAT" if live else "○ OFFLINE"
	_main_content.modulate.a = 1.0 if live else 0.65
	$Stage/Desk/LeftMonitor/CategoryVisual.modulate.a = 1.0 if live else 0.65
	_chat_content.modulate.a = 1.0 if live else 0.75

func _push_chat() -> void:
	var nickname: String = CHAT_NAMES[chat_index % CHAT_NAMES.size()]
	var message: String = CHAT_MESSAGES[chat_index % CHAT_MESSAGES.size()]
	var color: String = CHAT_COLORS[chat_index % CHAT_COLORS.size()]
	_chat_lines.append("[color=%s]%s[/color] [color=#dddce3]%s[/color]" % [color, nickname, message])
	if _chat_lines.size() > CHAT_LIMIT:
		_chat_lines.remove_at(0)
	chat_index += 1
	for i: int in range(_chat_rows.size()):
		_chat_rows[i].text = _chat_lines[i] if i < _chat_lines.size() else ""

func _ignore_child_input(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_child_input(child)

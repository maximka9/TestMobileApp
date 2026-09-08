class_name AchievementPan
extends ScrollContainer
var held: bool = false
var dragged: bool = false
var origin: Vector2
var previous: Vector2

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_begin(event.position, event.pressed)
		elif event.pressed and get_global_rect().has_point(event.position):
			var direction: int = -1 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
				if event.shift_pressed or event.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
					scroll_horizontal += direction * 60
				else:
					scroll_vertical += direction * 60
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		_drag(event.position)
	elif event is InputEventScreenTouch:
		_begin(event.position, event.pressed and not event.canceled)
	elif event is InputEventScreenDrag:
		_drag(event.position)

func _begin(at: Vector2, pressed: bool) -> void:
	if pressed and get_global_rect().has_point(at):
		held = true
		dragged = false
		origin = at
		previous = at
	elif not pressed:
		held = false

func _drag(at: Vector2) -> void:
	if not held:
		return
	if at.distance_to(origin) > 6:
		dragged = true
	if dragged:
		scroll_horizontal -= int(at.x - previous.x)
		scroll_vertical -= int(at.y - previous.y)
		get_viewport().set_input_as_handled()
	previous = at

func focus_node(node: Control) -> void:
	scroll_horizontal = int(node.position.x + node.size.x / 2 - size.x / 2)
	scroll_vertical = int(node.position.y + node.size.y / 2 - size.y / 2)

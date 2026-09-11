class_name AchievementPan
extends ScrollContainer
var held: bool = false
var dragged: bool = false
var origin: Vector2
var previous: Vector2
const MIN_ZOOM: float = 0.60
const DEFAULT_ZOOM: float = 1.00
const MAX_ZOOM: float = 1.80
const ZOOM_STEP: float = 0.10
signal zoom_changed(value: float)
var zoom: float = DEFAULT_ZOOM
var canvas: Control
var bounds: Control

func attach_graph(graph: Control) -> void:
	canvas = graph
	bounds = Control.new()
	bounds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bounds)
	bounds.add_child(canvas)
	canvas.pivot_offset = Vector2.ZERO

func set_zoom(value: float, pivot: Vector2 = Vector2(-1, -1)) -> void:
	if canvas == null:
		return
	if pivot.x < 0:
		pivot = size / 2
	var world: Vector2 = (Vector2(scroll_horizontal, scroll_vertical) + pivot) / zoom
	zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	canvas.scale = Vector2.ONE * zoom
	canvas.size = canvas.custom_minimum_size
	bounds.custom_minimum_size = canvas.custom_minimum_size * zoom
	bounds.size = bounds.custom_minimum_size
	get_h_scroll_bar().max_value = maxf(size.x, bounds.custom_minimum_size.x)
	get_v_scroll_bar().max_value = maxf(size.y, bounds.custom_minimum_size.y)
	get_h_scroll_bar().page = size.x
	get_v_scroll_bar().page = size.y
	scroll_horizontal = int(world.x * zoom - pivot.x)
	scroll_vertical = int(world.y * zoom - pivot.y)
	zoom_changed.emit(zoom)

func fit() -> void:
	set_zoom(minf(size.x / canvas.custom_minimum_size.x, size.y / canvas.custom_minimum_size.y))
	scroll_horizontal = int((bounds.custom_minimum_size.x - size.x) / 2)
	scroll_vertical = 0 # Top-down progression: Fit starts with the root and branch split.

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMagnifyGesture and get_global_rect().has_point(event.position):
		set_zoom(zoom * event.factor, event.position - global_position)
		held = false
		dragged = true
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_begin(event.position, event.pressed)
		elif event.pressed and get_global_rect().has_point(event.position):
			var direction: int = -1 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
				if event.ctrl_pressed:
					set_zoom(zoom - direction * ZOOM_STEP, event.position - global_position)
				elif event.shift_pressed or event.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
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
	var controls: Control = get_parent().get_node_or_null("ZoomControls")
	if pressed and controls != null and controls.get_global_rect().has_point(at):
		return
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
	if bounds != null:
		get_h_scroll_bar().max_value = maxf(size.x, bounds.custom_minimum_size.x)
		get_v_scroll_bar().max_value = maxf(size.y, bounds.custom_minimum_size.y)
	scroll_horizontal = int((node.position.x + node.size.x / 2) * zoom - size.x / 2)
	scroll_vertical = int((node.position.y + node.size.y / 2) * zoom - size.y / 2)

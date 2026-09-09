class_name FloatingTextPool
extends Control
## Fixed allocation at ready; clicks only rewrite one existing label and its state.
const CAPACITY: int = 16
const LIFETIME: float = 0.65
var capacity: int = CAPACITY
var total_emitted: int = 0
var _labels: Array[Label] = []
var _ages: PackedFloat64Array = []
var _origins: PackedVector2Array = []
var _motion: PackedByteArray = []
var _next: int = 0

func _ready() -> void:
	z_index = 10 # Feedback remains above the foreground monitor and character.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ages.resize(CAPACITY)
	_origins.resize(CAPACITY)
	_motion.resize(CAPACITY)
	for i: int in range(CAPACITY):
		var label: Label = Label.new()
		label.name = "Number%02d" % i
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", Color("ffe1d3"))
		label.add_theme_color_override("font_outline_color", Color("250b12"))
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_font_size_override("font_size", 20)
		label.visible = false
		add_child(label)
		_labels.append(label)
		_ages[i] = LIFETIME

func emit_amount(at: Vector2, amount: float, bounds: Vector2, reduced_motion: bool, xp: int = 0) -> void:
	var index: int = _next
	_next = (_next + 1) % CAPACITY
	total_emitted += 1
	var label: Label = _labels[index]
	label.text = ("+%s хайпа\n" % (str(int(amount)) if amount == floor(amount) else "%.1f" % amount) if amount > 0 else "") + "+%d XP" % xp
	_origins[index] = Vector2(clampf(at.x - 14.0, 6.0, maxf(6.0, bounds.x - 155.0)), clampf(at.y - 22.0, 24.0, maxf(24.0, bounds.y - 60.0)))
	label.position = _origins[index]
	label.modulate.a = 1.0
	label.visible = true
	_ages[index] = 0.0
	_motion[index] = 0 if reduced_motion else 1

func _process(delta: float) -> void:
	for i: int in range(_labels.size()):
		if _ages[i] >= LIFETIME:
			continue
		_ages[i] = minf(LIFETIME, _ages[i] + delta)
		var progress: float = _ages[i] / LIFETIME
		var label: Label = _labels[i]
		label.position.y = _origins[i].y - (roundf(progress * 28.0) if _motion[i] == 1 else 0.0)
		label.modulate.a = 1.0 - progress
		label.visible = _ages[i] < LIFETIME

func active_count() -> int:
	var result: int = 0
	for age: float in _ages:
		if age < LIFETIME:
			result += 1
	return result

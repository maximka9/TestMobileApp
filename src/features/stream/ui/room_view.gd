class_name RoomView
extends Control
## Original code-drawn pixel placeholders. No third-party graphics or network chat.
signal tapped(position: Vector2)
const CHAT: PackedStringArray = ["user228: ХАХАХА", "anon: +", "chat_user: KEKW", "user52: КЛИП", "kot: жми жми", "viewer: отличный эфир"]
var live: bool = false
var chat_index: int = 0
var chat_clock: float = 0.0
var pulse: float = 0.0
var reduced_motion: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(0, 160)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	resized.connect(queue_redraw)
	gui_input.connect(_on_input)

func _process(delta: float) -> void:
	if pulse > 0.0:
		pulse = maxf(0.0, pulse - delta * 5.0)
		queue_redraw()
	if live:
		chat_clock += delta
		if chat_clock >= 2.5:
			chat_clock = 0.0
			chat_index = (chat_index + 1) % CHAT.size()
			queue_redraw()

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tapped.emit(event.position)
		accept_event()

func react(position_clicked: Vector2, amount: float) -> void:
	pulse = 0.0 if reduced_motion else 1.0
	var floating: Label = Label.new()
	floating.text = "+%s" % (str(int(amount)) if amount == floor(amount) else "%.1f" % amount)
	floating.add_theme_color_override("font_color", Color("c4f78d"))
	floating.add_theme_font_size_override("font_size", 22)
	floating.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating.position = Vector2(clampf(position_clicked.x, 8, size.x - 60), clampf(position_clicked.y, 30, size.y - 40))
	add_child(floating)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if not reduced_motion:
		tween.tween_property(floating, "position:y", floating.position.y - 35, 0.6)
	tween.tween_property(floating, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(floating.queue_free)

func _rect(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(color))

func _draw() -> void:
	var ratio: float = minf(size.x / 336.0, size.y / 280.0)
	var origin: Vector2 = Vector2((size.x - 336.0 * ratio) / 2.0, (size.y - 280.0 * ratio) / 2.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color("202039"))
	draw_set_transform(origin, 0.0, Vector2.ONE * ratio)
	_rect(0, 0, 336, 207, "29273e")
	for y: int in range(16, 200, 24):
		_rect(0, y, 336, 1, "302d47")
	_rect(0, 207, 336, 73, "393041")
	for x: int in range(0, 336, 42):
		_rect(x, 207, 2, 73, "48394c")
	_rect(16, 22, 81, 91, "141a30")
	_rect(21, 27, 71, 81, "364768")
	_rect(24, 52, 20, 53, "26314d")
	_rect(54, 36, 17, 69, "273550")
	_rect(74, 66, 15, 39, "222c46")
	for x: int in [28, 37, 57, 65, 78]:
		_rect(x, 74, 3, 4, "edc98f")
	_rect(53, 27, 3, 81, "141a30")
	_rect(21, 68, 71, 3, "141a30")
	_rect(114, 20, 101, 30, "161b2e")
	draw_string(ThemeDB.fallback_font, Vector2(122, 40), "SASA / ROOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("baa2f1"))
	_rect(258, 29, 58, 6, "765a6a")
	_rect(266, 12, 7, 17, "a688cd")
	_rect(276, 8, 7, 21, "c9a26e")
	_rect(287, 16, 16, 13, "708d78")
	# Game monitor and its pixel landscape.
	_rect(25, 119, 111, 71, "121727")
	_rect(30, 124, 101, 59, "294659")
	_rect(34, 165, 93, 14, "517066")
	_rect(44, 151, 24, 14, "75865d")
	_rect(83, 140, 20, 25, "506471")
	_rect(65, 159, 8, 13, "d1af8c")
	_rect(73, 190, 13, 13, "111726")
	_rect(60, 200, 39, 5, "16192a")
	# Chat monitor: locally rotated messages are actually drawn on its screen.
	_rect(226, 113, 101, 77, "121727")
	_rect(231, 118, 91, 65, "1c263a")
	draw_string(ThemeDB.fallback_font, Vector2(235, 131), "CHAT / " + ("LIVE" if live else "OFF"), HORIZONTAL_ALIGNMENT_LEFT, 85, 9, Color("bba0ee"))
	for i: int in range(3):
		var line: String = CHAT[(chat_index + i) % CHAT.size()] if live else ["Эфир скоро", "Чат ждёт тебя", "...Погнали?"][i]
		draw_string(ThemeDB.fallback_font, Vector2(235, 145 + i * 13), line, HORIZONTAL_ALIGNMENT_LEFT, 85, 8, Color("9db6c8"))
	_rect(267, 190, 12, 13, "111726")
	# Chair and streamer, with a brief scale response to taps.
	var bump: float = 1.0 + pulse * 0.035
	draw_set_transform(origin + Vector2(175, 177) * ratio, 0.0, Vector2.ONE * ratio * bump)
	_rect(-34, -48, 64, 101, "151827")
	_rect(-29, -42, 54, 91, "65527a")
	_rect(-24, -37, 8, 78, "846394")
	_rect(-21, -57, 41, 42, "dca98d")
	_rect(-24, -65, 46, 17, "44373c")
	_rect(-24, -52, 7, 17, "44373c")
	_rect(16, -53, 7, 15, "44373c")
	_rect(-14, -43, 8, 4, "29273e")
	_rect(5, -43, 8, 4, "29273e")
	_rect(-7, -26, 15, 3, "97695e")
	_rect(-29, -61, 6, 30, "ad91d5")
	_rect(22, -61, 6, 30, "ad91d5")
	_rect(-23, -69, 46, 5, "ad91d5")
	_rect(-28, -14, 56, 53, "a8c877")
	_rect(-19, -7, 39, 40, "b9dc84")
	_rect(-40, 5, 15, 31, "dca98d")
	_rect(28, 5, 15, 31, "dca98d")
	_rect(-17, 37, 15, 31, "25293e")
	_rect(6, 37, 15, 31, "25293e")
	draw_set_transform(origin, 0.0, Vector2.ONE * ratio)
	# Desk, keyboard, PC and microphone.
	_rect(17, 204, 309, 11, "b28a7a")
	_rect(17, 215, 309, 8, "775b63")
	_rect(27, 223, 10, 50, "302537")
	_rect(302, 223, 10, 50, "302537")
	_rect(107, 197, 80, 6, "b3a4bf")
	_rect(230, 227, 46, 49, "161c30")
	_rect(236, 233, 34, 7, "55637b")
	_rect(249, 249, 12, 12, "a48ed8")
	_rect(207, 160, 5, 43, "131827")
	_rect(201, 151, 17, 23, "232a41")
	_rect(204, 153, 11, 13, "899bb0")
	_rect(199, 201, 23, 4, "131827")
	_rect(4, 5, 4, 197, "a181d0")
	if live:
		_rect(310, 8, 7, 7, "f68e92")
	draw_set_transform(Vector2.ZERO)

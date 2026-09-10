class_name AchievementNotificationQueue
extends Control
## Ephemeral presentation state; historical unlocks are never replayed.
var pending: Array[String] = []
var seen: Dictionary = {}
var active_id: String = ""
var elapsed: float = 0.0
var reduced_motion: bool = false
var card: PanelContainer
var heading: Label
var description: Label
var catalog: ContentCatalog
const DURATION: float = 3.8

func setup(content: ContentCatalog) -> void:
	catalog = content
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("21151e")
	style.border_color = Color("e4b252")
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	var body: VBoxContainer = VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(body)
	for label: Label in [SasaUI.label("ДОСТИЖЕНИЕ ПОЛУЧЕНО", &"caption", &"AccentLabel"), SasaUI.label("", &"body"), SasaUI.label("", &"small", &"MutedLabel")]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.custom_minimum_size.x = 240
		body.add_child(label)
	heading = body.get_child(1)
	description = body.get_child(2)
	hide()

func enqueue(id: String) -> void:
	if seen.has(id) or not catalog.achievements.has(id):
		return
	seen[id] = true
	pending.append(id)

func advance(delta: float, blocked: bool, reduce: bool, available: Rect2) -> void:
	reduced_motion = reduce
	if blocked:
		hide()
		return
	if active_id.is_empty():
		if pending.is_empty():
			hide()
			return
		active_id = pending.pop_front()
		elapsed = 0
		var definition: AchievementDefinition = catalog.achievements[active_id]
		heading.text = "★ " + definition.display_name
		description.text = definition.description
	elapsed += delta
	if elapsed >= DURATION:
		active_id = ""
		hide()
		return
	show()
	card.custom_minimum_size.x = minf(290, available.size.x)
	card.size = Vector2(card.custom_minimum_size.x, 0)
	var entering: float = clampf(elapsed / 0.3, 0, 1)
	var leaving: float = clampf((elapsed - 3.5) / 0.3, 0, 1)
	card.modulate.a = entering * (1 - leaving)
	card.position = available.end - card.size
	card.pivot_offset = card.size / 2
	card.scale = Vector2.ONE if reduce else Vector2.ONE * (1 + sin(entering * PI) * 0.035)
	if not reduce:
		card.position.x += (1 - entering) * 60 + leaving * 30
	queue_redraw()

func _draw() -> void:
	if reduced_motion or elapsed < 0.3 or elapsed > 0.8 or active_id.is_empty():
		return
	var progress: float = (elapsed - 0.3) / 0.5
	for i: int in range(16):
		var angle: float = i * TAU / 16
		var at: Vector2 = card.position + Vector2(24, -6) + Vector2(cos(angle), sin(angle)) * (10 + progress * 38)
		var color: Color = Color("e4b252") if i % 2 == 0 else Color("d44958")
		color.a = 1 - progress
		draw_rect(Rect2(at.round(), Vector2(3, 3)), color)
		if i % 4 == 0:
			draw_rect(Rect2(at.round() - Vector2(2, 0), Vector2(7, 2)), color)
			draw_rect(Rect2(at.round() - Vector2(0, 2), Vector2(2, 7)), color)

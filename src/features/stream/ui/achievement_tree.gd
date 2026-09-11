class_name AchievementTree
extends Control

signal selected(id: String)
var catalog: ContentCatalog
var player: PlayerState
var buttons: Dictionary = {}
var _completion: String = ""
const NODE_SIZE := Vector2(64, 64)
const COLORS: Array[Color] = [Color("d44958"), Color("d44958"), Color("e4b252"), Color("f06b88")]
var positions: Dictionary = {}
var extents: Dictionary = {}
var selected_id: String = ""
var layout: AchievementLayout = AchievementLayout.new()

func setup(content: ContentCatalog, state: PlayerState) -> void:
	catalog = content
	player = state
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var graph_font: FontFile = (load("res://assets/fonts/NotoSans.ttf") as FontFile).duplicate()
	graph_font.multichannel_signed_distance_field = true
	layout.build(catalog.achievements)
	for id: String in catalog.achievements:
		var definition: AchievementDefinition = catalog.achievements[id]
		var button: Button = SasaUI.button("", func() -> void:
			if not get_parent().get_parent() is AchievementPan or not get_parent().get_parent().dragged:
				selected.emit(id))
		button.position = layout.positions[id]
		button.add_theme_font_override("font", graph_font)
		button.size = NODE_SIZE
		positions[id] = button.position
		extents[id] = button.size
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.icon = definition.icon if definition.icon != null else SasaUI.achievement_icon(id)
		button.add_theme_constant_override("icon_max_width", 44)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(button)
		buttons[id] = button
	custom_minimum_size = layout.bounds
	refresh(true)

func refresh(force: bool = false) -> void:
	var completion: String = str(player.unlocked_achievements)
	if not force and completion == _completion:
		return
	_completion = completion
	for id: String in buttons:
		var definition: AchievementDefinition = catalog.achievements[id]
		var completed: bool = id in player.unlocked_achievements
		var available: bool = true
		for parent: String in definition.parent_ids:
			available = available and parent in player.unlocked_achievements
		var button: Button = buttons[id]
		button.text = "✓" if completed else "?" if definition.secret else ""
		button.self_modulate = Color.WHITE if completed or available else Color(0.48, 0.48, 0.52)
		button.set_meta("completed", completed)
		button.set_meta("state", "completed" if completed else "secret" if definition.secret else "available" if available else "locked")
		button.tooltip_text = "Выполнено" if completed else "Доступно" if available else "Сначала выполните предыдущие достижения"
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color("301b22") if completed else Color("141419")
		box.border_color = COLORS[definition.tier] if completed else Color("942f42") if available else Color("45424a")
		if selected_id == id:
			box.border_color = Color.WHITE
		box.set_border_width_all(3 if completed else 2)
		box.set_corner_radius_all(8)
		box.shadow_color = Color(0.8, 0.1, 0.2, 0.25) if completed else Color.TRANSPARENT
		box.shadow_size = 5 if completed else 0
		button.add_theme_stylebox_override("normal", box)
		var hover: StyleBoxFlat = box.duplicate()
		hover.bg_color = box.bg_color.lightened(0.08)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_color_override("font_color", Color.WHITE if completed else Color("9994a0"))
		if force and available and not completed and not player.settings.get("reduced_motion", false):
			var tween: Tween = create_tween()
			tween.tween_property(button, "modulate", Color(1.3, 1.15, 1.15), 0.3)
			tween.tween_property(button, "modulate", Color.WHITE, 0.5)
	queue_redraw()

func _draw() -> void:
	if catalog == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("0c090e"))
	for x: int in range(0, int(size.x), 32):
		for y: int in range(0, int(size.y), 32):
			draw_circle(Vector2(x + 8, y + 8), 1, Color(0.5, 0.15, 0.22, 0.18))
	var drawn: Dictionary = {}
	for connection: Dictionary in layout.connections:
		var points: PackedVector2Array = connection.points
		var color: Color = Color("b64050") if connection.child in player.unlocked_achievements else Color("75273a") if connection.parent in player.unlocked_achievements else Color("39363f")
		for index: int in range(points.size() - 1):
			var key: String = str(points[index]) + str(points[index + 1])
			if not drawn.has(key):
				draw_line(points[index], points[index + 1], color, 1.0)
				drawn[key] = true

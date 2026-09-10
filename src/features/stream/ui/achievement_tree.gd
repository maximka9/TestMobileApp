class_name AchievementTree
extends Control

signal selected(id: String)
var catalog: ContentCatalog
var player: PlayerState
var buttons: Dictionary = {}
var _completion: String = ""
const NODE_SIZE := Vector2(150, 84)
const COLORS: Array[Color] = [Color("d44958"), Color("d44958"), Color("e4b252"), Color("f06b88")]
var positions: Dictionary = {}
var extents: Dictionary = {}

func setup(content: ContentCatalog, state: PlayerState) -> void:
	catalog = content
	player = state
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var graph_font: FontFile = (load("res://assets/fonts/NotoSans.ttf") as FontFile).duplicate()
	graph_font.multichannel_signed_distance_field = true
	var minimum: Vector2 = Vector2.ZERO
	var maximum: Vector2 = Vector2.ZERO
	for definition: AchievementDefinition in catalog.achievements.values():
		minimum = minimum.min(definition.graph_position)
	var offset: Vector2 = Vector2(24, 24) - minimum
	for id: String in catalog.achievements:
		var definition: AchievementDefinition = catalog.achievements[id]
		var button: Button = SasaUI.button("", func() -> void:
			if not get_parent().get_parent() is AchievementPan or not get_parent().get_parent().dragged:
				selected.emit(id))
		button.position = definition.graph_position + offset
		button.add_theme_font_override("font", graph_font)
		button.size = NODE_SIZE + (Vector2(12, 40) if definition.tier == 3 else Vector2.ZERO)
		positions[id] = button.position
		extents[id] = button.size
		maximum = maximum.max(button.position + button.size)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.icon = definition.icon
		add_child(button)
		buttons[id] = button
	custom_minimum_size = maximum + Vector2(24, 24)
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
		button.text = ("✓\n" if completed else "◆\n" if available else "◇\n") + (definition.display_name if completed or not definition.secret else "?")
		button.set_meta("completed", completed)
		button.set_meta("state", "completed" if completed else "secret" if definition.secret else "available" if available else "locked")
		button.tooltip_text = "Выполнено" if completed else "Доступно" if available else "Сначала выполните предыдущие достижения"
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color("301b22") if completed else Color("141419")
		box.border_color = COLORS[definition.tier] if completed else Color("942f42") if available else Color("45424a")
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
	for id: String in catalog.achievements:
		var definition: AchievementDefinition = catalog.achievements[id]
		for parent_id: String in definition.parent_ids:
			if catalog.achievements.has(parent_id):
				var from: Vector2 = positions[parent_id] + Vector2(extents[parent_id].x / 2, extents[parent_id].y)
				var to: Vector2 = positions[id] + Vector2(extents[id].x / 2, 0)
				var elbow: float = (from.y + to.y) / 2
				var color: Color = Color("d44958") if id in player.unlocked_achievements else Color("75273a") if parent_id in player.unlocked_achievements else Color("45424a")
				draw_polyline(PackedVector2Array([from, Vector2(from.x, elbow), Vector2(to.x, elbow), to]), color, 3)

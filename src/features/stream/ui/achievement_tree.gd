class_name AchievementTree
extends Control

signal selected(id: String)
var catalog: ContentCatalog
var player: PlayerState
var buttons: Dictionary = {}
var _completion: String = ""
const NODE_SIZE := Vector2(150, 84)
const COLORS: Array[Color] = [Color("8794a1"), Color("d44958"), Color("e4b252"), Color("f06b88")]

func setup(content: ContentCatalog, state: PlayerState) -> void:
	catalog = content
	player = state
	custom_minimum_size = Vector2(1000, 870)
	for id: String in catalog.achievements:
		var definition: AchievementDefinition = catalog.achievements[id]
		var button: Button = SasaUI.button("", func() -> void: selected.emit(id))
		button.position = definition.graph_position
		button.size = NODE_SIZE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.icon = definition.icon
		add_child(button)
		buttons[id] = button
	refresh(true)

func refresh(force: bool = false) -> void:
	var completion: String = str(player.unlocked_achievements)
	if not force and completion == _completion:
		return
	_completion = completion
	for id: String in buttons:
		var definition: AchievementDefinition = catalog.achievements[id]
		var completed: bool = id in player.unlocked_achievements
		var button: Button = buttons[id]
		button.text = ("✓ " if completed else "◇ ") + (definition.display_name if completed or not definition.secret else "?")
		button.set_meta("completed", completed)
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color("301b22") if completed else Color("141419")
		box.border_color = COLORS[definition.tier] if completed else Color("45424a")
		box.set_border_width_all(3 if completed else 2)
		box.set_corner_radius_all(8)
		box.shadow_color = Color(0.8, 0.1, 0.2, 0.25) if completed else Color.TRANSPARENT
		box.shadow_size = 5 if completed else 0
		button.add_theme_stylebox_override("normal", box)
		button.add_theme_stylebox_override("hover", box)
		button.add_theme_color_override("font_color", Color.WHITE if completed else Color("9994a0"))
	queue_redraw()

func _draw() -> void:
	if catalog == null:
		return
	for id: String in catalog.achievements:
		var definition: AchievementDefinition = catalog.achievements[id]
		for parent_id: String in definition.parent_ids:
			if catalog.achievements.has(parent_id):
				var parent: AchievementDefinition = catalog.achievements[parent_id]
				var from: Vector2 = parent.graph_position + Vector2(75, 84)
				var to: Vector2 = definition.graph_position + Vector2(75, 0)
				var elbow: float = (from.y + to.y) / 2
				var color: Color = Color("d44958") if parent_id in player.unlocked_achievements else Color("45424a")
				draw_polyline(PackedVector2Array([from, Vector2(from.x, elbow), Vector2(to.x, elbow), to]), color, 3)

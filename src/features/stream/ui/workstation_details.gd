extends Node2D
## Pixel-aligned native art: one coherent tabletop plane, no mirrored key legends.
func _draw() -> void:
	var surface := PackedVector2Array([Vector2(23, 1), Vector2(279, 1), Vector2(302, 30), Vector2(1, 30)])
	draw_colored_polygon(surface, Color("6d1814"))
	for y: int in range(3, 30, 3):
		var inset: float = 23 - y * 0.72
		draw_line(Vector2(inset, y), Vector2(279 + y * 0.75, y), Color("9b2920") if y % 2 else Color("421411"), 1)
	# Mouse is to the seated character's right (camera left).
	_quad(Vector2(42, 9), Vector2(37, 8), Vector2(20, -7), Color("18151b"))
	_quad(Vector2(55, 10), Vector2(13, 3), Vector2(9, -4), Color("454048"))
	_quad(Vector2(57, 9), Vector2(8, 2), Vector2(5, -2), Color("922c35"))
	# Keyboard plane: its near-user edge faces the character, not the camera.
	var origin := Vector2(100, 16)
	var across := Vector2(79, 13)
	var depth := Vector2(24, -15)
	_quad(origin, across, depth, Color("14151b"))
	draw_line(origin, origin + across, Color("81777a"), 2)
	for row: int in range(4):
		for column: int in range(12):
			var at: Vector2 = origin + across * (0.04 + column * 0.077) + depth * (0.12 + row * 0.2)
			_quad(at.round(), across * 0.055, depth * 0.12, Color("c8b9a0") if row < 3 else Color("9b3540"))
	_quad(origin + across * 0.3 + depth * 0.83, across * 0.42, depth * 0.09, Color("d3bc9a"))

func _quad(origin: Vector2, across: Vector2, depth: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([origin, origin + across, origin + across + depth, origin + depth]), color)

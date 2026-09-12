extends Node2D
## Pixel-aligned native art: one coherent tabletop plane, no mirrored key legends.
func _draw() -> void:
	var surface := PackedVector2Array([Vector2(23, 1), Vector2(279, 1), Vector2(302, 30), Vector2(1, 30)])
	draw_colored_polygon(surface, Color("6d1814"))
	for y: int in range(3, 30, 3):
		var inset: float = 23 - y * 0.72
		draw_line(Vector2(inset, y), Vector2(279 + y * 0.75, y), Color("9b2920") if y % 2 else Color("421411"), 1)
	# Mouse and keyboard: palm edge faces SASA; cables lead away toward monitor.
	_quad(Vector2(66, 4), Vector2(37, 0), Vector2(-8, 21), Color("100f15"))
	_quad(Vector2(67, 5), Vector2(35, 0), Vector2(-7, 19), Color("24202a"))
	draw_polyline(PackedVector2Array([Vector2(80, 21), Vector2(77, 27), Vector2(102, 28)]), Color("0b0c10"), 1)
	draw_colored_polygon(PackedVector2Array([Vector2(80, 6), Vector2(87, 6), Vector2(90, 9), Vector2(88, 17), Vector2(85, 21), Vector2(77, 21), Vector2(75, 18), Vector2(77, 10)]), Color("0b0e15"))
	draw_colored_polygon(PackedVector2Array([Vector2(80, 7), Vector2(86, 7), Vector2(88, 10), Vector2(86, 17), Vector2(78, 17), Vector2(78, 11)]), Color("525663"))
	draw_line(Vector2(78, 17), Vector2(86, 17), Color("252933"), 1)
	draw_line(Vector2(82, 14), Vector2(80, 20), Color("11131a"), 1)
	draw_rect(Rect2(81, 15, 2, 3), Color("d64c63"))
	var origin := Vector2(119, 3)
	var across := Vector2(86, 0)
	var depth := Vector2(-12, 23)
	_quad(origin + Vector2(0, 2), across, depth, Color("090b10"))
	_quad(origin, across, depth, Color("4a4c59"))
	_quad(origin + Vector2(1, 1), across - Vector2(2, 0), depth * 0.9, Color("171a22"))
	for row: int in range(5):
		for column: int in range(14):
			if row == 0 and column in range(3, 9):
				continue
			var at: Vector2 = (origin + across * (0.03 + column * 0.067) + depth * (0.09 + row * 0.17)).round()
			_key(at, Vector2(4, 0), row == 4 or column == 13)
	_key(origin + across * 0.23 + depth * 0.09, Vector2(33, 0), false)
	draw_line(origin + depth, origin + depth + across, Color("8c3048"), 1)
	for x: int in range(3):
		draw_rect(Rect2(origin + across * 0.86 + Vector2(x * 3, 1), Vector2.ONE), Color("ec6d84"))

func _key(at: Vector2, across: Vector2, accent: bool) -> void:
	_quad(at + Vector2(0, 1), across, Vector2(-1, 2), Color("10131c"))
	_quad(at, across, Vector2(-1, 2), Color("a44959") if accent else Color("b4bac5"))
	draw_rect(Rect2(at + Vector2(1, 1), Vector2.ONE), Color("363946"))

func _quad(origin: Vector2, across: Vector2, depth: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([origin, origin + across, origin + across + depth, origin + depth]), color)

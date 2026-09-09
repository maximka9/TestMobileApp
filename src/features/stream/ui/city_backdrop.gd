extends Control
## Small code-native city backdrop, confined to the gameplay stage.

func _draw() -> void:
	draw_rect(Rect2(0, 0, 336, 250), Color("23364d"))
	draw_circle(Vector2(277, 32), 15, Color("f1d6a0"))
	for i: int in range(7):
		var height: float = 75 + (i * 29) % 65
		draw_rect(Rect2(i * 51, 175 - height, 47, height), Color("354b65") if i % 2 == 0 else Color("2b4057"))
		for floor_index: int in range(4):
			for column: int in range(3):
				draw_rect(Rect2(i * 51 + column * 13 + 6, 180 - height + floor_index * 18, 6, 9), Color("d9b776"))
	draw_rect(Rect2(0, 175, 336, 75), Color("454956"))
	draw_rect(Rect2(0, 195, 336, 4), Color("9497a3"))
	for i: int in range(6):
		draw_rect(Rect2(i * 65, 235, 35, 3), Color("d3bd8b"))

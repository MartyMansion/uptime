extends Node2D
## LifeOS as a paper cut-out: a smug phone with a cardboard smile. Drawn into the portrait slot.
const INK := Color(0.12, 0.1, 0.1)
func _draw() -> void:
	draw_rect(Rect2(20, 6, 56, 84), Color(0.3, 0.34, 0.42)); draw_rect(Rect2(20, 6, 56, 84), INK, false, 3)
	draw_rect(Rect2(26, 14, 44, 62), Color(0.62, 0.86, 0.95)); draw_rect(Rect2(26, 14, 44, 62), INK, false, 2)
	draw_circle(Vector2(38, 36), 4, INK); draw_circle(Vector2(58, 36), 4, INK)
	draw_arc(Vector2(48, 46), 12, 0.3, PI - 0.3, 10, INK, 3)
	draw_circle(Vector2(48, 84), 3, Color(0.85, 0.85, 0.8))

class_name BBHoldRing
extends Node2D
## Visible feedback for the grown-ups hold gesture.

var ratio := 0.0


func _draw() -> void:
	if ratio <= 0.01:
		return
	draw_arc(Vector2.ZERO, 46.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(ratio, 0.0, 1.0), 40,
		Color(1, 1, 1, 0.9), 9.0, true)
	draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 40, Color(1, 1, 1, 0.25), 4.0, true)

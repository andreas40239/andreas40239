class_name BBPearlIcon
extends Node2D
## The soft bubble-shaped pearl icon used by the HUD counter.

func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 46.0, Color(0.85, 0.96, 1.0, 0.55))
	draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 26, Color(1, 1, 1, 0.85), 5.0, true)
	BBDraw.ellipse(self, Vector2.ZERO, 26.0, 26.0, Color(0.99, 0.97, 1.0), 0.0, 20)
	BBDraw.ellipse(self, Vector2(-8, -9), 10.0, 8.0, Color.WHITE, -0.5, 12)

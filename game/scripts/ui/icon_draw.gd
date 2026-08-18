extends Control

## Draws a simple vector icon (spike or claw) sized to fit this control's
## rect, matching the game's vector-shape art style instead of needing an
## image asset.

@export var icon_type: String = "spike"
@export var icon_color: Color = Color(0.35, 0.65, 0.35)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var s: Vector2 = size
	var c: Vector2 = s * 0.5
	match icon_type:
		"spike":
			draw_colored_polygon(PackedVector2Array([
				Vector2(c.x, s.y * 0.08),
				Vector2(s.x * 0.82, s.y * 0.92),
				Vector2(s.x * 0.18, s.y * 0.92),
			]), icon_color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - s.x * 0.16, s.y * 0.55),
				Vector2(c.x, s.y * 0.18),
				Vector2(c.x + s.x * 0.04, s.y * 0.55),
			]), icon_color.lightened(0.3))
		"claw":
			for i in 3:
				var off: float = (i - 1) * s.x * 0.24
				var base := Vector2(c.x + off, s.y * 0.88)
				var tip := Vector2(c.x + off * 1.5, s.y * 0.08)
				var mid := Vector2(c.x + off * 1.25, s.y * 0.42)
				var w: float = s.x * 0.075
				draw_colored_polygon(PackedVector2Array([
					base + Vector2(-w, 0), base + Vector2(w, 0),
					mid + Vector2(w * 0.5, 0), tip, mid + Vector2(-w * 0.5, 0),
				]), icon_color)

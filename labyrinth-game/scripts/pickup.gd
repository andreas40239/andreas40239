extends Node2D
## Einsammelbare Gegenstaende (Power-Ups, Kristalle, Traenke).

var game: Node
var kind := "potion"
var anim := 0.0


func _ready() -> void:
	anim = randf() * 5.0


func update(dt: float) -> void:
	anim += dt
	queue_redraw()


func _draw() -> void:
	var bob := sin(anim * 3.0) * 3.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(0, 30), 10, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2(0, bob - 4), 0.0, Vector2.ONE)
	var glow_c := Color(1, 1, 1)
	match kind:
		"fire": glow_c = Color(1, 0.5, 0.1)
		"ice": glow_c = Color(0.5, 0.85, 1)
		"heart": glow_c = Color(1, 0.3, 0.4)
		"crystal": glow_c = Color(0.7, 0.5, 1.0)
		"potion": glow_c = Color(1, 0.4, 0.5)
	var pulse := 0.25 + 0.12 * sin(anim * 5.0)
	draw_circle(Vector2.ZERO, 18, Color(glow_c, pulse * 0.5))
	draw_circle(Vector2.ZERO, 12, Color(glow_c, pulse))
	match kind:
		"fire", "ice":
			var blade := Color(1, 0.55, 0.15) if kind == "fire" else Color(0.55, 0.9, 1.0)
			draw_line(Vector2(-9, 9), Vector2(9, -13), blade, 4.0)
			draw_line(Vector2(-9, 9), Vector2(9, -13), Color(1, 1, 1, 0.6), 1.5)
			draw_line(Vector2(-12, 3), Vector2(-3, 12), Color(0.25, 0.25, 0.3), 3.0)
			draw_line(Vector2(-9, 9), Vector2(-13, 13), Color(0.4, 0.25, 0.1), 3.0)
			if kind == "fire":
				for i in 3:
					var a := anim * 6.0 + i * 2.0
					draw_circle(Vector2(3 + sin(a) * 4, -6 + cos(a) * 4 - i * 2), 2.5, Color(1, 0.8, 0.2, 0.8))
			else:
				for i in 3:
					var a := anim * 2.0 + i * TAU / 3.0
					draw_circle(Vector2(cos(a), sin(a)) * 14.0, 1.8, Color(0.9, 1, 1))
		"heart":
			_heart(Vector2.ZERO, 10.0, Color(0.95, 0.2, 0.3))
			draw_circle(Vector2(-4, -4), 2, Color(1, 1, 1, 0.7))
		"potion":
			draw_circle(Vector2(0, 3), 7, Color(0.9, 0.2, 0.35))
			draw_rect(Rect2(-2.5, -8, 5, 6), Color(0.8, 0.85, 0.9))
			draw_rect(Rect2(-3.5, -10, 7, 3), Color(0.5, 0.3, 0.15))
		"crystal":
			var pts := PackedVector2Array([Vector2(0, -14), Vector2(8, -2), Vector2(0, 14), Vector2(-8, -2)])
			draw_colored_polygon(pts, Color(0.65, 0.45, 1.0))
			draw_colored_polygon(PackedVector2Array([Vector2(0, -14), Vector2(8, -2), Vector2(0, 0)]), Color(0.85, 0.75, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _heart(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-s * 0.45, -s * 0.2), s * 0.52, col)
	draw_circle(c + Vector2(s * 0.45, -s * 0.2), s * 0.52, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.95, 0), c + Vector2(s * 0.95, 0), c + Vector2(0, s)]), col)

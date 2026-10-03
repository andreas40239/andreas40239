class_name SceneryBackground
extends Control
## Fröhlicher Hintergrund für Titel und Weltkarte: Himmel, Sonne, Wolken, Hügel, Dorf.

var show_village := true
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var sky_top := Color("7ec8f2")
	var sky_bottom := Color("d6f0ff")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.7), Vector2(0, h * 0.7)]),
		PackedColorArray([sky_top, sky_top, sky_bottom, sky_bottom]))
	# Sonne mit Strahlen
	var sc := Vector2(w * 0.12, h * 0.16)
	for i in 12:
		var a := _t * 0.15 + TAU * i / 12.0
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([sc + d * 70 + n * 16, sc + d * 140, sc + d * 70 - n * 16]), Color(1, 0.86, 0.3, 0.6))
	draw_circle(sc, 70, Color("ffd84d"))
	draw_circle(sc + Vector2(-20, -10), 8, Color("6b4a2f"))
	draw_circle(sc + Vector2(20, -10), 8, Color("6b4a2f"))
	draw_arc(sc + Vector2(0, 8), 26, 0.3, PI - 0.3, 12, Color("6b4a2f"), 6.0, true)
	# Wolken
	for i in 4:
		var x := fmod(_t * (12.0 + i * 5.0) + i * 600.0, w + 400.0) - 200.0
		var y := h * (0.1 + 0.08 * i)
		_cloud(Vector2(x, y), 0.8 + 0.2 * (i % 2))
	# Hügel
	Icons.ellipse(self, Vector2(w * 0.2, h * 0.78), w * 0.45, h * 0.24, Color("8fd16a"))
	Icons.ellipse(self, Vector2(w * 0.85, h * 0.8), w * 0.5, h * 0.26, Color("7cc35c"))
	if show_village:
		_house(Vector2(w * 0.8, h * 0.6), Color("ffb36b"), Color("d9534f"))
		_house(Vector2(w * 0.89, h * 0.62), Color("fff1c7"), Color("4f8fe8"))
		_house(Vector2(w * 0.72, h * 0.64), Color("ffd6e8"), Color("9b59d0"))
		# Windmühle
		var mc := Vector2(w * 0.94, h * 0.5)
		draw_colored_polygon(PackedVector2Array([mc + Vector2(-30, 120), mc + Vector2(-16, 0), mc + Vector2(16, 0), mc + Vector2(30, 120)]), Color("f3e3c3"))
		for i in 4:
			var a := _t * 0.8 + i * PI * 0.5
			var d := Vector2(cos(a), sin(a))
			draw_line(mc, mc + d * 90, Color("a8693a"), 10.0, true)
			draw_colored_polygon(PackedVector2Array([mc + d * 30, mc + d * 90, mc + d * 90 + Vector2(-d.y, d.x) * 24, mc + d * 30 + Vector2(-d.y, d.x) * 24]), Color(1, 1, 1, 0.85))
		draw_circle(mc, 10, Color("6b4a2f"))
	draw_rect(Rect2(0, h * 0.82, w, h * 0.18 + 2), Color("6bbf59"))
	Icons.ellipse(self, Vector2(w * 0.5, h * 0.84), w * 0.7, h * 0.07, Color("79c865"))


func _cloud(p: Vector2, s: float) -> void:
	var c := Color(1, 1, 1, 0.92)
	draw_circle(p, 46 * s, c)
	draw_circle(p + Vector2(50, 10) * s, 38 * s, c)
	draw_circle(p + Vector2(-50, 12) * s, 34 * s, c)
	draw_circle(p + Vector2(10, 24) * s, 40 * s, c)


func _house(p: Vector2, wall: Color, roof: Color) -> void:
	draw_rect(Rect2(p + Vector2(-50, -70), Vector2(100, 70)), wall)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-64, -66), p + Vector2(0, -126), p + Vector2(64, -66)]), roof)
	Icons.rounded_rect(self, Rect2(p + Vector2(-12, -42), Vector2(24, 42)), 10, Color("8d5f3a"))
	draw_rect(Rect2(p + Vector2(20, -56), Vector2(20, 18)), Color("bfe6ff"))

class_name StarRow
extends Control
## Drei Sterne (gefüllt/leer), optional mit Einblend-Animation.

signal star_shown(index: int)

var count := 0
var star_size := 48.0
var animate := false
var _t := 0.0
var _shown := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(animate)
	if not animate:
		_t = 99.0


func _process(dt: float) -> void:
	_t += dt
	var n := clampi(int((_t - 0.35) / 0.4) + 1, 0, count) if _t > 0.35 else 0
	if n != _shown:
		_shown = n
		star_shown.emit(n)
	queue_redraw()
	if _t > 3.0:
		set_process(false)


static func _star_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.46
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


func _draw() -> void:
	var gap := star_size * 1.15
	var x0 := size.x * 0.5 - gap
	for i in 3:
		var c := Vector2(x0 + i * gap, size.y * 0.5 + (0.0 if i == 1 else star_size * 0.08))
		var r := star_size * (0.56 if i == 1 else 0.48)
		draw_colored_polygon(_star_points(c + Vector2(0, 3), r), Color(0, 0, 0, 0.3))
		draw_colored_polygon(_star_points(c, r), Color(0.24, 0.3, 0.37))
		if i < count:
			var k := 1.0
			if animate:
				k = clampf((_t - 0.35 - i * 0.4) / 0.25, 0.0, 1.0)
				if k <= 0.0:
					continue
				k = 1.0 + 0.35 * sin(k * PI) if k < 1.0 else 1.0
			draw_colored_polygon(_star_points(c, r * k), Color("ffcf33"))
			draw_colored_polygon(_star_points(c - Vector2(0, r * 0.06), r * k * 0.62), Color("ffe680"))

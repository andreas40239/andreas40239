# Windy the cloud: a friendly face that blows gusts to show wind (GDD 6.2).
class_name WindCloud
extends Control

var wind := 0.0
var _t := 0.0
var _spin := 0.0

func set_wind(w: float) -> void:
	wind = w
	queue_redraw()

func announce_change(w: float) -> void:
	wind = w
	_spin = 1.0
	A.play("wind", clampf(0.8 + absf(w) / 40.0, 0.8, 1.6))

func _process(delta: float) -> void:
	_t += delta
	if _spin > 0.0:
		_spin = maxf(0.0, _spin - delta * 1.2)
	queue_redraw()

func _draw() -> void:
	var c := Vector2(size.x * 0.5, 44.0)
	var strength: float = absf(wind)
	var dirv: float = signf(wind)
	var puff: float = 1.0 + (0.06 + 0.05 * (strength / 30.0)) * sin(_t * (2.0 + strength * 0.12))
	var rot: float = _spin * TAU
	draw_set_transform(c, rot, Vector2(puff, 2.0 - puff))
	# Cloud puffs.
	var cc := Color(1, 1, 1, 0.97)
	draw_circle(Vector2(-30, 4), 20.0, cc)
	draw_circle(Vector2(0, -6), 26.0, cc)
	draw_circle(Vector2(30, 4), 20.0, cc)
	draw_circle(Vector2(0, 10), 22.0, cc)
	# Face.
	var look := Vector2(dirv * 3.0, 0)
	for ex in [-9.0, 9.0]:
		draw_circle(Vector2(ex, -6), 4.5, Color(0.25, 0.3, 0.45))
		draw_circle(Vector2(ex, -6) + look * 0.5, 1.8, Color.WHITE)
	if strength > 0.5:
		# Puffed cheeks blowing.
		draw_circle(Vector2(dirv * 14.0, 4), 6.0, Color(1.0, 0.8, 0.8))
		draw_arc(Vector2(dirv * 20.0, 4), 4.0, -PI / 2.0, PI / 2.0, 8, Color(0.25, 0.3, 0.45), 2.0)
	else:
		draw_arc(Vector2(0, 4), 6.0, 0.4, PI - 0.4, 10, Color(0.25, 0.3, 0.45), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Gust streaks, speed proportional to strength.
	if strength > 0.5 and not G.settings["wind_off"]:
		var speed: float = 40.0 + strength * 9.0
		for i in range(3):
			var phase: float = fposmod(_t * speed + float(i) * 90.0, 260.0)
			var x: float = c.x + dirv * (55.0 + phase) - dirv * 30.0
			var y: float = 20.0 + float(i) * 22.0
			var a: float = clampf(1.2 - phase / 260.0, 0.0, 0.8)
			draw_line(Vector2(x, y), Vector2(x + dirv * 26.0, y), Color(1, 1, 1, a), 4.0)
			draw_arc(Vector2(x + dirv * 26.0, y - 5.0), 5.0, 0, PI, 8, Color(1, 1, 1, a * 0.7), 3.0)
	# Wind strength number + arrow.
	var f := ThemeDB.fallback_font
	var txt := "0"
	if strength > 0.5:
		txt = str(int(strength))
	draw_string(f, c + Vector2(58, 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	if strength > 0.5:
		var ay := c.y + 26.0
		var ax := c.x + 62.0
		draw_line(Vector2(ax, ay), Vector2(ax + dirv * 22.0, ay), Color.WHITE, 4.0)
		var tip := Vector2(ax + dirv * 30.0, ay)
		draw_colored_polygon(PackedVector2Array([
			tip, Vector2(ax + dirv * 20.0, ay - 7.0), Vector2(ax + dirv * 20.0, ay + 7.0)]), Color.WHITE)

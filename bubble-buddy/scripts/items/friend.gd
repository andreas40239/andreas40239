class_name BBFriend
extends Node2D
## A freed baby sea creature. Follows Finley for ten seconds, waves, and swims
## happily off the top of the screen.

const FOLLOW_TIME := 10.0

var species := "turtle"
var golden := false
var slot := 0
var _life := 0.0
var _target := Vector2.ZERO
var _leaving := false
var _wave := 0.0
var alive := true


func _ready() -> void:
	z_index = 18


func tick(delta: float, leader: Vector2) -> void:
	_life += delta
	if _leaving:
		_wave += delta
		position.y -= 260.0 * delta
		position.x += sin(_wave * 3.0) * 60.0 * delta
		if position.y < -200.0:
			alive = false
	else:
		if _life >= FOLLOW_TIME:
			_leaving = true
			Sound.play_varied("giggle", 0.12, -6.0)
		# Trail behind the leader in a gentle queue.
		_target = leader + Vector2(-90.0 - slot * 12.0, 70.0 + slot * 46.0)
		position = position.lerp(_target, clampf(delta * 3.4, 0.0, 1.0))
	queue_redraw()


func remaining() -> float:
	return maxf(FOLLOW_TIME - _life, 0.0)


func _draw() -> void:
	var col := _color()
	var bob := sin(_life * 4.0) * 4.0
	var waving := _leaving

	match species:
		"turtle":
			_draw_turtle(col, bob, waving)
		"seahorse":
			_draw_seahorse(col, bob, waving)
		"octopus":
			_draw_octopus(col, bob, waving)
		_:
			_draw_ray(col, bob, waving)

	if golden:
		for i in 3:
			var a := _life * 2.0 + TAU * float(i) / 3.0
			BBDraw.sparkle(self, Vector2(cos(a), sin(a)) * 48.0, 12.0, Color(1, 0.96, 0.7, 0.9), a)


func _color() -> Color:
	match species:
		"turtle": return Color(0.45, 0.78, 0.48)
		"seahorse": return Color(0.98, 0.72, 0.42)
		"octopus": return Color(0.82, 0.52, 0.86)
		_: return Color(0.55, 0.78, 0.94)


func _face(center: Vector2, r: float) -> void:
	BBDraw.eye(self, center + Vector2(-r * 0.3, -r * 0.1), r * 0.22, Vector2(0.2, 0.1))
	BBDraw.eye(self, center + Vector2(r * 0.3, -r * 0.1), r * 0.22, Vector2(0.2, 0.1))
	BBDraw.smile(self, center + Vector2(0, r * 0.28), r * 0.3, Color(0.3, 0.26, 0.2), 3.5)


func _flipper(at: Vector2, angle: float, size: float, col: Color) -> void:
	BBDraw.ellipse(self, at, size, size * 0.5, col.darkened(0.1), angle, 14)


func _draw_turtle(col: Color, bob: float, waving: bool) -> void:
	var c := Vector2(0, bob)
	var wave_a: float = -0.9 if waving else sin(_life * 5.0) * 0.4
	_flipper(c + Vector2(-26, 6), 0.6, 18.0, col)
	_flipper(c + Vector2(26, 6), wave_a, 18.0, col)
	BBDraw.ellipse(self, c, 32.0, 26.0, Color(0.36, 0.60, 0.38), 0.0, 24)
	for i in 3:
		BBDraw.ellipse(self, c + Vector2((i - 1) * 16.0, -2.0), 8.0, 8.0, Color(0.52, 0.76, 0.5), 0.0, 12)
	BBDraw.ellipse(self, c + Vector2(0, -26), 17.0, 15.0, col, 0.0, 18)
	_face(c + Vector2(0, -26), 17.0)


func _draw_seahorse(col: Color, bob: float, waving: bool) -> void:
	var c := Vector2(0, bob)
	var curl := PackedVector2Array()
	for i in 9:
		var k := float(i) / 8.0
		var a := k * PI * 1.4 + (0.4 if waving else sin(_life * 3.0) * 0.2)
		curl.append(c + Vector2(sin(a) * 16.0 * (1.0 - k * 0.5), 16.0 + k * 32.0))
	draw_polyline(curl, col, 16.0, true)
	BBDraw.ellipse(self, c + Vector2(0, 2), 17.0, 22.0, col, 0.0, 20)
	BBDraw.ellipse(self, c + Vector2(6, -22), 15.0, 13.0, col, -0.3, 18)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(16, -24), c + Vector2(34, -20), c + Vector2(16, -14),
	]), col.darkened(0.08))
	# Crest.
	for i in 3:
		BBDraw.ellipse(self, c + Vector2(-4 - i * 5, -32 + i * 7), 6.0, 4.0, col.darkened(0.15), 0.6, 10)
	_face(c + Vector2(4, -22), 14.0)


func _draw_octopus(col: Color, bob: float, waving: bool) -> void:
	var c := Vector2(0, bob)
	for i in 6:
		var base := c + Vector2((float(i) - 2.5) * 10.0, 18.0)
		var pts := PackedVector2Array()
		for j in 6:
			var k := float(j) / 5.0
			var swing := (1.2 if waving and i == 5 else sin(_life * 4.0 + i) * 0.5)
			pts.append(base + Vector2(sin(k * 3.0 + swing) * 14.0 * k, 26.0 * k))
		draw_polyline(pts, col.darkened(0.06), 8.0, true)
	BBDraw.blob(self, c, 28.0, col, _life * 2.0, 3, 0.05, 26)
	_face(c, 28.0)


func _draw_ray(col: Color, bob: float, waving: bool) -> void:
	var c := Vector2(0, bob)
	var flap := (0.8 if waving else sin(_life * 4.5) * 0.5)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -12),
		c + Vector2(-46, 10 - flap * 14.0),
		c + Vector2(-14, 22),
		c + Vector2(14, 22),
		c + Vector2(46, 10 - flap * 14.0),
	]), col)
	draw_line(c + Vector2(0, 20), c + Vector2(0, 48), col.darkened(0.1), 6.0, true)
	_face(c + Vector2(0, -2), 20.0)

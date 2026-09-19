class_name BBPowerUp
extends BBEntity
## The three power-ups, sharing one entity so spawning stays simple.

enum Type { SHIELD, CURRENT, RAINBOW }

var type: int = Type.SHIELD


func _ready() -> void:
	kind = Kind.POWERUP
	radius = 56.0 if type != Type.CURRENT else 88.0


func on_touch(game, _player) -> void:
	game.collect_power_up(self)


func label() -> String:
	match type:
		Type.SHIELD: return "Bubble Shield!"
		Type.CURRENT: return "Zoom!"
		_: return "Rainbow Rush!"


func tint() -> Color:
	match type:
		Type.SHIELD: return Color(0.72, 0.94, 1.0)
		Type.CURRENT: return Color(0.62, 0.95, 0.82)
		_: return BBDraw.rainbow_color(age * 0.5)


func _draw() -> void:
	match type:
		Type.SHIELD:
			_draw_shield()
		Type.CURRENT:
			_draw_current()
		_:
			_draw_rainbow()


func _draw_shield() -> void:
	var pulse := 1.0 + sin(age * 3.0) * 0.07
	draw_circle(Vector2.ZERO, 74.0 * pulse, Color(0.75, 0.95, 1.0, 0.18))
	draw_arc(Vector2.ZERO, 52.0 * pulse, 0.0, TAU, 30, Color(1, 1, 1, 0.85), 6.0, true)
	draw_circle(Vector2(-16, -18), 12.0, Color(1, 1, 1, 0.8))
	# A small fish inside makes the effect legible without words.
	BBDraw.ellipse(self, Vector2(2, 4), 20.0, 14.0, Color(1.0, 0.6, 0.24), 0.0, 18)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, 4), Vector2(-32, -8), Vector2(-32, 16),
	]), Color(1.0, 0.6, 0.24))
	BBDraw.sparkle(self, Vector2(38, -38), 14.0, Color(1, 1, 1, 0.9), age)


func _draw_current() -> void:
	# A glowing upward stream: three chevrons plus flowing lines.
	var col := Color(0.62, 0.96, 0.85)
	draw_circle(Vector2.ZERO, 96.0, Color(col.r, col.g, col.b, 0.13))
	for i in 3:
		var y := 34.0 - i * 34.0 - fposmod(age * 70.0, 34.0)
		draw_polyline(PackedVector2Array([
			Vector2(-44, y + 24), Vector2(0, y), Vector2(44, y + 24),
		]), Color(col.r, col.g, col.b, 0.9 - i * 0.22), 9.0, true)
	for s in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for j in 9:
			var k := float(j) / 8.0
			pts.append(Vector2(s * (56.0 + sin(k * 6.0 + age * 3.0) * 10.0), 70.0 - k * 150.0))
		draw_polyline(pts, Color(col.r, col.g, col.b, 0.5), 6.0, true)
	BBDraw.sparkle(self, Vector2(0, -78), 16.0, Color(1, 1, 1, 0.9), age * 1.4)


func _draw_rainbow() -> void:
	var r := 54.0 + sin(age * 3.4) * 4.0
	for i in 6:
		var col := BBDraw.rainbow_color(age * 0.4 + float(i) / 6.0)
		col.a = 0.85
		draw_arc(Vector2.ZERO, r - i * 7.0, PI * 0.1, PI * 0.9, 26, col, 7.0, true)
	draw_circle(Vector2.ZERO, r * 1.5, Color(1, 1, 1, 0.12))
	for i in 3:
		var a := age * 2.0 + TAU * float(i) / 3.0
		BBDraw.sparkle(self, Vector2(cos(a), sin(a)) * r * 1.15, 15.0, Color(1, 1, 1, 0.9), a)

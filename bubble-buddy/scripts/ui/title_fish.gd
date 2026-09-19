class_name BBTitleFish
extends Node2D
## Finley bobbing on the title screen, blowing the occasional bubble.

var _t := 0.0
var _bubbles: Array = []


func _process(delta: float) -> void:
	_t += delta
	if randf() < delta * 1.4:
		_bubbles.append({"p": Vector2(96, 10), "r": randf_range(9.0, 20.0), "v": randf_range(60.0, 110.0), "x": randf_range(-20.0, 30.0)})
	for b in _bubbles:
		b["p"] += Vector2(sin(_t * 2.0 + b["x"]) * 22.0 * delta + b["x"] * delta * 0.4, -b["v"] * delta)
	_bubbles = _bubbles.filter(func(b): return b["p"].y > -520.0)
	queue_redraw()


func _draw() -> void:
	for b in _bubbles:
		var k: float = clampf(1.0 + b["p"].y / 520.0, 0.0, 1.0)
		draw_circle(b["p"], b["r"], Color(1, 1, 1, 0.22 * k))
		draw_arc(b["p"], b["r"], 0.0, TAU, 16, Color(1, 1, 1, 0.5 * k), 3.0, true)

	var bob := sin(_t * 1.6) * 16.0
	var tilt := sin(_t * 0.9) * 0.08
	draw_set_transform(Vector2(0, bob), tilt, Vector2.ONE * 1.6)

	var body := Color(1.0, 0.54, 0.16)
	var wig := sin(_t * 6.0) * 0.5
	# Tail.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-52, -8), Vector2(-96, -38 + wig * 20), Vector2(-84, 0), Vector2(-96, 38 + wig * 20), Vector2(-52, 8),
	]), body.darkened(0.06))
	# Fins.
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -42), Vector2(-34, -72 + wig * 8), Vector2(20, -40)]), body.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(-4, 42), Vector2(-26, 64 - wig * 6), Vector2(18, 40)]), body.darkened(0.1))
	# Body.
	BBDraw.ellipse(self, Vector2.ZERO, 62.0, 46.0, body, 0.0, 34)
	BBDraw.ellipse(self, Vector2(6, -13), 46.0, 19.0, Color(1.0, 0.68, 0.32), 0.0, 28)
	for x in [-12.0, 26.0]:
		var h := 46.0 * sqrt(maxf(0.0, 1.0 - pow(x / 62.0, 2.0)))
		var pts := PackedVector2Array()
		for i in 10:
			var k: float = lerpf(-1.0, 1.0, float(i) / 9.0)
			pts.append(Vector2(x + sin(k * 1.4) * 5.0 - 13.0, h * k))
		for i in 10:
			var k: float = lerpf(1.0, -1.0, float(i) / 9.0)
			pts.append(Vector2(x + sin(k * 1.4) * 5.0 + 13.0, h * k))
		draw_colored_polygon(pts, Color(1, 1, 1, 0.95))
	# Face.
	BBDraw.eye(self, Vector2(28, -8), 15.0, Vector2(0.3, 0.1), maxf(0.0, sin(_t * 0.7) * 6.0 - 5.0))
	BBDraw.ellipse(self, Vector2(57, 12), 9.0, 10.0, Color(0.85, 0.35, 0.28), 0.0, 14)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

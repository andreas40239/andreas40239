extends Node2D
## Partikel (Funken, Splitter, Explosionen).

var parts: Array = []  # [pos, vel, life, max_life, color, size]


func burst(p: Vector2, c: Color, n: int, speed: float) -> void:
	for i in n:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * speed
		var life := randf_range(0.3, 0.8)
		parts.append([p, v, life, life, c, randf_range(1.5, 3.5)])
	if parts.size() > 600:
		parts = parts.slice(parts.size() - 600)


func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	var keep: Array = []
	for pt in parts:
		pt[2] -= dt
		if pt[2] > 0.0:
			pt[0] += pt[1] * dt
			pt[1] *= 1.0 - 3.0 * dt
			keep.append(pt)
	parts = keep
	queue_redraw()


func _draw() -> void:
	for pt in parts:
		var k: float = pt[2] / pt[3]
		draw_circle(pt[0], pt[5] * (0.5 + 0.5 * k), Color(pt[4], k))

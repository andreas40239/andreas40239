# Procedural static terrain (GDD sections 5 & 13). Pure heightmap, no physics bodies.
class_name Terrain
extends Node2D

const WORLD_W := 2400.0
const STEP := 8.0
const BOTTOM_Y := 1100.0

var hmap := PackedFloat32Array()
var spawn_points: Array = []
var rocks: Array = []
var flowers: Array = []

func generate(level: int, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var n := int(WORLD_W / STEP) + 1
	hmap.resize(n)
	var base_y := 540.0
	# Height variation grows every 5 levels (GDD 13.1), capped for playability.
	var amp := 50.0 + minf(float(level), 30.0) * 5.0
	var phases := []
	var freqs := [1.1, 2.3, 4.7, 7.9]
	var amps := [1.0, 0.5, 0.22, 0.1]
	for i in range(4):
		phases.append(rng.randf_range(0.0, TAU))
	for i in range(n):
		var x := float(i) / float(n - 1)
		var h := 0.0
		for o in range(4):
			h += sin(x * TAU * freqs[o] + phases[o]) * amps[o]
		hmap[i] = base_y - h * amp
	# Four flat spawn platforms, at least 200 px apart (GDD 13.1).
	spawn_points.clear()
	var seg := WORLD_W / 4.0
	for k in range(4):
		var sx := seg * k + rng.randf_range(seg * 0.28, seg * 0.72)
		var ci := int(sx / STEP)
		var half := 8  # flatten ~64 px each side
		var y := hmap[clampi(ci, half, n - 1 - half)]
		for j in range(-half, half + 1):
			var idx := clampi(ci + j, 0, n - 1)
			hmap[idx] = y
		spawn_points.append(Vector2(sx, y))
	# Decorations.
	rocks.clear()
	flowers.clear()
	for i in range(14):
		var rx := rng.randf_range(40.0, WORLD_W - 40.0)
		rocks.append(Vector3(rx, ground_y(rx), rng.randf_range(5.0, 14.0)))
	for i in range(26):
		var fx := rng.randf_range(20.0, WORLD_W - 20.0)
		flowers.append(Vector3(fx, ground_y(fx), float(rng.randi_range(0, 2))))
	queue_redraw()

func ground_y(x: float) -> float:
	var fx: float = clampf(x, 0.0, WORLD_W) / STEP
	var i := int(fx)
	var n := hmap.size()
	if i >= n - 1:
		return hmap[n - 1]
	var frac := fx - float(i)
	return lerpf(hmap[i], hmap[i + 1], frac)

func _draw() -> void:
	if hmap.is_empty():
		return
	var n := hmap.size()
	# Dirt body.
	var poly := PackedVector2Array()
	poly.append(Vector2(0, BOTTOM_Y))
	for i in range(n):
		poly.append(Vector2(i * STEP, hmap[i]))
	poly.append(Vector2(WORLD_W, BOTTOM_Y))
	draw_colored_polygon(poly, Color(0.55, 0.38, 0.24))
	# Slightly darker lower dirt band for depth.
	var poly2 := PackedVector2Array()
	poly2.append(Vector2(0, BOTTOM_Y))
	for i in range(n):
		poly2.append(Vector2(i * STEP, hmap[i] + 90.0))
	poly2.append(Vector2(WORLD_W, BOTTOM_Y))
	draw_colored_polygon(poly2, Color(0.47, 0.31, 0.19))
	# Grass strip.
	var grass := PackedVector2Array()
	for i in range(n):
		grass.append(Vector2(i * STEP, hmap[i] - 2.0))
	for i in range(n - 1, -1, -1):
		grass.append(Vector2(i * STEP, hmap[i] + 16.0))
	draw_colored_polygon(grass, Color(0.42, 0.75, 0.33))
	# Rocks.
	for r in rocks:
		draw_circle(Vector2(r.x, r.y - r.z * 0.35), r.z, Color(0.62, 0.62, 0.66))
		draw_circle(Vector2(r.x - r.z * 0.3, r.y - r.z * 0.5), r.z * 0.55, Color(0.72, 0.72, 0.76))
	# Flowers.
	var petal := [Color(1.0, 0.7, 0.8), Color(1.0, 0.9, 0.4), Color(0.8, 0.7, 1.0)]
	for f in flowers:
		var base := Vector2(f.x, f.y)
		draw_line(base, base + Vector2(0, -10), Color(0.25, 0.55, 0.25), 2.0)
		draw_circle(base + Vector2(0, -12), 4.5, petal[int(f.z)])
		draw_circle(base + Vector2(0, -12), 2.0, Color(1.0, 0.85, 0.3))

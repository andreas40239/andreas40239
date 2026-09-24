# Procedural static terrain (GDD sections 5 & 13). Pure heightmap, no physics bodies.
class_name Terrain
extends Node2D

const WORLD_W := 2400.0
const STEP := 8.0
const BOTTOM_Y := 1100.0

# Battlefields. Map 0 is the procedural rolling hills the levels scale up;
# the others are hand-shaped, harder layouts with their own look.
const MAPS := [
	{"name": "Rolling Hills", "deco": "flowers",
		"sky_top": Color(0.45, 0.75, 0.98), "sky_bot": Color(0.72, 0.90, 1.0),
		"far": Color(0.62, 0.78, 0.92), "near": Color(0.55, 0.8, 0.62),
		"top": Color(0.42, 0.75, 0.33), "dirt": Color(0.55, 0.38, 0.24),
		"deep": Color(0.47, 0.31, 0.19), "rock": Color(0.62, 0.62, 0.66)},
	{"name": "Snowy Peak", "deco": "pines",
		"sky_top": Color(0.52, 0.72, 0.95), "sky_bot": Color(0.86, 0.93, 1.0),
		"far": Color(0.78, 0.85, 0.95), "near": Color(0.86, 0.91, 0.97),
		"top": Color(0.97, 0.98, 1.0), "dirt": Color(0.56, 0.6, 0.7),
		"deep": Color(0.45, 0.49, 0.6), "rock": Color(0.7, 0.73, 0.8)},
	{"name": "Desert Canyon", "deco": "cacti",
		"sky_top": Color(0.98, 0.72, 0.45), "sky_bot": Color(1.0, 0.92, 0.72),
		"far": Color(0.94, 0.72, 0.52), "near": Color(0.9, 0.62, 0.42),
		"top": Color(0.96, 0.8, 0.48), "dirt": Color(0.86, 0.55, 0.32),
		"deep": Color(0.73, 0.42, 0.25), "rock": Color(0.78, 0.5, 0.36)},
	{"name": "Rocky Towers", "deco": "crystals",
		"sky_top": Color(0.5, 0.5, 0.86), "sky_bot": Color(0.98, 0.78, 0.74),
		"far": Color(0.62, 0.56, 0.82), "near": Color(0.58, 0.52, 0.74),
		"top": Color(0.46, 0.72, 0.42), "dirt": Color(0.52, 0.47, 0.5),
		"deep": Color(0.41, 0.37, 0.42), "rock": Color(0.66, 0.63, 0.7)},
]

# Where the four tanks start on each designed map, as fractions of the width.
# Every pair is within reach of a full-power shot over the obstacles between
# them (test/maps_reach.gd checks this).
const SPAWNS := [
	[],
	[0.10, 0.34, 0.66, 0.90],
	[0.12, 0.43, 0.57, 0.88],
	[0.10, 0.37, 0.63, 0.90],
]

var map_id := 0
var hmap := PackedFloat32Array()
var spawn_points: Array = []
var rocks: Array = []
var flowers: Array = []   # decorations: Vector3(x, y, variant)

static func theme(id: int) -> Dictionary:
	return MAPS[clampi(id, 0, MAPS.size() - 1)]

static func _smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

# 1 on a flat-topped plateau centred at c, falling off over `edge` each side.
static func _mesa(x: float, c: float, halfw: float, edge: float) -> float:
	return _smooth(c - halfw - edge, c - halfw, x) - _smooth(c + halfw, c + halfw + edge, x)

# Ground height (px, smaller = higher) at x in 0..1 for a designed map.
static func designed_height(id: int, x: float) -> float:
	match id:
		1:  # Snowy Peak: one big mountain in the middle, foothills either side.
			return 640.0 - 390.0 * exp(-pow((x - 0.5) / 0.12, 2.0)) \
					- 80.0 * exp(-pow((x - 0.22) / 0.05, 2.0)) \
					- 70.0 * exp(-pow((x - 0.78) / 0.05, 2.0)) \
					- 14.0 * sin(x * TAU * 5.0 + 0.7)
		2:  # Desert Canyon: high mesas, a deep canyon, a rock pillar in it.
			var y := 400.0 + 440.0 * (_smooth(0.29, 0.36, x) - _smooth(0.64, 0.71, x))
			y -= 280.0 * _mesa(x, 0.5, 0.02, 0.015)
			return y - 10.0 * sin(x * TAU * 7.0 + 1.3)
		3:  # Rocky Towers: stepped ledges split by three tall spires.
			var pts := [Vector2(0.0, 540), Vector2(0.10, 520), Vector2(0.17, 600),
					Vector2(0.30, 520), Vector2(0.37, 470), Vector2(0.44, 580),
					Vector2(0.56, 660), Vector2(0.63, 640), Vector2(0.70, 600),
					Vector2(0.83, 540), Vector2(0.90, 520), Vector2(1.0, 500)]
			var y := 540.0
			for i in range(pts.size() - 1):
				if x >= pts[i].x and x <= pts[i + 1].x:
					y = lerpf(pts[i].y, pts[i + 1].y, _smooth(pts[i].x, pts[i + 1].x, x))
					break
			for sp in [Vector2(0.235, 300.0), Vector2(0.5, 290.0), Vector2(0.765, 300.0)]:
				y = lerpf(y, sp.y, _mesa(x, sp.x, 0.012, 0.014))
			return y - 8.0 * sin(x * TAU * 9.0 + 0.4)
	return 540.0

# Raw heightmap for a map before the spawn platforms are carved in.
static func heights(id: int, level: int, rng: RandomNumberGenerator, n: int) -> PackedFloat32Array:
	var h := PackedFloat32Array()
	h.resize(n)
	if id == 0:
		# Height variation grows every 5 levels (GDD 13.1), capped for playability.
		var amp := 50.0 + minf(float(level), 30.0) * 5.0
		var freqs := [1.1, 2.3, 4.7, 7.9]
		var amps := [1.0, 0.5, 0.22, 0.1]
		var phases := []
		for i in range(4):
			phases.append(rng.randf_range(0.0, TAU))
		for i in range(n):
			var x := float(i) / float(n - 1)
			var v := 0.0
			for o in range(4):
				v += sin(x * TAU * freqs[o] + phases[o]) * amps[o]
			h[i] = 540.0 - v * amp
	else:
		for i in range(n):
			h[i] = designed_height(id, float(i) / float(n - 1))
	return h

func generate(level: int, seed_val: int, p_map := 0) -> void:
	map_id = clampi(p_map, 0, MAPS.size() - 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var n := int(WORLD_W / STEP) + 1
	hmap = heights(map_id, level, rng, n)
	# Four flat spawn platforms, at least 200 px apart (GDD 13.1).
	spawn_points.clear()
	var seg := WORLD_W / 4.0
	for k in range(4):
		var sx: float
		if map_id == 0:
			sx = seg * k + rng.randf_range(seg * 0.28, seg * 0.72)
		else:
			sx = SPAWNS[map_id][k] * WORLD_W + rng.randf_range(-18.0, 18.0)
		var ci := int(sx / STEP)
		var half := 8  # flatten ~64 px each side
		var y := hmap[clampi(ci, half, n - 1 - half)]
		for j in range(-half, half + 1):
			var idx := clampi(ci + j, 0, n - 1)
			hmap[idx] = y
		spawn_points.append(Vector2(sx, y))
	# Decorations, kept off the spawn platforms so they never hide a tank.
	rocks.clear()
	flowers.clear()
	for i in range(14):
		var rx := _free_x(rng)
		rocks.append(Vector3(rx, ground_y(rx), rng.randf_range(5.0, 14.0)))
	var count := 26 if map_id == 0 else 18
	for i in range(count):
		var fx := _free_x(rng)
		flowers.append(Vector3(fx, ground_y(fx), float(rng.randi_range(0, 2))))
	queue_redraw()

func _free_x(rng: RandomNumberGenerator) -> float:
	for attempt in range(12):
		var x := rng.randf_range(30.0, WORLD_W - 30.0)
		var ok := true
		for sp in spawn_points:
			if absf(sp.x - x) < 80.0:
				ok = false
				break
		if ok:
			return x
	return rng.randf_range(30.0, WORLD_W - 30.0)

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
	var th := theme(map_id)
	var n := hmap.size()
	# Dirt body.
	var poly := PackedVector2Array()
	poly.append(Vector2(0, BOTTOM_Y))
	for i in range(n):
		poly.append(Vector2(i * STEP, hmap[i]))
	poly.append(Vector2(WORLD_W, BOTTOM_Y))
	draw_colored_polygon(poly, th["dirt"])
	# Darker lower band for depth; the canyon gets extra rock strata.
	var bands := [90.0] if map_id != 2 else [70.0, 150.0, 240.0]
	for bi in range(bands.size()):
		var poly2 := PackedVector2Array()
		poly2.append(Vector2(0, BOTTOM_Y))
		for i in range(n):
			poly2.append(Vector2(i * STEP, minf(hmap[i] + bands[bi], BOTTOM_Y)))
		poly2.append(Vector2(WORLD_W, BOTTOM_Y))
		var c: Color = th["deep"] if bi % 2 == 0 else th["dirt"].darkened(0.05)
		draw_colored_polygon(poly2, c)
	# Top layer: grass, snow or sand.
	var thick := 22.0 if map_id == 1 else 16.0
	var top := PackedVector2Array()
	for i in range(n):
		top.append(Vector2(i * STEP, hmap[i] - 2.0))
	for i in range(n - 1, -1, -1):
		top.append(Vector2(i * STEP, hmap[i] + thick))
	draw_colored_polygon(top, th["top"])
	# Rocks.
	var rc: Color = th["rock"]
	for r in rocks:
		draw_circle(Vector2(r.x, r.y - r.z * 0.35), r.z, rc)
		draw_circle(Vector2(r.x - r.z * 0.3, r.y - r.z * 0.5), r.z * 0.55, rc.lightened(0.12))
	for f in flowers:
		_draw_deco(th["deco"], Vector2(f.x, f.y), int(f.z))

func _draw_deco(kind: String, base: Vector2, v: int) -> void:
	match kind:
		"pines":
			var h := 26.0 + float(v) * 7.0
			draw_rect(Rect2(base.x - 2.5, base.y - 7.0, 5.0, 8.0), Color(0.45, 0.32, 0.22))
			for k in range(3):
				var y0 := base.y - 6.0 - float(k) * h * 0.26
				var w := h * (0.42 - float(k) * 0.1)
				draw_colored_polygon(PackedVector2Array([Vector2(base.x - w, y0),
						Vector2(base.x + w, y0), Vector2(base.x, y0 - h * 0.45)]),
						Color(0.2, 0.52, 0.38))
			draw_colored_polygon(PackedVector2Array([Vector2(base.x - 5, base.y - h * 0.78),
					Vector2(base.x + 5, base.y - h * 0.78), Vector2(base.x, base.y - h - 4.0)]),
					Color(0.97, 0.98, 1.0))
		"cacti":
			var h := 22.0 + float(v) * 6.0
			var g := Color(0.36, 0.64, 0.36)
			draw_line(base, base + Vector2(0, -h), g, 8.0)
			draw_circle(base + Vector2(0, -h), 4.0, g)
			draw_line(base + Vector2(0, -h * 0.5), base + Vector2(8, -h * 0.5), g, 5.0)
			draw_line(base + Vector2(8, -h * 0.5), base + Vector2(8, -h * 0.8), g, 5.0)
			if v != 1:
				draw_line(base + Vector2(0, -h * 0.35), base + Vector2(-7, -h * 0.35), g, 5.0)
				draw_line(base + Vector2(-7, -h * 0.35), base + Vector2(-7, -h * 0.6), g, 5.0)
			if v == 2:
				draw_circle(base + Vector2(0, -h - 3.0), 3.0, Color(1.0, 0.5, 0.7))
		"crystals":
			var cols := [Color(0.6, 0.85, 1.0), Color(0.85, 0.6, 1.0), Color(1.0, 0.7, 0.85)]
			var c: Color = cols[v]
			for k in range(3):
				var ox := float(k - 1) * 6.0
				var hh := 12.0 + float((k + v) % 3) * 5.0
				draw_colored_polygon(PackedVector2Array([base + Vector2(ox - 4, 0),
						base + Vector2(ox + 4, 0), base + Vector2(ox + 3, -hh * 0.7),
						base + Vector2(ox, -hh), base + Vector2(ox - 3, -hh * 0.7)]), c)
			draw_line(base + Vector2(-1, -4), base + Vector2(-1, -12), Color(1, 1, 1, 0.7), 1.5)
		_:
			var petal := [Color(1.0, 0.7, 0.8), Color(1.0, 0.9, 0.4), Color(0.8, 0.7, 1.0)]
			draw_line(base, base + Vector2(0, -10), Color(0.25, 0.55, 0.25), 2.0)
			draw_circle(base + Vector2(0, -12), 4.5, petal[v])
			draw_circle(base + Vector2(0, -12), 2.0, Color(1.0, 0.85, 0.3))

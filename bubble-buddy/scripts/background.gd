class_name BBBackground
extends Node2D
## Three parallax layers, caustic light, sunbeams and idle background critters.
##
## Art rule enforced here: the sea floor stays visible along the bottom and the
## surface stays bright at the top, so the screen never becomes a dark void.

const SUNBEAM_COUNT := 5

var view_size := Vector2(1080, 1920)
var scroll_speed := 130.0

var _zone := 0
var _water_top := Color.WHITE
var _water_bottom := Color.WHITE
var _sand := Color.WHITE
var _far := Color.WHITE
var _mid := Color.WHITE
var _near := Color.WHITE
var _target := {}
var _blend := 1.0

var _far_items: Array = []
var _mid_items: Array = []
var _critters: Array = []
var _gradient: GradientTexture2D
var _caustics: ColorRect
var _motes: GPUParticles2D
var _t := 0.0


func _ready() -> void:
	z_index = -100
	_apply_zone(0, true)
	_build_gradient()
	_build_caustics()
	_build_motes()
	_seed_layers()


func _build_gradient() -> void:
	_gradient = GradientTexture2D.new()
	_gradient.width = 8
	_gradient.height = 256
	_gradient.fill_from = Vector2(0, 0)
	_gradient.fill_to = Vector2(0, 1)
	_update_gradient()


func _update_gradient() -> void:
	var g := Gradient.new()
	g.set_color(0, _water_top)
	g.set_color(1, _water_bottom)
	# A brighter sliver right at the surface keeps the top of the screen airy.
	g.add_point(0.18, _water_top.lerp(Color.WHITE, 0.35))
	g.add_point(0.75, _water_bottom.lerp(_water_top, 0.18))
	_gradient.gradient = g


func _build_caustics() -> void:
	_caustics = ColorRect.new()
	_caustics.size = view_size
	_caustics.color = Color.WHITE
	_caustics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/caustics.gdshader")
	_caustics.material = mat
	add_child(_caustics)


func _build_motes() -> void:
	# Foreground layer: slow drifting flecks, the closest parallax plane.
	_motes = GPUParticles2D.new()
	_motes.amount = 40
	_motes.lifetime = 7.0
	_motes.preprocess = 4.0
	_motes.texture = BBDraw.dot_texture()
	_motes.position = Vector2(view_size.x * 0.5, -40)
	_motes.z_index = 40
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(view_size.x * 0.6, 10, 1)
	m.direction = Vector3(0, 1, 0)
	m.spread = 12.0
	m.initial_velocity_min = 110.0
	m.initial_velocity_max = 220.0
	m.gravity = Vector3(0, 10, 0)
	m.scale_min = 0.3
	m.scale_max = 1.1
	m.color = Color(1, 1, 1, 0.35)
	_motes.process_material = m
	add_child(_motes)


func _seed_layers() -> void:
	# Far layer: soft dunes and distant rock humps.
	for i in 7:
		_far_items.append({
			"x": randf_range(-100.0, view_size.x + 100.0),
			"y": randf_range(-view_size.y, view_size.y),
			"r": randf_range(150.0, 320.0),
			"squash": randf_range(0.35, 0.6),
		})
	# Mid layer: coral fans and kelp shapes.
	for i in 9:
		_mid_items.append({
			"x": randf_range(-60.0, view_size.x + 60.0),
			"y": randf_range(-view_size.y, view_size.y),
			"r": randf_range(70.0, 180.0),
			"arms": randi_range(3, 6),
			"phase": randf() * TAU,
		})
	for i in 4:
		_spawn_critter(randf_range(-view_size.y * 0.2, view_size.y))


func _spawn_critter(y: float) -> void:
	_critters.append({
		"x": randf_range(0.0, view_size.x),
		"y": y,
		"dir": 1.0 if randf() < 0.5 else -1.0,
		"speed": randf_range(30.0, 80.0),
		"size": randf_range(26.0, 52.0),
		"phase": randf() * TAU,
		"hue": randf(),
	})


func set_zone(zone: int) -> void:
	if zone == _zone:
		return
	_zone = zone
	_apply_zone(zone, false)


func _apply_zone(zone: int, immediate: bool) -> void:
	var z := Zones.get_zone(zone)
	if immediate:
		_water_top = z["water_top"]
		_water_bottom = z["water_bottom"]
		_sand = z["sand"]
		_far = z["far"]
		_mid = z["mid"]
		_near = z["near"]
		_blend = 1.0
	else:
		_target = z
		_blend = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _blend < 1.0 and not _target.is_empty():
		# Seamless colour crossfade into the next zone.
		_blend = minf(_blend + delta * 0.45, 1.0)
		var k: float = clampf(delta * 1.6, 0.0, 1.0)
		_water_top = _water_top.lerp(_target["water_top"], k)
		_water_bottom = _water_bottom.lerp(_target["water_bottom"], k)
		_sand = _sand.lerp(_target["sand"], k)
		_far = _far.lerp(_target["far"], k)
		_mid = _mid.lerp(_target["mid"], k)
		_near = _near.lerp(_target["near"], k)
		_update_gradient()

	var dy := scroll_speed * delta
	for item in _far_items:
		item["y"] += dy * 0.18
		if item["y"] - item["r"] > view_size.y + 200.0:
			item["y"] -= view_size.y + 400.0 + randf_range(0.0, 300.0)
			item["x"] = randf_range(-100.0, view_size.x + 100.0)
	for item in _mid_items:
		item["y"] += dy * 0.45
		if item["y"] - item["r"] > view_size.y + 200.0:
			item["y"] -= view_size.y + 400.0 + randf_range(0.0, 300.0)
			item["x"] = randf_range(-60.0, view_size.x + 60.0)
	for c in _critters:
		c["y"] += dy * 0.5
		c["x"] += c["dir"] * c["speed"] * delta
		if c["x"] < -140.0:
			c["x"] = view_size.x + 120.0
		elif c["x"] > view_size.x + 140.0:
			c["x"] = -120.0
		if c["y"] > view_size.y + 220.0:
			c["y"] -= view_size.y + 440.0
	queue_redraw()


func _draw() -> void:
	# --- Water ------------------------------------------------------------
	draw_texture_rect(_gradient, Rect2(Vector2.ZERO, view_size), false)

	# --- Far layer: dunes -------------------------------------------------
	for item in _far_items:
		BBDraw.ellipse(self, Vector2(item["x"], item["y"]), item["r"], item["r"] * item["squash"],
			Color(_far.r, _far.g, _far.b, 0.5), 0.0, 22)

	# --- Sunbeams (between far and mid, always from the surface) ----------
	for i in SUNBEAM_COUNT:
		var base_x := view_size.x * (0.1 + 0.2 * i) + sin(_t * 0.25 + i) * 60.0
		var width := 90.0 + sin(_t * 0.4 + i * 1.7) * 26.0
		var pts := PackedVector2Array([
			Vector2(base_x - width * 0.3, -50.0),
			Vector2(base_x + width * 0.3, -50.0),
			Vector2(base_x + width * 1.1, view_size.y * 0.85),
			Vector2(base_x - width * 0.6, view_size.y * 0.85),
		])
		draw_colored_polygon(pts, Color(1.0, 0.98, 0.85, 0.055))

	# --- Mid layer: coral -------------------------------------------------
	for item in _mid_items:
		_draw_coral(Vector2(item["x"], item["y"]), item["r"], item["arms"], item["phase"])

	# --- Background critters ---------------------------------------------
	for c in _critters:
		_draw_critter(c)

	# --- Sea floor haze (art rule: the floor is always visible) -----------
	var floor_h := view_size.y * 0.09
	var floor_top := view_size.y - floor_h
	for i in 8:
		var k := float(i) / 7.0
		var a := 0.06 + 0.12 * k
		draw_rect(Rect2(0, floor_top + floor_h * k * 0.9, view_size.x, floor_h), Color(_sand.r, _sand.g, _sand.b, a))
	for i in 5:
		var x := fposmod(view_size.x * (0.1 + i * 0.23) - _t * 8.0, view_size.x + 500.0) - 200.0
		BBDraw.ellipse(self, Vector2(x, view_size.y + 40.0), 260.0, 130.0, Color(_sand.r, _sand.g, _sand.b, 0.5), 0.0, 20)


func _draw_coral(pos: Vector2, r: float, arms: int, phase: float) -> void:
	var col := Color(_mid.r, _mid.g, _mid.b, 0.62)
	var sway := sin(_t * 0.7 + phase) * 0.14
	for a in arms:
		var ang := -PI * 0.5 + (float(a) - (arms - 1) * 0.5) * 0.36 + sway
		var length := r * 0.92
		var tip := pos + Vector2(cos(ang), sin(ang)) * length
		draw_line(pos, tip, col, maxf(8.0, r * 0.14), true)
		BBDraw.ellipse(self, tip, r * 0.16, r * 0.16, col, 0.0, 12)
	BBDraw.ellipse(self, pos, r * 0.5, r * 0.26, col, 0.0, 18)


func _draw_critter(c: Dictionary) -> void:
	var pos := Vector2(c["x"], c["y"])
	var s: float = c["size"]
	var dir: float = c["dir"]
	var wig := sin(_t * 4.0 + c["phase"]) * 0.22
	var body := Color(_near.r, _near.g, _near.b, 0.45).lerp(BBDraw.rainbow_color(c["hue"]), 0.35)
	body.a = 0.5
	# A simple, friendly background fish: body, tail, eye dot.
	BBDraw.ellipse(self, pos, s, s * 0.6, body, wig * 0.3, 18)
	var tail := pos - Vector2(dir * s * 1.1, 0)
	draw_colored_polygon(PackedVector2Array([
		tail,
		tail - Vector2(dir * s * 0.7, -s * 0.55 - wig * s),
		tail - Vector2(dir * s * 0.7, s * 0.55 + wig * s),
	]), body)
	BBDraw.ellipse(self, pos + Vector2(dir * s * 0.5, -s * 0.12), s * 0.13, s * 0.13, Color(0.15, 0.22, 0.3, 0.5), 0.0, 10)

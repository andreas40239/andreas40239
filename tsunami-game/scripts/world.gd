extends Node2D
## Zeichnet die Spielwelt (Himmel, Meer, Strand, Rohstoffe, Baumaschinen, Mauer)
## und spielt die Tsunami-Animation ab.

signal resource_clicked(kind: String, pos: Vector2)
signal tsunami_impact
signal tsunami_finished(survived: bool)

const W := 1280.0
const H := 720.0
const GROUND_Y := 470.0
const WALL_X := 700.0
const WALL_W := 44.0
const BEACH_X0 := WALL_X + WALL_W + 14.0
const BEACH_X1 := 1010.0
const SEA_FLOOR_Y := GROUND_Y + 95.0
const SEA_REST := -0.6          # Ruhewasserstand in Metern relativ zum Land
const VIEW_PIXELS := 390.0      # Pixel, die für die Höhenanzeige zur Verfügung stehen

const RESOURCE_RECTS := {
	"stone": Rect2(18, GROUND_Y - 62, 104, 62),
	"wood": Rect2(222, GROUND_Y - 125, 112, 125),
	"sand": Rect2(428, GROUND_Y - 48, 92, 48),
}
const RESOURCE_LABELS := {"stone": "Felsen", "wood": "Wald", "sand": "Sand"}

enum Phase { IDLE, RETREAT, APPROACH, IMPACT, OVERFLOW, RECEDE }

var game: Node          # main.gd – liefert Mauerhöhe, Maschinenlevel, Tsunami-Infos
var audio: Node         # ocean_audio.gd

var px_per_m := 40.0
var t := 0.0
var display_wall_h := 0.0
var build_flash := 0.0

# Tsunami-Zustand
var phase := Phase.IDLE
var phase_t := 0.0
var wave_h := 0.0
var wall_at_impact := 0.0
var survived := false
var crest_x := W + 300.0
var amp := 0.0
var offset := 0.0
var flood_h := 0.0
var flood_front := WALL_X
var storm := 0.0
var shake := 0.0

var _floaters: Array = []
var _hit := {"stone": 0.0, "wood": 0.0, "sand": 0.0}
var _splash: CPUParticles2D
var _spill: CPUParticles2D
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_splash = _make_particles(420, true)
	_spill = _make_particles(160, false)
	_spill.direction = Vector2(-1, -0.3)
	_spill.spread = 25.0
	_spill.initial_velocity_min = 120.0
	_spill.initial_velocity_max = 260.0
	_spill.lifetime = 0.9


func _make_particles(amount: int, one_shot: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.one_shot = one_shot
	p.emitting = false
	p.explosiveness = 0.85 if one_shot else 0.0
	p.lifetime = 1.4
	p.direction = Vector2(0.25, -1)
	p.spread = 40.0
	p.gravity = Vector2(0, 900)
	p.initial_velocity_min = 250.0
	p.initial_velocity_max = 700.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 8.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(18, 6)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.95))
	g.set_color(1, Color(0.55, 0.8, 1.0, 0.0))
	p.color_ramp = g
	add_child(p)
	return p


# ---------------------------------------------------------------- Umrechnung

func h_to_y(h: float) -> float:
	return GROUND_Y - h * px_per_m


## Wasserhöhe (Meter über Land) an Position x
func sea_h(x: float) -> float:
	var h := SEA_REST + offset
	h += 0.12 * sin(x * 0.03 + t * 1.6) + 0.08 * sin(x * 0.071 - t * 2.3)
	if amp > 0.0:
		var d := x - crest_x
		if d < 0.0:
			h += amp * exp(-pow(d / 60.0, 2.0))
		else:
			h += amp * (0.35 + 0.65 * exp(-pow(d / 320.0, 2.0)))
	return h


func is_busy() -> bool:
	return phase != Phase.IDLE


# ---------------------------------------------------------------- Steuerung

func start_tsunami(height: float, wall_h: float) -> void:
	wave_h = height
	wall_at_impact = wall_h
	survived = wall_h >= height
	phase = Phase.RETREAT
	phase_t = 0.0
	crest_x = W + 300.0
	amp = 0.0
	flood_h = 0.0
	flood_front = WALL_X


func notify_built() -> void:
	build_flash = 1.0


func spawn_floater(pos: Vector2, text: String, color: Color) -> void:
	_floaters.append({"pos": pos, "text": text, "color": color, "life": 1.2})


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := get_local_mouse_position()
		for kind in RESOURCE_RECTS:
			if (RESOURCE_RECTS[kind] as Rect2).has_point(p):
				_hit[kind] = 1.0
				resource_clicked.emit(kind, p)
				get_viewport().set_input_as_handled()
				return


# ---------------------------------------------------------------- Update

func _process(delta: float) -> void:
	t += delta
	_update_tsunami(delta)

	var target_wall: float = game.wall_height if game else 0.0
	display_wall_h = move_toward(display_wall_h, target_wall, delta * maxf(2.0, absf(target_wall - display_wall_h) * 3.0))
	build_flash = maxf(0.0, build_flash - delta * 1.5)
	for k in _hit:
		_hit[k] = maxf(0.0, _hit[k] - delta * 4.0)

	# Maßstab so wählen, dass Mauer und (bekannter / sichtbarer) Tsunami ins Bild passen
	var view := maxf(6.0, display_wall_h + 2.0)
	if game and game.tsunami_known:
		view = maxf(view, game.tsunami_height * 1.15)
	view = maxf(view, (SEA_REST + offset + amp) * 1.12)
	px_per_m = lerpf(px_per_m, VIEW_PIXELS / view, 1.0 - exp(-delta * 2.5))

	for f in _floaters:
		f.life -= delta
		f.pos.y -= 45.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)

	shake = maxf(0.0, shake - delta * 1.2)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 14.0

	var over := false
	for kind in RESOURCE_RECTS:
		if (RESOURCE_RECTS[kind] as Rect2).has_point(get_local_mouse_position()):
			over = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over else Input.CURSOR_ARROW)

	if audio:
		audio.intensity = storm
	queue_redraw()


func _update_tsunami(delta: float) -> void:
	if phase == Phase.IDLE:
		storm = move_toward(storm, 0.0, delta * 0.5)
		offset = lerpf(offset, 0.0, 1.0 - exp(-delta * 2.0))
		return
	phase_t += delta
	var full := wave_h - SEA_REST
	match phase:
		Phase.RETREAT:
			# Das Meer zieht sich zurück – typisches Warnzeichen
			var p := minf(phase_t / 2.2, 1.0)
			offset = -1.4 * smoothstep(0.0, 1.0, p)
			storm = 0.35 * p
			if phase_t >= 2.2:
				_set_phase(Phase.APPROACH)
		Phase.APPROACH:
			var p := minf(phase_t / 4.2, 1.0)
			crest_x = lerpf(W + 300.0, WALL_X + WALL_W, pow(p, 1.25))
			amp = full * (0.2 + 0.8 * p * p)
			offset = lerpf(-1.4, 0.0, p)
			storm = 0.35 + 0.65 * p
			if p >= 1.0:
				_on_impact()
		Phase.IMPACT:
			# Die Mauer hält: Welle zerschellt und läuft zurück
			crest_x += 90.0 * delta
			amp = full * clampf(1.0 - (phase_t - 0.25) / 2.3, 0.0, 1.0)
			if phase_t >= 2.6:
				_set_phase(Phase.RECEDE)
		Phase.OVERFLOW:
			var target := clampf((wave_h - wall_at_impact) * 0.85 + 0.4, 0.5, maxf(0.5, wave_h * 0.9))
			flood_h = target * smoothstep(0.0, 1.0, minf(phase_t / 1.2, 1.0))
			flood_front = lerpf(WALL_X, -60.0, smoothstep(0.0, 1.0, minf(phase_t / 2.4, 1.0)))
			if phase_t > 1.8:
				amp = full * clampf(1.0 - (phase_t - 1.8) / 2.0, 0.0, 1.0)
				crest_x += 60.0 * delta
			_spill.emitting = sea_h(WALL_X + WALL_W) > wall_at_impact + 0.2
			_spill.position = Vector2(WALL_X + WALL_W * 0.5, h_to_y(wall_at_impact) - 4.0)
			if phase_t >= 4.0:
				_spill.emitting = false
				_set_phase(Phase.RECEDE)
		Phase.RECEDE:
			var k := 1.0 - exp(-delta * 2.2)
			amp = lerpf(amp, 0.0, k)
			flood_h = lerpf(flood_h, 0.0, k)
			storm = move_toward(storm, 0.0, delta * 0.5)
			if phase_t >= 2.5:
				amp = 0.0
				flood_h = 0.0
				phase = Phase.IDLE
				tsunami_finished.emit(survived)


func _set_phase(p: Phase) -> void:
	phase = p
	phase_t = 0.0


func _on_impact() -> void:
	crest_x = WALL_X + WALL_W
	amp = wave_h - SEA_REST
	shake = clampf(0.4 + wave_h * 0.05, 0.4, 1.4)
	tsunami_impact.emit()
	if audio:
		audio.impact(1.0)
	var top := minf(wave_h, wall_at_impact) if survived else wall_at_impact
	_splash.position = Vector2(WALL_X + WALL_W + 6.0, h_to_y(top))
	var power := clampf(sqrt(maxf(wave_h, 1.0)) * 170.0, 300.0, 1100.0)
	_splash.initial_velocity_min = power * 0.5
	_splash.initial_velocity_max = power
	_splash.restart()
	_splash.emitting = true
	_set_phase(Phase.IMPACT if survived else Phase.OVERFLOW)


# ---------------------------------------------------------------- Zeichnen

func _draw() -> void:
	_draw_sky()
	_draw_sea()
	_draw_ground()
	_draw_rocks(70.0)
	_draw_trees()
	_draw_sand(474.0)
	if game:
		var m: Dictionary = game.machines
		if m.excavator.level > 0:
			_draw_excavator(168.0, m.excavator.level)
		if m.harvester.level > 0:
			_draw_harvester(380.0, m.harvester.level)
		if m.mixer.level > 0:
			_draw_mixer(578.0, m.mixer.level)
		if m.crane.level > 0:
			_draw_crane(650.0, m.crane.level)
	_draw_wall()
	_draw_flood()
	_draw_marker()
	_draw_resource_labels()
	for f in _floaters:
		var c: Color = f.color
		c.a = clampf(f.life / 0.6, 0.0, 1.0)
		_text(f.pos, f.text, 18, c, true)


func _text(pos: Vector2, s: String, size: int, color: Color, outline := false) -> void:
	if outline:
		draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, color.a * 0.7))
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_sky() -> void:
	var top := Color(0.36, 0.62, 0.9).lerp(Color(0.18, 0.2, 0.26), storm)
	var bottom := Color(0.78, 0.9, 0.98).lerp(Color(0.42, 0.45, 0.5), storm)
	draw_polygon(PackedVector2Array([Vector2(-20, -20), Vector2(W + 20, -20), Vector2(W + 20, H), Vector2(-20, H)]),
		PackedColorArray([top, top, bottom, bottom]))
	# Sonne
	var sun := Color(1.0, 0.93, 0.6, 1.0 - storm * 0.8)
	draw_circle(Vector2(1120, 110), 42, sun)
	draw_circle(Vector2(1120, 110), 56, Color(sun.r, sun.g, sun.b, 0.18 * sun.a))
	# Wolken
	var cloud := Color(1, 1, 1, 0.85).lerp(Color(0.35, 0.37, 0.42, 0.95), storm)
	for i in 5:
		var cx := fmod(i * 290.0 + t * (8.0 + i * 2.0) + storm * t * 20.0, W + 300.0) - 150.0
		var cy := 95.0 + (i % 3) * 45.0
		for j in 4:
			draw_circle(Vector2(cx + j * 26.0, cy - (j % 2) * 12.0), 22.0 + (j % 2) * 8.0, cloud)


func _draw_sea() -> void:
	var pts := PackedVector2Array()
	var x := WALL_X + WALL_W
	while x <= W + 10.0:
		pts.append(Vector2(x, h_to_y(sea_h(x))))
		x += 8.0
	var surface := pts.duplicate()
	pts.append(Vector2(W + 10.0, H + 20.0))
	pts.append(Vector2(WALL_X + WALL_W, H + 20.0))
	var deep := Color(0.05, 0.3, 0.5).lerp(Color(0.12, 0.25, 0.3), storm)
	var shallow := Color(0.15, 0.55, 0.75).lerp(Color(0.25, 0.4, 0.45), storm)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(shallow.lerp(deep, clampf((p.y - 200.0) / 450.0, 0.0, 1.0)))
	draw_polygon(pts, cols)
	draw_polyline(surface, Color(0.85, 0.95, 1.0, 0.9), 3.0)
	# Gischt auf dem Wellenkamm
	if amp > 0.5:
		for i in surface.size():
			var d := surface[i].x - crest_x
			if d > -50.0 and d < 120.0:
				var r := 3.0 + 5.0 * absf(sin(i * 1.7 + t * 9.0))
				draw_circle(surface[i] + Vector2(0, 2), r, Color(1, 1, 1, 0.85))


func _draw_ground() -> void:
	# Strand / Meeresboden
	var beach := PackedVector2Array([
		Vector2(WALL_X, GROUND_Y), Vector2(BEACH_X0, GROUND_Y),
		Vector2(BEACH_X1, SEA_FLOOR_Y), Vector2(W + 20, SEA_FLOOR_Y + 15),
		Vector2(W + 20, H + 20), Vector2(WALL_X, H + 20)])
	draw_colored_polygon(beach, Color(0.86, 0.76, 0.52))
	# Land mit Gras
	draw_rect(Rect2(-20, GROUND_Y, BEACH_X0 + 20, H - GROUND_Y + 20), Color(0.47, 0.36, 0.24))
	draw_rect(Rect2(-20, GROUND_Y, BEACH_X0 - 6, 10), Color(0.33, 0.62, 0.27))
	for i in 60:
		var gx := i * 12.0 + 3.0
		if gx < WALL_X - 4.0:
			draw_line(Vector2(gx, GROUND_Y), Vector2(gx + 3, GROUND_Y - 6), Color(0.28, 0.55, 0.22), 2.0)


func _draw_rocks(x: float) -> void:
	var j: float = sin(t * 50.0) * _hit.stone * 3.0
	var g := Color(0.5, 0.5, 0.53)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 50 + j, GROUND_Y), Vector2(x - 40 + j, GROUND_Y - 30),
		Vector2(x - 12 + j, GROUND_Y - 52), Vector2(x + 18 + j, GROUND_Y - 40), Vector2(x + 46 + j, GROUND_Y)]), g)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 10, GROUND_Y), Vector2(x + 8, GROUND_Y - 24),
		Vector2(x + 34, GROUND_Y - 28), Vector2(x + 52, GROUND_Y)]), g.darkened(0.15))
	draw_line(Vector2(x - 12 + j, GROUND_Y - 52), Vector2(x - 20 + j, GROUND_Y - 20), g.darkened(0.3), 2.0)
	draw_line(Vector2(x + 18 + j, GROUND_Y - 40), Vector2(x + 5 + j, GROUND_Y - 14), g.darkened(0.3), 2.0)


func _draw_trees() -> void:
	var j: float = sin(t * 45.0) * _hit.wood * 4.0
	var xs := [240.0, 278.0, 316.0]
	var hs := [105.0, 122.0, 98.0]
	for i in 3:
		var x: float = xs[i]
		var h: float = hs[i]
		draw_rect(Rect2(x - 5, GROUND_Y - 28, 10, 28), Color(0.45, 0.3, 0.17))
		for k in 3:
			var base := GROUND_Y - 22.0 - k * h * 0.24
			var w := 30.0 - k * 7.0
			var sway: float = j + sin(t * 1.3 + i) * 1.5 * (k + 1)
			draw_colored_polygon(PackedVector2Array([Vector2(x - w, base), Vector2(x + w, base),
				Vector2(x + sway, base - h * 0.42)]), Color(0.16, 0.45 + 0.05 * k, 0.2))


func _draw_sand(x: float) -> void:
	var j: float = _hit.sand * 4.0
	var pts := PackedVector2Array()
	for i in 21:
		var a := PI * i / 20.0
		pts.append(Vector2(x - cos(a) * 44.0, GROUND_Y - sin(a) * (34.0 - j)))
	draw_colored_polygon(pts, Color(0.9, 0.78, 0.5))
	for i in 6:
		draw_circle(Vector2(x - 25 + i * 10, GROUND_Y - 10 - (i % 3) * 6), 1.5, Color(0.75, 0.62, 0.38))


func _draw_resource_labels() -> void:
	if game and game.level > 1 and t > 20.0:
		return
	var a := 0.6 + 0.4 * sin(t * 3.0)
	for kind in RESOURCE_RECTS:
		var r: Rect2 = RESOURCE_RECTS[kind]
		_text(Vector2(r.position.x + 4, r.position.y - 8), "Klick: " + RESOURCE_LABELS[kind], 14, Color(1, 1, 1, a), true)


func _wheel(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color(0.15, 0.15, 0.15))
	draw_circle(c, r * 0.45, Color(0.6, 0.6, 0.6))


func _level_tag(pos: Vector2, lvl: int) -> void:
	_text(pos, "Lv %d" % lvl, 12, Color(1, 1, 0.8), true)


func _draw_excavator(x: float, lvl: int) -> void:
	var yel := Color(0.95, 0.72, 0.1)
	# Ketten
	draw_rect(Rect2(x - 32, GROUND_Y - 14, 64, 14), Color(0.18, 0.18, 0.18))
	for i in 4:
		draw_circle(Vector2(x - 24 + i * 16, GROUND_Y - 7), 5, Color(0.45, 0.45, 0.45))
	# Oberwagen + Kabine
	draw_rect(Rect2(x - 26, GROUND_Y - 38, 50, 24), yel)
	draw_rect(Rect2(x - 4, GROUND_Y - 60, 26, 22), yel.darkened(0.1))
	draw_rect(Rect2(x + 1, GROUND_Y - 56, 16, 13), Color(0.6, 0.85, 1.0))
	# Arm zeigt nach links zu den Felsen
	var piv := Vector2(x - 22, GROUND_Y - 32)
	var a1 := deg_to_rad(-140.0 + 14.0 * sin(t * 2.2))
	var p1 := piv + Vector2.from_angle(a1) * 48.0
	var a2 := a1 - deg_to_rad(95.0 + 22.0 * sin(t * 2.2 + 1.2))
	var p2 := p1 + Vector2.from_angle(a2) * 38.0
	draw_line(piv, p1, yel.darkened(0.15), 8.0)
	draw_line(p1, p2, yel.darkened(0.25), 6.0)
	var bd := Vector2.from_angle(a2 + 1.2)
	draw_colored_polygon(PackedVector2Array([p2, p2 + bd * 16.0, p2 + Vector2.from_angle(a2) * 12.0 + bd * 6.0]), Color(0.3, 0.3, 0.3))
	_level_tag(Vector2(x - 14, GROUND_Y - 66), lvl)


func _draw_harvester(x: float, lvl: int) -> void:
	var green := Color(0.25, 0.6, 0.25)
	draw_rect(Rect2(x - 26, GROUND_Y - 34, 54, 20), green)
	draw_rect(Rect2(x + 6, GROUND_Y - 56, 22, 22), green.darkened(0.15))
	draw_rect(Rect2(x + 10, GROUND_Y - 52, 14, 12), Color(0.6, 0.85, 1.0))
	_wheel(Vector2(x - 16, GROUND_Y - 10), 10)
	_wheel(Vector2(x + 18, GROUND_Y - 10), 10)
	# Kranarm mit Kreissäge zum Wald
	var piv := Vector2(x - 20, GROUND_Y - 34)
	var tip := piv + Vector2(-36 + 4 * sin(t * 3.0), -26 + 8 * sin(t * 1.7))
	draw_line(piv, tip, Color(0.3, 0.3, 0.3), 5.0)
	draw_circle(tip, 11, Color(0.7, 0.7, 0.75))
	for i in 6:
		var a := t * 14.0 + i * TAU / 6.0
		draw_line(tip, tip + Vector2.from_angle(a) * 11.0, Color(0.35, 0.35, 0.4), 2.0)
	_level_tag(Vector2(x - 8, GROUND_Y - 62), lvl)


func _draw_mixer(x: float, lvl: int) -> void:
	var red := Color(0.85, 0.25, 0.2)
	draw_rect(Rect2(x - 40, GROUND_Y - 24, 76, 10), Color(0.3, 0.3, 0.3))
	draw_rect(Rect2(x + 18, GROUND_Y - 46, 22, 26), red)
	draw_rect(Rect2(x + 24, GROUND_Y - 42, 12, 10), Color(0.6, 0.85, 1.0))
	_wheel(Vector2(x - 26, GROUND_Y - 10), 10)
	_wheel(Vector2(x + 26, GROUND_Y - 10), 10)
	# Rotierende Trommel
	var c := Vector2(x - 12, GROUND_Y - 42)
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * 28.0, sin(a) * 15.0).rotated(-0.25))
	draw_colored_polygon(pts, Color(0.9, 0.9, 0.88))
	for i in 3:
		var ph := fmod(t * 1.5 + i / 3.0, 1.0)
		var sx := lerpf(-24.0, 24.0, ph)
		var hh := 15.0 * sqrt(maxf(0.0, 1.0 - pow(sx / 28.0, 2.0)))
		draw_line(c + Vector2(sx - 6, -hh).rotated(-0.25), c + Vector2(sx + 6, hh).rotated(-0.25), red, 3.0)
	_level_tag(Vector2(x - 24, GROUND_Y - 62), lvl)


func _draw_crane(x: float, lvl: int) -> void:
	var yel := Color(0.98, 0.78, 0.12)
	var top_y := maxf(96.0, minf(GROUND_Y - 230.0, h_to_y(display_wall_h) - 55.0))
	# Gittermast
	draw_line(Vector2(x - 8, GROUND_Y), Vector2(x - 8, top_y), yel, 3.0)
	draw_line(Vector2(x + 8, GROUND_Y), Vector2(x + 8, top_y), yel, 3.0)
	var y := GROUND_Y
	var left := true
	while y > top_y + 14.0:
		var ny := y - 16.0
		draw_line(Vector2(x - 8 if left else x + 8, y), Vector2(x + 8 if left else x - 8, ny), yel.darkened(0.2), 2.0)
		y = ny
		left = not left
	# Ausleger über die Mauer
	var jib_end := WALL_X + WALL_W + 30.0
	draw_line(Vector2(x - 50, top_y), Vector2(jib_end, top_y), yel, 5.0)
	draw_line(Vector2(x, top_y - 26), Vector2(jib_end, top_y), yel.darkened(0.2), 2.0)
	draw_line(Vector2(x, top_y - 26), Vector2(x - 50, top_y), yel.darkened(0.2), 2.0)
	draw_rect(Rect2(x - 56, top_y + 2, 18, 18), Color(0.4, 0.4, 0.4))
	draw_rect(Rect2(x - 6, top_y + 4, 16, 12), Color(0.6, 0.85, 1.0))
	# Laufkatze + Haken mit Steinblock
	var trolley_x := WALL_X + WALL_W * 0.5 + sin(t * 0.8) * 8.0
	var wall_top := h_to_y(display_wall_h)
	var hook_y := lerpf(top_y + 30.0, wall_top - 18.0, 0.5 + 0.5 * sin(t * 1.1)) if build_flash <= 0.0 \
		else lerpf(wall_top - 18.0, top_y + 30.0, build_flash)
	draw_rect(Rect2(trolley_x - 8, top_y + 2, 16, 6), Color(0.3, 0.3, 0.3))
	draw_line(Vector2(trolley_x, top_y + 8), Vector2(trolley_x, hook_y), Color(0.2, 0.2, 0.2), 1.5)
	draw_rect(Rect2(trolley_x - 14, hook_y, 28, 14), Color(0.6, 0.6, 0.62))
	_level_tag(Vector2(x + 12, top_y + 30), lvl)


func _draw_wall() -> void:
	var h := display_wall_h
	if h <= 0.01:
		_text(Vector2(WALL_X - 30, GROUND_Y - 10), "Bauplatz", 14, Color(1, 1, 1, 0.8), true)
		draw_rect(Rect2(WALL_X, GROUND_Y - 4, WALL_W, 4), Color(0.4, 0.4, 0.4))
		return
	var stone := Color(0.55, 0.56, 0.6)
	var concrete := Color(0.74, 0.73, 0.68)
	var row_m := 0.5
	var rows := int(ceil(h / row_m))
	for r in rows:
		var h0 := r * row_m
		var h1 := minf(h, h0 + row_m)
		var y0 := h_to_y(h0)
		var y1 := h_to_y(h1)
		var col := concrete if h0 >= 4.0 else stone
		col = col.lightened(0.04 * (r % 2))
		draw_rect(Rect2(WALL_X, y1, WALL_W, y0 - y1), col)
		draw_line(Vector2(WALL_X, y1), Vector2(WALL_X + WALL_W, y1), col.darkened(0.35), 1.0)
		if h0 < 4.0 and y0 - y1 > 6.0:
			var bx := WALL_X + (WALL_W * 0.5 if r % 2 == 0 else WALL_W * 0.25)
			draw_line(Vector2(bx, y0), Vector2(bx, y1), col.darkened(0.35), 1.0)
	var top := h_to_y(h)
	draw_rect(Rect2(WALL_X - 3, top - 5, WALL_W + 6, 6), Color(0.35, 0.36, 0.4))
	if build_flash > 0.0:
		draw_rect(Rect2(WALL_X - 3, top - 5, WALL_W + 6, 16), Color(1, 1, 0.6, build_flash * 0.6))
	_text(Vector2(WALL_X + 2, top - 10), "%.1f m" % h, 15, Color.WHITE, true)


func _draw_flood() -> void:
	var water := Color(0.15, 0.45, 0.7, 0.78)
	var sea_wall := sea_h(WALL_X + WALL_W)
	var wall_h := display_wall_h
	# Wasser schwappt über die Mauer und stürzt auf der Landseite herab
	if sea_wall > wall_h + 0.05 and wall_h > 0.3:
		var ys := h_to_y(sea_wall)
		var yw := h_to_y(wall_h)
		draw_colored_polygon(PackedVector2Array([Vector2(WALL_X + WALL_W, ys), Vector2(WALL_X, ys + 6.0),
			Vector2(WALL_X, yw), Vector2(WALL_X + WALL_W, yw)]), water)
		draw_colored_polygon(PackedVector2Array([Vector2(WALL_X, ys + 6.0), Vector2(WALL_X - 30.0, ys + 26.0),
			Vector2(WALL_X - 34.0, GROUND_Y), Vector2(WALL_X, GROUND_Y)]), water)
	if flood_h > 0.02 and flood_front < WALL_X:
		var pts := PackedVector2Array()
		var x := WALL_X
		while x >= flood_front:
			pts.append(Vector2(x, h_to_y(flood_h + 0.1 * sin(x * 0.05 + t * 4.0))))
			x -= 10.0
		pts.append(Vector2(flood_front, GROUND_Y))
		pts.append(Vector2(WALL_X, GROUND_Y))
		draw_colored_polygon(pts, water)
		draw_polyline(pts.slice(0, pts.size() - 2), Color(0.85, 0.95, 1.0, 0.8), 2.0)


func _draw_marker() -> void:
	if not game or not game.tsunami_known:
		return
	var y := h_to_y(game.tsunami_height)
	var x := WALL_X - 40.0
	while x < W - 10.0:
		draw_line(Vector2(x, y), Vector2(x + 14, y), Color(1, 0.25, 0.2, 0.9), 2.0)
		x += 24.0
	_text(Vector2(W - 210, y - 8), "Tsunami: %.1f m" % game.tsunami_height, 18, Color(1, 0.55, 0.5), true)

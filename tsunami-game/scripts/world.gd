extends Node2D
## Zeichnet die Spielwelt (Himmel, Meer, Strand, Rohstoffe, Baumaschinen, Dorf, Mauer,
## Schutzanlagen) und spielt die Tsunami-Wellen mit Rissen und Treibgut ab.

signal resource_clicked(kind: String, pos: Vector2)
signal wave_impact(index: int, height: float)
signal crack_fixed(pos: Vector2)
signal crack_failed(pos: Vector2)
signal debris_hit(kind: String)
signal debris_destroyed(kind: String, pos: Vector2)
signal house_flooded(index: int)
signal wall_tapped(layer_index: int)
signal tsunami_finished

const W := 1280.0
const H := 720.0
const GROUND_Y := 470.0
const WALL_X := 700.0
const WALL_W := 44.0
const FRONT_X := 792.0          # vordere Mauer (ab 20 m hinterer Mauer)
const FRONT_W := 36.0
const BEACH_X0 := WALL_X + WALL_W + 14.0
const BEACH_X1 := 1010.0
const SEA_FLOOR_Y := GROUND_Y + 95.0
const SEA_REST := -0.6          # Ruhewasserstand in Metern relativ zum Land
const VIEW_PIXELS := 370.0      # Pixel, die für die Höhenanzeige zur Verfügung stehen

const ROCK_X := 45.0
const EXCAVATOR_X := 124.0
const TREE_XS := [176.0, 206.0, 236.0]
const HARVESTER_X := 282.0
const SAND_X := 342.0
const MIXER_X := 420.0
const CRANE_X := 664.0
const BREAKWATER_X := 1030.0
const BUOY_X := 1205.0

const RESOURCE_RECTS := {
	"stone": Rect2(0, GROUND_Y - 62, 98, 62),
	"wood": Rect2(155, GROUND_Y - 125, 100, 125),
	"sand": Rect2(306, GROUND_Y - 42, 72, 42),
}
const RESOURCE_LABELS := {"stone": "Felsen", "wood": "Wald", "sand": "Sand"}
const MAT_COLORS := {
	"wood": Color(0.62, 0.43, 0.24), "stone": Color(0.55, 0.56, 0.6), "concrete": Color(0.78, 0.78, 0.74),
}
const SHIRTS := [Color(0.9, 0.3, 0.3), Color(0.3, 0.5, 0.9), Color(0.95, 0.75, 0.2), Color(0.4, 0.75, 0.4), Color(0.8, 0.4, 0.8)]

enum Phase { IDLE, RETREAT, APPROACH, IMPACT, BETWEEN, RECEDE }

var game: Node          # main.gd
var audio: Node         # ocean_audio.gd

var px_per_m := 40.0
var t := 0.0
var display_wall_h := 0.0       # hintere Mauer
var display_front_h := 0.0      # vordere Mauer
var selected_layer := -1        # hervorgehobene Schicht (Sanieren-Dialog)
var build_flash := 0.0
var pre_retreat := 0.0  # vom Hauptskript gesetzt: Meer zieht sich vor dem Tsunami zurück (m)
var quake := 0.0
var cheer := 0.0

# Tsunami-Zustand
var phase := Phase.IDLE
var phase_t := 0.0
var waves: Array = []
var wave_idx := 0
var debris_per_wave := 0
var crest_x := W + 300.0
var amp := 0.0
var offset := 0.0
var flood_h := 0.0
var flood_front := WALL_X
var flood_target_h := 0.0
var flood_target_x := WALL_X
var basin_h := 0.0              # Wasserstand zwischen den beiden Mauern
var basin_target := 0.0
var storm := 0.0
var shake := 0.0

var cracks: Array = []      # {h, life, max, seed}
var debris: Array = []      # {kind, off, x, free, rot}
var _collapse := {}         # Hausindex -> Animationszeit
var _floaters: Array = []
var _hit := {"stone": 0.0, "wood": 0.0, "sand": 0.0}
var _splash: CPUParticles2D
var _spill: CPUParticles2D
var _burst: CPUParticles2D
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_splash = _make_particles(420, true, Color(1, 1, 1, 0.95), Color(0.55, 0.8, 1.0, 0.0))
	_spill = _make_particles(160, false, Color(1, 1, 1, 0.95), Color(0.55, 0.8, 1.0, 0.0))
	_spill.direction = Vector2(-1, -0.3)
	_spill.spread = 25.0
	_spill.initial_velocity_min = 120.0
	_spill.initial_velocity_max = 260.0
	_spill.lifetime = 0.9
	_burst = _make_particles(40, true, Color(0.9, 0.8, 0.6, 1.0), Color(0.5, 0.4, 0.3, 0.0))
	_burst.direction = Vector2(0, -1)
	_burst.spread = 180.0
	_burst.initial_velocity_min = 80.0
	_burst.initial_velocity_max = 260.0
	_burst.lifetime = 0.8


func _make_particles(amount: int, one_shot: bool, c0: Color, c1: Color) -> CPUParticles2D:
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
	g.set_color(0, c0)
	g.set_color(1, c1)
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


func has_front() -> bool:
	return game != null and game.front_height > 0.01


func wall_left(w: int) -> float:
	return FRONT_X if w == 1 else WALL_X


func wall_width(w: int) -> float:
	return FRONT_W if w == 1 else WALL_W


func wall_h(w: int) -> float:
	return game.front_height if w == 1 else game.back_height


## Stelle, an der die Welle zuerst aufschlägt
func impact_x() -> float:
	return FRONT_X + FRONT_W if has_front() else WALL_X + WALL_W


## Wasserstand direkt vor der hinteren Mauer
func level_at_back() -> float:
	return basin_h if has_front() else sea_h(WALL_X + WALL_W)


func is_busy() -> bool:
	return phase != Phase.IDLE


func crack_center(c: Dictionary) -> Vector2:
	return Vector2(wall_left(c.w) + wall_width(c.w) * 0.5, h_to_y(c.h))


# ---------------------------------------------------------------- Steuerung

func start_quake() -> void:
	quake = 1.6
	if audio:
		audio.impact(0.7)


func start_tsunami(heights: Array, n_debris: int) -> void:
	waves = heights
	wave_idx = 0
	debris_per_wave = n_debris
	phase = Phase.RETREAT
	phase_t = 0.0
	crest_x = W + 300.0
	amp = 0.0
	flood_h = 0.0
	flood_front = WALL_X
	flood_target_h = 0.0
	flood_target_x = WALL_X
	basin_h = 0.0
	basin_target = 0.0
	cracks.clear()
	debris.clear()


func add_cracks(n: int, life: float) -> void:
	var w := 1 if game.front_height > 0.4 else 0
	var wh := wall_h(w)
	if wh < 0.4:
		return
	for i in n:
		cracks.append({"w": w, "h": wh * randf_range(0.12, 0.92), "life": life, "max": life, "seed": randf() * 100.0})


func notify_built() -> void:
	build_flash = 1.0


func on_breach() -> void:
	shake = 1.5
	var w := 1 if display_front_h > 0.01 else 0
	_burst.position = Vector2(wall_left(w) + wall_width(w) * 0.5, h_to_y(display_front_h if w == 1 else display_wall_h))
	_burst.restart()
	_burst.emitting = true
	# Nach dem Einsturz sind alle offenen Risse weg
	cracks.clear()
	display_wall_h = game.back_height
	display_front_h = game.front_height


func spawn_floater(pos: Vector2, text: String, color: Color) -> void:
	_floaters.append({"pos": pos, "text": text, "color": color, "life": 1.2})


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = (make_input_local(event) as InputEventMouseButton).position
	# 1. Treibgut zerstören
	for d in debris:
		if d.free and Vector2(d.x, _debris_y(d)).distance_to(p) < 42.0:
			debris.erase(d)
			_burst.position = Vector2(d.x, _debris_y(d))
			_burst.restart()
			_burst.emitting = true
			debris_destroyed.emit(d.kind, Vector2(d.x, _debris_y(d)))
			get_viewport().set_input_as_handled()
			return
	# 2. Risse flicken
	for c in cracks:
		if crack_center(c).distance_to(p) < 40.0:
			cracks.erase(c)
			spawn_floater(crack_center(c) + Vector2(-60, -8), "Geflickt!", Color(0.6, 1.0, 0.6))
			crack_fixed.emit(crack_center(c))
			get_viewport().set_input_as_handled()
			return
	# 3. Mauerschicht antippen (Sanieren) – nur vor dem Tsunami
	if game.state == game.State.PREP:
		for w in [0, 1]:
			var x0 := wall_left(w) - 10.0
			if p.x >= x0 and p.x <= x0 + wall_width(w) + 20.0 and p.y <= GROUND_Y + 10.0 and p.y >= h_to_y(wall_h(w)) - 10.0:
				var idx: int = game.layer_at(w, clampf((GROUND_Y - p.y) / px_per_m, 0.0, wall_h(w) - 0.01))
				if idx >= 0:
					wall_tapped.emit(idx)
					get_viewport().set_input_as_handled()
					return
	# 4. Rohstoffe sammeln
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
	_update_cracks(delta)
	_update_debris(delta)

	var tb: float = game.back_height if game else 0.0
	var tf: float = game.front_height if game else 0.0
	display_wall_h = move_toward(display_wall_h, tb, delta * maxf(2.0, absf(tb - display_wall_h) * 3.0))
	display_front_h = move_toward(display_front_h, tf, delta * maxf(2.0, absf(tf - display_front_h) * 3.0))
	build_flash = maxf(0.0, build_flash - delta * 1.5)
	cheer = maxf(0.0, cheer - delta)
	for k in _hit:
		_hit[k] = maxf(0.0, _hit[k] - delta * 4.0)
	for i in _collapse.keys():
		_collapse[i] = minf(1.0, _collapse[i] + delta * 1.5)

	# Maßstab so wählen, dass Mauer, erwartete Welle und sichtbare Welle ins Bild passen
	var view := maxf(6.0, maxf(display_wall_h, display_front_h) + 2.0)
	if game:
		view = maxf(view, game.estimate().y * 1.12)
	view = maxf(view, (SEA_REST + offset + amp) * 1.12)
	px_per_m = lerpf(px_per_m, VIEW_PIXELS / view, 1.0 - exp(-delta * 2.5))

	for f in _floaters:
		f.life -= delta
		f.pos.y -= 45.0 * delta
	_floaters = _floaters.filter(func(f): return f.life > 0.0)

	shake = maxf(0.0, shake - delta * 1.2)
	quake = maxf(0.0, quake - delta * 0.8)
	var s := shake * 14.0 + quake * 5.0
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * s

	if audio:
		audio.intensity = storm
	queue_redraw()


func _update_cracks(delta: float) -> void:
	for c in cracks.duplicate():
		c.life -= delta
		if c.life <= 0.0:
			cracks.erase(c)
			_burst.position = crack_center(c)
			_burst.restart()
			_burst.emitting = true
			crack_failed.emit(crack_center(c))


func _debris_y(d: Dictionary) -> float:
	return h_to_y(sea_h(d.x)) - 4.0


func _update_debris(delta: float) -> void:
	for d in debris.duplicate():
		if not d.free:
			d.x = crest_x + d.off
		else:
			d.x -= 190.0 * delta
		d.rot = sin(t * 2.0 + d.off) * 0.25
		if d.x <= impact_x() + 16.0:
			debris.erase(d)
			shake = maxf(shake, 0.6)
			_burst.position = Vector2(impact_x() + 10.0, _debris_y(d))
			_burst.restart()
			_burst.emitting = true
			if audio:
				audio.impact(0.6)
			debris_hit.emit(d.kind)


func _update_tsunami(delta: float) -> void:
	if phase != Phase.IMPACT:
		basin_target = 0.0
		basin_h = lerpf(basin_h, 0.0, 1.0 - exp(-delta * 1.2))
	if phase == Phase.IDLE:
		storm = move_toward(storm, 0.15 if pre_retreat > 0.0 else 0.0, delta * 0.5)
		offset = lerpf(offset, -pre_retreat, 1.0 - exp(-delta * 1.5))
		flood_h = lerpf(flood_h, 0.0, 1.0 - exp(-delta * 2.0))
		return
	phase_t += delta
	var wave_h: float = waves[wave_idx]
	var full := wave_h - SEA_REST
	match phase:
		Phase.RETREAT:
			var p := minf(phase_t / 1.5, 1.0)
			offset = lerpf(-pre_retreat, -(0.8 + 0.1 * wave_h), p)
			storm = maxf(storm, 0.35 * p)
			if phase_t >= 1.5:
				_start_approach()
		Phase.APPROACH:
			var p := minf(phase_t / 3.8, 1.0)
			crest_x = lerpf(W + 300.0, impact_x(), pow(p, 1.25))
			amp = maxf(amp * 0.98, full * (0.2 + 0.8 * p * p))
			offset = lerpf(offset, 0.0, 1.0 - exp(-delta * 1.5))
			storm = maxf(storm, 0.35 + 0.65 * p)
			if p >= 1.0:
				_on_impact()
		Phase.IMPACT:
			if phase_t > 0.4:
				crest_x += 70.0 * delta
			if phase_t > 2.0:
				amp = full * clampf(1.0 - (phase_t - 2.0) / 1.4, 0.0, 1.0)
			_update_overflow(delta)
			if phase_t >= 3.4:
				_spill.emitting = false
				if wave_idx + 1 < waves.size():
					_set_phase(Phase.BETWEEN)
				else:
					_set_phase(Phase.RECEDE)
		Phase.BETWEEN:
			amp = lerpf(amp, 0.0, 1.0 - exp(-delta * 3.0))
			flood_h = lerpf(flood_h, flood_h * 0.6, 1.0 - exp(-delta * 1.5))
			if phase_t >= 1.6:
				wave_idx += 1
				_start_approach()
		Phase.RECEDE:
			var k := 1.0 - exp(-delta * 2.2)
			amp = lerpf(amp, 0.0, k)
			flood_h = lerpf(flood_h, 0.0, k)
			storm = move_toward(storm, 0.0, delta * 0.5)
			if phase_t >= 2.5 and cracks.is_empty() and debris.is_empty():
				amp = 0.0
				phase = Phase.IDLE
				tsunami_finished.emit()


func _start_approach() -> void:
	_set_phase(Phase.APPROACH)
	crest_x = W + 300.0
	flood_target_h = 0.0
	var kinds := ["boot", "container", "stamm"]
	for i in debris_per_wave:
		debris.append({"kind": kinds[randi() % kinds.size()], "off": 70.0 + i * 85.0 + randf() * 30.0,
			"x": W + 400.0, "free": false, "rot": 0.0})


func _update_overflow(delta: float) -> void:
	if has_front():
		var over_front: float = sea_h(impact_x()) - game.front_height
		if over_front > 0.05:
			basin_target = maxf(basin_target, over_front)
		basin_h = move_toward(basin_h, basin_target, delta * 6.0)
	var wh: float = game.back_height
	var over := level_at_back() - wh
	if over > 0.05:
		flood_target_h = maxf(flood_target_h, over * 0.8 + 0.3)
		flood_target_x = minf(flood_target_x, WALL_X - (40.0 + over * 90.0))
		_spill.emitting = wh > 0.3
		_spill.position = Vector2(WALL_X + WALL_W * 0.5, h_to_y(wh) - 4.0)
	elif has_front() and sea_h(impact_x()) > game.front_height + 0.05:
		_spill.emitting = true
		_spill.position = Vector2(FRONT_X + FRONT_W * 0.5, h_to_y(game.front_height) - 4.0)
	else:
		_spill.emitting = false
	flood_h = move_toward(flood_h, flood_target_h, delta * 3.0)
	flood_front = move_toward(flood_front, flood_target_x, delta * 280.0)
	if flood_h > 0.25:
		for i in game.houses.size():
			var hs: Dictionary = game.houses[i]
			if hs.alive and hs.x > flood_front:
				_collapse[i] = 0.0
				house_flooded.emit(i)


func _set_phase(p: Phase) -> void:
	phase = p
	phase_t = 0.0


func _on_impact() -> void:
	var wave_h: float = waves[wave_idx]
	crest_x = impact_x()
	amp = wave_h - SEA_REST
	shake = clampf(0.4 + wave_h * 0.05, 0.4, 1.4)
	for d in debris:
		d.free = true
	if audio:
		audio.impact(1.0)
	var top := minf(wave_h, game.front_height if has_front() else game.back_height)
	_splash.position = Vector2(impact_x() + 6.0, h_to_y(top))
	var power := clampf(sqrt(maxf(wave_h, 1.0)) * 170.0, 300.0, 1100.0)
	_splash.initial_velocity_min = power * 0.5
	_splash.initial_velocity_max = power
	_splash.restart()
	_splash.emitting = true
	_set_phase(Phase.IMPACT)
	wave_impact.emit(wave_idx, wave_h)


# ---------------------------------------------------------------- Zeichnen

func _draw() -> void:
	_draw_sky()
	_draw_sea()
	_draw_ground()
	if game:
		_draw_defenses()
	_draw_rocks(ROCK_X)
	_draw_trees()
	_draw_sand(SAND_X)
	if game:
		var m: Dictionary = game.machines
		if m.excavator.level > 0:
			_draw_excavator(EXCAVATOR_X, m.excavator.level)
		if m.harvester.level > 0:
			_draw_harvester(HARVESTER_X, m.harvester.level)
		if m.mixer.level > 0:
			_draw_mixer(MIXER_X, m.mixer.level)
		_draw_village()
		if m.crane.level > 0:
			_draw_crane(CRANE_X, m.crane.level)
	_draw_basin()
	_draw_wall(0)
	_draw_wall(1)
	_draw_cracks()
	_draw_debris()
	_draw_flood()
	_draw_estimate()
	_draw_seismograph()
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
	var sun := Color(1.0, 0.93, 0.6, 1.0 - storm * 0.8)
	draw_circle(Vector2(1120, 150), 40, sun)
	draw_circle(Vector2(1120, 150), 54, Color(sun.r, sun.g, sun.b, 0.18 * sun.a))
	var cloud := Color(1, 1, 1, 0.85).lerp(Color(0.35, 0.37, 0.42, 0.95), storm)
	for i in 5:
		var cx := fmod(i * 290.0 + t * (8.0 + i * 2.0) + storm * t * 20.0, W + 300.0) - 150.0
		var cy := 120.0 + (i % 3) * 40.0
		for j in 4:
			draw_circle(Vector2(cx + j * 26.0, cy - (j % 2) * 12.0), 22.0 + (j % 2) * 8.0, cloud)


func _draw_sea() -> void:
	var pts := PackedVector2Array()
	var x0 := impact_x()
	var x := x0
	while x <= W + 10.0:
		pts.append(Vector2(x, h_to_y(sea_h(x))))
		x += 8.0
	var surface := pts.duplicate()
	pts.append(Vector2(W + 10.0, H + 20.0))
	pts.append(Vector2(x0, H + 20.0))
	var deep := Color(0.05, 0.3, 0.5).lerp(Color(0.12, 0.25, 0.3), storm)
	var shallow := Color(0.15, 0.55, 0.75).lerp(Color(0.25, 0.4, 0.45), storm)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(shallow.lerp(deep, clampf((p.y - 200.0) / 450.0, 0.0, 1.0)))
	draw_polygon(pts, cols)
	draw_polyline(surface, Color(0.85, 0.95, 1.0, 0.9), 3.0)
	if amp > 0.5:
		for i in surface.size():
			var d := surface[i].x - crest_x
			if d > -50.0 and d < 120.0:
				var r := 3.0 + 5.0 * absf(sin(i * 1.7 + t * 9.0))
				draw_circle(surface[i] + Vector2(0, 2), r, Color(1, 1, 1, 0.85))


func _draw_ground() -> void:
	var beach := PackedVector2Array([
		Vector2(WALL_X, GROUND_Y), Vector2(BEACH_X0, GROUND_Y),
		Vector2(BEACH_X1, SEA_FLOOR_Y), Vector2(W + 20, SEA_FLOOR_Y + 15),
		Vector2(W + 20, H + 20), Vector2(WALL_X, H + 20)])
	draw_colored_polygon(beach, Color(0.86, 0.76, 0.52))
	draw_rect(Rect2(-20, GROUND_Y, BEACH_X0 + 20, H - GROUND_Y + 20), Color(0.47, 0.36, 0.24))
	draw_rect(Rect2(-20, GROUND_Y, BEACH_X0 - 6, 10), Color(0.33, 0.62, 0.27))
	for i in 60:
		var gx := i * 12.0 + 3.0
		if gx < WALL_X - 4.0:
			draw_line(Vector2(gx, GROUND_Y), Vector2(gx + 3, GROUND_Y - 6), Color(0.28, 0.55, 0.22), 2.0)


func _beach_y(x: float) -> float:
	if x <= BEACH_X0:
		return GROUND_Y
	return lerpf(GROUND_Y, SEA_FLOOR_Y, clampf((x - BEACH_X0) / (BEACH_X1 - BEACH_X0), 0.0, 1.0))


func _draw_defenses() -> void:
	var d: Dictionary = game.defenses
	# Schutzwald: Palmen auf dem Strand
	for i in d.forest.level * 2:
		var x: float = FRONT_X + FRONT_W + 14.0 + i * 18.0
		var y := _beach_y(x)
		var sway := sin(t * 1.4 + i) * 3.0 + storm * sin(t * 6.0 + i) * 6.0
		var top := Vector2(x + 6 + sway, y - 46)
		draw_line(Vector2(x, y), Vector2(x + 3, y - 24), Color(0.5, 0.35, 0.2), 4.0)
		draw_line(Vector2(x + 3, y - 24), top, Color(0.5, 0.35, 0.2), 4.0)
		for k in 5:
			var a := -PI + k * PI / 4.0 + sin(t + i) * 0.1
			draw_line(top, top + Vector2(cos(a) * 18.0, sin(a) * 9.0 + 6.0), Color(0.2, 0.55, 0.22), 3.0)
	# Wellenbrecher: Tetrapoden-Haufen, die aus dem Wasser ragen
	for i in d.breakwater.level:
		var cx: float = BREAKWATER_X + i * 40.0
		var base := h_to_y(SEA_REST) + 26.0
		for k in 5:
			var p := Vector2(cx + (k % 3) * 12.0 - 12.0, base - 10.0 - (k / 3) * 12.0)
			_tetrapod(p, 9.0, k * 0.9 + i)
	# Warnboje
	if d.buoy.level > 0:
		var by := h_to_y(sea_h(BUOY_X))
		draw_colored_polygon(PackedVector2Array([Vector2(BUOY_X - 12, by), Vector2(BUOY_X + 12, by),
			Vector2(BUOY_X + 6, by - 22), Vector2(BUOY_X - 6, by - 22)]), Color(0.95, 0.75, 0.1))
		draw_rect(Rect2(BUOY_X - 7, by - 15, 14, 4), Color(0.85, 0.2, 0.15))
		draw_line(Vector2(BUOY_X, by - 22), Vector2(BUOY_X, by - 38), Color(0.3, 0.3, 0.3), 2.0)
		if fmod(t, 1.0) < 0.5:
			draw_circle(Vector2(BUOY_X, by - 40), 4, Color(1, 0.2, 0.2))
		_level_tag(Vector2(BUOY_X - 12, by - 48), d.buoy.level)


func _tetrapod(c: Vector2, r: float, rot: float) -> void:
	var col := Color(0.7, 0.7, 0.68)
	for k in 4:
		var a := rot + k * TAU / 4.0
		draw_line(c, c + Vector2.from_angle(a) * r, col, 5.0)
	draw_circle(c, 4.0, col.darkened(0.1))


func _draw_rocks(x: float) -> void:
	var j: float = sin(t * 50.0) * _hit.stone * 3.0
	var g := Color(0.5, 0.5, 0.53)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 44 + j, GROUND_Y), Vector2(x - 36 + j, GROUND_Y - 30),
		Vector2(x - 10 + j, GROUND_Y - 52), Vector2(x + 16 + j, GROUND_Y - 40), Vector2(x + 40 + j, GROUND_Y)]), g)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 8, GROUND_Y), Vector2(x + 8, GROUND_Y - 24),
		Vector2(x + 30, GROUND_Y - 28), Vector2(x + 48, GROUND_Y)]), g.darkened(0.15))
	draw_line(Vector2(x - 10 + j, GROUND_Y - 52), Vector2(x - 18 + j, GROUND_Y - 20), g.darkened(0.3), 2.0)
	draw_line(Vector2(x + 16 + j, GROUND_Y - 40), Vector2(x + 4 + j, GROUND_Y - 14), g.darkened(0.3), 2.0)


func _draw_trees() -> void:
	var j: float = sin(t * 45.0) * _hit.wood * 4.0
	var hs := [100.0, 118.0, 95.0]
	for i in 3:
		var x: float = TREE_XS[i]
		var h: float = hs[i]
		draw_rect(Rect2(x - 4, GROUND_Y - 26, 8, 26), Color(0.45, 0.3, 0.17))
		for k in 3:
			var base := GROUND_Y - 20.0 - k * h * 0.24
			var w := 22.0 - k * 5.0
			var sway: float = j + sin(t * 1.3 + i) * 1.5 * (k + 1) + storm * sin(t * 5.0 + i) * 3.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - w, base), Vector2(x + w, base),
				Vector2(x + sway, base - h * 0.42)]), Color(0.16, 0.45 + 0.05 * k, 0.2))


func _draw_sand(x: float) -> void:
	var j: float = _hit.sand * 4.0
	var pts := PackedVector2Array()
	for i in 21:
		var a := PI * i / 20.0
		pts.append(Vector2(x - cos(a) * 34.0, GROUND_Y - sin(a) * (30.0 - j)))
	draw_colored_polygon(pts, Color(0.9, 0.78, 0.5))
	for i in 5:
		draw_circle(Vector2(x - 20 + i * 10, GROUND_Y - 9 - (i % 3) * 6), 1.5, Color(0.75, 0.62, 0.38))


func _draw_resource_labels() -> void:
	if not game or game.level > 2:
		return
	var a := 0.6 + 0.4 * sin(t * 3.0)
	for kind in RESOURCE_RECTS:
		var r: Rect2 = RESOURCE_RECTS[kind]
		_text(Vector2(r.position.x + 2, r.position.y - 6), "Tipp: " + RESOURCE_LABELS[kind], 13, Color(1, 1, 1, a), true)


func _wheel(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color(0.15, 0.15, 0.15))
	draw_circle(c, r * 0.45, Color(0.6, 0.6, 0.6))


func _level_tag(pos: Vector2, lvl: int) -> void:
	_text(pos, "Lv %d" % lvl, 12, Color(1, 1, 0.8), true)


func _draw_excavator(x: float, lvl: int) -> void:
	var yel := Color(0.95, 0.72, 0.1)
	draw_rect(Rect2(x - 28, GROUND_Y - 13, 56, 13), Color(0.18, 0.18, 0.18))
	for i in 4:
		draw_circle(Vector2(x - 21 + i * 14, GROUND_Y - 6.5), 4.5, Color(0.45, 0.45, 0.45))
	draw_rect(Rect2(x - 22, GROUND_Y - 34, 44, 21), yel)
	draw_rect(Rect2(x - 2, GROUND_Y - 54, 22, 20), yel.darkened(0.1))
	draw_rect(Rect2(x + 2, GROUND_Y - 50, 14, 12), Color(0.6, 0.85, 1.0))
	var piv := Vector2(x - 18, GROUND_Y - 28)
	var a1 := deg_to_rad(-140.0 + 14.0 * sin(t * 2.2))
	var p1 := piv + Vector2.from_angle(a1) * 42.0
	var a2 := a1 - deg_to_rad(95.0 + 22.0 * sin(t * 2.2 + 1.2))
	var p2 := p1 + Vector2.from_angle(a2) * 32.0
	draw_line(piv, p1, yel.darkened(0.15), 7.0)
	draw_line(p1, p2, yel.darkened(0.25), 5.0)
	var bd := Vector2.from_angle(a2 + 1.2)
	draw_colored_polygon(PackedVector2Array([p2, p2 + bd * 14.0, p2 + Vector2.from_angle(a2) * 10.0 + bd * 5.0]), Color(0.3, 0.3, 0.3))
	_level_tag(Vector2(x - 12, GROUND_Y - 60), lvl)


func _draw_harvester(x: float, lvl: int) -> void:
	var green := Color(0.25, 0.6, 0.25)
	draw_rect(Rect2(x - 22, GROUND_Y - 30, 46, 18), green)
	draw_rect(Rect2(x + 4, GROUND_Y - 50, 20, 20), green.darkened(0.15))
	draw_rect(Rect2(x + 8, GROUND_Y - 46, 12, 11), Color(0.6, 0.85, 1.0))
	_wheel(Vector2(x - 13, GROUND_Y - 9), 9)
	_wheel(Vector2(x + 15, GROUND_Y - 9), 9)
	var piv := Vector2(x - 18, GROUND_Y - 30)
	var tip := piv + Vector2(-30 + 4 * sin(t * 3.0), -26 + 8 * sin(t * 1.7))
	draw_line(piv, tip, Color(0.3, 0.3, 0.3), 5.0)
	draw_circle(tip, 10, Color(0.7, 0.7, 0.75))
	for i in 6:
		var a := t * 14.0 + i * TAU / 6.0
		draw_line(tip, tip + Vector2.from_angle(a) * 10.0, Color(0.35, 0.35, 0.4), 2.0)
	_level_tag(Vector2(x - 6, GROUND_Y - 56), lvl)


func _draw_mixer(x: float, lvl: int) -> void:
	var red := Color(0.85, 0.25, 0.2)
	draw_rect(Rect2(x - 34, GROUND_Y - 22, 66, 9), Color(0.3, 0.3, 0.3))
	draw_rect(Rect2(x + 14, GROUND_Y - 42, 20, 24), red)
	draw_rect(Rect2(x + 19, GROUND_Y - 38, 11, 9), Color(0.6, 0.85, 1.0))
	_wheel(Vector2(x - 22, GROUND_Y - 9), 9)
	_wheel(Vector2(x + 22, GROUND_Y - 9), 9)
	var c := Vector2(x - 10, GROUND_Y - 38)
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * 24.0, sin(a) * 13.0).rotated(-0.25))
	draw_colored_polygon(pts, Color(0.9, 0.9, 0.88))
	for i in 3:
		var ph := fmod(t * 1.5 + i / 3.0, 1.0)
		var sx := lerpf(-20.0, 20.0, ph)
		var hh := 13.0 * sqrt(maxf(0.0, 1.0 - pow(sx / 24.0, 2.0)))
		draw_line(c + Vector2(sx - 5, -hh).rotated(-0.25), c + Vector2(sx + 5, hh).rotated(-0.25), red, 3.0)
	_level_tag(Vector2(x - 22, GROUND_Y - 56), lvl)


func _draw_village() -> void:
	var panic: bool = game.state == game.State.PREP and game.countdown < 12.0
	for i in game.houses.size():
		var hs: Dictionary = game.houses[i]
		var x: float = hs.x
		var roof := Color(0.75, 0.3, 0.2) if i % 2 == 0 else Color(0.35, 0.45, 0.7)
		if hs.alive:
			draw_rect(Rect2(x - 17, GROUND_Y - 26, 34, 26), Color(0.95, 0.9, 0.78))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 21, GROUND_Y - 25), Vector2(x + 21, GROUND_Y - 25),
				Vector2(x, GROUND_Y - 44)]), roof)
			draw_rect(Rect2(x - 12, GROUND_Y - 20, 9, 8), Color(1.0, 0.9, 0.5) if storm > 0.3 else Color(0.6, 0.85, 1.0))
			draw_rect(Rect2(x + 3, GROUND_Y - 16, 8, 16), Color(0.5, 0.33, 0.2))
			# Bewohner
			var px := x - 4.0 + (sin(t * 9.0 + i) * 6.0 if panic else sin(t * 0.7 + i * 2.0) * 3.0)
			var jump := absf(sin(t * 10.0 + i)) * 10.0 if cheer > 0.0 else 0.0
			_person(Vector2(px, GROUND_Y - jump), SHIRTS[i % SHIRTS.size()], cheer > 0.0 or panic)
		else:
			var k: float = _collapse.get(i, 1.0)
			if k < 0.9:
				var ang := k * 0.6
				var pts := PackedVector2Array()
				for p in [Vector2(-17, 0), Vector2(17, 0), Vector2(17, -26 * (1.0 - k)), Vector2(-17, -26 * (1.0 - k))]:
					pts.append(Vector2(x, GROUND_Y) + (p as Vector2).rotated(ang))
				draw_colored_polygon(pts, Color(0.95, 0.9, 0.78))
			for r in 5:
				var rx := x - 18 + r * 9
				draw_colored_polygon(PackedVector2Array([Vector2(rx, GROUND_Y), Vector2(rx + 10, GROUND_Y),
					Vector2(rx + 4, GROUND_Y - 6 - (r % 2) * 5)]), roof.darkened(0.3) if r % 2 == 0 else Color(0.6, 0.55, 0.5))


func _person(feet: Vector2, shirt: Color, arms_up: bool) -> void:
	var skin := Color(0.95, 0.8, 0.65)
	draw_line(feet + Vector2(-3, 0), feet + Vector2(0, -8), Color(0.2, 0.2, 0.3), 2.0)
	draw_line(feet + Vector2(3, 0), feet + Vector2(0, -8), Color(0.2, 0.2, 0.3), 2.0)
	draw_line(feet + Vector2(0, -8), feet + Vector2(0, -17), shirt, 4.0)
	var ay := -24.0 if arms_up else -10.0
	draw_line(feet + Vector2(0, -15), feet + Vector2(-5, ay), shirt, 2.0)
	draw_line(feet + Vector2(0, -15), feet + Vector2(5, ay), shirt, 2.0)
	draw_circle(feet + Vector2(0, -20), 3.5, skin)


func _draw_crane(x: float, lvl: int) -> void:
	var yel := Color(0.98, 0.78, 0.12)
	# Der Kran arbeitet an der Mauer, die gerade gebaut wird
	var tw: int = maxi(game.build_target(), 0)
	var tw_h := display_front_h if tw == 1 else display_wall_h
	var tallest := maxf(display_wall_h, display_front_h)
	var top_y := maxf(120.0, minf(GROUND_Y - 230.0, h_to_y(tallest) - 55.0))
	draw_line(Vector2(x - 7, GROUND_Y), Vector2(x - 7, top_y), yel, 3.0)
	draw_line(Vector2(x + 7, GROUND_Y), Vector2(x + 7, top_y), yel, 3.0)
	var y := GROUND_Y
	var left := true
	while y > top_y + 14.0:
		var ny := y - 16.0
		draw_line(Vector2(x - 7 if left else x + 7, y), Vector2(x + 7 if left else x - 7, ny), yel.darkened(0.2), 2.0)
		y = ny
		left = not left
	var jib_end := wall_left(tw) + wall_width(tw) + 30.0
	draw_line(Vector2(x - 46, top_y), Vector2(jib_end, top_y), yel, 5.0)
	draw_line(Vector2(x, top_y - 24), Vector2(jib_end, top_y), yel.darkened(0.2), 2.0)
	draw_line(Vector2(x, top_y - 24), Vector2(x - 46, top_y), yel.darkened(0.2), 2.0)
	draw_rect(Rect2(x - 52, top_y + 2, 16, 16), Color(0.4, 0.4, 0.4))
	draw_rect(Rect2(x - 6, top_y + 4, 14, 11), Color(0.6, 0.85, 1.0))
	var trolley_x := wall_left(tw) + wall_width(tw) * 0.5 + sin(t * 0.8) * 8.0
	var wall_top := h_to_y(tw_h)
	var hook_y := lerpf(top_y + 30.0, wall_top - 18.0, 0.5 + 0.5 * sin(t * 1.1)) if build_flash <= 0.0 \
		else lerpf(wall_top - 18.0, top_y + 30.0, build_flash)
	draw_rect(Rect2(trolley_x - 8, top_y + 2, 16, 6), Color(0.3, 0.3, 0.3))
	draw_line(Vector2(trolley_x, top_y + 8), Vector2(trolley_x, hook_y), Color(0.2, 0.2, 0.2), 1.5)
	draw_rect(Rect2(trolley_x - 14, hook_y, 28, 14), Color(0.6, 0.6, 0.62))
	_level_tag(Vector2(x + 10, top_y + 30), lvl)


## Zeichnet die hintere (w = 0) oder vordere (w = 1) Mauer Schicht für Schicht.
func _draw_wall(w: int) -> void:
	var x0 := wall_left(w)
	var ww := wall_width(w)
	var h := display_front_h if w == 1 else display_wall_h
	if w == 1:
		if h <= 0.01:
			return
		# Fundament der vorderen Mauer reicht bis auf den abfallenden Strand
		draw_rect(Rect2(x0, GROUND_Y, ww, _beach_y(x0 + ww) - GROUND_Y + 6.0), Color(0.5, 0.5, 0.5))
	elif h <= 0.01:
		_text(Vector2(x0 - 30, GROUND_Y - 10), "Bauplatz", 14, Color(1, 1, 1, 0.8), true)
		draw_rect(Rect2(x0, GROUND_Y - 4, ww, 4), Color(0.4, 0.4, 0.4))
		return
	var acc := 0.0
	var r := 0
	for i in game.layers.size():
		var layer: Dictionary = game.layers[i]
		if layer.w != w:
			continue
		var lh: float = layer.h
		if acc >= h:
			break
		var h1 := minf(h, acc + lh)
		var y0 := h_to_y(acc)
		var y1 := h_to_y(h1)
		var col: Color = MAT_COLORS[layer.m]
		col = col.lightened(0.05 * (r % 2))
		draw_rect(Rect2(x0, y1, ww, y0 - y1), col)
		draw_line(Vector2(x0, y1), Vector2(x0 + ww, y1), col.darkened(0.4), 1.0)
		if y0 - y1 > 6.0:
			match layer.m:
				"wood":
					for k in 3:
						var lx := x0 + ww * (k + 1) / 4.0
						draw_line(Vector2(lx, y0), Vector2(lx, y1), col.darkened(0.3), 1.0)
				"stone":
					var bx := x0 + (ww * 0.5 if r % 2 == 0 else ww * 0.25)
					draw_line(Vector2(bx, y0), Vector2(bx, y1), col.darkened(0.35), 1.0)
				"concrete":
					draw_line(Vector2(x0 + 4, (y0 + y1) * 0.5), Vector2(x0 + ww - 4, (y0 + y1) * 0.5), Color(0.45, 0.3, 0.25, 0.5), 1.0)
		if i == selected_layer:
			var pulse := 0.5 + 0.5 * sin(t * 8.0)
			draw_rect(Rect2(x0 - 3, y1 - 1, ww + 6, y0 - y1 + 2), Color(1, 0.9, 0.2, 0.25 + 0.25 * pulse))
			draw_rect(Rect2(x0 - 3, y1 - 1, ww + 6, y0 - y1 + 2), Color(1, 0.9, 0.2), false, 3.0)
		acc += lh
		r += 1
	var top := h_to_y(h)
	draw_rect(Rect2(x0 - 3, top - 5, ww + 6, 6), Color(0.35, 0.36, 0.4))
	# Beschädigung sichtbar machen
	var hp_ratio: float = game.wall_hp / maxf(game.wall_max_hp, 1.0)
	if hp_ratio < 0.7:
		var dmg := 1.0 - hp_ratio
		draw_rect(Rect2(x0, top, ww, GROUND_Y - top), Color(0.2, 0.1, 0.05, dmg * 0.35))
	if build_flash > 0.0 and game.build_target() == w:
		draw_rect(Rect2(x0 - 3, top - 5, ww + 6, 16), Color(1, 1, 0.6, build_flash * 0.6))
	_text(Vector2(x0 + 1, top - 10), "%.1f m" % h, 14, Color.WHITE, true)
	if w == 1:
		var total := display_wall_h + display_front_h
		_text(Vector2(x0 - 20, top - 28), "Schutz %.1f m" % total, 15, Color(0.7, 1.0, 0.7), true)


func _draw_cracks() -> void:
	for c in cracks:
		var p := crack_center(c)
		var x0 := wall_left(c.w)
		var ww := wall_width(c.w)
		var k: float = c.life / c.max
		var blink := 0.5 + 0.5 * sin(t * (10.0 + (1.0 - k) * 20.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(c.seed * 1000.0)
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(Vector2(x0 + i * ww / 6.0, p.y + rng.randf_range(-7, 7)))
		draw_polyline(pts, Color(0.15, 0.05, 0.05), 3.0)
		draw_circle(p, 30.0, Color(1, 0.2, 0.1, 0.12 + 0.18 * blink))
		draw_arc(p, 30.0, -PI / 2.0, -PI / 2.0 + TAU * k, 32, Color(1, 0.3 + 0.6 * k, 0.1), 5.0)
		_text(p + Vector2(34, 5), "TIPP!", 14, Color(1, 0.9, 0.3, 0.6 + 0.4 * blink), true)


func _draw_debris() -> void:
	for d in debris:
		var p := Vector2(d.x, _debris_y(d))
		draw_set_transform(p, d.rot)
		match d.kind:
			"boot":
				draw_colored_polygon(PackedVector2Array([Vector2(-28, -10), Vector2(28, -10), Vector2(18, 6), Vector2(-20, 6)]), Color(0.85, 0.85, 0.9))
				draw_rect(Rect2(-8, -24, 18, 14), Color(0.3, 0.5, 0.8))
				draw_line(Vector2(-28, -6), Vector2(28, -6), Color(0.8, 0.2, 0.2), 3.0)
			"container":
				draw_rect(Rect2(-26, -22, 52, 26), Color(0.8, 0.3, 0.15))
				for k in 6:
					draw_line(Vector2(-22 + k * 9, -20), Vector2(-22 + k * 9, 2), Color(0.55, 0.2, 0.1), 2.0)
			_:
				draw_rect(Rect2(-30, -9, 60, 14), Color(0.5, 0.33, 0.18))
				draw_circle(Vector2(30, -2), 7, Color(0.7, 0.55, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0)
		draw_arc(p + Vector2(0, -8), 36.0, 0, TAU, 32, Color(1, 0.9, 0.3, 0.5 + 0.4 * sin(t * 8.0)), 2.0)


## Wasser, das über eine Mauer schwappt und auf der Landseite herabstürzt
func _draw_cascade(x0: float, ww: float, level: float, wall_top: float, floor_y: float, water: Color) -> void:
	if wall_top <= 0.3 or h_to_y(level) + 10.0 >= h_to_y(wall_top):
		return
	var ys := h_to_y(level)
	var yw := h_to_y(wall_top)
	draw_colored_polygon(PackedVector2Array([Vector2(x0 + ww, ys), Vector2(x0, ys + 6.0),
		Vector2(x0, yw), Vector2(x0 + ww, yw)]), water)
	draw_colored_polygon(PackedVector2Array([Vector2(x0, ys + 6.0), Vector2(x0 - 30.0, minf(ys + 26.0, floor_y - 4.0)),
		Vector2(x0 - 34.0, floor_y), Vector2(x0, floor_y)]), water)


## Wasser zwischen vorderer und hinterer Mauer
func _draw_basin() -> void:
	if not has_front() or basin_h * px_per_m < 3.0:
		return
	var x0 := WALL_X + WALL_W
	var y := h_to_y(basin_h + 0.08 * sin(t * 4.0))
	draw_rect(Rect2(x0, y, FRONT_X - x0, _beach_y(FRONT_X) - y + 4.0), Color(0.15, 0.45, 0.7, 0.85))
	draw_line(Vector2(x0, y), Vector2(FRONT_X, y), Color(0.85, 0.95, 1.0, 0.8), 2.0)


func _draw_flood() -> void:
	var water := Color(0.15, 0.45, 0.7, 0.78)
	if has_front():
		_draw_cascade(FRONT_X, FRONT_W, sea_h(impact_x()), display_front_h, _beach_y(FRONT_X), water)
	_draw_cascade(WALL_X, WALL_W, level_at_back(), display_wall_h, GROUND_Y, water)
	if flood_h * px_per_m > 3.0 and flood_front < WALL_X - 12.0:
		var pts := PackedVector2Array()
		var x := WALL_X
		while x >= flood_front:
			pts.append(Vector2(x, h_to_y(flood_h + 0.1 * sin(x * 0.05 + t * 4.0))))
			x -= 10.0
		if pts.size() >= 2:
			pts.append(Vector2(flood_front, GROUND_Y))
			pts.append(Vector2(WALL_X, GROUND_Y))
			draw_colored_polygon(pts, water)
			draw_polyline(pts.slice(0, pts.size() - 2), Color(0.85, 0.95, 1.0, 0.8), 2.0)


func _draw_estimate() -> void:
	if not game:
		return
	if game.state == game.State.PREP:
		var e: Vector2 = game.estimate()
		var y0 := h_to_y(e.y)
		var y1 := h_to_y(e.x)
		var a := 0.18 + 0.08 * sin(t * 3.0)
		draw_rect(Rect2(WALL_X - 30, y0, W - WALL_X + 30, maxf(2.0, y1 - y0)), Color(1, 0.2, 0.15, a))
		draw_line(Vector2(WALL_X - 30, y0), Vector2(W, y0), Color(1, 0.3, 0.2, 0.8), 2.0)
		var label := "Erwartet: %.1f m" % e.y if is_equal_approx(e.x, e.y) else "Erwartet: %.1f – %.1f m" % [e.x, e.y]
		_text(Vector2(WALL_X + 140, maxf(y0 - 8, 132.0)), label, 17, Color(1, 0.6, 0.55), true)
	elif game.last_height > 0.0:
		var y := h_to_y(game.last_height)
		var x := WALL_X - 40.0
		while x < W - 10.0:
			draw_line(Vector2(x, y), Vector2(x + 14, y), Color(1, 0.25, 0.2, 0.9), 2.0)
			x += 24.0
		_text(Vector2(W - 210, y - 8), "Tsunami: %.1f m" % game.last_height, 17, Color(1, 0.55, 0.5), true)


func _draw_seismograph() -> void:
	if not game or game.state != game.State.PREP:
		return
	var r := Rect2(10, 112, 236, 74)
	draw_rect(r, Color(0.98, 0.97, 0.92, 0.92))
	draw_rect(r, Color(0.3, 0.3, 0.3), false, 2.0)
	var mag: float = game.quake_mag
	var pts := PackedVector2Array()
	var cy := r.position.y + 34.0
	for i in 110:
		var x := r.position.x + 6.0 + i * 2.05
		var age := fmod(t * 25.0 - i, 160.0)
		var burst := exp(-pow((age - 40.0) / 18.0, 2.0)) * (mag - 6.0) * 9.0
		var y := cy + sin(i * 2.7 + t * 30.0) * (1.5 + burst) * sin(i * 0.9 + t * 13.0)
		pts.append(Vector2(x, y))
	draw_polyline(pts, Color(0.75, 0.1, 0.1), 1.5)
	_text(r.position + Vector2(6, 16), "Seismograph", 12, Color(0.3, 0.3, 0.3))
	_text(r.position + Vector2(6, 68), "Erdbeben: Stärke %.1f" % mag, 15, Color(0.1, 0.1, 0.1))

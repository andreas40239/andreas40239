class_name CamRig
extends Node3D
## Kamerasteuerung: isometrische Übersicht (orthografisch), Verfolger- und Führerstandsicht.

enum Mode { ISO, CHASE, CAB }

const ELEV := deg_to_rad(36.0)
const ISO_DIST := 95.0
const MODE_NAMES := ["Übersicht", "Verfolger", "Führerstand"]

var cam: Camera3D
var mode: int = Mode.ISO
var focus := Vector3.ZERO
var zoom := 46.0                  # sichtbare Höhe in Welt-Einheiten (orthografisch)
var zoom_min := 14.0
var zoom_max := 90.0
var yaw_step := 0                 # Blickrichtung in 90°-Schritten
var bounds := Rect2(0, 0, 10, 10) # erlaubter Bereich für den Fokuspunkt
var target: Node3D = null         # Lok (für Verfolgung)
var follow := false
var target_dir := 1.0             # +1 vorwärts, -1 rückwärts (für die Blickrichtung)
var env: Environment
var sun: DirectionalLight3D

var _yaw := deg_to_rad(45.0)
var _chase_pos := Vector3.ZERO
var _chase_look := Vector3.ZERO
var _chase_init := false
var _focus_vel := Vector3.ZERO


func _ready() -> void:
	cam = Camera3D.new()
	cam.near = 0.3
	cam.far = 420.0
	add_child(cam)
	cam.make_current()
	_apply(1.0)


func set_mode(m: int) -> void:
	mode = m
	_chase_init = false
	if mode == Mode.ISO:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.near = 1.0
		cam.far = 400.0
		if env:
			env.fog_enabled = false
		if sun:
			sun.directional_shadow_max_distance = 260.0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	else:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 62.0 if mode == Mode.CHASE else 72.0
		cam.near = 0.15
		cam.far = 900.0
		if env:
			env.fog_enabled = true
		if sun:
			sun.directional_shadow_max_distance = 70.0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_apply(1.0)


func cycle_mode() -> int:
	set_mode((mode + 1) % 3)
	return mode


func rotate_step(dir: int) -> void:
	yaw_step = posmod(yaw_step + dir, 4)


func fit(world_w: float, world_h: float, aspect: float) -> void:
	## Wählt Fokus und Zoom so, dass das ganze Spielfeld sichtbar ist.
	focus = Vector3(world_w * 0.5, 0, world_h * 0.5)
	bounds = Rect2(0, 0, world_w, world_h)
	var diag := (world_w + world_h) * 0.7071
	var need_h := diag * sin(ELEV) + 3.0
	var need_w := diag + 4.0
	# Platz für die Leisten oben (ca. 10 %) und unten (ca. 18 %) freihalten
	zoom = maxf(need_h / 0.8, need_w / aspect)
	zoom_max = zoom * 1.25
	zoom = clampf(zoom, zoom_min, zoom_max)
	# Spielfeld etwas nach oben rücken (untere Leiste ist höher)
	var shift := zoom * 0.04
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	focus -= fwd * shift / sin(ELEV)


func _back_dir() -> Vector3:
	return Vector3(cos(ELEV) * sin(_yaw), sin(ELEV), cos(ELEV) * cos(_yaw))


func _process(dt: float) -> void:
	_apply(dt)


func _apply(dt: float) -> void:
	if cam == null:
		return
	var want_yaw := deg_to_rad(45.0 + 90.0 * yaw_step)
	_yaw = lerp_angle(_yaw, want_yaw, clampf(dt * 8.0, 0.0, 1.0))
	if mode == Mode.ISO:
		if follow and target != null:
			var k := clampf(dt * 3.0, 0.0, 1.0)
			focus = focus.lerp(Vector3(target.global_position.x, 0, target.global_position.z), k)
		focus.x = clampf(focus.x, bounds.position.x - 6.0, bounds.end.x + 6.0)
		focus.z = clampf(focus.z, bounds.position.y - 6.0, bounds.end.y + 6.0)
		cam.size = zoom
		cam.global_position = focus + _back_dir() * ISO_DIST
		cam.look_at(focus, Vector3.UP)
	elif target != null:
		var tb := target.global_transform.basis
		var fwd := -tb.z * target_dir
		var tp := target.global_position
		if mode == Mode.CHASE:
			var side := fwd.cross(Vector3.UP).normalized()
			var want_pos := tp - fwd * 13.5 + side * 4.2 + Vector3(0, 6.6, 0)
			var want_look := tp + fwd * 2.5 + Vector3(0, 1.0, 0)
			if not _chase_init:
				_chase_pos = want_pos
				_chase_look = want_look
				_chase_init = true
			var k := clampf(dt * 2.6, 0.0, 1.0)
			_chase_pos = _chase_pos.lerp(want_pos, k)
			_chase_look = _chase_look.lerp(want_look, clampf(dt * 5.0, 0.0, 1.0))
			cam.global_position = _chase_pos
			cam.look_at(_chase_look, Vector3.UP)
		else:
			var want_look := tp + fwd * 14.0 + Vector3(0, 1.3, 0)
			if not _chase_init:
				_chase_look = want_look
				_chase_init = true
			_chase_look = _chase_look.lerp(want_look, clampf(dt * 6.0, 0.0, 1.0))
			# Blick über das Führerhausdach nach vorn (rückwärts: vom Kohlenkasten nach hinten)
			var off := Vector3(0, 2.42, 0.1) if target_dir > 0.0 else Vector3(0, 2.5, 1.5)
			cam.global_position = target.global_transform * off
			cam.look_at(_chase_look, Vector3.UP)


# ---------------------------------------------------------------- Bedienung (nur Übersicht)

func pan_pixels(delta: Vector2) -> void:
	if mode != Mode.ISO:
		return
	var vh := float(get_viewport().get_visible_rect().size.y)
	var k := zoom / vh
	var right := cam.global_transform.basis.x
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	focus -= right * delta.x * k
	focus += fwd * delta.y * k / sin(ELEV)
	follow = false


func zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, zoom_min, zoom_max)


## Schnittpunkt des Bildschirmpunkts mit der Bodenebene (y = 0).
func ground_point(screen_pos: Vector2) -> Variant:
	var o := cam.project_ray_origin(screen_pos)
	var d := cam.project_ray_normal(screen_pos)
	if absf(d.y) < 1e-5:
		return null
	var t := -o.y / d.y
	if t < 0.0:
		return null
	return o + d * t

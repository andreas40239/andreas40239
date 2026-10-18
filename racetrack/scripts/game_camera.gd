class_name GameCamera
extends Camera3D
## Zwei Modi: Orbit-Kamera fuer den Editor und 3rd-Person-Verfolgerkamera
## (leicht erhoeht hinter dem Fahrzeug).

var target: Car = null

# Editor-Orbit
var orbit_target := Vector3.ZERO
var orbit_goal := Vector3.ZERO
var yaw := 0.0
var pitch := deg_to_rad(48.0)
var dist := 70.0
var dist_goal := 70.0

var _dir := Vector3.FORWARD
var _snap := true


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	near = 0.1
	far = 2000.0
	fov = 70.0


func follow(car: Car) -> void:
	target = car
	_snap = true


func edit_mode(goal: Vector3) -> void:
	target = null
	orbit_goal = goal
	orbit_target = goal
	fov = 60.0


func orbit_rotate(rel: Vector2) -> void:
	yaw -= rel.x * 0.006
	pitch = clampf(pitch + rel.y * 0.004, deg_to_rad(15.0), deg_to_rad(85.0))


func orbit_zoom(factor: float) -> void:
	dist_goal = clampf(dist_goal * factor, 18.0, 320.0)


func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		_chase(delta)
	else:
		_orbit(delta)


func _orbit(delta: float) -> void:
	var k := 1.0 - exp(-delta * 5.0)
	orbit_target = orbit_target.lerp(orbit_goal, k)
	dist = lerpf(dist, dist_goal, k)
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	global_position = orbit_target + off
	look_at(orbit_target, Vector3.UP)


func _chase(delta: float) -> void:
	var xf := target.get_global_transform_interpolated()
	var cfg := target.cfg
	var f := -xf.basis.z
	f.y = 0.0
	if f.length() > 0.05:
		f = f.normalized()
		# Rueckwaerts fahren: Kamera bleibt hinter dem Heck
		if _snap:
			_dir = f
		else:
			_dir = _dir.lerp(f, 1.0 - exp(-delta * 4.5)).normalized()
	var top: float = cfg["top"]
	var sr := clampf(absf(target.speed) / top, 0.0, 1.5)
	var d: float = cfg["cam_dist"] * (1.0 + sr * 0.12)
	var h: float = cfg["cam_h"]
	var desired := xf.origin - _dir * d + Vector3.UP * h
	if _snap:
		global_position = desired
		_snap = false
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-delta * 10.0))
	if global_position.y < 0.5:
		global_position.y = 0.5
	look_at(xf.origin + Vector3.UP * h * 0.42 + _dir * 2.0, Vector3.UP)
	fov = lerpf(fov, 70.0 + sr * 12.0, 1.0 - exp(-delta * 3.0))

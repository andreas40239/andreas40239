extends Node3D
## Moderne RTS-Kamera: WASD/Pfeile, Randscrollen, Mausrad-Zoom (zum Cursor),
## Q/E oder mittlere Maustaste zum Drehen/Neigen, weiche Bewegungen.

var cam: Camera3D
var focus := Vector3.ZERO
var focus_target := Vector3.ZERO
var yaw := 0.35
var yaw_target := 0.35
var pitch := deg_to_rad(57.0)
var pitch_target := deg_to_rad(57.0)
var dist := 30.0
var dist_target := 30.0
var bounds := Rect2(0, 0, 112, 112)
var edge_scroll := true
var input_enabled := true
var attract := false
var _mmb := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cam = Camera3D.new()
	cam.fov = 48.0
	cam.near = 0.3
	cam.far = 500.0
	add_child(cam)
	cam.current = true


func jump_to(p: Vector3, snap := false) -> void:
	focus_target = Vector3(p.x, 0, p.z)
	if snap:
		focus = focus_target


func _unhandled_input(e: InputEvent) -> void:
	if not input_enabled:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var f := 0.87 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.15
			var old := dist_target
			dist_target = clampf(dist_target * f, 9.0, 70.0)
			# Zoom Richtung Mauszeiger
			var hit = _ground_hit(mb.position)
			if hit != null and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				var k := 1.0 - dist_target / old
				focus_target += (Vector3(hit.x, 0, hit.z) - focus_target) * k
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mmb = mb.pressed
	elif e is InputEventMouseMotion and _mmb:
		var mm := e as InputEventMouseMotion
		yaw_target -= mm.relative.x * 0.006
		pitch_target = clampf(pitch_target + mm.relative.y * 0.004, deg_to_rad(30.0), deg_to_rad(82.0))


func _ground_hit(sp: Vector2):
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	if absf(d.y) < 0.001:
		return null
	var t := -o.y / d.y
	if t < 0:
		return null
	return o + d * t


func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.01)
	rd = minf(rd, 0.1)
	if attract:
		yaw_target += rd * 0.06
	elif input_enabled:
		var mv := Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			mv.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			mv.y += 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			mv.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			mv.x += 1
		if edge_scroll and DisplayServer.window_is_focused() and not _mmb:
			var vp := get_viewport()
			var mp := vp.get_mouse_position()
			var sz := vp.get_visible_rect().size
			var m := 5.0
			if mp.x >= 0 and mp.y >= 0 and mp.x <= sz.x and mp.y <= sz.y:
				if mp.x < m:
					mv.x -= 1
				elif mp.x > sz.x - m:
					mv.x += 1
				if mp.y < m:
					mv.y -= 1
				elif mp.y > sz.y - m:
					mv.y += 1
		if Input.is_key_pressed(KEY_Q):
			yaw_target += 1.8 * rd
		if Input.is_key_pressed(KEY_E):
			yaw_target -= 1.8 * rd
		if mv != Vector2.ZERO:
			mv = mv.normalized()
			var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
			var right := Vector3(cos(yaw), 0, -sin(yaw))
			var spd := dist * 1.15
			if Input.is_key_pressed(KEY_SHIFT):
				spd *= 2.0
			focus_target += (right * mv.x - fwd * mv.y) * spd * rd
	focus_target.x = clampf(focus_target.x, bounds.position.x, bounds.end.x)
	focus_target.z = clampf(focus_target.z, bounds.position.y, bounds.end.y)
	var k := 1.0 - exp(-12.0 * rd)
	focus = focus.lerp(focus_target, k)
	yaw = lerp_angle(yaw, yaw_target, k)
	pitch = lerpf(pitch, pitch_target, k)
	dist = lerpf(dist, dist_target, k)
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.global_position = focus + off
	cam.look_at(focus, Vector3.UP)

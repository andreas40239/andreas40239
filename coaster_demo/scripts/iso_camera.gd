class_name IsoCameraRig
extends Node3D
## Isometrische Orthogonal-Kamera: Drehen (Yaw/Pitch), Zoomen, Verschieben.

const MIN_ZOOM := 10.0
const MAX_ZOOM := 110.0
const MIN_PITCH := -80.0
const MAX_PITCH := -15.0

var yaw := 45.0
var pitch := -35.264   # klassischer Isometrie-Winkel
var zoom := 55.0
var bounds := Rect2(0, 0, 96, 96)

var cam: Camera3D


func _ready() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.5
	cam.far = 600.0
	cam.position = Vector3(0, 0, 200)
	add_child(cam)
	_apply()


func _apply() -> void:
	rotation_degrees = Vector3(pitch, yaw, 0)
	cam.size = zoom


func rotate_view(d_yaw: float, d_pitch: float) -> void:
	yaw = fposmod(yaw + d_yaw, 360.0)
	pitch = clampf(pitch + d_pitch, MIN_PITCH, MAX_PITCH)
	_apply()


func zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	_apply()


## Verschiebt die Ansicht um ein Bildschirm-Delta (Pixel), Inhalt folgt dem Finger.
func pan(screen_delta: Vector2) -> void:
	var vp_h := get_viewport().get_visible_rect().size.y
	var k := zoom / maxf(vp_h, 1.0)
	var right := global_basis.x
	right.y = 0
	right = right.normalized()
	var fwd := -global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var s := maxf(sin(deg_to_rad(-pitch)), 0.2)
	position -= right * screen_delta.x * k
	position += fwd * screen_delta.y * k / s
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z, bounds.position.y, bounds.end.y)


func make_current() -> void:
	cam.make_current()

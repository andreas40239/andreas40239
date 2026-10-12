extends Node3D
## Third-person camera at hedgehog height. Drag with the mouse, use the
## right stick or Z/X to look around. Lowers to nose height while sniffing,
## and slowly circles the nest during hibernation.

@export var target_path: NodePath
@export var distance := 3.2
@export var sniff_distance := 2.0
@export var height := 0.35
@export var mouse_sensitivity := 0.005
@export var turn_speed := 2.2

## 0..1, set by the level while the hedgehog sniffs.
var sniff_amount := 0.0
var yaw := 0.0
var pitch := -0.38

var _orbiting := false
var _dragging := false
var _target: Node3D

@onready var _arm: SpringArm3D = $SpringArm3D


func _ready() -> void:
	top_level = true
	_target = get_node_or_null(target_path)
	_arm.collision_mask = 1
	if _target:
		global_position = _target.global_position + Vector3.UP * height


## Turns the camera by a screen-space drag (used by touch swipes).
func rotate_by(radians: Vector2) -> void:
	if _orbiting:
		return
	yaw -= radians.x
	pitch = clampf(pitch - radians.y, -1.2, -0.05)


func start_orbit() -> void:
	_orbiting = true
	# Rise above the garden even if the hedgehog sleeps under the shed.
	_arm.collision_mask = 0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging and not _orbiting:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.2, -0.05)


func _process(delta: float) -> void:
	if _target == null:
		return
	var follow := _target.global_position + Vector3.UP * height
	global_position = global_position.lerp(follow, 1.0 - exp(-10.0 * delta))

	if _orbiting:
		yaw += delta * 0.25
		pitch = lerpf(pitch, -0.75, delta)
		_arm.spring_length = lerpf(_arm.spring_length, distance * 2.5, delta)
	else:
		yaw -= Input.get_axis("cam_left", "cam_right") * turn_speed * delta
		var sniff_pitch := lerpf(pitch, -0.12, sniff_amount)
		rotation = Vector3(sniff_pitch, yaw, 0.0)
		_arm.spring_length = lerpf(distance, sniff_distance, sniff_amount)
		return
	rotation = Vector3(pitch, yaw, 0.0)

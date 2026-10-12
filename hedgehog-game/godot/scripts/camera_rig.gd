extends Node3D
## Third-person camera at hedgehog height. Drag with the mouse, use the
## right stick or Z / X to look around. Lowers to nose height while sniffing,
## and slowly circles the nest during hibernation.
##
## Walls and tree trunks push the camera closer. This is done with a sphere
## cast (not a thin ray) and smoothed: the camera moves in quickly but eases
## back out slowly, so it can't flicker back and forth next to an obstacle.

@export var target_path: NodePath
@export var distance := 3.2
@export var sniff_distance := 2.0
@export var height := 0.35
@export var mouse_sensitivity := 0.005
@export var turn_speed := 2.2
## Radius of the sphere swept from the hedgehog to the camera.
@export var camera_radius := 0.22
@export var min_distance := 0.6

## 0..1, set by the level while the hedgehog sniffs.
var sniff_amount := 0.0
var yaw := 0.0
var pitch := -0.38

var _orbiting := false
var _dragging := false
var _target: Node3D
var _arm_length := 3.2
var _sphere := SphereShape3D.new()

@onready var _arm: SpringArm3D = $SpringArm3D


func _ready() -> void:
	top_level = true
	_target = get_node_or_null(target_path)
	# Collisions are handled here (smoothed), not by the SpringArm3D.
	_arm.collision_mask = 0
	_sphere.radius = camera_radius
	_arm_length = distance
	if _target:
		global_position = _target.global_position + Vector3.UP * height


## Turns the camera by a screen-space drag (used by touch swipes).
func rotate_by(radians: Vector2) -> void:
	if _orbiting:
		return
	yaw -= radians.x
	pitch = clampf(pitch - radians.y, -1.2, -0.05)


## Moves the camera to the hedgehog at once (after a respawn).
func snap_to_target() -> void:
	if _target:
		global_position = _target.global_position + Vector3.UP * height
		_arm_length = _safe_length(lerpf(distance, sniff_distance, sniff_amount))
		_arm.spring_length = _arm_length


func start_orbit() -> void:
	_orbiting = true


func _unhandled_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return  # Touches are handled by the touch controls.
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

	var wanted: float
	if _orbiting:
		# Rise above the garden even if the hedgehog sleeps under the shed.
		yaw += delta * 0.25
		pitch = lerpf(pitch, -0.75, delta)
		rotation = Vector3(pitch, yaw, 0.0)
		_arm_length = lerpf(_arm_length, distance * 2.5, delta)
		_arm.spring_length = _arm_length
		return

	yaw -= Input.get_axis("cam_left", "cam_right") * turn_speed * delta
	rotation = Vector3(lerpf(pitch, -0.12, sniff_amount), yaw, 0.0)
	wanted = lerpf(distance, sniff_distance, sniff_amount)
	var safe := _safe_length(wanted)
	if safe < _arm_length:
		_arm_length = lerpf(_arm_length, safe, 1.0 - exp(-30.0 * delta))
	else:
		_arm_length = lerpf(_arm_length, safe, 1.0 - exp(-2.5 * delta))
	_arm.spring_length = _arm_length


## How far the camera can be from the hedgehog without being inside a wall.
func _safe_length(length: float) -> float:
	var space := get_world_3d().direct_space_state
	var back := global_transform.basis.z
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.motion = back * length
	query.collision_mask = 1
	var result := space.cast_motion(query)
	if result.size() > 0 and result[0] > 0.0:
		return maxf(length * result[0], min_distance)
	# The sphere already touches something at the start (e.g. under the
	# shed): fall back to a thin ray.
	var ray := PhysicsRayQueryParameters3D.create(global_position, global_position + back * length, 1)
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return length
	return maxf(global_position.distance_to(hit["position"]) - 0.1, min_distance)

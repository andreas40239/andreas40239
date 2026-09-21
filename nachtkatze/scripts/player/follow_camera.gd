extends Camera3D
class_name FollowCamera
## Seitliche Verfolgerkamera mit fester Ausrichtung (GDD Abschnitt 13).
## Horizontal zieht sie zuegig nach, vertikal deutlich traeger und mit
## Totzone, damit kleine Spruenge das Bild nicht schaukeln lassen.

@export var target_path: NodePath
@export var offset := Vector3(0.0, 1.4, 9.0)
@export var horizontal_smoothing := 6.0
@export var vertical_smoothing := 2.5
## Hoehenaenderungen innerhalb dieser Spanne bewegen die Kamera nicht.
@export var vertical_deadzone := 0.8
## Vorausschau in Laufrichtung.
@export var look_ahead := 1.2
@export var look_ahead_smoothing := 2.0

var _target: Node3D = null
var _look_ahead_current := 0.0
var _vertical_anchor := 0.0

func _ready() -> void:
	_resolve_target()
	if _target != null:
		_vertical_anchor = _target.global_position.y
		global_position = _desired_position()
	rotation = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if _target == null:
		_resolve_target()
		if _target == null:
			return
	var target_y := _target.global_position.y
	if absf(target_y - _vertical_anchor) > vertical_deadzone:
		_vertical_anchor = target_y - signf(target_y - _vertical_anchor) * vertical_deadzone

	var facing := 1.0
	if _target is Player:
		facing = (_target as Player).facing
	_look_ahead_current = lerpf(_look_ahead_current, facing * look_ahead,
		_smoothing_weight(look_ahead_smoothing, delta))

	var desired := _desired_position()
	global_position.x = lerpf(global_position.x, desired.x,
		_smoothing_weight(horizontal_smoothing, delta))
	global_position.y = lerpf(global_position.y, desired.y,
		_smoothing_weight(vertical_smoothing, delta))
	global_position.z = desired.z
	rotation = Vector3.ZERO

func _desired_position() -> Vector3:
	return Vector3(
		_target.global_position.x + offset.x + _look_ahead_current,
		_vertical_anchor + offset.y,
		offset.z)

## Bildratenunabhaengige Glaettung.
func _smoothing_weight(speed: float, delta: float) -> float:
	return 1.0 - exp(-speed * delta)

func _resolve_target() -> void:
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		_target = get_tree().get_first_node_in_group("player") as Node3D

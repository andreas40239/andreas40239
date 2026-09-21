extends Camera3D
class_name FollowCamera
## Seitliche Verfolgerkamera mit fester Ausrichtung (GDD Abschnitt 13).
##
## Horizontal zieht sie zuegig nach. Vertikal gilt eine Besonderheit aus dem
## Spieltest: beim Steigen darf sie traege sein, damit kleine Spruenge das Bild
## nicht schaukeln lassen - beim Fallen und Herunterklettern muss sie dagegen
## schnell mitgehen, sonst sieht man den Landeplatz nicht.

@export var target_path: NodePath
@export var offset := Vector3(0.0, 1.0, 7.0)
@export var horizontal_smoothing := 6.0
## Nachziehen beim Steigen.
@export var vertical_smoothing := 2.5
## Nachziehen beim Fallen und Herunterklettern.
@export var fall_smoothing := 12.0
## Hoehenaenderungen innerhalb dieser Spanne bewegen die Kamera nicht.
@export var vertical_deadzone := 0.8
## Beim Fallen schrumpft die Totzone, damit die Kamera sofort mitgeht.
@export var fall_deadzone := 0.05
## Zusaetzlicher Blick nach unten, abhaengig von der Fallgeschwindigkeit.
@export var fall_look_down := 1.6
## Fallgeschwindigkeit, ab der voll nach unten geschaut wird.
@export var fall_look_down_speed := 10.0
@export var look_ahead := 1.2
@export var look_ahead_smoothing := 2.0

var _target: Node3D = null
var _look_ahead_current := 0.0
var _look_down_current := 0.0
var _vertical_anchor := 0.0
var _last_target_y := 0.0

func _ready() -> void:
	_resolve_target()
	if _target != null:
		_vertical_anchor = _target.global_position.y
		_last_target_y = _vertical_anchor
		global_position = _desired_position()
	rotation = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if _target == null:
		_resolve_target()
		if _target == null:
			return

	var target_y := _target.global_position.y
	var fall_speed := _fall_speed(target_y, delta)
	var falling := fall_speed > 0.5

	# Beim Fallen faellt die Totzone praktisch weg.
	var deadzone := fall_deadzone if falling else vertical_deadzone
	var difference := target_y - _vertical_anchor
	if absf(difference) > deadzone:
		_vertical_anchor = target_y - signf(difference) * deadzone

	var facing := 1.0
	if _target is Player:
		facing = (_target as Player).facing
	_look_ahead_current = lerpf(_look_ahead_current, facing * look_ahead,
		_smoothing_weight(look_ahead_smoothing, delta))
	var look_down_goal := clampf(fall_speed / fall_look_down_speed, 0.0, 1.0) * fall_look_down
	_look_down_current = lerpf(_look_down_current, look_down_goal,
		_smoothing_weight(fall_smoothing if falling else 4.0, delta))

	var desired := _desired_position()
	global_position.x = lerpf(global_position.x, desired.x,
		_smoothing_weight(horizontal_smoothing, delta))
	global_position.y = lerpf(global_position.y, desired.y,
		_smoothing_weight(fall_smoothing if falling else vertical_smoothing, delta))
	global_position.z = desired.z
	rotation = Vector3.ZERO
	_last_target_y = target_y

## Fallgeschwindigkeit in m/s (positiv beim Sinken). Nutzt die Geschwindigkeit
## des Koerpers, sonst die Hoehenaenderung seit dem letzten Schritt.
func _fall_speed(target_y: float, delta: float) -> float:
	if _target is CharacterBody3D:
		return maxf(-(_target as CharacterBody3D).velocity.y, 0.0)
	if delta <= 0.0:
		return 0.0
	return maxf((_last_target_y - target_y) / delta, 0.0)

func _desired_position() -> Vector3:
	return Vector3(
		_target.global_position.x + offset.x + _look_ahead_current,
		_vertical_anchor + offset.y - _look_down_current,
		offset.z)

## Bildratenunabhaengige Glaettung.
func _smoothing_weight(speed: float, delta: float) -> float:
	return 1.0 - exp(-speed * delta)

func _resolve_target() -> void:
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		_target = get_tree().get_first_node_in_group("player") as Node3D

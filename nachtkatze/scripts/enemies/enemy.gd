extends CharacterBody3D
class_name Enemy
## Gemeinsame Basis der Gegner (GDD Abschnitt 4).
##
## Regelt, was alle teilen: Schwerkraft, Treffer bei Beruehrung, das
## Warnzeichen vor dem Angriff und das Finden der Spielerkatze. Die
## Zustandsautomaten stehen in den abgeleiteten Skripten.

## Gleiche Schwerkraft wie die Spielerkatze, damit Spruenge vergleichbar sind.
const GRAVITY := Player.GRAVITY
const MAX_FALL_SPEED := 20.0

@export var damage: int = 1
## Warnzeit vor dem Angriff (GDD Abschnitt 4: 0,6 bis 0,8 s).
@export_range(0.3, 1.5, 0.05) var warning_time: float = 0.7
## Passive Gegner warnen nur und greifen nie an (Tutorial, GDD Abschnitt 7).
@export var passive: bool = false

var home_position := Vector3.ZERO

var _player: Player = null
var _warning_pulse := 0.0

@onready var visual: Node3D = get_node_or_null("Visual")
@onready var warning_sign: Node3D = get_node_or_null("Visual/WarnZeichen")
@onready var hitbox: Area3D = get_node_or_null("Hitbox")

func _ready() -> void:
	add_to_group("enemy")
	home_position = global_position
	collision_layer = 64   # Gegner
	collision_mask = 1     # Welt
	_set_warning_visible(false)
	_find_player()

func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player

## Von den abgeleiteten Skripten jeden Physikschritt aufrufen.
func _tick_common(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_find_player()
	_damage_on_contact()
	if warning_sign != null and warning_sign.visible:
		_warning_pulse += delta
		var pulse := 1.0 + sin(_warning_pulse * 12.0) * 0.18
		warning_sign.scale = Vector3(pulse, pulse, pulse)

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = maxf(velocity.y, -0.1)
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL_SPEED)

## Beruehrung kostet einen Lebenspunkt (GDD Abschnitt 3). Die Katze ignoriert
## den Treffer selbst, solange sie unverwundbar ist.
func _damage_on_contact() -> void:
	if hitbox == null or not is_dangerous():
		return
	for body in hitbox.get_overlapping_bodies():
		var player := body as Player
		if player != null:
			player.take_damage(damage, global_position)

## Passive Gegner (Tutorial) tun nichts; Abgeleitete koennen weiter einschraenken.
func is_dangerous() -> bool:
	return not passive

func _set_warning_visible(value: bool) -> void:
	if warning_sign != null:
		warning_sign.visible = value
		if value:
			_warning_pulse = 0.0
		else:
			warning_sign.scale = Vector3.ONE

## Blickrichtung: 1 = rechts, -1 = links.
func _face(direction: float) -> void:
	if visual == null or is_zero_approx(direction):
		return
	visual.rotation.y = 0.0 if direction > 0.0 else PI

func _player_delta() -> Vector3:
	if _player == null:
		return Vector3(INF, INF, 0.0)
	return _player.global_position - global_position

## Ist die Katze in Reichweite? max_height trennt Strassen- von Fassadenebene.
func _player_in_range(radius: float, max_height: float) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _player.state in [Player.State.DEAD, Player.State.VICTORY]:
		return false
	var delta := _player_delta()
	return absf(delta.x) <= radius and absf(delta.y) <= max_height

func _lock_z_axis() -> void:
	global_position.z = 0.0
	velocity.z = 0.0

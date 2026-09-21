extends Area3D
class_name Car
## Fahrendes Auto (GDD Abschnitt 4, ab Level 4).
##
## Zustaende: Warten -> Warnung (Scheinwerfer kuendigt an) -> Fahren.
## Das Auto setzt sich relativ zur Spielerkatze an, damit die Warnung auch
## sichtbar ist, und faehrt dann an ihr vorbei. Ein Treffer kostet einen
## Lebenspunkt mit Rueckstoss - kein Sofort-Aus.

enum State { WARTEN, WARNUNG, FAHREN }

@export var damage: int = 1
## -1 faehrt nach links, 1 nach rechts.
@export_range(-1, 1, 2) var drive_direction: int = -1
@export var speed: float = 9.0
## Abstand, in dem das Auto vor der Katze auftaucht (ausserhalb des Bildes).
@export var spawn_distance: float = 13.0
## Strecke, die es danach faehrt.
@export var travel_length: float = 28.0
## Pause zwischen zwei Durchfahrten.
@export var pause_time: float = 5.0
@export var warning_time: float = 0.8

var state: State = State.WARTEN

var _timer := 0.0
var _travelled := 0.0
var _player: Player = null

@onready var visual: Node3D = get_node_or_null("Visual")
@onready var headlight: Node3D = get_node_or_null("Visual/Scheinwerfer")
@onready var lamp: OmniLight3D = get_node_or_null("Visual/Scheinwerfer/Licht")

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 32   # Gefahr
	collision_mask = 2     # Spieler
	monitoring = true
	_player = get_tree().get_first_node_in_group("player") as Player
	_enter(State.WARTEN, pause_time)

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	_timer -= delta

	match state:
		State.WARTEN:
			_set_visible(false)
			if _timer <= 0.0:
				_place_ahead_of_player()
				_enter(State.WARNUNG, warning_time)
		State.WARNUNG:
			# Das Auto steht noch ausserhalb des Bildes, nur sein Scheinwerfer
			# leuchtet voraus.
			_set_visible(true)
			if _timer <= 0.0:
				_enter(State.FAHREN, 0.0)
				_travelled = 0.0
		State.FAHREN:
			var step := speed * delta
			position.x += float(drive_direction) * step
			_travelled += step
			_damage_on_contact()
			if _travelled >= travel_length:
				_enter(State.WARTEN, pause_time)

## Setzt den Durchfahrtszyklus neu an.
func restart_cycle(pause: float = 0.0) -> void:
	_enter(State.WARTEN, pause)

func _damage_on_contact() -> void:
	for body in get_overlapping_bodies():
		var player := body as Player
		if player != null:
			player.take_damage(damage, global_position)

func _place_ahead_of_player() -> void:
	var reference_x := _player.global_position.x if _player != null else 0.0
	position.x = reference_x - float(drive_direction) * spawn_distance
	# Scheinwerfer zeigen in Fahrtrichtung.
	if headlight != null:
		headlight.position.x = absf(headlight.position.x) * float(drive_direction)
	if visual != null:
		visual.rotation.y = 0.0 if drive_direction > 0 else PI

func _set_visible(value: bool) -> void:
	if visual != null:
		visual.visible = value
	if lamp != null:
		lamp.visible = value
	set_deferred("monitoring", value)

func _enter(new_state: State, duration: float) -> void:
	state = new_state
	_timer = duration

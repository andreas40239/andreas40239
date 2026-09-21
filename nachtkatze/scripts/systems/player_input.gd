extends Node
## Autoload "PlayerInput": buendelt Touch-Steuerung (GDD Abschnitt 2) und Tastatur.
##
## Touch ist die Zielsteuerung auf Android; die Tastatur (Pfeiltasten + Leertaste)
## existiert nur fuer das Testen am Entwicklungsrechner.

## Werte unterhalb dieser Schwelle gelten als "kein Ausschlag".
const DEADZONE := 0.2

## Richtung vom virtuellen Joystick, Wertebereich -1..1 je Achse.
var touch_move: Vector2 = Vector2.ZERO

var _jump_buffered: bool = false
var _jump_held: bool = false

func set_touch_move(value: Vector2) -> void:
	touch_move = value.limit_length(1.0)

func press_jump() -> void:
	_jump_buffered = true
	_jump_held = true

func release_jump() -> void:
	_jump_held = false

## Kombinierte Bewegungsrichtung: x = links/rechts, y = hoch/runter (Klettern).
func get_move_vector() -> Vector2:
	var keyboard := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down"))
	var combined := keyboard + touch_move
	if absf(combined.x) < DEADZONE:
		combined.x = 0.0
	if absf(combined.y) < DEADZONE:
		combined.y = 0.0
	return combined.limit_length(1.0)

## Gibt genau einmal true zurueck, wenn Springen ausgeloest wurde.
func consume_jump() -> bool:
	if _jump_buffered:
		_jump_buffered = false
		return true
	return Input.is_action_just_pressed("ui_accept")

func is_jump_held() -> bool:
	return _jump_held or Input.is_action_pressed("ui_accept")

## Beim Szenenwechsel zuruecksetzen, damit kein Tastendruck haengen bleibt.
func reset() -> void:
	touch_move = Vector2.ZERO
	_jump_buffered = false
	_jump_held = false

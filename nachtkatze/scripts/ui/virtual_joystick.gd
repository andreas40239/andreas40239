extends Control
class_name VirtualJoystick
## Virtueller Joystick fuer die linke Bildschirmhaelfte (GDD Abschnitt 2):
## links/rechts zum Laufen, hoch/runter zum Klettern.
##
## Der Ring erscheint dort, wo der Finger aufsetzt - das trifft auf kleinen
## Geraeten deutlich zuverlaessiger als ein fest platzierter Ring.

const BASE_COLOR := Color(0.95, 0.95, 1.0, 0.14)
const RING_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const KNOB_COLOR := Color(0.98, 0.78, 0.40, 0.75)

## Radius, ab dem der Ausschlag als voll gilt.
@export var radius := 110.0
## Ausschlag unterhalb dieses Anteils wird als Null gewertet.
@export var deadzone_ratio := 0.18

var output := Vector2.ZERO

var _active_pointer: int = -99
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_origin = size * 0.5
	_knob = _origin

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _active_pointer == -99:
			_begin(touch.index, touch.position)
		elif not touch.pressed and _active_pointer == touch.index:
			_end()
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _active_pointer == drag.index:
			_update(drag.position)
			accept_event()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed and _active_pointer == -99:
			_begin(-1, click.position)
		elif not click.pressed and _active_pointer == -1:
			_end()
		accept_event()
	elif event is InputEventMouseMotion and _active_pointer == -1:
		_update((event as InputEventMouseMotion).position)
		accept_event()

func _exit_tree() -> void:
	_end()

func _begin(pointer: int, position_in_control: Vector2) -> void:
	_active_pointer = pointer
	_origin = position_in_control
	_update(position_in_control)

func _update(position_in_control: Vector2) -> void:
	var delta := (position_in_control - _origin).limit_length(radius)
	_knob = _origin + delta
	var value := delta / radius
	if value.length() < deadzone_ratio:
		value = Vector2.ZERO
	# Bildschirmkoordinaten zeigen nach unten, Spielrichtung nach oben.
	output = Vector2(value.x, -value.y)
	PlayerInput.set_touch_move(output)
	queue_redraw()

func _end() -> void:
	_active_pointer = -99
	output = Vector2.ZERO
	PlayerInput.set_touch_move(Vector2.ZERO)
	_knob = _origin
	queue_redraw()

func _draw() -> void:
	if _active_pointer == -99:
		# Ruhezustand: dezenter Hinweis in der Mitte des Bereichs.
		var idle_center := size * 0.5
		draw_circle(idle_center, radius * 0.55, BASE_COLOR)
		draw_arc(idle_center, radius * 0.55, 0.0, TAU, 48, RING_COLOR, 3.0, true)
		return
	draw_circle(_origin, radius, BASE_COLOR)
	draw_arc(_origin, radius, 0.0, TAU, 64, RING_COLOR, 3.0, true)
	draw_circle(_knob, radius * 0.33, KNOB_COLOR)

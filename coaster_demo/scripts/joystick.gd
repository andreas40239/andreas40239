class_name VirtualJoystick
extends Control
## Virtueller Touch-Joystick. `output` liegt in [-1, 1] je Achse.
## Funktioniert auch mit der Maus (Desktop-Test).

@export var radius := 80.0
@export var knob_radius := 34.0
@export var dead_zone := 0.12

var output := Vector2.ZERO
var _touch := -1
var _mouse := false
var _knob := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(radius, radius) * 2.0 + Vector2(16, 16)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func owns_touch(index: int) -> bool:
	return index == _touch


func _center() -> Vector2:
	return size * 0.5


func _hit(global_pos: Vector2) -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(global_pos)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1 and _hit(event.position):
			_touch = event.index
			_update(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch:
			_touch = -1
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _touch:
			_update(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed and _hit(event.position):
			_mouse = true
			_update(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _mouse:
			_mouse = false
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		_update(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION and _touch != -1:
		# Emulierte Maus-Events des Joystick-Fingers nicht an die GUI weiterreichen.
		get_viewport().set_input_as_handled()


func _update(global_pos: Vector2) -> void:
	var local := global_pos - get_global_rect().position - _center()
	_knob = local.limit_length(radius)
	var v := _knob / radius
	output = Vector2.ZERO if v.length() < dead_zone else v
	queue_redraw()


func _release() -> void:
	_knob = Vector2.ZERO
	output = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c := _center()
	draw_circle(c, radius, Color(0.1, 0.1, 0.12, 0.35))
	draw_arc(c, radius, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0, true)
	draw_line(c + Vector2(-radius * 0.6, 0), c + Vector2(radius * 0.6, 0), Color(1, 1, 1, 0.15), 2)
	draw_line(c + Vector2(0, -radius * 0.6), c + Vector2(0, radius * 0.6), Color(1, 1, 1, 0.15), 2)
	var active := _touch != -1 or _mouse
	draw_circle(c + _knob, knob_radius, Color(0.9, 0.9, 0.92, 0.9 if active else 0.6))

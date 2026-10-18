class_name TouchControls
extends Control
## Multitouch-Steuerung: Lenkrad links unten, grosser Gas-Button rechts unten,
## kleinerer Brems-Button daneben.

const WHEEL_R := 120.0
const GAS_R := 98.0
const BRAKE_R := 62.0
const MAX_ANGLE := 120.0
const MARGIN := 36.0

var steer := 0.0
var gas := false
var brake := false
var wheel_angle := 0.0

var _touches := {}   # index -> Rolle
var _last_angle := 0.0
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func wheel_center() -> Vector2:
	return Vector2(MARGIN + WHEEL_R, size.y - MARGIN - WHEEL_R)


func gas_center() -> Vector2:
	return Vector2(size.x - MARGIN - GAS_R, size.y - MARGIN - GAS_R)


func brake_center() -> Vector2:
	var g := gas_center()
	return Vector2(g.x - GAS_R - 34.0 - BRAKE_R, size.y - MARGIN - BRAKE_R)


func release_all() -> void:
	_touches.clear()
	gas = false
	brake = false


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var ev := make_input_local(event) as InputEventScreenTouch
		var p := ev.position
		if ev.pressed:
			var role := ""
			if p.distance_to(wheel_center()) < WHEEL_R * 1.35:
				role = "wheel"
				_last_angle = (p - wheel_center()).angle()
			elif p.distance_to(brake_center()) < BRAKE_R * 1.3:
				role = "brake"
			elif p.distance_to(gas_center()) < GAS_R * 1.3:
				role = "gas"
			if role != "":
				_touches[ev.index] = role
				get_viewport().set_input_as_handled()
		elif _touches.has(ev.index):
			_touches.erase(ev.index)
			get_viewport().set_input_as_handled()
		_update_buttons()
	elif event is InputEventScreenDrag:
		var ev := make_input_local(event) as InputEventScreenDrag
		if _touches.get(ev.index, "") == "wheel":
			var rel := ev.position - wheel_center()
			if rel.length() > 18.0:
				var a := rel.angle()
				var d := wrapf(a - _last_angle, -PI, PI)
				_last_angle = a
				wheel_angle = clampf(wheel_angle + rad_to_deg(d), -MAX_ANGLE, MAX_ANGLE)
			get_viewport().set_input_as_handled()


func _update_buttons() -> void:
	gas = false
	brake = false
	for r in _touches.values():
		if r == "gas":
			gas = true
		elif r == "brake":
			brake = true


func _wheel_held() -> bool:
	for r in _touches.values():
		if r == "wheel":
			return true
	return false


func _process(delta: float) -> void:
	if not _wheel_held():
		wheel_angle = move_toward(wheel_angle, 0.0, 420.0 * delta)
	steer = wheel_angle / MAX_ANGLE
	queue_redraw()


func _draw() -> void:
	var c := wheel_center()
	var a := deg_to_rad(wheel_angle)
	draw_circle(c, WHEEL_R + 14.0, Color(0, 0, 0, 0.18))
	draw_arc(c, WHEEL_R, 0, TAU, 48, Color(0.12, 0.12, 0.14, 0.92), 26.0, true)
	draw_arc(c, WHEEL_R + 9.0, 0, TAU, 48, Color(0.35, 0.35, 0.4, 0.9), 4.0, true)
	for sa in [0.0, PI, PI * 0.5]:
		var d := Vector2.from_angle(sa + a)
		draw_line(c, c + d * (WHEEL_R - 8.0), Color(0.2, 0.2, 0.24, 0.92), 20.0, true)
	var top_dir := Vector2.from_angle(-PI * 0.5 + a)
	draw_line(c + top_dir * (WHEEL_R - 13.0), c + top_dir * (WHEEL_R + 13.0), Color(0.95, 0.2, 0.1), 14.0)
	draw_circle(c, 30.0, Color(0.25, 0.25, 0.3, 0.95))
	draw_circle(c, 14.0, Color(0.95, 0.75, 0.1))

	var g := gas_center()
	draw_circle(g, GAS_R, Color(0.1, 0.75, 0.2, 0.95 if gas else 0.6))
	draw_arc(g, GAS_R, 0, TAU, 48, Color(1, 1, 1, 0.8), 4.0, true)
	draw_string(_font, g + Vector2(-GAS_R, 14), "GAS", HORIZONTAL_ALIGNMENT_CENTER, GAS_R * 2.0, 40, Color.WHITE)
	var b := brake_center()
	draw_circle(b, BRAKE_R, Color(0.85, 0.12, 0.1, 0.95 if brake else 0.6))
	draw_arc(b, BRAKE_R, 0, TAU, 40, Color(1, 1, 1, 0.8), 4.0, true)
	draw_string(_font, b + Vector2(-BRAKE_R, 9), "BREMSE", HORIZONTAL_ALIGNMENT_CENTER, BRAKE_R * 2.0, 22, Color.WHITE)

class_name BBBubbleButton
extends Control
## The one action button: a big friendly bubble in the corner. Handles touch and
## mouse, and grows while held so charging is visible.

signal pressed_down
signal released

const SIZE := 200.0

var charge := 0.0
var ready_ratio := 1.0
var _held := false
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_held = true
			pressed_down.emit()
		else:
			_held = false
			released.emit()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_held = true
			pressed_down.emit()
		else:
			_held = false
			released.emit()
		accept_event()


func _draw() -> void:
	var c := size * 0.5
	var r: float = SIZE * 0.5 * (1.0 + charge * 0.06) * (0.96 if _held else 1.0)
	var wob := sin(_t * 2.4) * 3.0

	# Halo.
	draw_circle(c, r + 14.0 + wob, Color(1, 1, 1, 0.16))
	# Body.
	draw_circle(c, r, Color(0.78, 0.94, 1.0, 0.45))
	draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.9), 7.0, true)
	draw_circle(c + Vector2(-r * 0.32, -r * 0.34), r * 0.2, Color(1, 1, 1, 0.85))

	# Readiness ring: fills back up while the Big Bubble recharges.
	if ready_ratio < 1.0:
		draw_arc(c, r - 16.0, -PI * 0.5, -PI * 0.5 + TAU * ready_ratio, 40, Color(1, 0.85, 0.4, 0.9), 10.0, true)
	else:
		# Ready: three little bubbles clustered inside.
		for i in 3:
			var a := _t * 1.2 + TAU * float(i) / 3.0
			draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.32, r * 0.16, Color(1, 1, 1, 0.55))

	if charge > 0.0:
		draw_arc(c, r * 0.62, -PI * 0.5, -PI * 0.5 + TAU * charge, 30, Color.WHITE, 9.0, true)

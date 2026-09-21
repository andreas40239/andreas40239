extends Control
class_name TouchButton
## Runde Touch-Taste (Springen, Pause). Verarbeitet echte Mehrfinger-Touches
## und - fuer das Testen am Rechner - auch Mausklicks.

signal pressed()
signal released()

enum Icon { SPRUNG, PAUSE }

const BASE_COLOR := Color(0.95, 0.95, 1.0, 0.16)
const ACTIVE_COLOR := Color(0.98, 0.78, 0.40, 0.45)
const SYMBOL_COLOR := Color(1.0, 1.0, 1.0, 0.85)

@export var icon: Icon = Icon.SPRUNG:
	set(value):
		icon = value
		queue_redraw()

var _active_pointer: int = -99   # -99 = keine Eingabe, -1 = Maus, sonst Touch-Index

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _active_pointer == -99:
			_begin(touch.index)
		elif not touch.pressed and _active_pointer == touch.index:
			_end()
		accept_event()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		# Bei aktivem Finger die vom System erzeugte Maus-Kopie ignorieren.
		if click.pressed and _active_pointer == -99:
			_begin(-1)
		elif not click.pressed and _active_pointer == -1:
			_end()
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_EXIT_TREE:
		if _active_pointer != -99:
			_end()

func _begin(pointer: int) -> void:
	_active_pointer = pointer
	queue_redraw()
	pressed.emit()

func _end() -> void:
	_active_pointer = -99
	queue_redraw()
	released.emit()

func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	var center := size * 0.5
	draw_circle(center, radius, ACTIVE_COLOR if _active_pointer != -99 else BASE_COLOR)
	draw_arc(center, radius - 2.0, 0.0, TAU, 48, SYMBOL_COLOR * Color(1, 1, 1, 0.5), 3.0, true)
	match icon:
		Icon.SPRUNG:
			# Pfeil nach oben
			var r := radius * 0.45
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -r),
				center + Vector2(r * 0.85, r * 0.35),
				center + Vector2(-r * 0.85, r * 0.35),
			]), SYMBOL_COLOR)
		Icon.PAUSE:
			var bar := Vector2(radius * 0.22, radius * 0.9)
			draw_rect(Rect2(center + Vector2(-radius * 0.38, -bar.y * 0.5), bar), SYMBOL_COLOR)
			draw_rect(Rect2(center + Vector2(radius * 0.16, -bar.y * 0.5), bar), SYMBOL_COLOR)

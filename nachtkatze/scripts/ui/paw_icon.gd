extends Control
class_name PawIcon
## Ein Lebenspunkt als Pfotensymbol (GDD Abschnitt 12: LP oben links).
## Wird gezeichnet statt als Textur geladen - das Asset-Kit folgt spaeter.

const FILLED_COLOR := Color(0.98, 0.74, 0.38)
const EMPTY_COLOR := Color(0.30, 0.32, 0.40, 0.75)

@export var filled: bool = true:
	set(value):
		filled = value
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(54, 54)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var color := FILLED_COLOR if filled else EMPTY_COLOR
	var s := minf(size.x, size.y)
	var center := size * 0.5
	# Ballen
	draw_circle(center + Vector2(0.0, s * 0.12), s * 0.26, color)
	# Vier Zehen
	var toes := [
		Vector2(-0.26, -0.20),
		Vector2(-0.09, -0.31),
		Vector2(0.09, -0.31),
		Vector2(0.26, -0.20),
	]
	for toe in toes:
		draw_circle(center + toe * s, s * 0.105, color)

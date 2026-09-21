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

## Vier Zehen rund um den Ballen.
const TOES := [
	Vector2(-0.26, -0.20),
	Vector2(-0.09, -0.31),
	Vector2(0.09, -0.31),
	Vector2(0.26, -0.20),
]

func _draw() -> void:
	draw_paw(self, size * 0.5, minf(size.x, size.y),
		FILLED_COLOR if filled else EMPTY_COLOR)

## Zeichnet eine Pfote auf eine beliebige Zeichenflaeche.
static func draw_paw(canvas: CanvasItem, center: Vector2, span: float, color: Color) -> void:
	canvas.draw_circle(center + Vector2(0.0, span * 0.12), span * 0.26, color)
	for toe in TOES:
		canvas.draw_circle(center + toe * span, span * 0.105, color)

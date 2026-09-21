extends Control
class_name HintOverlay
## Tutorial-Hinweise fuer Level 0 (GDD Abschnitt 7).
##
## Erklaerungen laufen ausschliesslich ueber Symbole - kein Text, weil die
## Zielgruppe ab 5 Jahren noch nicht liest. Gezeichnet statt als Textur, so
## lange es noch kein Asset-Kit gibt.

enum Hint { KEIN, LAUFEN, SPRINGEN, KLETTERN, FRESSEN, VORSICHT }

const SYMBOL_COLOR := Color(1.0, 1.0, 1.0, 0.92)
const RING_COLOR := Color(1.0, 1.0, 1.0, 0.45)
const BACKGROUND_COLOR := Color(0.06, 0.08, 0.14, 0.45)
const WARN_COLOR := Color(1.0, 0.72, 0.25, 0.95)
const FADE_SPEED := 4.0

var _hint: Hint = Hint.KEIN
var _alpha := 0.0
var _pulse := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func show_hint(kind: Hint) -> void:
	_hint = kind
	set_process(true)

func hide_hint(kind: Hint = Hint.KEIN) -> void:
	# Nur ausblenden, wenn kein anderer Hinweis inzwischen uebernommen hat.
	if kind == Hint.KEIN or kind == _hint:
		_hint = Hint.KEIN

## Aktuell gezeigtes Symbol.
func current_hint() -> Hint:
	return _hint

func _process(delta: float) -> void:
	_pulse += delta
	var goal := 1.0 if _hint != Hint.KEIN else 0.0
	_alpha = move_toward(_alpha, goal, delta * FADE_SPEED)
	visible = _alpha > 0.01
	if visible:
		queue_redraw()
	elif is_zero_approx(_alpha) and _hint == Hint.KEIN:
		set_process(false)

func _draw() -> void:
	if _hint == Hint.KEIN and is_zero_approx(_alpha):
		return
	var radius := minf(size.x, size.y) * 0.5
	var center := size * 0.5
	var fade := Color(1.0, 1.0, 1.0, _alpha)
	draw_circle(center, radius, BACKGROUND_COLOR * fade)
	draw_arc(center, radius - 2.0, 0.0, TAU, 48, RING_COLOR * fade, 3.0, true)
	var color := SYMBOL_COLOR * fade
	match _hint:
		Hint.LAUFEN:
			_draw_arrow(center + Vector2(-radius * 0.38, 0.0), radius * 0.3, PI, color)
			_draw_arrow(center + Vector2(radius * 0.38, 0.0), radius * 0.3, 0.0, color)
			draw_circle(center, radius * 0.16, color)
		Hint.SPRINGEN:
			_draw_arrow(center + Vector2(0.0, -radius * 0.1), radius * 0.45, -PI * 0.5, color)
			draw_rect(Rect2(center + Vector2(-radius * 0.45, radius * 0.45),
				Vector2(radius * 0.9, radius * 0.12)), color)
		Hint.KLETTERN:
			# Zwei Pfeile nach oben: am Joystick hoch druecken.
			var bob := sin(_pulse * 4.0) * radius * 0.06
			_draw_arrow(center + Vector2(0.0, -radius * 0.28 + bob), radius * 0.28, -PI * 0.5, color)
			_draw_arrow(center + Vector2(0.0, radius * 0.22 + bob), radius * 0.28, -PI * 0.5, color)
		Hint.FRESSEN:
			PawIcon.draw_paw(self, center, radius * 1.5, color)
		Hint.VORSICHT:
			var warn := WARN_COLOR * fade
			draw_rect(Rect2(center + Vector2(-radius * 0.09, -radius * 0.5),
				Vector2(radius * 0.18, radius * 0.62)), warn)
			draw_circle(center + Vector2(0.0, radius * 0.36), radius * 0.11, warn)

## Dreieck als Pfeil; rotation 0 zeigt nach rechts.
func _draw_arrow(center: Vector2, span: float, rotation: float, color: Color) -> void:
	var points := PackedVector2Array()
	for angle in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		points.append(center + Vector2(span, 0.0).rotated(rotation + angle))
	draw_colored_polygon(points, color)

class_name BuildSpot
extends Node2D
## Ein freier Bauplatz (großes Plus, mindestens 56-64 dp Touch-Fläche).

var index: int = 0
var station: Station = null
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var _t := 0.0
var _pulse := 0.0


func is_free() -> bool:
	return station == null


## Kurzes Aufleuchten (z. B. wenn ein Kind zuerst eine Karte antippt).
func pulse() -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	_t += delta
	_pulse = maxf(0.0, _pulse - delta * 0.8)
	if is_free():
		queue_redraw()


func _draw() -> void:
	if not is_free():
		return
	Icons.ellipse(self, Vector2(0, 10), 56, 26, Color(0.55, 0.42, 0.25, 0.22))
	Icons.ellipse(self, Vector2(0, 6), 50, 22, Color("e2c48f"))
	var breathe := 1.0 + 0.05 * sin(_t * 3.0) + 0.2 * sin(_pulse * PI)
	var c := Vector2(0, -8)
	if selected:
		draw_circle(c, 46 * breathe, Color(1.0, 0.9, 0.3, 0.45))
	draw_circle(c, 32 * breathe, Color.WHITE)
	draw_arc(c, 32 * breathe, 0, TAU, 32, Color("5fc356") if not selected else Color("ff9f1c"), 5.0, true)
	Icons.plus(self, c, 36 * breathe, Color("5fc356") if not selected else Color("ff9f1c"))

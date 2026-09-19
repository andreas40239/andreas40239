class_name BBRing
extends Node2D
## An expanding soft ring: the visual "something nice happened here" stamp.

var max_radius := 90.0
var color := Color(1, 1, 1, 0.9)
var duration := 0.45
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / duration
	var r: float = lerpf(max_radius * 0.15, max_radius, ease(k, 0.35))
	var a: float = (1.0 - k) * color.a
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color.r, color.g, color.b, a), maxf(2.0, 10.0 * (1.0 - k)), true)

class_name RangeIndicator
extends Node2D
## Zeigt die Reichweite einer Station als weichen Kreis (unter Monstern und Stationen).

var _center := Vector2.ZERO
var _radius := 0.0
var _color := Color.WHITE
var _time_left := -1.0
var _visible_amount := 0.0
var _t := 0.0


func show_range(center: Vector2, radius: float, color: Color, duration: float = -1.0) -> void:
	_center = center
	_radius = radius
	_color = color
	_time_left = duration
	_visible_amount = 1.0
	queue_redraw()


func hide_range() -> void:
	_visible_amount = 0.0
	_time_left = -1.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _time_left > 0.0:
		_time_left -= delta
		if _time_left <= 0.0:
			_time_left = 0.0
	if _time_left == 0.0:
		_visible_amount = maxf(0.0, _visible_amount - delta * 2.0)
	if _visible_amount > 0.0:
		queue_redraw()


func _draw() -> void:
	if _visible_amount <= 0.0:
		return
	var a := _visible_amount
	draw_circle(_center, _radius, Color(_color.r, _color.g, _color.b, 0.22 * a))
	var segs := 28
	for i in segs:
		if i % 2 == 0:
			var a0 := _t * 0.4 + TAU * i / segs
			draw_arc(_center, _radius, a0, a0 + TAU / segs, 6, Color(1, 1, 1, 0.85 * a), 4.0, true)

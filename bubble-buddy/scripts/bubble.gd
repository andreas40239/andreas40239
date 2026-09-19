class_name BBBubble
extends Node2D
## Finley's bubbles. The small stream fires automatically; the Big Bubble is the
## player's one action button.
##
## Nothing here destroys anything. Bubbles nudge, slow, pop seaweed open and free
## trapped friends.

const SMALL_SPEED := 520.0
const BIG_SPEED := 430.0

var big := false
var power := 1.0
var radius := 16.0
var hits_left := 1
var alive := true
var _t := 0.0
var _drift := 0.0
var _visual: BBBubbleVisual


func setup(is_big: bool, charge := 1.0) -> void:
	big = is_big
	power = charge
	z_index = 15
	if big:
		radius = lerpf(46.0, 92.0, charge)
		hits_left = 3
		_visual = BBBubbleVisual.new()
		_visual.diameter = radius * 2.0
		add_child(_visual)
	else:
		radius = 15.0
		hits_left = 1
	_drift = randf_range(-1.0, 1.0)


func tick(delta: float, scroll_speed: float) -> void:
	_t += delta
	var speed := BIG_SPEED if big else SMALL_SPEED
	# Bubbles rise through the water, and the world scrolls past them.
	position.y -= speed * delta
	position.y += scroll_speed * delta * 0.25
	position.x += sin(_t * 3.4 + _drift * 3.0) * (26.0 if big else 44.0) * delta
	if big:
		radius = minf(radius + delta * 18.0, 120.0)
		_visual.diameter = radius * 2.0
	if position.y < -260.0:
		alive = false
	queue_redraw()


func consume_hit() -> void:
	hits_left -= 1
	if hits_left <= 0:
		alive = false


func _draw() -> void:
	if big:
		# The shader child draws the bubble itself; add a few clinging droplets.
		for i in 3:
			var a := _t * 1.3 + i * TAU / 3.0
			var p := Vector2(cos(a), sin(a)) * radius * 0.82
			draw_circle(p, radius * 0.08, Color(1, 1, 1, 0.5))
		return
	var wob := 1.0 + sin(_t * 8.0) * 0.08
	draw_circle(Vector2.ZERO, radius * wob, Color(0.85, 0.97, 1.0, 0.42))
	draw_arc(Vector2.ZERO, radius * wob, 0.0, TAU, 18, Color(1, 1, 1, 0.8), 3.0, true)
	draw_circle(Vector2(-radius * 0.3, -radius * 0.32), radius * 0.26, Color(1, 1, 1, 0.8))

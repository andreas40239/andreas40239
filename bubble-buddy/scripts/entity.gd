class_name BBEntity
extends Node2D
## Base class for everything that drifts down the screen as Finley swims up.
##
## The world scrolls by moving entities downward; `scroll_factor` lets parallax
## and floating items move at their own pace. Collision is a simple radius test
## resolved in game.gd, which keeps behaviour readable and perfectly consistent
## across devices.

enum Kind { OBSTACLE, COLLECTIBLE, POWERUP, GATE, DECOR }

var kind: int = Kind.OBSTACLE
var radius := 40.0
var scroll_factor := 1.0
var alive := true
var age := 0.0
## Obstacles that have been bubbled aside stop colliding with Finley.
var pushed := false
var push_velocity := Vector2.ZERO
var spin := 0.0


func advance(delta: float, scroll_speed: float) -> void:
	age += delta
	position.y += scroll_speed * scroll_factor * delta
	if push_velocity != Vector2.ZERO:
		position += push_velocity * delta
		push_velocity = push_velocity.lerp(Vector2.ZERO, clampf(delta * 1.6, 0.0, 1.0))
		rotation += spin * delta
		spin = lerpf(spin, 0.0, clampf(delta * 1.2, 0.0, 1.0))
	update_entity(delta)
	queue_redraw()


func update_entity(_delta: float) -> void:
	pass


## True when Finley currently collides with this entity.
func overlaps(point: Vector2, other_radius: float) -> bool:
	return position.distance_to(point) < radius + other_radius


## A gentle nudge from the auto-fired bubble stream. Default: no effect.
func on_small_bubble(_game) -> bool:
	return false


## The Big Bubble. `dir` is -1 or 1 and says which way to tumble.
func on_big_bubble(_game, _dir: float) -> bool:
	return false


## Finley touched this. Entities implement their own reaction so all of a
## creature's behaviour lives in one place.
func on_touch(_game, _player) -> void:
	pass


## Rainbow Rush turns obstacles into confetti.
func on_rainbow(game) -> void:
	game.fx.confetti(position, 18)
	Sound.play_varied("pop", 0.12)
	alive = false


func push_aside(dir: float, force := 620.0) -> void:
	pushed = true
	push_velocity = Vector2(dir * force, -force * 0.18)
	spin = dir * randf_range(5.0, 9.0)

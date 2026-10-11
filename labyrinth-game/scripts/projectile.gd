extends Node2D
## Geschosse: Tinte, Dolche, Felsen, Feuerbaelle.

var game: Node
var velocity := Vector2.ZERO
var kind := "ink"
var hostile := true
var radius := 7.0
var life := 4.0
var anim := 0.0


func _ready() -> void:
	match kind:
		"rock": radius = 10.0
		"dagger": radius = 5.0
		"fireball": radius = 9.0
		"web": radius = 9.0
		"icerock": radius = 10.0
		_: radius = 7.0


func color() -> Color:
	match kind:
		"rock": return Color(0.55, 0.45, 0.35)
		"dagger": return Color(0.75, 0.7, 0.9)
		"fireball": return Color(1.0, 0.5, 0.1)
		"web": return Color(0.95, 0.95, 1.0)
		"icerock": return Color(0.6, 0.85, 1.0)
	return Color(0.35, 0.1, 0.45)


func update(dt: float) -> void:
	anim += dt
	life -= dt
	position += velocity * dt
	if life <= 0.0 or game.touches_solid(position, radius * 0.6, true):
		game.effects.burst(position, color(), 8, 80.0)
		kill()
		return
	if hostile and not game.player.dead and position.distance_to(game.player.position) < radius + game.player.radius - 2.0:
		if kind == "web":
			game.player.slow = 2.0
			game.audio.sfx("web")
		else:
			game.player.hurt(1, velocity.normalized())
		game.effects.burst(position, color(), 10, 100.0)
		kill()
		return
	queue_redraw()


func kill() -> void:
	game.projectiles.erase(self)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2(0, 12), radius * 0.7, Color(0, 0, 0, 0.25))
	match kind:
		"web":
			for i in 6:
				var a := TAU * i / 6.0 + anim * 3.0
				draw_line(Vector2.ZERO, Vector2.from_angle(a) * radius, color(), 1.0)
			draw_arc(Vector2.ZERO, radius * 0.5, 0, TAU, 8, color(), 1.0)
			draw_arc(Vector2.ZERO, radius, 0, TAU, 10, color(), 1.0)
		"icerock":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -radius), Vector2(radius * 0.8, 0), Vector2(0, radius), Vector2(-radius * 0.8, 0)]), color())
			draw_line(Vector2(0, -radius), Vector2(0, radius), Color(1, 1, 1, 0.6), 1.5)
		"rock":
			draw_circle(Vector2.ZERO, radius, color())
			draw_circle(Vector2(-3, -3), radius * 0.4, color().lightened(0.2))
		"dagger":
			var d := velocity.normalized()
			draw_line(-d * 8, d * 8, color(), 3.0)
			draw_line(-d * 8, -d * 3, Color(0.3, 0.2, 0.4), 4.0)
		"fireball":
			for i in 3:
				draw_circle(-velocity.normalized() * i * 6.0, radius - i * 2.5, Color(1.0, 0.3 + i * 0.2, 0.05, 0.85 - i * 0.2))
			draw_circle(Vector2.ZERO, radius * 0.5, Color(1, 0.95, 0.6))
		_:
			draw_circle(Vector2.ZERO, radius, color())
			draw_circle(Vector2(-2, -2), 2.5, Color(0.7, 0.5, 0.8, 0.8))

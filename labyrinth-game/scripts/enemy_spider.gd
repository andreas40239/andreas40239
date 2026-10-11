extends "res://scripts/enemy_base.gd"
## Kleine Spinne (von der Riesenspinne gerufen): krabbelt auf den Helden zu.

var jitter := Vector2.ZERO


func _ready() -> void:
	super._ready()
	radius = 8.0
	hp = 1
	max_hp = 1
	set_meta("brood", true)


func think(dt: float) -> void:
	if randf() < dt * 4.0:
		jitter = Vector2.from_angle(randf() * TAU) * 40.0
	move(to_player().normalized() * 70.0 + jitter, dt)


func _draw() -> void:
	draw_shadow(7, 7)
	var c := tint(Color(0.3, 0.22, 0.35))
	var w := sin(anim * 20.0) * 2.0
	for s in [-1.0, 1.0]:
		for i in 3:
			draw_line(Vector2(s * 3, -2 + i * 3), Vector2(s * 10, -5 + i * 5 + (w if i % 2 == 0 else -w)), c, 1.5)
	draw_circle(Vector2(0, 2), 6, c)
	draw_circle(Vector2(0, -4), 4, c)
	draw_circle(Vector2(-1.5, -5), 1.0, Color(1, 0.3, 0.3))
	draw_circle(Vector2(1.5, -5), 1.0, Color(1, 0.3, 0.3))
	draw_ice()

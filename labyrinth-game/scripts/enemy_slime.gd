extends "res://scripts/enemy_base.gd"
## Schleim: huepft auf den Helden zu.

var hop_cd := 1.0
var hop_t := 0.0
var hop_dir := Vector2.ZERO


func _ready() -> void:
	super._ready()
	radius = 11.0
	hp = 2
	max_hp = 2
	hop_cd = randf_range(0.5, 1.5)


func think(dt: float) -> void:
	var to := to_player()
	if hop_t > 0.0:
		hop_t -= dt
		move(hop_dir * 125.0, dt)
		return
	hop_cd -= dt
	if hop_cd <= 0.0:
		hop_cd = randf_range(0.9, 1.4)
		if to.length() < 200.0 and not game.player.dead:
			hop_dir = to.normalized()
			hop_t = 0.35
			if randf() < 0.5:
				game.audio.sfx("slime", -6.0)
		else:
			hop_dir = Vector2.from_angle(randf() * TAU)
			hop_t = 0.15


func _draw() -> void:
	var squash := 1.0 + (0.25 * sin(hop_t / 0.35 * PI) if hop_t > 0.0 else 0.08 * sin(anim * 5.0))
	var lift := -6.0 * sin(hop_t / 0.35 * PI) if hop_t > 0.0 else 0.0
	draw_shadow(10, 8)
	var c := tint(Color(0.35, 0.8, 0.35, 0.92))
	draw_set_transform(Vector2(0, 3 + lift), 0.0, Vector2(1.0 / squash, squash))
	draw_circle(Vector2(0, -4), 11, c)
	draw_rect(Rect2(-11, -4, 22, 8), c)
	draw_circle(Vector2(-4, -8), 3, Color(1, 1, 1, 0.35))
	draw_circle(Vector2(-4, -3), 2, Color.BLACK)
	draw_circle(Vector2(4, -3), 2, Color.BLACK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_ice()

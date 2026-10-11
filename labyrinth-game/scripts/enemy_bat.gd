extends "res://scripts/enemy_base.gd"
## Fledermaus: schwebt, greift an, wenn der Held nahe kommt.

var home := Vector2.ZERO
var aggro := false
var retreat := 0.0


func _ready() -> void:
	super._ready()
	radius = 9.0
	hp = 1
	max_hp = 1
	flying = true
	home = position


func think(dt: float) -> void:
	var to := to_player()
	var d := to.length()
	if not aggro:
		position = home + Vector2(sin(anim * 1.3) * 10.0, cos(anim * 2.1) * 6.0)
		if d < 170.0 and not game.player.dead:
			aggro = true
			game.audio.sfx("bat", -3.0)
		return
	if d > 360.0:
		# zurueck nach Hause
		move((home - position).limit_length(70.0), dt)
		if position.distance_to(home) < 4.0:
			aggro = false
		return
	if retreat > 0.0:
		retreat -= dt
		move(-to.normalized() * 90.0, dt)
		return
	var side := to.normalized().orthogonal() * sin(anim * 6.0) * 60.0
	move(to.normalized() * 88.0 + side, dt)
	if d < radius + game.player.radius + 2.0:
		retreat = 0.8


func _draw() -> void:
	var flap := sin(anim * 18.0)
	draw_shadow(7, 16)
	var body := tint(Color(0.3, 0.2, 0.35))
	var wing := tint(Color(0.22, 0.12, 0.28))
	for s in [-1.0, 1.0]:
		var pts := PackedVector2Array([
			Vector2(s * 4, -1), Vector2(s * 16, -6 - flap * 7), Vector2(s * 13, 1 - flap * 2),
			Vector2(s * 9, -1 - flap * 3), Vector2(s * 6, 3)])
		draw_colored_polygon(pts, wing)
	draw_circle(Vector2.ZERO, 6, body)
	draw_line(Vector2(-3, -5), Vector2(-5, -10), body, 2)
	draw_line(Vector2(3, -5), Vector2(5, -10), body, 2)
	draw_circle(Vector2(-2, -1), 1.3, Color(1, 0.2, 0.2))
	draw_circle(Vector2(2, -1), 1.3, Color(1, 0.2, 0.2))
	draw_ice()

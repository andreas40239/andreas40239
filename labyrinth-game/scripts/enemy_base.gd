extends Node2D
## Gemeinsame Grundlage fuer alle Gegner und Bosse.

var game: Node
var radius := 12.0
var hp := 1
var max_hp := 1
var flash := 0.0
var frozen := 0.0
var knock := Vector2.ZERO
var boss_id := 0
var flying := false
var hit_cd := 0.0
var anim := 0.0
var freeze_time := 1.6


func _ready() -> void:
	anim = randf() * 10.0


func update(dt: float) -> void:
	anim += dt
	flash = maxf(0.0, flash - dt)
	hit_cd = maxf(0.0, hit_cd - dt)
	if knock.length() > 1.0:
		position = game.move_circle(position, knock * dt, radius, flying)
		knock = knock.move_toward(Vector2.ZERO, 700.0 * dt)
	if frozen > 0.0:
		frozen -= dt
	else:
		think(dt)
	queue_redraw()


func think(_dt: float) -> void:
	pass


func player() -> Node2D:
	return game.player


func to_player() -> Vector2:
	return game.player.position - position


func move(v: Vector2, dt: float) -> bool:
	## Bewegt sich; gibt true zurueck, wenn eine Wand den Weg versperrt hat.
	var want := position + v * dt
	position = game.move_circle(position, v * dt, radius, flying)
	return position.distance_to(want) > 0.5


func is_hittable() -> bool:
	return hit_cd <= 0.0


func is_dangerous() -> bool:
	return frozen <= 0.0


func contact_damage() -> int:
	return 1


func touches(p: Vector2, r: float) -> bool:
	return position.distance_to(p) < radius + r - 2.0


func take_hit(dmg: int, dir: Vector2, weapon: int) -> void:
	hp -= dmg
	flash = 0.15
	hit_cd = 0.12
	knock = dir * knock_power()
	game.audio.sfx("hit")
	game.effects.burst(position, Color(1, 1, 1), 6, 100.0)
	if weapon == 2 and hp > 0:
		frozen = freeze_time
		game.audio.sfx("freeze", -4.0)
		game.effects.burst(position, Color(0.6, 0.9, 1.0), 10, 120.0)
	elif weapon == 1:
		game.effects.burst(position, Color(1.0, 0.5, 0.1), 8, 110.0)
	if hp <= 0:
		die()


func knock_power() -> float:
	return 220.0


func die() -> void:
	game.enemies.erase(self)
	game.audio.sfx("monster_die")
	game.effects.burst(position, Color(0.7, 0.2, 0.9), 16, 140.0)
	queue_free()


## Farbe mit Treffer-Blitz und Eis-Toenung
func tint(c: Color) -> Color:
	if flash > 0.0:
		return Color(1, 1, 1)
	if frozen > 0.0:
		return c.lerp(Color(0.6, 0.85, 1.0), 0.65)
	return c


func draw_shadow(r: float, y: float = 0.0) -> void:
	draw_set_transform(Vector2(0, y), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_ice() -> void:
	if frozen > 0.0:
		draw_arc(Vector2.ZERO, radius + 3.0, 0, TAU, 18, Color(0.75, 0.95, 1.0, 0.8), 2.0)
		for i in 5:
			var a := TAU * i / 5.0 + 0.3
			draw_line(Vector2.from_angle(a) * (radius - 2), Vector2.from_angle(a) * (radius + 6), Color(0.85, 0.97, 1.0, 0.9), 2.0)

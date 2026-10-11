extends "res://scripts/enemy_base.gd"
## Zwischenboss 5: Riesenkrake - taucht auf und spuckt Tinte.

const POOL := Rect2(26 * 32, 34 * 32, 7 * 32, 6 * 32)
const EDGE := 20.0

var fighting := false
var mode := "sub"
var t := 1.5
var target := Vector2.ZERO
var shot_cd := 0.6
var phase2 := false
var rise := 0.0  # 0 = untergetaucht, 1 = aufgetaucht


func _ready() -> void:
	super._ready()
	radius = 24.0
	hp = 9
	max_hp = 9
	flying = true
	freeze_time = 1.2
	target = position


func start_fight() -> void:
	fighting = true
	mode = "sub"
	t = 1.0
	_pick_target()
	game.audio.sfx("octopus")


func _pick_target() -> void:
	var inner := POOL.grow(-EDGE)
	var p: Vector2 = game.player.position
	var c := Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))
	# auf den Rand des inneren Rechtecks schieben
	var dl := c.x - inner.position.x
	var dr := inner.end.x - c.x
	var du := c.y - inner.position.y
	var dd := inner.end.y - c.y
	var m := minf(minf(dl, dr), minf(du, dd))
	if m == dl: c.x = inner.position.x
	elif m == dr: c.x = inner.end.x
	elif m == du: c.y = inner.position.y
	else: c.y = inner.end.y
	c += Vector2(randf_range(-30, 30), randf_range(-30, 30))
	target = Vector2(clampf(c.x, inner.position.x, inner.end.x), clampf(c.y, inner.position.y, inner.end.y))


func knock_power() -> float:
	return 0.0


func is_hittable() -> bool:
	return fighting and mode == "up" and hit_cd <= 0.0


func is_dangerous() -> bool:
	return fighting and mode == "up" and frozen <= 0.0


func take_hit(dmg: int, dir: Vector2, weapon: int) -> void:
	super.take_hit(dmg, dir, weapon)
	game.audio.sfx("octopus", -6.0)
	if hp > 0 and hp <= 4 and not phase2:
		phase2 = true
		game.hud.show_message("Die Krake tobt!", "")


func think(dt: float) -> void:
	if not fighting:
		rise = 0.0
		return
	t -= dt
	match mode:
		"sub":
			rise = maxf(0.0, rise - dt * 3.0)
			position = position.move_toward(target, 170.0 * dt)
			if t <= 0.0 and position.distance_to(target) < 2.0:
				mode = "rise"
				t = 0.45
				game.audio.sfx("ink", -6.0)
		"rise":
			rise = 1.0 - t / 0.45
			if t <= 0.0:
				mode = "up"
				t = 2.6 if phase2 else 3.2
				shot_cd = 0.5
				if randf() < 0.5:
					game.audio.sfx("octopus", -3.0)
		"up":
			rise = 1.0
			shot_cd -= dt
			if shot_cd <= 0.0 and not game.player.dead:
				shot_cd = 0.7 if phase2 else 0.9
				var d := to_player().normalized()
				var spread := [-0.3, 0.0, 0.3] if phase2 else [0.0]
				for a in spread:
					game.spawn_projectile(position + d * 18.0, d.rotated(a) * 165.0, "ink")
				game.audio.sfx("ink")
			if t <= 0.0:
				mode = "sink"
				t = 0.4
		"sink":
			rise = t / 0.4
			if t <= 0.0:
				mode = "sub"
				t = 1.2 if phase2 else 1.6
				_pick_target()


func _draw() -> void:
	var c := tint(Color(0.75, 0.25, 0.45))
	if rise < 0.05:
		# nur ein Schatten unter Wasser
		var a := 0.35 + 0.1 * sin(anim * 3.0)
		draw_circle(Vector2.ZERO, 20, Color(0.05, 0.05, 0.15, a))
		for i in 2:
			var rr := fmod(anim * 20.0 + i * 15.0, 30.0) + 10.0
			draw_arc(Vector2.ZERO, rr, 0, TAU, 20, Color(0.7, 0.85, 1.0, 0.3 * (1.0 - rr / 40.0)), 1.5)
		return
	var s := rise
	draw_set_transform(Vector2(0, (1.0 - s) * 10.0), 0.0, Vector2(s, s))
	# Tentakel
	for i in 8:
		var base_a := TAU * i / 8.0 + 0.2
		var pts := PackedVector2Array()
		for k in 7:
			var r := 12.0 + k * 5.5
			var a := base_a + sin(anim * 3.0 + k * 0.7 + i) * 0.35
			pts.append(Vector2.from_angle(a) * r)
		draw_polyline(pts, c.darkened(0.15), 6.0)
		draw_circle(pts[pts.size() - 1], 2.5, c.darkened(0.15))
	# Kopf
	draw_circle(Vector2(0, -6), 18, c)
	draw_circle(Vector2(-6, -14), 5, Color(1, 1, 1, 0.2))
	draw_circle(Vector2(-7, -3), 5, Color(1, 1, 0.8))
	draw_circle(Vector2(7, -3), 5, Color(1, 1, 0.8))
	var look := to_player().normalized() * 2.0
	draw_circle(Vector2(-7, -3) + look, 2.5, Color.BLACK)
	draw_circle(Vector2(7, -3) + look, 2.5, Color.BLACK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Wasserring
	draw_arc(Vector2(0, 8), 26, 0, TAU, 24, Color(0.7, 0.9, 1.0, 0.5), 2.0)
	draw_ice()


func die() -> void:
	game.boss_defeated(boss_id)

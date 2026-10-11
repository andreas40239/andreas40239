extends "res://scripts/enemy_base.gd"
## Level 2: Riesenspinne - krabbelt, spinnt klebrige Netze und ruft kleine Spinnen.

var fighting := false
var mode := "walk"
var t := 1.5
var wander := Vector2.ZERO
var cycle_n := 0
var phase2 := false


func _ready() -> void:
	super._ready()
	radius = 22.0
	hp = 10
	max_hp = 10
	freeze_time = 1.0


func start_fight() -> void:
	fighting = true
	mode = "walk"
	t = 1.2
	game.audio.sfx("spider")


func is_hittable() -> bool:
	return fighting and hit_cd <= 0.0


func is_dangerous() -> bool:
	return fighting and frozen <= 0.0


func knock_power() -> float:
	return 90.0


func take_hit(dmg: int, dir: Vector2, weapon: int) -> void:
	super.take_hit(dmg, dir, weapon)
	if hp > 0 and hp <= 5 and not phase2:
		phase2 = true
		game.audio.sfx("spider")
		game.hud.show_message("Die Spinne wird flink!", "")


func think(dt: float) -> void:
	if not fighting:
		return
	t -= dt
	var to := to_player()
	match mode:
		"walk":
			# Zickzack auf den Helden zu
			if wander == Vector2.ZERO or randf() < dt * 1.5:
				wander = to.normalized().rotated(randf_range(-1.0, 1.0))
			move(wander * (85.0 if phase2 else 65.0), dt)
			if t <= 0.0:
				cycle_n += 1
				if cycle_n % 3 == 0:
					mode = "brood"
					t = 0.8
				else:
					mode = "aim"
					t = 0.5
		"aim":
			if t <= 0.0:
				var d := to.normalized()
				var spread := [-0.35, 0.0, 0.35] if phase2 else [-0.2, 0.2]
				for a in spread:
					game.spawn_projectile(position + d * 16.0, d.rotated(a) * 150.0, "web")
				game.audio.sfx("web")
				mode = "walk"
				t = randf_range(1.4, 2.2)
		"brood":
			if t <= 0.0:
				var n := 0
				for e in game.enemies:
					if e.has_meta("brood"):
						n += 1
				for i in mini(2, 4 - n):
					game.spawn_baby_spider(position + Vector2.from_angle(randf() * TAU) * 22.0)
				game.audio.sfx("spider", -3.0)
				mode = "walk"
				t = 1.5


func _draw() -> void:
	draw_shadow(26, 16)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.35, 1.35))
	var body := tint(Color(0.25, 0.18, 0.3))
	var leg := tint(Color(0.18, 0.12, 0.2))
	var walk := sin(anim * 14.0) if mode == "walk" else 0.0
	# Beine
	for s in [-1.0, 1.0]:
		for i in 4:
			var a := -0.9 + i * 0.6
			var knee := Vector2(s * (18 + i * 2), -8 + i * 7 + walk * (3 if i % 2 == 0 else -3))
			var foot := Vector2(s * (28 + i), 4 + i * 7 - walk * (2 if i % 2 == 0 else -2))
			draw_line(Vector2(s * 6, a * 6), knee, leg, 3.0)
			draw_line(knee, foot, leg, 2.5)
	# Hinterleib + Kopf
	draw_circle(Vector2(0, 8), 15, body)
	draw_circle(Vector2(-4, 4), 4, Color(1, 1, 1, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 2), Vector2(4, 8), Vector2(0, 14), Vector2(-4, 8)]), Color(0.85, 0.2, 0.25))
	draw_circle(Vector2(0, -8), 10, body)
	var eye := Color(1, 0.25, 0.25) if mode != "aim" else Color(1, 1, 0.4)
	for p in [Vector2(-4, -10), Vector2(4, -10), Vector2(-2, -13), Vector2(2, -13)]:
		draw_circle(p, 1.8, eye)
	draw_line(Vector2(-3, -1), Vector2(-4, 3), Color(0.9, 0.9, 0.8), 2.0)
	draw_line(Vector2(3, -1), Vector2(4, 3), Color(0.9, 0.9, 0.8), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_ice()


func die() -> void:
	game.boss_defeated(boss_id)

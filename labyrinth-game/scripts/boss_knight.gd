extends "res://scripts/enemy_base.gd"
## Zwischenboss 4: Schattenritter - stuermt auf den Helden zu.

var fighting := false
var mode := "walk"
var t := 1.5
var charge_dir := Vector2.ZERO
var phase2 := false


func _ready() -> void:
	super._ready()
	radius = 15.0
	hp = 10
	max_hp = 10
	freeze_time = 1.0


func start_fight() -> void:
	fighting = true
	mode = "walk"
	t = 1.2
	game.audio.sfx("knight")


func is_hittable() -> bool:
	return fighting and hit_cd <= 0.0


func is_dangerous() -> bool:
	return fighting and frozen <= 0.0


func knock_power() -> float:
	return 0.0 if mode == "charge" else 120.0


func take_hit(dmg: int, dir: Vector2, weapon: int) -> void:
	# Betaeubt nimmt er doppelten Schaden
	super.take_hit(dmg * (2 if mode == "stun" else 1), dir, weapon)
	if hp > 0 and hp <= 5 and not phase2:
		phase2 = true
		game.audio.sfx("knight")
		game.hud.show_message("Der Ritter wird wütend!", "")


func think(dt: float) -> void:
	if not fighting:
		return
	t -= dt
	var to := to_player()
	match mode:
		"walk":
			move(to.normalized() * (80.0 if phase2 else 60.0), dt)
			if t <= 0.0:
				mode = "windup"
				t = 0.45 if phase2 else 0.6
		"windup":
			charge_dir = to.normalized()
			if t <= 0.0:
				mode = "charge"
				t = 0.8
		"charge":
			var blocked := move(charge_dir * (360.0 if phase2 else 320.0), dt)
			if blocked:
				mode = "stun"
				t = 1.4
				game.add_shake(8.0)
				game.audio.sfx("slam", -6.0)
				game.effects.burst(position + charge_dir * radius, Color(0.6, 0.6, 0.7), 20, 160.0)
			elif t <= 0.0:
				mode = "walk"
				t = randf_range(1.0, 1.8)
				if phase2:
					for a in [-0.35, 0.0, 0.35]:
						game.spawn_projectile(position, to.normalized().rotated(a) * 190.0, "dagger")
					game.audio.sfx("swing", -3.0)
		"stun":
			if t <= 0.0:
				mode = "walk"
				t = randf_range(1.0, 1.6)


func _draw() -> void:
	draw_shadow(15, 14)
	var dir := charge_dir if mode in ["charge", "windup"] else to_player().normalized()
	var shake_off := Vector2(randf_range(-1.5, 1.5), 0) if mode == "windup" else Vector2.ZERO
	draw_set_transform(shake_off, 0.0, Vector2.ONE)
	var armor := tint(Color(0.22, 0.2, 0.3))
	var trim := tint(Color(0.55, 0.45, 0.7))
	if mode == "windup" and int(anim * 20.0) % 2 == 0:
		armor = Color(0.8, 0.2, 0.2)
	# Umhang
	draw_circle(-dir * 6 + Vector2(0, 3), 14, tint(Color(0.15, 0.05, 0.2)))
	# Ruestung
	draw_circle(Vector2(0, 2), 13, armor)
	draw_rect(Rect2(-13, -2, 26, 4), trim)
	# Helm
	draw_circle(Vector2(0, -10), 9, armor)
	draw_rect(Rect2(-6, -12, 12, 3), Color(0, 0, 0))
	var eye := Color(1, 0.2, 0.2) if mode != "stun" else Color(0.5, 0.5, 0.5)
	draw_circle(Vector2(-3, -10.5), 1.5, eye)
	draw_circle(Vector2(3, -10.5), 1.5, eye)
	draw_colored_polygon(PackedVector2Array([Vector2(-2, -19), Vector2(0, -27), Vector2(2, -19)]), trim)
	# Schwert/Lanze
	var tip := dir * 30.0
	draw_line(dir * 8.0, tip, tint(Color(0.7, 0.7, 0.8)), 4.0)
	draw_line(dir.orthogonal() * 5 + dir * 9, -dir.orthogonal() * 5 + dir * 9, trim, 3.0)
	if mode == "stun":
		for i in 3:
			var a := anim * 4.0 + TAU * i / 3.0
			draw_circle(Vector2(cos(a) * 12, -24 + sin(a) * 4), 2.5, Color(1, 1, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_ice()


func die() -> void:
	game.boss_defeated(boss_id)

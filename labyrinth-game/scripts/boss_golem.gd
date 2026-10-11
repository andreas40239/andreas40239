extends "res://scripts/enemy_base.gd"
## Zwischenboss 7: Steingolem - nur mit Eis verwundbar, stampft Felsen.
## Als Eisgolem (Level 2) ist er umgekehrt nur mit Feuer verwundbar.

var fighting := false
var mode := "walk"
var t := 2.0
var phase2 := false
var hint_cd := 0.0
var ice_variant := false


func _ready() -> void:
	super._ready()
	radius = 21.0
	hp = 10
	max_hp = 10
	freeze_time = 1.2


func start_fight() -> void:
	fighting = true
	mode = "walk"
	t = 1.5
	game.audio.sfx("golem")


func is_hittable() -> bool:
	return fighting and hit_cd <= 0.0


func is_dangerous() -> bool:
	return fighting and frozen <= 0.0


func knock_power() -> float:
	return 40.0


func take_hit(dmg: int, dir: Vector2, weapon: int) -> void:
	var immune := weapon < 1 if ice_variant else weapon < 2
	if immune:
		hit_cd = 0.2
		flash = 0.05
		game.audio.sfx("clank")
		game.effects.burst(position + dir * -radius, Color(1, 0.9, 0.5), 6, 90.0)
		hint_cd -= 1.0
		if hint_cd <= 0.0:
			hint_cd = 4.0
			if ice_variant:
				game.hud.show_message("Kling! Das Eis ist zu hart.", "Nur Feuer kann den Eisgolem schmelzen.")
			else:
				game.hud.show_message("Kling! Der Golem ist zu hart.", "Nur eisige Kälte kann seinen Stein sprengen.")
		return
	if ice_variant:
		# Feuer schmilzt: kein Einfrieren, dafür Dampf
		hp -= dmg
		flash = 0.15
		hit_cd = 0.12
		knock = dir * knock_power()
		game.audio.sfx("hit")
		game.audio.sfx("fire", -6.0)
		game.effects.burst(position, Color(0.9, 0.95, 1.0), 14, 120.0)
		if hp <= 0:
			die()
			return
	else:
		super.take_hit(dmg, dir, weapon)
	if hp > 0 and hp <= 5 and not phase2:
		phase2 = true
		game.audio.sfx("golem")
		game.hud.show_message("Der Golem bebt vor Zorn!", "")


func think(dt: float) -> void:
	if not fighting:
		return
	t -= dt
	var to := to_player()
	match mode:
		"walk":
			move(to.normalized() * (55.0 if phase2 else 40.0), dt)
			if t <= 0.0:
				mode = "windup"
				t = 0.8
				if randf() < 0.4:
					game.audio.sfx("golem", -6.0)
		"windup":
			if t <= 0.0:
				_slam()
				mode = "recover"
				t = 1.1
		"recover":
			if t <= 0.0:
				mode = "walk"
				t = randf_range(1.8, 2.8)


func _slam() -> void:
	game.audio.sfx("slam")
	game.add_shake(12.0)
	game.effects.burst(position + Vector2(0, 12), Color(0.55, 0.45, 0.35), 30, 200.0)
	var n := 12 if phase2 else 8
	var off := randf() * TAU
	for i in n:
		var d := Vector2.from_angle(off + TAU * i / n)
		game.spawn_projectile(position + d * 24.0, d * 150.0, rock_kind())
	if phase2:
		game.spawn_projectile(position, to_player().normalized() * 210.0, rock_kind())


func rock_kind() -> String:
	return "icerock" if ice_variant else "rock"


func _draw() -> void:
	draw_shadow(22, 18)
	var lift := -8.0 if mode == "windup" else 0.0
	var stone := tint(Color(0.45, 0.4, 0.35))
	var dark := tint(Color(0.3, 0.27, 0.24))
	var glow := Color(1.0, 0.45, 0.1) if frozen <= 0.0 else Color(0.5, 0.85, 1.0)
	if ice_variant:
		stone = tint(Color(0.65, 0.82, 0.95))
		dark = tint(Color(0.42, 0.6, 0.78))
		glow = Color(0.2, 0.4, 1.0)
	# Beine
	draw_rect(Rect2(-15, 6, 11, 14), dark)
	draw_rect(Rect2(4, 6, 11, 14), dark)
	# Rumpf
	draw_rect(Rect2(-18, -16, 36, 26), stone)
	draw_line(Vector2(-10, -10), Vector2(-2, 2), glow, 2.0)
	draw_line(Vector2(6, -14), Vector2(12, 0), glow, 2.0)
	# Arme
	for s in [-1.0, 1.0]:
		draw_rect(Rect2(s * 22 - 6, -14 + lift, 12, 24), dark)
		draw_circle(Vector2(s * 22, 12 + lift), 8, stone)
	# Kopf
	draw_rect(Rect2(-9, -28, 18, 13), stone)
	draw_rect(Rect2(-6, -24, 4, 3), glow)
	draw_rect(Rect2(2, -24, 4, 3), glow)
	if mode == "windup":
		draw_arc(Vector2.ZERO, 34, 0, TAU, 24, Color(1, 0.3, 0.2, 0.5 + 0.5 * sin(anim * 30.0)), 2.0)
	draw_ice()


func die() -> void:
	game.boss_defeated(boss_id)

extends Node2D
## Der Held: Bewegung, Schwerthieb, Schaden.

const SPEED := 135.0
const ATTACK_TIME := 0.22
const ATTACK_COOLDOWN := 0.34
const WEAPON_NAMES := ["Holzschwert", "Feuerschwert", "Eisschwert"]

var game: Node
var radius := 10.0
var hp := 5
var max_hp := 5
var weapon := 0  # 0 Holz, 1 Feuer, 2 Eis (+Feuer)
var input_dir := Vector2.ZERO
var facing := Vector2.DOWN
var knock := Vector2.ZERO
var invuln := 0.0
var attack_t := 0.0
var cooldown := 0.0
var walk_anim := 0.0
var slide := Vector2.ZERO  # Schwung auf dem Eis
var slow := 0.0  # Spinnennetz
var dead := false


func update(dt: float) -> void:
	invuln = maxf(0.0, invuln - dt)
	cooldown = maxf(0.0, cooldown - dt)
	attack_t = maxf(0.0, attack_t - dt)
	if dead:
		queue_redraw()
		return
	var dir := input_dir
	if dir.length() > 1.0:
		dir = dir.normalized()
	if dir.length() > 0.2:
		facing = dir.normalized()
		walk_anim += dt * 10.0 * dir.length()
	slow = maxf(0.0, slow - dt)
	var speed := SPEED * (0.55 if attack_t > 0.0 else 1.0) * (0.45 if slow > 0.0 else 1.0)
	var want := dir * speed
	if game.is_ice(position):
		# auf dem Eis nur langsam lenken und bremsen
		slide = slide.lerp(want * 1.15, minf(1.0, 1.6 * dt))
	else:
		slide = want
	var vel := slide + knock
	knock = knock.move_toward(Vector2.ZERO, 900.0 * dt)
	var before := position
	position = game.move_circle(position, vel * dt, radius)
	if dt > 0.0 and game.is_ice(position):
		# an Wänden geht der Schwung verloren
		var real := (position - before) / dt - knock
		if real.length() < slide.length() * 0.7:
			slide = slide.lerp(real, 0.5)
	position = game.resolve_rings(position, radius)
	position = game.resolve_tiles(position, radius)
	queue_redraw()


func try_attack() -> void:
	if dead or cooldown > 0.0:
		return
	cooldown = ATTACK_COOLDOWN
	attack_t = ATTACK_TIME
	match weapon:
		0: game.audio.sfx("swing")
		1: game.audio.sfx("swing_fire")
		_: game.audio.sfx("swing_ice")
	game.player_attack(position, facing, weapon)


func hurt(dmg: int, from_dir: Vector2, force := false) -> void:
	if dead or (invuln > 0.0 and not force):
		return
	hp -= dmg
	invuln = 1.1
	knock = from_dir.normalized() * 260.0 if from_dir != Vector2.ZERO else Vector2.ZERO
	game.audio.sfx("hurt")
	game.add_shake(5.0)
	game.hud.flash_damage()
	if hp <= 0:
		hp = 0
		dead = true
		game.player_died()


func revive(at: Vector2) -> void:
	dead = false
	hp = max_hp
	position = at
	knock = Vector2.ZERO
	slide = Vector2.ZERO
	slow = 0.0
	invuln = 1.5


func blade_color() -> Color:
	match weapon:
		1: return Color(1.0, 0.55, 0.15)
		2: return Color(0.55, 0.9, 1.0)
	return Color(0.7, 0.55, 0.35)


func _draw() -> void:
	if dead:
		draw_circle(Vector2(0, 4), 9, Color(0.4, 0.05, 0.05, 0.7))
		return
	if invuln > 0.0 and int(invuln * 16.0) % 2 == 0:
		return
	var bob := sin(walk_anim) * 1.5
	# Schatten
	draw_circle(Vector2(0, 9), 8, Color(0, 0, 0, 0.35))
	# Umhang
	var back := -facing * 5.0
	draw_circle(back + Vector2(0, 2 + bob * 0.3), 8, Color(0.55, 0.12, 0.15))
	# Koerper
	draw_circle(Vector2(0, 2 + bob * 0.3), 7.5, Color(0.2, 0.45, 0.25))
	draw_rect(Rect2(-7, 1 + bob * 0.3, 14, 2.5), Color(0.45, 0.3, 0.15))
	# Kopf
	var head := Vector2(0, -6 + bob * 0.2)
	draw_circle(head, 6, Color(0.95, 0.8, 0.65))
	draw_arc(head, 6.3, PI + 0.2, TAU - 0.2, 10, Color(0.45, 0.28, 0.12), 3.5)
	# Augen in Blickrichtung
	if facing.y > -0.5:
		var eo := Vector2(facing.x * 2.5, 1)
		draw_circle(head + eo + Vector2(-2, 0), 1.1, Color.BLACK)
		draw_circle(head + eo + Vector2(2, 0), 1.1, Color.BLACK)
	# Schwert
	var col := blade_color()
	var ang := facing.angle()
	if attack_t > 0.0:
		var k := 1.0 - attack_t / ATTACK_TIME
		var a := ang - 1.2 + 2.4 * k
		var tip := Vector2.from_angle(a) * 34.0
		# Schwung-Spur
		draw_arc(Vector2.ZERO, 30.0, ang - 1.2, a, 14, Color(col, 0.35), 10.0)
		draw_line(Vector2.from_angle(a) * 8.0, tip, col, 4.0)
		draw_line(Vector2.from_angle(a) * 8.0, tip, Color(1, 1, 1, 0.7), 1.5)
		if weapon == 1:
			for i in 3:
				draw_circle(tip * (0.6 + i * 0.15) + Vector2(randf_range(-3, 3), randf_range(-3, 3)), 3.0, Color(1, 0.7, 0.2, 0.8))
		elif weapon == 2:
			draw_circle(tip, 4.0, Color(0.8, 0.95, 1.0, 0.8))
	else:
		var hand := facing.rotated(PI * 0.5) * 8.0 + Vector2(0, 3)
		var tip2 := hand + Vector2.from_angle(ang - 0.6) * 18.0
		draw_line(hand, tip2, col, 3.0)
		draw_line(hand - Vector2.from_angle(ang - 0.6).orthogonal() * 3.0, hand + Vector2.from_angle(ang - 0.6).orthogonal() * 3.0, Color(0.3, 0.3, 0.3), 2.0)
		if weapon > 0:
			draw_circle(tip2, 2.5, Color(col, 0.6))
	if slow > 0.0:
		# Spinnennetz klebt am Helden
		for i in 4:
			var a := TAU * i / 4.0 + 0.4
			draw_line(Vector2.from_angle(a) * 4.0, Vector2.from_angle(a) * 15.0, Color(1, 1, 1, 0.7), 1.0)
		draw_arc(Vector2.ZERO, 9.0, 0, TAU, 12, Color(1, 1, 1, 0.6), 1.0)
		draw_arc(Vector2.ZERO, 14.0, 0, TAU, 12, Color(1, 1, 1, 0.5), 1.0)

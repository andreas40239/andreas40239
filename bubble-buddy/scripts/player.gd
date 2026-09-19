class_name BBPlayer
extends Node2D
## Finley, a small bright clownfish.
##
## Finley cannot die, lose a life, or fail. The worst thing that happens is a
## one second dizzy wobble and a few dropped pearls, which can be picked back up.

const RADIUS := 46.0
const MOVE_SPEED := 1150.0
const STEER_SMOOTH := 9.0
const BUBBLE_INTERVAL := 1.2      # auto bubble stream (GDD 4)
const BIG_BUBBLE_COOLDOWN := 3.0
const BIG_BUBBLE_CHARGE := 0.45   # hold time for a fully grown bubble
const DIZZY_TIME := 1.0
const TRAIL_LENGTH := 26

signal fired_big_bubble(charge: float)
signal fired_small_bubble

var target := Vector2.ZERO
var velocity := Vector2.ZERO
var dizzy := 0.0
var shield := false
var rainbow := 0.0
var current := 0.0
var celebrate := 0.0
var tangle := 0.0      # slowed for a moment by tangled seaweed
var charging := false
var charge := 0.0
var cooldown := 0.0

var _bubble_timer := BUBBLE_INTERVAL * 0.5
var _pucker := 0.0
var _blink := 0.0
var _blink_timer := 2.0
var _tail := 0.0
var _bob := 0.0
var _trail: Array[Vector2] = []
var _shield_visual: BBBubbleVisual
var _trail_particles: GPUParticles2D


func _ready() -> void:
	z_index = 20
	_shield_visual = BBBubbleVisual.new()
	_shield_visual.diameter = 210.0
	_shield_visual.visible = false
	_shield_visual.z_index = -1
	add_child(_shield_visual)
	_build_trail_particles()


func _build_trail_particles() -> void:
	_trail_particles = GPUParticles2D.new()
	_trail_particles.amount = 18
	_trail_particles.lifetime = 1.6
	_trail_particles.texture = BBDraw.dot_texture()
	_trail_particles.position = Vector2(-52, 6)
	_trail_particles.z_index = -2
	_trail_particles.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(-1, -0.4, 0)
	m.spread = 25.0
	m.initial_velocity_min = 40.0
	m.initial_velocity_max = 110.0
	m.gravity = Vector3(0, -120, 0)
	m.scale_min = 0.12
	m.scale_max = 0.4
	m.color = Color(0.9, 0.98, 1.0, 0.55)
	_trail_particles.process_material = m
	add_child(_trail_particles)


func tick(delta: float, bounds: Rect2) -> void:
	_tail += delta * (9.0 + velocity.length() * 0.006)
	_bob += delta * 2.1
	cooldown = maxf(cooldown - delta, 0.0)
	dizzy = maxf(dizzy - delta, 0.0)
	rainbow = maxf(rainbow - delta, 0.0)
	current = maxf(current - delta, 0.0)
	celebrate = maxf(celebrate - delta, 0.0)
	tangle = maxf(tangle - delta, 0.0)
	_pucker = maxf(_pucker - delta * 2.4, 0.0)

	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = randf_range(2.2, 5.5)
		_blink = 1.0
	_blink = maxf(_blink - delta * 4.0, 0.0)

	if charging:
		charge = minf(charge + delta / BIG_BUBBLE_CHARGE, 1.0)

	# Steering. While dizzy Finley drifts instead of responding, which reads as
	# a wobble rather than as lost control.
	var desired := target
	if dizzy > 0.0:
		desired = position + Vector2(sin(dizzy * 18.0) * 80.0, 30.0)
	# Tangled seaweed makes Finley sluggish for a moment, never stuck.
	var smooth := STEER_SMOOTH * (0.45 if tangle > 0.0 else 1.0)
	var top_speed := MOVE_SPEED * (0.5 if tangle > 0.0 else 1.0)
	var to_target := desired - position
	var step := to_target * clampf(delta * smooth, 0.0, 1.0)
	if step.length() > top_speed * delta:
		step = step.normalized() * top_speed * delta
	velocity = step / maxf(delta, 0.0001)
	position += step

	# The Speed Current carries Finley upward; the player still steers sideways.
	if current > 0.0:
		position.y -= 210.0 * delta

	position.x = clampf(position.x, bounds.position.x, bounds.position.x + bounds.size.x)
	position.y = clampf(position.y, bounds.position.y, bounds.position.y + bounds.size.y)

	_bubble_timer -= delta
	if _bubble_timer <= 0.0:
		_bubble_timer = BUBBLE_INTERVAL
		if dizzy <= 0.0:
			_pucker = 1.0
			fired_small_bubble.emit()

	_shield_visual.visible = shield
	_trail_particles.emitting = dizzy <= 0.0

	if rainbow > 0.0:
		_trail.push_front(position)
		while _trail.size() > TRAIL_LENGTH:
			_trail.pop_back()
	elif not _trail.is_empty():
		_trail.pop_back()

	queue_redraw()


func start_charge() -> void:
	if cooldown > 0.0 or dizzy > 0.0:
		return
	charging = true
	charge = 0.0


func release_charge() -> void:
	if not charging:
		return
	charging = false
	if cooldown > 0.0:
		return
	# Even the briefest tap produces a usable bubble: no precision required.
	var power: float = maxf(charge, 0.35)
	charge = 0.0
	cooldown = BIG_BUBBLE_COOLDOWN
	_pucker = 1.0
	fired_big_bubble.emit(power)


func hit() -> void:
	dizzy = DIZZY_TIME
	charging = false
	charge = 0.0


func cooldown_ratio() -> float:
	return 1.0 - cooldown / BIG_BUBBLE_COOLDOWN


func body_rotation() -> float:
	var tilt: float = clampf(velocity.x * 0.00035, -0.32, 0.32)
	if dizzy > 0.0:
		tilt += sin(dizzy * 26.0) * 0.5
	if celebrate > 0.0:
		# Loop-de-loop celebration.
		tilt += TAU * (1.0 - celebrate / 1.2)
	return tilt + sin(_bob) * 0.04


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if rainbow > 0.0 and _trail.size() > 2:
		_draw_rainbow_trail()

	var rot := body_rotation()
	var t := Transform2D(rot, Vector2.ZERO)
	draw_set_transform_matrix(t)

	var body_col := Color(1.0, 0.54, 0.16)
	var body_light := Color(1.0, 0.68, 0.32)
	if rainbow > 0.0:
		body_col = body_col.lerp(BBDraw.rainbow_color(age_hue()), 0.45)

	var rx := 62.0
	var ry := 46.0 + sin(_bob * 1.3) * 1.5

	# Tail fin (wiggles with swim speed).
	var wig := sin(_tail) * 0.55
	var tail_base := Vector2(-rx * 0.86, 0)
	draw_colored_polygon(PackedVector2Array([
		tail_base + Vector2(6, -10),
		tail_base + Vector2(-46, -40 + wig * 24),
		tail_base + Vector2(-34, 0 + wig * 10),
		tail_base + Vector2(-46, 40 + wig * 24),
		tail_base + Vector2(6, 10),
	]), body_col.darkened(0.06))

	# Dorsal and belly fins.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -ry * 0.92), Vector2(-34, -ry - 26 + wig * 8), Vector2(20, -ry * 0.86),
	]), body_col.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, ry * 0.9), Vector2(-26, ry + 20 - wig * 6), Vector2(18, ry * 0.84),
	]), body_col.darkened(0.1))

	# Body.
	BBDraw.ellipse(self, Vector2.ZERO, rx, ry, body_col, 0.0, 34)
	BBDraw.ellipse(self, Vector2(6, -ry * 0.28), rx * 0.74, ry * 0.42, body_light, 0.0, 28)

	# Two white stripes with soft dark edging, the clownfish signature.
	_draw_stripe(-12.0, rx, ry)
	_draw_stripe(26.0, rx, ry)

	# Pectoral fin, flapping quickly.
	var flap := sin(_tail * 1.6) * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, 8), Vector2(-16, 34 + flap * 14), Vector2(22, 24 + flap * 6),
	]), Color(1.0, 0.78, 0.5, 0.92))

	# Face.
	var look := Vector2(clampf(velocity.x * 0.0006, -1.0, 1.0), clampf(velocity.y * 0.0004, -0.6, 0.6))
	if dizzy > 0.0:
		BBDraw.spiral_eye(self, Vector2(rx * 0.46, -8), 15.0, -dizzy * 9.0)
	else:
		BBDraw.eye(self, Vector2(rx * 0.46, -8), 15.0, look, _blink)

	# Mouth: a small "o" that puffs out when blowing bubbles.
	var mouth := Vector2(rx * 0.92, 12)
	var pucker := _pucker
	if charging:
		pucker = maxf(pucker, 0.4 + charge * 0.6)
	BBDraw.ellipse(self, mouth, 7.0 + pucker * 7.0, 6.0 + pucker * 8.0, Color(0.85, 0.35, 0.28), 0.0, 14)
	if pucker > 0.05:
		# Puffed cheek.
		BBDraw.ellipse(self, Vector2(rx * 0.56, 14), 13.0 * pucker, 11.0 * pucker, body_light, 0.0, 14)

	draw_set_transform_matrix(Transform2D.IDENTITY)

	if charging:
		_draw_charge_bubble()
	_draw_cooldown_meter()


func age_hue() -> float:
	return fposmod(Time.get_ticks_msec() * 0.0004, 1.0)


func _draw_stripe(x: float, rx: float, ry: float) -> void:
	var h := ry * sqrt(maxf(0.0, 1.0 - pow(x / rx, 2.0))) * 1.02
	var w := 13.0
	var pts := PackedVector2Array()
	for i in 12:
		var k: float = lerpf(-1.0, 1.0, float(i) / 11.0)
		pts.append(Vector2(x + sin(k * 1.4) * 5.0 - w, h * k))
	for i in 12:
		var k: float = lerpf(1.0, -1.0, float(i) / 11.0)
		pts.append(Vector2(x + sin(k * 1.4) * 5.0 + w, h * k))
	draw_colored_polygon(pts, Color(1, 1, 1, 0.95))


func _draw_charge_bubble() -> void:
	var r: float = lerpf(16.0, 62.0, charge)
	var pos := Vector2(78, 10)
	draw_circle(pos, r, Color(0.82, 0.96, 1.0, 0.3))
	draw_arc(pos, r, 0.0, TAU, 28, Color(1, 1, 1, 0.8), 4.0, true)
	draw_circle(pos + Vector2(-r * 0.3, -r * 0.3), r * 0.22, Color(1, 1, 1, 0.75))


## The Big Bubble cooldown lives as a small meter around Finley (GDD 9, HUD).
func _draw_cooldown_meter() -> void:
	if cooldown <= 0.0:
		return
	var ratio := cooldown_ratio()
	draw_arc(Vector2.ZERO, 86.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 36, Color(0.8, 0.96, 1.0, 0.75), 7.0, true)


func _draw_rainbow_trail() -> void:
	for i in range(_trail.size() - 1):
		var a := to_local(_trail[i])
		var b := to_local(_trail[i + 1])
		var k := float(i) / float(_trail.size())
		var col := BBDraw.rainbow_color(age_hue() + k * 0.5)
		col.a = (1.0 - k) * 0.7
		draw_line(a, b, col, lerpf(56.0, 8.0, k), true)

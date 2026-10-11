extends Node2D
## 1: Der Endlos-Drache - fliegt ewig eine liegende Acht durch die Halle.

const CENTER := Vector2(46.5 * 32, 7.0 * 32)
const AMP := Vector2(440.0, 128.0)
const SPEED := TAU / 9.0
const SEGMENTS := 22
const SPACING := 0.085

var game: Node
var s := 0.0
var frozen := 0.0
var fire_cd := 3.0
var anim := 0.0
var seg_pos: Array = []
var seg_r: Array = []


func _ready() -> void:
	for i in SEGMENTS:
		var k := float(i) / (SEGMENTS - 1)
		seg_r.append(lerpf(17.0, 6.0, k) if i > 0 else 18.0)
		seg_pos.append(Vector2.ZERO)
	_layout()


func curve(p: float) -> Vector2:
	return CENTER + Vector2(AMP.x * sin(p), AMP.y * sin(2.0 * p))


func _layout() -> void:
	for i in SEGMENTS:
		seg_pos[i] = curve(s - i * SPACING)


func update(dt: float) -> void:
	anim += dt
	if frozen > 0.0:
		frozen -= dt
	else:
		s = fmod(s + SPEED * dt, TAU * 100.0)
		_maybe_breathe(dt)
	_layout()
	queue_redraw()


func _maybe_breathe(dt: float) -> void:
	var p: Vector2 = game.player.position
	if game.state != "play" or p.y > 12 * 32 or p.x < 29 * 32:
		return
	fire_cd -= dt
	if fire_cd <= 0.0:
		fire_cd = randf_range(2.6, 4.0)
		var head: Vector2 = seg_pos[0]
		if head.distance_to(p) < 420.0:
			game.spawn_projectile(head, (p - head).normalized() * 170.0, "fireball")
			game.audio.sfx("fire", -2.0)


func freeze(t: float) -> void:
	frozen = maxf(frozen, t)


func touches(p: Vector2, r: float) -> bool:
	if frozen > 0.0:
		return false
	for i in SEGMENTS:
		if p.distance_to(seg_pos[i]) < r + seg_r[i] - 3.0:
			return true
	return false


func hit_test(p: Vector2, r: float) -> bool:
	for i in SEGMENTS:
		if p.distance_to(seg_pos[i]) < r + seg_r[i]:
			return true
	return false


func push_dir(p: Vector2) -> Vector2:
	var best := 0
	var bd := INF
	for i in SEGMENTS:
		var d: float = p.distance_squared_to(seg_pos[i])
		if d < bd:
			bd = d
			best = i
	return (p - seg_pos[best]).normalized()


func _draw() -> void:
	var ice := frozen > 0.0
	var body := Color(0.75, 0.15, 0.12) if not ice else Color(0.6, 0.85, 1.0)
	var belly := Color(0.95, 0.6, 0.2) if not ice else Color(0.85, 0.95, 1.0)
	var spike := Color(0.35, 0.05, 0.05) if not ice else Color(0.4, 0.6, 0.8)
	# Schatten am Boden
	for i in range(SEGMENTS - 1, -1, -3):
		draw_circle(seg_pos[i] + Vector2(10, 26), seg_r[i] * 0.8, Color(0, 0, 0, 0.18))
	# Fluegel am 4. Segment
	var wseg: Vector2 = seg_pos[4]
	var wdir: Vector2 = (seg_pos[3] - seg_pos[5]).normalized()
	var flap := sin(anim * 7.0) if not ice else 0.3
	for sgn in [-1.0, 1.0]:
		var n: Vector2 = wdir.orthogonal() * sgn
		var pts := PackedVector2Array([
			wseg + wdir * 10.0,
			wseg + n * (46.0 + flap * 12.0) + wdir * 6.0,
			wseg + n * (38.0 + flap * 10.0) - wdir * 14.0,
			wseg + n * (26.0 + flap * 6.0) - wdir * 8.0,
			wseg + n * (20.0 + flap * 4.0) - wdir * 22.0,
			wseg - wdir * 12.0])
		draw_colored_polygon(pts, Color(body.darkened(0.35), 0.92))
		draw_line(wseg, wseg + n * (46.0 + flap * 12.0) + wdir * 6.0, spike, 2.0)
	# Koerper von hinten nach vorne
	for i in range(SEGMENTS - 1, 0, -1):
		var p: Vector2 = seg_pos[i]
		var r: float = seg_r[i]
		draw_circle(p, r, body)
		draw_circle(p + Vector2(0, r * 0.35), r * 0.55, belly)
		var d: Vector2 = (seg_pos[i - 1] - p).normalized()
		var n2 := d.orthogonal()
		draw_colored_polygon(PackedVector2Array([p - n2 * r * 0.3, p - n2 * (r + 6), p + d * r * 0.3]), spike)
	# Kopf
	var h: Vector2 = seg_pos[0]
	var hd: Vector2 = (seg_pos[0] - seg_pos[1]).normalized()
	var hn := hd.orthogonal()
	draw_circle(h, 16, body)
	draw_colored_polygon(PackedVector2Array([h + hn * 12, h + hd * 26 + hn * 5, h + hd * 26 - hn * 5, h - hn * 12]), body)
	var jaw := 3.0 + (2.0 + 2.0 * sin(anim * 10.0) if fire_cd < 0.6 and not ice else 0.0)
	draw_line(h + hd * 26, h + hd * 12, Color(0.2, 0, 0), jaw)
	for sgn in [-1.0, 1.0]:
		draw_line(h - hd * 6 + hn * 8 * sgn, h - hd * 22 + hn * 16 * sgn, Color(0.9, 0.85, 0.7), 4.0)
		draw_circle(h + hd * 6 + hn * 7 * sgn, 3.5, Color(1, 0.9, 0.1))
		draw_circle(h + hd * 7 + hn * 7 * sgn, 1.5, Color.BLACK)
	if fire_cd < 0.6 and not ice:
		draw_circle(h + hd * 30, 5 + 3 * sin(anim * 30.0), Color(1, 0.6, 0.1, 0.8))
	if ice:
		for i in range(0, SEGMENTS, 3):
			draw_arc(seg_pos[i], seg_r[i] + 3, 0, TAU, 12, Color(0.9, 1, 1, 0.7), 1.5)

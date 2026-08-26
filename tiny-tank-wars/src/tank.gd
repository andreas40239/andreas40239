# A friendly cartoon tank, fully drawn in code (GDD section 15 art style).
class_name Tank
extends Node2D

var idx := 0                # turn-order index
var seat := 0               # human seat index (points/upgrades pool)
var is_human := true
var display_name := "Player 1"
var color := Color(0.9, 0.3, 0.3)
var symbol := "●"

var hp := 100.0
var alive := true
var angle := 60.0           # 0..180 deg
var power := 55.0           # 0..100 %
var damage_dealt := 0.0

# Iron Cover: absorbs one direct hit per level, then shows cracks.
var shield_active := false
var shield_cracked := false

# AI state
var ai_tier := 0            # 0 rookie, 1 semi-rookie, 2 cadet, 3 veteran
var personality := 0        # 0 none, 1 high-archer, 2 straight-shooter, 3 power-player
var ai_memory := {}

var _t := 0.0
var _flash := 0.0
var _my_turn := false

const R := 26.0

func center() -> Vector2:
	return global_position + Vector2(0, -16)

func barrel_tip() -> Vector2:
	var a := deg_to_rad(angle)
	return center() + Vector2(cos(a), -sin(a)) * 42.0

func setup(p_idx: int, p_seat: int, p_human: bool, p_name: String) -> void:
	idx = p_idx
	seat = p_seat
	is_human = p_human
	display_name = p_name
	color = UIKit.PLAYER_COLORS[idx]
	symbol = UIKit.PLAYER_SYMBOLS[idx]
	angle = 60.0 if global_position.x < 1200.0 else 120.0
	power = 55.0

func hp_color() -> Color:
	if hp >= 60.0:
		return Color(0.35, 0.8, 0.35)
	if hp >= 30.0:
		return Color(0.95, 0.8, 0.2)
	return Color(0.9, 0.3, 0.25)

func hurt_flash() -> void:
	_flash = 1.0

func set_my_turn(v: bool) -> void:
	_my_turn = v
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
	queue_redraw()

func _draw() -> void:
	if not alive:
		return
	var bounce: float = sin(_t * 3.0 + float(idx) * 1.7) * 1.5
	var o := Vector2(0, bounce)
	var body_col := color if _flash <= 0.0 else color.lerp(Color.WHITE, _flash)
	# Shadow.
	draw_ellipse_approx(Vector2(0, 4), Vector2(30, 7), Color(0, 0, 0, 0.18))
	# Tracks.
	draw_rounded_rect(Rect2(-28, -12 + o.y, 56, 16), 8, Color(0.32, 0.33, 0.4))
	for i in range(4):
		draw_circle(Vector2(-19.5 + i * 13.0, -4 + o.y), 4.5, Color(0.62, 0.63, 0.7))
	# Barrel (behind turret).
	var a := deg_to_rad(angle)
	var dirv := Vector2(cos(a), -sin(a))
	var pivot := Vector2(0, -16) + o
	draw_line(pivot, pivot + dirv * 42.0, Color(0.36, 0.42, 0.52), 11.0)
	draw_circle(pivot + dirv * 42.0, 5.5, Color(0.36, 0.42, 0.52))
	# Hull.
	draw_rounded_rect(Rect2(-26, -22 + o.y, 52, 14), 7, body_col)
	# Turret dome.
	draw_circle_arc_dome(pivot, 15.0, body_col.lightened(0.12))
	# Face: eyes look toward barrel direction, expression follows HP.
	var look := Vector2(cos(a), -sin(a)) * 2.0
	for ex in [-6.0, 6.0]:
		var ec := pivot + Vector2(ex, -6)
		draw_circle(ec, 4.6, Color.WHITE)
		draw_circle(ec + look, 2.2, Color(0.15, 0.15, 0.25))
	if hp >= 40.0:
		draw_arc(pivot + Vector2(0, -3), 5.0, 0.35, PI - 0.35, 10, Color(0.25, 0.1, 0.1), 2.0)
	else:
		draw_arc(pivot + Vector2(0, 3.0), 5.0, PI + 0.35, TAU - 0.35, 10, Color(0.25, 0.1, 0.1), 2.0)
	# Iron Cover dome.
	if shield_active or shield_cracked:
		var sc := Color(0.5, 0.85, 1.0, 0.28 if shield_active else 0.14)
		draw_circle(Vector2(0, -14) + o, 40.0, sc)
		draw_arc(Vector2(0, -14) + o, 40.0, PI, TAU, 24, Color(0.6, 0.9, 1.0, 0.8), 3.0)
		if shield_cracked:
			var cc := Color(0.9, 0.95, 1.0, 0.85)
			draw_line(Vector2(-6, -46) + o, Vector2(2, -30) + o, cc, 2.0)
			draw_line(Vector2(2, -30) + o, Vector2(-4, -20) + o, cc, 2.0)
			draw_line(Vector2(2, -30) + o, Vector2(12, -26) + o, cc, 2.0)
	# Health bar + badge above.
	var bw := 56.0
	var by := -58.0 + o.y
	draw_rounded_rect(Rect2(-bw / 2.0 - 2, by - 2, bw + 4, 12), 5, Color(0, 0, 0, 0.35))
	draw_rounded_rect(Rect2(-bw / 2.0, by, bw * clampf(hp / 100.0, 0.0, 1.0), 8), 4, hp_color())
	# Player badge: colored disc + geometric symbol (colorblind-friendly).
	var bc := Vector2(0, by - 16)
	draw_circle(bc, 12.0, color)
	draw_arc(bc, 12.0, 0, TAU, 20, Color(1, 1, 1, 0.9), 2.0)
	draw_symbol(bc, 6.5, idx, Color.WHITE)
	# Active-turn arrow.
	if _my_turn:
		var ay: float = by - 34.0 + sin(_t * 6.0) * 3.0
		var tri := PackedVector2Array([Vector2(-9, ay - 10), Vector2(9, ay - 10), Vector2(0, ay)])
		draw_colored_polygon(tri, Color(1.0, 1.0, 1.0, 0.95))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.2, 0.3, 0.4, 0.8), 2.0)

# Geometric player symbols: 0 circle, 1 triangle, 2 square, 3 star.
func draw_symbol(c: Vector2, s: float, which: int, col: Color) -> void:
	match which:
		0:
			draw_circle(c, s, col)
		1:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -s), c + Vector2(s, s * 0.8), c + Vector2(-s, s * 0.8)]), col)
		2:
			draw_rect(Rect2(c - Vector2(s * 0.85, s * 0.85), Vector2(s * 1.7, s * 1.7)), col)
		3:
			var pts := PackedVector2Array()
			for i in range(10):
				var a := -PI / 2.0 + TAU * float(i) / 10.0
				var rr := s * 1.2 if i % 2 == 0 else s * 0.5
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, col)

func draw_rounded_rect(r: Rect2, rad: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	draw_style_box(sb, r)

func draw_ellipse_approx(c: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, col)

func draw_circle_arc_dome(c: Vector2, rad: float, col: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(c + Vector2(rad, 2))
	for i in range(16):
		var a := PI * float(i) / 15.0
		pts.append(c + Vector2(cos(a) * rad, -sin(a) * rad + 2.0))
	pts.append(c + Vector2(-rad, 2))
	draw_colored_polygon(pts, col)

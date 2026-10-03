class_name Icons
extends RefCounted
## Einfache, runde Vektor-Icons. Nur innerhalb von _draw() eines CanvasItems aufrufen.
## c = Mittelpunkt, s = Größe (ungefährer Durchmesser).

const INK := Color("2f3b5c")


static func draw(ci: CanvasItem, icon: StringName, c: Vector2, s: float, tint: Color = Color.WHITE) -> void:
	match icon:
		&"apple": apple(ci, c, s)
		&"bubble": bubble(ci, c, s)
		&"note": note(ci, c, s, Color("3a56c8"))
		&"moon": moon(ci, c, s, Color("ffd84d"))
		&"pinwheel": pinwheel(ci, c, s, 0.0)
		&"heart": heart(ci, c, s, Color("ff5a87"))
		&"sun": sun(ci, c, s)
		&"swirl": swirl(ci, c, s, Color("9b59d0"))
		&"flag": flag(ci, c, s)
		&"pause": pause(ci, c, s, tint)
		&"play": play(ci, c, s, tint)
		&"fast": fast(ci, c, s, tint)
		&"gear": gear(ci, c, s, tint)
		&"star": star(ci, c, s, Color("ffd23f"), false)
		&"star_empty": star(ci, c, s, Color(1, 1, 1, 0.45), true)
		&"lock": lock(ci, c, s)
		&"plus": plus(ci, c, s, tint)
		&"close": close(ci, c, s, tint)
		&"coins": coins(ci, c, s)
		&"range": range_icon(ci, c, s, tint)
		&"power": sparkle(ci, c, s, tint)
		&"sparkle": sparkle(ci, c, s, tint)
		&"retry": retry(ci, c, s, tint)
		&"map": map_icon(ci, c, s)
		&"back": back(ci, c, s, tint)
		&"cookie": cookie(ci, c, s)
		&"zzz": zzz(ci, c, s, tint)
		&"check": check(ci, c, s, tint)
		_:
			ci.draw_circle(c, s * 0.3, tint)


# --- Hilfsfunktionen -------------------------------------------------------------

static func ellipse_points(c: Vector2, rx: float, ry: float, rot: float = 0.0, segments: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rt := Transform2D(rot, c)
	for i in segments:
		var a := TAU * i / segments
		pts.append(rt * Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color, rot: float = 0.0) -> void:
	ci.draw_colored_polygon(ellipse_points(c, rx, ry, rot), color)


static func ellipse_outline(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color, width: float, rot: float = 0.0) -> void:
	var pts := ellipse_points(c, rx, ry, rot, 32)
	pts.append(pts[0])
	ci.draw_polyline(pts, color, width, true)


static func disc(ci: CanvasItem, c: Vector2, r: float, color: Color, outline: Color = Color(0, 0, 0, 0), width: float = 0.0) -> void:
	ci.draw_circle(c, r, color)
	if width > 0.0:
		ci.draw_arc(c, r, 0, TAU, 32, outline, width, true)


static func rounded_rect(ci: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	ci.draw_rect(Rect2(rect.position + Vector2(r, 0), rect.size - Vector2(2 * r, 0)), color)
	ci.draw_rect(Rect2(rect.position + Vector2(0, r), rect.size - Vector2(0, 2 * r)), color)
	ci.draw_circle(rect.position + Vector2(r, r), r, color)
	ci.draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color)
	ci.draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color)
	ci.draw_circle(rect.end - Vector2(r, r), r, color)


static func thick_line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	ci.draw_line(a, b, color, width, true)
	ci.draw_circle(a, width * 0.5, color)
	ci.draw_circle(b, width * 0.5, color)


# --- Bedürfnis-Icons ------------------------------------------------------------

static func apple(ci: CanvasItem, c: Vector2, s: float) -> void:
	var r := s * 0.36
	var red := Color("ef4b4b")
	var o := c + Vector2(0, s * 0.06)
	ci.draw_circle(o + Vector2(-r * 0.36, 0), r * 0.82, red)
	ci.draw_circle(o + Vector2(r * 0.36, 0), r * 0.82, red)
	ci.draw_circle(o + Vector2(0, r * 0.18), r * 0.8, red)
	ci.draw_circle(o + Vector2(-r * 0.45, -r * 0.2), r * 0.22, Color(1, 1, 1, 0.55))
	ci.draw_line(o + Vector2(0, -r * 0.55), o + Vector2(r * 0.15, -r * 1.15), Color("7a4a26"), s * 0.08, true)
	ellipse(ci, o + Vector2(r * 0.52, -r * 0.98), r * 0.4, r * 0.18, Color("4caf50"), -0.5)


static func bubble(ci: CanvasItem, c: Vector2, s: float) -> void:
	var r := s * 0.32
	var o := c + Vector2(-s * 0.06, s * 0.06)
	ci.draw_circle(o, r, Color(0.6, 0.87, 1.0, 0.55))
	ci.draw_arc(o, r, 0, TAU, 32, Color("3d9ad6"), s * 0.06, true)
	ci.draw_arc(o, r * 0.62, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.95), s * 0.06, true)
	var o2 := c + Vector2(s * 0.27, -s * 0.24)
	ci.draw_circle(o2, r * 0.42, Color(0.6, 0.87, 1.0, 0.55))
	ci.draw_arc(o2, r * 0.42, 0, TAU, 20, Color("3d9ad6"), s * 0.045, true)


static func note(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var head1 := c + Vector2(-s * 0.2, s * 0.24)
	var head2 := c + Vector2(s * 0.2, s * 0.14)
	ellipse(ci, head1, s * 0.14, s * 0.1, col, -0.35)
	ellipse(ci, head2, s * 0.14, s * 0.1, col, -0.35)
	var w := s * 0.07
	ci.draw_line(head1 + Vector2(s * 0.11, -s * 0.02), head1 + Vector2(s * 0.11, -s * 0.48), col, w, true)
	ci.draw_line(head2 + Vector2(s * 0.11, -s * 0.02), head2 + Vector2(s * 0.11, -s * 0.48), col, w, true)
	var beam := PackedVector2Array([
		head1 + Vector2(s * 0.08, -s * 0.48), head2 + Vector2(s * 0.14, -s * 0.58),
		head2 + Vector2(s * 0.14, -s * 0.44), head1 + Vector2(s * 0.08, -s * 0.34)])
	ci.draw_colored_polygon(beam, col)


static func moon(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var r1 := s * 0.38
	var off := Vector2(r1 * 0.55, -r1 * 0.3)
	var r2 := r1 * 0.82
	var d := off.length()
	var a := (r1 * r1 - r2 * r2 + d * d) / (2.0 * d)
	var theta := acos(clampf(a / r1, -1.0, 1.0))
	var u := off.angle()
	var pts := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var ang := lerpf(u + theta, u + TAU - theta, float(i) / steps)
		pts.append(c + Vector2(cos(ang), sin(ang)) * r1)
	var c2 := c + off
	var p1 := c + Vector2(cos(u + theta), sin(u + theta)) * r1
	var p2 := pts[pts.size() - 1]
	var m := u + PI
	var d2 := wrapf((p2 - c2).angle() - m, -PI, PI)
	var d1 := wrapf((p1 - c2).angle() - m, -PI, PI)
	for i in range(1, steps):
		var ang := m + lerpf(d2, d1, float(i) / steps)
		pts.append(c2 + Vector2(cos(ang), sin(ang)) * r2)
	ci.draw_colored_polygon(pts, col)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, col.darkened(0.3), s * 0.04, true)


static func pinwheel(ci: CanvasItem, c: Vector2, s: float, rot: float) -> void:
	thick_line(ci, c, c + Vector2(0, s * 0.48), Color("8d6e4a"), s * 0.07)
	var cols := [Color("ff6b6b"), Color("ffd23f"), Color("4f8fe8"), Color("5fd068")]
	for i in 4:
		var a := rot + i * PI * 0.5
		var tip := c + Vector2(cos(a), sin(a)) * s * 0.42
		var side := c + Vector2(cos(a + 0.95), sin(a + 0.95)) * s * 0.3
		ci.draw_colored_polygon(PackedVector2Array([c, tip, side]), cols[i])
	ci.draw_circle(c, s * 0.07, Color.WHITE)


# --- Allgemeine Icons -----------------------------------------------------------

static func heart(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var k := s / 34.0
	for i in 40:
		var t := TAU * i / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(c + Vector2(x, y + 1.5) * k)
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(c + Vector2(-6, -5) * k, 3.2 * k, Color(1, 1, 1, 0.6))


static func sun(ci: CanvasItem, c: Vector2, s: float) -> void:
	var ray := Color("ffb02e")
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		ci.draw_colored_polygon(PackedVector2Array([
			c + d * s * 0.5, c + d * s * 0.26 + n * s * 0.1, c + d * s * 0.26 - n * s * 0.1]), ray)
	ci.draw_circle(c, s * 0.3, Color("ffd23f"))
	ci.draw_arc(c, s * 0.3, 0, TAU, 28, ray, s * 0.05, true)
	ci.draw_arc(c + Vector2(0, s * 0.02), s * 0.12, 0.3, PI - 0.3, 10, Color("b8641c"), s * 0.04, true)


static func swirl(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 46:
		var ang := k * 0.32
		var r := s * 0.03 + k * s * 0.0092
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	ci.draw_polyline(pts, col, s * 0.09, true)
	ci.draw_circle(pts[pts.size() - 1], s * 0.045, col)


static func flag(ci: CanvasItem, c: Vector2, s: float) -> void:
	thick_line(ci, c + Vector2(-s * 0.24, s * 0.42), c + Vector2(-s * 0.24, -s * 0.42), Color("6b5a4a"), s * 0.07)
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.22, -s * 0.4), c + Vector2(s * 0.36, -s * 0.25), c + Vector2(-s * 0.22, -s * 0.06)]),
		Color("5fd068"))


static func pause(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	rounded_rect(ci, Rect2(c + Vector2(-s * 0.28, -s * 0.32), Vector2(s * 0.2, s * 0.64)), s * 0.07, col)
	rounded_rect(ci, Rect2(c + Vector2(s * 0.08, -s * 0.32), Vector2(s * 0.2, s * 0.64)), s * 0.07, col)


static func play(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.22, -s * 0.34), c + Vector2(s * 0.34, 0), c + Vector2(-s * 0.22, s * 0.34)]), col)


static func fast(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	for dx in [-s * 0.18, s * 0.16]:
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2(dx - s * 0.18, -s * 0.28), c + Vector2(dx + s * 0.18, 0), c + Vector2(dx - s * 0.18, s * 0.28)]), col)


static func gear(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var teeth := 8
	for i in teeth * 4:
		var a := TAU * i / (teeth * 4.0)
		var r: float = s * 0.42 if (i % 4) < 2 else s * 0.31
		pts.append(c + Vector2(cos(a + 0.2), sin(a + 0.2)) * r)
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(c, s * 0.13, col.darkened(0.45))


static func star(ci: CanvasItem, c: Vector2, s: float, col: Color, empty: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0
		var r: float = s * 0.48 if i % 2 == 0 else s * 0.21
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, col)
	var outline := pts.duplicate()
	outline.append(pts[0])
	var oc: Color = Color(0.6, 0.6, 0.65, 0.9) if empty else Color("e09a12")
	ci.draw_polyline(outline, oc, s * 0.05, true)
	if not empty:
		ci.draw_circle(c + Vector2(-s * 0.08, -s * 0.06), s * 0.06, Color(1, 1, 1, 0.7))


static func lock(ci: CanvasItem, c: Vector2, s: float) -> void:
	var col := Color("8a93a8")
	ci.draw_arc(c + Vector2(0, -s * 0.08), s * 0.19, PI, TAU, 16, col.darkened(0.2), s * 0.09, true)
	ci.draw_line(c + Vector2(-s * 0.19, -s * 0.08), c + Vector2(-s * 0.19, s * 0.02), col.darkened(0.2), s * 0.09)
	ci.draw_line(c + Vector2(s * 0.19, -s * 0.08), c + Vector2(s * 0.19, s * 0.02), col.darkened(0.2), s * 0.09)
	rounded_rect(ci, Rect2(c + Vector2(-s * 0.3, -s * 0.02), Vector2(s * 0.6, s * 0.44)), s * 0.08, col)
	ci.draw_circle(c + Vector2(0, s * 0.17), s * 0.06, col.darkened(0.5))


static func plus(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	thick_line(ci, c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.3, 0), col, s * 0.16)
	thick_line(ci, c + Vector2(0, -s * 0.3), c + Vector2(0, s * 0.3), col, s * 0.16)


static func close(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	thick_line(ci, c + Vector2(-s * 0.24, -s * 0.24), c + Vector2(s * 0.24, s * 0.24), col, s * 0.13)
	thick_line(ci, c + Vector2(s * 0.24, -s * 0.24), c + Vector2(-s * 0.24, s * 0.24), col, s * 0.13)


static func coins(ci: CanvasItem, c: Vector2, s: float) -> void:
	for off in [Vector2(-s * 0.12, s * 0.08), Vector2(s * 0.12, -s * 0.08)]:
		ci.draw_circle(c + off, s * 0.26, Color("ffd23f"))
		ci.draw_arc(c + off, s * 0.26, 0, TAU, 24, Color("e09a12"), s * 0.05, true)
		ci.draw_arc(c + off, s * 0.15, 0, TAU, 20, Color("e09a12"), s * 0.03, true)


static func range_icon(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_arc(c, s * 0.4, 0, TAU, 32, col, s * 0.07, true)
	ci.draw_arc(c, s * 0.24, 0, TAU, 24, col, s * 0.07, true)
	ci.draw_circle(c, s * 0.09, col)


static func sparkle(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := -PI * 0.5 + TAU * i / 8.0
		var r: float = s * 0.46 if i % 2 == 0 else s * 0.13
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, col)


static func retry(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_arc(c, s * 0.3, -PI * 0.35, PI * 1.35, 24, col, s * 0.11, true)
	var a := -PI * 0.35
	var tip := c + Vector2(cos(a), sin(a)) * s * 0.3
	ci.draw_colored_polygon(PackedVector2Array([
		tip + Vector2(-s * 0.2, -s * 0.08), tip + Vector2(s * 0.12, -s * 0.2), tip + Vector2(s * 0.06, s * 0.16)]), col)


static func map_icon(ci: CanvasItem, c: Vector2, s: float) -> void:
	var cols := [Color("8fd16a"), Color("6bbf59"), Color("8fd16a")]
	for i in 3:
		var x0 := c.x - s * 0.36 + i * s * 0.24
		var y_off: float = s * 0.05 if i % 2 == 0 else -s * 0.05
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(x0, c.y - s * 0.3 + y_off), Vector2(x0 + s * 0.24, c.y - s * 0.3 - y_off),
			Vector2(x0 + s * 0.24, c.y + s * 0.3 - y_off), Vector2(x0, c.y + s * 0.3 + y_off)]), cols[i])
	ci.draw_circle(c + Vector2(s * 0.1, -s * 0.05), s * 0.07, Color("ef4b4b"))


static func back(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.36, 0), c + Vector2(-s * 0.02, -s * 0.3), c + Vector2(-s * 0.02, s * 0.3)]), col)
	thick_line(ci, c + Vector2(-s * 0.1, 0), c + Vector2(s * 0.32, 0), col, s * 0.16)


static func cookie(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_circle(c, s * 0.42, Color("d99a52"))
	ci.draw_arc(c, s * 0.42, 0, TAU, 28, Color("a8692c"), s * 0.05, true)
	var chips := [Vector2(-0.15, -0.14), Vector2(0.16, -0.08), Vector2(-0.02, 0.15), Vector2(0.2, 0.18), Vector2(-0.22, 0.1)]
	for p in chips:
		ci.draw_circle(c + p * s, s * 0.06, Color("5b3418"))


static func zzz(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := s * 0.1
	var pts := PackedVector2Array([
		c + Vector2(-s * 0.28, -s * 0.28), c + Vector2(s * 0.28, -s * 0.28),
		c + Vector2(-s * 0.28, s * 0.28), c + Vector2(s * 0.28, s * 0.28)])
	ci.draw_polyline(pts, col, w, true)


static func check(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_polyline(PackedVector2Array([
		c + Vector2(-s * 0.3, 0), c + Vector2(-s * 0.08, s * 0.24), c + Vector2(s * 0.32, -s * 0.24)]), col, s * 0.14, true)

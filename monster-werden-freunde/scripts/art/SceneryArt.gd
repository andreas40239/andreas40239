class_name SceneryArt
extends RefCounted
## Landschafts-Deko für die drei Welten (Wiese, Strand und Meer, Schnee und Berge).

## Farben pro Thema: Untergrund, Flecken hell/dunkel, Pfad außen/innen/Mitte.
const THEMES := {
	&"meadow": {"ground": Color("8fd16a"), "patch_a": Color(0.62, 0.86, 0.5, 0.35), "patch_b": Color(0.45, 0.74, 0.38, 0.25),
		"path_border": Color("c99d62"), "path": Color("edd3a0"), "path_mid": Color(0.98, 0.9, 0.74, 0.7), "plaza": Color("e9d3a3")},
	&"beach": {"ground": Color("f4dfa4"), "patch_a": Color(1.0, 0.95, 0.78, 0.5), "patch_b": Color(0.88, 0.78, 0.55, 0.3),
		"path_border": Color("9c6b3f"), "path": Color("c99a62"), "path_mid": Color(0.88, 0.7, 0.48, 0.8), "plaza": Color("fbefc8")},
	&"snow": {"ground": Color("eef6fc"), "patch_a": Color(1, 1, 1, 0.7), "patch_b": Color(0.78, 0.87, 0.95, 0.45),
		"path_border": Color("9dbbd0"), "path": Color("d3e4f0"), "path_mid": Color(0.9, 0.95, 1.0, 0.8), "plaza": Color("dfeaf3")},
}


static func colors(theme: StringName) -> Dictionary:
	return THEMES.get(theme, THEMES[&"meadow"])


## Meer am oberen Rand (Strand-Welt). y_edge = Wasserlinie.
static func sea(ci: CanvasItem, x0: float, x1: float, y_edge: float, t: float) -> void:
	ci.draw_rect(Rect2(x0, y_edge - 2000, x1 - x0, 2000), Color("5bc0eb"))
	ci.draw_rect(Rect2(x0, y_edge - 60, x1 - x0, 60), Color("7fd3f2"))
	var pts := PackedVector2Array()
	var x := x0
	while x <= x1:
		pts.append(Vector2(x, y_edge + sin(x * 0.02 + t * 1.5) * 8.0))
		x += 20.0
	ci.draw_polyline(pts, Color(1, 1, 1, 0.9), 10.0, true)
	for i in 12:
		var wx := x0 + fmod(i * 397.0 + t * 25.0, x1 - x0)
		ci.draw_arc(Vector2(wx, y_edge - 90 - (i % 3) * 40), 18, PI * 1.15, PI * 1.85, 8, Color(1, 1, 1, 0.6), 4.0, true)


## Berge am oberen Rand (Schnee-Welt).
static func mountains(ci: CanvasItem, x0: float, x1: float, base_y: float) -> void:
	ci.draw_rect(Rect2(x0, base_y - 2000, x1 - x0, 2000), Color("b9dcf2"))
	var x := x0
	var i := 0
	while x < x1:
		var w := 320.0 + (i % 3) * 90.0
		var h := 230.0 + (i % 2) * 90.0
		var peak := Vector2(x + w * 0.5, base_y - h)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, base_y), peak, Vector2(x + w, base_y)]), Color("8fb3cf") if i % 2 == 0 else Color("a3c3db"))
		ci.draw_colored_polygon(PackedVector2Array([peak, peak + Vector2(-w * 0.17, h * 0.34), peak + Vector2(-w * 0.05, h * 0.27),
			peak + Vector2(w * 0.05, h * 0.36), peak + Vector2(w * 0.17, h * 0.34)]), Color.WHITE)
		x += w * 0.7
		i += 1


static func palm(ci: CanvasItem, p: Vector2, s: float, t: float) -> void:
	Icons.ellipse(ci, p + Vector2(10, 4) * s, 40 * s, 12 * s, Color(0, 0, 0, 0.15))
	var top := p + Vector2(18, -120) * s
	var pts := PackedVector2Array()
	for k in 9:
		var f := k / 8.0
		pts.append(p.lerp(top, f) + Vector2(sin(f * PI) * -14.0 * s, 0))
	ci.draw_polyline(pts, Color("a8693a"), 13.0 * s, true)
	for k in range(1, 8, 2):
		ci.draw_circle(pts[k], 7.0 * s, Color("8d5f3a"))
	var sway := sin(t * 1.2) * 0.08
	for i in 6:
		var a := -PI * 0.5 + (i - 2.5) * 0.55 + sway
		var d := Vector2(cos(a), sin(a) * 0.6 + 0.35)
		var leaf := PackedVector2Array([top, top + d * 70 * s + Vector2(-d.y, d.x) * 14 * s, top + d * 95 * s, top + d * 60 * s - Vector2(-d.y, d.x) * 6 * s])
		ci.draw_colored_polygon(leaf, Color("3f9a52") if i % 2 == 0 else Color("4fb35e"))
	ci.draw_circle(top + Vector2(-6, 8) * s, 7 * s, Color("7a4a26"))
	ci.draw_circle(top + Vector2(6, 10) * s, 7 * s, Color("7a4a26"))


static func umbrella(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	Icons.ellipse(ci, p + Vector2(0, 2), 50 * s, 12 * s, Color(0, 0, 0, 0.12))
	ci.draw_line(p, p + Vector2(4, -80) * s, Color("8d6e4a"), 4.0 * s, true)
	var top := p + Vector2(4, -84) * s
	var pts := PackedVector2Array([top + Vector2(-56, 18) * s])
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(top + Vector2(cos(a) * 56, sin(a) * 30 + 18) * s)
	ci.draw_colored_polygon(pts, col)
	for i in 3:
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(0, -12) * s, top + Vector2(-38 + i * 38, 18) * s, top + Vector2(-20 + i * 38, 18) * s]), Color.WHITE)
	Icons.rounded_rect(ci, Rect2(p + Vector2(-34, -10) * s, Vector2(60, 14) * s), 6 * s, Color.from_hsv(fmod(col.h + 0.5, 1.0), 0.4, 1.0))


static func shell(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array([p + Vector2(0, 8) * s])
	for i in 9:
		var a := PI + PI * i / 8.0
		pts.append(p + Vector2(cos(a) * 14, sin(a) * 14) * s)
	ci.draw_colored_polygon(pts, col)
	for i in 4:
		ci.draw_line(p + Vector2(0, 6) * s, p + Vector2(-10 + i * 7, -9) * s, col.darkened(0.25), 1.5, true)


static func starfish(ci: CanvasItem, p: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0
		var r := 18.0 * s if i % 2 == 0 else 7.0 * s
		pts.append(p + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, Color("ff8f6b"))
	ci.draw_circle(p, 3.0 * s, Color("ffd2b8"))


static func sandcastle(ci: CanvasItem, p: Vector2, s: float) -> void:
	var sand := Color("e6c27a")
	ci.draw_rect(Rect2(p + Vector2(-34, -30) * s, Vector2(68, 30) * s), sand)
	for i in 3:
		ci.draw_rect(Rect2(p + Vector2(-34 + i * 26, -52) * s, Vector2(16, 22) * s), sand)
	ci.draw_line(p + Vector2(0, -52) * s, p + Vector2(0, -78) * s, Color("8d6e4a"), 2.0)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -78) * s, p + Vector2(18, -72) * s, p + Vector2(0, -66) * s]), Color("ff6b6b"))


static func pine(ci: CanvasItem, p: Vector2, s: float) -> void:
	Icons.ellipse(ci, p + Vector2(0, 4), 38 * s, 10 * s, Color(0, 0, 0, 0.1))
	ci.draw_rect(Rect2(p + Vector2(-7, -24) * s, Vector2(14, 26) * s), Color("7a4a26"))
	for i in 3:
		var y := -20.0 - i * 34.0
		var w := 52.0 - i * 12.0
		var tri := PackedVector2Array([p + Vector2(-w, y) * s, p + Vector2(0, y - 56) * s, p + Vector2(w, y) * s])
		ci.draw_colored_polygon(tri, Color("2f7d57"))
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.45, y - 30) * s, p + Vector2(0, y - 56) * s,
			p + Vector2(w * 0.45, y - 30) * s, p + Vector2(0, y - 22) * s]), Color.WHITE)


static func snow_pile(ci: CanvasItem, p: Vector2, s: float) -> void:
	Icons.ellipse(ci, p, 40 * s, 16 * s, Color("dbe9f4"))
	Icons.ellipse(ci, p + Vector2(-8, -8) * s, 26 * s, 12 * s, Color.WHITE)


static func snowy_rock(ci: CanvasItem, p: Vector2, s: float) -> void:
	Icons.ellipse(ci, p, 32 * s, 20 * s, Color("8f9aab"))
	Icons.ellipse(ci, p + Vector2(-4, -12) * s, 24 * s, 8 * s, Color.WHITE)


static func ice_flowers(ci: CanvasItem, p: Vector2, s: float) -> void:
	for off in [Vector2(-12, 0), Vector2(12, -6), Vector2(0, 10)]:
		Icons.snowflake(ci, p + off * s, 16 * s, Color("9fd3ff"))

class_name StationArt
extends RefCounted
## Zeichnet die Hilfsstationen. Ursprung = Bodenmitte. activity 0..1 steuert Animationen.

const OUTLINE := Color("4a3a2c")


static func draw_station(ci: CanvasItem, id: StringName, t: float, activity: float, level: int = 1,
		upgrade_path: StringName = &"", show_base: bool = true) -> void:
	if show_base:
		Icons.ellipse(ci, Vector2(0, 8), 58, 22, Color(0, 0, 0, 0.15))
		Icons.ellipse(ci, Vector2(0, 2), 54, 20, Color("c9cfae"))
		Icons.ellipse_outline(ci, Vector2(0, 2), 54, 20, Color("9aa07f"), 3.0)
	match id:
		&"keksstand": _keksstand(ci, t, activity)
		&"seifenblasen": _seifenblasen(ci, t, activity)
		&"musikbox": _musikbox(ci, t, activity)
		&"ventilator": _ventilator(ci, t, activity)
		&"ruhe": _ruhe(ci, t, activity)
		&"batterie": _booth(ci, t, activity, Color("3cc6a0"), Color("e8fff8"), &"battery")
		&"fluegelladen": _booth(ci, t, activity, Color("ff8fb1"), Color("fff0f5"), &"wing")
		&"kakao": _booth(ci, t, activity, Color("8d5f3a"), Color("fff1dc"), &"mug")
		&"disco": _disco(ci, t, activity)
		&"schneemann": _schneemann(ci, t, activity)
	if level >= 2:
		var badge := Vector2(44, -112)
		ci.draw_circle(badge, 21, Color.WHITE)
		ci.draw_arc(badge, 21, 0, TAU, 24, Color("e09a12"), 3.0, true)
		if upgrade_path == &"range":
			Icons.range_icon(ci, badge, 30, Color("3d9ad6"))
		else:
			Icons.sparkle(ci, badge, 34, Color("ff9f1c"))


static func _box(ci: CanvasItem, rect: Rect2, col: Color, radius: float = 8.0) -> void:
	Icons.rounded_rect(ci, rect.grow(3.0), radius + 3.0, OUTLINE)
	Icons.rounded_rect(ci, rect, radius, col)


static func _keksstand(ci: CanvasItem, t: float, activity: float) -> void:
	# Pfosten
	ci.draw_rect(Rect2(-42, -96, 8, 70), Color("a8693a"))
	ci.draw_rect(Rect2(34, -96, 8, 70), Color("a8693a"))
	# Theke
	_box(ci, Rect2(-46, -40, 92, 42), Color("c98b4f"), 6)
	ci.draw_rect(Rect2(-46, -40, 92, 10), Color("e5ae6f"))
	for i in 3:
		ci.draw_line(Vector2(-30 + i * 30, -24), Vector2(-30 + i * 30, -2), Color("a8693a"), 3.0)
	# Markise mit Streifen
	var top := -112.0
	var bottom := -88.0
	for i in 6:
		var x0 := -52.0 + i * 104.0 / 6.0
		var x1 := x0 + 104.0 / 6.0
		var col: Color = Color("ff6b6b") if i % 2 == 0 else Color("fff4e0")
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 4, top), Vector2(x1 + 4, top), Vector2(x1, bottom), Vector2(x0, bottom)]), col)
		ci.draw_circle(Vector2((x0 + x1) * 0.5, bottom), 104.0 / 12.0, col)
	ci.draw_line(Vector2(-48, top), Vector2(56, top), OUTLINE, 3.0, true)
	# Kekse auf der Theke
	for i in 3:
		Icons.cookie(ci, Vector2(-26 + i * 26, -46), 20)
	# Keks-Schild
	var bounce := -sin(activity * PI) * 8.0
	Icons.cookie(ci, Vector2(0, -132 + bounce), 36)


static func _seifenblasen(ci: CanvasItem, t: float, activity: float) -> void:
	# Beine
	ci.draw_line(Vector2(-22, -10), Vector2(-28, 2), Color("6c7a89"), 6.0, true)
	ci.draw_line(Vector2(22, -10), Vector2(28, 2), Color("6c7a89"), 6.0, true)
	# Tank
	var c := Vector2(0, -46)
	ci.draw_circle(c, 38, OUTLINE)
	ci.draw_circle(c, 35, Color("7cc8f0"))
	ci.draw_circle(c + Vector2(-2, 4), 20, Color(1, 1, 1, 0.55))
	for i in 3:
		var ph := fmod(t * 0.7 + i * 0.33, 1.0)
		ci.draw_circle(c + Vector2(-8 + i * 8, 14 - ph * 26), 3 + i, Color(1, 1, 1, 0.8))
	Icons.ellipse(ci, c + Vector2(-16, -18), 9, 5, Color(1, 1, 1, 0.6), -0.6)
	# Düse
	var nozzle_base := c + Vector2(22, -24)
	var nozzle_tip := c + Vector2(38, -50)
	Icons.thick_line(ci, nozzle_base, nozzle_tip, Color("6c7a89"), 11)
	ci.draw_arc(nozzle_tip, 9, 0, TAU, 16, Color("ff8fb1"), 5.0, true)
	# aufsteigende Blasen
	for i in 4:
		var ph := fmod(t * (0.45 + activity * 0.6) + i * 0.25, 1.0)
		var p := nozzle_tip + Vector2(sin(ph * 6.0 + i) * 10, -12 - ph * 60)
		var r := 5.0 + ph * 7.0
		var a := 1.0 - ph
		ci.draw_circle(p, r, Color(0.7, 0.9, 1.0, 0.35 * a))
		ci.draw_arc(p, r, 0, TAU, 16, Color(0.3, 0.6, 0.9, 0.8 * a), 2.0, true)


static func _musikbox(ci: CanvasItem, t: float, activity: float) -> void:
	_box(ci, Rect2(-40, -78, 80, 78), Color("b5764b"), 10)
	Icons.rounded_rect(ci, Rect2(-32, -70, 64, 62), 8, Color("d39a68"))
	var pulse := 1.0 + activity * 0.08 * sin(t * 14.0)
	var sc := Vector2(0, -40)
	ci.draw_circle(sc, 24 * pulse, Color("4a3b5c"))
	ci.draw_arc(sc, 24 * pulse, 0, TAU, 24, Color("f3c9ff"), 4.0, true)
	ci.draw_circle(sc, 9 * pulse, Color("8a6fa8"))
	ci.draw_circle(sc + Vector2(-3, -3), 3, Color(1, 1, 1, 0.6))
	# Kurbel
	var crank := Vector2(44, -54)
	var ang := t * (1.0 + activity * 5.0)
	ci.draw_line(crank, crank + Vector2(cos(ang), sin(ang)) * 14, Color("6b4a2f"), 5.0, true)
	ci.draw_circle(crank, 5, Color("6b4a2f"))
	# Note oben
	Icons.note(ci, Vector2(0, -104 - sin(t * 3.0) * 4), 36, Color("e85aa8"))


static func _ventilator(ci: CanvasItem, t: float, activity: float) -> void:
	Icons.ellipse(ci, Vector2(0, -4), 26, 10, Color("6c7a89"))
	ci.draw_rect(Rect2(-5, -76, 10, 72), Color("6c7a89"))
	var c := Vector2(0, -92)
	ci.draw_circle(c, 38, Color(0.85, 0.97, 0.95, 0.65))
	var rot := t * (2.0 + activity * 14.0)
	for i in 4:
		var a := rot + i * PI * 0.5
		Icons.ellipse(ci, c + Vector2(cos(a), sin(a)) * 18, 18, 9, Color("8fd3c7"), a)
	ci.draw_circle(c, 9, Color("ff8f6b"))
	ci.draw_arc(c, 38, 0, TAU, 32, Color("5c6f7a"), 4.0, true)
	for i in 4:
		var a := i * PI * 0.25
		ci.draw_line(c + Vector2(cos(a), sin(a)) * 38, c - Vector2(cos(a), sin(a)) * 38, Color(0.36, 0.43, 0.48, 0.35), 1.5, true)
	if activity > 0.05:
		for i in 3:
			var ph := fmod(t * 2.0 + i * 0.33, 1.0)
			var y := c.y - 20 + i * 20
			ci.draw_arc(Vector2(44 + ph * 30, y), 10, -0.8, 0.8, 8, Color(1, 1, 1, activity * (1.0 - ph)), 3.0, true)


static func _ruhe(ci: CanvasItem, t: float, activity: float) -> void:
	ci.draw_rect(Rect2(-50, -84, 9, 84), Color("a8693a"))
	ci.draw_rect(Rect2(41, -84, 9, 84), Color("a8693a"))
	var sway := sin(t * 1.5) * 3.0
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		var x := lerpf(-42.0, 42.0, k)
		var dip := sin(k * PI) * 26.0
		top.append(Vector2(x + sway * sin(k * PI), -66 + dip))
		bot.append(Vector2(x + sway * sin(k * PI), -66 + dip + 10 + sin(k * PI) * 6))
	var band := top.duplicate()
	for i in range(bot.size() - 1, -1, -1):
		band.append(bot[i])
	ci.draw_colored_polygon(band, Color("b59cf0"))
	ci.draw_polyline(top, Color("7d62c4"), 3.0, true)
	ci.draw_polyline(bot, Color("7d62c4"), 3.0, true)
	Icons.ellipse(ci, Vector2(-26 + sway * 0.5, -52), 14, 8, Color.WHITE, -0.3)
	# Seile
	ci.draw_line(Vector2(-42, -80), top[0], Color("8d6e4a"), 2.0)
	ci.draw_line(Vector2(42, -80), top[top.size() - 1], Color("8d6e4a"), 2.0)
	# Mond-Schild
	Icons.moon(ci, Vector2(0, -110 + sin(t * 1.2) * 4), 34, Color("ffd84d"))
	if activity > 0.05:
		Icons.zzz(ci, Vector2(30, -128 - fmod(t * 20.0, 20.0)), 16, Color(0.48, 0.38, 0.75, activity))



## Verkaufsstand mit gestreifter Markise und Schild (Batterie-, Flügel-, Kakaostand).
static func _booth(ci: CanvasItem, t: float, activity: float, stripe_a: Color, stripe_b: Color, sign_icon: StringName) -> void:
	ci.draw_rect(Rect2(-42, -96, 8, 70), Color("a8693a"))
	ci.draw_rect(Rect2(34, -96, 8, 70), Color("a8693a"))
	_box(ci, Rect2(-46, -40, 92, 42), Color("d9c3a0"), 6)
	ci.draw_rect(Rect2(-46, -40, 92, 10), Color("efe0c4"))
	var top := -112.0
	var bottom := -88.0
	for i in 6:
		var x0 := -52.0 + i * 104.0 / 6.0
		var x1 := x0 + 104.0 / 6.0
		var col: Color = stripe_a if i % 2 == 0 else stripe_b
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 4, top), Vector2(x1 + 4, top), Vector2(x1, bottom), Vector2(x0, bottom)]), col)
		ci.draw_circle(Vector2((x0 + x1) * 0.5, bottom), 104.0 / 12.0, col)
	ci.draw_line(Vector2(-48, top), Vector2(56, top), OUTLINE, 3.0, true)
	var bounce := -sin(activity * PI) * 8.0
	match sign_icon:
		&"battery":
			for i in 3:
				Icons.battery(ci, Vector2(-26 + i * 26, -50), 22, 1.0)
			Icons.battery(ci, Vector2(0, -136 + bounce), 46, 0.5 + 0.5 * sin(t * 3.0))
		&"wing":
			for i in 2:
				Icons.feather(ci, Vector2(-18 + i * 36, -50), 26, 0.4 * i)
			Icons.wing(ci, Vector2(0, -134 + bounce), 46)
		&"mug":
			for i in 3:
				Icons.mug(ci, Vector2(-26 + i * 26, -52), 20, t + i)
			Icons.mug(ci, Vector2(0, -136 + bounce), 40, t)


static func _disco(ci: CanvasItem, t: float, activity: float) -> void:
	# bunte Tanzfläche
	for i in 3:
		for j in 2:
			var col := Color.from_hsv(fmod((i + j * 3) / 6.0 + t * (0.1 + activity * 0.5), 1.0), 0.55, 1.0)
			var p := Vector2(-45 + i * 30, -18 + j * 14)
			ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(30, 0), p + Vector2(30, 14), p + Vector2(0, 14)]), col)
	ci.draw_rect(Rect2(-45, -18, 90, 28), OUTLINE, false, 3.0)
	# Mast und Kugel
	ci.draw_rect(Rect2(-4, -100, 8, 82), Color("6c7a89"))
	ci.draw_line(Vector2(0, -100), Vector2(0, -108), Color("6c7a89"), 3.0)
	Icons.discoball(ci, Vector2(0, -128), 52, t * (1.0 + activity * 3.0))
	# Lichtstrahlen beim Tanz-Impuls
	if activity > 0.05:
		for i in 6:
			var a := t * 2.0 + i * TAU / 6.0
			var col := Color.from_hsv(i / 6.0, 0.6, 1.0, 0.45 * activity)
			ci.draw_line(Vector2(0, -128), Vector2(0, -128) + Vector2(cos(a), sin(a) * 0.6) * 80, col, 6.0, true)


static func _schneemann(ci: CanvasItem, t: float, activity: float) -> void:
	var sway := sin(t * 2.0) * 2.0
	ci.draw_circle(Vector2(0, -26), 30, Color("f4f9ff"))
	ci.draw_arc(Vector2(0, -26), 30, 0, TAU, 28, Color("a9c4dd"), 3.0, true)
	ci.draw_circle(Vector2(sway * 0.5, -72), 23, Color("f4f9ff"))
	ci.draw_arc(Vector2(sway * 0.5, -72), 23, 0, TAU, 24, Color("a9c4dd"), 3.0, true)
	var h := Vector2(sway, -108)
	ci.draw_circle(h, 18, Color("f4f9ff"))
	ci.draw_arc(h, 18, 0, TAU, 20, Color("a9c4dd"), 3.0, true)
	ci.draw_circle(h + Vector2(-6, -3), 2.5, Color("2f2f3a"))
	ci.draw_circle(h + Vector2(6, -3), 2.5, Color("2f2f3a"))
	ci.draw_colored_polygon(PackedVector2Array([h + Vector2(0, 2), h + Vector2(16, 5), h + Vector2(0, 7)]), Color("ff8f3c"))
	ci.draw_arc(h + Vector2(0, 6), 7, 0.4, PI - 0.4, 8, Color("2f2f3a"), 2.0, true)
	# Mütze und Schal
	ci.draw_rect(Rect2(h + Vector2(-14, -22), Vector2(28, 8)), Color("2f3b5c"))
	ci.draw_rect(Rect2(h + Vector2(-9, -38), Vector2(18, 17)), Color("2f3b5c"))
	Icons.ellipse(ci, Vector2(sway * 0.7, -90), 22, 6, Color("e84a5f"))
	# winkende Ast-Arme
	var wave := sin(t * (2.0 + activity * 6.0)) * 0.4
	ci.draw_line(Vector2(-20, -76), Vector2(-20, -76) + Vector2(-cos(0.5 + wave), -sin(0.5 + wave)) * 30, Color("8d5f3a"), 3.5, true)
	ci.draw_line(Vector2(20, -76), Vector2(48, -88), Color("8d5f3a"), 3.5, true)
	for i in 3:
		ci.draw_circle(Vector2(0, -40 + i * 12), 3, Color("2f2f3a"))
	if activity > 0.05:
		Icons.heart(ci, Vector2(34, -130 - fmod(t * 20.0, 20.0)), 18, Color(1.0, 0.35, 0.53, activity))

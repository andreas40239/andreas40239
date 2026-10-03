class_name MonsterArt
extends RefCounted
## Zeichnet die niedlichen Monster prozedural (runde Formen, große Augen, keine Zähne).
## Ursprung = Bodenpunkt zwischen den Füßen. mood: 0 = wild ... 1 = Freund.


static func draw_monster(ci: CanvasItem, kind: StringName, base: Color, radius: float, mood: float,
		t: float, facing: float = 1.0, walking: bool = true) -> void:
	var R := radius
	var happy := clampf(mood, 0.0, 1.0)
	var body_col := base.lerp(base.lightened(0.3), happy)
	var dark := base.darkened(0.55)
	var speed: float = 10.0 if kind != &"flitzi" else 15.0
	if kind == &"schlummi":
		speed = 7.0
	var step: float = sin(t * speed) if walking else sin(t * 2.0) * 0.3
	var bob := absf(step) * R * 0.08
	var c := Vector2(0, -R * 1.0 - bob)

	# Schatten
	Icons.ellipse(ci, Vector2(0, 2), R * 0.85, R * 0.22, Color(0, 0, 0, 0.16))
	# Füße
	var foot_col := dark.lightened(0.2)
	Icons.ellipse(ci, Vector2(-R * 0.42, -R * 0.1 - maxf(0.0, step) * R * 0.14), R * 0.26, R * 0.16, foot_col)
	Icons.ellipse(ci, Vector2(R * 0.42, -R * 0.1 - maxf(0.0, -step) * R * 0.14), R * 0.26, R * 0.16, foot_col)

	# Merkmale hinter dem Körper
	match kind:
		&"knurri":
			for sx in [-1.0, 1.0]:
				var base_p: Vector2 = c + Vector2(sx * R * 0.42, -R * 0.72)
				var horn := PackedVector2Array([base_p + Vector2(-R * 0.16, 0), base_p + Vector2(sx * R * 0.12, -R * 0.42),
					base_p + Vector2(R * 0.16, 0)])
				ci.draw_colored_polygon(horn, Color("fff1c7"))
				ci.draw_polyline(horn, dark, R * 0.05, true)
		&"flitzi":
			for i in 5:
				var a := -PI * 0.5 + (i - 2) * 0.38
				var d := Vector2(cos(a), sin(a))
				var n := Vector2(-d.y, d.x)
				var tip := c + d * R * (1.45 + 0.08 * sin(t * 20.0 + i))
				ci.draw_colored_polygon(PackedVector2Array([c + d * R * 0.8 + n * R * 0.2, tip, c + d * R * 0.8 - n * R * 0.2]),
					base.darkened(0.15))
			if happy < 0.5:
				for i in 3:
					var y := c.y - R * 0.3 + i * R * 0.3
					var x0 := -facing * R * (1.25 + 0.1 * i)
					ci.draw_line(Vector2(x0, y), Vector2(x0 - facing * R * 0.5, y), Color(1, 1, 1, 0.7 * (1.0 - happy * 2.0)), R * 0.07, true)

	# Arme
	var arm_col := body_col.darkened(0.08)
	var wave: float = sin(t * 9.0) * 0.6 if happy >= 1.0 else 0.0
	Icons.ellipse(ci, c + Vector2(-R * 0.95, R * 0.2), R * 0.2, R * 0.32, arm_col, 0.4)
	if happy >= 1.0:
		Icons.ellipse(ci, c + Vector2(R * 0.98, -R * 0.35), R * 0.2, R * 0.34, arm_col, -0.6 + wave)
	else:
		Icons.ellipse(ci, c + Vector2(R * 0.95, R * 0.2), R * 0.2, R * 0.32, arm_col, -0.4)

	# Fell-Körper mit Kontur
	var fur: float = 0.05 if kind != &"matschi" else 0.07
	var outline_pts := _blob(c, R * 1.07, fur, t, 1.0)
	ci.draw_colored_polygon(outline_pts, dark)
	ci.draw_colored_polygon(_blob(c, R, fur, t, 1.0), body_col)
	# Bauch
	Icons.ellipse(ci, c + Vector2(facing * R * 0.05, R * 0.36), R * 0.56, R * 0.44, body_col.lightened(0.28))
	# Glanz
	Icons.ellipse(ci, c + Vector2(-R * 0.45, -R * 0.55), R * 0.2, R * 0.12, Color(1, 1, 1, 0.35), -0.6)

	# Merkmale auf dem Körper
	match kind:
		&"matschi":
			var mud := Color("5e4127")
			mud.a = clampf(1.0 - happy * 1.2, 0.0, 1.0)
			if mud.a > 0.01:
				ci.draw_circle(c + Vector2(R * 0.45, R * 0.35), R * 0.17, mud)
				ci.draw_circle(c + Vector2(-R * 0.5, R * 0.05), R * 0.12, mud)
				ci.draw_circle(c + Vector2(R * 0.1, -R * 0.62), R * 0.1, mud)
				ci.draw_circle(c + Vector2(-R * 0.15, R * 0.6), R * 0.13, mud)
			if happy < 0.5:
				var a := 1.0 - happy * 2.0
				for i in 3:
					var x := (i - 1) * R * 0.45
					var pts := PackedVector2Array()
					for k in 8:
						var yy := c.y - R * 1.2 - k * R * 0.09
						pts.append(Vector2(x + sin(k * 1.2 + t * 4.0 + i) * R * 0.08, yy))
					ci.draw_polyline(pts, Color(0.55, 0.65, 0.3, 0.75 * a), R * 0.06, true)
		&"troepfli":
			var top := c + Vector2(0, -R * 0.95)
			var drop := PackedVector2Array([top + Vector2(0, -R * 0.55)])
			for i in 13:
				var a := PI * i / 12.0
				drop.append(top + Vector2(cos(a) * R * 0.22, -sin(a) * R * 0.22 * -1.0 - R * 0.02))
			ci.draw_colored_polygon(drop, base.lightened(0.45))
			ci.draw_polyline(drop, dark, R * 0.04, true)

	# Gesicht
	var fx := facing * R * 0.1
	var eye_y := c.y - R * 0.12
	var er := R * 0.24
	if kind == &"flitzi":
		er = R * 0.27
	for sx in [-1.0, 1.0]:
		var e := Vector2(sx * R * 0.34 + fx, eye_y)
		ci.draw_circle(e, er, Color.WHITE)
		ci.draw_arc(e, er, 0, TAU, 24, dark, R * 0.05, true)
		var jitter := Vector2.ZERO
		if kind == &"flitzi" and happy < 0.6:
			jitter = Vector2(sin(t * 31.0), cos(t * 27.0)) * er * 0.12
		var pr: float = er * (0.5 if kind != &"flitzi" or happy > 0.6 else 0.36)
		var pupil: Vector2 = e + Vector2(facing * er * 0.25, er * 0.12) + jitter
		ci.draw_circle(pupil, pr, Color("232338"))
		ci.draw_circle(pupil + Vector2(-pr * 0.35, -pr * 0.4), pr * 0.36, Color.WHITE)
		# Augenlider (müde) bzw. Augenbrauen (mürrisch / traurig)
		if kind == &"schlummi" and happy < 0.75:
			var cover := 0.62 * (1.0 - happy / 0.75)
			_eyelid(ci, e, er * 1.04, cover, body_col.darkened(0.1), dark)
		elif happy < 0.35:
			var outer: Vector2 = e + Vector2(sx * er * 0.95, -er * 1.3)
			var inner: Vector2 = e + Vector2(-sx * er * 0.7, -er * 0.95)
			if kind == &"troepfli":
				outer = e + Vector2(sx * er * 0.95, -er * 0.95)
				inner = e + Vector2(-sx * er * 0.7, -er * 1.45)
			Icons.thick_line(ci, outer, inner, dark, R * 0.09)
		if kind == &"troepfli" and happy < 0.4 and sx > 0:
			var fall := fmod(t * 0.8, 1.0)
			var tear := e + Vector2(er * 0.3, er * 1.1 + fall * R * 0.5)
			ci.draw_circle(tear, R * 0.08, Color(0.6, 0.85, 1.0, 1.0 - fall))

	# Wangen
	if happy > 0.55:
		var blush := Color(1.0, 0.55, 0.65, clampf((happy - 0.55) * 1.6, 0.0, 0.7))
		Icons.ellipse(ci, Vector2(-R * 0.62 + fx, eye_y + R * 0.34), R * 0.14, R * 0.09, blush)
		Icons.ellipse(ci, Vector2(R * 0.62 + fx, eye_y + R * 0.34), R * 0.14, R * 0.09, blush)

	# Mund
	var m := Vector2(fx, c.y + R * 0.3)
	var mw := R * 0.08
	if happy >= 1.0:
		var mouth := PackedVector2Array()
		for i in 13:
			var a := PI * i / 12.0
			mouth.append(m + Vector2(cos(a) * R * 0.3, sin(a) * R * 0.3 - R * 0.06))
		ci.draw_colored_polygon(mouth, Color("8c2b3c"))
		Icons.ellipse(ci, m + Vector2(0, R * 0.12), R * 0.14, R * 0.07, Color("ff8fa3"))
	elif happy >= 0.7:
		ci.draw_arc(m + Vector2(0, -R * 0.16), R * 0.24, PI * 0.2, PI * 0.8, 12, dark, mw, true)
	elif happy >= 0.35:
		var pts := PackedVector2Array()
		for i in 9:
			var x := -R * 0.2 + i * R * 0.05
			pts.append(m + Vector2(x, sin(i * 1.2) * R * 0.03))
		ci.draw_polyline(pts, dark, mw, true)
	else:
		match kind:
			&"schlummi":
				var yawn := 0.5 + 0.5 * sin(t * 1.8)
				Icons.ellipse(ci, m + Vector2(0, R * 0.02), R * 0.12, R * (0.08 + 0.1 * yawn), Color("5a2a4a"))
			&"flitzi":
				Icons.ellipse(ci, m + Vector2(0, R * 0.02), R * 0.13, R * 0.13, Color("8c2b3c"))
			_:
				ci.draw_arc(m + Vector2(0, R * 0.2), R * 0.24, PI * 1.22, PI * 1.78, 12, dark, mw, true)

	# Mütze von Schlummi
	if kind == &"schlummi":
		var hc := c + Vector2(R * 0.05, -R * 0.82)
		var tip := hc + Vector2(R * 0.85, -R * 0.35 + sin(t * 2.0) * R * 0.05)
		var cap := PackedVector2Array([hc + Vector2(-R * 0.55, R * 0.12), tip, hc + Vector2(R * 0.55, R * 0.02)])
		ci.draw_colored_polygon(cap, Color("4b5bd6"))
		ci.draw_polyline(cap, dark, R * 0.04, true)
		Icons.ellipse(ci, hc + Vector2(0, R * 0.08), R * 0.6, R * 0.13, Color.WHITE, -0.08)
		ci.draw_circle(tip, R * 0.14, Color.WHITE)


static func _blob(c: Vector2, r: float, fur: float, t: float, squash: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 40
	for i in n:
		var a := TAU * i / n
		var rr := r * (1.0 + fur * sin(a * 11.0 + t * 1.5))
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * 0.96 * squash))
	return pts


static func _eyelid(ci: CanvasItem, e: Vector2, r: float, cover: float, col: Color, line: Color) -> void:
	# Deckt den oberen Teil des Auges bis zur Linie y = e.y - r + 2r*cover ab.
	var dy := -r + 2.0 * r * cover
	var a := asin(clampf(dy / r, -1.0, 1.0))
	var pts := PackedVector2Array()
	var steps := 12
	for i in steps + 1:
		var ang := lerpf(PI - a, TAU + a, float(i) / steps)
		pts.append(e + Vector2(cos(ang), sin(ang)) * r)
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, col)
		ci.draw_line(pts[0], pts[pts.size() - 1], line, r * 0.18, true)

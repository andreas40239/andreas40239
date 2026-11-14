class_name TrackModels
extends RefCounted
## 3D-Modelle für alle baubaren Teile: Gleis, Weiche, Brücke, Bahnübergang, Bahnhof.

const C_BALLAST := Color("c4bdb0")
const C_SLEEPER := Color("5f4532")
const C_RAIL := Color("6a4a3c")
const C_RAIL_TOP := Color("c9ced6")
const C_TRUSS := Color("9a4435")
const C_STONE := Color("a9a295")
const C_PLATFORM := Color("d9d2c2")
const C_ROUTE := Color("ffe14a")

static var _lamp_on: StandardMaterial3D
static var _lamp_off: StandardMaterial3D
static var font: Font


static func _basis_along(tg: Vector3) -> Basis:
	var right := tg.cross(Vector3.UP).normalized()
	return Basis(right, Vector3.UP, -tg)


static func _beam(mk: MeshKit, p0: Vector3, p1: Vector3, thick: float, col: Color, width: float = -1.0) -> void:
	var d := p1 - p0
	var ln := d.length()
	if ln < 1e-4:
		return
	var z := d / ln
	var ref := Vector3.RIGHT if absf(z.dot(Vector3.RIGHT)) < 0.9 else Vector3.UP
	var y := z.cross(ref).normalized()
	var x := y.cross(z).normalized()
	mk.box(Vector3(thick if width < 0.0 else width, thick, ln), (p0 + p1) * 0.5, col, Basis(x, y, z))


static func _sleepers(mk: MeshKit, a: int, b: int, y: float = 0.195, length: float = 1.5, s0: float = 0.0, s1: float = -1.0) -> void:
	mk.use("main")
	var ln := G.link_len(a, b)
	var n := int(round(ln / 0.5))
	var sp := ln / n
	for i in n:
		var s := (i + 0.5) * sp
		if s < s0 or (s1 >= 0.0 and s > s1):
			continue
		var pt := G.link_point(a, b, s)
		var shade := 0.06 * float((i * 7 + a * 3 + b) % 3) - 0.06
		mk.box(Vector3(length, 0.09, 0.26), (pt[0] as Vector3) + Vector3(0, y, 0), C_SLEEPER.lightened(shade) if shade > 0 else C_SLEEPER.darkened(-shade), _basis_along(pt[1]))


static func _rails(mk: MeshKit, a: int, b: int, y: float = 0.0) -> void:
	var path := G.link_path(a, b, 14)
	for off in [-G.GAUGE, G.GAUGE]:
		mk.use("main")
		mk.extrude(PackedVector2Array([Vector2(off - 0.045, y + 0.2), Vector2(off - 0.03, y + 0.262),
			Vector2(off + 0.03, y + 0.262), Vector2(off + 0.045, y + 0.2)]), path, C_RAIL)
		mk.use("metal")
		mk.extrude(PackedVector2Array([Vector2(off - 0.04, y + 0.26), Vector2(off - 0.04, y + G.RAIL_TOP),
			Vector2(off + 0.04, y + G.RAIL_TOP), Vector2(off + 0.04, y + 0.26)]), path, C_RAIL_TOP)


static func _ballast(mk: MeshKit, a: int, b: int) -> void:
	mk.use("ballast")
	mk.extrude(PackedVector2Array([Vector2(-1.14, 0.0), Vector2(-0.9, 0.15), Vector2(0.9, 0.15), Vector2(1.14, 0.0)]),
		G.link_path(a, b, 14), C_BALLAST)


static func _full_track(mk: MeshKit, a: int, b: int) -> void:
	_ballast(mk, a, b)
	_sleepers(mk, a, b)
	_rails(mk, a, b)


# ----------------------------------------------------------------- Gleis / Weiche

static func track(links: Array) -> Node3D:
	var mk := MeshKit.new()
	for l in links:
		_full_track(mk, l[0], l[1])
	var root := Node3D.new()
	root.add_child(mk.instance(Mats.all()))
	return root


static func _route_ribbon(a: int, b: int) -> MeshInstance3D:
	var mk := MeshKit.new()
	mk.use("emit")
	var ln := G.link_len(a, b)
	var segs := 10
	var path := []
	for i in segs + 1:
		path.append(G.link_point(a, b, lerpf(0.35, ln - 0.75, float(i) / segs)))
	mk.extrude(PackedVector2Array([Vector2(-0.13, 0.25), Vector2(-0.13, 0.27), Vector2(0.13, 0.27), Vector2(0.13, 0.25)]), path, C_ROUTE)
	# Pfeilspitze
	var tip := G.link_point(a, b, ln - 0.3)
	var base := G.link_point(a, b, ln - 0.8)
	var right := (base[1] as Vector3).cross(Vector3.UP).normalized()
	var up := Vector3(0, 0.27, 0)
	mk.tri((tip[0] as Vector3) + up, (base[0] as Vector3) + right * 0.34 + up, (base[0] as Vector3) - right * 0.34 + up, C_ROUTE, Vector3.UP)
	var mi := mk.instance(Mats.all(), false)
	return mi


## Weiche: links[0] und links[1] teilen sich die Kante `stem`.
static func switch_piece(links: Array, state: int) -> Node3D:
	var mk := MeshKit.new()
	var stem := switch_stem(links)
	for l in links:
		_ballast(mk, l[0], l[1])
		_rails(mk, l[0], l[1])
	# Schwellen: durchgehend auf der ersten Verbindung, auf der zweiten erst nach dem Auseinanderlaufen
	var l0: Array = links[0]
	var l1: Array = links[1]
	_sleepers(mk, l0[0], l0[1], 0.195, 1.9)
	var ln1 := G.link_len(l1[0], l1[1])
	if l1[0] == stem:
		_sleepers(mk, l1[0], l1[1], 0.195, 1.5, ln1 * 0.55, -1.0)
	else:
		_sleepers(mk, l1[0], l1[1], 0.195, 1.5, 0.0, ln1 * 0.45)
	# Stellhebel mit Signalscheibe
	var sp := G.dir_vec(stem) * 1.3
	var side := G.dir_vec(stem).cross(Vector3.UP) * 1.25
	mk.use("main")
	mk.box(Vector3(0.36, 0.1, 0.36), sp + side + Vector3(0, 0.2, 0), Color("3a3d42"))
	mk.box(Vector3(0.07, 0.6, 0.07), sp + side + Vector3(0, 0.5, 0), Color("2a2c30"))
	mk.use("gloss")
	mk.cyl(0.17, 0.17, 0.05, sp + side + Vector3(0, 0.82, 0), Color("f6f3ec"), 10, G.dir_vec(stem))
	mk.cyl(0.1, 0.1, 0.06, sp + side + Vector3(0, 0.82, 0), Color("d8322a"), 10, G.dir_vec(stem))

	var root := Node3D.new()
	root.add_child(mk.instance(Mats.all()))
	var inds: Array = []
	for l in links:
		# Pfeil immer vom Stamm weg zeichnen
		var ind := _route_ribbon(l[0], l[1]) if l[0] == stem else _route_ribbon(l[1], l[0])
		root.add_child(ind)
		inds.append(ind)
	root.set_meta("ind", inds)
	set_switch_state(root, state)
	return root


static func switch_stem(links: Array) -> int:
	for e in links[0]:
		if e in links[1]:
			return e
	return links[0][0]


static func set_switch_state(node: Node3D, state: int) -> void:
	var inds: Array = node.get_meta("ind", [])
	for i in inds.size():
		(inds[i] as Node3D).visible = (i == state)


# ----------------------------------------------------------------- Brücke

static func bridge(a: int) -> Node3D:
	var mk := MeshKit.new()
	mk.use("main")
	# Widerlager und Mittelpfeiler
	for sz in [-1.0, 1.0]:
		mk.box(Vector3(2.7, 1.25, 0.42), Vector3(0, -0.5, sz * 1.8), C_STONE, Basis.IDENTITY, 0.18)
		mk.box(Vector3(2.9, 0.1, 0.5), Vector3(0, 0.1, sz * 1.78), C_STONE.lightened(0.1))
	mk.box(Vector3(1.9, 1.15, 0.5), Vector3(0, -0.62, 0), C_STONE.darkened(0.06), Basis.IDENTITY, 0.2)
	mk.box(Vector3(2.1, 0.1, 0.62), Vector3(0, -0.06, 0), C_STONE.lightened(0.06))
	# Fahrbahnträger
	mk.use("gloss")
	mk.box(Vector3(2.06, 0.12, 4.0), Vector3(0, 0.09, 0), Color("4a4f55"))
	for sx in [-1.0, 1.0]:
		mk.box(Vector3(0.14, 0.3, 4.0), Vector3(sx * 1.03, 0.07, 0), C_TRUSS)
	for i in 5:
		mk.box(Vector3(2.0, 0.16, 0.1), Vector3(0, 0.0, -1.6 + i * 0.8), C_TRUSS.darkened(0.15))
	# Fachwerkträger (Warren)
	var yb := 0.2
	var yt := 1.42
	var bz := [-2.0, -0.667, 0.667, 2.0]
	var tz := [-1.333, 0.0, 1.333]
	for sx in [-1.0, 1.0]:
		var x: float = sx * 1.03
		_beam(mk, Vector3(x, yt, tz[0]), Vector3(x, yt, tz[2]), 0.13, C_TRUSS)
		for i in 3:
			_beam(mk, Vector3(x, yb, bz[i]), Vector3(x, yt, tz[i]), 0.1, C_TRUSS)
			_beam(mk, Vector3(x, yt, tz[i]), Vector3(x, yb, bz[i + 1]), 0.1, C_TRUSS)
		for z in tz:
			mk.box(Vector3(0.18, 0.18, 0.18), Vector3(x, yt, z), C_TRUSS.darkened(0.12))
	# Schwellen und Schienen (ohne Schotter)
	var l := [G.N, G.S]
	_sleepers(mk, l[0], l[1], 0.19, 1.6)
	_rails(mk, l[0], l[1])
	var root := Node3D.new()
	var mi := mk.instance(Mats.all())
	if a == G.E or a == G.W:
		mi.rotation.y = PI * 0.5
	root.add_child(mi)
	return root


# ----------------------------------------------------------------- Bahnübergang

static func _lamp_mats() -> void:
	if _lamp_on != null:
		return
	_lamp_on = StandardMaterial3D.new()
	_lamp_on.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_on.albedo_color = Color(1.0, 0.16, 0.1)
	_lamp_off = StandardMaterial3D.new()
	_lamp_off.albedo_color = Color(0.28, 0.05, 0.04)
	_lamp_off.roughness = 0.3


static func _barrier_unit() -> Node3D:
	var unit := Node3D.new()
	var mk := MeshKit.new()
	var gray := Color("c9ccd1")
	mk.use("main")
	mk.box(Vector3(0.42, 0.08, 0.42), Vector3(0, 0.07, 0), Color("8f8b84"))
	mk.box(Vector3(0.18, 0.95, 0.18), Vector3(0, 0.55, 0), gray, Basis.IDENTITY, 0.15)
	mk.box(Vector3(0.3, 0.34, 0.34), Vector3(0, 0.95, 0), Color("4a4f57"))
	# Signalmast mit Andreaskreuz (zeigt dem Verkehr entgegen: -x)
	var mz := 0.62
	mk.box(Vector3(0.3, 0.08, 0.3), Vector3(0, 0.07, mz), Color("8f8b84"))
	mk.cyl(0.05, 0.05, 2.25, Vector3(0, 0.05, mz), gray, 8)
	for sgn in [-1.0, 1.0]:
		var b := Basis(Vector3.RIGHT, deg_to_rad(sgn * 38.0))
		mk.box(Vector3(0.035, 0.15, 1.05), Vector3(-0.07, 1.95, mz), Color("f6f3ec"), b)
		for e in [-1.0, 1.0]:
			mk.box(Vector3(0.04, 0.152, 0.26), Vector3(-0.07, 1.95, mz) + b * Vector3(0, 0, e * 0.4), Color("d8322a"), b)
	# Lichtzeichen
	mk.box(Vector3(0.05, 0.56, 0.32), Vector3(-0.07, 1.25, mz), Color("1d2024"))
	mk.box(Vector3(0.06, 0.6, 0.36), Vector3(-0.06, 1.25, mz), Color("f6f3ec"))
	mk.box(Vector3(0.07, 0.56, 0.32), Vector3(-0.07, 1.25, mz), Color("1d2024"))
	mk.cyl(0.085, 0.085, 0.03, Vector3(-0.1, 1.11, mz), Color("7a6418"), 10, Vector3.LEFT)
	unit.add_child(mk.instance(Mats.all()))

	_lamp_mats()
	var lmk := MeshKit.new()
	lmk.cyl(0.095, 0.095, 0.035, Vector3(-0.1, 1.38, mz), Color.WHITE, 12, Vector3.LEFT)
	var lamp := lmk.instance({}, false)
	lamp.material_override = _lamp_off
	unit.add_child(lamp)

	# Schrankenbaum (zeigt in -z über die eigene Fahrspur)
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0.98, 0)
	var bmk := MeshKit.new()
	bmk.use("gloss")
	for i in 8:
		bmk.box(Vector3(0.07, 0.1, 0.25), Vector3(0.19, 0, -0.1 - i * 0.25 - 0.125), Color("d8322a") if i % 2 == 0 else Color("f6f3ec"))
	bmk.box(Vector3(0.07, 0.12, 0.5), Vector3(0.19, 0, 0.2), Color("f6f3ec"))
	bmk.box(Vector3(0.12, 0.26, 0.28), Vector3(0.19, 0, 0.55), Color("4a4f57"))
	bmk.cyl(0.07, 0.07, 0.3, Vector3(0.02, 0, 0), Color("4a4f57"), 8, Vector3.RIGHT)
	pivot.add_child(bmk.instance(Mats.all()))
	unit.add_child(pivot)
	unit.set_meta("pivot", pivot)
	unit.set_meta("lamp", lamp)
	return unit


## Bahnübergang; `a` ist die Gleisrichtung (die Straße verläuft quer dazu).
static func crossing(a: int) -> Node3D:
	var mk := MeshKit.new()
	_full_track(mk, G.N, G.S)
	# Rampen (Asphalt) und Belagplatten
	var yd := G.RAIL_TOP - 0.015
	var rw := 1.5
	mk.use("road")
	for sx in [-1.0, 1.0]:
		mk.quad(Vector3(sx * 1.16, yd, -rw), Vector3(sx * 1.16, yd, rw), Vector3(sx * 2.0, 0.035, rw), Vector3(sx * 2.0, 0.035, -rw), Color("5a5e64"), Vector3(sx * 0.3, 1, 0))
		for sz in [-1.0, 1.0]:
			mk.tri(Vector3(sx * 1.16, yd, sz * rw), Vector3(sx * 2.0, 0.035, sz * rw), Vector3(sx * 1.16, 0.0, sz * rw), Color("4a4d52"), Vector3(0, 0, sz))
	mk.use("main")
	var plate := Color("5b5650")
	mk.box(Vector3(0.7, 0.12, rw * 2.0), Vector3(0, yd - 0.06, 0), plate)
	for sx in [-1.0, 1.0]:
		mk.box(Vector3(0.66, 0.12, rw * 2.0), Vector3(sx * 0.83, yd - 0.06, 0), plate)
		for i in 5:
			mk.box(Vector3(0.66, 0.012, 0.03), Vector3(sx * 0.83, yd + 0.002, -1.2 + i * 0.6), plate.darkened(0.35))
		mk.box(Vector3(0.05, 0.3, rw * 2.0), Vector3(sx * 1.16, yd - 0.15, 0), plate.darkened(0.2))
	for i in 5:
		mk.box(Vector3(0.7, 0.012, 0.03), Vector3(0, yd + 0.002, -1.2 + i * 0.6), plate.darkened(0.35))
	# Haltelinien
	for sx in [-1.0, 1.0]:
		mk.box(Vector3(0.14, 0.012, 1.3), Vector3(sx * 2.25, 0.04, sx * -0.72), Color("f1f1ea"))

	var root := Node3D.new()
	var inner := Node3D.new()
	root.add_child(inner)
	inner.add_child(mk.instance(Mats.all()))
	var units: Array = []
	var u1 := _barrier_unit()
	u1.position = Vector3(-1.95, 0, 1.75)
	inner.add_child(u1)
	units.append(u1)
	var u2 := _barrier_unit()
	u2.position = Vector3(1.95, 0, -1.75)
	u2.rotation.y = PI
	inner.add_child(u2)
	units.append(u2)
	if a == G.E or a == G.W:
		inner.rotation.y = PI * 0.5
	root.set_meta("units", units)
	set_barrier(root, 0.0, false)
	return root


## k = 0 offen … 1 geschlossen; lamp = rotes Licht an.
static func set_barrier(node: Node3D, k: float, lamp: bool) -> void:
	_lamp_mats()
	for u in node.get_meta("units", []):
		var pivot: Node3D = (u as Node3D).get_meta("pivot")
		pivot.rotation.x = deg_to_rad(lerpf(82.0, 0.0, k))
		var l: MeshInstance3D = (u as Node3D).get_meta("lamp")
		l.material_override = _lamp_on if lamp else _lamp_off


# ----------------------------------------------------------------- Bahnhof

static func buffer_stop(mk: MeshKit, z: float, face: float) -> void:
	mk.use("main")
	var dark := Color("3a3d42")
	for sx in [-1.0, 1.0]:
		_beam(mk, Vector3(sx * G.GAUGE, 0.28, z - face * 0.55), Vector3(sx * G.GAUGE, 0.95, z), 0.1, dark)
		mk.box(Vector3(0.1, 0.7, 0.1), Vector3(sx * G.GAUGE, 0.62, z), dark)
	mk.use("gloss")
	mk.box(Vector3(1.5, 0.26, 0.14), Vector3(0, 0.9, z - face * 0.06), Color("d8322a"))
	for sx in [-1.0, 0.0, 1.0]:
		mk.box(Vector3(0.24, 0.265, 0.145), Vector3(sx * 0.5, 0.9, z - face * 0.06), Color("f6f3ec"))
	mk.use("emit")
	mk.cyl(0.07, 0.07, 0.03, Vector3(0, 1.16, z - face * 0.08), Color("ff3a2a"), 8, Vector3(0, 0, -face))
	mk.use("main")
	mk.box(Vector3(0.1, 0.22, 0.1), Vector3(0, 1.1, z), dark)


static func _lamp_post(mk: MeshKit, p: Vector3) -> void:
	mk.use("main")
	var c := Color("2f3a40")
	mk.cyl(0.07, 0.05, 0.15, p, c, 8)
	mk.cyl(0.035, 0.03, 1.75, p, c, 6)
	mk.box(Vector3(0.5, 0.04, 0.04), p + Vector3(-0.2, 1.75, 0), c)
	mk.box(Vector3(0.2, 0.06, 0.14), p + Vector3(-0.42, 1.71, 0), c)
	mk.use("emit")
	mk.box(Vector3(0.16, 0.03, 0.1), p + Vector3(-0.42, 1.67, 0), Color("fff2c0"))
	mk.use("main")


static func _bench(mk: MeshKit, p: Vector3) -> void:
	mk.use("main")
	var wood := Color("9a6b3f")
	mk.box(Vector3(0.3, 0.05, 0.9), p + Vector3(0, 0.26, 0), wood)
	mk.box(Vector3(0.05, 0.3, 0.9), p + Vector3(0.14, 0.42, 0), wood)
	for sz in [-1.0, 1.0]:
		mk.box(Vector3(0.28, 0.25, 0.05), p + Vector3(0, 0.125, sz * 0.38), Color("3a3d42"))


static func _sign(root: Node3D, text: String, pos: Vector3, size: float, col: Color, face_x: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 96
	l.pixel_size = size / 96.0
	l.modulate = col
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.position = pos
	l.rotation.y = -PI * 0.5 if face_x < 0.0 else PI * 0.5
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	root.add_child(l)


## Bahnhofsabschnitt. Lokal: Gleis entlang z, Bahnsteig auf der +x-Seite.
## idx/count: Position im Bahnhof; buffer: -1/0/+1 = Prellbock an -z / keiner / +z.
static func station(idx: int, count: int, is_start: bool, station_name: String, buffer: int) -> Node3D:
	var mk := MeshKit.new()
	_full_track(mk, G.N, G.S)
	var accent := Color("2f8f5b") if is_start else Color("d98a1f")
	# Bahnsteig
	mk.use("main")
	mk.box(Vector3(2.4, 0.4, 4.0), Vector3(2.15, 0.2, 0), C_PLATFORM.darkened(0.2), Basis.IDENTITY, 0.2)
	mk.box(Vector3(2.46, 0.06, 4.0), Vector3(2.14, 0.43, 0), C_PLATFORM)
	mk.box(Vector3(0.1, 0.012, 4.0), Vector3(1.1, 0.462, 0), Color("f6f3ec"))
	mk.box(Vector3(0.22, 0.012, 4.0), Vector3(1.32, 0.462, 0), Color("e8c53a"))
	for i in 4:
		mk.box(Vector3(2.2, 0.01, 0.025), Vector3(2.2, 0.462, -1.5 + i * 1.0), C_PLATFORM.darkened(0.1))

	var root := Node3D.new()
	var mid := count / 2
	if idx == mid:
		# Empfangsgebäude auf dem Nachbarfeld
		var wall := Color("f1e6cf") if is_start else Color("eedcc4")
		var roof := Color("a9483a") if is_start else Color("596b7b")
		var bx := 4.55
		var bw := 2.1      # Tiefe (x)
		var bl := 3.3      # Länge (z)
		var wh := 2.15
		mk.box(Vector3(bw + 0.5, 0.46, bl + 0.5), Vector3(bx - 0.05, 0.23, 0), C_PLATFORM.darkened(0.12))
		mk.push_at(Vector3(bx, 0.46, 0), 90)
		# lokal im Gebäude: Länge entlang x' (= Welt -z…), Tiefe entlang z'
		mk.box(Vector3(bl, wh, bw), Vector3(0, wh * 0.5, 0), wall, Basis.IDENTITY, 0.1)
		mk.box(Vector3(bl + 0.04, 0.3, bw + 0.04), Vector3(0, 0.15, 0), accent.darkened(0.1))
		Models._roof(mk, bl, bw, wh, 1.15, roof, wall, 0.3)
		for i in 3:
			if i == 1:
				continue
			Models._window(mk, Vector3(-1.05 + i * 1.05, 1.15, bw * 0.5), 0, 0.42, 0.62)
			Models._window(mk, Vector3(-1.05 + i * 1.05, 1.15, -bw * 0.5), 180, 0.42, 0.62)
		Models._window(mk, Vector3(0, 1.15, bw * 0.5), 0, 0.42, 0.62)
		Models._door(mk, Vector3(0, 0.0, -bw * 0.5), 180, accent.darkened(0.25), 0.6, 1.1)
		Models._window(mk, Vector3(bl * 0.5, 1.15, 0), 90, 0.4, 0.6)
		Models._window(mk, Vector3(-bl * 0.5, 1.15, 0), 270, 0.4, 0.6)
		Models._chimney(mk, Vector3(-0.9, wh + 0.55, 0.2), 0.95)
		mk.pop()
		# Vordach über dem Bahnsteig
		mk.use("main")
		mk.box(Vector3(2.3, 0.08, bl + 0.5), Vector3(2.5, 2.2, 0), roof.darkened(0.12), Basis(Vector3.BACK, deg_to_rad(-5.0)))
		mk.box(Vector3(0.06, 0.2, bl + 0.5), Vector3(1.36, 2.02, 0), accent)
		for sz in [-1.0, 1.0]:
			mk.box(Vector3(0.09, 1.72, 0.09), Vector3(1.55, 1.32, sz * 1.5), Color("3a4046"))
			_beam(mk, Vector3(1.55, 1.9, sz * 1.5), Vector3(2.0, 2.15, sz * 1.5), 0.06, Color("3a4046"))
		# Uhr
		mk.cyl(0.24, 0.24, 0.06, Vector3(1.38, 1.62, 0), Color("2f3a40"), 14, Vector3.LEFT)
		mk.cyl(0.2, 0.2, 0.07, Vector3(1.38, 1.62, 0), Color("f6f3ec"), 14, Vector3.LEFT)
		mk.box(Vector3(0.09, 0.15, 0.025), Vector3(1.33, 1.67, 0), Color("1d2024"))
		mk.box(Vector3(0.09, 0.025, 0.12), Vector3(1.33, 1.62, 0.05), Color("1d2024"))
		# Stationsschild
		mk.box(Vector3(0.05, 0.36, 2.3), Vector3(1.37, 2.38, 0), Color("22407a") if is_start else Color("22407a"))
		mk.box(Vector3(0.04, 0.42, 2.36), Vector3(1.38, 2.38, 0), Color("f6f3ec"))
		mk.box(Vector3(0.05, 0.36, 2.3), Vector3(1.365, 2.38, 0), Color("22407a"))
		_sign(root, station_name, Vector3(1.33, 2.38, 0), 0.27, Color("ffffff"), -1.0)
	else:
		var sz := -1.0 if idx < mid else 1.0
		_lamp_post(mk, Vector3(2.9, 0.46, sz * 0.9))
		_bench(mk, Vector3(2.75, 0.46, sz * -0.3))
		# Blumenkübel
		mk.cyl(0.2, 0.26, 0.28, Vector3(2.85, 0.46, sz * 1.65), Color("8f6a4a"), 8)
		mk.blob(Vector3(0.27, 0.2, 0.27), Vector3(2.85, 0.82, sz * 1.65), Color("5c9c48"), 0, 0.15, Models._rng(idx + 3))
		for i in 4:
			mk.blob(Vector3(0.07, 0.06, 0.07), Vector3(2.85 + 0.14 * cos(i * 1.7), 0.97, sz * 1.65 + 0.14 * sin(i * 1.7)),
				Color("ef6f7a") if is_start else Color("f4d03f"), 0)
		# Namensschild auf Pfosten
		for e in [-1.0, 1.0]:
			mk.box(Vector3(0.05, 1.3, 0.05), Vector3(3.2, 1.1, sz * 0.9 * 0.0 + e * 0.75 + sz * -1.0 * 0.0), Color("3a4046"))
		mk.box(Vector3(0.05, 0.4, 1.7), Vector3(3.2, 1.55, 0), Color("f6f3ec"))
		mk.box(Vector3(0.06, 0.32, 1.62), Vector3(3.19, 1.55, 0), Color("22407a"))
		_sign(root, station_name, Vector3(3.15, 1.55, 0), 0.22, Color("ffffff"), -1.0)
	if buffer != 0:
		buffer_stop(mk, buffer * 1.7, float(buffer))
	root.add_child(mk.instance(Mats.all()))
	root.move_child(root.get_child(root.get_child_count() - 1), 0)
	return root

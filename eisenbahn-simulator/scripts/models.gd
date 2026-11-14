class_name Models
extends RefCounted
## Prozedurale 3D-Modelle für Landschaft und Fahrzeuge. Alles wird zur Laufzeit
## aus Grundformen aufgebaut – es gibt keine externen Modell-Dateien.

const WALLS := ["f4ead5", "ecdcb8", "f7f3ea", "e9cfa6", "dbe5ea", "f1dccd", "e3e8d2", "f6e7b9"]
const ROOFS := ["b5483a", "9a3d33", "c2573f", "5f6d7b", "7c4a3a", "46525f", "a8553a"]
const SHUTTERS := ["3f7a55", "3d6a8f", "8f3b32", "6a5a3c", "40536b"]
const CAR_COLORS := ["d9463e", "f2c230", "3b7fc4", "f4f1ea", "3ba272", "ee7f2d", "8e5fb3", "2c3e50", "77c6d6"]

const C_STONE := Color("a7a094")
const C_TRUNK := Color("6e4f35")
const C_GLASS := Color("35526b")
const C_WHITE := Color("f6f3ec")
const C_DARK := Color("23272c")


static func _rng(seed_val: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val * 7919 + 13
	return r


static func _pick(rng: RandomNumberGenerator, arr: Array) -> Color:
	return Color(arr[rng.randi() % arr.size()])


# ======================================================================= Häuser

static func _window(mk: MeshKit, pos: Vector3, yaw: float, w: float, h: float, shutter: Color = Color(-1, 0, 0)) -> void:
	mk.push_at(pos, yaw)
	mk.use("main")
	mk.box(Vector3(w + 0.12, h + 0.12, 0.05), Vector3(0, 0, 0.012), C_WHITE)
	mk.box(Vector3(w + 0.2, 0.05, 0.12), Vector3(0, -h * 0.5 - 0.07, 0.05), C_WHITE.darkened(0.08))
	mk.box(Vector3(0.035, h, 0.075), Vector3(0, 0, 0.012), C_WHITE)
	mk.box(Vector3(w, 0.035, 0.075), Vector3(0, 0.03, 0.012), C_WHITE)
	if shutter.r >= 0.0:
		for sx in [-1.0, 1.0]:
			mk.box(Vector3(w * 0.42, h + 0.06, 0.04), Vector3(sx * (w * 0.5 + w * 0.21 + 0.07), 0, 0.02), shutter)
	mk.use("glass")
	mk.box(Vector3(w, h, 0.06), Vector3(0, 0, 0.012), C_GLASS)
	mk.use("main")
	mk.pop()


static func _door(mk: MeshKit, pos: Vector3, yaw: float, col: Color, w: float = 0.42, h: float = 0.88) -> void:
	mk.push_at(pos, yaw)
	mk.use("main")
	mk.box(Vector3(w + 0.12, h + 0.06, 0.05), Vector3(0, h * 0.5 + 0.03, 0.012), C_WHITE)
	mk.box(Vector3(w, h, 0.07), Vector3(0, h * 0.5, 0.012), col)
	mk.box(Vector3(w * 0.6, h * 0.3, 0.08), Vector3(0, h * 0.72, 0.012), col.darkened(0.25))
	mk.box(Vector3(0.05, 0.05, 0.05), Vector3(w * 0.32, h * 0.45, 0.06), Color("d4a84b"))
	mk.box(Vector3(w + 0.3, 0.1, 0.34), Vector3(0, 0.05, 0.17), C_STONE)
	mk.pop()


## Satteldach aus zwei Platten mit Überstand; First entlang x. Giebeldreiecke in Wandfarbe.
static func _roof(mk: MeshKit, w: float, d: float, wall_h: float, roof_h: float, col: Color, wall_col: Color, over: float = 0.22) -> void:
	mk.use("main")
	# Giebelfüllung (First entlang x => Prisma um 90° gedreht)
	mk.gable(d, w, roof_h, Vector3(0, wall_h, 0), wall_col, Basis(Vector3.UP, PI * 0.5), wall_col)
	var hs := d * 0.5
	var ln := sqrt(hs * hs + roof_h * roof_h)
	for sz in [-1.0, 1.0]:
		var dvec := Vector3(0, -roof_h, hs * sz) / ln
		var nrm := Vector3(0, hs, roof_h * sz) / ln
		var total := ln + over
		var c := Vector3(0, wall_h + roof_h, 0) + dvec * (total * 0.5) + nrm * 0.05
		var bx := Basis(Vector3.RIGHT, nrm, Vector3.RIGHT.cross(nrm).normalized())
		mk.box(Vector3(w + over * 2.0, 0.11, total), c, col, bx)
		# Traufkante etwas dunkler
		mk.box(Vector3(w + over * 2.0 + 0.02, 0.13, 0.09), Vector3(0, wall_h + roof_h, 0) + dvec * (total - 0.04) + nrm * 0.05, col.darkened(0.22), bx)
	mk.box(Vector3(w + over * 2.0 + 0.04, 0.1, 0.16), Vector3(0, wall_h + roof_h + 0.07, 0), col.darkened(0.18))


static func _chimney(mk: MeshKit, pos: Vector3, h: float) -> void:
	mk.use("main")
	mk.box(Vector3(0.3, h, 0.3), pos + Vector3(0, h * 0.5, 0), Color("a86050"), Basis.IDENTITY, 0.15)
	mk.box(Vector3(0.38, 0.08, 0.38), pos + Vector3(0, h + 0.04, 0), Color("6d4038"))
	mk.box(Vector3(0.2, 0.06, 0.2), pos + Vector3(0, h + 0.1, 0), C_DARK)


static func house(seed_val: int) -> Node3D:
	var rng := _rng(seed_val)
	var mk := MeshKit.new()
	var kind := rng.randi() % 5
	var wall := _pick(rng, WALLS)
	var roof := _pick(rng, ROOFS)
	var shut := _pick(rng, SHUTTERS) if rng.randf() < 0.65 else Color(-1, 0, 0)
	var door := _pick(rng, ["6b4226", "3f5f7f", "7a2f2a", "3f6b4a"])

	# Grundstück
	mk.box(Vector3(3.5, 0.04, 3.4), Vector3(0, 0.02, 0), Color("b9c98a"))

	if kind == 3:
		# Scheune
		wall = _pick(rng, ["9c4a3a", "8a5a3c", "a6583f"])
		roof = _pick(rng, ["4b4f57", "5d4a3e", "6a3b33"])
		var w := 2.9
		var d := 2.2
		var wh := 1.7
		mk.box(Vector3(w + 0.08, 0.16, d + 0.08), Vector3(0, 0.08, 0), C_STONE)
		mk.box(Vector3(w, wh, d), Vector3(0, wh * 0.5 + 0.1, 0), wall, Basis.IDENTITY, 0.14)
		for i in 7:
			mk.box(Vector3(0.04, wh, 0.02), Vector3(-w * 0.5 + 0.25 + i * 0.4, wh * 0.5 + 0.1, d * 0.5 + 0.01), wall.darkened(0.12))
			mk.box(Vector3(0.04, wh, 0.02), Vector3(-w * 0.5 + 0.25 + i * 0.4, wh * 0.5 + 0.1, -d * 0.5 - 0.01), wall.darkened(0.12))
		_roof(mk, w, d, wh + 0.1, 1.25, roof, wall, 0.25)
		# Scheunentor
		mk.box(Vector3(1.0, 1.25, 0.06), Vector3(0.3, 0.72, d * 0.5 + 0.02), C_WHITE)
		mk.box(Vector3(0.88, 1.15, 0.08), Vector3(0.3, 0.68, d * 0.5 + 0.02), wall.darkened(0.3))
		mk.box(Vector3(0.05, 1.15, 0.1), Vector3(0.3, 0.68, d * 0.5 + 0.02), C_WHITE)
		_window(mk, Vector3(-0.9, 1.1, d * 0.5), 0, 0.34, 0.34)
		# Heuballen
		mk.cyl(0.26, 0.26, 0.4, Vector3(1.2, 0.3, 1.45), Color("e3c66a"), 9, Vector3.RIGHT)
		mk.cyl(0.26, 0.26, 0.4, Vector3(0.65, 0.3, 1.5), Color("d9bb5c"), 9, Vector3.RIGHT)
	elif kind == 4:
		# zweistöckiges Stadthaus
		var w := rng.randf_range(2.1, 2.5)
		var d := rng.randf_range(2.0, 2.3)
		var wh := rng.randf_range(2.5, 2.9)
		mk.box(Vector3(w + 0.08, 0.2, d + 0.08), Vector3(0, 0.1, 0), C_STONE)
		mk.box(Vector3(w, wh, d), Vector3(0, wh * 0.5 + 0.1, 0), wall, Basis.IDENTITY, 0.12)
		mk.box(Vector3(w + 0.04, 0.07, d + 0.04), Vector3(0, wh * 0.52 + 0.1, 0), wall.darkened(0.12))
		_roof(mk, w, d, wh + 0.1, rng.randf_range(1.0, 1.3), roof, wall)
		for fl in 2:
			var y := 0.85 + fl * (wh * 0.5)
			for sx in [-1.0, 1.0]:
				if fl == 0 and sx > 0.0:
					continue
				_window(mk, Vector3(sx * w * 0.26, y, d * 0.5), 0, 0.36, 0.5, shut)
				_window(mk, Vector3(sx * w * 0.26, y, -d * 0.5), 180, 0.36, 0.5, shut)
			_window(mk, Vector3(w * 0.5, y, 0), 90, 0.36, 0.5)
			_window(mk, Vector3(-w * 0.5, y, 0), 270, 0.36, 0.5)
		_door(mk, Vector3(w * 0.26, 0.2, d * 0.5), 0, door)
		_chimney(mk, Vector3(-w * 0.25, wh + 0.5, 0.25), 0.95)
	else:
		# Einfamilienhaus (ggf. mit Anbau)
		var w := rng.randf_range(2.2, 2.8)
		var d := rng.randf_range(1.9, 2.3)
		var wh := rng.randf_range(1.5, 1.9)
		var rh := rng.randf_range(1.05, 1.4)
		var ox := 0.0
		if kind == 2:
			ox = -0.3
		mk.push_at(Vector3(ox, 0, -0.15))
		mk.box(Vector3(w + 0.08, 0.18, d + 0.08), Vector3(0, 0.09, 0), C_STONE)
		mk.box(Vector3(w, wh, d), Vector3(0, wh * 0.5 + 0.1, 0), wall, Basis.IDENTITY, 0.12)
		_roof(mk, w, d, wh + 0.1, rh, roof, wall)
		_window(mk, Vector3(-w * 0.27, 0.95, d * 0.5), 0, 0.42, 0.46, shut)
		_door(mk, Vector3(w * 0.24, 0.18, d * 0.5), 0, door)
		_window(mk, Vector3(-w * 0.27, 0.95, -d * 0.5), 180, 0.42, 0.46, shut)
		_window(mk, Vector3(w * 0.27, 0.95, -d * 0.5), 180, 0.42, 0.46, shut)
		_window(mk, Vector3(w * 0.5, 0.95, 0), 90, 0.4, 0.46)
		_window(mk, Vector3(-w * 0.5, 0.95, 0), 270, 0.4, 0.46)
		# Giebelfenster
		_window(mk, Vector3(w * 0.5, wh + 0.45, 0), 90, 0.28, 0.3)
		_window(mk, Vector3(-w * 0.5, wh + 0.45, 0), 270, 0.28, 0.3)
		_chimney(mk, Vector3(w * rng.randf_range(-0.3, 0.3), wh + rh * 0.45, -d * 0.2), 0.9)
		mk.pop()
		if kind == 2:
			# Anbau / Garage
			var aw := 1.0
			var ad := 1.5
			var ah := 1.15
			var ax := ox + w * 0.5 + aw * 0.5 - 0.02
			mk.box(Vector3(aw, ah, ad), Vector3(ax, ah * 0.5 + 0.06, 0.05), wall.darkened(0.04), Basis.IDENTITY, 0.12)
			mk.box(Vector3(aw + 0.16, 0.1, ad + 0.2), Vector3(ax + 0.02, ah + 0.11, 0.05), roof.darkened(0.1))
			mk.box(Vector3(0.7, 0.8, 0.05), Vector3(ax, 0.48, 0.05 + ad * 0.5 + 0.01), C_WHITE.darkened(0.1))
			for i in 4:
				mk.box(Vector3(0.7, 0.02, 0.06), Vector3(ax, 0.2 + i * 0.18, 0.05 + ad * 0.5 + 0.01), Color("9aa0a6"))

	# Garten-Details
	var deco := rng.randi() % 4
	if deco == 0:
		# Hecke
		for i in 6:
			mk.blob(Vector3(0.3, 0.26, 0.24), Vector3(-1.5 + i * 0.6, 0.24, 1.55), Color("4f8f45"), 0, 0.12, rng, Color("3c7038"))
	elif deco == 1:
		# Zaun
		for i in 9:
			mk.box(Vector3(0.07, 0.42, 0.07), Vector3(-1.6 + i * 0.4, 0.21, 1.6), C_WHITE)
		mk.box(Vector3(3.3, 0.06, 0.04), Vector3(0, 0.32, 1.6), C_WHITE)
		mk.box(Vector3(3.3, 0.06, 0.04), Vector3(0, 0.16, 1.6), C_WHITE)
	elif deco == 2:
		# Blumenbeet
		mk.box(Vector3(1.2, 0.1, 0.4), Vector3(-0.9, 0.07, 1.45), Color("7a5a3e"))
		for i in 6:
			var fc := _pick(rng, ["e8545a", "f4d03f", "f39ac0", "ffffff", "c77dff"])
			mk.blob(Vector3(0.09, 0.09, 0.09), Vector3(-1.35 + i * 0.18, 0.2, 1.45 + rng.randf_range(-0.08, 0.08)), fc, 0)
	else:
		# kleiner Obstbaum
		var tp := Vector3(rng.randf_range(-1.4, -1.0), 0, 1.35)
		mk.cyl(0.07, 0.05, 0.5, tp, C_TRUNK, 6)
		mk.blob(Vector3(0.42, 0.4, 0.42), tp + Vector3(0, 0.8, 0), Color("6fb04a"), 1, 0.12, rng, Color("4f8f3d"))

	var root := Node3D.new()
	root.add_child(mk.instance(Mats.all()))
	root.rotation.y = (rng.randi() % 4) * PI * 0.5
	return root


static func church(seed_val: int) -> Node3D:
	var rng := _rng(seed_val)
	var mk := MeshKit.new()
	var wall := Color("f3eee2")
	var roof := Color("7a3f36")
	mk.box(Vector3(3.6, 0.04, 3.2), Vector3(0, 0.02, 0), Color("c8c2ae"))
	# Schiff
	var w := 2.4
	var d := 1.7
	var wh := 2.0
	mk.push_at(Vector3(0.45, 0, 0))
	mk.box(Vector3(w + 0.1, 0.2, d + 0.1), Vector3(0, 0.1, 0), C_STONE)
	mk.box(Vector3(w, wh, d), Vector3(0, wh * 0.5 + 0.1, 0), wall, Basis.IDENTITY, 0.12)
	_roof(mk, w, d, wh + 0.1, 1.35, roof, wall, 0.18)
	for i in 3:
		for sz in [-1.0, 1.0]:
			mk.push_at(Vector3(-0.75 + i * 0.75, 1.15, sz * d * 0.5), 0.0 if sz > 0 else 180.0)
			mk.box(Vector3(0.34, 0.95, 0.05), Vector3(0, 0, 0.012), C_WHITE.darkened(0.1))
			mk.use("glass")
			mk.box(Vector3(0.24, 0.85, 0.06), Vector3(0, 0, 0.012), Color("4a6fa0"))
			mk.use("main")
			mk.pop()
	mk.pop()
	# Turm
	var tw := 1.15
	var th := 3.6
	var tx := -1.1
	mk.box(Vector3(tw + 0.1, 0.24, tw + 0.1), Vector3(tx, 0.12, 0), C_STONE)
	mk.box(Vector3(tw, th, tw), Vector3(tx, th * 0.5 + 0.1, 0), wall, Basis.IDENTITY, 0.1)
	mk.box(Vector3(tw + 0.1, 0.1, tw + 0.1), Vector3(tx, th * 0.72, 0), wall.darkened(0.12))
	mk.cyl(tw * 0.78, 0.0, 1.9, Vector3(tx, th + 0.1, 0), roof, 4, Vector3.UP, false, false, roof.lightened(0.08))
	mk.box(Vector3(0.05, 0.4, 0.05), Vector3(tx, th + 2.15, 0), Color("d4a84b"))
	mk.box(Vector3(0.22, 0.05, 0.05), Vector3(tx, th + 2.2, 0), Color("d4a84b"))
	# Uhr und Schallfenster
	for yaw in [0.0, 90.0, 180.0, 270.0]:
		var b := Basis(Vector3.UP, deg_to_rad(yaw))
		var o: Vector3 = b * Vector3(0, 0, tw * 0.5 + 0.01)
		mk.cyl(0.26, 0.26, 0.04, Vector3(tx, th * 0.86, 0) + o, C_WHITE, 12, b * Vector3.BACK)
		mk.box(Vector3(0.03, 0.2, 0.02), Vector3(tx, th * 0.86 + 0.08, 0) + o + b * Vector3(0, 0, 0.04), C_DARK, b)
		mk.box(Vector3(0.14, 0.03, 0.02), Vector3(tx, th * 0.86, 0) + o + b * Vector3(0.06, 0, 0.04), C_DARK, b)
		mk.box(Vector3(0.3, 0.5, 0.03), Vector3(tx, th * 0.58, 0) + o, Color("4a3b32"), b)
	_door(mk, Vector3(tx, 0.24, tw * 0.5), 0, Color("5a3a26"), 0.5, 1.05)
	var root := Node3D.new()
	root.add_child(mk.instance(Mats.all()))
	root.rotation.y = (rng.randi() % 4) * PI * 0.5
	return root


# ======================================================================= Natur

static func conifer_mesh(variant: int) -> ArrayMesh:
	var rng := _rng(100 + variant)
	var mk := MeshKit.new()
	var cols := [Color("2f6b43"), Color("3a7d4c"), Color("2a6240")]
	var c: Color = cols[variant % 3]
	mk.cyl(0.11, 0.08, 0.6, Vector3.ZERO, C_TRUNK.darkened(0.1), 6)
	var tiers := 3 + (variant % 2)
	var y := 0.42
	var r := 0.92
	for i in tiers:
		var h := 1.15 - i * 0.08
		mk.push_at(Vector3(0, y, 0), rng.randf_range(0, 60))
		mk.cyl(r, 0.0, h, Vector3.ZERO, c.darkened(0.16), 7, Vector3.UP, false, true, c.lightened(0.14 + i * 0.03))
		mk.pop()
		y += h * 0.52
		r *= 0.74
	return mk.build(Mats.all())


static func decid_mesh(variant: int) -> ArrayMesh:
	var rng := _rng(200 + variant)
	var mk := MeshKit.new()
	var cols := [Color("68ab45"), Color("7cbd52"), Color("549a43")]
	var c: Color = cols[variant % 3]
	mk.cyl(0.14, 0.09, 1.05, Vector3.ZERO, C_TRUNK, 6)
	mk.cyl(0.05, 0.03, 0.5, Vector3(0, 0.7, 0), C_TRUNK, 5, Vector3(0.6, 0.8, 0.1))
	var dark := c.darkened(0.3)
	if variant % 3 == 0:
		mk.blob(Vector3(0.95, 0.85, 0.95), Vector3(0, 1.75, 0), c.lightened(0.06), 1, 0.13, rng, dark)
	elif variant % 3 == 1:
		mk.blob(Vector3(0.75, 0.7, 0.75), Vector3(-0.3, 1.55, 0.1), c, 1, 0.13, rng, dark)
		mk.blob(Vector3(0.7, 0.65, 0.7), Vector3(0.4, 1.7, -0.15), c.lightened(0.05), 1, 0.13, rng, dark)
		mk.blob(Vector3(0.6, 0.55, 0.6), Vector3(0.0, 2.2, 0.1), c.lightened(0.1), 1, 0.13, rng, dark)
	else:
		mk.blob(Vector3(0.7, 1.15, 0.7), Vector3(0, 1.95, 0), c, 1, 0.12, rng, dark)
	return mk.build(Mats.all())


## Vereinfachte Bäume für den Wald außerhalb des Spielfelds (wenige Dreiecke).
static func conifer_lite(variant: int) -> ArrayMesh:
	var mk := MeshKit.new()
	var cols := [Color("2f6b43"), Color("3a7d4c"), Color("2a6240")]
	var c: Color = cols[variant % 3]
	mk.cyl(0.1, 0.08, 0.5, Vector3.ZERO, C_TRUNK.darkened(0.1), 4, Vector3.UP, false, false)
	var y := 0.4
	var r := 0.95
	for i in 2 + (variant % 2):
		var h := 1.5 - i * 0.15
		mk.push_at(Vector3(0, y, 0), 25.0 * i)
		mk.cyl(r, 0.0, h, Vector3.ZERO, c.darkened(0.16), 5, Vector3.UP, false, false, c.lightened(0.16 + i * 0.03))
		mk.pop()
		y += h * 0.55
		r *= 0.72
	return mk.build(Mats.all())


static func decid_lite(variant: int) -> ArrayMesh:
	var rng := _rng(250 + variant)
	var mk := MeshKit.new()
	var cols := [Color("68ab45"), Color("7cbd52"), Color("549a43")]
	var c: Color = cols[variant % 3]
	mk.cyl(0.13, 0.09, 1.0, Vector3.ZERO, C_TRUNK, 4, Vector3.UP, false, false)
	var rad := Vector3(0.95, 0.85, 0.95) if variant % 3 != 2 else Vector3(0.72, 1.15, 0.72)
	mk.blob(rad, Vector3(0, 1.8, 0), c.lightened(0.05), 0, 0.14, rng, c.darkened(0.3))
	return mk.build(Mats.all())


static func rock_mesh(variant: int) -> ArrayMesh:
	var rng := _rng(300 + variant)
	var mk := MeshKit.new()
	var c := Color("9b9a96")
	mk.blob(Vector3(0.8, 0.55, 0.65), Vector3(0, 0.3, 0), c, 0, 0.22, rng, c.darkened(0.3))
	mk.blob(Vector3(0.45, 0.35, 0.5), Vector3(0.7, 0.18, 0.35), c.lightened(0.06), 0, 0.22, rng, c.darkened(0.3))
	if variant % 2 == 0:
		mk.blob(Vector3(0.35, 0.28, 0.3), Vector3(-0.6, 0.14, -0.5), c.darkened(0.05), 0, 0.2, rng, c.darkened(0.3))
	return mk.build(Mats.all())


static func bush_mesh() -> ArrayMesh:
	var rng := _rng(401)
	var mk := MeshKit.new()
	var c := Color("5c9c48")
	mk.blob(Vector3(0.4, 0.3, 0.4), Vector3(0, 0.22, 0), c, 0, 0.15, rng, c.darkened(0.3))
	mk.blob(Vector3(0.28, 0.24, 0.28), Vector3(0.35, 0.18, 0.1), c.lightened(0.08), 0, 0.15, rng, c.darkened(0.3))
	return mk.build(Mats.all())


static func flower_mesh() -> ArrayMesh:
	var mk := MeshKit.new()
	var cols := [Color("f6f3ec"), Color("f4d03f"), Color("ef6f7a")]
	var rng := _rng(402)
	for i in 5:
		var p := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
		mk.box(Vector3(0.025, 0.2, 0.025), p + Vector3(0, 0.1, 0), Color("4f8f45"))
		mk.blob(Vector3(0.07, 0.05, 0.07), p + Vector3(0, 0.22, 0), cols[i % 3], 0)
	return mk.build(Mats.all())


# ======================================================================= Fahrzeuge

static func _wheel_mesh(r: float, tire: Color, disc: Color, spokes: bool) -> ArrayMesh:
	var mk := MeshKit.new()
	mk.use("main")
	mk.cyl(r, r, 0.1, Vector3(-0.05, 0, 0), tire, 14, Vector3.RIGHT)
	mk.cyl(r * 0.8, r * 0.8, 0.12, Vector3(-0.06, 0, 0), disc, 12, Vector3.RIGHT)
	mk.cyl(r * 0.22, r * 0.22, 0.16, Vector3(-0.08, 0, 0), tire, 8, Vector3.RIGHT)
	if spokes:
		for i in 3:
			var b := Basis(Vector3.RIGHT, i * PI / 3.0)
			mk.box(Vector3(0.135, r * 1.5, r * 0.12), Vector3.ZERO, disc.lightened(0.25), b)
		# Gegengewicht – macht die Drehung sichtbar
		mk.box(Vector3(0.14, r * 0.3, r * 0.75), Vector3(0, -r * 0.55, 0), tire)
	return mk.build(Mats.all())


static func _buffers(mk: MeshKit, z: float, dirz: float, y: float) -> void:
	mk.use("main")
	for sx in [-1.0, 1.0]:
		mk.cyl(0.045, 0.045, 0.2, Vector3(sx * 0.42, y, z), C_DARK, 6, Vector3(0, 0, dirz))
		mk.use("metal")
		mk.cyl(0.11, 0.11, 0.04, Vector3(sx * 0.42, y, z + dirz * 0.2), Color("b8bcc2"), 8, Vector3(0, 0, dirz))
		mk.use("main")
	# Kupplungshaken
	mk.box(Vector3(0.07, 0.07, 0.22), Vector3(0, y - 0.02, z + dirz * 0.1), C_DARK)


## Dampflok (Tenderlok, Achsfolge C). Vorne ist -Z.
static func loco() -> Node3D:
	var root := Node3D.new()
	var mk := MeshKit.new()
	var green := Color("1f7550")
	var green2 := Color("185c3f")
	var red := Color("b3302a")
	var brass := Color("d9ad4e")
	var black := Color("24282d")

	# Rahmen und Pufferbohlen
	mk.use("gloss")
	mk.box(Vector3(1.0, 0.16, 3.0), Vector3(0, 0.72, 0), red)
	mk.box(Vector3(1.34, 0.3, 0.1), Vector3(0, 0.74, -1.52), red)
	mk.box(Vector3(1.34, 0.3, 0.1), Vector3(0, 0.74, 1.52), red)
	# Umlaufblech
	mk.box(Vector3(1.36, 0.05, 2.95), Vector3(0, 0.83, 0), black)
	_buffers(mk, -1.57, -1.0, 0.74)
	_buffers(mk, 1.57, 1.0, 0.74)

	# Kessel und Rauchkammer
	mk.use("gloss")
	mk.cyl(0.43, 0.43, 1.35, Vector3(0, 1.32, 0.4), green, 16, Vector3.FORWARD)
	mk.cyl(0.455, 0.455, 0.5, Vector3(0, 1.32, -0.95), black, 16, Vector3.FORWARD)
	mk.cyl(0.36, 0.3, 0.06, Vector3(0, 1.32, -1.45), black.lightened(0.08), 14, Vector3.FORWARD)
	mk.use("metal")
	mk.cyl(0.05, 0.05, 0.04, Vector3(0, 1.32, -1.51), brass, 8, Vector3.FORWARD)
	# Kesselbänder
	for z in [-0.9, -0.35, 0.2]:
		mk.cyl(0.44, 0.44, 0.04, Vector3(0, 1.32, z), brass, 16, Vector3.FORWARD, true, false)
	# Kesselstützen
	mk.use("gloss")
	mk.box(Vector3(0.5, 0.42, 0.34), Vector3(0, 0.98, -1.15), black)
	mk.box(Vector3(0.4, 0.42, 1.2), Vector3(0, 0.98, -0.2), black)

	# Schornstein
	mk.cyl(0.13, 0.12, 0.42, Vector3(0, 1.7, -1.18), black, 12)
	mk.cyl(0.12, 0.2, 0.14, Vector3(0, 2.12, -1.18), black, 12)
	mk.cyl(0.2, 0.2, 0.04, Vector3(0, 2.26, -1.18), black.lightened(0.1), 12)
	# Dampfdom und Sandkasten
	mk.use("metal")
	mk.cyl(0.19, 0.19, 0.22, Vector3(0, 1.7, -0.45), brass, 12)
	mk.blob(Vector3(0.19, 0.13, 0.19), Vector3(0, 1.92, -0.45), brass, 1, 0.0, null, Color(-1, 0, 0), true)
	mk.use("gloss")
	mk.cyl(0.14, 0.12, 0.2, Vector3(0, 1.72, 0.05), green2, 10)
	# Pfeife
	mk.use("metal")
	mk.cyl(0.035, 0.035, 0.26, Vector3(0.16, 1.7, 0.28), brass, 6)
	mk.cyl(0.05, 0.03, 0.08, Vector3(0.16, 1.94, 0.28), brass, 6)

	# Wasserkästen
	mk.use("gloss")
	for sx in [-1.0, 1.0]:
		mk.box(Vector3(0.3, 0.62, 1.3), Vector3(sx * 0.52, 1.17, -0.3), green)
		mk.box(Vector3(0.012, 0.44, 1.12), Vector3(sx * 0.672, 1.17, -0.3), brass)
		mk.box(Vector3(0.014, 0.38, 1.06), Vector3(sx * 0.673, 1.17, -0.3), green)
	# Führerhaus
	mk.box(Vector3(1.36, 1.12, 0.95), Vector3(0, 1.42, 0.83), green)
	mk.box(Vector3(1.38, 0.05, 0.97), Vector3(0, 0.88, 0.83), green2)
	mk.box(Vector3(1.56, 0.07, 1.2), Vector3(0, 2.02, 0.83), black)
	mk.box(Vector3(1.3, 0.06, 1.1), Vector3(0, 2.08, 0.83), black.lightened(0.06))
	# Kohlenkasten
	mk.box(Vector3(1.3, 0.75, 0.32), Vector3(0, 1.23, 1.44), green)
	mk.use("main")
	mk.blob(Vector3(0.55, 0.16, 0.13), Vector3(0, 1.62, 1.44), Color("17181b"), 1, 0.2, _rng(5))
	# Fenster
	mk.use("glass")
	for sx in [-1.0, 1.0]:
		mk.box(Vector3(0.03, 0.4, 0.5), Vector3(sx * 0.68, 1.66, 0.83), C_GLASS)
		mk.cyl(0.14, 0.14, 0.03, Vector3(sx * 0.38, 1.72, 0.345), C_GLASS, 10, Vector3.FORWARD)
		mk.box(Vector3(0.3, 0.3, 0.03), Vector3(sx * 0.38, 1.7, 1.31), C_GLASS)
	mk.use("metal")
	for sx in [-1.0, 1.0]:
		mk.box(Vector3(0.035, 0.46, 0.035), Vector3(sx * 0.69, 1.66, 0.56), brass)
		mk.box(Vector3(0.035, 0.46, 0.035), Vector3(sx * 0.69, 1.66, 1.1), brass)
		mk.box(Vector3(0.035, 0.035, 0.56), Vector3(sx * 0.69, 1.88, 0.83), brass)
		mk.box(Vector3(0.035, 0.035, 0.56), Vector3(sx * 0.69, 1.44, 0.83), brass)

	# Zylinder
	mk.use("gloss")
	for sx in [-1.0, 1.0]:
		mk.cyl(0.17, 0.17, 0.5, Vector3(sx * 0.62, 0.66, -0.95), black, 10, Vector3.FORWARD)
		mk.use("metal")
		mk.cyl(0.03, 0.03, 0.6, Vector3(sx * 0.62, 0.66, -0.95), Color("c2c6cc"), 6, Vector3.BACK)
		mk.use("gloss")
	# Laternen
	mk.use("main")
	for sx in [-1.0, 1.0]:
		mk.box(Vector3(0.14, 0.16, 0.12), Vector3(sx * 0.44, 0.98, -1.5), black)
	mk.box(Vector3(0.14, 0.16, 0.12), Vector3(0, 1.86, -1.38), black)
	mk.use("emit")
	for sx in [-1.0, 1.0]:
		mk.cyl(0.055, 0.055, 0.02, Vector3(sx * 0.44, 0.98, -1.57), Color("fff2b0"), 8, Vector3.FORWARD)
	mk.cyl(0.055, 0.055, 0.02, Vector3(0, 1.86, -1.45), Color("fff2b0"), 8, Vector3.FORWARD)
	# Stufen
	mk.use("main")
	for sx in [-1.0, 1.0]:
		mk.box(Vector3(0.12, 0.03, 0.3), Vector3(sx * 0.72, 0.5, 0.83), black)
		mk.box(Vector3(0.03, 0.34, 0.03), Vector3(sx * 0.72, 0.66, 0.7), black)
		mk.box(Vector3(0.03, 0.34, 0.03), Vector3(sx * 0.72, 0.66, 0.96), black)

	root.add_child(mk.instance(Mats.all()))

	# Räder (drehbar) und Kuppelstangen
	var wr := 0.37
	var wmesh := _wheel_mesh(wr, black, red, true)
	var wheels: Array = []
	var wz := [-0.92, -0.08, 0.76]
	for sx in [-1.0, 1.0]:
		for z in wz:
			var wmi := MeshInstance3D.new()
			wmi.mesh = wmesh
			wmi.position = Vector3(sx * 0.44, G.RAIL_TOP + wr - 0.02, z)
			if sx < 0.0:
				wmi.scale.x = -1.0
			root.add_child(wmi)
			wheels.append(wmi)
	var rods: Array = []
	var rmk := MeshKit.new()
	rmk.use("metal")
	rmk.box(Vector3(0.04, 0.07, 1.9), Vector3(0, 0, -0.08), Color("c9cdd3"))
	for z in wz:
		rmk.cyl(0.05, 0.05, 0.06, Vector3(-0.03, 0, z), Color("9aa0a8"), 8, Vector3.RIGHT)
	# Treibstange zum Zylinder
	rmk.box(Vector3(0.035, 0.05, 0.85), Vector3(0.04, 0, -0.5), Color("b9bdc3"))
	var rod_mesh := rmk.build(Mats.all())
	for sx in [-1.0, 1.0]:
		var rod := MeshInstance3D.new()
		rod.mesh = rod_mesh
		rod.position = Vector3(sx * 0.56, G.RAIL_TOP + wr - 0.02, 0)
		root.add_child(rod)
		rods.append(rod)
	root.set_meta("wheels", wheels)
	root.set_meta("wheel_r", wr)
	root.set_meta("rods", rods)
	root.set_meta("rod_y", G.RAIL_TOP + wr - 0.02)
	root.set_meta("chimney", Vector3(0, 2.32, -1.18))
	root.set_meta("whistle", Vector3(0.16, 2.0, 0.28))
	return root


## Personenwagen. `tail` = Schlusslicht am hinteren Ende.
static func coach(color_idx: int, tail: bool = false) -> Node3D:
	var root := Node3D.new()
	var mk := MeshKit.new()
	var schemes := [
		[Color("9c2f2f"), Color("f1e4c3")],
		[Color("2f5d8a"), Color("f1e4c3")],
		[Color("2f6b4a"), Color("efe6c8")],
	]
	var lower: Color = schemes[color_idx % schemes.size()][0]
	var upper: Color = schemes[color_idx % schemes.size()][1]
	var black := Color("24282d")
	var roofc := Color("596069")
	var L := 2.9

	mk.use("main")
	mk.box(Vector3(1.1, 0.14, L - 0.1), Vector3(0, 0.7, 0), black)
	# Trittbretter
	for sx in [-1.0, 1.0]:
		mk.box(Vector3(0.1, 0.03, L - 0.5), Vector3(sx * 0.68, 0.62, 0), black.lightened(0.1))
	mk.use("gloss")
	mk.box(Vector3(1.32, 0.52, L), Vector3(0, 1.03, 0), lower)
	mk.box(Vector3(1.32, 0.5, L), Vector3(0, 1.54, 0), upper)
	mk.box(Vector3(1.33, 0.07, L + 0.01), Vector3(0, 1.82, 0), lower)
	mk.box(Vector3(1.335, 0.03, L + 0.01), Vector3(0, 1.285, 0), Color("d9ad4e"))
	# Fenster und Türen
	for sx in [-1.0, 1.0]:
		mk.use("glass")
		for i in 5:
			mk.box(Vector3(0.03, 0.34, 0.34), Vector3(sx * 0.655, 1.56, -0.92 + i * 0.46), C_GLASS)
		mk.use("gloss")
		for ez in [-1.0, 1.0]:
			mk.box(Vector3(0.03, 0.98, 0.3), Vector3(sx * 0.656, 1.26, ez * (L * 0.5 - 0.22)), lower.darkened(0.12))
			mk.use("glass")
			mk.box(Vector3(0.035, 0.3, 0.18), Vector3(sx * 0.656, 1.56, ez * (L * 0.5 - 0.22)), C_GLASS)
			mk.use("gloss")
	# Stirnwände
	for ez in [-1.0, 1.0]:
		mk.box(Vector3(0.4, 1.0, 0.03), Vector3(0, 1.3, ez * (L * 0.5 + 0.005)), lower.darkened(0.2))
	# Tonnendach
	mk.use("main")
	var prof := PackedVector2Array([Vector2(-0.72, 1.84), Vector2(-0.66, 1.97), Vector2(-0.4, 2.08), Vector2(0, 2.12),
		Vector2(0.4, 2.08), Vector2(0.66, 1.97), Vector2(0.72, 1.84)])
	mk.extrude(prof, [[Vector3(0, 0, -L * 0.5 - 0.06), Vector3.BACK], [Vector3(0, 0, L * 0.5 + 0.06), Vector3.BACK]], roofc)
	for z in [-0.9, 0.0, 0.9]:
		mk.box(Vector3(0.22, 0.07, 0.3), Vector3(0, 2.15, z), roofc.darkened(0.2))
	_buffers(mk, -L * 0.5 - 0.02, -1.0, 0.74)
	_buffers(mk, L * 0.5 + 0.02, 1.0, 0.74)
	# Drehgestelle
	mk.use("main")
	for bz in [-0.9, 0.9]:
		mk.box(Vector3(1.0, 0.16, 0.95), Vector3(0, 0.52, bz), black.lightened(0.05))
		for sx in [-1.0, 1.0]:
			mk.box(Vector3(0.05, 0.1, 0.8), Vector3(sx * 0.56, 0.48, bz), black.lightened(0.12))
	if tail:
		mk.use("emit")
		for sx in [-1.0, 1.0]:
			mk.cyl(0.05, 0.05, 0.02, Vector3(sx * 0.48, 1.0, L * 0.5 + 0.01), Color("ff4030"), 8, Vector3.BACK)
	root.add_child(mk.instance(Mats.all()))

	var wr := 0.23
	var wmesh := _wheel_mesh(wr, black, Color("5a5f66"), false)
	var wheels: Array = []
	for bz in [-0.9, 0.9]:
		for dz in [-0.28, 0.28]:
			for sx in [-1.0, 1.0]:
				var wmi := MeshInstance3D.new()
				wmi.mesh = wmesh
				wmi.position = Vector3(sx * 0.44, G.RAIL_TOP + wr - 0.02, bz + dz)
				if sx < 0.0:
					wmi.scale.x = -1.0
				root.add_child(wmi)
				wheels.append(wmi)
	root.set_meta("wheels", wheels)
	root.set_meta("wheel_r", wr)
	return root


## Straßenfahrzeug; vorne ist -Z.
static func car(seed_val: int) -> Node3D:
	var rng := _rng(seed_val)
	var mk := MeshKit.new()
	var c := _pick(rng, CAR_COLORS)
	var kind := rng.randi() % 4
	var black := Color("1d2024")
	mk.use("gloss")
	if kind == 3:
		# Lieferwagen
		mk.box(Vector3(0.98, 0.34, 2.1), Vector3(0, 0.4, 0), c)
		mk.box(Vector3(0.96, 0.6, 1.3), Vector3(0, 0.87, 0.38), C_WHITE)
		mk.box(Vector3(0.94, 0.42, 0.55), Vector3(0, 0.78, -0.56), c)
		mk.use("glass")
		mk.box(Vector3(0.86, 0.26, 0.03), Vector3(0, 0.82, -0.84), C_GLASS)
		mk.box(Vector3(0.96, 0.22, 0.34), Vector3(0, 0.84, -0.58), C_GLASS)
	else:
		var ln := 1.85 if kind != 2 else 2.0
		mk.box(Vector3(0.96, 0.34, ln), Vector3(0, 0.38, 0), c)
		var cab_l := 0.95 if kind != 2 else 1.2
		var cab_z := 0.12 if kind != 2 else 0.25
		mk.box(Vector3(0.86, 0.3, cab_l), Vector3(0, 0.7, cab_z), c.lightened(0.05))
		mk.use("glass")
		mk.box(Vector3(0.78, 0.22, cab_l + 0.02), Vector3(0, 0.7, cab_z), C_GLASS)
		mk.box(Vector3(0.88, 0.22, cab_l - 0.16), Vector3(0, 0.7, cab_z), C_GLASS)
		mk.use("gloss")
		mk.box(Vector3(0.88, 0.04, cab_l + 0.02), Vector3(0, 0.865, cab_z), c)
		for sx in [-1.0, 1.0]:
			for ez in [-1.0, 1.0]:
				mk.box(Vector3(0.05, 0.3, 0.05), Vector3(sx * 0.41, 0.7, cab_z + ez * (cab_l * 0.5 - 0.02)), c)
	var ln2 := 2.1 if kind == 3 else (2.0 if kind == 2 else 1.85)
	mk.use("main")
	mk.box(Vector3(1.0, 0.1, 0.08), Vector3(0, 0.26, -ln2 * 0.5), black.lightened(0.2))
	mk.box(Vector3(1.0, 0.1, 0.08), Vector3(0, 0.26, ln2 * 0.5), black.lightened(0.2))
	for sx in [-1.0, 1.0]:
		for ez in [-1.0, 1.0]:
			mk.cyl(0.19, 0.19, 0.14, Vector3(sx * 0.5 - sx * 0.14, 0.19, ez * ln2 * 0.31), black, 10, Vector3(sx, 0, 0))
			mk.cyl(0.09, 0.09, 0.02, Vector3(sx * 0.5, 0.19, ez * ln2 * 0.31), Color("b9bdc3"), 8, Vector3(sx, 0, 0))
	mk.use("emit")
	for sx in [-1.0, 1.0]:
		mk.box(Vector3(0.18, 0.09, 0.02), Vector3(sx * 0.32, 0.42, -ln2 * 0.5 - 0.005), Color("fff6c8"))
		mk.box(Vector3(0.16, 0.08, 0.02), Vector3(sx * 0.34, 0.42, ln2 * 0.5 + 0.005), Color("e23b2e"))
	var root := Node3D.new()
	root.add_child(mk.instance(Mats.all()))
	root.set_meta("length", ln2)
	return root

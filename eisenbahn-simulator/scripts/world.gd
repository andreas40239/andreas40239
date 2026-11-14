class_name World
extends Node3D
## Spielfeld eines Levels: Gelände, Landschaft und alle gebauten Teile samt Bauregeln.

signal changed

const MARGIN := 16                  # Kacheln Landschaft rund um das Spielfeld
const WATER_Y := -0.42
const SHAPES := [[G.N, G.S], [G.E, G.W], [G.N, G.E], [G.E, G.S], [G.S, G.W], [G.W, G.N]]

class Cell:
	var terrain: int = G.Terrain.GRASS
	var obst: int = G.Obst.NONE
	var road_axis: int = -1         # 0 = West-Ost, 1 = Nord-Süd, 2 = Kreuzung
	var road_bridge: bool = false
	var piece: Piece = null
	var deco: Array = []            # [MultiMesh, Index, Transform3D]

class Piece:
	var kind: int
	var links: Array = []           # [[a, b], ...] verbundene Kachelkanten
	var state: int = 0              # aktive Verbindung (Weiche)
	var node: Node3D
	var tile: Vector2i
	var closed: float = 0.0         # Bahnübergang: 0 offen … 1 zu
	var active: bool = false

var index: int = 0
var level: Dictionary
var w: int
var h: int
var cells: Array = []
var start_tiles: Array[Vector2i] = []
var goal_tiles: Array[Vector2i] = []
var start_exit: int
var goal_open: int
var start_plat: int
var goal_plat: int
var spent: int = 0
var budget: int = 0
var par: int = 0
var crossings: Array[Piece] = []
var switches: Array[Piece] = []
var roads: Array[Dictionary] = []   # {axis, idx} – für den Straßenverkehr

var _pieces_root: Node3D
var _zone_root: Node3D
var _grid: MeshInstance3D
var _hint: MeshInstance3D
var _noise := FastNoiseLite.new()
var _loading := false


func setup(level_index: int) -> void:
	index = level_index
	level = Levels.LIST[level_index]
	var rows: Array = level["map"]
	h = rows.size()
	w = (rows[0] as String).length()
	start_exit = level["start_exit"]
	goal_open = level["goal_open"]
	_noise.seed = 1234 + level_index
	_noise.frequency = 0.035
	_parse(rows)
	_build_terrain()
	_build_roads()
	_build_scenery()
	_build_overlays()
	_pieces_root = Node3D.new()
	_pieces_root.name = "Pieces"
	add_child(_pieces_root)
	var sol := solve()
	par = int(sol["cost"]) + (start_tiles.size() + goal_tiles.size()) * G.COST[G.Kind.STATION]
	budget = int(ceil(par * float(level.get("budget_factor", 1.5)) / 10.0)) * 10


# ====================================================================== Karte

func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < w and t.y < h


func cell(t: Vector2i) -> Cell:
	return cells[t.y][t.x]


func _parse(rows: Array) -> void:
	cells.clear()
	var s_tiles: Array[Vector2i] = []
	var g_tiles: Array[Vector2i] = []
	for z in h:
		var row: Array = []
		var line: String = rows[z]
		for x in w:
			var c := Cell.new()
			match line[x]:
				"~": c.terrain = G.Terrain.WATER
				"T", "t": c.obst = G.Obst.TREE
				"R": c.obst = G.Obst.ROCK
				"H", "K": c.obst = G.Obst.HOUSE
				"-":
					c.terrain = G.Terrain.ROAD
					c.road_axis = 0
				"|":
					c.terrain = G.Terrain.ROAD
					c.road_axis = 1
				"+":
					c.terrain = G.Terrain.ROAD
					c.road_axis = 2
				"=":
					c.terrain = G.Terrain.WATER
					c.road_axis = 0
					c.road_bridge = true
				"!":
					c.terrain = G.Terrain.WATER
					c.road_axis = 1
					c.road_bridge = true
				"S":
					c.terrain = G.Terrain.ZONE_START
					s_tiles.append(Vector2i(x, z))
				"G":
					c.terrain = G.Terrain.ZONE_GOAL
					g_tiles.append(Vector2i(x, z))
				"s", "g": c.terrain = G.Terrain.RESERVED
			row.append(c)
		cells.append(row)
	# Bahnhofsfelder entlang der Fahrtrichtung sortieren (Prellbock zuerst / Einfahrt zuerst)
	var sd := Vector2i(G.DX[start_exit], G.DZ[start_exit])
	s_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * sd.x + a.y * sd.y < b.x * sd.x + b.y * sd.y)
	var gd_dir := G.opp(goal_open)
	var gd := Vector2i(G.DX[gd_dir], G.DZ[gd_dir])
	g_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * gd.x + a.y * gd.y < b.x * gd.x + b.y * gd.y)
	start_tiles = s_tiles
	goal_tiles = g_tiles
	start_plat = _find_plat(start_tiles[0], "s")
	goal_plat = _find_plat(goal_tiles[0], "g")
	# Straßenzüge für den Verkehr erfassen
	roads.clear()
	for z in h:
		var ch := (level["map"][z] as String)[0]
		if ch == "-" or ch == "=":
			roads.append({"axis": 0, "idx": z})
	for x in w:
		var ch := (level["map"][0] as String)[x]
		if ch == "|" or ch == "!":
			roads.append({"axis": 1, "idx": x})


func _find_plat(t: Vector2i, ch: String) -> int:
	for d in 4:
		var n := G.step(t, d)
		if in_bounds(n) and (level["map"][n.y] as String)[n.x] == ch:
			return d
	return G.N


func _char_ext(tx: int, tz: int) -> String:
	## Kartenzeichen, auch außerhalb des Spielfelds (Straßen/Flüsse laufen gerade weiter).
	var ox := tx < 0 or tx >= w
	var oz := tz < 0 or tz >= h
	if ox and oz:
		return "."
	var cx := clampi(tx, 0, w - 1)
	var cz := clampi(tz, 0, h - 1)
	var ch: String = (level["map"][cz] as String)[cx]
	if not ox and not oz:
		return ch
	if ox:
		return ch if ch in ["-", "=", "+"] else ("~" if ch == "~" else ".")
	return ch if ch in ["|", "!", "+"] else ("~" if ch == "~" else ".")


func _water_ext(tx: int, tz: int) -> bool:
	var ch := _char_ext(tx, tz)
	return ch == "~" or ch == "=" or ch == "!"


func _road_ext(tx: int, tz: int) -> bool:
	return _char_ext(tx, tz) in ["-", "|", "+", "=", "!"]


# ====================================================================== Gelände

func _build_terrain() -> void:
	var m := MARGIN
	var nx := (w + 2 * m) * 2 + 1
	var nz := (h + 2 * m) * 2 + 1
	var hgt := PackedFloat32Array()
	hgt.resize(nx * nz)
	var rim := PackedByteArray()
	rim.resize(nx * nz)
	for j in nz:
		for i in nx:
			var tx0 := floori((i - 1) / 2.0) - m
			var tx1 := floori(i / 2.0) - m
			var tz0 := floori((j - 1) / 2.0) - m
			var tz1 := floori(j / 2.0) - m
			var all_w := true
			var any_w := false
			for tx in ([tx0] if tx0 == tx1 else [tx0, tx1]):
				for tz in ([tz0] if tz0 == tz1 else [tz0, tz1]):
					if _water_ext(tx, tz):
						any_w = true
					else:
						all_w = false
			hgt[j * nx + i] = -1.0 if all_w else 0.0
			rim[j * nx + i] = 1 if (any_w and not all_w) else 0

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(nx * nz)
	norms.resize(nx * nz)
	cols.resize(nx * nz)
	var g1 := Color("86bf5c")
	var g2 := Color("6fae50")
	var g3 := Color("9ccb68")
	var out_tint := Color("5e9a4b")
	var sand := Color("d9c68c")
	var bank := Color("9a9a5c")
	for j in nz:
		for i in nx:
			var k := j * nx + i
			var px := (i * 0.5 - m) * G.T
			var pz := (j * 0.5 - m) * G.T
			var y := hgt[k]
			verts[k] = Vector3(px, y, pz)
			var hl := hgt[k - 1] if i > 0 else y
			var hr := hgt[k + 1] if i < nx - 1 else y
			var hu := hgt[k - nx] if j > 0 else y
			var hd := hgt[k + nx] if j < nz - 1 else y
			norms[k] = Vector3(hl - hr, G.T, hu - hd).normalized()
			var n := _noise.get_noise_2d(px, pz) * 0.5 + 0.5
			var n2 := _noise.get_noise_2d(px * 3.1 + 80.0, pz * 3.1 - 40.0) * 0.5 + 0.5
			var c := g1.lerp(g2, smoothstep(0.3, 0.7, n)).lerp(g3, smoothstep(0.55, 0.9, n2) * 0.45)
			# außerhalb des Spielfelds dunkler, damit die Baufläche erkennbar bleibt
			var dx := maxf(maxf(-px, px - w * G.T), 0.0)
			var dz := maxf(maxf(-pz, pz - h * G.T), 0.0)
			var dist := maxf(dx, dz)
			c = c.lerp(out_tint.lerp(Color("4f8a45"), n), smoothstep(0.0, G.T * 2.5, dist) * 0.85)
			if y < -0.5:
				c = sand
			elif rim[k] == 1:
				c = c.lerp(bank, 0.55)
			cols[k] = c
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var d := a + nx
			var e := d + 1
			if (i + j) % 2 == 0:
				idx.append_array([a, b, e, a, e, d])
			else:
				idx.append_array([a, b, d, b, e, d])
	# weiter Rand bis zum Horizont
	var far := 1400.0
	var x0 := -m * G.T
	var x1 := (w + m) * G.T
	var z0 := -m * G.T
	var z1 := (h + m) * G.T
	var oc := Color("5a9549")
	var base := verts.size()
	var ring := [
		Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1),
		Vector3(-far, 0, -far), Vector3(far, 0, -far), Vector3(far, 0, far), Vector3(-far, 0, far)]
	for p in ring:
		verts.append(p)
		norms.append(Vector3.UP)
		cols.append(oc)
	for q in [[4, 5, 1, 0], [5, 6, 2, 1], [6, 7, 3, 2], [7, 4, 0, 3]]:
		idx.append_array([base + q[0], base + q[1], base + q[2], base + q[0], base + q[2], base + q[3]])
	# Randfarbe des feinen Netzes an den weiten Rand angleichen
	for j in nz:
		for i in nx:
			if i == 0 or j == 0 or i == nx - 1 or j == nz - 1:
				if hgt[j * nx + i] > -0.5:
					cols[j * nx + i] = oc
			elif i == 1 or j == 1 or i == nx - 2 or j == nz - 2:
				if hgt[j * nx + i] > -0.5:
					cols[j * nx + i] = cols[j * nx + i].lerp(oc, 0.5)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, Mats.get_mat("ground"))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Terrain"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	# Wasserfläche
	var wk := MeshKit.new()
	wk.use("water")
	for tz in range(-m, h + m):
		for tx in range(-m, w + m):
			if _water_ext(tx, tz):
				var p := Vector3(tx * G.T, WATER_Y, tz * G.T)
				wk.quad(p, p + Vector3(G.T, 0, 0), p + Vector3(G.T, 0, G.T), p + Vector3(0, 0, G.T), Color.WHITE, Vector3.UP)
	if not wk.is_empty():
		var wmi := wk.instance(Mats.all(), false)
		wmi.name = "Water"
		add_child(wmi)


# ====================================================================== Straßen

func _build_roads() -> void:
	var mk := MeshKit.new()
	var asphalt := Color("5a5e64")
	var line := Color("f1f1ea")
	var ext := 260.0
	for r in roads:
		var axis: int = r["axis"]
		var i: int = r["idx"]
		var len_tiles := w if axis == 0 else h
		var c := (i + 0.5) * G.T
		var a0 := -ext
		var a1 := len_tiles * G.T + ext
		var bx := Basis.IDENTITY if axis == 0 else Basis(Vector3.UP, PI * 0.5)
		var mid := (a0 + a1) * 0.5
		var ctr := Vector3(mid, 0, c) if axis == 0 else Vector3(c, 0, mid)
		mk.use("road")
		mk.box(Vector3(a1 - a0, 0.07, 2.8), ctr, asphalt, bx)
		mk.use("main")
		for sgn in [-1.0, 1.0]:
			var off: Vector3 = bx * Vector3(0, 0, sgn * 1.47)
			mk.box(Vector3(a1 - a0, 0.08, 0.16), ctr + off, Color("b9b6ad"), bx)
			var off2: Vector3 = bx * Vector3(0, 0, sgn * 1.26)
			mk.box(Vector3(a1 - a0, 0.012, 0.08), ctr + off2 + Vector3(0, 0.036, 0), line, bx)
		# Mittelstriche (auf Kreuzungen ausgespart)
		var s := a0 + 0.5
		while s < a1:
			var tcoord := floori((s + 0.6) / G.T)
			var t := Vector2i(tcoord, i) if axis == 0 else Vector2i(i, tcoord)
			var skip := in_bounds(t) and cell(t).road_axis == 2
			if not skip:
				var p := Vector3(s + 0.6, 0.036, c) if axis == 0 else Vector3(c, 0.036, s + 0.6)
				mk.box(Vector3(1.2, 0.012, 0.1), p, line, bx)
			s += 2.0
	# Kreuzungen: Linien abdecken
	for z in h:
		for x in w:
			var c: Cell = cells[z][x]
			if c.road_axis == 2:
				mk.use("road")
				mk.box(Vector3(2.44, 0.09, 2.44), G.tile_center(Vector2i(x, z)), asphalt)
			if c.road_bridge:
				# Straßenbrücke über das Wasser
				var bx := Basis.IDENTITY if c.road_axis == 0 else Basis(Vector3.UP, PI * 0.5)
				var p := G.tile_center(Vector2i(x, z))
				mk.use("main")
				mk.box(Vector3(G.T, 0.32, 3.3), p + Vector3(0, -0.16, 0), Color("b5b1a8"), bx)
				for sgn in [-1.0, 1.0]:
					mk.box(Vector3(G.T, 0.5, 0.16), p + bx * Vector3(0, 0.22, sgn * 1.58), Color("c9c5bb"), bx)
					mk.box(Vector3(0.5, 1.1, 0.5), p + bx * Vector3(0, -0.6, sgn * 1.1), Color("a9a59c"), bx)
	var mi := mk.instance(Mats.all(), false)
	mi.name = "Roads"
	add_child(mi)


# ====================================================================== Landschaft

func _mm(mesh: Mesh, xforms: Array, tints: Array, shadows: bool = true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, tints[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _tree_xf(p: Vector3, rng: RandomNumberGenerator, smin: float, smax: float) -> Transform3D:
	var s := rng.randf_range(smin, smax)
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
	return Transform3D(b, p)


func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + index * 17
	var con: Array = [[], [], []]
	var dec: Array = [[], [], []]
	var con_t: Array = [[], [], []]
	var dec_t: Array = [[], [], []]
	var rocks: Array = []
	var rock_t: Array = []
	var bushes: Array = []
	var bush_t: Array = []
	var flowers: Array = []
	var flower_t: Array = []
	var deco_cells: Array = []     # [Cell, Liste, Index] – wird nach dem Erzeugen verknüpft
	var rows: Array = level["map"]
	var spots := [Vector3(-1.0, 0, -0.9), Vector3(0.95, 0, -0.35), Vector3(-0.15, 0, 1.05), Vector3(1.1, 0, 1.2)]
	for z in h:
		for x in w:
			var ch: String = (rows[z] as String)[x]
			var ctr := G.tile_center(Vector2i(x, z))
			var c: Cell = cells[z][x]
			match ch:
				"H":
					var hs := Models.house(G.hash2(x, z, index + 1))
					hs.position = ctr
					add_child(hs)
				"K":
					var ks := Models.church(G.hash2(x, z, index + 1))
					ks.position = ctr
					add_child(ks)
				"T", "t":
					var cnt := 3 + (rng.randi() % 2)
					for i in cnt:
						var p: Vector3 = ctr + spots[i] + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
						var v := rng.randi() % 3
						var mixed := rng.randf() < 0.18
						var tint := Color.from_hsv(0.0, 0.0, rng.randf_range(0.86, 1.0))
						if (ch == "T") != mixed:
							con[v].append(_tree_xf(p, rng, 0.85, 1.25))
							con_t[v].append(tint)
						else:
							dec[v].append(_tree_xf(p, rng, 0.8, 1.15))
							dec_t[v].append(tint)
				"R":
					rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.1, 1.5)), ctr))
					rock_t.append(Color.WHITE)
				".":
					# kleine Details auf freien Wiesen (verschwinden beim Bebauen)
					var r := rng.randf()
					if r < 0.16:
						var p := ctr + Vector3(rng.randf_range(-1.3, 1.3), 0, rng.randf_range(-1.3, 1.3))
						deco_cells.append([c, 0, bushes.size()])
						bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), p))
						bush_t.append(Color.from_hsv(0.0, 0.0, rng.randf_range(0.85, 1.0)))
					elif r < 0.42:
						var p := ctr + Vector3(rng.randf_range(-1.3, 1.3), 0, rng.randf_range(-1.3, 1.3))
						deco_cells.append([c, 1, flowers.size()])
						flowers.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.5)), p))
						flower_t.append(Color.WHITE)
	# Wald rund um das Spielfeld: vereinfachte Bäume, nur der nahe Ring wirft Schatten
	var m := MARGIN
	var lite: Array = []          # [near/far][Nadel/Laub][Variante] -> [Transforms, Farben]
	for ring in 2:
		var kinds := []
		for kd in 2:
			var vars := []
			for v in 3:
				vars.append([[], []])
			kinds.append(vars)
		lite.append(kinds)
	for tz in range(-m, h + m):
		for tx in range(-m, w + m):
			if tx >= 0 and tz >= 0 and tx < w and tz < h:
				continue
			if _water_ext(tx, tz) or _road_ext(tx, tz):
				continue
			var dist := maxi(maxi(-tx, tx - (w - 1)), maxi(-tz, tz - (h - 1)))
			var n := _noise.get_noise_2d(tx * 9.0, tz * 9.0) * 0.5 + 0.5
			var dens := clampf(0.1 + dist * 0.1, 0.0, 0.5) * (0.45 + n * 1.1)
			if dist > 9:
				dens *= 0.6
			var ctr := Vector3((tx + 0.5) * G.T, 0, (tz + 0.5) * G.T)
			for i in 2:
				if rng.randf() > dens:
					continue
				var p: Vector3 = ctr + spots[i * 2] + Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9))
				var v := rng.randi() % 3
				var tint := Color.from_hsv(0.0, 0.0, rng.randf_range(0.8, 1.0))
				var kd := 0 if (n > 0.5 or rng.randf() < 0.25) else 1
				var ring := 0 if dist <= 4 else 1
				var xf := _tree_xf(p, rng, 1.0, 1.6) if kd == 0 else _tree_xf(p, rng, 0.95, 1.45)
				lite[ring][kd][v][0].append(xf)
				lite[ring][kd][v][1].append(tint)
	for ring in 2:
		for kd in 2:
			for v in 3:
				var data: Array = lite[ring][kd][v]
				if data[0].is_empty():
					continue
				var mesh: Mesh = Models.conifer_lite(v) if kd == 0 else Models.decid_lite(v)
				_mm(mesh, data[0], data[1], ring == 0)
	for v in 3:
		if not con[v].is_empty():
			_mm(Models.conifer_mesh(v), con[v], con_t[v])
		if not dec[v].is_empty():
			_mm(Models.decid_mesh(v), dec[v], dec_t[v])
	if not rocks.is_empty():
		_mm(Models.rock_mesh(0), rocks, rock_t)
	var bmm: MultiMeshInstance3D = _mm(Models.bush_mesh(), bushes, bush_t) if not bushes.is_empty() else null
	var fmm: MultiMeshInstance3D = _mm(Models.flower_mesh(), flowers, flower_t, false) if not flowers.is_empty() else null
	for dc in deco_cells:
		var mmi: MultiMeshInstance3D = bmm if dc[1] == 0 else fmm
		var src: Array = bushes if dc[1] == 0 else flowers
		(dc[0] as Cell).deco.append([mmi.multimesh, dc[2], src[dc[2]]])


func _set_deco(c: Cell, show: bool) -> void:
	for d in c.deco:
		var xf: Transform3D = d[2] if show else Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.0001), Vector3(0, -50, 0))
		(d[0] as MultiMesh).set_instance_transform(d[1], xf)


# ====================================================================== Markierungen

func _tile_quad(mk: MeshKit, t: Vector2i, col: Color, y: float, inset: float = 0.08) -> void:
	var p := Vector3(t.x * G.T + inset, y, t.y * G.T + inset)
	var s := G.T - inset * 2.0
	mk.quad(p, p + Vector3(s, 0, 0), p + Vector3(s, 0, s), p + Vector3(0, 0, s), col, Vector3.UP)


func _frame(mk: MeshKit, x0: float, z0: float, x1: float, z1: float, wd: float, col: Color, y: float) -> void:
	mk.quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z0 + wd), Vector3(x0, y, z0 + wd), col, Vector3.UP)
	mk.quad(Vector3(x0, y, z1 - wd), Vector3(x1, y, z1 - wd), Vector3(x1, y, z1), Vector3(x0, y, z1), col, Vector3.UP)
	mk.quad(Vector3(x0, y, z0), Vector3(x0 + wd, y, z0), Vector3(x0 + wd, y, z1), Vector3(x0, y, z1), col, Vector3.UP)
	mk.quad(Vector3(x1 - wd, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x1 - wd, y, z1), col, Vector3.UP)


func _zone_marker(tiles: Array[Vector2i], plat: int, col: Color, text: String) -> Node3D:
	var root := Node3D.new()
	var mk := MeshKit.new()
	mk.use("overlay")
	var x0 := 1e9
	var z0 := 1e9
	var x1 := -1e9
	var z1 := -1e9
	for t in tiles:
		_tile_quad(mk, t, Color(col, 0.34), 0.07)
		var pt := G.step(t, plat)
		_tile_quad(mk, pt, Color(col, 0.16), 0.07)
		for q in [t, pt]:
			x0 = minf(x0, q.x * G.T)
			z0 = minf(z0, q.y * G.T)
			x1 = maxf(x1, (q.x + 1) * G.T)
			z1 = maxf(z1, (q.y + 1) * G.T)
	_frame(mk, x0, z0, x1, z1, 0.16, Color(col.lightened(0.25), 0.95), 0.08)
	root.add_child(mk.instance(Mats.all(), false))
	var l := Label3D.new()
	l.text = text
	l.font = TrackModels.font
	l.font_size = 120
	l.pixel_size = 0.016
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Color.WHITE
	l.outline_modulate = col.darkened(0.35)
	l.outline_size = 34
	l.render_priority = 5
	l.outline_render_priority = 4
	l.position = Vector3((x0 + x1) * 0.5, 3.4, (z0 + z1) * 0.5)
	root.add_child(l)
	root.set_meta("label", l)
	return root


func _build_overlays() -> void:
	_zone_root = Node3D.new()
	add_child(_zone_root)
	_zone_root.add_child(_zone_marker(start_tiles, start_plat, Color("35c46a"), "START"))
	_zone_root.add_child(_zone_marker(goal_tiles, goal_plat, Color("ff9d1e"), "ZIEL"))
	# Raster
	var mk := MeshKit.new()
	mk.use("overlay")
	var gc := Color(1, 1, 1, 0.16)
	for x in range(1, w):
		mk.quad(Vector3(x * G.T - 0.03, 0.05, 0), Vector3(x * G.T + 0.03, 0.05, 0), Vector3(x * G.T + 0.03, 0.05, h * G.T), Vector3(x * G.T - 0.03, 0.05, h * G.T), gc, Vector3.UP)
	for z in range(1, h):
		mk.quad(Vector3(0, 0.05, z * G.T - 0.03), Vector3(w * G.T, 0.05, z * G.T - 0.03), Vector3(w * G.T, 0.05, z * G.T + 0.03), Vector3(0, 0.05, z * G.T + 0.03), gc, Vector3.UP)
	_frame(mk, -0.1, -0.1, w * G.T + 0.1, h * G.T + 0.1, 0.14, Color(1, 1, 1, 0.5), 0.05)
	_grid = mk.instance(Mats.all(), false)
	add_child(_grid)
	_hint = MeshInstance3D.new()
	_hint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hint)


func set_build_view(on: bool) -> void:
	_grid.visible = on
	_zone_root.visible = on
	_hint.visible = on


## Hebt die Felder hervor, auf denen das gewählte Werkzeug bauen kann.
func show_tool_hint(tool: int) -> void:
	var mk := MeshKit.new()
	mk.use("overlay")
	var col := Color(1, 1, 1, 0.0)
	match tool:
		G.Tool.BRIDGE: col = Color(0.35, 0.8, 1.0, 0.34)
		G.Tool.CROSSING: col = Color(1.0, 0.85, 0.2, 0.36)
		G.Tool.STATION: col = Color(1.0, 1.0, 1.0, 0.3)
	if col.a > 0.0:
		for z in h:
			for x in w:
				var t := Vector2i(x, z)
				if cell(t).piece == null and check_tool(tool, t) == "":
					_tile_quad(mk, t, col, 0.1, 0.3)
	_hint.mesh = mk.build(Mats.all()) if not mk.is_empty() else null


# ====================================================================== Bauregeln

static func kind_name(kind: int) -> String:
	match kind:
		G.Kind.TRACK: return "Gleis"
		G.Kind.SWITCH: return "Weiche"
		G.Kind.BRIDGE: return "Brücke"
		G.Kind.CROSSING: return "Bahnübergang"
		G.Kind.STATION: return "Bahnhof"
	return ""


## Liefert "" wenn `tool` auf Kachel t bauen darf, sonst eine Erklärung.
func check_tool(tool: int, t: Vector2i) -> String:
	if not in_bounds(t):
		return "Außerhalb des Spielfelds."
	var c := cell(t)
	match c.obst:
		G.Obst.HOUSE: return "Hier steht ein Gebäude."
		G.Obst.TREE: return "Hier stehen Bäume."
		G.Obst.ROCK: return "Felsen im Weg."
	match c.terrain:
		G.Terrain.RESERVED:
			return "Dieser Platz gehört zum Bahnhof."
		G.Terrain.WATER:
			if c.road_bridge:
				return "Hier verläuft die Straßenbrücke."
			if tool != G.Tool.BRIDGE:
				return "Über das Wasser führt nur eine Brücke."
		G.Terrain.ROAD:
			if c.road_axis == 2:
				return "Auf der Kreuzung kann nicht gebaut werden."
			if tool != G.Tool.CROSSING:
				return "Auf Straßen sind nur Bahnübergänge möglich."
		G.Terrain.ZONE_START, G.Terrain.ZONE_GOAL:
			if tool != G.Tool.STATION:
				return "Auf den markierten Feldern entsteht ein Bahnhof."
		_:
			match tool:
				G.Tool.BRIDGE: return "Brücken gehören über das Wasser."
				G.Tool.CROSSING: return "Bahnübergänge gehören auf eine Straße."
				G.Tool.STATION: return "Bahnhöfe nur auf den markierten Feldern."
	return ""


func _zone_axis_dir(t: Vector2i) -> int:
	return start_exit if cell(t).terrain == G.Terrain.ZONE_START else goal_open


## Ist die Verbindung a–b auf dieser Kachel vom Gelände her zulässig?
func link_ok(t: Vector2i, a: int, b: int) -> bool:
	if a == b:
		return false
	var c := cell(t)
	match c.terrain:
		G.Terrain.WATER:
			return G.opp(a) == b
		G.Terrain.ROAD:
			if G.opp(a) != b:
				return false
			return (a % 2 == 0) if c.road_axis == 0 else (a % 2 == 1)
		G.Terrain.ZONE_START, G.Terrain.ZONE_GOAL:
			return G.opp(a) == b and a % 2 == _zone_axis_dir(t) % 2
	return true


func _terrain_kind(t: Vector2i) -> int:
	match cell(t).terrain:
		G.Terrain.WATER: return G.Kind.BRIDGE
		G.Terrain.ROAD: return G.Kind.CROSSING
		G.Terrain.ZONE_START, G.Terrain.ZONE_GOAL: return G.Kind.STATION
	return G.Kind.TRACK


func piece_at(t: Vector2i) -> Piece:
	return cell(t).piece if in_bounds(t) else null


static func piece_has_edge(p: Piece, e: int) -> bool:
	for l in p.links:
		if e in l:
			return true
	return false


static func has_link(p: Piece, a: int, b: int) -> bool:
	for l in p.links:
		if (l[0] == a and l[1] == b) or (l[0] == b and l[1] == a):
			return true
	return false


## Zeigt vom Nachbarn in Richtung e ein Gleis auf diese Kachel?
func edge_connected(t: Vector2i, e: int) -> bool:
	var p := piece_at(G.step(t, e))
	return p != null and piece_has_edge(p, G.opp(e))


## Wie edge_connected, zählt aber auch die (noch unbebauten) Bahnhofsenden als Anschluss.
func is_conn(t: Vector2i, e: int) -> bool:
	if edge_connected(t, e):
		return true
	var n := G.step(t, e)
	if n == start_tiles.back() and e == G.opp(start_exit):
		return true
	if n == goal_tiles[0] and e == G.opp(goal_open):
		return true
	return false


func _incoming(t: Vector2i) -> Array[int]:
	var out: Array[int] = []
	for d in 4:
		if edge_connected(t, d):
			out.append(d)
	# Bahnhofsenden zählen auch unbebaut als Anschluss
	if G.step(start_tiles.back(), start_exit) == t and not (G.opp(start_exit) in out):
		out.append(G.opp(start_exit))
	if G.step(goal_tiles[0], goal_open) == t and not (G.opp(goal_open) in out):
		out.append(G.opp(goal_open))
	return out


func _auto_link(t: Vector2i) -> Array:
	var inc := _incoming(t)
	for i in inc.size():
		for j in range(i + 1, inc.size()):
			if link_ok(t, inc[i], inc[j]):
				return [inc[i], inc[j]]
	if inc.size() >= 1 and link_ok(t, inc[0], G.opp(inc[0])):
		return [inc[0], G.opp(inc[0])]
	var c := cell(t)
	match c.terrain:
		G.Terrain.WATER:
			var ns_water := 0
			for d in [G.N, G.S]:
				var n := G.step(t, d)
				if in_bounds(n) and cell(n).terrain == G.Terrain.WATER:
					ns_water += 1
			var ew_water := 0
			for d in [G.E, G.W]:
				var n := G.step(t, d)
				if in_bounds(n) and cell(n).terrain == G.Terrain.WATER:
					ew_water += 1
			return [G.E, G.W] if ns_water >= ew_water else [G.N, G.S]
		G.Terrain.ROAD:
			return [G.N, G.S] if c.road_axis == 0 else [G.E, G.W]
		G.Terrain.ZONE_START, G.Terrain.ZONE_GOAL:
			var d := _zone_axis_dir(t)
			return [d, G.opp(d)]
	return [G.E, G.W]


func _switch_variants(base: Array) -> Array:
	var out := []
	for e in base:
		for x in 4:
			if x != base[0] and x != base[1]:
				out.append([e, x])
	return out


func can_afford(cost: int) -> bool:
	return spent + cost <= budget


const MSG_BUDGET := "Das Budget reicht dafür nicht."


## Einzelnes Antippen einer Kachel mit einem Werkzeug. Liefert "" oder einen Hinweis.
func tap(tool: int, t: Vector2i) -> String:
	if not in_bounds(t):
		return ""
	var c := cell(t)
	if tool == G.Tool.ERASE:
		if c.piece == null:
			return "Hier gibt es nichts zum Abreißen."
		remove(t)
		return ""
	var err := check_tool(tool, t)
	if err != "":
		return err
	match tool:
		G.Tool.TRACK:
			if c.piece == null:
				return place(t, G.Kind.TRACK, [_auto_link(t)])
			if c.piece.kind == G.Kind.TRACK:
				var l: Array = c.piece.links[0]
				var i := 0
				for k in SHAPES.size():
					if has_link(c.piece, SHAPES[k][0], SHAPES[k][1]):
						i = k
				var nl: Array = SHAPES[(i + 1) % SHAPES.size()]
				_reshape(c.piece, [nl.duplicate()])
				return ""
			return "Hier liegt eine Weiche – zum Ändern das Weichen-Werkzeug nutzen."
		G.Tool.SWITCH:
			if c.piece == null:
				return "Weichen werden auf ein vorhandenes Gleis gesetzt."
			if c.piece.kind == G.Kind.TRACK:
				if not can_afford(G.COST[G.Kind.SWITCH] - G.COST[G.Kind.TRACK]):
					return MSG_BUDGET
				var base: Array = c.piece.links[0]
				var vars := _switch_variants(base)
				var pick: Array = vars[0]
				for v in vars:
					if edge_connected(t, v[1]):
						pick = v
						break
				_convert_to_switch(c.piece, pick)
				return ""
			# vorhandene Weiche: nächste Variante
			var base2: Array = c.piece.links[0]
			var vars2 := _switch_variants(base2)
			var cur := 0
			for k in vars2.size():
				if has_link(c.piece, vars2[k][0], vars2[k][1]):
					cur = k
			var nv: Array = vars2[(cur + 1) % vars2.size()]
			_reshape(c.piece, [base2, nv])
			return ""
		G.Tool.BRIDGE:
			if c.piece == null:
				return place(t, G.Kind.BRIDGE, [_auto_link(t)])
			var l2: Array = c.piece.links[0]
			_reshape(c.piece, [[(l2[0] + 1) % 4, (l2[1] + 1) % 4]])
			return ""
		G.Tool.CROSSING, G.Tool.STATION:
			if c.piece == null:
				return place(t, _terrain_kind(t), [_auto_link(t)])
			return ""
	return ""


## Formt eine Kachel beim Ziehen: d1/d2 sind die gewünschten Anschlussrichtungen (-1 = offen).
## `fresh`: Kachel wurde in diesem Zug gerade erst gelegt und darf frei umgeformt werden.
func shape(tool: int, t: Vector2i, d1: int, d2: int, fresh: bool) -> String:
	var err := check_tool(tool, t)
	if err != "":
		return err
	var c := cell(t)
	var p := c.piece
	var want: Array
	if d1 >= 0 and d2 >= 0:
		want = [d1, d2]
	else:
		var d := maxi(d1, d2)
		if p != null:
			if piece_has_edge(p, d):
				return ""
			if p.kind != G.Kind.TRACK:
				if p.kind == G.Kind.BRIDGE and link_ok(t, d, G.opp(d)) and not edge_connected(t, p.links[0][0]) and not edge_connected(t, p.links[0][1]):
					_reshape(p, [[d, G.opp(d)]])
				return ""
			var l: Array = p.links[0]
			var conn: Array[int] = []
			for e in l:
				if is_conn(t, e):
					conn.append(e)
			if conn.size() == 2:
				if tool != G.Tool.SWITCH:
					return ""
				want = [G.opp(d) if G.opp(d) in l else l[0], d]
			elif conn.size() == 1:
				want = [conn[0], d]
			else:
				want = [G.opp(d), d]
		else:
			want = [d, G.opp(d)]
			for e in _incoming(t):
				if e != d and link_ok(t, e, d):
					want = [e, d]
					break
	if want[0] == want[1]:
		return ""
	if not link_ok(t, want[0], want[1]):
		match c.terrain:
			G.Terrain.WATER: return "Brücken verlaufen gerade."
			G.Terrain.ROAD: return "Bahnübergänge kreuzen die Straße im rechten Winkel."
			_: return "Bahnhofsgleise liegen in Bahnhofsrichtung."
	if p == null:
		return place(t, _terrain_kind(t), [want])
	if has_link(p, want[0], want[1]):
		return ""
	if p.kind == G.Kind.TRACK:
		var l: Array = p.links[0]
		var shared := 0
		for e in want:
			if e in l:
				shared += 1
		if tool == G.Tool.SWITCH and shared == 1 and not fresh:
			if not can_afford(G.COST[G.Kind.SWITCH] - G.COST[G.Kind.TRACK]):
				return MSG_BUDGET
			_convert_to_switch(p, want)
			return ""
		var conn_cnt := 0
		var keeps := true
		for e in l:
			if is_conn(t, e):
				conn_cnt += 1
				if not (e in want):
					keeps = false
		if fresh or conn_cnt < 2 or keeps:
			_reshape(p, [want])
		return ""
	if p.kind == G.Kind.BRIDGE and fresh:
		_reshape(p, [want])
	return ""


# ====================================================================== Teile

func _make_node(p: Piece) -> Node3D:
	var n: Node3D
	match p.kind:
		G.Kind.TRACK:
			n = TrackModels.track(p.links)
		G.Kind.SWITCH:
			n = TrackModels.switch_piece(p.links, p.state)
		G.Kind.BRIDGE:
			n = TrackModels.bridge(p.links[0][0])
		G.Kind.CROSSING:
			n = TrackModels.crossing(p.links[0][0])
		_:
			n = _station_node(p.tile)
	n.position = G.tile_center(p.tile)
	return n


func _station_node(t: Vector2i) -> Node3D:
	var is_start := cell(t).terrain == G.Terrain.ZONE_START
	var tiles := start_tiles if is_start else goal_tiles
	var plat := start_plat if is_start else goal_plat
	var idx := tiles.find(t)
	# Prellbock am geschlossenen Ende
	var buffer_dir := -1
	if is_start and idx == 0:
		buffer_dir = G.opp(start_exit)
	elif not is_start and idx == tiles.size() - 1:
		buffer_dir = G.opp(goal_open)
	var lx := G.dir_vec(plat)
	var lz := lx.cross(Vector3.UP)
	var buffer := 0
	if buffer_dir >= 0:
		buffer = 1 if G.dir_vec(buffer_dir).dot(lz) > 0.0 else -1
	var nm: String = level["start_name"] if is_start else level["goal_name"]
	# Reihenfolge der Abschnitte in lokaler z-Richtung
	var n := TrackModels.station(idx, tiles.size(), is_start, nm, buffer)
	var inner := Node3D.new()
	inner.add_child(n)
	n.transform.basis = Basis(lx, Vector3.UP, lz)
	return inner


func place(t: Vector2i, kind: int, links: Array) -> String:
	var cost: int = G.COST[kind]
	if not can_afford(cost):
		return MSG_BUDGET
	var c := cell(t)
	var p := Piece.new()
	p.kind = kind
	p.links = links.duplicate(true)
	p.tile = t
	c.piece = p
	p.node = _make_node(p)
	_pieces_root.add_child(p.node)
	_pop_in(p.node)
	spent += cost
	_set_deco(c, false)
	if kind == G.Kind.CROSSING:
		crossings.append(p)
	_auto_join(t)
	changed.emit()
	return ""


## Lose Gleisenden der Nachbarn biegen sich zu den offenen Enden dieses Teils hin.
func _auto_join(t: Vector2i) -> void:
	var p := piece_at(t)
	if p == null or _loading:
		return
	for l in p.links:
		for e in l:
			if is_conn(t, e):
				continue
			var n := G.step(t, e)
			var np := piece_at(n)
			if np == null or np.kind != G.Kind.TRACK:
				continue
			var back := G.opp(e)
			var nl: Array = np.links[0]
			var conn: Array[int] = []
			for x in nl:
				if is_conn(n, x):
					conn.append(x)
			var want: Array = []
			if conn.is_empty():
				want = [back, e]
			elif conn.size() == 1 and conn[0] != back:
				want = [conn[0], back]
			if want.size() == 2 and link_ok(n, want[0], want[1]):
				np.links = [want]
				np.state = 0
				_rebuild(np)


func remove(t: Vector2i) -> void:
	var c := cell(t)
	var p := c.piece
	if p == null:
		return
	spent -= G.COST[p.kind]
	crossings.erase(p)
	switches.erase(p)
	p.node.queue_free()
	c.piece = null
	_set_deco(c, true)
	changed.emit()


func _rebuild(p: Piece) -> void:
	if p.node != null:
		p.node.queue_free()
	p.node = _make_node(p)
	_pieces_root.add_child(p.node)


func _reshape(p: Piece, links: Array) -> void:
	p.links = links.duplicate(true)
	p.state = 0
	_rebuild(p)
	_auto_join(p.tile)
	changed.emit()


func _convert_to_switch(p: Piece, extra: Array) -> void:
	spent += G.COST[G.Kind.SWITCH] - G.COST[G.Kind.TRACK]
	p.kind = G.Kind.SWITCH
	p.links = [p.links[0], extra.duplicate()]
	p.state = 0
	if not switches.has(p):
		switches.append(p)
	_rebuild(p)
	_pop_in(p.node)
	changed.emit()


func _pop_in(n: Node3D) -> void:
	if not is_inside_tree():
		return
	n.scale = Vector3(0.85, 0.3, 0.85)
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func toggle_switch(p: Piece) -> void:
	p.state = 1 - p.state
	TrackModels.set_switch_state(p.node, p.state)


func set_switch(p: Piece, state: int) -> void:
	if p.state != state:
		p.state = state
		TrackModels.set_switch_state(p.node, p.state)


func clear_all() -> void:
	for z in h:
		for x in w:
			if cells[z][x].piece != null:
				remove(Vector2i(x, z))


func piece_count() -> int:
	var n := 0
	for z in h:
		for x in w:
			if cells[z][x].piece != null:
				n += 1
	return n


# ====================================================================== Strecke prüfen

func stations_built(tiles: Array[Vector2i]) -> bool:
	for t in tiles:
		if cell(t).piece == null:
			return false
	return true


## Gibt es eine durchgehende, befahrbare Verbindung vom Start- zum Zielbahnhof?
func route_complete() -> bool:
	if not stations_built(start_tiles) or not stations_built(goal_tiles):
		return false
	var seen := {}
	var queue: Array = [[start_tiles.back(), G.opp(start_exit)]]
	while not queue.is_empty():
		var st: Array = queue.pop_back()
		var t: Vector2i = st[0]
		var e: int = st[1]
		var key := Vector3i(t.x, t.y, e)
		if seen.has(key):
			continue
		seen[key] = true
		if t == goal_tiles[0] and e == goal_open:
			return true
		var p := piece_at(t)
		if p == null:
			continue
		for l in p.links:
			if e in l:
				var x: int = l[1] if l[0] == e else l[0]
				var n := G.step(t, x)
				var np := piece_at(n)
				if np != null and piece_has_edge(np, G.opp(x)):
					queue.append([n, G.opp(x)])
	return false


## Günstigste Strecke (Dijkstra über Kachel + Einfahrkante). Dient als Maßstab für
## Budget und Sterne und dem automatischen Test.
func solve() -> Dictionary:
	var first := G.step(start_tiles.back(), start_exit)
	var dist := {}
	var prev := {}
	var open: Array = []
	var s0 := Vector3i(first.x, first.y, G.opp(start_exit))
	dist[s0] = 0
	open.append(s0)
	var goal_key := Vector3i(goal_tiles[0].x, goal_tiles[0].y, goal_open)
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if dist[open[i]] < dist[open[bi]]:
				bi = i
		var cur: Vector3i = open[bi]
		open.remove_at(bi)
		if cur == goal_key:
			break
		var t := Vector2i(cur.x, cur.y)
		var e := cur.z
		if not in_bounds(t):
			continue
		var kind := _terrain_kind(t)
		if kind == G.Kind.STATION:
			continue
		var tool := G.Tool.TRACK
		if kind == G.Kind.BRIDGE:
			tool = G.Tool.BRIDGE
		elif kind == G.Kind.CROSSING:
			tool = G.Tool.CROSSING
		if check_tool(tool, t) != "":
			continue
		for x in 4:
			if x == e or not link_ok(t, e, x):
				continue
			var n := G.step(t, x)
			var nk := Vector3i(n.x, n.y, G.opp(x))
			var nd: int = dist[cur] + G.COST[kind] * 100 + (0 if G.opp(e) == x else 1)
			if not dist.has(nk) or nd < dist[nk]:
				dist[nk] = nd
				prev[nk] = cur
				if not open.has(nk):
					open.append(nk)
	if not dist.has(goal_key):
		return {"cost": 0, "path": [], "ok": false}
	var path := []
	var k := goal_key
	while prev.has(k):
		var pk: Vector3i = prev[k]
		# pk: Kachel mit Einfahrkante pk.z, Ausfahrkante = Gegenrichtung von k.z
		path.push_front([Vector2i(pk.x, pk.y), pk.z, G.opp(k.z)])
		k = pk
	return {"cost": int(dist[goal_key] / 100), "path": path, "ok": true}


# ====================================================================== Speichern

func to_save() -> Array:
	var out := []
	for z in h:
		for x in w:
			var p: Piece = cells[z][x].piece
			if p != null:
				out.append([x, z, p.kind, p.links.duplicate(true)])
	return out


func load_save(data: Array) -> void:
	_loading = true
	_load_pieces(data)
	_loading = false


func _load_pieces(data: Array) -> void:
	for d in data:
		var t := Vector2i(int(d[0]), int(d[1]))
		if not in_bounds(t) or cell(t).piece != null:
			continue
		var kind := int(d[2])
		var links := []
		for l in d[3]:
			links.append([int(l[0]), int(l[1])])
		if links.is_empty():
			continue
		var base_kind := G.Kind.TRACK if kind == G.Kind.SWITCH else kind
		var tool := G.Tool.TRACK
		match base_kind:
			G.Kind.BRIDGE: tool = G.Tool.BRIDGE
			G.Kind.CROSSING: tool = G.Tool.CROSSING
			G.Kind.STATION: tool = G.Tool.STATION
		if check_tool(tool, t) != "" or not link_ok(t, links[0][0], links[0][1]):
			continue
		if place(t, base_kind, [links[0]]) != "":
			continue
		if kind == G.Kind.SWITCH and links.size() > 1:
			_convert_to_switch(cell(t).piece, links[1])

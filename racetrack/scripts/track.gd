class_name Track
extends Node3D
## Rennstrecke auf einem Raster. Teile werden nacheinander an das offene Ende
## angehaengt. Erzeugt Fahrbahn, Banden, Kollision, Booster-Zonen und das
## Start/Ziel-Banner (nur wenn die Strecke geschlossen ist).

signal changed

const TILE := 12.0            # Kantenlaenge einer Rasterzelle (m)
const N := 24                 # Spielfeld N x N Zellen
const WIDTH := 9.0            # Fahrbahnbreite
const WALL_H := 1.0           # sichtbare Bandenhoehe
const WALL_COLL_H := 1.9      # Kollisionshoehe der Bande (etwas hoeher, damit nichts drueberhuepft)
const WALL_T := 0.5           # Bandenstaerke
const LEVEL_H := 2.5          # Hoehe pro Rampenstufe
const ROAD_Y := 0.06
const STEP := 1.0             # Abstand der Mittellinien-Stuetzpunkte
const BANK_ANGLE := 0.52      # ~30 Grad Steilkurve
const MAX_LEVEL := 4
const START_CELL := Vector2i(11, 17)
const START_DIR := 0
const LINE_INDEX := 6         # Stuetzpunkt der Start/Ziel-Linie
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

enum { START, STRAIGHT, BOOST, RAMP_UP, RAMP_DOWN, TIGHT_L, TIGHT_R, WIDE_L, WIDE_R, BANK_L, BANK_R }

# turn: -1 links, +1 rechts; radius in Zellen; dl: Hoehenstufen-Aenderung
const PIECES := [
	{"name": "Start", "turn": 0, "radius": 0.0, "dl": 0, "bank": false, "boost": false},
	{"name": "Gerade", "turn": 0, "radius": 0.0, "dl": 0, "bank": false, "boost": false},
	{"name": "Booster", "turn": 0, "radius": 0.0, "dl": 0, "bank": false, "boost": true},
	{"name": "Rampe hoch", "turn": 0, "radius": 0.0, "dl": 1, "bank": false, "boost": false},
	{"name": "Rampe runter", "turn": 0, "radius": 0.0, "dl": -1, "bank": false, "boost": false},
	{"name": "Kurve eng L", "turn": -1, "radius": 0.5, "dl": 0, "bank": false, "boost": false},
	{"name": "Kurve eng R", "turn": 1, "radius": 0.5, "dl": 0, "bank": false, "boost": false},
	{"name": "Kurve lang L", "turn": -1, "radius": 1.5, "dl": 0, "bank": false, "boost": false},
	{"name": "Kurve lang R", "turn": 1, "radius": 1.5, "dl": 0, "bank": false, "boost": false},
	{"name": "Steilkurve L", "turn": -1, "radius": 2.5, "dl": 0, "bank": true, "boost": false},
	{"name": "Steilkurve R", "turn": 1, "radius": 2.5, "dl": 0, "bank": true, "boost": false},
]

const DEMO := [BOOST, RAMP_UP, RAMP_DOWN, STRAIGHT, STRAIGHT, BANK_R, STRAIGHT, TIGHT_R, STRAIGHT,
	TIGHT_L, TIGHT_R, BOOST, RAMP_UP, STRAIGHT, RAMP_DOWN, STRAIGHT, STRAIGHT, WIDE_R,
	STRAIGHT, STRAIGHT, STRAIGHT, TIGHT_R, STRAIGHT]

# --- Zustand ---------------------------------------------------------------
var placed: Array = []          # je Teil: {type, cell, dir, level, entry, cells}
var occupied := {}              # Vector2i -> Teil-Index
var cursor_cell := START_CELL
var cursor_dir := START_DIR
var cursor_level := 0
var closed := false

# --- Stuetzpunkte der Mittellinie -----------------------------------------
var centers := PackedVector3Array()
var tangents := PackedVector3Array()
var rights := PackedVector3Array()   # gekippt (Steilkurve)
var normals := PackedVector3Array()
var dists := PackedFloat32Array()
var total_length := 0.0
var boost_boxes: Array[AABB] = []

var _mesh_inst: MeshInstance3D
var _body: StaticBody3D
var _shape: CollisionShape3D
var _banner: Node3D
var _cursor: Node3D
var _mat_road: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_boost: ShaderMaterial
var _mat_check: ShaderMaterial
var banner_position := Vector3.ZERO


class MeshData:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	func strip(a: PackedVector3Array, b: PackedVector3Array, ua: float, ub: float,
			vv: PackedFloat32Array, ref: PackedVector3Array) -> void:
		var base := v.size()
		var m := a.size()
		for i in m:
			var along := a[mini(i + 1, m - 1)] - a[maxi(i - 1, 0)]
			var across := b[i] - a[i]
			var nn := across.cross(along).normalized()
			if nn.dot(ref[i]) < 0.0:
				nn = -nn
			v.append(a[i])
			v.append(b[i])
			n.append(nn)
			n.append(nn)
			uv.append(Vector2(ua, vv[i]))
			uv.append(Vector2(ub, vv[i]))
		for i in m - 1:
			var k := base + i * 2
			idx.append_array(PackedInt32Array([k, k + 1, k + 2, k + 1, k + 3, k + 2]))

	func quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, nn: Vector3) -> void:
		var base := v.size()
		v.append_array(PackedVector3Array([p0, p1, p2, p3]))
		n.append_array(PackedVector3Array([nn, nn, nn, nn]))
		uv.append_array(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

	func arrays() -> Array:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		return arr


func _ready() -> void:
	_make_materials()
	_mesh_inst = MeshInstance3D.new()
	_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_inst)
	_body = StaticBody3D.new()
	_body.set_meta("track", true)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.25
	_body.physics_material_override = pm
	add_child(_body)
	_shape = CollisionShape3D.new()
	_body.add_child(_shape)
	_cursor = _make_cursor()
	add_child(_cursor)
	clear()


# ---------------------------------------------------------------------------
# Raster-Helfer
# ---------------------------------------------------------------------------
static func cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x - N / 2 + 0.5) * TILE, (c.y - N / 2 + 0.5) * TILE)


static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE + N / 2), floori(p.y / TILE + N / 2))


static func in_field(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < N and c.y < N


func _entry_point(cell: Vector2i, dir: int) -> Vector2:
	return cell_center(cell) - Vector2(DIRS[dir]) * TILE * 0.5


func _piece_path(type: int, p: Vector2, d: int, step: float) -> Dictionary:
	var info: Dictionary = PIECES[type]
	var f := Vector2(DIRS[d])
	var r := Vector2(-f.y, f.x)
	var pts := PackedVector2Array()
	var exit_dir := d
	var endp: Vector2
	var turn: int = info["turn"]
	if turn == 0:
		var cnt := int(round(TILE / step))
		for i in cnt:
			pts.append(p + f * (TILE * i / cnt))
		endp = p + f * TILE
	else:
		var rad: float = info["radius"] * TILE
		var c := p + r * turn * rad
		var cnt := maxi(4, int(ceil(rad * PI * 0.5 / step)))
		for i in cnt:
			var th := PI * 0.5 * i / cnt
			pts.append(c - r * turn * rad * cos(th) + f * rad * sin(th))
		endp = c + f * rad
		exit_dir = posmod(d + turn, 4)
	return {"pts": pts, "end": endp, "dir": exit_dir}


func _piece_cells(type: int, p: Vector2, d: int) -> Array:
	var path := _piece_path(type, p, d, 0.5)
	var pts: PackedVector2Array = path["pts"]
	pts.append(path["end"])
	var cells := {}
	for i in range(1, pts.size() - 1):
		var tg := (pts[i + 1] - pts[i - 1]).normalized()
		var lat := Vector2(-tg.y, tg.x)
		for k in 9:
			var off := lerpf(-WIDTH * 0.5 + 0.3, WIDTH * 0.5 - 0.3, k / 8.0)
			cells[world_to_cell(pts[i] + lat * off)] = true
	return cells.keys()


# ---------------------------------------------------------------------------
# Bearbeiten
# ---------------------------------------------------------------------------
func clear() -> void:
	placed.clear()
	occupied.clear()
	closed = false
	cursor_cell = START_CELL
	cursor_dir = START_DIR
	cursor_level = 0
	_add(START)
	rebuild()


func piece_count() -> int:
	return placed.size()


## Haengt ein Teil an. Gibt "" bei Erfolg zurueck, sonst eine Fehlermeldung.
func add_piece(type: int, do_rebuild := true) -> String:
	if closed:
		return "Strecke ist geschlossen – erst 'Rückgängig'."
	var err := _add(type)
	if err == "" and do_rebuild:
		rebuild()
	return err


func _add(type: int) -> String:
	var info: Dictionary = PIECES[type]
	var lvl1: int = cursor_level + info["dl"]
	if lvl1 < 0:
		return "Schon auf Bodenhöhe!"
	if lvl1 > MAX_LEVEL:
		return "Maximale Höhe erreicht!"
	var entry := _entry_point(cursor_cell, cursor_dir)
	var cells := _piece_cells(type, entry, cursor_dir)
	for c in cells:
		if not in_field(c):
			return "Kein Platz – Spielfeldrand!"
		if occupied.has(c):
			return "Kein Platz – dort liegt schon Strecke!"
	var path := _piece_path(type, entry, cursor_dir, STEP)
	var idx := placed.size()
	placed.append({"type": type, "cell": cursor_cell, "dir": cursor_dir, "level": cursor_level,
		"entry": entry, "cells": cells})
	for c in cells:
		occupied[c] = idx
	var exit_dir: int = path["dir"]
	var endp: Vector2 = path["end"]
	cursor_dir = exit_dir
	cursor_level = lvl1
	cursor_cell = world_to_cell(endp + Vector2(DIRS[exit_dir]) * TILE * 0.5)
	closed = idx > 0 and cursor_cell == START_CELL and cursor_dir == START_DIR and cursor_level == 0
	return ""


func undo() -> bool:
	if placed.size() <= 1:
		return false
	var last: Dictionary = placed.pop_back()
	for c in last["cells"]:
		occupied.erase(c)
	cursor_cell = last["cell"]
	cursor_dir = last["dir"]
	cursor_level = last["level"]
	closed = false
	rebuild()
	return true


func get_types() -> Array:
	var out := []
	for i in range(1, placed.size()):
		out.append(placed[i]["type"])
	return out


func load_types(types: Array) -> void:
	placed.clear()
	occupied.clear()
	closed = false
	cursor_cell = START_CELL
	cursor_dir = START_DIR
	cursor_level = 0
	_add(START)
	for t in types:
		if int(t) > START and int(t) < PIECES.size():
			_add(int(t))
	rebuild()


func load_demo() -> void:
	load_types(DEMO)


func cursor_world() -> Vector3:
	var p := _entry_point(cursor_cell, cursor_dir)
	return Vector3(p.x, ROAD_Y + cursor_level * LEVEL_H, p.y)


func set_cursor_visible(v: bool) -> void:
	_cursor.visible = v and not closed


func is_boost(pos: Vector3) -> bool:
	for b in boost_boxes:
		if b.has_point(pos):
			return true
	return false


## Index des naechstgelegenen Stuetzpunkts (lokale Suche um hint).
func nearest_sample(pos: Vector3, hint := -1) -> int:
	var n := centers.size()
	if n == 0:
		return -1
	var best := -1
	var bd := INF
	if hint >= 0 and hint < n:
		for k in range(-25, 26):
			var j := posmod(hint + k, n) if closed else clampi(hint + k, 0, n - 1)
			var d := centers[j].distance_squared_to(pos)
			if d < bd:
				bd = d
				best = j
		if bd < 144.0:
			return best
	for j in n:
		var d := centers[j].distance_squared_to(pos)
		if d < bd:
			bd = d
			best = j
	return best


func sample_transform(i: int) -> Transform3D:
	i = clampi(i, 0, centers.size() - 1)
	var b := Basis.looking_at(tangents[i], normals[i])
	return Transform3D(b, centers[i])


# ---------------------------------------------------------------------------
# Geometrie erzeugen
# ---------------------------------------------------------------------------
func _smooth(arr: PackedFloat32Array, radius: int, extrapolate_end: bool) -> PackedFloat32Array:
	var n := arr.size()
	var out := PackedFloat32Array()
	out.resize(n)
	if n == 0:
		return out
	var slope := 0.0
	if extrapolate_end and n > 2:
		slope = arr[n - 1] - arr[n - 2]
	for i in n:
		var s := 0.0
		for k in range(-radius, radius + 1):
			var j := i + k
			if closed:
				s += arr[posmod(j, n)]
			elif j < 0:
				s += arr[0]
			elif j >= n:
				s += arr[n - 1] + slope * (j - n + 1)
			else:
				s += arr[j]
		out[i] = s / (2 * radius + 1)
	return out


func rebuild() -> void:
	var pos2 := PackedVector2Array()
	var lvl := PackedFloat32Array()
	var bank := PackedFloat32Array()
	var boost := PackedByteArray()
	boost_boxes.clear()
	for pc in placed:
		var type: int = pc["type"]
		var info: Dictionary = PIECES[type]
		var path := _piece_path(type, pc["entry"], pc["dir"], STEP)
		var pts: PackedVector2Array = path["pts"]
		var cnt := pts.size()
		var b: float = -float(info["turn"]) * BANK_ANGLE if info["bank"] else 0.0
		for i in cnt:
			pos2.append(pts[i])
			lvl.append(float(pc["level"]) + float(info["dl"]) * float(i) / cnt)
			bank.append(b)
			boost.append(1 if info["boost"] else 0)
	if not closed:
		var last: Dictionary = placed[placed.size() - 1]
		var lp := _piece_path(last["type"], last["entry"], last["dir"], STEP)
		pos2.append(lp["end"])
		lvl.append(float(cursor_level))
		bank.append(bank[bank.size() - 1])
		boost.append(0)
	# Mittellinien-Hoehe = Rampenhoehe + Anhebung durch Steilkurve (Drehpunkt Innenkante).
	# Die Schraeglage wird ueber ~25 m eingeblendet, damit die Fahrbahn nicht zu stark verwindet.
	var lift := PackedFloat32Array()
	lift.resize(lvl.size())
	for i in lvl.size():
		lvl[i] *= LEVEL_H
		lift[i] = absf(sin(bank[i])) * WIDTH * 0.5
	var hl := _smooth(lvl, 6, true)
	var hb := _smooth(lift, 12, false)
	var bk := _smooth(bank, 12, false)
	var h := PackedFloat32Array()
	h.resize(lvl.size())
	for i in lvl.size():
		h[i] = hl[i] + hb[i]
	var n := pos2.size()
	centers.resize(n)
	tangents.resize(n)
	rights.resize(n)
	normals.resize(n)
	dists.resize(n)
	for i in n:
		centers[i] = Vector3(pos2[i].x, ROAD_Y + h[i], pos2[i].y)
	total_length = 0.0
	for i in n:
		var ip := posmod(i - 1, n) if closed else maxi(i - 1, 0)
		var inx := posmod(i + 1, n) if closed else mini(i + 1, n - 1)
		var t := (centers[inx] - centers[ip]).normalized()
		var r := t.cross(Vector3.UP).normalized()
		var rb := (r * cos(bk[i]) + Vector3.UP * sin(bk[i])).normalized()
		tangents[i] = t
		rights[i] = rb
		normals[i] = rb.cross(t).normalized()
		if i > 0:
			total_length += centers[i].distance_to(centers[i - 1])
		dists[i] = total_length
	if closed:
		total_length += centers[0].distance_to(centers[n - 1])
	# Booster-Zonen
	var si := 0
	for pc in placed:
		var type: int = pc["type"]
		var cnt := int(round(TILE / STEP)) if PIECES[type]["turn"] == 0 else 0
		if PIECES[type]["turn"] != 0:
			var rad: float = PIECES[type]["radius"] * TILE
			cnt = maxi(4, int(ceil(rad * PI * 0.5 / STEP)))
		if PIECES[type]["boost"]:
			var cc := cell_center(pc["cell"])
			var y := centers[si + cnt / 2].y
			boost_boxes.append(AABB(Vector3(cc.x - TILE * 0.5, y - 2.0, cc.y - TILE * 0.5), Vector3(TILE, 5.0, TILE)))
		si += cnt
	_build_geometry(boost)
	_build_banner()
	_update_cursor()
	changed.emit()


func _build_geometry(boost: PackedByteArray) -> void:
	var n := centers.size()
	var rows := range(n)
	if closed:
		rows.append(0)
	var m := rows.size()
	var vroad := PackedFloat32Array()
	var vwall := PackedFloat32Array()
	var L := PackedVector3Array()
	var R := PackedVector3Array()
	var nrm := PackedVector3Array()
	var cen := PackedVector3Array()
	var rb := PackedVector3Array()
	for k in m:
		var i: int = rows[k]
		var d := dists[i] if k < n else total_length
		vroad.append(d / 12.0)
		vwall.append(d / 4.0)
		L.append(centers[i] - rights[i] * WIDTH * 0.5)
		R.append(centers[i] + rights[i] * WIDTH * 0.5)
		nrm.append(normals[i])
		cen.append(centers[i])
		rb.append(rights[i])

	var road := MeshData.new()
	road.strip(L, R, 0.0, 1.0, vroad, nrm)
	var wall := MeshData.new()
	var faces := PackedVector3Array()
	_add_faces(faces, L, R, nrm)
	for s in [-1.0, 1.0]:
		var e := R if s > 0 else L
		var top := PackedVector3Array()
		var otop := PackedVector3Array()
		var obot := PackedVector3Array()
		var ctop := PackedVector3Array()
		var inward := PackedVector3Array()
		var outward := PackedVector3Array()
		var ctop_o := PackedVector3Array()
		var cbot_o := PackedVector3Array()
		var ups := PackedVector3Array()
		for k in m:
			top.append(e[k] + nrm[k] * WALL_H)
			otop.append(top[k] + rb[k] * s * WALL_T)
			obot.append(Vector3(otop[k].x, -0.05, otop[k].z))
			inward.append(-rb[k] * s)
			outward.append(rb[k] * s)
			var flat_out: Vector3 = Vector3(rb[k].x, 0.0, rb[k].z).normalized() * s
			ctop.append(e[k] + Vector3.UP * WALL_COLL_H)
			ctop_o.append(ctop[k] + flat_out * WALL_T)
			cbot_o.append(Vector3(ctop_o[k].x, -0.05, ctop_o[k].z))
			ups.append(Vector3.UP)
		wall.strip(e, top, 0.25, 0.25, vwall, inward)
		wall.strip(top, otop, 0.25, 0.25, vwall, nrm)
		wall.strip(otop, obot, 0.75, 0.75, vwall, outward)
		_add_faces(faces, e, ctop, inward)
		_add_faces(faces, ctop, ctop_o, ups)
		_add_faces(faces, ctop_o, cbot_o, outward)
	if not closed:
		# Abschlussflaechen am offenen Anfang und Ende
		for k in [0, m - 1]:
			var lg := Vector3(L[k].x, -0.05, L[k].z)
			var rg := Vector3(R[k].x, -0.05, R[k].z)
			var t := tangents[rows[k]]
			var out_dir := t if k > 0 else -t
			wall.quad(L[k], R[k], rg, lg, out_dir)
			_add_tri(faces, L[k], R[k], rg, out_dir)
			_add_tri(faces, L[k], rg, lg, out_dir)
	# Booster-Overlay
	var bst := MeshData.new()
	var run_a := PackedVector3Array()
	var run_b := PackedVector3Array()
	var run_v := PackedFloat32Array()
	var run_n := PackedVector3Array()
	for k in m:
		var i: int = rows[k]
		var on: bool = k < n and boost[i] == 1
		var prev_on: bool = k > 0 and rows[k - 1] < n and boost[rows[k - 1]] == 1
		if on or prev_on:
			run_a.append(cen[k] - rb[k] * WIDTH * 0.42 + nrm[k] * 0.03)
			run_b.append(cen[k] + rb[k] * WIDTH * 0.42 + nrm[k] * 0.03)
			run_v.append(vroad[k] * 2.4)
			run_n.append(nrm[k])
		if (not on or k == m - 1) and run_a.size() > 1:
			bst.strip(run_a, run_b, 0.0, 1.0, run_v, run_n)
			run_a = PackedVector3Array()
			run_b = PackedVector3Array()
			run_v = PackedFloat32Array()
			run_n = PackedVector3Array()
		elif not on:
			run_a.clear()
			run_b.clear()
			run_v.clear()
			run_n.clear()
	# Start/Ziel-Linie
	var chk := MeshData.new()
	var li := mini(LINE_INDEX, n - 1)
	var c := centers[li] + normals[li] * 0.035
	var hw := rights[li] * WIDTH * 0.5
	var ht := tangents[li] * 0.9
	chk.quad(c - hw - ht, c + hw - ht, c + hw + ht, c - hw + ht, normals[li])

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, road.arrays())
	mesh.surface_set_material(0, _mat_road)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wall.arrays())
	mesh.surface_set_material(1, _mat_wall)
	var si := 2
	if bst.v.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bst.arrays())
		mesh.surface_set_material(si, _mat_boost)
		si += 1
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, chk.arrays())
	mesh.surface_set_material(si, _mat_check)
	_mesh_inst.mesh = mesh

	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = false
	shape.set_faces(faces)
	_shape.shape = shape


## Einseitige Kollisionsdreiecke, Vorderseite zeigt nach `ref`.
## (Jolt/Godot: Vorderseite = (c-a)x(b-a))
func _add_faces(faces: PackedVector3Array, a: PackedVector3Array, b: PackedVector3Array, ref: PackedVector3Array) -> void:
	for i in a.size() - 1:
		_add_tri(faces, a[i], b[i], a[i + 1], ref[i])
		_add_tri(faces, b[i], b[i + 1], a[i + 1], ref[i])


func _add_tri(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, ref: Vector3) -> void:
	if (c - a).cross(b - a).dot(ref) >= 0.0:
		faces.append_array(PackedVector3Array([a, b, c]))
	else:
		faces.append_array(PackedVector3Array([a, c, b]))


# ---------------------------------------------------------------------------
# Start/Ziel-Banner
# ---------------------------------------------------------------------------
func _build_banner() -> void:
	if _banner:
		_banner.queue_free()
		_banner = null
	if not closed:
		return
	_banner = Node3D.new()
	add_child(_banner)
	var li := LINE_INDEX
	var t := tangents[li]
	var flat := Vector3(t.x, 0, t.z).normalized()
	var right := flat.cross(Vector3.UP).normalized()
	var base := centers[li]
	var span := WIDTH * 0.5 + WALL_T + 0.9
	var top_y := base.y + 6.5
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.85, 0.85, 0.88)
	var body := StaticBody3D.new()
	_banner.add_child(body)
	for s in [-1.0, 1.0]:
		var p := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.9, top_y + 1.0, 0.9)
		p.mesh = bm
		p.material_override = pillar_mat
		p.position = Vector3(base.x, 0, base.z) + right * s * span + Vector3.UP * (top_y + 1.0) * 0.5
		_banner.add_child(p)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		cs.shape = bs
		cs.position = p.position
		body.add_child(cs)
	var board := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(span * 2.0 + 1.0, 2.2, 0.35)
	board.mesh = bb
	board.material_override = _mat_check
	var xf := Transform3D(Basis(right, Vector3.UP, -flat), Vector3(base.x, top_y, base.z))
	board.transform = xf
	_banner.add_child(board)
	for side in [1.0, -1.0]:
		var plate := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(span * 2.0 - 1.0, 1.3, 0.05)
		plate.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.1, 0.12)
		plate.material_override = mat
		plate.transform = xf * Transform3D(Basis(), Vector3(0, 0, 0.2 * side))
		_banner.add_child(plate)
		var lbl := Label3D.new()
		lbl.text = "START / ZIEL"
		lbl.font_size = 120
		lbl.pixel_size = 0.0085
		lbl.outline_size = 0
		lbl.modulate = Color(1, 0.95, 0.3)
		lbl.shaded = false
		lbl.transform = xf * Transform3D(Basis(Vector3.UP, 0.0 if side > 0 else PI), Vector3(0, 0, 0.23 * side))
		_banner.add_child(lbl)
	banner_position = Vector3(base.x, top_y, base.z)


# ---------------------------------------------------------------------------
# Materialien & Cursor
# ---------------------------------------------------------------------------
func _make_materials() -> void:
	var img := Image.create(256, 256, true, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in 256:
		for x in 256:
			var g := 0.30 + rng.randf() * 0.05
			var col := Color(g, g, g * 1.04)
			var u := x / 256.0
			if (u > 0.025 and u < 0.05) or (u > 0.95 and u < 0.975):
				col = Color(0.92, 0.92, 0.92)
			elif u > 0.493 and u < 0.507 and y < 128:
				col = Color(0.9, 0.9, 0.9)
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	_mat_road = StandardMaterial3D.new()
	_mat_road.albedo_texture = ImageTexture.create_from_image(img)
	_mat_road.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_road.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_road.roughness = 0.9

	var wimg := Image.create(2, 2, false, Image.FORMAT_RGB8)
	wimg.set_pixel(0, 0, Color(0.85, 0.12, 0.1))
	wimg.set_pixel(0, 1, Color(0.95, 0.95, 0.95))
	wimg.set_pixel(1, 0, Color(0.55, 0.55, 0.57))
	wimg.set_pixel(1, 1, Color(0.55, 0.55, 0.57))
	_mat_wall = StandardMaterial3D.new()
	_mat_wall.albedo_texture = ImageTexture.create_from_image(wimg)
	_mat_wall.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat_wall.cull_mode = BaseMaterial3D.CULL_DISABLED

	var bsh := Shader.new()
	bsh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	float u = abs(UV.x * 2.0 - 1.0);
	float c = fract(UV.y + u * 0.45 - TIME * 1.6);
	ALBEDO = mix(vec3(1.0, 0.35, 0.0), vec3(1.0, 0.9, 0.15), step(0.5, c));
}
"""
	_mat_boost = ShaderMaterial.new()
	_mat_boost.shader = bsh

	var csh := Shader.new()
	csh.code = """
shader_type spatial;
render_mode cull_disabled;
void fragment() {
	vec2 g = floor(UV * vec2(12.0, 2.0));
	float c = mod(g.x + g.y, 2.0);
	ALBEDO = vec3(c * 0.95 + 0.03);
}
"""
	_mat_check = ShaderMaterial.new()
	_mat_check.shader = csh


func _make_cursor() -> Node3D:
	var root := Node3D.new()
	var arrow := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(5.0, 4.0, 0.6)
	arrow.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.0)
	mat.emission_energy_multiplier = 0.6
	arrow.material_override = mat
	# Prisma liegt flach und zeigt in -Z
	arrow.rotation = Vector3(-PI * 0.5, 0, 0)
	arrow.position = Vector3(0, 0, -1.5)
	root.add_child(arrow)
	return root


func _update_cursor() -> void:
	var p := cursor_world()
	var f := Vector3(DIRS[cursor_dir].x, 0, DIRS[cursor_dir].y)
	_cursor.transform = Transform3D(Basis.looking_at(f, Vector3.UP), p + Vector3.UP * 1.5)
	_cursor.visible = _cursor.visible and not closed


func _process(_delta: float) -> void:
	if _cursor.visible:
		_cursor.get_child(0).position.y = 0.4 * sin(Time.get_ticks_msec() * 0.005)

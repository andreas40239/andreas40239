class_name CoasterTrack
extends Node3D
## Streckendaten (Raster-basiert), Pfad-Berechnung und Greybox-Darstellung.
##
## Die Strecke ist eine Kette von Teilen auf einem Raster. Jedes Teil belegt
## genau eine Rasterzelle. Der "Cursor" ist die Zelle, in die das nächste Teil
## gesetzt wird (inkl. Fahrtrichtung und Höhenstufe).

signal changed

enum Piece { STATION, STRAIGHT, LEFT, RIGHT, UP, DOWN }

const TILE := 4.0          # Kantenlänge einer Rasterzelle in Metern
const LEVEL := 2.0         # Höhe einer Höhenstufe in Metern
const GRID := 24           # Rastergröße (GRID x GRID Zellen)
const MAX_LEVEL := 8
const STATION_CELL := Vector2i(6, 12)
const STATION_LEN := 3
# Richtungen: 0 = +X (Ost), 1 = +Z (Süd), 2 = -X (West), 3 = -Z (Nord)
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

const PIECE_NAMES := {
	Piece.STATION: "Station", Piece.STRAIGHT: "Gerade", Piece.LEFT: "Links",
	Piece.RIGHT: "Rechts", Piece.UP: "Hoch", Piece.DOWN: "Runter",
}

var pieces: Array[Dictionary] = []
var cursor_cell := STATION_CELL
var cursor_dir := 0
var cursor_h := 0
var closed := false

# Gebackener Pfad (Mittellinie der Schienen)
var path_points := PackedVector3Array()
var path_dist := PackedFloat32Array()
var path_piece := PackedInt32Array()
var length := 0.0

var _mesh_instance: MeshInstance3D
var _ties: MultiMeshInstance3D
var _supports: MultiMeshInstance3D
var _station_deco: Node3D


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	_ties = MultiMeshInstance3D.new()
	add_child(_ties)
	_supports = MultiMeshInstance3D.new()
	add_child(_supports)
	_station_deco = Node3D.new()
	add_child(_station_deco)
	reset()


# ---------------------------------------------------------------- Bauen ---

func reset() -> void:
	pieces.clear()
	cursor_cell = STATION_CELL
	cursor_dir = 0
	cursor_h = 0
	closed = false
	for i in STATION_LEN:
		_append(Piece.STATION)
	_rebuild()


static func dir_vec3(d: int) -> Vector3:
	return Vector3(DIRS[d].x, 0, DIRS[d].y)


static func cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * TILE, 0.0, (cell.y + 0.5) * TILE)


static func out_dir_of(type: int, d: int) -> int:
	match type:
		Piece.LEFT:
			return (d + 3) % 4
		Piece.RIGHT:
			return (d + 1) % 4
	return d


static func out_h_of(type: int, h: int) -> int:
	match type:
		Piece.UP:
			return h + 1
		Piece.DOWN:
			return h - 1
	return h


static func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID and c.y < GRID


## Liefert "" wenn das Teil gesetzt werden kann, sonst eine Fehlermeldung.
func can_place(type: int) -> String:
	if closed:
		return "Strecke ist geschlossen – Zurück drücken zum Ändern"
	var nh := out_h_of(type, cursor_h)
	if nh < 0:
		return "Tiefer geht es nicht"
	if nh > MAX_LEVEL:
		return "Maximale Höhe erreicht"
	if not in_grid(cursor_cell):
		return "Außerhalb des Baufelds"
	var next := cursor_cell + DIRS[out_dir_of(type, cursor_dir)]
	if not in_grid(next):
		return "Kein Platz mehr am Rand"
	if is_blocked(cursor_cell, mini(cursor_h, nh), maxi(cursor_h, nh)):
		return "Zelle belegt – Zurück drücken"
	return ""


## Eine Zelle ist blockiert, wenn dort ein Teil mit weniger als 1 freier
## Höhenstufe Abstand liegt (Kreuzungen sind mit genug Abstand erlaubt).
func is_blocked(cell: Vector2i, lo: int, hi: int) -> bool:
	for p in pieces:
		if p.cell != cell:
			continue
		var plo: int = mini(p.h, p.out_h)
		var phi: int = maxi(p.h, p.out_h)
		if lo <= phi + 1 and plo <= hi + 1:
			return true
	return false


func place(type: int) -> String:
	var err := can_place(type)
	if err != "":
		return err
	_append(type)
	closed = cursor_cell == STATION_CELL and cursor_dir == 0 and cursor_h == 0
	_rebuild()
	return ""


func undo() -> bool:
	if pieces.size() <= STATION_LEN:
		return false
	var p: Dictionary = pieces.pop_back()
	cursor_cell = p.cell
	cursor_dir = p.dir
	cursor_h = p.h
	closed = false
	_rebuild()
	return true


func _append(type: int) -> void:
	var p := {
		"type": type, "cell": cursor_cell, "dir": cursor_dir, "h": cursor_h,
		"out_dir": out_dir_of(type, cursor_dir), "out_h": out_h_of(type, cursor_h),
	}
	pieces.append(p)
	cursor_dir = p.out_dir
	cursor_h = p.out_h
	cursor_cell = cursor_cell + DIRS[cursor_dir]


## Baut eine geschlossene Beispielstrecke.
func build_demo() -> void:
	reset()
	var S := Piece.STRAIGHT
	var seq := [
		Piece.UP, Piece.UP, Piece.UP, Piece.UP, S, Piece.RIGHT,
		Piece.DOWN, Piece.DOWN, Piece.RIGHT,
		Piece.DOWN, Piece.DOWN, S, S, S, S, S, S,
		Piece.RIGHT, S, S, Piece.RIGHT,
	]
	for t in seq:
		var err := place(t)
		if err != "":
			push_warning("Demo-Strecke: %s" % err)
			break


# ------------------------------------------------------------ Geometrie ---

func _piece_samples(p: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var c := cell_center(p.cell)
	var d := dir_vec3(p.dir)
	var nd := dir_vec3(p.out_dir)
	var y0: float = p.h * LEVEL
	var y1: float = p.out_h * LEVEL
	var half := TILE * 0.5
	if p.type == Piece.LEFT or p.type == Piece.RIGHT:
		var n := 10
		var pivot := c - d * half + nd * half
		for i in n:
			var t := float(i) / n * PI * 0.5
			var pt := pivot - nd * half * cos(t) + d * half * sin(t)
			pt.y = y0
			out.append(pt)
	else:
		var n := 6
		var a := c - d * half
		for i in n:
			var t := float(i) / n
			var pt := a + d * TILE * t
			pt.y = lerpf(y0, y1, t)
			out.append(pt)
	return out


func _build_path() -> void:
	var pts := PackedVector3Array()
	var owner_piece := PackedInt32Array()
	for i in pieces.size():
		for pt in _piece_samples(pieces[i]):
			pts.append(pt)
			owner_piece.append(i)
	if not closed:
		var last: Dictionary = pieces[pieces.size() - 1]
		var end := cell_center(last.cell) + dir_vec3(last.out_dir) * TILE * 0.5
		end.y = last.out_h * LEVEL
		pts.append(end)
		owner_piece.append(pieces.size() - 1)

	# Höhenverlauf glätten, damit Übergänge Flach<->Steigung weich werden.
	var n := pts.size()
	for _iter in 6:
		var ys := PackedFloat32Array()
		ys.resize(n)
		for i in n:
			var fixed: bool = pieces[owner_piece[i]].type == Piece.STATION
			if not closed and (i == 0 or i == n - 1):
				fixed = true
			if fixed:
				ys[i] = pts[i].y
				continue
			var a := pts[(i - 1 + n) % n].y
			var b := pts[(i + 1) % n].y
			ys[i] = (a + 2.0 * pts[i].y + b) * 0.25
		for i in n:
			pts[i].y = ys[i]

	path_points = pts
	path_piece = owner_piece
	path_dist = PackedFloat32Array()
	path_dist.resize(n)
	var acc := 0.0
	for i in n:
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		path_dist[i] = acc
	if closed:
		acc += pts[n - 1].distance_to(pts[0])
	length = acc


## Position/Tangente/Teil an Bogenlänge s.
func sample(s: float) -> Dictionary:
	var n := path_points.size()
	if closed:
		s = fposmod(s, length)
	else:
		s = clampf(s, 0.0, length)
	# binäre Suche nach dem Segment
	var lo := 0
	var hi := n - 1
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if path_dist[mid] <= s:
			lo = mid
		else:
			hi = mid - 1
	var i0 := lo
	var i1 := i0 + 1
	var seg_end := 0.0
	if i1 >= n:
		if closed:
			i1 = 0
			seg_end = length
		else:
			i1 = i0
			i0 = maxi(i0 - 1, 0)
			seg_end = path_dist[i1]
	else:
		seg_end = path_dist[i1]
	var seg_start := path_dist[i0]
	var t := 0.0
	if seg_end - seg_start > 0.0001:
		t = clampf((s - seg_start) / (seg_end - seg_start), 0.0, 1.0)
	var a := path_points[i0]
	var b := path_points[i1]
	var tangent := (b - a).normalized()
	if tangent == Vector3.ZERO:
		tangent = Vector3.RIGHT
	return {"pos": a.lerp(b, t), "tangent": tangent, "piece": path_piece[i0]}


## Startposition des Wagens: Mitte der Station.
func station_s() -> float:
	return TILE * (STATION_LEN * 0.5)


# ----------------------------------------------------------- Darstellung ---

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _frame(i: int) -> Basis:
	var n := path_points.size()
	var prev := path_points[(i - 1 + n) % n] if (closed or i > 0) else path_points[i]
	var next := path_points[(i + 1) % n] if (closed or i < n - 1) else path_points[i]
	var t := (next - prev).normalized()
	var side := t.cross(Vector3.UP).normalized()
	var up := side.cross(t).normalized()
	return Basis(side, up, -t)


func _rebuild() -> void:
	_build_path()
	_build_rails()
	_build_ties_and_supports()
	_build_station()
	changed.emit()


func _build_rails() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := path_points.size()
	var frames: Array[Basis] = []
	for i in n:
		frames.append(_frame(i))
	# Zwei Schienen + ein Mittelträger
	_extrude(st, frames, Vector2(-0.55, 0.15), Vector2(0.12, 0.12))
	_extrude(st, frames, Vector2(0.55, 0.15), Vector2(0.12, 0.12))
	_extrude(st, frames, Vector2(0.0, -0.15), Vector2(0.3, 0.3))
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _mat(Color(0.78, 0.78, 0.8)))
	_mesh_instance.mesh = mesh


## Extrudiert ein Rechteckprofil entlang des Pfads (flache Normalen).
func _extrude(st: SurfaceTool, frames: Array[Basis], offset: Vector2, size: Vector2) -> void:
	var n := path_points.size()
	var segs := n if closed else n - 1
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in segs:
		var j := (i + 1) % n
		var ring_a: Array[Vector3] = []
		var ring_b: Array[Vector3] = []
		for c in corners:
			var lx: float = offset.x + c.x * size.x * 0.5
			var ly: float = offset.y + c.y * size.y * 0.5
			ring_a.append(path_points[i] + frames[i].x * lx + frames[i].y * ly)
			ring_b.append(path_points[j] + frames[j].x * lx + frames[j].y * ly)
		for k in 4:
			var k2 := (k + 1) % 4
			st.add_vertex(ring_a[k])
			st.add_vertex(ring_b[k])
			st.add_vertex(ring_b[k2])
			st.add_vertex(ring_a[k])
			st.add_vertex(ring_b[k2])
			st.add_vertex(ring_a[k2])


func _build_ties_and_supports() -> void:
	# Schwellen alle ~0.8 m
	var tie_mesh := BoxMesh.new()
	tie_mesh.size = Vector3(1.4, 0.08, 0.25)
	tie_mesh.material = _mat(Color(0.45, 0.45, 0.47))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tie_mesh
	var count := int(length / 0.8)
	mm.instance_count = count
	for k in count:
		var smp := sample(k * 0.8)
		var t: Vector3 = smp.tangent
		var side := t.cross(Vector3.UP).normalized()
		var up := side.cross(t).normalized()
		var pos: Vector3 = smp.pos + up * 0.05
		mm.set_instance_transform(k, Transform3D(Basis(side, up, -t), pos))
	_ties.multimesh = mm

	# Stützen: eine pro Teil (Teilmitte), wenn höher als der Boden
	var sup_mesh := BoxMesh.new()
	sup_mesh.size = Vector3(0.3, 1.0, 0.3)
	sup_mesh.material = _mat(Color(0.55, 0.55, 0.57))
	var xforms: Array[Transform3D] = []
	var acc := {}
	for i in path_points.size():
		var pi := path_piece[i]
		if not acc.has(pi):
			acc[pi] = []
		acc[pi].append(path_points[i])
	for pi in acc:
		var pts: Array = acc[pi]
		var mid: Vector3 = pts[pts.size() / 2]
		var top := mid.y - 0.3
		if top < 0.3:
			continue
		xforms.append(Transform3D(Basis.from_scale(Vector3(1, top, 1)), Vector3(mid.x, top * 0.5, mid.z)))
	var smm := MultiMesh.new()
	smm.transform_format = MultiMesh.TRANSFORM_3D
	smm.mesh = sup_mesh
	smm.instance_count = xforms.size()
	for k in xforms.size():
		smm.set_instance_transform(k, xforms[k])
	_supports.multimesh = smm


func _build_station() -> void:
	if _station_deco.get_child_count() > 0:
		return
	var platform := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(TILE * STATION_LEN, 0.5, 2.0)
	box.material = _mat(Color(0.62, 0.62, 0.66))
	platform.mesh = box
	var start := cell_center(STATION_CELL) - Vector3(TILE * 0.5, 0, 0)
	platform.position = start + Vector3(TILE * STATION_LEN * 0.5, 0.25, -TILE * 0.5 + 0.6)
	_station_deco.add_child(platform)
	var roof := MeshInstance3D.new()
	var rbox := BoxMesh.new()
	rbox.size = Vector3(TILE * STATION_LEN, 0.2, 3.2)
	rbox.material = _mat(Color(0.5, 0.5, 0.53))
	roof.mesh = rbox
	roof.position = platform.position + Vector3(0, 3.2, 0.9)
	_station_deco.add_child(roof)
	for x in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		var pbox := BoxMesh.new()
		pbox.size = Vector3(0.2, 3.2, 0.2)
		pbox.material = rbox.material
		pole.mesh = pbox
		pole.position = platform.position + Vector3(x * (TILE * STATION_LEN * 0.5 - 0.3), 1.6, 0)
		_station_deco.add_child(pole)

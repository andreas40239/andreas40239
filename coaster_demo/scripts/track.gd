class_name CoasterTrack
extends Node3D
## Streckendaten (Raster-basiert), Pfad-Berechnung und Greybox-Darstellung.
##
## Die Strecke ist eine Kette von Teilen auf einem Raster. Jedes Teil belegt
## genau eine Rasterzelle. Der "Cursor" ist die Zelle, in die das nächste Teil
## gesetzt wird (inkl. Fahrtrichtung und Höhenstufe).

signal changed

# Neue Teile immer hinten anhängen – die Nummern stehen in den Spielständen.
enum Piece {
	STATION, STRAIGHT, LEFT, RIGHT, UP, DOWN, BANK_LEFT, BANK_RIGHT, STEEP_DOWN, LOOP,
	STEEP_UP, WIDE_LEFT, WIDE_RIGHT, CORKSCREW, BOOSTER, BRAKE, TUNNEL, SPLASH,
}

const TILE := 4.0          # Kantenlänge einer Rasterzelle in Metern
const LEVEL := 2.0         # Höhe einer Höhenstufe in Metern
const GRID := 24           # Rastergröße (GRID x GRID Zellen)
const MAX_LEVEL := 8
const STATION_CELL := Vector2i(6, 12)
const STATION_LEN := 3
const BANK_ANGLE := 35.0   # Neigung der Schrägkurven in Grad
const LOOP_RADIUS := 2.6   # Radius des Loopings in Metern
const LOOP_LEVELS := 3     # belegte Höhenstufen über dem Looping-Einstieg
const LOOP_SHIFT := 1.8    # seitlicher Versatz zwischen Ein- und Ausfahrt
const WIDE_RADIUS := 6.0   # Radius der weiten Kurve (1,5 Zellen)
const WIDE_BANK := 20.0    # Neigung der weiten Kurve
const CORK_RADIUS := 1.6   # Radius des Korkenziehers um seine Achse
const CORK_LEVELS := 2
# Richtungen: 0 = +X (Ost), 1 = +Z (Süd), 2 = -X (West), 3 = -Z (Nord)
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

const PIECE_NAMES := {
	Piece.STATION: "Station", Piece.STRAIGHT: "Gerade", Piece.LEFT: "Links",
	Piece.RIGHT: "Rechts", Piece.UP: "Hoch", Piece.DOWN: "Runter",
	Piece.BANK_LEFT: "Schrägkurve links", Piece.BANK_RIGHT: "Schrägkurve rechts",
	Piece.STEEP_DOWN: "Steile Abfahrt", Piece.LOOP: "Looping",
	Piece.STEEP_UP: "Steile Auffahrt", Piece.WIDE_LEFT: "Weite Kurve links",
	Piece.WIDE_RIGHT: "Weite Kurve rechts", Piece.CORKSCREW: "Korkenzieher",
	Piece.BOOSTER: "Booster", Piece.BRAKE: "Bremse", Piece.TUNNEL: "Tunnel",
	Piece.SPLASH: "Wasser-Splash",
}

var pieces: Array[Dictionary] = []
var cursor_cell := STATION_CELL
var cursor_dir := 0
var cursor_h := 0
var closed := false

# Gebackener Pfad (Mittellinie der Schienen)
var path_points := PackedVector3Array()
var path_tan := PackedVector3Array()   # Fahrtrichtung je Punkt
var path_up := PackedVector3Array()    # Schienen-Normale je Punkt (Neigung, Looping)
var path_dist := PackedFloat32Array()
var path_piece := PackedInt32Array()
var length := 0.0

var _mesh_instance: MeshInstance3D
var _ties: MultiMeshInstance3D
var _supports: MultiMeshInstance3D
var _station_deco: Node3D
var _special_deco: Node3D


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	_ties = MultiMeshInstance3D.new()
	add_child(_ties)
	_supports = MultiMeshInstance3D.new()
	add_child(_supports)
	_station_deco = Node3D.new()
	add_child(_station_deco)
	_special_deco = Node3D.new()
	add_child(_special_deco)
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
		Piece.LEFT, Piece.BANK_LEFT, Piece.WIDE_LEFT:
			return (d + 3) % 4
		Piece.RIGHT, Piece.BANK_RIGHT, Piece.WIDE_RIGHT:
			return (d + 1) % 4
	return d


static func out_h_of(type: int, h: int) -> int:
	match type:
		Piece.UP:
			return h + 1
		Piece.DOWN:
			return h - 1
		Piece.STEEP_DOWN:
			return h - 2
		Piece.STEEP_UP:
			return h + 2
	return h


static func is_turn(type: int) -> bool:
	return type in [Piece.LEFT, Piece.RIGHT, Piece.BANK_LEFT, Piece.BANK_RIGHT]


static func is_wide_turn(type: int) -> bool:
	return type == Piece.WIDE_LEFT or type == Piece.WIDE_RIGHT


## Teile, bei denen der Kettenlift zieht.
static func is_lift(type: int) -> bool:
	return type == Piece.UP or type == Piece.STEEP_UP


## Zellen, die ein Teil belegt (Looping/Korkenzieher: 2 lang, weite Kurve: 3 Zellen).
## Die letzte Zelle ist die, aus der das Teil herausführt.
static func cells_of(type: int, cell: Vector2i, d: int) -> Array[Vector2i]:
	if type == Piece.LOOP or type == Piece.CORKSCREW:
		return [cell, cell + DIRS[d]]
	if is_wide_turn(type):
		var nd := out_dir_of(type, d)
		return [cell, cell + DIRS[d], cell + DIRS[d] + DIRS[nd]]
	return [cell]


static func height_range(type: int, h: int) -> Vector2i:
	if type == Piece.LOOP:
		return Vector2i(h, h + LOOP_LEVELS)
	if type == Piece.CORKSCREW:
		return Vector2i(h, h + CORK_LEVELS)
	var nh := out_h_of(type, h)
	return Vector2i(mini(h, nh), maxi(h, nh))


static func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID and c.y < GRID


## Liefert "" wenn das Teil gesetzt werden kann, sonst eine Fehlermeldung.
func can_place(type: int) -> String:
	if closed:
		return "Strecke ist geschlossen – Zurück drücken zum Ändern"
	if (type == Piece.TUNNEL or type == Piece.SPLASH) and cursor_h != 0:
		return "%s geht nur auf Bodenhöhe" % PIECE_NAMES[type]
	var nh := out_h_of(type, cursor_h)
	if nh < 0:
		return "Tiefer geht es nicht"
	if nh > MAX_LEVEL:
		return "Maximale Höhe erreicht"
	var hr := height_range(type, cursor_h)
	if hr.y > MAX_LEVEL + LOOP_LEVELS:
		return "Maximale Höhe erreicht"
	var cells := cells_of(type, cursor_cell, cursor_dir)
	for c in cells:
		if not in_grid(c):
			return "Außerhalb des Baufelds"
	var next := cells[cells.size() - 1] + DIRS[out_dir_of(type, cursor_dir)]
	if not in_grid(next):
		return "Kein Platz mehr am Rand"
	for c in cells:
		if is_blocked(c, hr.x, hr.y):
			return "Kein Platz – Zelle belegt"
	return ""


## Eine Zelle ist blockiert, wenn dort ein Teil mit weniger als 1 freier
## Höhenstufe Abstand liegt (Kreuzungen sind mit genug Abstand erlaubt).
func is_blocked(cell: Vector2i, lo: int, hi: int) -> bool:
	for p in pieces:
		if not cell in p.cells:
			continue
		var plo: int = p.lo
		var phi: int = p.hi
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
	var cells := cells_of(type, cursor_cell, cursor_dir)
	var hr := height_range(type, cursor_h)
	var p := {
		"type": type, "cell": cursor_cell, "dir": cursor_dir, "h": cursor_h,
		"out_dir": out_dir_of(type, cursor_dir), "out_h": out_h_of(type, cursor_h),
		"cells": cells, "lo": hr.x, "hi": hr.y,
	}
	pieces.append(p)
	cursor_dir = p.out_dir
	cursor_h = p.out_h
	cursor_cell = cells[cells.size() - 1] + DIRS[cursor_dir]


## Teiltypen nach der Station (zum Speichern).
func get_types() -> Array[int]:
	var out: Array[int] = []
	for i in range(STATION_LEN, pieces.size()):
		out.append(pieces[i].type)
	return out


## Baut eine gespeicherte Strecke wieder auf. Gibt false zurück, wenn ein Teil
## nicht gesetzt werden konnte (die Strecke bleibt dann bis dorthin gebaut).
func load_types(types: Array) -> bool:
	reset()
	for t in types:
		var type := int(t)
		if type <= Piece.STATION or type >= Piece.size() or can_place(type) != "":
			_rebuild()
			return false
		_append(type)
		closed = cursor_cell == STATION_CELL and cursor_dir == 0 and cursor_h == 0
	_rebuild()
	return true


## Baut eine geschlossene Beispielstrecke.
func build_demo() -> void:
	reset()
	var S := Piece.STRAIGHT
	var U := Piece.UP
	var BR := Piece.BANK_RIGHT
	var T := Piece.TUNNEL
	var seq := [
		U, U, U, U, U, BR,                                  # Lift + Schrägkurve
		Piece.STEEP_DOWN, Piece.STEEP_DOWN, Piece.DOWN, S,  # First Drop
		Piece.LOOP, BR,                                     # Looping
		Piece.BOOSTER, Piece.CORKSCREW, S, Piece.SPLASH, S, S, S, BR,  # Booster, Korkenzieher, Splash
		S, T, T, S, Piece.BRAKE, S, BR,                     # Tunnel, Bremse, Station
	]
	for t in seq:
		var err := place(t)
		if err != "":
			push_warning("Demo-Strecke: %s" % err)
			break


# ------------------------------------------------------------ Geometrie ---

## Liefert Punkte, Normalen (vor dem Glätten) und ob das Teil fix bleibt.
func _piece_samples(p: Dictionary) -> Dictionary:
	var pts: Array[Vector3] = []
	var ups: Array[Vector3] = []
	var c := cell_center(p.cell)
	var d := dir_vec3(p.dir)
	var nd := dir_vec3(p.out_dir)
	var y0: float = p.h * LEVEL
	var y1: float = p.out_h * LEVEL
	var half := TILE * 0.5
	var a := c - d * half
	if is_turn(p.type):
		var n := 10
		var pivot := c - d * half + nd * half
		var banked: bool = p.type == Piece.BANK_LEFT or p.type == Piece.BANK_RIGHT
		for i in n:
			var t := float(i) / n * PI * 0.5
			var pt := pivot - nd * half * cos(t) + d * half * sin(t)
			pt.y = y0
			pts.append(pt)
			var up := Vector3.UP
			if banked:
				var inward := Vector3(pivot.x - pt.x, 0, pivot.z - pt.z).normalized()
				up += inward * tan(deg_to_rad(BANK_ANGLE))
			ups.append(up)
	elif is_wide_turn(p.type):
		var n := 16
		var pivot := a + nd * WIDE_RADIUS
		for i in n:
			var t := float(i) / n * PI * 0.5
			var pt := pivot - nd * WIDE_RADIUS * cos(t) + d * WIDE_RADIUS * sin(t)
			pt.y = y0
			pts.append(pt)
			var inward := Vector3(pivot.x - pt.x, 0, pivot.z - pt.z).normalized()
			ups.append(Vector3.UP + inward * tan(deg_to_rad(WIDE_BANK)))
	elif p.type == Piece.CORKSCREW:
		# Schraube um eine Achse in Fahrtrichtung: 360° Drehung über 2 Zellen
		var side := d.cross(Vector3.UP)
		var r := CORK_RADIUS
		var n := 36
		for i in n:
			var u := float(i) / n
			var th := TAU * smoothstep(0.1, 0.9, u)
			var pt := a + d * (2.0 * TILE * u) + side * (r * sin(th))
			pt.y = y0 + r * (1.0 - cos(th))
			pts.append(pt)
			ups.append(Vector3.UP * cos(th) - side * sin(th))
	elif p.type == Piece.LOOP:
		var lat_dir := d.cross(Vector3.UP)
		var w := LOOP_SHIFT
		var r := LOOP_RADIUS
		for i in 5:  # Einfahrt: seitlich nach innen versetzen
			var x := TILE * i / 5.0
			var lat := -w * 0.5 * smoothstep(0.0, 1.0, x / TILE)
			pts.append(a + d * x + lat_dir * lat + Vector3(0, y0, 0))
			ups.append(Vector3.UP)
		var steps := 30
		for i in steps:  # Kreis
			var th := TAU * i / steps
			var lat := -w * 0.5 + w * th / TAU
			var pt := a + d * (TILE + r * sin(th)) + lat_dir * lat
			pt.y = y0 + r * (1.0 - cos(th))
			pts.append(pt)
			ups.append(d * -sin(th) + Vector3.UP * cos(th))
		for i in 5:  # Ausfahrt: zurück auf die Mittellinie
			var x := TILE * i / 5.0
			var lat := w * 0.5 * (1.0 - smoothstep(0.0, 1.0, x / TILE))
			pts.append(a + d * (TILE + x) + lat_dir * lat + Vector3(0, y0, 0))
			ups.append(Vector3.UP)
	else:
		var n := 6
		for i in n:
			var t := float(i) / n
			var pt := a + d * TILE * t
			pt.y = lerpf(y0, y1, t)
			pts.append(pt)
			ups.append(Vector3.UP)
	var fixed: bool = p.type in [Piece.STATION, Piece.LOOP, Piece.CORKSCREW]
	return {"pts": pts, "ups": ups, "fixed": fixed}


func _build_path() -> void:
	var pts := PackedVector3Array()
	var ups := PackedVector3Array()
	var fixed := PackedByteArray()
	var owner_piece := PackedInt32Array()
	for i in pieces.size():
		var smp := _piece_samples(pieces[i])
		for k in smp.pts.size():
			pts.append(smp.pts[k])
			ups.append(smp.ups[k])
			fixed.append(1 if smp.fixed else 0)
			owner_piece.append(i)
	if not closed:
		var last: Dictionary = pieces[pieces.size() - 1]
		var end := cell_center(last.cells[last.cells.size() - 1]) + dir_vec3(last.out_dir) * TILE * 0.5
		end.y = last.out_h * LEVEL
		pts.append(end)
		ups.append(Vector3.UP)
		fixed.append(1)
		owner_piece.append(pieces.size() - 1)
		fixed[0] = 1

	# Höhe und Neigung glätten, damit Übergänge weich werden.
	var n := pts.size()
	for _iter in 6:
		var new_pts := pts.duplicate()
		var new_ups := ups.duplicate()
		for i in n:
			if fixed[i]:
				continue
			var ia := (i - 1 + n) % n
			var ib := (i + 1) % n
			new_pts[i].y = (pts[ia].y + 2.0 * pts[i].y + pts[ib].y) * 0.25
			new_ups[i] = (ups[ia] + 2.0 * ups[i] + ups[ib]) * 0.25
		pts = new_pts
		ups = new_ups

	# Tangenten (zentrale Differenz) und orthonormale Normalen
	var tans := PackedVector3Array()
	tans.resize(n)
	for i in n:
		var prev := pts[(i - 1 + n) % n] if (closed or i > 0) else pts[i]
		var next := pts[(i + 1) % n] if (closed or i < n - 1) else pts[i]
		var t := (next - prev).normalized()
		tans[i] = t
		ups[i] = _ortho_up(t, ups[i])

	path_points = pts
	path_tan = tans
	path_up = ups
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


static func _ortho_up(t: Vector3, up: Vector3) -> Vector3:
	var side := t.cross(up)
	if side.length_squared() < 0.000001:
		side = t.cross(Vector3.RIGHT)
	return side.normalized().cross(t).normalized()


## Position/Tangente/Normale/Teil an Bogenlänge s.
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
	var tangent := path_tan[i0].lerp(path_tan[i1], t).normalized()
	if tangent == Vector3.ZERO:
		tangent = Vector3.RIGHT
	var up := _ortho_up(tangent, path_up[i0].lerp(path_up[i1], t))
	return {
		"pos": path_points[i0].lerp(path_points[i1], t), "tangent": tangent,
		"up": up, "piece": path_piece[i0],
	}


## Ausrichtung entlang der Strecke: -Z = Fahrtrichtung, Y = Schienen-Normale.
static func frame_basis(tangent: Vector3, up: Vector3) -> Basis:
	return Basis(tangent.cross(up).normalized(), up, -tangent)


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
	return frame_basis(path_tan[i], path_up[i])


func _rebuild() -> void:
	_build_path()
	_build_rails()
	_build_ties_and_supports()
	_build_station()
	_build_special_deco()
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
		var up: Vector3 = smp.up
		var pos: Vector3 = smp.pos + up * 0.05
		mm.set_instance_transform(k, Transform3D(frame_basis(smp.tangent, up), pos))
	_ties.multimesh = mm

	# Stützen: eine pro Teil (Teilmitte), wenn höher als der Boden
	var sup_mesh := BoxMesh.new()
	sup_mesh.size = Vector3(0.3, 1.0, 0.3)
	sup_mesh.material = _mat(Color(0.55, 0.55, 0.57))
	var xforms: Array[Transform3D] = []
	var acc := {}
	for i in path_points.size():
		var pi := path_piece[i]
		if pieces[pi].type == Piece.LOOP or pieces[pi].type == Piece.CORKSCREW:
			continue  # Inversionen tragen sich selbst (Greybox)
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


## Zusätzliche Greybox-Teile für Booster, Bremse, Tunnel und Splash.
func _build_special_deco() -> void:
	for c in _special_deco.get_children():
		c.queue_free()
	var mid_index := {}
	for i in path_points.size():
		mid_index[path_piece[i]] = mid_index.get(path_piece[i], []) + [i]
	for pi in pieces.size():
		var p: Dictionary = pieces[pi]
		if not p.type in [Piece.BOOSTER, Piece.BRAKE, Piece.TUNNEL, Piece.SPLASH]:
			continue
		var idx: Array = mid_index.get(pi, [])
		if idx.is_empty():
			continue
		var i: int = idx[idx.size() / 2]
		var xf := Transform3D(_frame(i), path_points[i])
		match p.type:
			Piece.BOOSTER:
				for k in 5:  # Antriebsräder / Linearmotor-Flossen zwischen den Schienen
					_deco_box(xf, Vector3(0, 0.08, -1.6 + k * 0.8), Vector3(0.18, 0.25, 0.5), Color(0.95, 0.6, 0.2))
			Piece.BRAKE:
				for k in 4:
					for x in [-0.25, 0.25]:
						_deco_box(xf, Vector3(x, 0.1, -1.5 + k * 1.0), Vector3(0.06, 0.3, 0.8), Color(0.8, 0.25, 0.2))
			Piece.TUNNEL:
				var tun := Color(0.36, 0.37, 0.4)
				for x in [-1.9, 1.9]:
					_deco_box(xf, Vector3(x, 1.5, 0), Vector3(0.3, 3.4, TILE), tun)
				_deco_box(xf, Vector3(0, 3.35, 0), Vector3(4.1, 0.4, TILE), tun)
				_deco_box(xf, Vector3(0, 4.0, 0), Vector3(5.5, 1.0, TILE), Color(0.35, 0.55, 0.28))
			Piece.SPLASH:
				var water := _mat(Color(0.25, 0.55, 0.9, 0.75))
				water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_deco_box(xf, Vector3(0, 0.05, 0), Vector3(5.0, 0.35, TILE), Color(), water)
				for x in [-2.6, 2.6]:
					_deco_box(xf, Vector3(x, 0.0, 0), Vector3(0.3, 0.6, TILE), Color(0.55, 0.55, 0.58))


func _deco_box(xf: Transform3D, local_pos: Vector3, size: Vector3, color: Color, mat: Material = null) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = mat if mat != null else _mat(color)
	mi.mesh = b
	mi.transform = Transform3D(xf.basis, xf * local_pos)
	_special_deco.add_child(mi)

class_name CoasterTrain
extends Node3D
## Zug aus mehreren Wagen mit Fahrgästen (Greybox). Die Wagen folgen der
## Strecke im festen Abstand hinter dem ersten Wagen. Fahrgäste reißen bei hohem
## Tempo, in steilen Abfahrten und kopfüber die Arme hoch.
##
## Für wenige Draw Calls wird jeder Wagen, jeder Fahrgast-Körper und jedes
## Arm-Paar als ein einziges Mesh mit Vertex-Farben gebaut.

const CAR_COUNT := 3
const CAR_SPACING := 2.7          # Abstand der Wagenmitten entlang der Strecke (m)
const ROWS := [-0.45, 0.6]        # Sitzreihen (lokales z, vorne negativ)
const SEATS := [-0.36, 0.36]      # Sitzplätze links/rechts (lokales x)
const EYE_HEIGHT := 1.72
const ARM_REST := 60.0            # Arme am Bügel (Grad nach vorn)
const ARM_UP := 165.0             # Arme hochgerissen

const BODY := Color(0.85, 0.85, 0.87)
const DARK := Color(0.3, 0.3, 0.32)
const WHEEL := Color(0.2, 0.2, 0.22)
const SKIN := Color(0.9, 0.85, 0.8)

var cars: Array[Node3D] = []
var _riders: Array[Dictionary] = []
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.9
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for ci in CAR_COUNT:
		var car := Node3D.new()
		add_child(car)
		cars.append(car)
		var st := _begin()
		_box(st, Vector3(1.5, 0.5, 2.3), Vector3(0, 0.55, 0), BODY)          # Wanne
		_box(st, Vector3(0.12, 0.3, 2.3), Vector3(-0.72, 0.95, 0), BODY)    # Seitenwände
		_box(st, Vector3(0.12, 0.3, 2.3), Vector3(0.72, 0.95, 0), BODY)
		for z in [-0.9, 0.9]:  # Fahrwerk
			_box(st, Vector3(1.3, 0.25, 0.35), Vector3(0, 0.2, z), WHEEL)
		if ci == 0:
			_box(st, Vector3(1.5, 0.5, 0.45), Vector3(0, 0.65, -1.3), DARK)  # Bug
		else:
			_box(st, Vector3(0.3, 0.2, 0.5), Vector3(0, 0.4, -1.3), WHEEL)   # Kupplung
		for z: float in ROWS:
			_box(st, Vector3(1.3, 0.5, 0.14), Vector3(0, 0.95, z + 0.38), DARK)  # Lehne
			_box(st, Vector3(1.3, 0.07, 0.07), Vector3(0, 1.0, z - 0.32), DARK)  # Bügel
		car.add_child(_commit(st))
		for row in ROWS.size():
			for seat in SEATS.size():
				_riders.append(_make_rider(car, ci, row, seat, rng))


func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _commit(st: SurfaceTool, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _material
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Quader mit flachen Normalen und Vertex-Farbe.
func _box(st: SurfaceTool, size: Vector3, pos: Vector3, color: Color) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	st.set_color(color)
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := pos + n * h
		var du := u * h
		var dv := v * h
		var q := [c - du - dv, c - du + dv, c + du + dv, c + du - dv]
		st.set_normal(n)
		for idx in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(q[idx])


## Grobe Kugel (für Köpfe).
func _sphere(st: SurfaceTool, r: float, pos: Vector3, color: Color) -> void:
	st.set_color(color)
	var rings := 5
	var segs := 8
	for i in rings:
		for j in segs:
			var pts := []
			for k in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var th := PI * float(k[0]) / rings
				var ph := TAU * float(k[1]) / segs
				pts.append(Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)))
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_normal(pts[idx])
				st.add_vertex(pos + pts[idx] * r)


func _make_rider(car: Node3D, ci: int, row: int, seat: int, rng: RandomNumberGenerator) -> Dictionary:
	var root := Node3D.new()
	root.position = Vector3(SEATS[seat], 0.75, ROWS[row] + 0.1)
	car.add_child(root)
	var shade := rng.randf_range(0.35, 0.75)
	var shirt := Color(shade, shade, shade + 0.04)
	var st := _begin()
	_box(st, Vector3(0.34, 0.5, 0.22), Vector3(0, 0.4, 0), shirt)   # Oberkörper
	_sphere(st, 0.13, Vector3(0, 0.82, 0), SKIN)                    # Kopf
	root.add_child(_commit(st))
	var pivot := Node3D.new()                                       # Schulterachse
	pivot.position = Vector3(0, 0.6, 0)
	root.add_child(pivot)
	var arms := _begin()
	for side in [-1.0, 1.0]:
		_box(arms, Vector3(0.09, 0.46, 0.09), Vector3(side * 0.22, -0.23, 0), shirt)
	pivot.add_child(_commit(arms, false))
	pivot.rotation_degrees.x = ARM_REST
	return {
		"root": root, "arms": pivot, "car": ci, "row": row, "seat": seat,
		"angle": ARM_REST, "excite": rng.randf_range(0.0, 1.0),
	}


## Setzt alle Wagen hinter die Bogenlänge s (erster Wagen bei s).
func place(track: CoasterTrack, s: float) -> void:
	for i in cars.size():
		var smp := track.sample(s - i * CAR_SPACING)
		cars[i].global_transform = Transform3D(CoasterTrack.frame_basis(smp.tangent, smp.up), smp.pos)


## Mittlere Steigung (dy/ds) über alle Wagen – der ganze Zug zieht bzw. bremst.
func mean_slope(track: CoasterTrack, s: float) -> float:
	var acc := 0.0
	for i in cars.size():
		acc += track.sample(s - i * CAR_SPACING).tangent.y
	return acc / cars.size()


## Eine Abfrage pro Wagen für die Physik: mittlere Steigung und ob ein Wagen
## im Kettenlift hängt.
func probe(track: CoasterTrack, s: float) -> Dictionary:
	var slope := 0.0
	var on_lift := false
	for i in cars.size():
		var smp := track.sample(s - i * CAR_SPACING)
		slope += smp.tangent.y
		on_lift = on_lift or CoasterTrack.is_lift(track.pieces[smp.piece].type)
	return {"slope": slope / cars.size(), "on_lift": on_lift}


## Liegt irgendein Wagen auf einem Teil der angegebenen Typen?
func any_on(track: CoasterTrack, s: float, types: Array) -> bool:
	for i in cars.size():
		var smp := track.sample(s - i * CAR_SPACING)
		if track.pieces[smp.piece].type in types:
			return true
	return false


## Kamera-Transform (global) für einen Sitzplatz – Augenhöhe des Fahrgasts.
func eye_transform(car: int, row: int, seat: int) -> Transform3D:
	var local := Transform3D(Basis.IDENTITY, Vector3(SEATS[seat], EYE_HEIGHT, ROWS[row] + 0.05))
	return cars[car].global_transform * local


## Blendet den Fahrgast aus, auf dessen Platz die Kamera sitzt (car = -1: keiner).
func hide_rider_at(car: int, row: int, seat: int) -> void:
	for r in _riders:
		r.root.visible = not (car >= 0 and r.car == car and r.row == row and r.seat == seat)


func animate(delta: float, speed: float, drop: bool) -> void:
	var k := 1.0 - exp(-6.0 * delta)
	for r in _riders:
		var car: Node3D = cars[r.car]
		var inverted := car.global_basis.y.y < 0.2
		var wild: bool = inverted or drop or speed > 12.0 + 8.0 * (1.0 - r.excite)
		r.angle = lerpf(r.angle, ARM_UP if wild else ARM_REST, k)
		r.arms.rotation_degrees.x = r.angle

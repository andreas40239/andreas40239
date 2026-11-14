class_name MeshKit
extends RefCounted
## Kleiner Baukasten für prozedurale Low-Poly-Meshes mit Vertex-Farben.
## Alle Modelle des Spiels (Häuser, Bäume, Züge, Gleise ...) entstehen hiermit im Code.

class Surf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()

var _surfs: Dictionary = {}
var _order: Array[String] = []
var _cur: Surf
var _xf := Transform3D.IDENTITY
var _stack: Array[Transform3D] = []


func _init() -> void:
	use("main")


## Wählt die Oberfläche (= Material), in die folgende Geometrie geschrieben wird.
func use(surface: String) -> MeshKit:
	if not _surfs.has(surface):
		_surfs[surface] = Surf.new()
		_order.append(surface)
	_cur = _surfs[surface]
	return self


func push(t: Transform3D) -> void:
	_stack.append(_xf)
	_xf = _xf * t


func push_at(pos: Vector3, yaw_deg: float = 0.0, scale: Vector3 = Vector3.ONE) -> void:
	var b := Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(scale)
	push(Transform3D(b, pos))


func pop() -> void:
	_xf = _stack.pop_back()


func is_empty() -> bool:
	for s in _surfs.values():
		if (s as Surf).v.size() > 0:
			return false
	return true


# ---------------------------------------------------------------- Grundformen

## Dreieck; die Orientierung wird über `out_hint` (zeigt nach außen) korrigiert.
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, out_hint: Vector3 = Vector3.ZERO) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if out_hint != Vector3.ZERO and n.dot(out_hint) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	var wn := (_xf.basis.inverse().transposed() * n).normalized()
	_cur.v.append(_xf * a); _cur.v.append(_xf * b); _cur.v.append(_xf * c)
	_cur.n.append(wn); _cur.n.append(wn); _cur.n.append(wn)
	_cur.c.append(col); _cur.c.append(col); _cur.c.append(col)


## Dreieck mit eigenen Normalen und Farben pro Ecke (für weiche Flächen).
func tri_smooth(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		ca: Color, cb: Color, cc: Color) -> void:
	var fn := (c - a).cross(b - a)
	if fn.length_squared() < 1e-12:
		return
	if fn.dot(na + nb + nc) < 0.0:
		var t := b; b = c; c = t
		var tn := nb; nb = nc; nc = tn
		var tc := cb; cb = cc; cc = tc
	var nb3 := _xf.basis.inverse().transposed()
	_cur.v.append(_xf * a); _cur.v.append(_xf * b); _cur.v.append(_xf * c)
	_cur.n.append((nb3 * na).normalized()); _cur.n.append((nb3 * nb).normalized()); _cur.n.append((nb3 * nc).normalized())
	_cur.c.append(ca); _cur.c.append(cb); _cur.c.append(cc)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, out_hint: Vector3 = Vector3.ZERO) -> void:
	tri(a, b, c, col, out_hint)
	tri(a, c, d, col, out_hint)


## Viereck mit Farbverlauf (a,b = col1; c,d = col2).
func quad_grad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col1: Color, col2: Color, out_hint: Vector3) -> void:
	var n := (c - a).cross(b - a).normalized()
	if n.dot(out_hint) < 0.0:
		n = -n
	tri_smooth(a, b, c, n, n, n, col1, col1, col2)
	tri_smooth(a, c, d, n, n, n, col1, col2, col2)


## Quader. `shade` dunkelt die Unterkante der Seitenflächen leicht ab (Pseudo-AO).
func box(size: Vector3, center: Vector3, col: Color, basis: Basis = Basis.IDENTITY, shade: float = 0.0) -> void:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				p.append(center + basis * Vector3(sx * h.x, sy * h.y, sz * h.z))
	# Index = sx*4 + sy*2 + sz
	var faces := [
		[0, 1, 3, 2, Vector3.LEFT], [4, 6, 7, 5, Vector3.RIGHT],
		[0, 4, 5, 1, Vector3.DOWN], [2, 3, 7, 6, Vector3.UP],
		[0, 2, 6, 4, Vector3.FORWARD], [1, 5, 7, 3, Vector3.BACK],
	]
	var dark := col.darkened(shade)
	for f in faces:
		var hint: Vector3 = basis * (f[4] as Vector3)
		if shade > 0.0 and absf((f[4] as Vector3).y) < 0.5:
			# Seitenfläche: unten dunkler
			var q: Array[Vector3] = [p[f[0]], p[f[1]], p[f[2]], p[f[3]]]
			var cols: Array[Color] = []
			for v in q:
				var ly := (basis.inverse() * (v - center)).y
				cols.append(dark if ly < 0.0 else col)
			var n := hint.normalized()
			tri_smooth(q[0], q[1], q[2], n, n, n, cols[0], cols[1], cols[2])
			tri_smooth(q[0], q[2], q[3], n, n, n, cols[0], cols[2], cols[3])
		else:
			quad(p[f[0]], p[f[1]], p[f[2]], p[f[3]], col, hint)


## Kegelstumpf/Zylinder entlang einer Achse. base = Mittelpunkt der Unterseite.
func cyl(r0: float, r1: float, h: float, base: Vector3, col: Color, segs: int = 10,
		axis: Vector3 = Vector3.UP, smooth: bool = true, caps: bool = true, col_top: Color = Color(-1, 0, 0)) -> void:
	axis = axis.normalized()
	var ref := Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK
	var u := axis.cross(ref).normalized()
	var w := axis.cross(u).normalized()
	var top := base + axis * h
	var ct := col if col_top.r < 0.0 else col_top
	var slope := (r0 - r1) / maxf(h, 1e-5)
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var d0 := u * cos(a0) + w * sin(a0)
		var d1 := u * cos(a1) + w * sin(a1)
		var b0 := base + d0 * r0
		var b1 := base + d1 * r0
		var t0 := top + d0 * r1
		var t1 := top + d1 * r1
		if smooth:
			var n0 := (d0 + axis * slope).normalized()
			var n1 := (d1 + axis * slope).normalized()
			if r1 > 1e-4:
				tri_smooth(b0, b1, t1, n0, n1, n1, col, col, ct)
				tri_smooth(b0, t1, t0, n0, n1, n0, col, ct, ct)
			else:
				tri_smooth(b0, b1, top, n0, n1, ((n0 + n1) * 0.5).normalized(), col, col, ct)
		else:
			var hint := (d0 + d1) * 0.5 + axis * slope
			if r1 > 1e-4:
				quad_grad(b0, b1, t1, t0, col, ct, hint)
			else:
				tri_smooth(b0, b1, top, hint, hint, hint, col, col, ct)
		if caps:
			if r0 > 1e-4:
				tri(base, b0, b1, col, -axis)
			if r1 > 1e-4:
				tri(top, t0, t1, ct, axis)


## Satteldach (Dreiecksprisma). Grundfläche w (x) × d (z), First entlang z.
func gable(w: float, d: float, h: float, base: Vector3, col: Color, basis: Basis = Basis.IDENTITY,
		gable_col: Color = Color(-1, 0, 0)) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var gc := col if gable_col.r < 0.0 else gable_col
	var a := base + basis * Vector3(-hw, 0, -hd)
	var b := base + basis * Vector3(hw, 0, -hd)
	var c := base + basis * Vector3(hw, 0, hd)
	var e := base + basis * Vector3(-hw, 0, hd)
	var r0 := base + basis * Vector3(0, h, -hd)
	var r1 := base + basis * Vector3(0, h, hd)
	quad(a, r0, r1, e, col, basis * Vector3(-h, hw, 0))
	quad(b, c, r1, r0, col, basis * Vector3(h, hw, 0))
	tri(a, b, r0, gc, basis * Vector3.FORWARD)
	tri(e, r1, c, gc, basis * Vector3.BACK)
	quad(a, e, c, b, col.darkened(0.3), basis * Vector3.DOWN)


## Walmdach (Pyramidenstumpf mit First).
func hip(w: float, d: float, h: float, ridge: float, base: Vector3, col: Color, basis: Basis = Basis.IDENTITY) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var hr := ridge * 0.5
	var a := base + basis * Vector3(-hw, 0, -hd)
	var b := base + basis * Vector3(hw, 0, -hd)
	var c := base + basis * Vector3(hw, 0, hd)
	var e := base + basis * Vector3(-hw, 0, hd)
	var r0 := base + basis * Vector3(0, h, -hr)
	var r1 := base + basis * Vector3(0, h, hr)
	quad(a, r0, r1, e, col, basis * Vector3(-1, 1, 0))
	quad(b, c, r1, r0, col, basis * Vector3(1, 1, 0))
	tri(a, b, r0, col.darkened(0.08), basis * Vector3(0, 1, -1))
	tri(e, r1, c, col.darkened(0.08), basis * Vector3(0, 1, 1))


## Low-Poly-Kugel (Ikosaeder, optional unterteilt und leicht verbeult).
func blob(radius: Vector3, center: Vector3, col: Color, subdiv: int = 1, jitter: float = 0.0,
		rng: RandomNumberGenerator = null, col_bottom: Color = Color(-1, 0, 0), smooth: bool = false) -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in verts.size():
		verts[i] = verts[i].normalized()
	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for _s in subdiv:
		var cache := {}
		var nf: Array = []
		for f in faces:
			var m: Array[int] = []
			for k in 3:
				var i0: int = f[k]
				var i1: int = f[(k + 1) % 3]
				var key := Vector2i(mini(i0, i1), maxi(i0, i1))
				if not cache.has(key):
					verts.append(((verts[i0] + verts[i1]) * 0.5).normalized())
					cache[key] = verts.size() - 1
				m.append(cache[key])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		faces = nf
	var pts: Array[Vector3] = []
	for v in verts:
		var k := 1.0
		if jitter > 0.0 and rng != null:
			k += rng.randf_range(-jitter, jitter)
		pts.append(center + Vector3(v.x * radius.x, v.y * radius.y, v.z * radius.z) * k)
	var cb := col if col_bottom.r < 0.0 else col_bottom
	for f in faces:
		var a := pts[f[0]]
		var b := pts[f[1]]
		var c := pts[f[2]]
		var colv: Array[Color] = []
		for p in [a, b, c]:
			var ky := clampf(((p as Vector3).y - center.y) / maxf(radius.y, 1e-4) * 0.5 + 0.5, 0.0, 1.0)
			colv.append(cb.lerp(col, ky))
		if smooth:
			tri_smooth(a, b, c, (a - center).normalized(), (b - center).normalized(), (c - center).normalized(),
				colv[0], colv[1], colv[2])
		else:
			var n := ((a + b + c) / 3.0 - center).normalized()
			var fn := (c - a).cross(b - a).normalized()
			if fn.dot(n) < 0.0:
				fn = -fn
			tri_smooth(a, b, c, fn, fn, fn, colv[0], colv[1], colv[2])


## Zieht ein geschlossenes 2D-Profil (x = rechts, y = oben) entlang eines Pfades.
## path: Array von [Position, Tangente].
func extrude(profile: PackedVector2Array, path: Array, col: Color, caps: bool = true) -> void:
	var rings: Array = []
	for st in path:
		var p: Vector3 = st[0]
		var tg: Vector3 = (st[1] as Vector3).normalized()
		var right := tg.cross(Vector3.UP).normalized()
		var ring: Array[Vector3] = []
		for q in profile:
			ring.append(p + right * q.x + Vector3.UP * q.y)
		rings.append(ring)
	var cnt := profile.size()
	var pc := Vector2.ZERO
	for q in profile:
		pc += q
	pc /= cnt
	for i in rings.size() - 1:
		var r0: Array[Vector3] = rings[i]
		var r1: Array[Vector3] = rings[i + 1]
		var p0: Vector3 = path[i][0]
		var tg0: Vector3 = (path[i][1] as Vector3).normalized()
		var right0 := tg0.cross(Vector3.UP).normalized()
		var mid := p0 + right0 * pc.x + Vector3.UP * pc.y
		for k in cnt:
			var k2 := (k + 1) % cnt
			var fc := (r0[k] + r0[k2] + r1[k] + r1[k2]) * 0.25
			var mid2 := (mid + ((path[i + 1][0] as Vector3) + right0 * pc.x + Vector3.UP * pc.y)) * 0.5
			quad(r0[k], r0[k2], r1[k2], r1[k], col, fc - mid2)
	if caps and rings.size() > 1:
		for e in [0, rings.size() - 1]:
			var r: Array[Vector3] = rings[e]
			var tg: Vector3 = (path[e][1] as Vector3).normalized()
			var hint := -tg if e == 0 else tg
			for k in range(1, cnt - 1):
				tri(r[0], r[k], r[k + 1], col, hint)


# ---------------------------------------------------------------- Ausgabe

func build(materials: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for sname in _order:
		var s: Surf = _surfs[sname]
		if s.v.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s.v
		arr[Mesh.ARRAY_NORMAL] = s.n
		arr[Mesh.ARRAY_COLOR] = s.c
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		if materials.has(sname):
			mesh.surface_set_material(mesh.get_surface_count() - 1, materials[sname])
	return mesh


func instance(materials: Dictionary, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = build(materials)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

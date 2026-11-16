class_name MeshBatch
extends RefCounted
## Sammelt viele Quader und baut daraus ein einziges Mesh je Material
## (wenige Draw-Calls – wichtig für Mobilgeräte).

var _data := {}   # Material -> {v, n, uv, idx}


func add_box(mat: Material, center: Vector3, size: Vector3, yaw := 0.0, uv_scale := 0.5) -> void:
	if not _data.has(mat):
		_data[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(),
			"uv": PackedVector2Array(), "idx": PackedInt32Array()}
	var d: Dictionary = _data[mat]
	var basis := Basis(Vector3.UP, yaw)
	var hs := size * 0.5
	# je Fläche: Normale, u-Achse, v-Achse (u x v = n)
	var faces := [
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var base: int = d.v.size()
		var corners := [-u - v, u - v, u + v, -u + v]
		for c in corners:
			var lp: Vector3 = (n + c) * hs
			var wp: Vector3 = center + basis * lp
			d.v.append(wp)
			d.n.append(basis * n)
			# planare Welt-UVs, damit Texturen über Flächen hinweg kacheln
			var uu: float = (lp.dot(u.abs()) + center.dot(u.abs())) * uv_scale
			var vv: float = (lp.dot(v.abs()) + center.dot(v.abs())) * uv_scale
			d.uv.append(Vector2(uu, -vv))
		d.idx.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


func is_empty() -> bool:
	return _data.is_empty()


func build(node_name := "Batch") -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for mat in _data:
		var d: Dictionary = _data[mat]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = d.v
		arr[Mesh.ARRAY_NORMAL] = d.n
		arr[Mesh.ARRAY_TEX_UV] = d.uv
		arr[Mesh.ARRAY_INDEX] = d.idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	return mi

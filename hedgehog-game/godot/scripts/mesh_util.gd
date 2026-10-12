class_name MeshUtil
extends RefCounted
## Helpers for building grey-box visuals out of primitive meshes.


static func material(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func add(parent: Node3D, mesh: PrimitiveMesh, color: Color, pos := Vector3.ZERO,
		scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	mesh.material = material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scl
	instance.rotation = rot
	parent.add_child(instance)
	return instance


static func sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	return mesh


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 16
	return mesh


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh


## Adds a cone pointing along `normal`, e.g. a hedgehog spine.
static func add_spike(parent: Node3D, base: Vector3, normal: Vector3, length: float,
		color: Color) -> MeshInstance3D:
	var spike := add(parent, cylinder(0.0, length * 0.28, length), color)
	spike.quaternion = Quaternion(Vector3.UP, normal.normalized())
	spike.position = base + normal.normalized() * length * 0.5
	return spike


## Evenly spread directions on a unit sphere (Fibonacci lattice).
static func sphere_points(count: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var golden := PI * (3.0 - sqrt(5.0))
	for i in count:
		var y := 1.0 - (i + 0.5) / count * 2.0
		var r := sqrt(1.0 - y * y)
		var theta := golden * i
		points.append(Vector3(cos(theta) * r, y, sin(theta) * r))
	return points


## Merges every visible MeshInstance3D below `root` into a single mesh that
## keeps each part's colour as a vertex colour, so the whole thing is one draw
## call instead of dozens. The original MeshInstance3Ds are freed; other nodes
## (bodies, collision shapes) are left alone. Nodes in `exclude` (and their
## children) are skipped. Returns the new MeshInstance3D, a child of `root`.
static func merge(root: Node3D, exclude: Array = [], alpha := 1.0) -> MeshInstance3D:
	var data := {
		"vertices": PackedVector3Array(), "normals": PackedVector3Array(),
		"colors": PackedColorArray(), "indices": PackedInt32Array(), "merged": [],
	}
	_collect(root, Transform3D.IDENTITY, exclude, data)
	for node in data["merged"]:
		node.get_parent().remove_child(node)
		node.queue_free()
	var instance := MeshInstance3D.new()
	instance.name = "Merged"
	if data["vertices"].is_empty():
		root.add_child(instance)
		return instance
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_COLOR] = data["colors"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		mat.albedo_color.a = alpha
	mesh.surface_set_material(0, mat)
	instance.mesh = mesh
	root.add_child(instance)
	return instance


static func _collect(node: Node, xform: Transform3D, exclude: Array, data: Dictionary) -> void:
	for child in node.get_children():
		if exclude.has(child) or not child is Node3D or not child.visible:
			continue
		var child_xform: Transform3D = xform * child.transform
		if child is MeshInstance3D and child.mesh and child.get_child_count() == 0:
			if _append(child, child_xform, data):
				data["merged"].append(child)
				continue
		_collect(child, child_xform, exclude, data)


static func _append(instance: MeshInstance3D, xform: Transform3D, data: Dictionary) -> bool:
	var mesh: Mesh = instance.mesh
	# Transparent parts keep their own material.
	for s in mesh.get_surface_count():
		var check := instance.get_active_material(s) as BaseMaterial3D
		if check and check.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return false
	var normal_basis := xform.basis.inverse().transposed()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var mat := instance.get_active_material(s) as BaseMaterial3D
		var color: Color = mat.albedo_color if mat else Color.WHITE
		var offset: int = data["vertices"].size()
		for i in vertices.size():
			data["vertices"].append(xform * vertices[i])
			data["normals"].append((normal_basis * normals[i]).normalized())
			data["colors"].append(color)
		if indices.is_empty():
			for i in vertices.size():
				data["indices"].append(offset + i)
		else:
			for index in indices:
				data["indices"].append(offset + index)
	return true

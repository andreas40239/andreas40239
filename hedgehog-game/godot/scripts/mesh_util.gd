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

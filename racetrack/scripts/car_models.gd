class_name CarModels
## Greybox-Modelle aus Grundkoerpern. Ursprung = Boden, -Z = vorne.
## Das Modell speichert seine 4 Rad-Knoten (VL, VR, HL, HR) als Meta "wheels".

static var _mats := {}


static func _mat(c: Color, emissive := false) -> StandardMaterial3D:
	var key := c.to_html() + str(emissive)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.55
	if emissive:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.5
	_mats[key] = m
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO, emissive := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col, emissive)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, col: Color, rot := Vector3.ZERO, seg := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _mat(col)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, r: float, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _mat(col)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _wheel(parent: Node3D, r: float, w: float, rim: Color, side: float) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var tyre := Color(0.08, 0.08, 0.09)
	_cyl(n, r, w, Vector3.ZERO, tyre, Vector3(0, 0, PI * 0.5), 16)
	_cyl(n, r * 0.62, w * 1.04, Vector3(side * 0.01, 0, 0), rim, Vector3(0, 0, PI * 0.5), 10)
	# Speiche, damit die Drehung sichtbar ist
	_box(n, Vector3(w * 1.08, r * 1.15, r * 0.18), Vector3.ZERO, rim.darkened(0.45))
	return n


static func build(type: int) -> Node3D:
	var root := Node3D.new()
	var cfg: Dictionary = Car.CONFIGS[type]
	var r: float = cfg["radius"]
	var ww: float = cfg["wheel_w"]
	var wheels := []
	var rim := Color(0.75, 0.75, 0.78)
	match type:
		Car.KART:
			rim = Color(0.9, 0.75, 0.1)
			var blue := Color(0.1, 0.35, 0.9)
			_box(root, Vector3(0.8, 0.05, 1.45), Vector3(0, 0.1, 0), Color(0.25, 0.25, 0.27))
			_box(root, Vector3(0.16, 0.14, 0.7), Vector3(-0.42, 0.17, 0.0), blue)
			_box(root, Vector3(0.16, 0.14, 0.7), Vector3(0.42, 0.17, 0.0), blue)
			_box(root, Vector3(0.7, 0.14, 0.28), Vector3(0, 0.17, -0.8), blue, Vector3(0.25, 0, 0))
			_box(root, Vector3(0.36, 0.1, 0.06), Vector3(0, 0.27, -0.94), Color(0.95, 0.95, 0.95))
			_box(root, Vector3(1.05, 0.1, 0.1), Vector3(0, 0.2, 0.86), Color(0.3, 0.3, 0.3))
			_box(root, Vector3(0.4, 0.38, 0.3), Vector3(0, 0.3, 0.22), Color(0.1, 0.1, 0.1), Vector3(-0.25, 0, 0))
			_box(root, Vector3(0.26, 0.24, 0.32), Vector3(0.28, 0.26, 0.48), Color(0.7, 0.7, 0.72))
			_cyl(root, 0.05, 0.3, Vector3(0.28, 0.26, 0.72), Color(0.4, 0.4, 0.4), Vector3(PI * 0.5, 0, 0))
			# Fahrer
			_box(root, Vector3(0.36, 0.44, 0.26), Vector3(0, 0.58, 0.14), Color(0.9, 0.15, 0.1), Vector3(-0.2, 0, 0))
			_box(root, Vector3(0.1, 0.1, 0.4), Vector3(-0.17, 0.55, -0.12), Color(0.9, 0.15, 0.1), Vector3(0.6, 0, 0))
			_box(root, Vector3(0.1, 0.1, 0.4), Vector3(0.17, 0.55, -0.12), Color(0.9, 0.15, 0.1), Vector3(0.6, 0, 0))
			_sphere(root, 0.16, Vector3(0, 0.92, 0.08), Color(1.0, 0.85, 0.1))
			_box(root, Vector3(0.24, 0.08, 0.05), Vector3(0, 0.93, -0.07), Color(0.05, 0.05, 0.08))
			var sw := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.1
			tm.outer_radius = 0.13
			tm.rings = 12
			tm.ring_segments = 6
			sw.mesh = tm
			sw.material_override = _mat(Color(0.1, 0.1, 0.1))
			sw.position = Vector3(0, 0.5, -0.3)
			sw.rotation = Vector3(PI * 0.5 - 0.5, 0, 0)
			root.add_child(sw)
		Car.RACER:
			var red := Color(0.85, 0.05, 0.04)
			var black := Color(0.06, 0.06, 0.07)
			_box(root, Vector3(1.85, 0.4, 4.3), Vector3(0, 0.48, 0), red)
			_box(root, Vector3(1.75, 0.18, 1.4), Vector3(0, 0.66, -1.45), red, Vector3(-0.08, 0, 0))
			_box(root, Vector3(1.6, 0.22, 0.5), Vector3(0, 0.42, -2.2), red, Vector3(-0.25, 0, 0))
			_box(root, Vector3(1.3, 0.42, 1.6), Vector3(0, 0.88, 0.15), Color(0.12, 0.14, 0.18), Vector3(0.0, 0, 0))
			_box(root, Vector3(1.22, 0.08, 1.0), Vector3(0, 1.12, 0.25), red)
			_box(root, Vector3(1.9, 0.3, 1.2), Vector3(0, 0.78, 1.45), red, Vector3(0.06, 0, 0))
			_box(root, Vector3(0.12, 0.25, 0.8), Vector3(-0.94, 0.55, 0.5), black)
			_box(root, Vector3(0.12, 0.25, 0.8), Vector3(0.94, 0.55, 0.5), black)
			_box(root, Vector3(2.0, 0.05, 0.45), Vector3(0, 0.22, -2.25), black)
			_box(root, Vector3(2.0, 0.07, 0.5), Vector3(0, 1.28, 2.0), black)
			_box(root, Vector3(0.07, 0.4, 0.25), Vector3(-0.6, 1.05, 2.0), black)
			_box(root, Vector3(0.07, 0.4, 0.25), Vector3(0.6, 1.05, 2.0), black)
			_box(root, Vector3(0.4, 0.1, 0.05), Vector3(-0.6, 0.6, -2.42), Color(1, 0.95, 0.7), Vector3.ZERO, true)
			_box(root, Vector3(0.4, 0.1, 0.05), Vector3(0.6, 0.6, -2.42), Color(1, 0.95, 0.7), Vector3.ZERO, true)
			_box(root, Vector3(0.35, 0.12, 0.05), Vector3(-0.6, 0.62, 2.16), Color(1, 0.1, 0.05), Vector3.ZERO, true)
			_box(root, Vector3(0.35, 0.12, 0.05), Vector3(0.6, 0.62, 2.16), Color(1, 0.1, 0.05), Vector3.ZERO, true)
			_box(root, Vector3(0.22, 0.28, 0.04), Vector3(0, 0.72, -1.9), Color(1.0, 0.85, 0.0), Vector3(-0.08, 0, 0))
			_cyl(root, 0.06, 0.2, Vector3(-0.3, 0.42, 2.2), Color(0.5, 0.5, 0.5), Vector3(PI * 0.5, 0, 0))
			_cyl(root, 0.06, 0.2, Vector3(0.3, 0.42, 2.2), Color(0.5, 0.5, 0.5), Vector3(PI * 0.5, 0, 0))
		Car.TRUCK:
			rim = Color(0.95, 0.75, 0.1)
			var body := Color(0.15, 0.62, 0.2)
			var dark := Color(0.2, 0.2, 0.22)
			_box(root, Vector3(1.3, 0.3, 3.8), Vector3(0, 1.05, 0), dark)
			_cyl(root, 0.12, 2.4, Vector3(0, 0.9, -1.5), dark, Vector3(0, 0, PI * 0.5))
			_cyl(root, 0.12, 2.4, Vector3(0, 0.9, 1.5), dark, Vector3(0, 0, PI * 0.5))
			for z in [-1.5, 1.5]:
				for x in [-0.7, 0.7]:
					_cyl(root, 0.09, 0.9, Vector3(x, 1.35, z), Color(0.9, 0.3, 0.1), Vector3(0, 0, x * 0.5))
			_box(root, Vector3(2.4, 0.75, 4.1), Vector3(0, 1.75, 0), body)
			_box(root, Vector3(2.2, 0.85, 1.6), Vector3(0, 2.55, -0.1), body)
			_box(root, Vector3(2.0, 0.55, 0.05), Vector3(0, 2.6, -0.92), Color(0.15, 0.2, 0.28), Vector3(-0.15, 0, 0))
			_box(root, Vector3(2.24, 0.5, 1.0), Vector3(0, 2.62, -0.05), Color(0.15, 0.2, 0.28))
			_box(root, Vector3(2.4, 0.5, 0.1), Vector3(0, 2.35, 2.0), body)
			_box(root, Vector3(0.1, 0.5, 1.4), Vector3(-1.15, 2.35, 1.3), body)
			_box(root, Vector3(0.1, 0.5, 1.4), Vector3(1.15, 2.35, 1.3), body)
			_box(root, Vector3(0.1, 1.0, 0.1), Vector3(-1.0, 2.9, 0.9), Color(0.85, 0.85, 0.85))
			_box(root, Vector3(0.1, 1.0, 0.1), Vector3(1.0, 2.9, 0.9), Color(0.85, 0.85, 0.85))
			_box(root, Vector3(2.1, 0.1, 0.1), Vector3(0, 3.4, 0.9), Color(0.85, 0.85, 0.85))
			for x in [-0.6, -0.2, 0.2, 0.6]:
				_box(root, Vector3(0.25, 0.18, 0.12), Vector3(x, 3.08, -0.5), Color(1.0, 0.95, 0.5), Vector3.ZERO, true)
			_box(root, Vector3(2.5, 0.25, 0.2), Vector3(0, 1.45, -2.12), Color(0.8, 0.8, 0.82))
			_box(root, Vector3(0.4, 0.15, 0.05), Vector3(-0.8, 1.9, -2.07), Color(1, 0.95, 0.7), Vector3.ZERO, true)
			_box(root, Vector3(0.4, 0.15, 0.05), Vector3(0.8, 1.9, -2.07), Color(1, 0.95, 0.7), Vector3.ZERO, true)
			_box(root, Vector3(0.4, 0.15, 0.05), Vector3(-0.8, 1.9, 2.07), Color(1, 0.1, 0.05), Vector3.ZERO, true)
			_box(root, Vector3(0.4, 0.15, 0.05), Vector3(0.8, 1.9, 2.07), Color(1, 0.1, 0.05), Vector3.ZERO, true)
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		wheels.append(_wheel(root, r, ww, rim, side))
	root.set_meta("wheels", wheels)
	return root

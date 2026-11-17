class_name Props
## Kleine 3D-Objekte aus Grundformen: Upgrades, Melonen-Matsch, Glassplitter.


static func _mat(c: Color, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _box(parent: Node3D, m: Material, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func melon_mesh(radius := 0.2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.2
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	# Streifen über eine Verlaufstextur
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in 12:
		offs.append(i / 12.0)
		cols.append(Color(0.08, 0.32, 0.12) if i % 2 == 0 else Color(0.35, 0.62, 0.25))
	g.offsets = offs
	g.colors = cols
	var gt := GradientTexture1D.new()
	gt.gradient = g
	gt.width = 96
	m.albedo_texture = gt
	m.roughness = 0.35
	mi.material_override = m
	return mi


static func garlic() -> Node3D:
	var n := Node3D.new()
	var white := _mat(Color(0.95, 0.93, 0.85), 0.5)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.17
	sm.height = 0.28
	sm.radial_segments = 10
	sm.rings = 6
	bulb.mesh = sm
	bulb.material_override = white
	bulb.position.y = 0.14
	n.add_child(bulb)
	# Zehen andeuten
	var purple := _mat(Color(0.8, 0.7, 0.85), 0.5)
	for i in 5:
		var a := i * TAU / 5.0
		var clove := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = 0.075
		cm.height = 0.22
		cm.radial_segments = 6
		cm.rings = 4
		clove.mesh = cm
		clove.material_override = purple if i % 2 == 0 else white
		clove.position = Vector3(cos(a) * 0.11, 0.13, sin(a) * 0.11)
		n.add_child(clove)
	_box(n, _mat(Color(0.75, 0.7, 0.5)), Vector3(0, 0.32, 0), Vector3(0.05, 0.14, 0.05))
	_box(n, _mat(Color(0.4, 0.6, 0.25)), Vector3(0.02, 0.42, 0), Vector3(0.03, 0.12, 0.03), Vector3(0, 0, -0.4))
	return n


static func souvlaki() -> Node3D:
	var n := Node3D.new()
	var tilt := Node3D.new()
	tilt.rotation = Vector3(0, 0, 0.9)
	tilt.position.y = 0.24
	n.add_child(tilt)
	_box(tilt, _mat(Color(0.8, 0.65, 0.4)), Vector3.ZERO, Vector3(0.025, 0.72, 0.025))
	var meat := _mat(Color(0.55, 0.3, 0.15), 0.6)
	var meat2 := _mat(Color(0.68, 0.4, 0.18), 0.6)
	var pepper := _mat(Color(0.25, 0.6, 0.2), 0.4)
	var tomato := _mat(Color(0.8, 0.15, 0.1), 0.4)
	var seq := [meat, pepper, meat2, tomato, meat, meat2]
	for i in seq.size():
		var s := 0.1 if seq[i] == meat or seq[i] == meat2 else 0.085
		_box(tilt, seq[i], Vector3(0, -0.2 + i * 0.095, 0), Vector3(s, 0.085, s), Vector3(0, i * 0.5, 0))
	return n


## Flasche Olivenöl.
static func oil_bottle() -> Node3D:
	var n := Node3D.new()
	var glass := _mat(Color(0.12, 0.32, 0.12), 0.15)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.1
	cm.height = 0.34
	cm.radial_segments = 10
	body.mesh = cm
	body.material_override = glass
	body.position.y = 0.17
	n.add_child(body)
	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.035
	nm.bottom_radius = 0.07
	nm.height = 0.16
	nm.radial_segments = 8
	neck.mesh = nm
	neck.material_override = glass
	neck.position.y = 0.42
	n.add_child(neck)
	_box(n, _mat(Color(0.75, 0.6, 0.35)), Vector3(0, 0.53, 0), Vector3(0.06, 0.07, 0.06))
	_box(n, _mat(Color(0.93, 0.88, 0.7)), Vector3(0, 0.18, 0.085), Vector3(0.13, 0.14, 0.04))
	_box(n, _mat(Color(0.3, 0.45, 0.15)), Vector3(0, 0.18, 0.108), Vector3(0.06, 0.05, 0.01))
	return n


## Glas Frappé mit Schaum und Strohhalm.
static func frappe() -> Node3D:
	var n := Node3D.new()
	var coffee := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.085
	cm.height = 0.3
	cm.radial_segments = 10
	coffee.mesh = cm
	coffee.material_override = _mat(Color(0.42, 0.26, 0.14), 0.2)
	coffee.position.y = 0.15
	n.add_child(coffee)
	var foam := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.105
	fm.bottom_radius = 0.102
	fm.height = 0.1
	fm.radial_segments = 10
	foam.mesh = fm
	foam.material_override = _mat(Color(0.93, 0.86, 0.72), 0.6)
	foam.position.y = 0.35
	n.add_child(foam)
	_box(n, _mat(Color(0.2, 0.5, 0.9)), Vector3(0.03, 0.42, 0), Vector3(0.025, 0.36, 0.025), Vector3(0, 0, -0.25))
	return n


static func pickup_model(kind: String) -> Node3D:
	match kind:
		"garlic":
			return garlic()
		"souvlaki":
			return souvlaki()
		"oil":
			return oil_bottle()
		"frappe":
			return frappe()
		_:
			var n := Node3D.new()
			var m := melon_mesh(0.2)
			m.position.y = 0.22
			n.add_child(m)
			return n


static func kind_color(kind: String) -> Color:
	match kind:
		"garlic": return Color(0.8, 1.0, 0.6)
		"souvlaki": return Color(1.0, 0.65, 0.2)
		"oil": return Color(0.55, 0.85, 0.3)
		"frappe": return Color(0.75, 0.55, 0.4)
		_: return Color(1.0, 0.35, 0.4)


static func kind_name(kind: String) -> String:
	match kind:
		"garlic": return "Knoblauch"
		"souvlaki": return "Souvlaki"
		"oil": return "Olivenöl"
		"frappe": return "Frappé"
		_: return "Wassermelone"


## Ölpfütze am Boden. Bewusst dunkel-oliv: kräftiges Gelb ist in der Zombie-Sicht
## für erkannte Menschen reserviert.
static func oil_puddle() -> Node3D:
	var n := Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.42, 0.1, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 0.9
	for i in 5:
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := Cfg.OIL_RADIUS if i == 0 else randf_range(0.25, 0.45)
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.012
		cm.radial_segments = 14
		disc.mesh = cm
		disc.material_override = m
		var a := randf() * TAU
		disc.position = Vector3.ZERO if i == 0 else Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 0.8)
		disc.position.y = 0.012 + i * 0.001
		n.add_child(disc)
	return n


## Zerplatzte Melone am Boden.
static func melon_splat() -> Node3D:
	var n := Node3D.new()
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.75
	cm.bottom_radius = 0.75
	cm.height = 0.02
	cm.radial_segments = 14
	disc.mesh = cm
	disc.material_override = _mat(Color(0.85, 0.12, 0.18), 0.3)
	disc.position.y = 0.015
	n.add_child(disc)
	var green := _mat(Color(0.12, 0.4, 0.15), 0.4)
	var red := _mat(Color(0.9, 0.2, 0.25), 0.4)
	var black := _mat(Color(0.05, 0.05, 0.05))
	for i in 9:
		var a := randf() * TAU
		var r := randf_range(0.15, 0.85)
		var p := Vector3(cos(a) * r, 0.06, sin(a) * r)
		_box(n, green if i % 3 != 0 else red, p, Vector3(0.22, 0.1, 0.16), Vector3(randf(), randf() * TAU, randf()))
	for i in 10:
		var a := randf() * TAU
		var r := randf_range(0.1, 0.7)
		_box(n, black, Vector3(cos(a) * r, 0.03, sin(a) * r), Vector3(0.035, 0.02, 0.05), Vector3(0, randf() * TAU, 0))
	return n


## Einmaliger Partikelstoß (Glas, Blut, Melone).
static func burst(color: Color, amount: int, speed: float, size: float, life := 0.9) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.0, 0)
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.3
	var bm := BoxMesh.new()
	bm.size = Vector3(size, size * 0.3, size)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = 0.4
	bm.material = m
	p.mesh = bm
	p.emitting = true
	return p

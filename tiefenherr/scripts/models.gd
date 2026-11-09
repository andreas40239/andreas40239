class_name Models
extends RefCounted
## Baut Kreaturen- und Heldenmodelle aus Grundkörpern (keine externen Assets nötig).

static var _mats := {}
static var _bar_shader: Shader


static func mat(c: Color, emit := 0.0, metal := 0.0, rough := 0.7) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(), emit, metal, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


static func _p(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, nm := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	if nm != "":
		mi.name = nm
	parent.add_child(mi)
	return mi


static func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


static func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 16
	c.rings = 4
	return c


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 12
	return c


static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func _pivot(parent: Node3D, nm: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	parent.add_child(n)
	return n


static func _eyes(root: Node3D, y: float, z: float, sep: float, c: Color, r := 0.035) -> void:
	_p(root, _sph(r), mat(c, 6.0), Vector3(-sep, y, z))
	_p(root, _sph(r), mat(c, 6.0), Vector3(sep, y, z))


static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	match kind:
		"imp":
			var skin := mat(Color(0.42, 0.45, 0.22), 0.0, 0.0, 0.8)
			_p(root, _cap(0.2, 0.55), skin, Vector3(0, 0.45, 0), Vector3(0.2, 0, 0))
			_p(root, _sph(0.19), skin, Vector3(0, 0.86, 0.04))
			_p(root, _cyl(0.0, 0.06, 0.28), skin, Vector3(-0.19, 0.95, 0), Vector3(0, 0, 1.1))
			_p(root, _cyl(0.0, 0.06, 0.28), skin, Vector3(0.19, 0.95, 0), Vector3(0, 0, -1.1))
			_eyes(root, 0.9, 0.2, 0.07, Color(1.0, 0.85, 0.2))
			_p(root, _cap(0.06, 0.3), skin, Vector3(-0.1, 0.12, 0))
			_p(root, _cap(0.06, 0.3), skin, Vector3(0.1, 0.12, 0))
			var tool := _pivot(root, "tool", Vector3(0.24, 0.6, 0.05))
			_p(tool, _box(0.04, 0.55, 0.04), mat(Color(0.35, 0.22, 0.12)), Vector3(0, 0.22, 0.05))
			_p(tool, _box(0.38, 0.06, 0.07), mat(Color(0.6, 0.6, 0.65), 0.0, 0.9, 0.3), Vector3(0, 0.48, 0.05))
			var sack := _p(root, _sph(0.17), mat(Color(0.9, 0.7, 0.2), 0.8, 0.6, 0.4), Vector3(0, 0.62, -0.24), Vector3.ZERO, Vector3.ONE, "sack")
			sack.visible = false
			root.scale = Vector3.ONE * 0.95
		"worm":
			var skin2 := mat(Color(0.35, 0.18, 0.32), 0.0, 0.1, 0.5)
			for k in 5:
				var r := 0.3 - k * 0.04
				_p(root, _sph(r), skin2, Vector3(0, r, -k * 0.32), Vector3.ZERO, Vector3.ONE, "seg%d" % k)
			_p(root, _sph(0.3), skin2, Vector3(0, 0.45, 0.15), Vector3.ZERO, Vector3.ONE, "head")
			_eyes(root, 0.55, 0.4, 0.1, Color(0.6, 1.0, 0.3), 0.05)
			_p(root, _cyl(0.0, 0.05, 0.2), mat(Color(0.9, 0.9, 0.8)), Vector3(-0.08, 0.32, 0.42), Vector3(1.6, 0, 0))
			_p(root, _cyl(0.0, 0.05, 0.2), mat(Color(0.9, 0.9, 0.8)), Vector3(0.08, 0.32, 0.42), Vector3(1.6, 0, 0))
		"bat":
			var fur := mat(Color(0.12, 0.1, 0.16), 0.0, 0.0, 0.9)
			_p(root, _sph(0.28), fur, Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1, 0.9, 1.3))
			_p(root, _sph(0.17), fur, Vector3(0, 0.45, 0.3))
			_p(root, _cyl(0.0, 0.07, 0.25), fur, Vector3(-0.1, 0.62, 0.3))
			_p(root, _cyl(0.0, 0.07, 0.25), fur, Vector3(0.1, 0.62, 0.3))
			_eyes(root, 0.48, 0.44, 0.07, Color(1.0, 0.15, 0.2), 0.04)
			var wl := _pivot(root, "wingL", Vector3(-0.2, 0.35, 0))
			_p(wl, _box(0.9, 0.03, 0.5), mat(Color(0.25, 0.12, 0.2), 0.0, 0.0, 0.6), Vector3(-0.45, 0, 0))
			var wr := _pivot(root, "wingR", Vector3(0.2, 0.35, 0))
			_p(wr, _box(0.9, 0.03, 0.5), mat(Color(0.25, 0.12, 0.2), 0.0, 0.0, 0.6), Vector3(0.45, 0, 0))
		"kobold":
			var skin3 := mat(Color(0.75, 0.28, 0.12), 0.0, 0.0, 0.6)
			_p(root, _cap(0.22, 0.65), skin3, Vector3(0, 0.55, 0))
			_p(root, _sph(0.2), skin3, Vector3(0, 1.02, 0.03))
			_p(root, _cyl(0.0, 0.05, 0.3), mat(Color(0.2, 0.15, 0.1)), Vector3(-0.12, 1.25, 0), Vector3(0, 0, 0.4))
			_p(root, _cyl(0.0, 0.05, 0.3), mat(Color(0.2, 0.15, 0.1)), Vector3(0.12, 1.25, 0), Vector3(0, 0, -0.4))
			_eyes(root, 1.05, 0.18, 0.07, Color(1.0, 0.95, 0.4))
			var tool2 := _pivot(root, "tool", Vector3(0.28, 0.75, 0.1))
			_p(tool2, _sph(0.13), mat(Color(1.0, 0.5, 0.1), 7.0), Vector3(0, 0.1, 0.12))
			var fl := OmniLight3D.new()
			fl.light_color = Color(1.0, 0.5, 0.15)
			fl.omni_range = 3.5
			fl.light_energy = 1.2
			fl.position = Vector3(0, 0.2, 0.15)
			tool2.add_child(fl)
			_p(root, _cap(0.07, 0.35), skin3, Vector3(-0.1, 0.15, 0))
			_p(root, _cap(0.07, 0.35), skin3, Vector3(0.1, 0.15, 0))
		"brute":
			var skin4 := mat(Color(0.35, 0.12, 0.1), 0.0, 0.0, 0.7)
			_p(root, _cap(0.42, 1.1), skin4, Vector3(0, 0.95, 0), Vector3(0.25, 0, 0))
			_p(root, _sph(0.3), skin4, Vector3(0, 1.6, 0.25))
			var horn := mat(Color(0.85, 0.8, 0.7), 0.0, 0.1, 0.4)
			_p(root, _cyl(0.0, 0.09, 0.55), horn, Vector3(-0.28, 1.82, 0.2), Vector3(0.3, 0, 0.9))
			_p(root, _cyl(0.0, 0.09, 0.55), horn, Vector3(0.28, 1.82, 0.2), Vector3(0.3, 0, -0.9))
			_eyes(root, 1.65, 0.52, 0.11, Color(1.0, 0.4, 0.1), 0.05)
			_p(root, _cap(0.14, 0.8), skin4, Vector3(-0.5, 0.95, 0.1), Vector3(0.3, 0, 0.2))
			var tool3 := _pivot(root, "tool", Vector3(0.5, 1.25, 0.1))
			_p(tool3, _cap(0.14, 0.8), skin4, Vector3(0, -0.3, 0))
			_p(tool3, _sph(0.2), skin4, Vector3(0, -0.72, 0.05))
			_p(root, _cap(0.16, 0.6), skin4, Vector3(-0.2, 0.3, 0))
			_p(root, _cap(0.16, 0.6), skin4, Vector3(0.2, 0.3, 0))
		"knight":
			var steel := mat(Color(0.7, 0.72, 0.78), 0.0, 0.85, 0.3)
			_p(root, _cap(0.25, 0.8), steel, Vector3(0, 0.75, 0))
			_p(root, _sph(0.21), steel, Vector3(0, 1.28, 0))
			_p(root, _box(0.3, 0.05, 0.05), mat(Color(0.1, 0.1, 0.12)), Vector3(0, 1.3, 0.2))
			_p(root, _cyl(0.0, 0.07, 0.35), mat(Color(0.8, 0.1, 0.1)), Vector3(0, 1.55, -0.05), Vector3(-0.4, 0, 0))
			_p(root, _box(0.5, 0.6, 0.06), mat(Color(0.15, 0.25, 0.6), 0.0, 0.4, 0.5), Vector3(-0.3, 0.8, 0.12), Vector3(0, 0.3, 0))
			_p(root, _sph(0.08), mat(Color(1.0, 0.85, 0.3), 1.0, 0.9, 0.3), Vector3(-0.32, 0.85, 0.17))
			var sw := _pivot(root, "tool", Vector3(0.3, 0.8, 0.1))
			_p(sw, _box(0.06, 0.85, 0.02), mat(Color(0.85, 0.88, 0.95), 0.3, 0.95, 0.15), Vector3(0, 0.45, 0.05))
			_p(sw, _box(0.25, 0.05, 0.05), mat(Color(0.6, 0.5, 0.2), 0.0, 0.8, 0.4), Vector3(0, 0.05, 0.05))
			_p(root, _cap(0.08, 0.45), steel, Vector3(-0.12, 0.2, 0))
			_p(root, _cap(0.08, 0.45), steel, Vector3(0.12, 0.2, 0))
		"archer":
			var cloak := mat(Color(0.18, 0.42, 0.2), 0.0, 0.0, 0.85)
			_p(root, _cyl(0.15, 0.32, 0.95), cloak, Vector3(0, 0.5, 0))
			_p(root, _sph(0.18), mat(Color(0.9, 0.75, 0.6)), Vector3(0, 1.15, 0))
			_p(root, _cyl(0.0, 0.22, 0.35), cloak, Vector3(0, 1.32, -0.02))
			var bow := _pivot(root, "tool", Vector3(-0.28, 0.85, 0.15))
			var tm := TorusMesh.new()
			tm.inner_radius = 0.42
			tm.outer_radius = 0.47
			_p(bow, tm, mat(Color(0.45, 0.28, 0.12)), Vector3(0, 0, 0), Vector3(0, 0, PI * 0.5), Vector3(1, 1, 0.35))
			_p(root, _cyl(0.06, 0.06, 0.5), mat(Color(0.4, 0.25, 0.12)), Vector3(0.12, 0.9, -0.22), Vector3(0.3, 0, 0))
		"priest":
			var robe := mat(Color(0.9, 0.88, 0.82), 0.0, 0.0, 0.8)
			_p(root, _cyl(0.14, 0.36, 1.05), robe, Vector3(0, 0.53, 0))
			_p(root, _sph(0.18), mat(Color(0.9, 0.75, 0.6)), Vector3(0, 1.2, 0))
			var halo := TorusMesh.new()
			halo.inner_radius = 0.18
			halo.outer_radius = 0.23
			_p(root, halo, mat(Color(1.0, 0.9, 0.4), 5.0), Vector3(0, 1.48, 0))
			var staff := _pivot(root, "tool", Vector3(0.3, 0.7, 0.1))
			_p(staff, _cyl(0.03, 0.03, 1.4), mat(Color(0.6, 0.45, 0.2), 0.0, 0.5, 0.4), Vector3(0, 0.2, 0))
			_p(staff, _sph(0.1), mat(Color(1.0, 0.95, 0.6), 6.0), Vector3(0, 0.95, 0))
		"dwarf":
			var tunic := mat(Color(0.5, 0.32, 0.15), 0.0, 0.0, 0.8)
			_p(root, _cap(0.28, 0.6), tunic, Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(1.15, 1, 1))
			_p(root, _sph(0.2), mat(Color(0.9, 0.72, 0.58)), Vector3(0, 0.9, 0))
			_p(root, _cyl(0.04, 0.2, 0.4), mat(Color(0.85, 0.45, 0.12)), Vector3(0, 0.72, 0.15), Vector3(-0.3, 0, 0))
			_p(root, _sph(0.21), mat(Color(0.6, 0.6, 0.62), 0.0, 0.9, 0.3), Vector3(0, 1.0, -0.02), Vector3.ZERO, Vector3(1, 0.6, 1))
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.85, 0.5)
			lamp.omni_range = 4.0
			lamp.light_energy = 1.0
			lamp.position = Vector3(0, 1.2, 0.2)
			root.add_child(lamp)
			var pk := _pivot(root, "tool", Vector3(0.3, 0.55, 0.05))
			_p(pk, _box(0.05, 0.65, 0.05), mat(Color(0.35, 0.22, 0.12)), Vector3(0, 0.28, 0.05))
			_p(pk, _box(0.5, 0.07, 0.08), mat(Color(0.6, 0.6, 0.65), 0.0, 0.9, 0.3), Vector3(0, 0.6, 0.05))
	return root


static func ring(team: int) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.66
	var c := Color(0.3, 1.0, 0.4) if team == 1 else Color(1.0, 0.3, 0.3)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.material_override = m
	mi.position = Vector3(0, 0.06, 0)
	mi.scale = Vector3(1, 0.3, 1)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func health_bar() -> MeshInstance3D:
	if _bar_shader == null:
		_bar_shader = Shader.new()
		_bar_shader.code = """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled;
instance uniform float fill = 1.0;
instance uniform vec4 bar_color : source_color = vec4(0.2, 0.9, 0.3, 1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec3 col = vec3(0.03);
	if (UV.x > 0.03 && UV.x < 0.97 && UV.y > 0.18 && UV.y < 0.82) {
		col = UV.x < fill ? bar_color.rgb : vec3(0.18, 0.02, 0.02);
	}
	ALBEDO = col;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _bar_shader
	sm.render_priority = 10
	var q := QuadMesh.new()
	q.size = Vector2(0.95, 0.13)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

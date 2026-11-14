class_name Mats
extends RefCounted
## Zentrale Material-Bibliothek. Fast alles nutzt Vertex-Farben, damit wenige
## Materialien (und damit wenige Draw-Calls) genügen.

static var _m: Dictionary = {}


static func all() -> Dictionary:
	if _m.is_empty():
		_build()
	return _m


static func get_mat(mat_name: String) -> Material:
	return all()[mat_name]


static func _vc(rough: float, metal: float = 0.0, spec: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = spec
	return m


static func _tri(m: StandardMaterial3D, tex_path: String, scale: float) -> StandardMaterial3D:
	m.albedo_texture = load(tex_path)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _build() -> void:
	_m["main"] = _vc(0.9, 0.0, 0.3)
	_m["gloss"] = _vc(0.35, 0.05, 0.6)
	_m["metal"] = _vc(0.32, 0.75, 0.6)
	_m["glass"] = _vc(0.08, 0.35, 0.9)

	var emit := StandardMaterial3D.new()
	emit.vertex_color_use_as_albedo = true
	emit.vertex_color_is_srgb = true
	emit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_m["emit"] = emit

	_m["ground"] = _tri(_vc(0.95, 0.0, 0.2), "res://assets/textures/grass.png", 0.085)
	_m["ballast"] = _tri(_vc(0.95, 0.0, 0.25), "res://assets/textures/gravel.png", 0.32)
	_m["road"] = _tri(_vc(0.85, 0.0, 0.3), "res://assets/textures/asphalt.png", 0.3)

	var water := ShaderMaterial.new()
	water.shader = load("res://scripts/water.gdshader")
	water.set_shader_parameter("noise_tex", load("res://assets/textures/water_noise.png"))
	_m["water"] = water

	# halbtransparente Markierungen (Zonen, Raster, Werkzeug-Hinweise)
	var ov := StandardMaterial3D.new()
	ov.vertex_color_use_as_albedo = true
	ov.vertex_color_is_srgb = true
	ov.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ov.cull_mode = BaseMaterial3D.CULL_DISABLED
	ov.render_priority = 1
	_m["overlay"] = ov

	var puff := StandardMaterial3D.new()
	puff.albedo_texture = load("res://assets/textures/puff.png")
	puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	puff.billboard_keep_scale = true
	puff.cull_mode = BaseMaterial3D.CULL_DISABLED
	_m["puff"] = puff

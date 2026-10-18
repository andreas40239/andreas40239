class_name Landscape
extends Node3D
## Himmel, Licht, Wiese, Spielfeldzaun, Baeume, Haeuser und feste Wolken.

var ground_material: ShaderMaterial
var sun: DirectionalLight3D


func _ready() -> void:
	_make_environment()
	_make_ground()
	_make_fence()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	_make_trees(rng)
	_make_houses(rng)
	_make_clouds(rng)


func set_grid_visible(v: bool) -> void:
	ground_material.set_shader_parameter("show_grid", v)


func _make_environment() -> void:
	var sky_shader := Shader.new()
	sky_shader.code = """
shader_type sky;
uniform vec3 bottom_color : source_color = vec3(0.07, 0.22, 0.62);
uniform vec3 top_color : source_color = vec3(0.62, 0.85, 1.0);
uniform vec3 sun_dir = vec3(0.4, 0.6, 0.5);
void sky() {
	float y = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 col = mix(bottom_color, top_color, pow(y, 0.55));
	float s = max(dot(normalize(EYEDIR), normalize(sun_dir)), 0.0);
	col += vec3(1.0, 0.95, 0.75) * (smoothstep(0.9993, 0.9997, s) + pow(s, 400.0) * 0.4);
	COLOR = col;
}
"""
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = sky_shader
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.8)
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-35), 0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_bias = 0.05
	add_child(sun)
	var to_sun := sun.global_transform.basis.z if sun.is_inside_tree() else sun.transform.basis.z
	sky_mat.set_shader_parameter("sun_dir", to_sun)


func _make_ground() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform bool show_grid = false;
uniform float tile = 12.0;
uniform float half_field = 144.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	vec3 grass = vec3(0.30, 0.58, 0.22);
	float inside = step(abs(p.x), half_field) * step(abs(p.y), half_field);
	vec2 cell = floor(p / tile);
	float chk = mod(cell.x + cell.y, 2.0);
	grass *= mix(1.0, 0.93 + 0.1 * chk, inside);
	grass *= mix(0.92, 1.0, inside);
	if (show_grid && inside > 0.5) {
		vec2 f = abs(fract(p / tile + 0.5) - 0.5) * tile;
		float line = 1.0 - smoothstep(0.08, 0.22, min(f.x, f.y));
		grass = mix(grass, vec3(0.85, 0.95, 0.8), line * 0.55);
	}
	ALBEDO = grass;
	ROUGHNESS = 1.0;
}
"""
	ground_material = ShaderMaterial.new()
	ground_material.shader = sh
	ground_material.set_shader_parameter("tile", Track.TILE)
	ground_material.set_shader_parameter("half_field", Track.TILE * Track.N * 0.5)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	mi.mesh = pm
	mi.material_override = ground_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var body := StaticBody3D.new()
	body.set_meta("ground", true)
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)


func _make_fence() -> void:
	var half := Track.TILE * Track.N * 0.5 + 3.0
	var body := StaticBody3D.new()
	add_child(body)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.95)
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.45, 0.3, 0.18)
	for i in 4:
		var horiz := i < 2
		var s := -1.0 if i % 2 == 0 else 1.0
		var size := Vector3(half * 2.0 + 1.0, 1.2, 0.6) if horiz else Vector3(0.6, 1.2, half * 2.0 + 1.0)
		var pos := Vector3(0, 0.6, s * half) if horiz else Vector3(s * half, 0.6, 0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(size.x, 0.25, size.z)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = pos + Vector3.UP * 0.35
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var mi2 := mi.duplicate()
		mi2.position = pos - Vector3.UP * 0.15
		add_child(mi2)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(size.x, 4.0, size.z) if horiz else Vector3(size.x, 4.0, size.z)
		cs.shape = bs
		cs.position = pos + Vector3.UP * 1.4
		body.add_child(cs)
	# Pfosten als MultiMesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm2 := BoxMesh.new()
	bm2.size = Vector3(0.3, 1.4, 0.3)
	mm.mesh = bm2
	var posts := []
	var stepv := 12.0
	var cnt := int(half * 2.0 / stepv)
	for k in cnt + 1:
		var a := -half + k * stepv
		posts.append(Vector3(a, 0.7, -half))
		posts.append(Vector3(a, 0.7, half))
		posts.append(Vector3(-half, 0.7, a))
		posts.append(Vector3(half, 0.7, a))
	mm.instance_count = posts.size()
	for k in posts.size():
		mm.set_instance_transform(k, Transform3D(Basis(), posts[k]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = post_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _ring_pos(rng: RandomNumberGenerator, inner: float, outer: float) -> Vector2:
	while true:
		var p := Vector2(rng.randf_range(-outer, outer), rng.randf_range(-outer, outer))
		if maxf(absf(p.x), absf(p.y)) > inner:
			return p
	return Vector2.ZERO


func _mm_instance(mesh: Mesh, xforms: Array, colors: Array, mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() > 0
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _color_mat(c: Color, use_vertex_color := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.vertex_color_use_as_albedo = use_vertex_color
	m.roughness = 0.9
	return m


func _make_trees(rng: RandomNumberGenerator) -> void:
	var half := Track.TILE * Track.N * 0.5
	var trunks := []
	var firs := []
	var fir_col := []
	var balls := []
	var ball_col := []
	for i in 170:
		var p := _ring_pos(rng, half + 10.0, half + 190.0)
		var s := rng.randf_range(0.8, 1.7)
		trunks.append(Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(p.x, 1.25 * s, p.y)))
		if rng.randf() < 0.5:
			var hs := s * rng.randf_range(0.9, 1.3)
			firs.append(Transform3D(Basis().scaled(Vector3(s, hs, s)), Vector3(p.x, 2.2 * s + 3.0 * hs, p.y)))
			fir_col.append(Color(0.12, 0.38 + rng.randf() * 0.1, 0.16))
		else:
			balls.append(Transform3D(Basis().scaled(Vector3(s, s * 0.9, s)), Vector3(p.x, 2.2 * s + 2.2 * s, p.y)))
			ball_col.append(Color(0.2 + rng.randf() * 0.12, 0.5 + rng.randf() * 0.15, 0.15))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.35
	trunk.height = 2.5
	trunk.radial_segments = 6
	trunk.rings = 1
	_mm_instance(trunk, trunks, [], _color_mat(Color(0.42, 0.28, 0.16)))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 2.2
	cone.height = 6.0
	cone.radial_segments = 8
	cone.rings = 1
	_mm_instance(cone, firs, fir_col, _color_mat(Color.WHITE, true))
	var sphere := SphereMesh.new()
	sphere.radius = 2.4
	sphere.height = 4.8
	sphere.radial_segments = 10
	sphere.rings = 6
	_mm_instance(sphere, balls, ball_col, _color_mat(Color.WHITE, true))


func _make_houses(rng: RandomNumberGenerator) -> void:
	var half := Track.TILE * Track.N * 0.5
	var bodies := []
	var body_cols := []
	var roofs := []
	var roof_cols := []
	var placed := []
	var wall_colors := [Color(0.95, 0.9, 0.75), Color(0.9, 0.85, 0.85), Color(0.8, 0.88, 0.95),
		Color(0.98, 0.95, 0.9), Color(0.92, 0.8, 0.6)]
	var roof_colors := [Color(0.65, 0.18, 0.12), Color(0.35, 0.3, 0.3), Color(0.55, 0.3, 0.15)]
	var tries := 0
	while bodies.size() < 18 and tries < 500:
		tries += 1
		var p := _ring_pos(rng, half + 18.0, half + 110.0)
		var ok := true
		for q in placed:
			if p.distance_to(q) < 22.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		var w := rng.randf_range(7.0, 12.0)
		var d := rng.randf_range(7.0, 10.0)
		var h := rng.randf_range(4.0, 7.0)
		var yaw := rng.randf() * TAU
		var b := Basis(Vector3.UP, yaw)
		bodies.append(Transform3D(b * Basis.from_scale(Vector3(w, h, d)), Vector3(p.x, h * 0.5, p.y)))
		body_cols.append(wall_colors[rng.randi() % wall_colors.size()])
		var rh := rng.randf_range(2.5, 4.0)
		roofs.append(Transform3D(b * Basis.from_scale(Vector3(w * 1.12, rh, d * 1.15)), Vector3(p.x, h + rh * 0.5, p.y)))
		roof_cols.append(roof_colors[rng.randi() % roof_colors.size()])
	var box := BoxMesh.new()
	_mm_instance(box, bodies, body_cols, _color_mat(Color.WHITE, true))
	var prism := PrismMesh.new()
	prism.left_to_right = 0.5
	_mm_instance(prism, roofs, roof_cols, _color_mat(Color.WHITE, true))
	# Fenster & Tueren als dunkle Flaechen
	var wins := []
	for t in bodies:
		var xf: Transform3D = t
		var bx := xf.basis.x
		var bz := xf.basis.z
		var by := xf.basis.y
		for side in [-1.0, 1.0]:
			for k in [-0.25, 0.25]:
				var pos: Vector3 = xf.origin + bz * 0.5 * side * 1.01 + bx * k + by * 0.12
				wins.append(Transform3D(Basis(bx.normalized(), by.normalized(), bz.normalized()) * Basis.from_scale(Vector3(1.4, 1.3, 0.05)), pos))
	_mm_instance(box, wins, [], _color_mat(Color(0.2, 0.28, 0.38)))


func _make_clouds(rng: RandomNumberGenerator) -> void:
	var xforms := []
	for i in 26:
		var ang := TAU * i / 26.0 + rng.randf_range(-0.1, 0.1)
		var dist := rng.randf_range(480.0, 850.0)
		var center := Vector3(cos(ang) * dist, rng.randf_range(110.0, 230.0), sin(ang) * dist)
		var size := rng.randf_range(18.0, 40.0)
		var tangent := Vector3(-sin(ang), 0, cos(ang))
		for k in rng.randi_range(4, 7):
			var off := tangent * rng.randf_range(-1.6, 1.6) * size + Vector3(rng.randf_range(-0.5, 0.5) * size,
				rng.randf_range(-0.1, 0.25) * size, rng.randf_range(-0.5, 0.5) * size)
			var s := size * rng.randf_range(0.6, 1.1)
			xforms.append(Transform3D(Basis().scaled(Vector3(s * 1.4, s * 0.55, s)), center + off))
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1)
	m.emission_enabled = true
	m.emission = Color(0.75, 0.78, 0.85)
	m.emission_energy_multiplier = 0.8
	m.roughness = 1.0
	m.disable_receive_shadows = true
	_mm_instance(sphere, xforms, [], m)

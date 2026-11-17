class_name CharModel
extends Node3D
## Klötzchen-Figur (Mensch oder Zombie) aus Quadern mit prozeduraler Animation.
## Die Figur schaut in +Z.

const SKIN_TONES := [Color(0.93, 0.74, 0.6), Color(0.82, 0.6, 0.45), Color(0.96, 0.8, 0.68), Color(0.7, 0.5, 0.36)]
const HAIR_TONES := [Color(0.12, 0.09, 0.07), Color(0.3, 0.18, 0.1), Color(0.08, 0.08, 0.1), Color(0.55, 0.4, 0.2)]
const ZOMBIE_SKIN := Color(0.42, 0.52, 0.4)
const HIGHLIGHT := Color(1.0, 0.92, 0.1)

var body: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var jaw: MeshInstance3D
var zombie_parts: Array[Node3D] = []
var human_parts: Array[Node3D] = []
var hair_node: MeshInstance3D

var m_skin: StandardMaterial3D
var m_shirt: StandardMaterial3D
var m_pants: StandardMaterial3D
var m_hair: StandardMaterial3D
var m_eye: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_blood: StandardMaterial3D
var m_tooth: StandardMaterial3D
var _all: Array[StandardMaterial3D] = []
var _hat_mats: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []

var is_zombie := false
var zombie_blend := 0.0
var highlighted := false
var phase := 0.0
var _t := 0.0
var _seed := 0.0
var _skin: Color
var _shirt: Color
var _pants: Color
var _bite_anim := 0.0
var _hit_anim := 0.0


## hair / hair_color / hat: Auswahl aus Cfg.HAIR_NAMES, Cfg.HAIR_COLORS, Cfg.HAT_NAMES
## (-1 = aus der Variante ableiten).
func setup(shirt: Color, variant: int, zombie: bool, hair := -1, hair_color := -1, hat := 0) -> void:
	if hair < 0:
		hair = variant % 2
	var hair_col: Color = HAIR_TONES[variant % HAIR_TONES.size()]
	if hair_color >= 0:
		hair_col = Cfg.HAIR_COLORS[hair_color % Cfg.HAIR_COLORS.size()]
	_seed = variant * 1.37
	_skin = SKIN_TONES[variant % SKIN_TONES.size()]
	_shirt = shirt
	_pants = Color(0.18, 0.22, 0.38).lerp(Color(0.3, 0.26, 0.22), (variant % 3) / 2.0)
	m_skin = _mk(_skin)
	m_shirt = _mk(shirt)
	m_pants = _mk(_pants)
	m_hair = _mk(hair_col)
	m_eye = _mk(Color(0.05, 0.05, 0.08))
	m_dark = _mk(Color(0.1, 0.02, 0.02))
	m_blood = _mk(Color(0.5, 0.03, 0.03))
	m_tooth = _mk(Color(0.9, 0.88, 0.75))

	body = Node3D.new()
	add_child(body)
	torso = Node3D.new()
	torso.position.y = 0.64
	body.add_child(torso)
	_box(torso, m_shirt, Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.28))
	_box(torso, m_pants, Vector3(0, 0.03, 0), Vector3(0.51, 0.1, 0.29))

	head = Node3D.new()
	head.position.y = 0.62
	torso.add_child(head)
	_box(head, m_skin, Vector3(0, 0.18, 0), Vector3(0.36, 0.36, 0.34))
	_build_hair(hair, hat)
	_build_hat(hat)
	# Augen
	_box(head, m_eye, Vector3(-0.09, 0.2, 0.171), Vector3(0.07, 0.07, 0.02))
	_box(head, m_eye, Vector3(0.09, 0.2, 0.171), Vector3(0.07, 0.07, 0.02))
	human_parts.append(_box(head, m_dark, Vector3(0, 0.07, 0.171), Vector3(0.12, 0.025, 0.02)))

	# Zombie-Details (nur als Zombie sichtbar)
	jaw = _box(head, m_dark, Vector3(0, 0.05, 0.172), Vector3(0.22, 0.1, 0.03))
	zombie_parts.append(jaw)
	zombie_parts.append(_box(head, m_tooth, Vector3(-0.05, 0.085, 0.19), Vector3(0.035, 0.04, 0.012)))
	zombie_parts.append(_box(head, m_tooth, Vector3(0.02, 0.085, 0.19), Vector3(0.035, 0.05, 0.012)))
	zombie_parts.append(_box(head, m_tooth, Vector3(0.075, 0.02, 0.19), Vector3(0.035, 0.04, 0.012)))
	zombie_parts.append(_box(head, m_tooth, Vector3(-0.02, 0.02, 0.19), Vector3(0.03, 0.035, 0.012)))
	zombie_parts.append(_box(head, m_blood, Vector3(0.03, -0.02, 0.173), Vector3(0.1, 0.1, 0.02)))
	zombie_parts.append(_box(head, m_blood, Vector3(-0.14, 0.3, 0.1), Vector3(0.1, 0.1, 0.16)))   # Kopfwunde
	zombie_parts.append(_box(head, m_dark, Vector3(-0.09, 0.2, 0.169), Vector3(0.12, 0.12, 0.02)))  # Augenhöhlen
	zombie_parts.append(_box(head, m_dark, Vector3(0.09, 0.2, 0.169), Vector3(0.11, 0.1, 0.02)))
	zombie_parts.append(_box(torso, m_blood, Vector3(0.08, 0.42, 0.142), Vector3(0.22, 0.2, 0.01)))
	zombie_parts.append(_box(torso, m_blood, Vector3(-0.12, 0.2, 0.142), Vector3(0.14, 0.26, 0.01)))
	zombie_parts.append(_box(torso, m_dark, Vector3(0.12, 0.14, 0.143), Vector3(0.16, 0.12, 0.012)))  # Riss
	zombie_parts.append(_box(torso, m_tooth, Vector3(0.12, 0.14, 0.146), Vector3(0.12, 0.02, 0.012))) # Rippe
	zombie_parts.append(_box(torso, m_tooth, Vector3(0.12, 0.18, 0.146), Vector3(0.1, 0.02, 0.012)))

	arm_l = _limb(torso, Vector3(-0.32, 0.56, 0), m_shirt, m_skin, 0.14, 0.56)
	arm_r = _limb(torso, Vector3(0.32, 0.56, 0), m_shirt, m_skin, 0.14, 0.56)
	leg_l = _limb(body, Vector3(-0.13, 0.64, 0), m_pants, m_dark, 0.2, 0.64)
	leg_r = _limb(body, Vector3(0.13, 0.64, 0), m_pants, m_dark, 0.2, 0.64)

	for m in _all:
		_base_colors.append(m.albedo_color)
	set_zombie(zombie, true)


## Frisur aus Quadern. Unter Hüten, die den Kopf bedecken, fallen hohe Frisuren flach aus.
func _build_hair(style: int, hat: int) -> void:
	var covered := hat in [1, 3, 4, 5, 8]
	var cap := func() -> void:
		_box(head, m_hair, Vector3(0, 0.34, -0.03), Vector3(0.39, 0.12, 0.37))
		_box(head, m_hair, Vector3(0, 0.22, -0.16), Vector3(0.39, 0.3, 0.06))
	match style:
		0:  # kurz
			cap.call()
		1:  # lang
			cap.call()
			_box(head, m_hair, Vector3(0, 0.02, -0.15), Vector3(0.4, 0.3, 0.08))
			for sx in [-0.195, 0.195]:
				_box(head, m_hair, Vector3(sx, 0.12, -0.05), Vector3(0.04, 0.4, 0.2))
		2:  # Glatze
			pass
		3:  # Irokese
			if not covered:
				_box(head, m_hair, Vector3(0, 0.44, -0.02), Vector3(0.09, 0.18, 0.36))
		4:  # Pferdeschwanz
			cap.call()
			_box(head, m_hair, Vector3(0, 0.25, -0.22), Vector3(0.1, 0.1, 0.1))
			_box(head, m_hair, Vector3(0, 0.08, -0.27), Vector3(0.08, 0.3, 0.08))
		5:  # Locken
			if covered:
				cap.call()
			else:
				_box(head, m_hair, Vector3(0, 0.39, -0.02), Vector3(0.5, 0.24, 0.48))
			_box(head, m_hair, Vector3(0, 0.2, -0.2), Vector3(0.46, 0.3, 0.1))
			for sx in [-0.21, 0.21]:
				_box(head, m_hair, Vector3(sx, 0.22, -0.04), Vector3(0.08, 0.26, 0.3))
		_:  # Zöpfe
			cap.call()
			for sx in [-0.22, 0.22]:
				_box(head, m_hair, Vector3(sx, 0.06, -0.02), Vector3(0.08, 0.4, 0.08))
				_box(head, m_shirt, Vector3(sx, -0.1, -0.02), Vector3(0.09, 0.05, 0.09))


func _hat_mat(c: Color, metal := false) -> StandardMaterial3D:
	var m := _mk(c)
	if metal:
		m.metallic = 0.7
		m.roughness = 0.35
	_hat_mats.append(m)
	return m


func _build_hat(hat: int) -> void:
	match hat:
		1:  # Kappe in der Farbe des Shirts
			var m := _hat_mat(_shirt.darkened(0.2))
			_box(head, m, Vector3(0, 0.445, -0.02), Vector3(0.41, 0.13, 0.39))
			_box(head, m, Vector3(0, 0.395, 0.25), Vector3(0.34, 0.03, 0.18))
			_box(head, _hat_mat(Color(0.9, 0.9, 0.9)), Vector3(0, 0.52, -0.02), Vector3(0.06, 0.03, 0.06))
		2:  # Strohhut
			var m := _hat_mat(Color(0.8, 0.66, 0.4))
			_box(head, m, Vector3(0, 0.415, 0), Vector3(0.66, 0.03, 0.64))
			_box(head, m, Vector3(0, 0.48, 0), Vector3(0.4, 0.12, 0.38))
			_box(head, _hat_mat(Color(0.7, 0.15, 0.12)), Vector3(0, 0.445, 0), Vector3(0.41, 0.04, 0.39))
		3:  # griechische Fischermütze
			var m := _hat_mat(Color(0.1, 0.13, 0.28))
			_box(head, m, Vector3(0, 0.44, -0.01), Vector3(0.41, 0.1, 0.39))
			_box(head, m, Vector3(0, 0.5, -0.03), Vector3(0.37, 0.04, 0.34))
			_box(head, _hat_mat(Color(0.04, 0.04, 0.06)), Vector3(0, 0.395, 0.22), Vector3(0.3, 0.03, 0.1))
			_box(head, _hat_mat(Color(0.75, 0.6, 0.2)), Vector3(0, 0.43, 0.19), Vector3(0.2, 0.025, 0.012))
		4:  # Wollmütze mit Bommel
			_box(head, _hat_mat(Color(0.75, 0.2, 0.2)), Vector3(0, 0.47, -0.01), Vector3(0.42, 0.16, 0.4))
			var m := _hat_mat(Color(0.92, 0.92, 0.9))
			_box(head, m, Vector3(0, 0.39, -0.01), Vector3(0.43, 0.06, 0.41))
			_box(head, m, Vector3(0, 0.6, -0.01), Vector3(0.11, 0.11, 0.11))
		5:  # Spartaner-Helm
			var m := _hat_mat(Color(0.8, 0.6, 0.25), true)
			_box(head, m, Vector3(0, 0.43, -0.02), Vector3(0.42, 0.16, 0.4))
			_box(head, m, Vector3(0, 0.2, -0.195), Vector3(0.42, 0.32, 0.04))
			for sx in [-0.2, 0.2]:
				_box(head, m, Vector3(sx, 0.17, 0.06), Vector3(0.03, 0.34, 0.22))
			_box(head, m, Vector3(0, 0.25, 0.185), Vector3(0.04, 0.2, 0.02))
			_box(head, m, Vector3(0, 0.345, 0.18), Vector3(0.36, 0.04, 0.03))
			_box(head, m, Vector3(0, 0.53, -0.04), Vector3(0.05, 0.05, 0.4))
			_box(head, _hat_mat(Color(0.75, 0.1, 0.1)), Vector3(0, 0.63, -0.05), Vector3(0.07, 0.17, 0.46))
		6:  # Lorbeerkranz (vorn offen)
			var m := _hat_mat(Color(0.3, 0.55, 0.2))
			for i in 9:
				var a := deg_to_rad(40.0 + i * 35.0)
				var p := Vector3(sin(a) * 0.2, 0.34 + 0.02 * (i % 2), cos(a) * 0.19)
				var leaf := _box(head, m, p, Vector3(0.07, 0.06, 0.11))
				leaf.rotation.y = a + PI * 0.5
		7:  # Krone
			var m := _hat_mat(Color(0.9, 0.72, 0.15), true)
			_box(head, m, Vector3(0, 0.41, 0), Vector3(0.4, 0.08, 0.38))
			for sx in [-0.16, 0.0, 0.16]:
				for sz in [-0.17, 0.17]:
					_box(head, m, Vector3(sx, 0.5, sz), Vector3(0.07, 0.1, 0.04))
			for sz in [-0.1, 0.1]:
				for sx in [-0.18, 0.18]:
					_box(head, m, Vector3(sx, 0.5, sz), Vector3(0.04, 0.1, 0.07))
			_box(head, _hat_mat(Color(0.8, 0.1, 0.15)), Vector3(0, 0.42, 0.195), Vector3(0.07, 0.05, 0.02))
		8:  # Kochmütze
			var m := _hat_mat(Color(0.95, 0.95, 0.95))
			_box(head, m, Vector3(0, 0.43, 0), Vector3(0.4, 0.1, 0.38))
			_box(head, m, Vector3(0, 0.58, 0), Vector3(0.48, 0.2, 0.46))


func _mk(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	m.metallic_specular = 0.2
	_all.append(m)
	return m


func _box(parent: Node3D, m: Material, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _limb(parent: Node3D, pivot_pos: Vector3, m_upper: Material, m_lower: Material, thick: float, length: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	parent.add_child(pivot)
	_box(pivot, m_upper, Vector3(0, -length * 0.3, 0), Vector3(thick, length * 0.6, thick))
	_box(pivot, m_lower, Vector3(0, -length * 0.8, 0), Vector3(thick * 0.96, length * 0.4, thick * 0.96))
	return pivot


func set_zombie(z: bool, instant := false) -> void:
	is_zombie = z
	if instant:
		zombie_blend = 1.0 if z else 0.0
		_apply_look()


func set_highlight(on: bool) -> void:
	if highlighted == on:
		return
	highlighted = on
	_apply_look()


func play_bite() -> void:
	_bite_anim = 0.45


func play_hit() -> void:
	_hit_anim = 0.4


func _apply_look() -> void:
	var zb := zombie_blend
	for i in _base_colors.size():
		_all[i].albedo_color = _base_colors[i]
	for p in zombie_parts:
		p.visible = zb > 0.5
	for p in human_parts:
		p.visible = zb <= 0.5
	m_skin.albedo_color = _skin.lerp(ZOMBIE_SKIN, zb)
	m_shirt.albedo_color = _shirt.lerp(_shirt.darkened(0.45).lerp(Color(0.25, 0.28, 0.22), 0.35), zb)
	m_pants.albedo_color = _pants.lerp(_pants.darkened(0.4), zb)
	# Hüte werden als Zombie schmutzig-dunkel (Gold würde in der Zombie-Sicht sonst gelb leuchten)
	for m in _hat_mats:
		m.albedo_color = m.albedo_color.lerp(m.albedo_color.darkened(0.55), zb)
	m_hair.albedo_color = m_hair.albedo_color.lerp(m_hair.albedo_color.darkened(0.4), zb)
	# glühende Augen
	m_eye.albedo_color = Color(0.05, 0.05, 0.08).lerp(Color(1.0, 0.95, 0.4), zb)
	m_eye.emission_enabled = zb > 0.5
	m_eye.emission = Color(1.0, 0.85, 0.2)
	m_eye.emission_energy_multiplier = 3.0
	for m in _all:
		if m == m_eye:
			continue
		m.emission_enabled = highlighted
		if highlighted:
			m.emission = HIGHLIGHT


## Wird jedes Frame vom Character aufgerufen.
## st: speed, pose ("stand","sneak","frozen","lie","crouch","inside","zwalk","zsprint","zstun","zlisten","turn","enter")
func animate(delta: float, speed: float, pose: String) -> void:
	_t += delta
	var target_blend := 1.0 if is_zombie else 0.0
	if zombie_blend != target_blend:
		zombie_blend = move_toward(zombie_blend, target_blend, delta / 1.5)
		_apply_look()
	if highlighted:
		var pulse := 0.6 + 0.4 * sin(_t * 9.0)
		for m in _all:
			if m != m_eye:
				m.emission_energy_multiplier = 1.2 + 1.6 * pulse
				m.albedo_color = HIGHLIGHT
	_bite_anim = maxf(0.0, _bite_anim - delta)
	_hit_anim = maxf(0.0, _hit_anim - delta)

	var moving := speed > 0.25
	var stride := 1.1
	if moving:
		phase += delta * speed / stride * PI
	var sw := sin(phase)
	var amp := clampf(speed / 3.0, 0.25, 1.0) if moving else 0.0

	# Zielwerte
	var body_y := 0.0
	var body_rx := 0.0     # Körper nach vorn
	var body_rz := 0.0
	var torso_rx := 0.0
	var head_rx := 0.0
	var head_rz := 0.0
	var al := 0.0          # Arm-Rotation x (vor/zurück)
	var ar := 0.0
	var alz := 0.0
	var arz := 0.0
	var ll := sw * 0.8 * amp
	var lr := -sw * 0.8 * amp
	var sc := Vector3.ONE
	var vis := true

	match pose:
		"stand":
			al = -sw * 0.9 * amp
			ar = sw * 0.9 * amp
			body_y = absf(cos(phase)) * 0.05 * amp + sin(_t * 2.0 + _seed) * 0.008
			torso_rx = 0.12 * amp
		"sneak":
			body_y = -0.12
			torso_rx = 0.45
			head_rx = -0.35
			al = -sw * 0.4 * amp - 0.5
			ar = sw * 0.4 * amp - 0.5
			ll = sw * 0.6 * amp - 0.25
			lr = -sw * 0.6 * amp - 0.25
		"frozen":
			# stocksteif, leichtes Zittern
			body_rz = sin(_t * 37.0) * 0.008
			al = 0.0
			ar = 0.0
			alz = 0.06
			arz = -0.06
			ll = 0.0
			lr = 0.0
		"lie":
			body_rx = -PI * 0.5
			body_y = 0.2
			ll = 0.0
			lr = 0.0
			al = 0.0
			ar = 0.0
		"crouch":
			body_y = -0.34
			torso_rx = 0.9
			head_rx = -0.7
			ll = -1.5
			lr = -1.5
			al = -1.0
			ar = -1.0
			sc = Vector3(0.9, 0.9, 0.9)
		"inside":
			vis = false
		"zwalk":
			torso_rx = 0.3 + sin(_t * 1.7 + _seed) * 0.06
			body_rz = sin(phase) * 0.12 * amp + sin(_t * 0.9 + _seed) * 0.04
			head_rz = 0.3 + sin(_t * 1.3) * 0.1
			head_rx = -0.15
			al = -1.35 + sin(_t * 2.3 + _seed) * 0.12
			ar = -1.1 + sin(_t * 1.9) * 0.15
			ll = sw * 0.5 * amp
			lr = -sw * 0.25 * amp   # hinkt
			body_y = absf(cos(phase)) * 0.03 * amp
		"zsprint":
			torso_rx = 0.55
			body_rz = sin(phase) * 0.15
			head_rx = -0.4
			head_rz = sin(_t * 14.0) * 0.12
			al = -1.6 + sw * 0.7
			ar = -1.6 - sw * 0.7
			ll = sw * 1.0
			lr = -sw * 1.0
			body_y = absf(cos(phase)) * 0.07
		"zstun":
			# kauen
			torso_rx = 0.55
			head_rx = 0.25 + sin(_t * 11.0) * 0.14
			al = -0.9
			ar = -0.7
			ll = 0.0
			lr = 0.0
		"zlisten":
			torso_rx = 0.1
			head_rz = 0.45
			head_rx = -0.2
			al = -0.2
			ar = -2.6
			arz = -0.5
			ll = 0.0
			lr = 0.0
		"turn":
			# Verwandlung: Krämpfe
			body_rz = sin(_t * 31.0) * 0.14
			torso_rx = 0.5 + sin(_t * 23.0) * 0.2
			head_rz = sin(_t * 27.0) * 0.4
			al = -1.0 + sin(_t * 29.0) * 0.6
			ar = -1.0 + cos(_t * 26.0) * 0.6
			ll = 0.0
			lr = 0.0
			body_y = -0.1
		"zslip":
			# auf dem Rücken, zappelt
			body_rx = -PI * 0.5
			body_y = 0.25
			al = -1.6 + sin(_t * 17.0) * 0.9
			ar = -1.6 + cos(_t * 15.0) * 0.9
			ll = -0.8 + sin(_t * 13.0) * 0.8
			lr = -0.8 + cos(_t * 14.0) * 0.8
			head_rx = 0.3
		"enter":
			torso_rx = 0.8
			al = -2.2
			ar = -2.2
			ll = sin(_t * 9.0) * 0.5
			lr = -sin(_t * 9.0) * 0.5

	if _bite_anim > 0.0:
		var k := sin((0.45 - _bite_anim) / 0.45 * PI)
		torso_rx += 0.6 * k
		head_rx -= 0.5 * k
		al = lerpf(al, -1.7, k)
		ar = lerpf(ar, -1.7, k)
	if _hit_anim > 0.0:
		body_rz += sin(_hit_anim * 40.0) * 0.2 * (_hit_anim / 0.4)

	visible = vis
	var k2 := clampf(delta * 14.0, 0.0, 1.0)
	body.position.y = lerpf(body.position.y, body_y, k2)
	body.rotation.x = lerp_angle(body.rotation.x, body_rx, k2)
	body.rotation.z = lerp_angle(body.rotation.z, body_rz, k2)
	body.scale = body.scale.lerp(sc, k2)
	torso.rotation.x = lerp_angle(torso.rotation.x, torso_rx, k2)
	head.rotation.x = lerp_angle(head.rotation.x, head_rx, k2)
	head.rotation.z = lerp_angle(head.rotation.z, head_rz, k2)
	arm_l.rotation.x = lerp_angle(arm_l.rotation.x, al, k2)
	arm_r.rotation.x = lerp_angle(arm_r.rotation.x, ar, k2)
	arm_l.rotation.z = lerp_angle(arm_l.rotation.z, alz, k2)
	arm_r.rotation.z = lerp_angle(arm_r.rotation.z, arz, k2)
	leg_l.rotation.x = lerp_angle(leg_l.rotation.x, ll, k2)
	leg_r.rotation.x = lerp_angle(leg_r.rotation.x, lr, k2)
	if jaw.visible:
		jaw.scale.y = 1.0 + 0.5 * absf(sin(_t * (11.0 if pose == "zstun" else 2.0) + _seed))

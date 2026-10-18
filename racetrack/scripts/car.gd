class_name Car
extends RigidBody3D
## Einfaches Raycast-Fahrzeug: 4 Federbeine, Reifenkraefte mit Reibkreis,
## Antrieb, Bremse/Rueckwaerts, Booster, Abtrieb und Luft-Stabilisierung.

signal boosted
signal landed(strength: float)
signal wall_hit(strength: float)

enum { KART, RACER, TRUCK }

const NAMES := ["Gokart", "Rennwagen", "Monstertruck"]

const CONFIGS := [
	{ # Gokart: leicht, wendig, niedrig
		"mass": 160.0, "wheelbase": 1.1, "track": 1.0, "radius": 0.16, "wheel_w": 0.2,
		"susp": 0.13, "zeta": 0.7, "top": 25.0, "accel": 8.0, "brake": 14.0, "grip": 1.3,
		"lat": 20.0, "steer_lo": 34.0, "steer_hi": 13.0, "roll": 0.15, "antiroll": 0.5,
		"com_y": 0.12, "downforce": 0.0, "awd": false, "offroad": 0.6,
		"body": Vector3(1.0, 0.32, 1.6), "body_y": 0.36, "cam_dist": 4.6, "cam_h": 1.9, "gears": 1,
	},
	{ # Rennwagen (Ferrari-Stil): schnell, viel Grip, Abtrieb
		"mass": 1100.0, "wheelbase": 2.7, "track": 1.7, "radius": 0.34, "wheel_w": 0.32,
		"susp": 0.21, "zeta": 0.7, "top": 52.0, "accel": 10.0, "brake": 16.0, "grip": 1.6,
		"lat": 20.0, "steer_lo": 28.0, "steer_hi": 6.5, "roll": 0.2, "antiroll": 0.6,
		"com_y": 0.3, "downforce": 2.2, "awd": false, "offroad": 0.55,
		"body": Vector3(1.9, 0.5, 4.4), "body_y": 0.62, "cam_dist": 7.5, "cam_h": 2.7, "gears": 6,
	},
	{ # Monstertruck: grosse Raeder, weiche lange Federung, Allrad
		"mass": 2800.0, "wheelbase": 3.0, "track": 2.6, "radius": 0.85, "wheel_w": 0.7,
		"susp": 0.55, "zeta": 0.55, "top": 34.0, "accel": 7.5, "brake": 11.0, "grip": 1.15,
		"lat": 16.0, "steer_lo": 32.0, "steer_hi": 11.0, "roll": 0.2, "antiroll": 0.45,
		"com_y": 0.95, "downforce": 0.0, "awd": true, "offroad": 1.0,
		"body": Vector3(2.4, 1.1, 4.0), "body_y": 2.0, "cam_dist": 10.0, "cam_h": 4.4, "gears": 4,
	},
]

var car_type := KART
var cfg: Dictionary
var track: Track

# Eingaben
var throttle := 0.0
var brake_input := 0.0
var steer_input := 0.0

# Zustand
var steer := 0.0
var speed := 0.0              # Vorwaerts-Geschwindigkeit (m/s)
var slip := 0.0               # 0..1 fuer Reifenquietschen
var rpm := 0.0                # 0..1 normiert fuer Motorsound
var boost_timer := 0.0
var air_time := 0.0
var contacts := 0
var upside_timer := 0.0
var on_grass := false

var _wheels: Array = []
var _k := 0.0
var _c := 0.0
var _gear := 0
var _last_wall := 0.0


func setup(type: int, trk: Track) -> void:
	car_type = type
	track = trk
	cfg = CONFIGS[type]
	mass = cfg["mass"]
	var g := 9.8
	var static_comp: float = cfg["susp"] * 0.45
	_k = mass * g / 4.0 / static_comp
	_c = 2.0 * float(cfg["zeta"]) * sqrt(_k * mass / 4.0)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, cfg["com_y"], 0.05)
	continuous_cd = true
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 6
	collision_layer = 2
	collision_mask = 1
	linear_damp = 0.0
	angular_damp = 0.6
	var pm := PhysicsMaterial.new()
	pm.friction = 0.25
	pm.bounce = 0.05
	physics_material_override = pm

	var r: float = cfg["radius"]
	var susp: float = cfg["susp"]
	var hub_rest_y := r
	var mount_y := hub_rest_y + susp - static_comp
	var hw: float = cfg["track"] * 0.5
	var hl: float = cfg["wheelbase"] * 0.5
	var model := CarModels.build(type)
	add_child(model)
	var wheel_nodes: Array = model.get_meta("wheels")
	var idx := 0
	for z in [-hl, hl]:
		for x in [-hw, hw]:
			var w := {
				"mount": Vector3(x, mount_y, z),
				"front": z < 0.0,
				"drive": cfg["awd"] or z > 0.0,
				"node": wheel_nodes[idx],
				"comp": static_comp,
				"contact": false,
				"spin": 0.0,
			}
			_wheels.append(w)
			idx += 1
	# Kollision: Karosserie-Box + Kugeln an den Radnaben
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = cfg["body"]
	cs.shape = bs
	cs.position = Vector3(0, cfg["body_y"], 0)
	add_child(cs)
	for w in _wheels:
		var sc := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = r * (0.45 if type == TRUCK else 0.6)
		sc.shape = sp
		sc.position = Vector3(w["mount"].x, hub_rest_y, w["mount"].z)
		add_child(sc)


func reset_to(xf: Transform3D) -> void:
	global_transform = Transform3D(xf.basis, xf.origin + xf.basis.y * 0.4)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	steer = 0.0
	boost_timer = 0.0
	upside_timer = 0.0
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if cfg.is_empty():
		return
	var space := get_world_3d().direct_space_state
	var xf := global_transform
	var up := xf.basis.y.normalized()
	var fwd := -xf.basis.z.normalized()
	var com := xf * center_of_mass
	speed = linear_velocity.dot(fwd)
	var top: float = cfg["top"]
	var spd_ratio := clampf(absf(speed) / top, 0.0, 1.0)

	var max_steer := deg_to_rad(lerpf(cfg["steer_lo"], cfg["steer_hi"], spd_ratio))
	steer = move_toward(steer, steer_input * max_steer, delta * 3.5)

	# Booster
	if track and track.is_boost(global_position):
		if boost_timer < 0.6:
			boosted.emit()
		boost_timer = 1.4
	boost_timer = maxf(boost_timer - delta, 0.0)
	var boosting := boost_timer > 0.0

	var r: float = cfg["radius"]
	var susp: float = cfg["susp"]
	var m4 := mass / 4.0
	var grip: float = cfg["grip"]
	var n_drive := 4.0 if cfg["awd"] else 2.0
	var top_eff := top * (1.45 if boosting else 1.0)
	var engine := 0.0
	if throttle > 0.0:
		engine = mass * float(cfg["accel"]) * throttle * maxf(0.0, 1.0 - pow(maxf(speed, 0.0) / top_eff, 2.0))
	if boosting:
		engine += mass * 14.0
	var reversing := brake_input > 0.0 and speed < 0.8 and throttle <= 0.0
	if reversing:
		engine = -mass * float(cfg["accel"]) * 0.5 * brake_input * maxf(0.0, 1.0 - absf(minf(speed, 0.0)) / 9.0)

	var was_contacts := contacts
	contacts = 0
	var slip_acc := 0.0
	var grass := 0
	var comps := []
	for w in _wheels:
		var mount_g: Vector3 = xf * w["mount"]
		var ray_len := susp + r
		var q := PhysicsRayQueryParameters3D.create(mount_g, mount_g - up * ray_len, 1, [get_rid()])
		var hit := space.intersect_ray(q)
		var node: Node3D = w["node"]
		if hit.is_empty():
			w["contact"] = false
			w["comp"] = 0.0
			comps.append(0.0)
			node.position = w["mount"] - Vector3.UP * susp
			_update_wheel_visual(w, delta, speed)
			continue
		contacts += 1
		var hp: Vector3 = hit["position"]
		var hn: Vector3 = hit["normal"]
		var dist := mount_g.distance_to(hp)
		var comp := clampf(susp - (dist - r), 0.0, susp)
		var comp_vel := (comp - float(w["comp"])) / delta
		w["comp"] = comp
		w["contact"] = true
		comps.append(comp)
		node.position = w["mount"] - Vector3.UP * (dist - r)
		var spring := maxf(_k * comp + _c * comp_vel, 0.0)
		# Bump-Stop bei voller Einfederung
		if comp >= susp * 0.98:
			spring += maxf(comp_vel, 0.0) * m4 * 6.0
		apply_force(up * spring, hp - global_position)

		var col: Object = hit["collider"]
		var is_grass: bool = col != null and col.has_meta("ground")
		if is_grass:
			grass += 1
		var surf_grip := grip * (lerpf(0.75, 1.0, cfg["offroad"]) if is_grass else 1.0)

		# Reifenrichtungen in der Bodenebene
		var wf := fwd
		if w["front"]:
			wf = fwd.rotated(up, -steer)
		wf = (wf - hn * wf.dot(hn)).normalized()
		var ws := wf.cross(hn).normalized()
		var v := linear_velocity + angular_velocity.cross(hp - com)
		var v_long := v.dot(wf)
		var v_lat := v.dot(ws)

		var load := spring
		var f_lat := -v_lat * m4 * float(cfg["lat"])
		var f_long := 0.0
		if w["drive"]:
			f_long += engine / n_drive
		if brake_input > 0.0 and not reversing:
			var fb := float(cfg["brake"]) * m4 * brake_input
			f_long -= signf(v_long) * minf(fb, absf(v_long) * m4 / delta)
		# Roll- und Motorwiderstand
		var roll_res := 0.04 + (0.35 * (1.0 - float(cfg["offroad"])) if is_grass else 0.0)
		if throttle <= 0.0 and not reversing:
			roll_res += 0.12
		f_long -= v_long * m4 * roll_res
		# Reibkreis (Seitenfuehrung hat Vorrang -> stabiles Arcade-Fahrverhalten)
		var fmax := surf_grip * load
		var ftot := sqrt(f_lat * f_lat + f_long * f_long)
		if ftot > fmax and ftot > 0.001:
			slip_acc += clampf((ftot - fmax) / maxf(fmax, 1.0), 0.0, 1.0)
			f_lat = clampf(f_lat, -fmax, fmax)
			var long_max := sqrt(maxf(fmax * fmax - f_lat * f_lat, fmax * fmax * 0.12))
			f_long = clampf(f_long, -long_max, long_max)
		if absf(v_lat) > 4.0:
			slip_acc += clampf((absf(v_lat) - 4.0) / 6.0, 0.0, 1.0)
		# Kraft etwas oberhalb des Aufstandspunkts (weniger Kippneigung)
		var app := hp + up * (com - hp).dot(up) * (1.0 - float(cfg["roll"]))
		apply_force(wf * f_long + ws * f_lat, app - global_position)
		_update_wheel_visual(w, delta, v_long)

	# Stabilisatoren (je Achse)
	var ar := _k * float(cfg["antiroll"])
	for a in 2:
		var wl: Dictionary = _wheels[a * 2]
		var wr: Dictionary = _wheels[a * 2 + 1]
		var diff := float(comps[a * 2]) - float(comps[a * 2 + 1])
		if wl["contact"]:
			apply_force(up * diff * ar, xf * wl["mount"] - global_position)
		if wr["contact"]:
			apply_force(-up * diff * ar, xf * wr["mount"] - global_position)

	on_grass = grass >= 2
	slip = lerpf(slip, clampf(slip_acc / 2.0, 0.0, 1.0), 0.25)
	# Abtrieb & Luftwiderstand
	if contacts > 0:
		apply_central_force(-up * float(cfg["downforce"]) * speed * speed * mass / 1000.0)
	apply_central_force(-linear_velocity * linear_velocity.length() * mass * 0.0006)

	# In der Luft: sanft aufrichten
	if contacts == 0:
		air_time += delta
		# Am Boden unter dem Fahrzeug ausrichten (sauberes Landen auf Steilkurven und Rampen)
		var target_up := Vector3.UP
		var dq := PhysicsRayQueryParameters3D.create(com, com + Vector3.DOWN * 20.0, 1, [get_rid()])
		var dh := space.intersect_ray(dq)
		if not dh.is_empty():
			target_up = dh["normal"]
		var axis := up.cross(target_up)
		var inertia_scale := mass * (2.0 if car_type == TRUCK else 1.0)
		apply_torque(axis * inertia_scale * 8.0 - angular_velocity * inertia_scale * 0.8)
	else:
		if was_contacts == 0 and air_time > 0.35:
			landed.emit(clampf(air_time, 0.0, 2.0))
		air_time = 0.0

	# Auf dem Dach? -> nach kurzer Zeit automatisch aufstellen
	if up.y < 0.25 and linear_velocity.length() < 3.0:
		upside_timer += delta
		if upside_timer > 1.6:
			flip_upright()
	else:
		upside_timer = 0.0

	_update_rpm(delta)


func flip_upright() -> void:
	var f := -global_transform.basis.z
	f.y = 0.0
	if f.length() < 0.1:
		f = Vector3.FORWARD
	var xf := Transform3D(Basis.looking_at(f.normalized(), Vector3.UP), global_position + Vector3.UP * 1.2)
	reset_to(xf)


func _update_wheel_visual(w: Dictionary, delta: float, v_long: float) -> void:
	var r: float = cfg["radius"]
	var spin_rate := v_long / r
	if not w["contact"] and w["drive"]:
		spin_rate = throttle * 40.0
	w["spin"] = fmod(float(w["spin"]) + spin_rate * delta, TAU)
	var node: Node3D = w["node"]
	var st := -steer if w["front"] else 0.0
	node.basis = Basis(Vector3.UP, st) * Basis(Vector3.RIGHT, -float(w["spin"]))


func _update_rpm(delta: float) -> void:
	var gears: int = cfg["gears"]
	var ratio := clampf(absf(speed) / float(cfg["top"]), 0.0, 1.2)
	var target := 0.0
	if contacts == 0:
		target = 0.35 + 0.6 * throttle
	elif gears <= 1:
		target = 0.12 + ratio * 0.85
	else:
		# Gangwechsel simulieren
		var g := clampi(int(ratio * gears * 0.999), 0, gears - 1)
		var lo := float(g) / gears
		var inner := clampf((ratio - lo) * gears, 0.0, 1.0)
		target = (0.15 + inner * 0.8) if g == 0 else (0.45 + inner * 0.5)
		_gear = g
	target += throttle * 0.08
	rpm = lerpf(rpm, target, clampf(delta * 8.0, 0.0, 1.0))


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for i in state.get_contact_count():
		var nrm := state.get_contact_local_normal(i)
		if absf(nrm.y) < 0.55:
			var imp := state.get_contact_impulse(i).length() / mass
			if imp > 2.5 and now - _last_wall > 0.25:
				_last_wall = now
				wall_hit.emit(clampf(imp / 10.0, 0.1, 1.0))


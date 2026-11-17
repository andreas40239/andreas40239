class_name Character
extends CharacterBody3D
## Eine Spielfigur – Mensch oder Zombie, vom Spieler oder von der KI gesteuert.

var game                       # Game (Hauptszene)
var cname := ""
var is_player := false         # die Figur des Spielers an DIESEM Gerät
var player_controlled := false # von einem Menschen gesteuert (HUD oder Netzwerk), sonst von brain
var owner_peer := 0            # Netzwerk: Peer-ID des steuernden Spielers (0 = Computer)
var puppet := false            # Netzwerk-Client: Figur wird nur angezeigt, Zustand kommt vom Gastgeber
var net_pos := Vector3.ZERO
var net_vel := Vector3.ZERO
var net_facing := 0.0
var net_age := 0.0
var net_chase := -1            # Zombie: Index der Figur, die er gerade verfolgt
var bite_cd := 0.0             # Sperre nach einem Fehlbiss
var input_age := 0.0           # Gastgeber: Sekunden seit der letzten Eingabe des Mitspielers
var is_zombie := false
var started_as_zombie := false
var lives := Cfg.MAX_LIVES
var bites := 0                 # ausgeteilte Bisse (als Zombie)
var bites_taken := 0
var brain = null               # HumanAI / ZombieAI
var model: CharModel
var shirt := Color.WHITE
var variant := 0

# --- Absichten (vom Spieler oder der KI gesetzt)
var move_dir := Vector3.ZERO
var want_sneak := false
var want_freeze := false
var want_listen := false

# --- Zustand
var hidden_in: HidingSpot = null
var hide_pose := "inside"
var frozen := false
var freeze_left := Cfg.FREEZE_MAX
var freeze_lock := 0.0
var sneaking := false
var moving := false
var motion := 0.25             # Auffälligkeit 0..1 (siehe Cfg.sight_range)
var garlic_t := 0.0
var souvlaki_t := 0.0
var has_melon := false
var invuln_t := 0.0
var stun_t := 0.0
var sprint_t := 0.0
var sprint_cd := 0.0
var heard_t := 0.0             # Zombie: Zeitfenster, in dem ein Sprint möglich ist
var heard_pos := Vector3.ZERO
var listening := false
var listen_t := 0.0
var noise_t := 0.0             # Mensch: hat gerade Lärm gemacht (gelbes Oval)
var turn_t := 0.0              # > 0: verwandelt sich gerade
var lure_t := 0.0              # Zombie: von Melone angelockt
var lure_pos := Vector3.ZERO
var busy := false              # gescriptete Bewegung (Fenster-Einstieg, Verstecken)
var busy_pose := "enter"
var facing := 0.0
var alive_time := 0.0          # Überlebenszeit als Mensch

var _step_acc := 0.0
var _groan_t := 3.0
var _shape: CollisionShape3D
var _label: Label3D
var _fx_garlic: CPUParticles3D
var _fx_speed: CPUParticles3D
var _melon_mesh: MeshInstance3D
var _freeze_ring: MeshInstance3D


func setup(p_game, p_name: String, p_shirt: Color, p_variant: int, zombie: bool) -> void:
	game = p_game
	cname = p_name
	shirt = p_shirt
	variant = p_variant
	is_zombie = zombie
	started_as_zombie = zombie
	if zombie:
		lives = 0
	collision_layer = 2
	collision_mask = Cfg.LAYER_WORLD
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.6
	_shape.shape = cap
	_shape.position.y = 0.8
	add_child(_shape)

	model = CharModel.new()
	add_child(model)
	model.setup(p_shirt, p_variant, zombie)

	_label = Label3D.new()
	_label.text = cname
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0011
	_label.font_size = 30
	_label.outline_size = 10
	_label.position.y = 2.05
	_label.modulate = p_shirt.lightened(0.5)
	_label.render_priority = 5
	add_child(_label)

	_fx_garlic = _make_particles(Color(0.55, 0.85, 0.3, 0.55), 14, 1.4, 0.5, 0.22)
	_fx_speed = _make_particles(Color(1.0, 0.6, 0.15, 0.8), 18, 0.5, 0.15, 0.08)
	_melon_mesh = Props.melon_mesh(0.14)
	_melon_mesh.position = Vector3(0, 1.2, -0.22)
	_melon_mesh.visible = false
	add_child(_melon_mesh)

	# eisblauer Ring am Boden, wenn die Figur "bewegungslos" ist
	_freeze_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	tm.rings = 24
	tm.ring_segments = 6
	_freeze_ring.mesh = tm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.55, 0.85, 1.0, 0.8)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_freeze_ring.material_override = fm
	_freeze_ring.position.y = 0.04
	_freeze_ring.scale.y = 0.2
	_freeze_ring.visible = false
	add_child(_freeze_ring)


func _make_particles(color: Color, amount: int, life: float, radius: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	p.direction = Vector3.UP
	p.spread = 180.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var qm := SphereMesh.new()
	qm.radius = size
	qm.height = size * 2.0
	qm.radial_segments = 6
	qm.rings = 3
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = color
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = pm
	p.mesh = qm
	p.position.y = 0.9
	p.emitting = false
	add_child(p)
	return p


func facing_dir() -> Vector3:
	return Vector3(sin(facing), 0, cos(facing))


func face_towards(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		facing = atan2(d.x, d.z)
		rotation.y = facing


func is_active_human() -> bool:
	return not is_zombie and turn_t <= 0.0


## Kann sich diese Figur gerade frei bewegen / handeln?
func can_act() -> bool:
	return not busy and turn_t <= 0.0 and stun_t <= 0.0


func listen_active() -> bool:
	return listening and listen_t >= Cfg.LISTEN_WARMUP


func current_speed() -> float:
	if is_zombie:
		if sprint_t > 0.0:
			return Cfg.ZOMBIE_SPRINT
		if brain != null and brain.walk_slow:
			return Cfg.ZOMBIE_WALK
		return Cfg.ZOMBIE_CHASE
	if sneaking:
		return Cfg.HUMAN_SNEAK * (1.5 if souvlaki_t > 0.0 else 1.0)
	return Cfg.HUMAN_SOUVLAKI if souvlaki_t > 0.0 else Cfg.HUMAN_RUN


func _physics_process(delta: float) -> void:
	if game == null or game.paused_logic:
		return
	if puppet:
		_puppet_process(delta)
		return
	_tick_timers(delta)
	if not is_zombie and turn_t <= 0.0 and game.phase != game.Phase.END:
		alive_time += delta

	if busy:
		velocity = Vector3.ZERO
		model.animate(delta, 2.0, busy_pose)
		return
	if turn_t > 0.0:
		turn_t -= delta
		velocity = Vector3.ZERO
		model.animate(delta, 0.0, "turn")
		if turn_t <= 0.0:
			_finish_turning()
		return
	if brain != null and not player_controlled:
		brain.think(delta)
	elif owner_peer > 1:
		# Mitspieler übers Netz: kommt nichts mehr an, bleibt die Figur stehen
		input_age += delta
		if input_age > 0.6:
			move_dir = Vector3.ZERO
	if hidden_in != null:
		velocity = Vector3.ZERO
		moving = false
		frozen = false
		motion = 0.0
		freeze_left = minf(Cfg.FREEZE_MAX, freeze_left + Cfg.FREEZE_REGEN * delta)
		model.animate(delta, 0.0, hide_pose)
		return

	var dir := move_dir
	if dir.length() > 1.0:
		dir = dir.normalized()
	if is_zombie:
		frozen = false
		sneaking = false
		if stun_t > 0.0:
			dir = Vector3.ZERO
			listening = false
		else:
			listening = want_listen
		if listening:
			listen_t += delta
			dir = Vector3.ZERO
		else:
			listen_t = 0.0
	else:
		listening = false
		var can_freeze := freeze_left > 0.0 and freeze_lock <= 0.0
		frozen = want_freeze and can_freeze
		if frozen:
			freeze_left -= delta
			dir = Vector3.ZERO
			if freeze_left <= 0.0:
				freeze_left = 0.0
				freeze_lock = Cfg.FREEZE_LOCK
				frozen = false
		elif not want_freeze:
			freeze_left = minf(Cfg.FREEZE_MAX, freeze_left + Cfg.FREEZE_REGEN * delta)
		sneaking = want_sneak

	var target := dir * current_speed()
	velocity = velocity.move_toward(target, 40.0 * delta)
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0
	var sp := Vector2(velocity.x, velocity.z).length()
	moving = sp > 0.35
	if moving:
		facing = lerp_angle(facing, atan2(velocity.x, velocity.z), clampf(delta * 12.0, 0, 1))
		rotation.y = facing

	if is_zombie:
		motion = 1.0
	elif frozen:
		motion = 0.0
	elif moving:
		motion = 0.6 if sneaking else 1.0
	else:
		motion = 0.25

	_steps(delta, sp)
	_groans(delta)
	_freeze_ring.visible = frozen
	model.animate(delta, sp, _pose())


## Netzwerk-Client: Position weich zum zuletzt gemeldeten Zustand führen und animieren.
func _puppet_process(delta: float) -> void:
	_tick_timers(delta)
	net_age += delta
	var target := net_pos + net_vel * minf(net_age, 0.12)
	if busy or hidden_in != null or global_position.distance_to(target) > 3.0:
		global_position = target
	else:
		global_position = global_position.lerp(target, clampf(delta * 18.0, 0.0, 1.0))
	velocity = net_vel
	facing = lerp_angle(facing, net_facing, clampf(delta * 14.0, 0.0, 1.0))
	rotation.y = facing
	_freeze_ring.visible = frozen and hidden_in == null
	var pose := _pose()
	var sp := Vector2(net_vel.x, net_vel.z).length()
	if busy:
		pose = busy_pose
		sp = 2.0
	elif turn_t > 0.0:
		pose = "turn"
		sp = 0.0
	elif hidden_in != null:
		pose = hide_pose
		sp = 0.0
	model.animate(delta, sp, pose)


func mark_zombie() -> void:
	is_zombie = true
	model.set_zombie(true)
	_label.modulate = Color(0.75, 0.95, 0.55)


func _tick_timers(delta: float) -> void:
	bite_cd = maxf(0.0, bite_cd - delta)
	garlic_t = maxf(0.0, garlic_t - delta)
	souvlaki_t = maxf(0.0, souvlaki_t - delta)
	invuln_t = maxf(0.0, invuln_t - delta)
	stun_t = maxf(0.0, stun_t - delta)
	sprint_t = maxf(0.0, sprint_t - delta)
	sprint_cd = maxf(0.0, sprint_cd - delta)
	heard_t = maxf(0.0, heard_t - delta)
	noise_t = maxf(0.0, noise_t - delta)
	lure_t = maxf(0.0, lure_t - delta)
	freeze_lock = maxf(0.0, freeze_lock - delta)
	_fx_garlic.emitting = garlic_t > 0.0 and hidden_in == null
	_fx_speed.emitting = souvlaki_t > 0.0 and moving
	_melon_mesh.visible = has_melon and not is_zombie and model.visible


func _pose() -> String:
	if is_zombie:
		if stun_t > 0.0:
			return "zstun"
		if listening:
			return "zlisten"
		if sprint_t > 0.0 and moving:
			return "zsprint"
		return "zwalk"
	if frozen:
		return "frozen"
	if sneaking:
		return "sneak"
	return "stand"


func _steps(delta: float, sp: float) -> void:
	if not moving:
		_step_acc = 0.6
		return
	_step_acc += sp * delta
	var stride := 1.15
	if is_zombie:
		stride = 1.3 if sprint_t > 0.0 else 0.85
	elif sneaking:
		stride = 0.75
	if _step_acc < stride:
		return
	_step_acc = 0.0
	if is_zombie:
		if sprint_t > 0.0:
			Sfx.play_at("step_run_%d" % randi_range(1, 4), global_position, -5.0, 0.8)
		else:
			Sfx.play_at("zombie_step_%d" % randi_range(1, 3), global_position, -4.0)
	elif sneaking:
		Sfx.play_at("step_sneak_%d" % randi_range(1, 2), global_position, -10.0)
	else:
		Sfx.play_at("step_run_%d" % randi_range(1, 4), global_position, 0.0)
		noise_t = Cfg.NOISE_MARK_TIME
		game.emit_noise(global_position, Cfg.RUN_NOISE_RADIUS, self, false)


func _groans(delta: float) -> void:
	if not is_zombie or game.phase == game.Phase.END:
		return
	_groan_t -= delta
	if _groan_t <= 0.0:
		_groan_t = randf_range(4.0, 9.0)
		Sfx.play_at("zombie_groan_%d" % randi_range(1, 4), global_position, -3.0)


# ------------------------------------------------------------------ Ereignisse

## Zombie hört ein Geräusch.
func hear(pos: Vector3, lure: bool) -> void:
	if not is_zombie or busy:
		return
	heard_t = 4.0
	heard_pos = pos
	if lure:
		lure_t = Cfg.MELON_LURE_TIME
		lure_pos = pos
		sprint_t = Cfg.SPRINT_TIME
	if brain != null and not player_controlled:
		brain.on_noise(pos, lure)


func try_sprint() -> bool:
	if not is_zombie or sprint_cd > 0.0 or stun_t > 0.0:
		return false
	sprint_t = Cfg.SPRINT_TIME
	sprint_cd = Cfg.SPRINT_TIME + Cfg.SPRINT_COOLDOWN
	if randf() < 0.6:
		Sfx.play_at("zombie_scream", global_position, -2.0)
	return true


func start_turning() -> void:
	turn_t = 2.2
	garlic_t = 0.0
	souvlaki_t = 0.0
	has_melon = false
	frozen = false
	velocity = Vector3.ZERO
	Sfx.play_at("transform", global_position, 0.0)


func _finish_turning() -> void:
	is_zombie = true
	lives = 0
	stun_t = 1.0
	sprint_cd = 2.0
	want_sneak = false
	want_freeze = false
	mark_zombie()
	game.on_turned(self)


func set_label_visible(v: bool) -> void:
	_label.visible = v


func set_collision_enabled(v: bool) -> void:
	_shape.disabled = not v

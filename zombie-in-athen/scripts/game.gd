extends Node3D
## Hauptszene eines Spiels: baut das Level, steuert Phasen, Bisse, Verstecke,
## Upgrades, Kamera und die Zombie-Sicht.

enum Phase { PREP, HUNT, END }

const HudScript := preload("res://scripts/hud.gd")

var phase: int = Phase.PREP
var paused_logic := false
var apt: ApartmentGen
var nav: Nav
var builder: ApartmentBuilder
var chars: Array[Character] = []
var player: Character
var spots: Array[HidingSpot] = []
var pickups: Array[Pickup] = []
var prep_left := 30.0
var match_left := 300.0
var time := 0.0
var cam: Camera3D
var cam_fwd := Vector3(-1, 0, -1).normalized()
var cam_right := Vector3(1, 0, -1).normalized()
var hud
var zombie_view := false
var marker_on := {}            # Character -> bool (gelbes Oval sichtbar)
var results := {}
var rng := RandomNumberGenerator.new()

var _level: Dictionary
var _markers := {}             # Character -> Sprite3D
var _pending: Array[Dictionary] = []   # Zombies, die draußen warten: {z, win}
var _spawned_outside := false
var _pickup_t := Cfg.PICKUP_FIRST
var _tick_t := 0.0
var _pound_t := 0.0
var _bite_cd := 0.0
var _vision: ColorRect
var _vision_strength := 0.0
var _aim_arrow: Node3D
var _aiming := false
var _aim_dir := Vector3.ZERO
var _listener: AudioListener3D
var _shot_times: Array = []
var _shot_i := 0
var _end_t := 0.0
var _env: Environment
var _noise_pings: Array[Dictionary] = []   # für die Minimap: {pos, t}


func _ready() -> void:
	_level = GameState.level
	var s: int = int(_level.get("seed", 0))
	if s == 0:
		s = randi() % 1000000 + 1
	rng.seed = s * 31 + 7
	prep_left = float(_level.get("prep_time", 30.0))
	match_left = float(_level.get("match_time", 300.0))
	Engine.time_scale = GameState.fast
	if GameState.fast > 1.0:
		# Zeitraffer (nur Tests): mehr Physik-Schritte statt größerer Schritte
		Engine.physics_ticks_per_second = int(60 * GameState.fast)
		Engine.max_physics_steps_per_frame = int(GameState.fast) * 4

	apt = ApartmentGen.new()
	apt.generate(s, _level)
	builder = ApartmentBuilder.new()
	add_child(builder.build(apt))
	spots = builder.spots
	nav = Nav.new()
	nav.setup(apt)

	_setup_environment()
	_spawn_characters()
	_setup_camera()
	_setup_overlays()

	hud = HudScript.new()
	add_child(hud)
	hud.setup(self)
	Sfx.reset_levels()
	Sfx.start_music()
	if GameState.shots_dir != "":
		_shot_times = [0.5, 8.0, 20.0, prep_left + 0.6, prep_left + 2.5, prep_left + 12.0,
			prep_left + 30.0, prep_left + 60.0, prep_left + 100.0]
	if GameState.touch_test:
		var tt := Node.new()
		tt.set_script(load("res://tests/touch_test.gd"))
		add_child(tt)
	print("LEVEL seed=%d size=%dx%d rooms=%d spots=%d openings=%d" % [s, apt.w, apt.h, apt.rooms.size(), spots.size(), apt.openings.size()])
	hud.announce("VERSTECK DICH!", "Die Zombies kommen in %d Sekunden" % int(prep_left), 3.5)


# ------------------------------------------------------------------ Aufbau

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.012, 0.018, 0.04)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.4, 0.5, 0.78)
	_env.ambient_light_energy = 0.5
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.5
	_env.glow_bloom = 0.05
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.08
	_env.adjustment_saturation = 1.08
	we.environment = _env
	add_child(we)
	# Mondlicht
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.66, 1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 60.0
	moon.shadow_opacity = 0.75
	add_child(moon)
	var d := Vector3(-0.38, -0.8, -0.55).normalized()
	moon.look_at_from_position(-d * 20.0, Vector3.ZERO)


func _spawn_characters() -> void:
	var used: Array[Vector2i] = []
	# Spieler startet im Schlafzimmer
	var bed_room := 0
	for r in apt.rooms:
		if r.type == ApartmentGen.RoomType.BEDROOM:
			bed_room = r.id
			break
	player = _make_char("Du", Cfg.SHIRT_COLORS[0], 0, GameState.as_zombie)
	player.is_player = true
	player.player_controlled = not GameState.autoplay
	if GameState.autoplay:
		player.brain = (ZombieAI.new(player, self) if GameState.as_zombie else HumanAI.new(player, self))
	var pc := nav.random_free_in_room(bed_room)
	used.append(pc)
	player.global_position = Nav.center(pc)
	var n_ai := int(_level.get("ai_humans", 3))
	for i in n_ai:
		var b := _make_char(Cfg.BOT_NAMES[i % Cfg.BOT_NAMES.size()], Cfg.SHIRT_COLORS[(i + 1) % Cfg.SHIRT_COLORS.size()], i + 1, false)
		b.brain = HumanAI.new(b, self)
		var cell := nav.random_free()
		for tries in 30:
			cell = nav.random_free()
			var ok := true
			for u in used:
				if Vector2(u - cell).length() < 4.0:
					ok = false
			if ok:
				break
		used.append(cell)
		b.global_position = Nav.center(cell)
		b.facing = rng.randf() * TAU
	_listener = AudioListener3D.new()
	_listener.position.y = 1.5
	player.add_child(_listener)
	_listener.make_current()


func _make_char(cname: String, shirt: Color, variant: int, zombie: bool) -> Character:
	var c := Character.new()
	add_child(c)
	c.setup(self, cname, shirt, variant, zombie)
	chars.append(c)
	return c


func _setup_camera() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = Cfg.CAM_SIZE
	cam.near = 0.5
	cam.far = 150.0
	cam.basis = Basis(Vector3.UP, deg_to_rad(Cfg.CAM_YAW_DEG)) * Basis(Vector3.RIGHT, deg_to_rad(Cfg.CAM_PITCH_DEG))
	add_child(cam)
	cam.global_position = _cam_pos_for(player.global_position)
	cam.make_current()


func _cam_pos_for(target: Vector3) -> Vector3:
	return target + Vector3(0, 1.0, 0) + cam.basis.z * 60.0


func _setup_overlays() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_vision = ColorRect.new()
	_vision.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vision.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/zombie_vision.gdshader")
	_vision.material = sm
	_vision.visible = false
	layer.add_child(_vision)

	# Wurfrichtungs-Pfeil für die Melone
	_aim_arrow = Node3D.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.3, 0.35, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	var shaft := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.02, 1.0)
	shaft.mesh = bm
	shaft.material_override = m
	shaft.position = Vector3(0, 0.08, 0.5)
	shaft.name = "Shaft"
	_aim_arrow.add_child(shaft)
	var head := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.6, 0.6, 0.02)
	head.mesh = pm
	head.material_override = m
	head.rotation.x = PI * 0.5
	head.name = "Head"
	_aim_arrow.add_child(head)
	_aim_arrow.visible = false
	add_child(_aim_arrow)


func _marker_for(c: Character) -> Node3D:
	if _markers.has(c):
		return _markers[c]
	var s := Sprite3D.new()
	var path := "res://assets/icons/marker_oval.png"
	if ResourceLoader.exists(path):
		s.texture = load(path)
	s.axis = Vector3.AXIS_Y
	s.pixel_size = 0.0105
	s.shaded = false
	s.no_depth_test = true
	s.modulate = Color(1.0, 0.92, 0.05)
	s.render_priority = 10
	s.visible = false
	add_child(s)
	_markers[c] = s
	return s


# ------------------------------------------------------------------ Abfragen

func humans() -> Array:
	return chars.filter(func(c): return c.is_active_human())


func zombies() -> Array:
	return chars.filter(func(c): return c.is_zombie)


## Sieht Zombie z den Menschen h? (Bewegung in Sichtlinie)
func can_see(z: Character, h: Character) -> bool:
	if h.hidden_in != null or h.frozen or h.is_zombie or h.turn_t > 0.0:
		return false
	var zp := z.global_position
	var hp := h.global_position
	var d := zp.distance_to(hp)
	if d > Cfg.sight_range(h.motion):
		return false
	if not z.player_controlled and d > 2.0:
		var to_h := (hp - zp).normalized()
		if z.facing_dir().dot(to_h) < cos(deg_to_rad(Cfg.ZOMBIE_FOV_DEG * 0.5)):
			return false
	return nav.los(zp, hp)


func nearest_spot_for(c: Character, reach := 1.35) -> HidingSpot:
	var best: HidingSpot = null
	var bd := reach
	for s in spots:
		if not s.has_room():
			continue
		var d := s.distance_to(c.global_position)
		if d < bd:
			bd = d
			best = s
	return best


# ------------------------------------------------------------------ Hauptschleife

func _physics_process(delta: float) -> void:
	if paused_logic:
		return
	time += delta
	_bite_cd = maxf(0.0, _bite_cd - delta)
	match phase:
		Phase.PREP:
			prep_left -= delta
			if prep_left <= 5.5 and not _spawned_outside:
				_spawn_zombies_outside()
			if prep_left <= 5.0:
				_tick_t -= delta
				if _tick_t <= 0.0:
					_tick_t = 1.0
					Sfx.play("tick", -4.0)
				_pound_t -= delta
				if _pound_t <= 0.0 and not _pending.is_empty():
					_pound_t = rng.randf_range(0.5, 0.9)
					var e: Dictionary = _pending[rng.randi_range(0, _pending.size() - 1)]
					Sfx.play_at("door_bang", e.win.pos, 2.0)
			if prep_left <= 0.0:
				_start_hunt()
		Phase.HUNT:
			match_left -= delta
			if not _all_turned_done():
				pass   # Verwandlung abwarten
			elif humans().size() <= 1:
				_end_game(false)
			elif match_left <= 0.0:
				_end_game(true)
		Phase.END:
			_end_t += delta
			if _end_t > 1.2:
				paused_logic = true
			return

	_apply_player_input()
	_update_pickups(delta)
	_update_audio_levels()
	for p in _noise_pings:
		p.t -= delta
	_noise_pings = _noise_pings.filter(func(p): return p.t > 0.0)

	if GameState.debug and int(time / 5.0) != int((time - delta) / 5.0):
		var line := "DBG t=%d" % int(time)
		for c in chars:
			var st := "?"
			if c.brain is ZombieAI:
				st = ZombieAI.S.keys()[c.brain.state]
			elif c.brain is HumanAI:
				st = HumanAI.S.keys()[c.brain.state]
			line += " | %s %s%s (%.1f,%.1f) L%d B%d" % [c.cname.left(8), st, "*H" if c.hidden_in != null else "", c.global_position.x, c.global_position.z, c.lives, c.bites]
		print(line)
	if GameState.quit_after > 0.0 and time >= GameState.quit_after:
		print("QUIT_AFTER time=%.1f phase=%d humans=%d zombies=%d" % [time, phase, humans().size(), zombies().size()])
		get_tree().quit()


func _all_turned_done() -> bool:
	for c in chars:
		if c.turn_t > 0.0:
			return false
	return true


func _apply_player_input() -> void:
	if not player.player_controlled:
		return
	var v: Vector2 = hud.move_vector()
	player.move_dir = cam_right * v.x + cam_fwd * v.y
	if player.is_zombie:
		player.want_listen = hud.listen_held
		player.want_sneak = false
		player.want_freeze = false
	else:
		player.want_sneak = hud.sneak_on
		player.want_freeze = hud.freeze_held
		player.want_listen = false
	if _aiming and not (player.has_melon and player.is_active_human() and player.hidden_in == null):
		_aiming = false
	if _aiming:
		_aim_dir = cam_right * hud.aim_vector.x + cam_fwd * hud.aim_vector.y
		if _aim_dir.length() < 0.2:
			_aim_dir = player.facing_dir()
		_aim_dir = _aim_dir.normalized()
		var land := _melon_landing(player.global_position, _aim_dir)
		var dist := player.global_position.distance_to(land)
		_aim_arrow.visible = true
		_aim_arrow.global_position = player.global_position
		_aim_arrow.rotation.y = atan2(_aim_dir.x, _aim_dir.z)
		var shaft: MeshInstance3D = _aim_arrow.get_node("Shaft")
		shaft.scale.z = maxf(0.3, dist - 0.3)
		shaft.position.z = (dist - 0.3) * 0.5
		var head: MeshInstance3D = _aim_arrow.get_node("Head")
		head.position = Vector3(0, 0.08, dist)
	else:
		_aim_arrow.visible = false


func _process(delta: float) -> void:
	_update_camera(delta)
	_update_visibility(delta)
	_update_lights(delta)
	if _shot_i < _shot_times.size() and time >= _shot_times[_shot_i]:
		_save_shot("shot_%02d_t%03d" % [_shot_i, int(time)])
		_shot_i += 1


func _save_shot(fname: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(GameState.shots_dir)
	img.save_png(GameState.shots_dir.path_join(fname + ".png"))


func _update_camera(delta: float) -> void:
	var target := player.global_position
	if GameState.follow != "":
		for c in chars:
			if c.cname.begins_with(GameState.follow):
				target = c.global_position
	if player.player_controlled and player.moving:
		target += player.velocity * 0.25
	var want := _cam_pos_for(target)
	cam.global_position = cam.global_position.lerp(want, clampf(delta * 5.0, 0, 1))


func _update_visibility(delta: float) -> void:
	zombie_view = player.is_zombie
	_vision_strength = move_toward(_vision_strength, 1.0 if zombie_view else 0.0, delta * 1.2)
	_vision.visible = _vision_strength > 0.01
	if _vision.visible:
		var sm: ShaderMaterial = _vision.material
		sm.set_shader_parameter("strength", _vision_strength)
		sm.set_shader_parameter("time_s", Time.get_ticks_msec() / 1000.0)
	var listen := zombie_view and player.listen_active()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 8.0)
	for c in chars:
		if c == player:
			continue
		var m: Node3D = _marker_for(c)
		if not c.is_active_human() or not zombie_view or phase == Phase.END:
			c.visible = true
			c.model.set_highlight(false)
			m.visible = false
			marker_on[c] = false
			continue
		var seen := can_see(player, c)
		c.visible = seen
		c.model.set_highlight(seen)
		var mark := c.noise_t > 0.0 or (listen and not c.frozen)
		marker_on[c] = mark
		m.visible = mark
		if mark:
			m.global_position = c.global_position + Vector3(0, 0.06, 0)
			var sc := 1.0 + 0.25 * pulse
			m.scale = Vector3(sc, sc, sc)
			m.modulate = Color(1.0, 0.92, 0.05, 0.7 + 0.3 * pulse)
	for s in spots:
		if s.eyes != null:
			s.eyes.visible = not zombie_view and s.count() > 0


func _update_lights(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in builder.lights.size():
		var e: Dictionary = builder.lights[i]
		var l: OmniLight3D = e.light
		var k := 1.0
		match e.mode:
			"flicker":
				k = 0.85 + 0.15 * sin(t * 13.0 + i) * sin(t * 7.3 + i * 2.0)
				if fmod(t + i * 3.7, 9.0) < 0.12:
					k = 0.25
			"tv":
				k = 0.65 + 0.35 * sin(t * 3.1 + sin(t * 11.0) * 2.0)
			"fluoro":
				var ph := fmod(t + i * 5.3, 11.0)
				if ph < 0.08 or (ph > 0.2 and ph < 0.26):
					k = 0.2
		l.light_energy = e.base * k


func _update_audio_levels() -> void:
	var chase := 0.0
	var heart := 0.0
	if phase == Phase.HUNT and not player.is_zombie and player.turn_t <= 0.0:
		var nd := INF
		for z in zombies():
			if z.busy:
				continue
			var d: float = z.global_position.distance_to(player.global_position)
			nd = minf(nd, d)
			if z.brain is ZombieAI and z.brain.target == player and z.brain.state == ZombieAI.S.CHASE:
				chase = 1.0
		heart = clampf((9.0 - nd) / 7.0, 0.0, 1.0)
		if player.hidden_in != null and player.hidden_in.sniffed_by != null:
			heart = 1.0
		chase = maxf(chase, clampf((4.0 - nd) / 4.0, 0.0, 1.0))
	elif phase == Phase.HUNT and player.is_zombie:
		chase = 0.5 if player.sprint_t > 0.0 else 0.0
	Sfx.chase_level = chase
	Sfx.heart_level = heart


# ------------------------------------------------------------------ Zombies kommen

func _spawn_zombies_outside() -> void:
	_spawned_outside = true
	var n := int(_level.get("zombies", 1))
	var wins: Array = builder.windows.filter(func(w): return not w.opening.is_empty())
	# nicht direkt neben dem Spieler einsteigen
	var scores := {}
	for w in wins:
		scores[w] = _opening_score(w)
	wins.sort_custom(func(a, b): return scores[a] > scores[b])
	for i in n:
		var win: Dictionary = wins[mini(i + (rng.randi_range(0, mini(2, wins.size() - 1 - i)) if i == 0 else 0), wins.size() - 1)]
		wins.erase(win)
		var z := _make_char("Zombie " + Cfg.ZOMBIE_NAMES[i % Cfg.ZOMBIE_NAMES.size()], Color(0.45, 0.4, 0.3), 5 + i, true)
		z.brain = ZombieAI.new(z, self)
		z.busy = true
		z.busy_pose = "enter"
		var o: Dictionary = win.opening
		var inside := Nav.center(o.inside)
		var out_dir := Vector3(o.out.x, 0, o.out.y)
		z.global_position = inside + out_dir * 1.35
		z.face_towards(inside)
		_pending.append({"z": z, "win": win, "inside": inside, "out": out_dir})


func _opening_score(win: Dictionary) -> float:
	var inside := Nav.center(win.opening.inside)
	var d := inside.distance_to(player.global_position)
	return clampf(d, 0.0, 9.0) + rng.randf() * 4.0


func _start_hunt() -> void:
	phase = Phase.HUNT
	if not _spawned_outside:
		_spawn_zombies_outside()
	Sfx.play("alarm", -2.0)
	hud.announce("DIE ZOMBIES KOMMEN!", "Renne nicht – sie hören dich.", 3.0)
	for e in _pending:
		_break_in(e)
	_pending.clear()


func _break_in(e: Dictionary) -> void:
	var z: Character = e.z
	var win: Dictionary = e.win
	var inside: Vector3 = e.inside
	var out_dir: Vector3 = e.out
	var edge_pos: Vector3 = inside + out_dir * 0.5
	if win.door != null:
		Sfx.play_at("door_break", win.pos, 6.0)
		var hinge: Node3D = win.door
		var tw := create_tween()
		tw.tween_property(hinge, "rotation:y", hinge.rotation.y + 1.75, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var p := Props.burst(Color(0.3, 0.2, 0.12), 14, 4.0, 0.1)
		add_child(p)
		p.global_position = win.pos
	else:
		Sfx.play_at("glass_break", win.pos, 6.0)
		if win.glass != null:
			win.glass.visible = false
		var p := Props.burst(Color(0.7, 0.85, 1.0, 0.8), 28, 4.5, 0.09, 1.1)
		add_child(p)
		p.global_position = win.pos
		p.direction = -out_dir + Vector3(0, 0.6, 0)
		# Scherben am Boden
		var shard_m := builder.glass_mat()
		for i in 7:
			var sh := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(rng.randf_range(0.06, 0.2), 0.01, rng.randf_range(0.05, 0.16))
			sh.mesh = bm
			sh.material_override = shard_m
			add_child(sh)
			sh.global_position = inside - out_dir * rng.randf_range(-0.2, 0.7) + Vector3(rng.randf_range(-0.5, 0.5), 0.01, rng.randf_range(-0.5, 0.5)) * Vector3(absf(out_dir.z), 1, absf(out_dir.x)) + Vector3(0, 0.005, 0)
			sh.rotation.y = rng.randf() * TAU
	# durchs Fenster / die Tür klettern
	var sill: float = win.sill
	var tw2 := create_tween()
	tw2.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw2.tween_interval(0.25)
	tw2.tween_property(z, "global_position", edge_pos + Vector3(0, sill * 0.8, 0), 0.45)
	tw2.tween_property(z, "global_position", inside, 0.4)
	tw2.tween_callback(func():
		z.busy = false
		z.stun_t = 0.4
		Sfx.play_at("zombie_scream", z.global_position, 0.0))
	emit_noise_ping(win.pos)


# ------------------------------------------------------------------ Geräusche

func emit_noise(pos: Vector3, radius: float, source: Character, lure: bool) -> void:
	if phase != Phase.HUNT:
		return
	for z in chars:
		if not z.is_zombie or z.busy or z == source:
			continue
		if lure or z.player_controlled or z.global_position.distance_to(pos) <= radius:
			z.hear(pos, lure)
	if lure:
		emit_noise_ping(pos)


func emit_noise_ping(pos: Vector3) -> void:
	_noise_pings.append({"pos": pos, "t": 1.5})


func noise_pings() -> Array[Dictionary]:
	return _noise_pings


# ------------------------------------------------------------------ Beißen

func try_bite(z: Character, h: Character) -> bool:
	if phase != Phase.HUNT or not z.is_zombie or not z.can_act():
		return false
	if not h.is_active_human() or h.invuln_t > 0.0 or h.garlic_t > 0.0:
		return false
	if h.hidden_in != null:
		hide_out(h)
	h.lives -= 1
	h.bites_taken += 1
	z.bites += 1
	z.stun_t = Cfg.BITE_STUN
	z.sprint_t = 0.0
	z.face_towards(h.global_position)
	z.model.play_bite()
	h.invuln_t = Cfg.INVULN_AFTER_BITE
	h.frozen = false
	h.model.play_hit()
	Sfx.play_at("zombie_bite", h.global_position, 3.0)
	Sfx.play_at("human_hurt", h.global_position, 0.0, 1.0 + 0.15 * (h.variant % 3))
	var p := Props.burst(Color(0.7, 0.02, 0.02), 16, 3.0, 0.07, 0.7)
	add_child(p)
	p.global_position = h.global_position + Vector3(0, 1.2, 0)
	if h.is_player:
		hud.flash(Color(0.8, 0.0, 0.0, 0.55))
		Input.vibrate_handheld(300)
		if h.lives > 0:
			hud.announce("GEBISSEN!", "Lauf weg – der Zombie ist 3 Sekunden abgelenkt. Noch %d Leben." % h.lives, 2.2)
	elif z.is_player:
		Input.vibrate_handheld(120)
		hud.toast("Du hast %s gebissen! (%d Bisse)" % [h.cname, z.bites])
	else:
		hud.toast("%s wurde von %s gebissen" % [h.cname, z.cname])
	if h.lives <= 0:
		h.start_turning()
		if h.is_player:
			hud.announce("DU WIRST ZUM ZOMBIE!", "", 2.2)
		else:
			hud.toast("%s verwandelt sich in einen Zombie!" % h.cname)
	elif h.brain is HumanAI:
		h.brain.on_bitten()
	return true


## Biss-Button des Spieler-Zombies.
func player_bite() -> void:
	if phase != Phase.HUNT or not player.is_zombie or not player.can_act() or _bite_cd > 0.0:
		return
	var best: Character = null
	var bd := INF
	for h in humans():
		if h.invuln_t > 0.0 or h.garlic_t > 0.0:
			continue
		var d := INF
		if h.hidden_in != null:
			var sd: float = h.hidden_in.distance_to(player.global_position)
			if sd < 1.0:
				d = sd
		else:
			var hd: float = h.global_position.distance_to(player.global_position)
			if hd < Cfg.BITE_RANGE + 0.3:
				d = hd
		if d < bd:
			bd = d
			best = h
	if best != null and try_bite(player, best):
		return
	# daneben
	_bite_cd = 0.7
	player.model.play_bite()
	Sfx.play_at("zombie_groan_2", player.global_position, -6.0, 1.4)


func player_sprint() -> void:
	if player.is_zombie and player.heard_t > 0.0 and player.can_act():
		player.try_sprint()


func on_turned(c: Character) -> void:
	if c.is_player and not GameState.autoplay:
		c.brain = null
		hud.set_zombie_mode(true)
		hud.announce("DU BIST JETZT EIN ZOMBIE", "Beiße die Menschen! Horche, um sie zu finden.", 3.5)
	else:
		c.brain = ZombieAI.new(c, self)
	hud.refresh_roster()


# ------------------------------------------------------------------ Verstecken

func hide_in(c: Character, spot: HidingSpot) -> bool:
	if not c.is_active_human() or c.hidden_in != null or c.busy:
		return false
	if not spot.has_room() or spot.distance_to(c.global_position) > 1.5:
		return false
	var idx := spot.add(c)
	if idx < 0:
		return false
	var slot := spot.slot_transform(idx)
	c.set_meta("hide_from", c.global_position)
	c.hidden_in = spot
	c.hide_pose = slot.pose
	c.set_collision_enabled(false)
	c.velocity = Vector3.ZERO
	c.global_position = slot.pos
	c.facing = slot.yaw
	c.rotation.y = c.facing
	c.frozen = false
	spot.wobble()
	Sfx.play_at("hide_in", spot.global_position, -2.0)
	return true


func hide_out(c: Character) -> void:
	var spot := c.hidden_in
	if spot == null:
		return
	spot.remove(c)
	c.hidden_in = null
	var from: Vector3 = c.get_meta("hide_from", c.global_position)
	c.global_position = spot.nearest_access(from)
	c.set_collision_enabled(true)
	spot.wobble()
	Sfx.play_at("hide_out", spot.global_position, -2.0)


func player_hide_toggle() -> void:
	if player.is_zombie or player.turn_t > 0.0 or phase == Phase.END:
		return
	if player.hidden_in != null:
		hide_out(player)
		return
	var s := nearest_spot_for(player)
	if s != null:
		if hide_in(player, s):
			hud.toast("Versteckt: %s" % s.label())
	else:
		hud.toast("Kein freies Versteck in Reichweite")


# ------------------------------------------------------------------ Upgrades

func _update_pickups(delta: float) -> void:
	if phase == Phase.END:
		return
	_pickup_t -= delta
	if _pickup_t <= 0.0:
		_pickup_t = rng.randf_range(Cfg.PICKUP_MIN_DELAY, Cfg.PICKUP_MAX_DELAY)
		if pickups.size() < Cfg.PICKUP_MAX:
			_spawn_pickup()
	for p in pickups.duplicate():
		for h in humans():
			if h.hidden_in != null or h.busy:
				continue
			if h.global_position.distance_to(p.global_position) < Cfg.PICKUP_RADIUS:
				_collect(h, p)
				break


func _spawn_pickup(kind := "", at := Vector3.INF) -> Pickup:
	if kind == "":
		kind = ["garlic", "souvlaki", "melon"][rng.randi_range(0, 2)]
	var pos := at
	if pos == Vector3.INF:
		for tries in 40:
			var cell := nav.random_free()
			pos = Nav.center(cell)
			var ok := apt.reserved[cell.y * apt.w + cell.x] == 0
			for c in chars:
				if c.global_position.distance_to(pos) < 3.0:
					ok = false
			for p in pickups:
				if p.global_position.distance_to(pos) < 4.0:
					ok = false
			if ok:
				break
	var p := Pickup.new()
	add_child(p)
	p.setup(kind)
	p.global_position = pos
	pickups.append(p)
	Sfx.play_at("upgrade_spawn", pos, 0.0)
	return p


func _collect(h: Character, p: Pickup) -> void:
	pickups.erase(p)
	h.lives = Cfg.MAX_LIVES
	Sfx.play_at("pickup", h.global_position, 0.0)
	match p.kind:
		"garlic":
			h.garlic_t = Cfg.GARLIC_TIME
			Sfx.play_at("garlic", h.global_position, 0.0)
			if h.is_player:
				hud.announce("KNOBLAUCH!", "Du stinkst 20 Sekunden – Zombies halten Abstand.", 2.5)
		"souvlaki":
			h.souvlaki_t = Cfg.SOUVLAKI_TIME
			Sfx.play_at("souvlaki", h.global_position, 0.0)
			if h.is_player:
				hud.announce("SOUVLAKI!", "20 Sekunden schneller als jeder Zombie.", 2.5)
		_:
			h.has_melon = true
			if h.is_player:
				hud.announce("WASSERMELONE!", "Melonen-Button halten, Richtung wählen, loslassen.", 3.0)
	if not h.is_player:
		hud.toast("%s: %s" % [h.cname, Props.kind_name(p.kind)])
	p.queue_free()


func set_aiming(on: bool) -> void:
	_aiming = on and player.has_melon and not player.is_zombie and player.hidden_in == null


func player_throw() -> void:
	if not _aiming:
		return
	_aiming = false
	_aim_arrow.visible = false
	if player.has_melon and player.is_active_human() and player.hidden_in == null:
		throw_melon(player, _aim_dir if _aim_dir.length() > 0.1 else player.facing_dir())


func _melon_landing(from: Vector3, dir: Vector3) -> Vector3:
	var best := from + dir * 0.8
	var d := 1.0
	while d <= Cfg.MELON_RANGE:
		var p := from + dir * d
		var cell := Nav.cell_of(p)
		if not apt.in_bounds(cell.x, cell.y) or not nav.los(from, p):
			break
		if not apt.is_blocked(cell.x, cell.y):
			best = p
		d += 0.25
	return Vector3(best.x, 0, best.z)


func throw_melon(c: Character, dir: Vector3) -> void:
	if not c.has_melon or c.hidden_in != null:
		return
	c.has_melon = false
	c.face_towards(c.global_position + dir)
	var from := c.global_position
	var land := _melon_landing(from, dir.normalized())
	Sfx.play_at("melon_throw", from, 0.0)
	var m := Props.melon_mesh(0.2)
	add_child(m)
	m.global_position = from + Vector3(0, 1.4, 0)
	var dur := 0.35 + from.distance_to(land) * 0.06
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_method(func(t: float):
		var p := from.lerp(land, t)
		p.y = 1.4 * (1.0 - t) + sin(t * PI) * 1.6 + 0.2 * t
		m.global_position = p
		m.rotation.x = t * 9.0, 0.0, 1.0, dur)
	tw.tween_callback(func():
		m.queue_free()
		var splat := Props.melon_splat()
		add_child(splat)
		splat.global_position = land
		var b := Props.burst(Color(0.9, 0.15, 0.2), 26, 4.0, 0.1, 0.8)
		add_child(b)
		b.global_position = land + Vector3(0, 0.2, 0)
		Sfx.play_at("melon_splat", land, 6.0)
		emit_noise(land, 999.0, c, true)
		hud.toast("%s wirft eine Melone – die Zombies rennen hin!" % ("Du" if c.is_player else c.cname))
		get_tree().create_timer(25.0, false).timeout.connect(splat.queue_free))


# ------------------------------------------------------------------ Spielende

func _end_game(sunrise: bool) -> void:
	phase = Phase.END
	_aiming = false
	_aim_arrow.visible = false
	var hs := humans()
	var top: Character = null
	for z in zombies():
		if z.bites > 0 and (top == null or z.bites > top.bites):
			top = z
	var player_wins := false
	var headline := ""
	var sub := ""
	if not player.is_zombie:
		player_wins = true
		headline = "ÜBERLEBT!" if sunrise and hs.size() > 1 else "DU BIST DER LETZTE MENSCH!"
		sub = "Die Sonne geht über Athen auf." if sunrise else "Alle anderen wurden zu Zombies."
	elif top == player:
		player_wins = true
		headline = "BESTER ZOMBIE!"
		sub = "Du hast die meisten Bisse (%d)." % player.bites
	else:
		headline = "VERLOREN"
		if hs.size() >= 1:
			sub = "%s hat als Mensch überlebt." % ", ".join(hs.map(func(h): return h.cname))
		if top != null:
			sub += "  Bester Zombie: %s (%d Bisse)." % [top.cname, top.bites]
	results = {"sunrise": sunrise, "humans": hs, "top_zombie": top, "player_wins": player_wins,
		"headline": headline, "sub": sub}
	Sfx.reset_levels()
	Sfx.play("win" if player_wins else "lose", 0.0)
	hud.show_end(results)
	print("RESULT sunrise=%s time=%.1f survivors=%s top=%s player_wins=%s" % [
		sunrise, time, hs.map(func(h): return h.cname),
		(top.cname + ":" + str(top.bites)) if top != null else "-", player_wins])
	if GameState.shots_dir != "":
		get_tree().create_timer(0.5, true, false, true).timeout.connect(func(): _save_shot("shot_end"))
	if GameState.autoplay and GameState.quit_after > 0.0:
		get_tree().create_timer(1.0, true, false, true).timeout.connect(get_tree().quit)


func restart() -> void:
	_reset_engine()
	get_tree().reload_current_scene()


func to_menu() -> void:
	_reset_engine()
	Sfx.reset_levels()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _reset_engine() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 8

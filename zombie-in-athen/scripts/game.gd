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
var net := false               # Netzwerk-Runde
var is_host := false           # dieses Gerät rechnet das Spiel
var is_client := false         # dieses Gerät zeigt nur an und schickt Eingaben

var _level: Dictionary
var _markers := {}             # Character -> Sprite3D
var _pending: Array[Dictionary] = []   # Zombies, die draußen warten: {z, win}
var _spawned_outside := false
var _pickup_t := Cfg.PICKUP_FIRST
var _tick_t := 0.0
var _pound_t := 0.0
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
var _waiting := false          # Gastgeber wartet, bis alle die Szene geladen haben
var _wait_t := 0.0
var _begun := false
var _snap_tick := 0
var _next_pickup_id := 1
var _net_pickups := {}         # Client: net_id -> Pickup
var _bot_t := 0.0              # Test-Bot auf einem Client
var _bot_dir := Vector3.ZERO
var _bot_flags := 0

var _ai_zombies := 1            # Computer-Zombies, die nach der Vorbereitungszeit kommen
var _puddles: Array[Dictionary] = []   # Ölpfützen: {id, pos, t, uses, node}
var _next_puddle_id := 1

const NF := 28                 # Zahlen je Figur im Schnappschuss
const POSES := ["inside", "lie", "crouch", "enter"]


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

	net = Net.active()
	is_host = Net.is_host()
	is_client = Net.is_client()
	if net:
		Net.game = self

	_setup_environment()
	_setup_camera()
	_setup_overlays()
	Sfx.reset_levels()
	Sfx.start_music()
	print("LEVEL seed=%d size=%dx%d rooms=%d spots=%d openings=%d" % [s, apt.w, apt.h, apt.rooms.size(), spots.size(), apt.openings.size()])
	if is_client:
		# Figuren und Spielzustand kommen vom Gastgeber (net_begin / net_snapshot)
		paused_logic = true
		Net.send_ready()
		return
	_spawn_characters()
	_attach_player()
	if GameState.touch_test:
		var tt := Node.new()
		tt.set_script(load("res://tests/touch_test.gd"))
		add_child(tt)
	if GameState.items_test:
		var it := Node.new()
		it.set_script(load("res://tests/items_test.gd"))
		add_child(it)
	if is_host and Net.players.size() > 1:
		_waiting = true
		paused_logic = true
		hud.announce("WARTE AUF MITSPIELER", "", 30.0)
	else:
		_begin()


func _exit_tree() -> void:
	if Net.game == self:
		Net.game = null


func _begin() -> void:
	_waiting = false
	paused_logic = false
	_begun = true
	if is_host:
		Net.send_begin(_roster())
	_intro()


## Ansage zum Rundenstart – je nachdem, ob man selbst der Zombie ist.
func _intro() -> void:
	var zname := ""
	for c in chars:
		if c.started_as_zombie and c.owner_peer != 0:
			zname = c.cname
	if player.started_as_zombie and not GameState.as_zombie:
		hud.announce("DU BIST DER ZOMBIE!", "In %d Sekunden brichst du ein. Wähle dein Fenster." % int(prep_left), 4.5)
	elif zname != "":
		hud.announce("VERSTECK DICH!", "%s ist der Zombie und kommt in %d Sekunden" % [zname, int(prep_left)], 4.5)
	else:
		hud.announce("VERSTECK DICH!", "Die Zombies kommen in %d Sekunden" % int(prep_left), 3.5)


## Kamera, Ohr und HUD an die Figur dieses Geräts hängen.
func _attach_player() -> void:
	player.is_player = true
	_listener = AudioListener3D.new()
	_listener.position.y = 1.5
	player.add_child(_listener)
	_listener.make_current()
	cam.global_position = _cam_pos_for(player.global_position)
	hud = HudScript.new()
	add_child(hud)
	hud.setup(self)
	if GameState.shots_dir != "":
		_shot_times = [0.5, 8.0, 20.0, prep_left + 0.6, prep_left + 2.5, prep_left + 12.0,
			prep_left + 30.0, prep_left + 60.0, prep_left + 100.0]


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
	# menschliche Spieler: allein "Du", im Netzwerk alle aus der Lobby (Gastgeber zuerst)
	var entries: Array = []      # [Name, Peer, Aussehen [Farbe, Frisur, Haarfarbe, Hut]]
	if net:
		var ids: Array = Net.players.keys()
		ids.sort()
		for id in ids:
			entries.append([Net.players[id], id, Net.looks.get(id, [0, 0, 0, 0])])
	else:
		entries.append(["Du", 0, GameState.look_array()])
	# Start-Zombie: im Mehrspieler ein zufällig ausgeloster Spieler statt eines Computer-Zombies
	var zi := -1
	if net and Net.player_zombie and entries.size() >= 2:
		zi = rng.randi_range(0, entries.size() - 1)
	_ai_zombies = maxi(0, int(_level.get("zombies", 1)) - (1 if zi >= 0 else 0))
	var n_players_human := entries.size() - (1 if zi >= 0 else 0)
	var n_bots := maxi(0, 1 + int(_level.get("ai_humans", 3)) - n_players_human)
	var bed_room := 0
	for r in apt.rooms:
		if r.type == ApartmentGen.RoomType.BEDROOM:
			bed_room = r.id
			break
	var used: Array[Vector2i] = []
	var used_colors := {}
	var zombie_char: Character = null
	for i in entries.size():
		var lk: Array = entries[i][2]
		var ci := clampi(int(lk[0]), 0, Cfg.SHIRT_COLORS.size() - 1)
		used_colors[ci] = true
		var owner: int = entries[i][1]
		var local: bool = (not net) or owner == Net.my_id()
		var zombie: bool = i == zi or (local and GameState.as_zombie)
		var c := _make_char(entries[i][0], Cfg.SHIRT_COLORS[ci], i, zombie, [int(lk[1]), int(lk[2]), int(lk[3])])
		c.owner_peer = owner
		if local:
			player = c
			c.player_controlled = not GameState.autoplay
			if GameState.autoplay:
				c.brain = (ZombieAI.new(c, self) if zombie else HumanAI.new(c, self))
		else:
			c.player_controlled = true
		if i == zi:
			zombie_char = c
		else:
			_place_start(c, used, bed_room)
	var next_color := 0
	for b in n_bots:
		while used_colors.has(next_color) and next_color < Cfg.SHIRT_COLORS.size() - 1:
			next_color += 1
		used_colors[next_color] = true
		# Computerspieler bekommen zufällige Frisuren und manchmal einen Hut
		var look := [rng.randi_range(0, Cfg.HAIR_NAMES.size() - 1), rng.randi_range(0, 4),
			rng.randi_range(1, Cfg.HAT_NAMES.size() - 1) if rng.randf() < 0.4 else 0]
		var c := _make_char(Cfg.BOT_NAMES[b % Cfg.BOT_NAMES.size()], Cfg.SHIRT_COLORS[next_color], chars.size(), false, look)
		c.brain = HumanAI.new(c, self)
		_place_start(c, used, bed_room)
	if zombie_char != null:
		# der Spieler-Zombie wartet von Anfang an draußen vor einem Fenster
		var wins := _free_openings()
		_wait_outside(zombie_char, wins[rng.randi_range(0, mini(3, wins.size() - 1))])


## Startplatz: der erste im Schlafzimmer, alle mit Abstand zueinander.
func _place_start(c: Character, used: Array[Vector2i], bed_room: int) -> void:
	var cell := nav.random_free_in_room(bed_room) if used.is_empty() else nav.random_free()
	if not used.is_empty():
		for tries in 30:
			cell = nav.random_free()
			var ok := true
			for u in used:
				if Vector2(u - cell).length() < 4.0:
					ok = false
			if ok:
				break
		c.facing = rng.randf() * TAU
	used.append(cell)
	c.global_position = Nav.center(cell)


func _make_char(cname: String, shirt: Color, variant: int, zombie: bool, look: Array = [-1, -1, 0]) -> Character:
	var c := Character.new()
	add_child(c)
	c.setup(self, cname, shirt, variant, zombie, look)
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
	cam.global_position = _cam_pos_for(Vector3(apt.w * 0.5, 0, apt.h * 0.5))
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
	if _waiting:
		_wait_t += delta
		if Net.all_ready() or _wait_t > 8.0:
			_begin()
		return
	if is_client:
		_client_tick(delta)
		return
	if paused_logic:
		return
	time += delta
	if is_host:
		_snap_tick += 1
		if _snap_tick % 2 == 0:
			Net.send_snapshot(_make_snapshot())
	match phase:
		Phase.PREP:
			prep_left -= delta
			if prep_left <= 5.5 and not _spawned_outside:
				_spawn_zombies_outside()
			if prep_left <= 5.0:
				_tick_t -= delta
				if _tick_t <= 0.0:
					_tick_t = 1.0
					Sfx.play_all("tick", -4.0)
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
	_update_puddles(delta)
	_update_audio_levels()
	for p in _noise_pings:
		p.t -= delta
	_noise_pings = _noise_pings.filter(func(p): return p.t > 0.0)

	_debug_line(delta)
	if GameState.quit_after > 0.0 and time >= GameState.quit_after:
		print("QUIT_AFTER time=%.1f phase=%d humans=%d zombies=%d" % [time, phase, humans().size(), zombies().size()])
		get_tree().quit()


func _debug_line(delta: float) -> void:
	if not GameState.debug or int(time / 5.0) == int((time - delta) / 5.0):
		return
	var line := "DBG t=%d ph=%d" % [int(time), phase]
	for c in chars:
		var st := "-"
		if c.brain is ZombieAI:
			st = ZombieAI.S.keys()[c.brain.state]
		elif c.brain is HumanAI:
			st = HumanAI.S.keys()[c.brain.state]
		line += " | %s %s%s%s (%.1f,%.1f) L%d B%d" % [c.cname.left(8), st, "*H" if c.hidden_in != null else "", "*Z" if c.is_zombie else "", c.global_position.x, c.global_position.z, c.lives, c.bites]
	line += " | pickups=%d" % pickups.size()
	print(line)


func _all_turned_done() -> bool:
	for c in chars:
		if c.turn_t > 0.0:
			return false
	return true


func _apply_player_input() -> void:
	if player == null or not player.player_controlled:
		return
	var v: Vector2 = hud.move_vector()
	var mv := cam_right * v.x + cam_fwd * v.y
	var flags := 0     # Bit 1 = leise, 2 = stillstehen, 4 = horchen
	if player.is_zombie:
		if hud.listen_held:
			flags |= 4
	else:
		if hud.sneak_on:
			flags |= 1
		if hud.freeze_held:
			flags |= 2
	if is_client:
		if GameState.autoplay:
			_bot_input()
			mv = _bot_dir
			flags = _bot_flags
		Net.send_input(mv.x, mv.z, flags)
	else:
		_set_input(player, mv, flags)
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
	if player == null:
		return
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
	if GameState.overview > 0.0:
		cam.size = GameState.overview
		cam.global_position = _cam_pos_for(Vector3(apt.w * 0.5, 0, apt.h * 0.5))
		return
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
			elif z.puppet and z.net_chase >= 0 and z.net_chase == chars.find(player):
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
	var wins := _free_openings()
	for i in _ai_zombies:
		if wins.is_empty():
			break
		var win: Dictionary = wins[rng.randi_range(0, mini(2, wins.size() - 1))]
		wins.erase(win)
		var z := _make_char("Zombie " + Cfg.ZOMBIE_NAMES[i % Cfg.ZOMBIE_NAMES.size()], Color(0.45, 0.4, 0.3), 5 + i, true)
		z.brain = ZombieAI.new(z, self)
		_wait_outside(z, win)
		Net.send_event("spawn", [_roster_entry(z)])


## Fenster und Türen, vor denen noch kein Zombie wartet – die von Menschen entferntesten zuerst.
func _free_openings() -> Array:
	var wins: Array = builder.windows.filter(func(w):
		if w.opening.is_empty():
			return false
		for e in _pending:
			if e.win == w:
				return false
		return true)
	var scores := {}
	for w in wins:
		scores[w] = _opening_score(w)
	wins.sort_custom(func(a, b): return scores[a] > scores[b])
	return wins


func _wait_outside(z: Character, win: Dictionary) -> void:
	z.busy = true
	z.busy_pose = "enter"
	var entry := {"z": z, "win": win, "inside": Vector3.ZERO, "out": Vector3.ZERO}
	for e in _pending:
		if e.z == z:
			entry = e
	if not _pending.has(entry):
		_pending.append(entry)
	var o: Dictionary = win.opening
	entry.win = win
	entry.inside = Nav.center(o.inside)
	entry.out = Vector3(o.out.x, 0, o.out.y)
	z.global_position = entry.inside + entry.out * 1.35
	z.face_towards(entry.inside)


## Spieler-Zombie wählt während der Vorbereitungszeit ein anderes Fenster.
func _act_window(c: Character) -> void:
	if phase != Phase.PREP or not c.busy:
		return
	for e in _pending:
		if e.z != c:
			continue
		var all: Array = builder.windows.filter(func(w): return not w.opening.is_empty())
		var idx := all.find(e.win)
		for k in range(1, all.size()):
			var cand: Dictionary = all[(idx + k) % all.size()]
			var taken := false
			for o in _pending:
				if o != e and o.win == cand:
					taken = true
			if not taken:
				_wait_outside(c, cand)
				return


func _opening_score(win: Dictionary) -> float:
	# nicht direkt neben einem Menschen einsteigen
	var inside := Nav.center(win.opening.inside)
	var d := 9.0
	for h in humans():
		d = minf(d, inside.distance_to(h.global_position))
	return d + rng.randf() * 4.0


func _start_hunt() -> void:
	phase = Phase.HUNT
	if not _spawned_outside:
		_spawn_zombies_outside()
	Sfx.play_all("alarm", -2.0)
	_announce_all("DIE ZOMBIES KOMMEN!", "Renne nicht – sie hören dich.", 3.0)
	for e in _pending:
		_break_in(e)
	_pending.clear()


func _break_in(e: Dictionary) -> void:
	var z: Character = e.z
	var win: Dictionary = e.win
	var inside: Vector3 = e.inside
	var out_dir: Vector3 = e.out
	var edge_pos: Vector3 = inside + out_dir * 0.5
	var idx := builder.windows.find(win)
	Sfx.play_at("door_break" if win.door != null else "glass_break", win.pos, 6.0)
	_break_fx(idx)
	Net.send_event("break", [idx])
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


## Sichtbare Folgen eines Einbruchs (läuft auf jedem Gerät).
func _break_fx(idx: int) -> void:
	if idx < 0 or idx >= builder.windows.size():
		return
	var win: Dictionary = builder.windows[idx]
	var inside := Nav.center(win.opening.inside)
	var out_dir := Vector3(win.opening.out.x, 0, win.opening.out.y)
	if win.door != null:
		var hinge: Node3D = win.door
		var tw := create_tween()
		tw.tween_property(hinge, "rotation:y", hinge.rotation.y + 1.75, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var p := Props.burst(Color(0.3, 0.2, 0.12), 14, 4.0, 0.1)
		add_child(p)
		p.global_position = win.pos
		return
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
		bm.size = Vector3(randf_range(0.06, 0.2), 0.01, randf_range(0.05, 0.16))
		sh.mesh = bm
		sh.material_override = shard_m
		add_child(sh)
		var side := Vector3(absf(out_dir.z), 0, absf(out_dir.x)) * randf_range(-0.5, 0.5)
		sh.global_position = inside - out_dir * randf_range(-0.2, 0.7) + side + Vector3(0, 0.015, 0)
		sh.rotation.y = randf() * TAU


# ------------------------------------------------------------------ Geräusche

func emit_noise(pos: Vector3, radius: float, source: Character, lure: bool) -> void:
	if phase != Phase.HUNT or is_client:
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
	Net.send_fx("ping", [pos])


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
	_fx("blood", h.global_position + Vector3(0, 1.2, 0))
	_hit_to(h)
	if h.lives > 0:
		_announce_to(h, "GEBISSEN!", "Lauf weg – der Zombie ist 3 Sekunden abgelenkt. Noch %d Leben." % h.lives, 2.2)
	_toast_to(z, "Du hast %s gebissen! (%d Bisse)" % [h.cname, z.bites])
	_toast_others("%s wurde von %s gebissen" % [h.cname, z.cname], [h, z])
	if h.lives <= 0:
		h.start_turning()
		_announce_to(h, "DU WIRST ZUM ZOMBIE!", "", 2.2)
		_toast_others("%s verwandelt sich in einen Zombie!" % h.cname, [h])
	elif h.brain is HumanAI:
		h.brain.on_bitten()
	return true


# ------------------------------------------------------------------ Aktionen der Spieler
# Die Buttons im HUD rufen player_*() auf. Auf dem Gastgeber (oder allein) wird die
# Aktion direkt ausgeführt, ein Client schickt sie an den Gastgeber.

func player_bite() -> void:
	_request("bite")


func player_sprint() -> void:
	_request("sprint")


func player_window() -> void:
	_request("window")


func player_oil() -> void:
	_request("oil")





func _request(kind: String, arg := Vector3.ZERO) -> void:
	if player == null or phase == Phase.END:
		return
	if is_client:
		Net.send_action(kind, arg)
	else:
		_do_action(player, kind, arg)


func _do_action(c: Character, kind: String, arg: Vector3) -> void:
	match kind:
		"hide":
			_act_hide(c)
		"bite":
			_act_bite(c)
		"sprint":
			if c.is_zombie and c.heard_t > 0.0 and c.can_act():
				c.try_sprint()
		"window":
			_act_window(c)
		"oil":
			drop_oil(c)
		"throw":
			if c.has_melon and c.is_active_human() and c.hidden_in == null:
				var d := Vector3(arg.x, 0, arg.z)
				throw_melon(c, d.normalized() if d.length() > 0.1 else c.facing_dir())


func _set_input(c: Character, mv: Vector3, flags: int) -> void:
	c.move_dir = Vector3(mv.x, 0, mv.z).limit_length(1.0)
	if c.is_zombie:
		c.want_listen = (flags & 4) != 0
		c.want_sneak = false
		c.want_freeze = false
	else:
		c.want_sneak = (flags & 1) != 0
		c.want_freeze = (flags & 2) != 0
		c.want_listen = false


## Biss eines von einem Menschen gesteuerten Zombies.
func _act_bite(c: Character) -> void:
	if phase != Phase.HUNT or not c.is_zombie or not c.can_act() or c.bite_cd > 0.0:
		return
	var best: Character = null
	var bd := INF
	for h in humans():
		if h.invuln_t > 0.0 or h.garlic_t > 0.0:
			continue
		var d := INF
		if h.hidden_in != null:
			var sd: float = h.hidden_in.distance_to(c.global_position)
			if sd < 1.0:
				d = sd
		else:
			var hd: float = h.global_position.distance_to(c.global_position)
			if hd < Cfg.BITE_RANGE + 0.3:
				d = hd
		if d < bd:
			bd = d
			best = h
	if best != null and try_bite(c, best):
		return
	# daneben
	c.bite_cd = 0.7
	c.model.play_bite()
	Sfx.play_at("zombie_groan_2", c.global_position, -6.0, 1.4)


func _act_hide(c: Character) -> void:
	if c.is_zombie or c.turn_t > 0.0 or phase == Phase.END:
		return
	if c.hidden_in != null:
		hide_out(c)
		return
	var s := nearest_spot_for(c)
	if s != null:
		if hide_in(c, s):
			_toast_to(c, "Versteckt: %s" % s.label())
	else:
		_toast_to(c, "Kein freies Versteck in Reichweite")


func on_turned(c: Character) -> void:
	if c.player_controlled:
		c.brain = null
		if c == player:
			hud.set_zombie_mode(true)
		_announce_to(c, "DU BIST JETZT EIN ZOMBIE", "Beiße die Menschen! Horche, um sie zu finden.", 3.5)
	else:
		c.brain = ZombieAI.new(c, self)


# --- Meldungen an einzelne oder alle Spieler (lokal oder übers Netz)

func _is_remote(c: Character) -> bool:
	return is_host and c.owner_peer > 1


func _announce_to(c: Character, title: String, sub: String, dur: float) -> void:
	if c == player:
		hud.announce(title, sub, dur)
	elif _is_remote(c):
		Net.send_event("ann", [title, sub, dur], c.owner_peer)


func _announce_all(title: String, sub: String, dur: float) -> void:
	hud.announce(title, sub, dur)
	Net.send_event("ann", [title, sub, dur])


func _toast_to(c: Character, text: String) -> void:
	if c == player:
		hud.toast(text)
	elif _is_remote(c):
		Net.send_event("toast", [text], c.owner_peer)


func _toast_others(text: String, skip: Array) -> void:
	if not skip.has(player):
		hud.toast(text)
	if is_host:
		for c in chars:
			if c.owner_peer > 1 and not skip.has(c):
				Net.send_event("toast", [text], c.owner_peer)


func _hit_to(c: Character) -> void:
	if c == player:
		hud.flash(Color(0.8, 0.0, 0.0, 0.55))
		Input.vibrate_handheld(300)
	elif _is_remote(c):
		Net.send_event("hit", [], c.owner_peer)


## Partikel-Effekt auf allen Geräten.
func _fx(kind: String, pos: Vector3) -> void:
	_fx_local(kind, pos)
	Net.send_fx("fx", [kind, pos])


func _fx_local(kind: String, pos: Vector3) -> void:
	var p: CPUParticles3D
	match kind:
		"blood":
			p = Props.burst(Color(0.7, 0.02, 0.02), 16, 3.0, 0.07, 0.7)
		_:
			p = Props.burst(Color(0.9, 0.15, 0.2), 26, 4.0, 0.1, 0.8)
	add_child(p)
	p.global_position = pos


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
	if is_client and player.hidden_in == null and player.is_active_human() and nearest_spot_for(player) == null:
		hud.toast("Kein freies Versteck in Reichweite")
		return
	_request("hide")


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
		kind = Cfg.PICKUP_KINDS[rng.randi_range(0, Cfg.PICKUP_KINDS.size() - 1)]
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
	p.net_id = _next_pickup_id
	_next_pickup_id += 1
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
			_announce_to(h, "KNOBLAUCH!", "Du stinkst 20 Sekunden – Zombies halten Abstand.", 2.5)
		"souvlaki":
			h.souvlaki_t = Cfg.SOUVLAKI_TIME
			Sfx.play_at("souvlaki", h.global_position, 0.0)
			_announce_to(h, "SOUVLAKI!", "20 Sekunden schneller als jeder Zombie.", 2.5)
		"oil":
			h.has_oil = true
			_announce_to(h, "OLIVENÖL!", "Öl-Button: Pfütze legen – Zombies rutschen darauf aus.", 3.0)
		"frappe":
			h.frappe_t = Cfg.FRAPPE_TIME
			h.freeze_left = Cfg.FREEZE_MAX
			h.freeze_lock = 0.0
			Sfx.play_at("frappe", h.global_position, 0.0)
			_announce_to(h, "FRAPPÉ!", "20 Sekunden leise UND schnell. Stillstehen ist aufgefüllt.", 3.0)
		_:
			h.has_melon = true
			_announce_to(h, "WASSERMELONE!", "Melonen-Button halten, Richtung wählen, loslassen.", 3.0)
	_toast_others("%s: %s" % [h.cname, Props.kind_name(p.kind)], [h])
	p.queue_free()


# --- Olivenöl

## Legt eine Ölpfütze hinter die Figur (Spieler-Button oder KI).
func drop_oil(c: Character) -> void:
	if is_client or not c.has_oil or not c.is_active_human() or c.hidden_in != null:
		return
	c.has_oil = false
	var pos := c.global_position - c.facing_dir() * 0.3
	pos.y = 0.0
	var id := _next_puddle_id
	_next_puddle_id += 1
	_add_puddle(id, pos)
	Net.send_event("oil", [id, pos])
	Sfx.play_at("oil", pos, 2.0)
	_toast_to(c, "Ölpfütze gelegt – Zombies rutschen darauf aus.")
	_toast_others("%s legt eine Ölpfütze" % c.cname, [c])


func _add_puddle(id: int, pos: Vector3) -> void:
	var node := Props.oil_puddle()
	add_child(node)
	node.global_position = pos
	_puddles.append({"id": id, "pos": pos, "t": Cfg.OIL_TIME, "uses": Cfg.OIL_USES, "node": node})


func _remove_puddle(id: int) -> void:
	for p in _puddles:
		if p.id == id:
			p.node.queue_free()
			_puddles.erase(p)
			return


func _update_puddles(delta: float) -> void:
	for p in _puddles.duplicate():
		p.t -= delta
		for z in chars:
			if not z.is_zombie or z.busy or z.slip_t > 0.0 or z.slip_cd > 0.0 or not z.moving:
				continue
			if z.global_position.distance_to(p.pos) < Cfg.OIL_RADIUS:
				z.slip()
				p.uses -= 1
				_announce_to(z, "AUSGERUTSCHT!", "", 1.5)
				_toast_others("%s rutscht auf dem Öl aus!" % z.cname, [z])
		if p.t <= 0.0 or p.uses <= 0:
			Net.send_event("oil_gone", [p.id])
			_remove_puddle(p.id)


func set_aiming(on: bool) -> void:
	_aiming = on and player.has_melon and not player.is_zombie and player.hidden_in == null


func player_throw() -> void:
	if not _aiming:
		return
	_aiming = false
	_aim_arrow.visible = false
	if player.has_melon and player.is_active_human() and player.hidden_in == null:
		_request("throw", _aim_dir if _aim_dir.length() > 0.1 else player.facing_dir())


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
	var dur := 0.35 + from.distance_to(land) * 0.06
	Sfx.play_at("melon_throw", from, 0.0)
	_melon_fx(from, land, dur)
	Net.send_event("melon", [from, land, dur])
	_toast_to(c, "Melone geworfen – die Zombies rennen hin!")
	_toast_others("%s wirft eine Melone – die Zombies rennen hin!" % c.cname, [c])
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_interval(dur)
	tw.tween_callback(func():
		Sfx.play_at("melon_splat", land, 6.0)
		emit_noise(land, 999.0, c, true))


## Flug und Aufprall der Melone (nur Optik, läuft auf jedem Gerät).
func _melon_fx(from: Vector3, land: Vector3, dur: float) -> void:
	var m := Props.melon_mesh(0.2)
	add_child(m)
	m.global_position = from + Vector3(0, 1.4, 0)
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
		_fx_local("melon", land + Vector3(0, 0.2, 0))
		get_tree().create_timer(25.0, false).timeout.connect(splat.queue_free))


# ------------------------------------------------------------------ Spielende

func _end_game(sunrise: bool) -> void:
	var top: Character = null
	for z in zombies():
		if z.bites > 0 and (top == null or z.bites > top.bites):
			top = z
	var stats: Array = []
	for c in chars:
		stats.append([c.is_zombie, c.lives, c.bites, c.bites_taken])
	Net.send_event("end", [sunrise, chars.find(top), stats])
	_finish(sunrise, top)


## Endbildschirm aus Sicht des Spielers an diesem Gerät.
func _finish(sunrise: bool, top: Character) -> void:
	phase = Phase.END
	_aiming = false
	_aim_arrow.visible = false
	var hs := humans()
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
		else:
			sub = "Kein Mensch hat überlebt."
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
	print("STATS " + " ".join(chars.map(func(c): return "%s:%s:%d:%d:%d" % [c.cname.replace(" ", "_"), "Z" if c.is_zombie else "H", c.lives, c.bites, c.bites_taken])))
	if GameState.shots_dir != "":
		get_tree().create_timer(0.5, true, false, true).timeout.connect(func(): _save_shot("shot_end"))
	if net and GameState.rematch > 0:
		# nur für automatische Tests: der Gastgeber startet eine weitere Runde
		GameState.rematch -= 1
		if is_host:
			get_tree().create_timer(2.0, true, false, true).timeout.connect(restart)
		return
	if GameState.autoplay and GameState.quit_after > 0.0:
		# der Gastgeber wartet kurz, damit die Clients ihr Ergebnis noch bekommen
		get_tree().create_timer(3.0 if is_host else 1.0, true, false, true).timeout.connect(get_tree().quit)


func restart() -> void:
	_reset_engine()
	if is_host:
		Net.start_match()
	elif not net:
		get_tree().reload_current_scene()


func to_menu() -> void:
	_reset_engine()
	Sfx.reset_levels()
	if net:
		Net.leave()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _reset_engine() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 8


# ------------------------------------------------------------------ Netzwerk
# Gastgeber: schickt Aufstellung, Schnappschüsse und Ereignisse.
# Client: baut daraus die Anzeige; eigene Logik läuft dort nicht.

func _roster_entry(c: Character) -> Array:
	return [c.cname, c.shirt, c.variant, c.started_as_zombie, c.owner_peer, c.look]


func _roster() -> Array:
	var out: Array = []
	for c in chars:
		out.append(_roster_entry(c))
	return out


func _char_of(peer: int) -> Character:
	for c in chars:
		if c.owner_peer == peer:
			return c
	return null


func _make_snapshot() -> Array:
	var cf := PackedFloat32Array()
	cf.resize(chars.size() * NF)
	for i in chars.size():
		var c := chars[i]
		var o := i * NF
		var p := c.global_position
		var flags := 0
		if c.is_zombie: flags |= 1
		if c.frozen: flags |= 2
		if c.sneaking: flags |= 4
		if c.moving: flags |= 8
		if c.listening: flags |= 16
		if c.busy: flags |= 32
		if c.has_melon: flags |= 64
		if c.has_oil: flags |= 128
		var pose := c.busy_pose if c.busy else c.hide_pose
		var chase := -1
		if c.brain is ZombieAI and c.brain.state == ZombieAI.S.CHASE and c.brain.target != null:
			chase = chars.find(c.brain.target)
		cf[o] = p.x
		cf[o + 1] = p.y
		cf[o + 2] = p.z
		cf[o + 3] = c.facing
		cf[o + 4] = c.velocity.x
		cf[o + 5] = c.velocity.z
		cf[o + 6] = flags
		cf[o + 7] = c.lives
		cf[o + 8] = c.bites
		cf[o + 9] = c.bites_taken
		cf[o + 10] = c.garlic_t
		cf[o + 11] = c.souvlaki_t
		cf[o + 12] = c.stun_t
		cf[o + 13] = c.sprint_t
		cf[o + 14] = c.sprint_cd
		cf[o + 15] = c.heard_t
		cf[o + 16] = c.noise_t
		cf[o + 17] = c.invuln_t
		cf[o + 18] = c.freeze_left
		cf[o + 19] = c.freeze_lock
		cf[o + 20] = c.turn_t
		cf[o + 21] = c.listen_t
		cf[o + 22] = spots.find(c.hidden_in) if c.hidden_in != null else -1
		cf[o + 23] = maxi(0, POSES.find(pose))
		cf[o + 24] = c.motion
		cf[o + 25] = chase
		cf[o + 26] = c.frappe_t
		cf[o + 27] = c.slip_t
	var sniff := PackedInt32Array()
	for i in spots.size():
		if spots[i].sniffed_by != null:
			sniff.append(i)
	var pk := PackedFloat32Array()
	for p in pickups:
		pk.append(p.net_id)
		pk.append(Cfg.PICKUP_KINDS.find(p.kind))
		pk.append(p.global_position.x)
		pk.append(p.global_position.z)
	return [phase, prep_left, match_left, time, cf, sniff, pk]


# --- Gastgeber

func net_peer_ready(peer: int) -> void:
	if _begun:
		Net.send_begin(_roster(), peer)   # Nachzügler


func net_input(peer: int, mx: float, mz: float, flags: int) -> void:
	var c := _char_of(peer)
	if c != null and c.player_controlled:
		c.input_age = 0.0
		_set_input(c, Vector3(mx, 0, mz), flags)


func net_action(peer: int, kind: String, arg: Vector3) -> void:
	var c := _char_of(peer)
	if c != null and c.player_controlled and not paused_logic:
		_do_action(c, kind, arg)


## Ein Mitspieler ist weg: der Computer übernimmt seine Figur.
func net_peer_left(peer: int) -> void:
	var c := _char_of(peer)
	if c == null:
		return
	c.owner_peer = 0
	c.player_controlled = false
	c.move_dir = Vector3.ZERO
	c.want_freeze = false
	c.want_listen = false
	if c.is_zombie:
		c.brain = ZombieAI.new(c, self)
	else:
		c.brain = HumanAI.new(c, self)
	if hud != null and phase != Phase.END:
		_toast_others("%s hat das Spiel verlassen – der Computer übernimmt." % c.cname, [])


# --- Client

func _add_roster_char(e: Array) -> void:
	var c := _make_char(e[0], e[1], e[2], e[3], e[5])
	c.owner_peer = e[4]
	c.puppet = true
	c.player_controlled = c.owner_peer != 0
	c.set_collision_enabled(false)
	if c.owner_peer == Net.my_id():
		player = c


func net_begin(roster: Array) -> void:
	if _begun or not is_client:
		return
	for e in roster:
		_add_roster_char(e)
	if player == null:
		player = chars[0]   # sollte nicht vorkommen: dann nur zuschauen
	_attach_player()
	_begun = true
	paused_logic = false
	_intro()


func net_snapshot(a: Array) -> void:
	if not _begun or not is_client or a.size() < 7:
		return
	if phase != Phase.END and int(a[0]) != Phase.END:
		phase = int(a[0])
	prep_left = a[1]
	match_left = a[2]
	time = a[3]
	var cf: PackedFloat32Array = a[4]
	for s in spots:
		s.slots.clear()
		s.sniffed_by = null
	for i in mini(chars.size(), cf.size() / NF):
		var c := chars[i]
		var o := i * NF
		var flags := int(cf[o + 6])
		c.net_pos = Vector3(cf[o], cf[o + 1], cf[o + 2])
		c.net_facing = cf[o + 3]
		c.net_vel = Vector3(cf[o + 4], 0, cf[o + 5])
		c.net_age = 0.0
		if (flags & 1) != 0 and not c.is_zombie:
			c.mark_zombie()
			if c == player:
				hud.set_zombie_mode(true)
		c.frozen = (flags & 2) != 0
		c.sneaking = (flags & 4) != 0
		c.moving = (flags & 8) != 0
		c.listening = (flags & 16) != 0
		c.busy = (flags & 32) != 0
		c.has_melon = (flags & 64) != 0
		c.has_oil = (flags & 128) != 0
		c.frappe_t = cf[o + 26]
		c.slip_t = cf[o + 27]
		c.lives = int(cf[o + 7])
		c.bites = int(cf[o + 8])
		c.bites_taken = int(cf[o + 9])
		c.garlic_t = cf[o + 10]
		c.souvlaki_t = cf[o + 11]
		c.stun_t = cf[o + 12]
		c.sprint_t = cf[o + 13]
		c.sprint_cd = cf[o + 14]
		c.heard_t = cf[o + 15]
		c.noise_t = cf[o + 16]
		c.invuln_t = cf[o + 17]
		c.freeze_left = cf[o + 18]
		c.freeze_lock = cf[o + 19]
		c.turn_t = cf[o + 20]
		c.listen_t = cf[o + 21]
		var si := int(cf[o + 22])
		var spot: HidingSpot = spots[si] if si >= 0 and si < spots.size() else null
		if spot != c.hidden_in:
			(spot if spot != null else c.hidden_in).wobble()
		c.hidden_in = spot
		if spot != null:
			spot.add(c)
		var pose: String = POSES[clampi(int(cf[o + 23]), 0, POSES.size() - 1)]
		if c.busy:
			c.busy_pose = pose
		else:
			c.hide_pose = pose
		c.motion = cf[o + 24]
		c.net_chase = int(cf[o + 25])
	var sniff: PackedInt32Array = a[5]
	for si in sniff:
		if si >= 0 and si < spots.size():
			spots[si].sniffed_by = spots[si]   # nur "nicht null" zählt für die Anzeige
	# Upgrades abgleichen
	var pk: PackedFloat32Array = a[6]
	var seen := {}
	for i in pk.size() / 4:
		var id := int(pk[i * 4])
		seen[id] = true
		if not _net_pickups.has(id):
			var p := Pickup.new()
			add_child(p)
			p.setup(Cfg.PICKUP_KINDS[clampi(int(pk[i * 4 + 1]), 0, Cfg.PICKUP_KINDS.size() - 1)])
			p.net_id = id
			p.global_position = Vector3(pk[i * 4 + 2], 0, pk[i * 4 + 3])
			_net_pickups[id] = p
			pickups.append(p)
	for id in _net_pickups.keys():
		if not seen.has(id):
			var p: Pickup = _net_pickups[id]
			pickups.erase(p)
			_net_pickups.erase(id)
			p.queue_free()


func net_event(kind: String, args: Array) -> void:
	if not _begun or not is_client:
		return
	match kind:
		"sfx":
			Sfx.play_at_local(args[0], args[1], args[2], args[3])
		"ui":
			Sfx.play(args[0], args[1])
		"ping":
			_noise_pings.append({"pos": args[0], "t": 1.5})
		"fx":
			_fx_local(args[0], args[1])
		"spawn":
			_add_roster_char(args[0])
		"ann":
			hud.announce(args[0], args[1], args[2])
		"toast":
			hud.toast(args[0])
		"hit":
			hud.flash(Color(0.8, 0.0, 0.0, 0.55))
			Input.vibrate_handheld(300)
		"break":
			_break_fx(args[0])
		"melon":
			_melon_fx(args[0], args[1], args[2])
		"oil":
			_add_puddle(args[0], args[1])
		"oil_gone":
			_remove_puddle(args[0])
		"end":
			if phase == Phase.END:
				return
			var stats: Array = args[2]
			for i in mini(chars.size(), stats.size()):
				var c := chars[i]
				if stats[i][0] and not c.is_zombie:
					c.mark_zombie()
				c.turn_t = 0.0
				c.lives = stats[i][1]
				c.bites = stats[i][2]
				c.bites_taken = stats[i][3]
			var ti: int = args[1]
			_finish(args[0], chars[ti] if ti >= 0 and ti < chars.size() else null)


func _client_tick(delta: float) -> void:
	if not _begun or player == null:
		return
	if phase != Phase.END:
		_apply_player_input()
	_debug_line(delta)
	_update_audio_levels()
	for p in _noise_pings:
		p.t -= delta
	_noise_pings = _noise_pings.filter(func(p): return p.t > 0.0)
	if GameState.quit_after > 0.0 and time >= GameState.quit_after:
		print("QUIT_AFTER time=%.1f phase=%d humans=%d zombies=%d" % [time, phase, humans().size(), zombies().size()])
		get_tree().quit()


## Client: der Gastgeber ist weg.
func net_closed() -> void:
	print("NET closed by host")
	_reset_engine()
	Sfx.reset_levels()
	get_tree().paused = false
	if GameState.autoplay:
		get_tree().quit()
		return
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Nur für automatische Tests: ein Client, der zufällig herumläuft und Knöpfe drückt.
func _bot_input() -> void:
	_bot_t -= get_physics_process_delta_time()
	if _bot_t > 0.0:
		return
	_bot_t = randf_range(0.6, 2.0)
	var a := randf() * TAU
	_bot_dir = Vector3(cos(a), 0, sin(a)) if randf() < 0.8 else Vector3.ZERO
	_bot_flags = (1 if randf() < 0.4 else 0) | (2 if randf() < 0.1 else 0) | (4 if randf() < 0.15 else 0)
	var r := randf()
	if r < 0.25:
		Net.send_action("hide", Vector3.ZERO)
	elif r < 0.5:
		Net.send_action("bite", Vector3.ZERO)
	elif r < 0.6:
		Net.send_action("sprint", Vector3.ZERO)
	elif r < 0.7:
		Net.send_action("throw", _bot_dir)
	elif r < 0.8:
		Net.send_action("oil", Vector3.ZERO)
	elif r < 0.9:
		Net.send_action("window", Vector3.ZERO)

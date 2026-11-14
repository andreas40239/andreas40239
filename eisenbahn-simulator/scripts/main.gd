extends Node
## Spielablauf: Hauptmenü → Bauen → Fahren → Ergebnis.

enum Mode { MENU, BUILD, DRIVE }

const MENU_DEMO_LEVEL := 2

var mode: int = Mode.MENU
var level_index := 0
var world: World
var train: Train
var traffic: Traffic
var rig: CamRig
var hud: Hud
var audio: GameAudio
var env: Environment
var sun: DirectionalLight3D
var tool: int = G.Tool.TRACK
var autopilot := false
var intro_shown := {}

var _touches: Dictionary = {}
var _stroke: Array[Vector2i] = []
var _stroke_fresh: Dictionary = {}
var _stroke_active := false
var _stroke_moved := false
var _gesture := false
var _dirty := false
var _time := 0.0
var _err_cool := 0.0
var _whistle_cool := 0.0
var _demo_wait := 0.0
var _menu_t := 0.0
var _result_pending := false
var _was_braking := false
var _last_active := {}


func _ready() -> void:
	Save.load_all()
	UI.init()
	_setup_env()
	audio = GameAudio.new()
	add_child(audio)
	rig = CamRig.new()
	rig.env = env
	rig.sun = sun
	add_child(rig)
	hud = Hud.new()
	add_child(hud)
	_connect_hud()
	get_tree().set_auto_accept_quit(false)
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("test"):
		var dt: Node = load("res://scripts/dev_test.gd").new()
		dt.set("main", self)
		dt.set("args", args)
		add_child(dt)
	else:
		show_menu()


func _setup_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("3f86d8")
	sm.sky_horizon_color = Color("c4e3f5")
	sm.ground_horizon_color = Color("c4e3f5")
	sm.ground_bottom_color = Color("86b56f")
	sm.sun_angle_max = 8.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d6e4ff")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 45.0
	env.fog_depth_end = 300.0
	env.fog_light_color = Color("c4e3f5")
	env.fog_density = 1.0
	env.fog_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("fff1d8")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	add_child(sun)
	sun.look_at_from_position(-Vector3(0.38, -0.85, -0.5) * 10.0, Vector3.ZERO)


func _connect_hud() -> void:
	hud.level_chosen.connect(start_level)
	hud.tool_selected.connect(select_tool)
	hud.drive_pressed.connect(enter_drive)
	hud.build_pressed.connect(func() -> void: enter_build(false))
	hud.menu_pressed.connect(show_menu)
	hud.rotate_pressed.connect(func() -> void: rig.rotate_step(1))
	hud.clear_pressed.connect(func() -> void:
		world.clear_all()
		audio.play("erase")
		_save_layout())
	hud.camera_pressed.connect(func() -> void:
		rig.cycle_mode()
		rig.follow = true
		hud.set_camera_name(CamRig.MODE_NAMES[rig.mode]))
	hud.switch_pressed.connect(_toggle_next_switch)
	hud.whistle_pressed.connect(func() -> void: audio.play("whistle", -2.0))
	hud.brake_changed.connect(func(down: bool) -> void:
		if train != null:
			train.braking = down
			if down and absf(train.speed) > 2.0:
				audio.play("brake", -8.0))
	hud.throttle_changed.connect(func(v: float) -> void:
		if train != null and train.state == Train.State.RUN:
			train.throttle = v)
	hud.settings_changed.connect(func() -> void:
		audio.apply_settings()
		Save.store())
	hud.ui_click.connect(func() -> void: audio.play("click", -6.0))


# ====================================================================== Zustände

func _unload() -> void:
	hud.close_dialog()
	_result_pending = false
	if train != null:
		train.queue_free()
		train = null
	if traffic != null:
		traffic.queue_free()
		traffic = null
	if world != null:
		world.queue_free()
		world = null
	rig.target = null
	audio.stop_loops()
	_last_active.clear()


func _load_world(i: int) -> void:
	_unload()
	level_index = i
	world = World.new()
	add_child(world)
	world.setup(i)
	traffic = Traffic.new()
	add_child(traffic)
	traffic.setup(world, int(world.level.get("cars", 0)))
	rig.yaw_step = 0
	rig.set_mode(CamRig.Mode.ISO)
	var vs := get_viewport().get_visible_rect().size
	rig.fit(world.w * G.T, world.h * G.T, vs.x / vs.y)


func show_menu() -> void:
	_save_layout()
	_load_world(MENU_DEMO_LEVEL)
	mode = Mode.MENU
	world.set_build_view(false)
	# Vorführstrecke: günstigste Route bauen und einen Zug darauf fahren lassen
	world.budget = 1000000
	_build_solution()
	_spawn_train()
	autopilot = true
	rig.zoom = rig.zoom * 0.62
	rig.follow = false
	_menu_t = 0.0
	hud.refresh_menu()
	hud.show_screen("menu")
	audio.music("menu")


func _build_solution() -> void:
	world._loading = true
	for t in world.start_tiles + world.goal_tiles:
		world.tap(G.Tool.STATION, t)
	for st in world.solve()["path"]:
		world.place(st[0], world._terrain_kind(st[0]), [[st[1], st[2]]])
	world._loading = false


func start_level(i: int) -> void:
	_load_world(i)
	world.load_save(Save.get_layout(i))
	world.changed.connect(_on_world_changed)
	hud.set_level_title(world.level["title"])
	enter_build(true)
	if not intro_shown.has(i):
		intro_shown[i] = true
		hud.dialog(world.level["title"], world.level["intro"], [["Los geht's", UI.C_GREEN, Callable(), "play"]], null, 720.0)


func enter_build(first: bool) -> void:
	mode = Mode.BUILD
	autopilot = false
	_result_pending = false
	hud.close_dialog()
	if train != null:
		train.queue_free()
		train = null
	rig.target = null
	rig.follow = false
	if rig.mode != CamRig.Mode.ISO:
		rig.set_mode(CamRig.Mode.ISO)
	if not first:
		var vs := get_viewport().get_visible_rect().size
		rig.fit(world.w * G.T, world.h * G.T, vs.x / vs.y)
	world.set_build_view(true)
	for p in world.crossings:
		p.active = false
	audio.stop_loops()
	hud.show_screen("build")
	select_tool(tool if not first else _suggest_tool())
	_on_world_changed()
	audio.music("build")


func _suggest_tool() -> int:
	if not world.stations_built(world.start_tiles) or not world.stations_built(world.goal_tiles):
		return G.Tool.STATION
	return G.Tool.TRACK


func select_tool(t: int) -> void:
	tool = t
	hud.set_tool(t)
	if world != null:
		world.show_tool_hint(t)


func _on_world_changed() -> void:
	if mode != Mode.BUILD or world == null:
		return
	_dirty = true
	hud.set_money(world.spent, world.budget)
	var complete := world.route_complete()
	hud.set_route(complete, world.stations_built(world.start_tiles))
	world.show_tool_hint(tool)
	var st_done := world.stations_built(world.start_tiles) and world.stations_built(world.goal_tiles)
	if not st_done:
		hud.set_hint("Wähle „Bahnhof“ und tippe auf die markierten Felder bei START und ZIEL.")
	elif not complete:
		hud.set_hint("Wähle „Gleis“ und ziehe mit dem Finger eine Strecke vom Start zum Ziel.")
	else:
		hud.set_hint("Die Strecke steht – tippe auf „Abfahrt!“")


func _save_layout() -> void:
	if world != null and mode != Mode.MENU:
		Save.set_layout(level_index, world.to_save())
		Save.store()
	_dirty = false


func _spawn_train() -> void:
	train = Train.new()
	add_child(train)
	train.setup(world)
	train.init_wheel_phases()
	train.crashed.connect(_on_crashed)
	train.arrived.connect(_on_arrived)
	train.chuff.connect(_on_chuff)
	train.bumped.connect(func() -> void: audio.play("bump", -4.0))


func enter_drive() -> void:
	if world == null or not world.stations_built(world.start_tiles):
		hud.toast("Baue zuerst den Startbahnhof.", true)
		audio.play("error", -6.0)
		return
	_save_layout()
	mode = Mode.DRIVE
	autopilot = false
	_result_pending = false
	world.set_build_view(false)
	_spawn_train()
	rig.target = train.loco
	rig.follow = true
	rig.zoom = clampf(rig.zoom, rig.zoom_min, 40.0)
	hud.show_screen("drive")
	hud.throttle.set_value_silent(0.0)
	hud.set_camera_name(CamRig.MODE_NAMES[rig.mode])
	hud.set_drive_hint("Ziel: Bahnhof %s" % world.level["goal_name"])
	audio.music("drive")
	audio.play("hiss", -8.0)
	if not world.route_complete():
		hud.toast("Probefahrt: Die Strecke ist noch nicht mit dem Ziel verbunden.", true)


func _on_chuff(strength: float) -> void:
	if mode == Mode.MENU:
		return
	var k := clampf(absf(train.speed) / G.MAX_SPEED, 0.0, 1.0)
	audio.play("chuff", lerpf(-13.0, -5.0, strength) - k * 3.0, 0.92 + k * 0.22 + randf_range(-0.03, 0.03))


func _on_crashed(reason: String) -> void:
	if mode == Mode.MENU:
		_demo_wait = 2.0
		return
	audio.play("crash", -2.0)
	hud.throttle.set_value_silent(0.0)
	_result_pending = true
	await get_tree().create_timer(1.3).timeout
	if not _result_pending or mode != Mode.DRIVE:
		return
	hud.show_result(false, "Oh nein!", reason if reason != "" else "Der Zug ist entgleist.", 0, [
		["Umbauen", UI.C_BLUE, func() -> void: enter_build(false), "build"],
		["Nochmal", UI.C_GREEN, _restart_drive, "retry"],
	])


func _restart_drive() -> void:
	if train != null:
		train.queue_free()
		train = null
	enter_drive()


func _on_arrived() -> void:
	if mode == Mode.MENU:
		_demo_wait = 4.0
		return
	audio.play("hiss", -5.0)
	audio.play("success", -3.0)
	hud.throttle.set_value_silent(0.0)
	var stars := stars_for(world.spent)
	var best_before := Save.stars[level_index]
	Save.stars[level_index] = maxi(best_before, stars)
	Save.store()
	_result_pending = true
	await get_tree().create_timer(1.0).timeout
	if not _result_pending or mode != Mode.DRIVE:
		return
	var body := "Du hast den Bahnhof %s erreicht.\nBaukosten: %d (Bestwert: %d)" % [world.level["goal_name"], world.spent, world.par]
	if stars < 3:
		body += "\nTipp: Eine günstigere Strecke bringt mehr Sterne."
	var btns := [
		["Menü", UI.C_BTN, show_menu, "home"],
		["Umbauen", UI.C_BLUE, func() -> void: enter_build(false), "build"],
	]
	if level_index + 1 < Levels.count():
		btns.append(["Weiter", UI.C_GREEN, func() -> void: start_level(level_index + 1), "next"])
	hud.show_result(true, "Angekommen!", body, stars, btns)
	if stars > 0:
		for i in stars:
			get_tree().create_timer(0.4 + i * 0.4).timeout.connect(func() -> void: audio.play("star", -4.0, 1.0 + i * 0.12))


func stars_for(cost: int) -> int:
	if cost <= int(world.par * 1.1):
		return 3
	if cost <= int(world.par * 1.3):
		return 2
	return 1


# ====================================================================== Laufender Betrieb

func _process(dt: float) -> void:
	_time += dt
	_err_cool = maxf(0.0, _err_cool - dt)
	_whistle_cool = maxf(0.0, _whistle_cool - dt)
	if world == null:
		return
	if train != null:
		if autopilot:
			_autopilot(dt)
		_update_crossings(dt)
		_update_train_audio()
	else:
		_relax_crossings(dt)
	match mode:
		Mode.MENU:
			_menu_t += dt
			rig.focus = Vector3(world.w * G.T * (0.5 + 0.16 * sin(_menu_t * 0.07)), 0, world.h * G.T * (0.5 + 0.14 * cos(_menu_t * 0.09)))
			if _demo_wait > 0.0:
				_demo_wait -= dt
				if _demo_wait <= 0.0 and train != null:
					train.place_at_start()
		Mode.DRIVE:
			_update_drive_hud()


func _autopilot(_dt: float) -> void:
	if train.state != Train.State.RUN:
		return
	var near_goal := false
	for en in train.ahead:
		if world.goal_tiles.has(en[0]):
			near_goal = true
	if train.goal_depth > 0.0:
		if train.goal_depth >= 8.3:
			train.throttle = 0.0
			train.braking = true
		elif train.speed > 1.7:
			train.throttle = 0.0
			train.braking = true
		else:
			train.braking = false
			train.throttle = 0.3
	elif near_goal:
		train.braking = train.speed > 2.6
		train.throttle = 0.45
	else:
		train.braking = false
		train.throttle = 0.85


func _update_crossings(dt: float) -> void:
	var ahead_tiles := {}
	for en in train.ahead:
		ahead_tiles[en[0]] = true
	var bell := 0.0
	for p in world.crossings:
		var act := train.state == Train.State.RUN and (train.occupied.has(p.tile) or ahead_tiles.has(p.tile))
		if act and not _last_active.get(p.tile, false) and mode == Mode.DRIVE and _whistle_cool <= 0.0:
			_whistle_cool = 6.0
			audio.play("whistle", -7.0)
		_last_active[p.tile] = act
		p.active = act
		p.closed = move_toward(p.closed, 1.0 if act else 0.0, dt / (1.5 if act else 1.9))
		var lamp := (act or p.closed > 0.03) and fmod(_time, 0.9) < 0.45
		TrackModels.set_barrier(p.node, smoothstep(0.0, 1.0, p.closed), lamp)
		if act or p.closed > 0.35:
			bell = 1.0
	audio.loop("bell", bell * (0.85 if mode == Mode.DRIVE else 0.0))


func _relax_crossings(dt: float) -> void:
	for p in world.crossings:
		p.active = false
		if p.closed > 0.0:
			p.closed = move_toward(p.closed, 0.0, dt / 1.5)
			TrackModels.set_barrier(p.node, smoothstep(0.0, 1.0, p.closed), false)
	audio.loop("bell", 0.0)


func _update_train_audio() -> void:
	if mode != Mode.DRIVE:
		audio.loop("roll", 0.0)
		return
	var k := clampf(absf(train.speed) / G.MAX_SPEED, 0.0, 1.0)
	audio.loop("roll", 0.0 if train.state != Train.State.RUN else k * 0.75, 0.75 + 0.55 * k)


func _update_drive_hud() -> void:
	if train == null:
		return
	hud.set_speed(train.speed * G.KMH)
	var sw := train.next_switch(36.0) if train.state == Train.State.RUN else null
	if sw != null:
		hud.set_switch_info(true, "Weiche: " + _switch_text(sw))
	else:
		hud.set_switch_info(false, "")
	if train.state != Train.State.RUN:
		hud.set_chip("")
	elif train.end_ahead >= 0.0:
		hud.set_chip("Achtung: Gleisende voraus!", UI.C_RED)
	elif train.in_goal():
		hud.set_chip("Im Bahnhof – jetzt anhalten!", UI.C_GREEN.darkened(0.15))
	elif train.goal_depth > 0.0:
		hud.set_chip("Einfahrt in den Zielbahnhof – langsam!", UI.C_ORANGE.darkened(0.1))
	else:
		hud.set_chip("")


func _switch_text(p: World.Piece) -> String:
	var stem := TrackModels.switch_stem(p.links)
	var l: Array = p.links[p.state]
	var x: int = l[1] if l[0] == stem else l[0]
	var heading := G.opp(stem)
	if x == heading:
		return "geradeaus"
	return "rechts" if x == (heading + 1) % 4 else "links"


func _toggle_next_switch() -> void:
	if train == null:
		return
	var sw := train.next_switch(36.0)
	if sw != null:
		_toggle_switch(sw)


func _toggle_switch(p: World.Piece) -> void:
	if train != null and train.occupied.has(p.tile):
		hud.toast("Die Weiche ist gerade besetzt.", true)
		audio.play("error", -6.0)
		return
	world.toggle_switch(p)
	audio.play("switch", -2.0)


# ====================================================================== Eingabe

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			_save_layout()
			get_tree().quit()
			return
		if hud.has_dialog():
			hud.close_dialog()
		elif mode == Mode.DRIVE:
			enter_build(false)
		elif mode == Mode.BUILD:
			show_menu()
		else:
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _dirty:
			_save_layout()


func _tile_at(screen_pos: Vector2) -> Variant:
	var gp: Variant = rig.ground_point(screen_pos)
	if gp == null:
		return null
	return G.world_to_tile(gp)


func _unhandled_input(e: InputEvent) -> void:
	if OS.is_debug_build() and e is InputEventScreenTouch and OS.get_cmdline_user_args().has("--debug"):
		print("[input] touch ", (e as InputEventScreenTouch).position, " pressed=", (e as InputEventScreenTouch).pressed, " mode=", mode, " dlg=", hud.has_dialog())
	if world == null or mode == Mode.MENU or hud.has_dialog():
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			rig.zoom_by(0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rig.zoom_by(1.1)
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
			if _touches.size() == 1:
				_gesture = false
				_stroke_begin(t.position)
			else:
				_gesture = true
				_stroke_cancel()
		else:
			var was_single := _touches.size() == 1 and not _gesture
			_touches.erase(t.index)
			if was_single:
				_stroke_end(t.position)
			if _touches.is_empty():
				_gesture = false
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if not _touches.has(d.index):
			return
		if _touches.size() >= 2:
			_pinch(d)
		else:
			_touches[d.index] = d.position
			if mode == Mode.BUILD and tool != G.Tool.VIEW and _stroke_active:
				_stroke_move(d.position)
			else:
				_stroke_moved = true
				rig.pan_pixels(d.relative)


func _pinch(d: InputEventScreenDrag) -> void:
	var keys := _touches.keys()
	var other: int = keys[0] if keys[0] != d.index else keys[1]
	var p_other: Vector2 = _touches[other]
	var p_old: Vector2 = _touches[d.index]
	var p_new := d.position
	var d_old := p_old.distance_to(p_other)
	var d_new := p_new.distance_to(p_other)
	if d_old > 8.0 and d_new > 8.0:
		rig.zoom_by(d_old / d_new)
	rig.pan_pixels((p_new - p_old) * 0.5)
	_touches[d.index] = p_new


func _stroke_begin(pos: Vector2) -> void:
	_stroke.clear()
	_stroke_fresh.clear()
	_stroke_moved = false
	_stroke_active = false
	var t: Variant = _tile_at(pos)
	if t == null:
		return
	_stroke.append(t)
	_stroke_active = true


func _stroke_cancel() -> void:
	_stroke_active = false


func _stroke_move(pos: Vector2) -> void:
	var tv: Variant = _tile_at(pos)
	if tv == null:
		return
	var target: Vector2i = tv
	var guard := 0
	while _stroke.back() != target and guard < 40:
		guard += 1
		var cur: Vector2i = _stroke.back()
		var dx := target.x - cur.x
		var dz := target.y - cur.y
		var dir := -1
		if absi(dx) >= absi(dz):
			dir = G.E if dx > 0 else G.W
		else:
			dir = G.S if dz > 0 else G.N
		_stroke_step(G.step(cur, dir), dir)


func _stroke_step(n: Vector2i, d_out: int) -> void:
	var cur: Vector2i = _stroke.back()
	_stroke_moved = true
	var before := world.spent
	var msg := ""
	if tool == G.Tool.ERASE:
		if _stroke.size() == 1 and world.piece_at(cur) != null:
			world.remove(cur)
		if world.piece_at(n) != null:
			world.remove(n)
	else:
		var d_in := -1
		if _stroke.size() >= 2:
			var prev: Vector2i = _stroke[_stroke.size() - 2]
			for d in 4:
				if G.step(cur, d) == prev:
					d_in = d
		if d_in == d_out:
			# Umkehr auf der Stelle: letzten Schritt zurücknehmen
			_stroke.pop_back()
			return
		if world.in_bounds(cur):
			var had := world.piece_at(cur) != null
			var m1 := world.shape(tool, cur, d_in, d_out, _stroke_fresh.has(cur))
			if not had and world.piece_at(cur) != null:
				_stroke_fresh[cur] = true
			if m1 != "" and _stroke.size() == 1:
				msg = m1
		if world.in_bounds(n):
			var had2 := world.piece_at(n) != null
			var m2 := world.shape(tool, n, G.opp(d_out), -1, _stroke_fresh.has(n))
			if not had2 and world.piece_at(n) != null:
				_stroke_fresh[n] = true
			if m2 != "":
				msg = m2
	_stroke.append(n)
	_feedback(before, msg)


func _stroke_end(pos: Vector2) -> void:
	if not _stroke_active and not (mode == Mode.DRIVE):
		if _dirty:
			_save_layout()
		return
	var was_tap := not _stroke_moved
	_stroke_active = false
	if was_tap:
		var tv: Variant = _tile_at(pos)
		if tv != null:
			var t: Vector2i = tv
			if mode == Mode.BUILD and tool != G.Tool.VIEW:
				var before := world.spent
				var sig := _piece_sig(t)
				var msg := world.tap(tool, t)
				_feedback(before, msg, sig != _piece_sig(t))
			elif mode == Mode.DRIVE:
				var p := world.piece_at(t)
				if p != null and p.kind == G.Kind.SWITCH:
					_toggle_switch(p)
	if _dirty and mode == Mode.BUILD:
		_save_layout()


func _piece_sig(t: Vector2i) -> String:
	var p := world.piece_at(t)
	return "" if p == null else str(p.kind, p.links)


func _feedback(spent_before: int, msg: String, changed_shape: bool = false) -> void:
	var diff := world.spent - spent_before
	if diff >= 30:
		audio.play("place_big", -3.0)
	elif diff > 0:
		audio.play("place", -5.0, randf_range(0.94, 1.08))
	elif diff < 0:
		audio.play("erase", -5.0)
	elif msg != "":
		if _err_cool <= 0.0:
			_err_cool = 0.8
			audio.play("error", -8.0)
			hud.toast(msg, true)
	elif changed_shape:
		audio.play("click", -4.0)

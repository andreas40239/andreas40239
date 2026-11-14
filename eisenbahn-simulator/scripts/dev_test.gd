extends Node
## Entwickler-Testläufe (nur mit Kommandozeilen-Argument --test=…):
## simulierte Touch-Eingaben, Autopilot-Fahrt und Screenshots.
##
##   godot --path . -- --test=menu  --shot=/tmp/menu.png
##   godot --path . -- --test=build --level=1 --shot=/tmp/b
##   godot --path . -- --test=drive --level=1 --shot=/tmp/d

var main: Node
var args: Dictionary
var fails := 0


func _ready() -> void:
	await get_tree().process_frame
	var t: String = args.get("test", "")
	print("[test] start ", t)
	# sauberer Ausgangszustand
	Save.layouts.clear()
	for i in Save.stars.size():
		Save.stars[i] = int(args.get("stars", "0"))
	Save.music_on = true
	Save.sfx_on = true
	match t:
		"menu": await _menu()
		"build": await _build()
		"drive": await _drive()
		"all": await _all()
		"closeup": await _closeup()
		"icon": await _icon()
		"switch": await _switch()
		"controls": await _controls()
	print("[test] done fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(suffix: String) -> void:
	if not args.has("shot"):
		return
	await RenderingServer.frame_post_draw
	var path: String = args["shot"]
	if suffix != "":
		path = path.trim_suffix(".png") + "_" + suffix + ".png"
	get_viewport().get_texture().get_image().save_png(path)
	print("[test] shot ", path)


func _check(cond: bool, what: String) -> void:
	if cond:
		print("[test] ok   ", what)
	else:
		fails += 1
		print("[test] FAIL ", what)


func _screen(tile: Vector2i) -> Vector2:
	## Fensterkoordinaten der Kachelmitte (für simulierte Eingaben).
	var vp := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var p: Vector2 = main.rig.cam.unproject_position(G.tile_center(tile))
	var v := p
	if main._tile_at(p) != tile:
		v = p * vp / win
	return v * win / vp


func _touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag_to(from: Vector2, to: Vector2, index: int = 0) -> void:
	var steps := 6
	for i in range(1, steps + 1):
		var e := InputEventScreenDrag.new()
		e.index = index
		var p := from.lerp(to, float(i) / steps)
		e.position = p
		e.relative = (to - from) / steps
		Input.parse_input_event(e)
		await get_tree().process_frame


func _tap_tile(tile: Vector2i) -> void:
	var p := _screen(tile)
	if args.has("debug"):
		print("[test] tap ", tile, " screen ", p, " -> ", main._tile_at(p), " vp=", get_viewport().get_visible_rect().size, " win=", DisplayServer.window_get_size())
	_touch(p, true)
	await _frames(2)
	_touch(p, false)
	await _frames(2)


func _drag_tiles(tiles: Array) -> void:
	var p := _screen(tiles[0])
	_touch(p, true)
	await _frames(2)
	for i in range(1, tiles.size()):
		var q := _screen(tiles[i])
		await _drag_to(p, q)
		p = q
	_touch(p, false)
	await _frames(2)


func _menu() -> void:
	main.show_menu()
	await _secs(float(args.get("wait", "3")))
	await _shot("")


## Baut die Lösungsstrecke ausschließlich über simulierte Touch-Eingaben.
func _build_by_touch(level: int) -> void:
	main.start_level(level)
	await _frames(5)
	main.hud.close_dialog()
	main.world.clear_all()
	await _frames(3)
	var w: World = main.world
	main.select_tool(G.Tool.STATION)
	for t in w.start_tiles:
		await _tap_tile(t)
	await _drag_tiles(w.goal_tiles)
	_check(w.stations_built(w.start_tiles) and w.stations_built(w.goal_tiles), "Bahnhöfe per Touch gebaut")
	var path: Array = w.solve()["path"]
	var run: Array = []
	for st in path:
		var kind: int = w._terrain_kind(st[0])
		if kind == G.Kind.TRACK:
			run.append(st[0])
			continue
		if run.size() > 0:
			main.select_tool(G.Tool.TRACK)
			if run.size() == 1:
				await _tap_tile(run[0])
			else:
				await _drag_tiles(run)
			run = []
		main.select_tool(G.Tool.BRIDGE if kind == G.Kind.BRIDGE else G.Tool.CROSSING)
		await _tap_tile(st[0])
	if run.size() > 0:
		main.select_tool(G.Tool.TRACK)
		if run.size() == 1:
			await _tap_tile(run[0])
		else:
			await _drag_tiles(run)
	await _frames(3)
	# Nachbessern: Einzelstücke, die beim Ziehen noch nicht passend liegen, per Ziehen über Nachbarn formen
	for st in path:
		var p := w.piece_at(st[0])
		if p == null:
			print("[test] fehlt: ", st)
		elif not World.has_link(p, st[1], st[2]):
			print("[test] falsche Form: ", st, " ist ", p.links)
	_check(w.route_complete(), "Strecke Level %d per Touch verbunden (Kosten %d, Bestwert %d, Budget %d)" % [level + 1, w.spent, w.par, w.budget])


func _build() -> void:
	var level := int(args.get("level", "0"))
	main.start_level(level)
	await _secs(0.6)
	await _shot("intro")
	main.hud.close_dialog()
	await _secs(0.4)
	await _shot("empty")
	await _build_by_touch(level)
	await _secs(0.5)
	await _shot("built")
	# Fehlbedienung: Gleis auf Wasser
	main.select_tool(G.Tool.TRACK)
	var w: World = main.world
	for z in w.h:
		for x in w.w:
			if w.cell(Vector2i(x, z)).terrain == G.Terrain.WATER and w.piece_at(Vector2i(x, z)) == null:
				await _tap_tile(Vector2i(x, z))
				await _secs(0.3)
				await _shot("toast")
				return


func _drive_level(level: int, shots: bool) -> void:
	main.start_level(level)
	await _frames(5)
	main.hud.close_dialog()
	main.world.clear_all()
	main._build_solution()
	await _frames(3)
	_check(main.world.route_complete(), "Level %d: Lösungsstrecke verbunden" % (level + 1))
	main.enter_drive()
	main.autopilot = true
	await _secs(1.0)
	if shots:
		await _shot("start")
	var t := 0.0
	var shot_i := 0
	var closed_seen := false
	while main.train != null and main.train.state == Train.State.RUN and t < 240.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		for p in main.world.crossings:
			if p.closed > 0.9:
				closed_seen = true
		if shots:
			if shot_i == 0 and t > 6.0:
				shot_i = 1
				await _shot("iso")
				print("[perf] prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			elif shot_i == 1 and t > 9.0:
				shot_i = 2
				main.rig.set_mode(CamRig.Mode.CHASE)
				await _frames(4)
				await _shot("chase")
			elif shot_i == 2 and t > 12.0:
				shot_i = 3
				main.rig.set_mode(CamRig.Mode.CAB)
				await _frames(4)
				await _shot("cab")
				print("[perf] cab prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				main.rig.set_mode(CamRig.Mode.ISO)
			elif shot_i == 3 and closed_seen:
				shot_i = 4
				await _shot("crossing")
	_check(main.train != null and main.train.state == Train.State.DONE, "Level %d: Zug im Zielbahnhof angekommen nach %.0f s" % [level + 1, t])
	if not main.world.crossings.is_empty():
		_check(closed_seen, "Level %d: Schranken haben geschlossen" % (level + 1))
	await _secs(2.6)
	if shots:
		await _shot("result")
	_check(Save.stars[level] == 3, "Level %d: 3 Sterne mit Bestwert-Strecke" % (level + 1))


func _drive() -> void:
	await _drive_level(int(args.get("level", "0")), true)


func _all() -> void:
	for i in Levels.count():
		await _build_by_touch(i)
	for i in Levels.count():
		await _drive_level(i, false)
	# Entgleisung: letztes Gleisstück vor dem Ziel entfernen
	main.start_level(0)
	await _frames(3)
	main.hud.close_dialog()
	main.world.clear_all()
	main._build_solution()
	var path: Array = main.world.solve()["path"]
	main.world.remove(path[path.size() - 2][0])
	_check(not main.world.route_complete(), "Lücke wird erkannt")
	main.enter_drive()
	main.autopilot = true
	var t := 0.0
	while main.train.state == Train.State.RUN and t < 120.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(main.train.state == Train.State.CRASHED, "Zug entgleist am Gleisende")
	await _secs(1.8)
	await _shot("crash")
	main.show_menu()
	await _frames(5)


func _closeup() -> void:
	var level := int(args.get("level", "1"))
	main.start_level(level)
	await _frames(3)
	main.hud.close_dialog()
	main.world.clear_all()
	main._build_solution()
	main.world.set_build_view(false)
	main.hud.show_screen("")
	main.rig.zoom = float(args.get("zoom", "16"))
	main.rig.focus = Vector3(float(args.get("fx", "20")), 0, float(args.get("fz", "20")))
	main.rig.yaw_step = int(args.get("yaw", "0"))
	if args.has("train"):
		main._spawn_train()
		main.mode = main.Mode.DRIVE
		main.hud.show_screen("")
		main.autopilot = true
		await _secs(float(args.get("wait", "3")))
		if args.has("stop"):
			Engine.time_scale = 0.0001
	await _secs(1.0 if not args.has("stop") else 0.0001)
	await _shot("")


## Rendert die Lok freigestellt (transparenter Hintergrund) für App-Icon und Startbild.
func _icon() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1024, 1024)
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfe8ff")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.4
	sun.light_color = Color("fff1d8")
	sv.add_child(sun)
	sun.look_at_from_position(Vector3(4, 8, 6), Vector3.ZERO)
	var root := Node3D.new()
	sv.add_child(root)
	var loco := Models.loco()
	root.add_child(loco)
	var tr := TrackModels.track([[G.N, G.S]])
	root.add_child(tr)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(args.get("size", "4.4"))
	sv.add_child(cam)
	cam.look_at_from_position(Vector3(-6.5, 4.6, -7.5) + Vector3(0, 1.05, -0.1), Vector3(0, 1.05, -0.1))
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.save_png(args["shot"])
	print("[test] icon ", args["shot"])


## Weiche per Touch setzen, umschalten und befahren.
func _switch() -> void:
	main.start_level(0)
	await _frames(4)
	main.hud.close_dialog()
	main.world.clear_all()
	main._build_solution()
	await _frames(3)
	var w: World = main.world
	var t := Vector2i(-1, -1)
	for st in w.solve()["path"]:
		if w._terrain_kind(st[0]) == G.Kind.TRACK and st[1] == G.W and st[2] == G.E and w.check_tool(G.Tool.TRACK, G.step(st[0], G.N)) == "":
			t = st[0]
			break
	_check(t.x >= 0, "gerades Gleis für die Weiche gefunden: %s" % t)
	var before := w.spent
	main.select_tool(G.Tool.SWITCH)
	await _tap_tile(t)
	var p := w.piece_at(t)
	_check(p.kind == G.Kind.SWITCH and w.spent == before + 30, "Weiche per Tippen gebaut (+30)")
	var first: Array = p.links[1].duplicate()
	await _tap_tile(t)
	_check(w.piece_at(t).links[1] != first, "erneutes Tippen wechselt die Weichenform")
	for i in 3:
		await _tap_tile(t)
	p = w.piece_at(t)
	_check(p.links[1] == first, "nach vier Varianten wieder die erste: %s" % [p.links])
	# Abzweig nach Norden mit dem Gleiswerkzeug ein Stück verlängern
	main.select_tool(G.Tool.TRACK)
	await _tap_tile(G.step(t, G.N))
	_check(w.piece_at(G.step(t, G.N)) != null and World.piece_has_edge(w.piece_at(G.step(t, G.N)), G.S), "Abzweiggleis schließt an die Weiche an")
	_check(w.route_complete(), "Hauptstrecke bleibt verbunden")
	main.rig.zoom = 20.0
	main.rig.focus = G.tile_center(t)
	await _secs(0.5)
	await _shot("build")
	# Fahrt 1: Weiche auf Abzweig -> Gleisende
	main.enter_drive()
	main.autopilot = true
	await _frames(3)
	var sw: World.Piece = main.train.next_switch(60.0)
	_check(sw != null and sw.tile == t, "Zug erkennt die Weiche voraus")
	main._toggle_next_switch()
	_check(w.piece_at(t).state == 1, "Weiche über die Taste umgestellt: " + main._switch_text(w.piece_at(t)))
	await _secs(0.4)
	await _shot("drive")
	var tm := 0.0
	while main.train.state == Train.State.RUN and tm < 90.0:
		await get_tree().process_frame
		tm += get_process_delta_time()
	_check(main.train.state == Train.State.CRASHED, "Abzweig ins Leere führt zur Entgleisung")
	await _secs(1.6)
	await _shot("crash")
	# Fahrt 2: Weiche geradeaus -> Ankunft
	main._restart_drive()
	main.autopilot = true
	await _frames(3)
	w.set_switch(w.piece_at(t), 0)
	tm = 0.0
	while main.train.state == Train.State.RUN and tm < 120.0:
		await get_tree().process_frame
		tm += get_process_delta_time()
	_check(main.train.state == Train.State.DONE, "mit Weiche geradeaus kommt der Zug an")
	_check(Save.stars[0] >= 2, "Sterne trotz Mehrkosten: %d" % Save.stars[0])


func _find_button(node: Node, text: String) -> TButton:
	for c in node.get_children():
		if c is TButton and (c as TButton).text == text and (c as TButton).is_visible_in_tree():
			return c
		var r := _find_button(c, text)
		if r != null:
			return r
	return null


func _win(p: Vector2) -> Vector2:
	return p * Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size


## Bedienung nur über die Oberfläche: Menü, Werkzeuge, Fahrregler, Bremse (Mehrfinger), Kamera.
func _controls() -> void:
	main.show_menu()
	await _frames(5)
	var play := _find_button(main.hud, "Spielen")
	_check(play != null, "Spielen-Knopf im Menü gefunden")
	var pp := _win(play.get_global_rect().get_center())
	_touch(pp, true)
	await _frames(2)
	_touch(pp, false)
	await _frames(6)
	_check(main.mode == main.Mode.BUILD and main.level_index == 0, "Level 1 über das Menü gestartet")
	_check(main.hud.has_dialog(), "Einführungsdialog erscheint")
	var go := _find_button(main.hud, "Los geht's")
	pp = _win(go.get_global_rect().get_center())
	_touch(pp, true)
	await _frames(2)
	_touch(pp, false)
	await _frames(4)
	_check(not main.hud.has_dialog(), "Dialog per Knopf geschlossen")
	# Tippen auf die Karte unter einem Knopf darf nichts bauen
	var gleis := _find_button(main.hud, "Gleis")
	pp = _win(gleis.get_global_rect().get_center())
	var before: int = main.world.piece_count()
	_touch(pp, true)
	await _frames(2)
	_touch(pp, false)
	await _frames(3)
	_check(main.tool == G.Tool.TRACK and main.world.piece_count() == before, "Werkzeugknopf wählt Gleis, ohne durch den Knopf hindurch zu bauen")
	main.world.clear_all()
	main._build_solution()
	await _frames(3)
	var ab := _find_button(main.hud, "Abfahrt!")
	pp = _win(ab.get_global_rect().get_center())
	_touch(pp, true)
	await _frames(2)
	_touch(pp, false)
	await _frames(6)
	_check(main.mode == main.Mode.DRIVE and main.train != null, "Abfahrt startet die Fahrt")
	# Fahrregler: Finger 0 ganz nach oben schieben und halten
	var th: Throttle = main.hud.throttle
	var tr := th.get_global_rect()
	var p0 := _win(Vector2(tr.get_center().x, tr.end.y - 120.0))
	var p1 := _win(Vector2(tr.get_center().x, tr.position.y + 50.0))
	_touch(p0, true, 0)
	await _frames(2)
	await _drag_to(p0, p1, 0)
	await _secs(2.0)
	_check(main.train.throttle > 0.9 and main.train.speed > 1.0, "Fahrregler vorwärts: Regler %.2f, Tempo %.1f" % [main.train.throttle, main.train.speed])
	await _shot("throttle")
	# Finger 1 hält zusätzlich die Bremse
	var br := _find_button(main.hud, "Bremse")
	var bp := _win(br.get_global_rect().get_center())
	_touch(bp, true, 1)
	await _frames(3)
	_check(main.train.braking and th.value > 0.9, "Bremse mit zweitem Finger, Regler bleibt gehalten")
	await _secs(2.5)
	_check(absf(main.train.speed) < 0.05, "Zug steht nach dem Bremsen")
	_touch(bp, false, 1)
	await _frames(3)
	_check(not main.train.braking, "Bremse gelöst")
	# Regler nach unten: rückwärts
	var p2 := _win(Vector2(tr.get_center().x, tr.end.y - 46.0))
	await _drag_to(p1, p2, 0)
	_touch(p2, false, 0)
	await _frames(3)
	_check(main.train.throttle < -0.8, "Fahrregler rückwärts: %.2f" % main.train.throttle)
	# Kamera umschalten
	var cam := _find_button(main.hud, "Übersicht")
	pp = _win(cam.get_global_rect().get_center())
	_touch(pp, true)
	await _frames(2)
	_touch(pp, false)
	await _frames(4)
	_check(main.rig.mode == CamRig.Mode.CHASE, "Kamerataste wechselt zur Verfolgeransicht")
	# Karte ziehen mit einem Finger in der Übersicht, zwei Finger zoomen
	main.rig.set_mode(CamRig.Mode.ISO)
	var z0: float = main.rig.zoom
	var c := Vector2(DisplayServer.window_get_size()) * 0.5
	_touch(c + Vector2(-60, 0), true, 0)
	_touch(c + Vector2(60, 0), true, 1)
	await _frames(2)
	await _drag_to(c + Vector2(60, 0), c + Vector2(200, 0), 1)
	_touch(c + Vector2(-60, 0), false, 0)
	_touch(c + Vector2(200, 0), false, 1)
	await _frames(3)
	_check(main.rig.zoom < z0 * 0.8, "Zwei-Finger-Zoom: %.1f -> %.1f" % [z0, main.rig.zoom])
	# zurück zum Bau
	var um := _find_button(main.hud, "Umbauen")
	pp = _win(um.get_global_rect().get_center())
	_touch(pp, true)
	await _frames(2)
	_touch(pp, false)
	await _frames(5)
	_check(main.mode == main.Mode.BUILD and main.train == null, "Umbauen führt zurück in den Baumodus")

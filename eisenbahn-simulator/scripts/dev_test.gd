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

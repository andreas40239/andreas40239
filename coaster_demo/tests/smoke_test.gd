extends SceneTree
## Headless-Smoke-Test:
##   godot --headless --path coaster_demo -s res://tests/smoke_test.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		fails += 1


func check_silent(cond: bool, msg: String) -> void:
	if not cond:
		check(false, msg)


func _initialize() -> void:
	# Notbremse: bei Skriptfehlern nicht hängen bleiben
	create_timer(60.0).timeout.connect(func(): print("TIMEOUT"); quit(2))
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var track: CoasterTrack = main.track
	check(track.pieces.size() == CoasterTrack.STATION_LEN, "Station angelegt")
	check(not track.closed, "neue Strecke offen")

	# Tap auf den Cursor (Bildschirmposition über die Kamera berechnen)
	var cam: Camera3D = main.rig.cam
	var target := CoasterTrack.cell_center(track.cursor_cell)
	var screen := cam.unproject_position(target)
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = root.get_final_transform() * screen  # Fenster- statt Viewport-Koordinaten
	ev.pressed = true
	root.push_input(ev)
	var ev2: InputEventScreenTouch = ev.duplicate()
	ev2.pressed = false
	root.push_input(ev2)
	await process_frame
	await process_frame
	check(track.pieces.size() == CoasterTrack.STATION_LEN + 1, "Tap setzt ein Teil (%d Teile)" % track.pieces.size())

	check(track.place(CoasterTrack.Piece.DOWN) != "", "Runter unter Boden verboten")
	check(track.place(CoasterTrack.Piece.UP) == "", "Hoch erlaubt")
	check(track.undo() and track.undo(), "Zurück")
	check(not track.undo(), "Station nicht löschbar")

	# Neue Teile
	track.reset()
	check(track.place(CoasterTrack.Piece.STEEP_DOWN) != "", "Steile Abfahrt am Boden verboten")
	check(track.place(CoasterTrack.Piece.UP) == "" and track.place(CoasterTrack.Piece.UP) == "", "2x Hoch")
	check(track.place(CoasterTrack.Piece.STEEP_DOWN) == "" and track.cursor_h == 0, "Steile Abfahrt: -2 Stufen")
	var before := track.cursor_cell
	check(track.place(CoasterTrack.Piece.LOOP) == "", "Looping gesetzt")
	check(track.cursor_cell == before + Vector2i(2, 0), "Looping belegt 2 Zellen")
	check(track.place(CoasterTrack.Piece.BANK_LEFT) == "" and track.cursor_dir == 3, "Schrägkurve links")
	var min_up := 1.0
	var inverted := false
	for i in track.path_up.size():
		var up: Vector3 = track.path_up[i]
		check_silent(absf(up.dot(track.path_tan[i])) < 0.01, "Normale senkrecht zur Tangente")
		if track.pieces[track.path_piece[i]].type == CoasterTrack.Piece.LOOP:
			inverted = inverted or up.y < -0.9
		if track.pieces[track.path_piece[i]].type == CoasterTrack.Piece.BANK_LEFT:
			min_up = minf(min_up, up.y)
	check(inverted, "Looping steht kopf")
	check(min_up < 0.85, "Schrägkurve ist geneigt (up.y=%.2f)" % min_up)

	track.build_demo()
	check(track.closed, "Demo-Strecke geschlossen (%d Teile, %.1f m)" % [track.pieces.size(), track.length])

	main._start_ride()
	var t := 0.0
	while t < 40.0:
		main._physics_ride(1.0 / 60.0)
		main._place_cart(main.ride_s)
		t += 1.0 / 60.0
	print("  info max %.1f km/h, Runden %d, Looping-Einfahrt %.1f km/h" % [main.ride_max_v * 3.6, main.ride_laps, main.loop_entry_v * 3.6])
	check(main.ride_laps >= 1, "Wagen fährt Runden")
	check(not main._loop_warned, "Demo: genug Tempo für den Looping")
	check(main.ride_max_v * 3.6 > 30.0, "Wagen wird schnell genug")
	main._stop_ride()
	check(not main.riding, "Fahrt gestoppt")

	# offene Strecke: Fahrt endet
	track.reset()
	track.place(CoasterTrack.Piece.STRAIGHT)
	track.place(CoasterTrack.Piece.LEFT)
	main._start_ride()
	for i in 600:
		main._physics_ride(1.0 / 60.0)
	check(main._ride_end_timer >= 0.0, "offene Strecke: Ende erkannt")
	main._stop_ride()

	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)

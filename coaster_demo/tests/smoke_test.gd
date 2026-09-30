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
	check(main.in_title and main.title.visible, "Start im Startbildschirm")
	check(track.closed, "Startbildschirm zeigt die Demo-Strecke")
	var s0: float = main.ride_s
	for i in 30:
		await process_frame
	check(main.ride_s != s0, "Wagen fährt im Hintergrund")
	main._leave_title("new")
	check(not main.in_title and main.build_bar.visible, "Neue Strecke → Baumodus")
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

	# Weitere Teile
	track.reset()
	check(track.place(CoasterTrack.Piece.STEEP_UP) == "" and track.cursor_h == 2, "Steile Auffahrt: +2 Stufen")
	check(track.place(CoasterTrack.Piece.TUNNEL) != "", "Tunnel nur am Boden")
	check(track.place(CoasterTrack.Piece.STEEP_DOWN) == "", "wieder runter")
	var c0 := track.cursor_cell
	check(track.place(CoasterTrack.Piece.WIDE_RIGHT) == "" and track.cursor_dir == 1
		and track.cursor_cell == c0 + Vector2i(1, 2), "Weite Kurve rechts: 3 Zellen, neue Richtung")
	c0 = track.cursor_cell
	check(track.place(CoasterTrack.Piece.CORKSCREW) == "" and track.cursor_cell == c0 + Vector2i(0, 2), "Korkenzieher: 2 Zellen")
	var cork_inv := false
	for i in track.path_up.size():
		if track.pieces[track.path_piece[i]].type == CoasterTrack.Piece.CORKSCREW:
			cork_inv = cork_inv or track.path_up[i].y < -0.9
	check(cork_inv, "Korkenzieher dreht kopfüber")
	for t in [CoasterTrack.Piece.BOOSTER, CoasterTrack.Piece.BRAKE, CoasterTrack.Piece.TUNNEL, CoasterTrack.Piece.SPLASH]:
		check(track.place(t) == "", "%s gesetzt" % CoasterTrack.PIECE_NAMES[t])
	var tps := track.get_types()
	check(track.load_types(tps) and track.get_types() == tps, "neue Teile speicher-/ladbar")

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

	# Speichern / Laden
	track.build_demo()
	var types := track.get_types()
	main._open_save_menu()
	check(main.save_menu.visible, "Menü öffnet")
	await main._on_save_slot(4)
	var data := SaveSlots.read(4)
	check(data.get("pieces", []).size() == types.size() and data.has("saved_text"), "Platz 5 gespeichert (%s)" % data.get("saved_text", "?"))
	track.reset()
	main._on_load_slot(4)
	check(track.closed and track.get_types() == types, "Platz 5 geladen, Strecke identisch")
	check(not main.save_menu.visible, "Menü nach dem Laden zu")
	check(not track.load_types([99]), "ungültige Daten werden abgelehnt")
	SaveSlots.erase(4)
	check(SaveSlots.read(4).is_empty(), "Platz gelöscht")

	# Autosave / Weiterbauen / Zurück-Taste
	track.reset()
	track.place(CoasterTrack.Piece.UP)
	track.place(CoasterTrack.Piece.LOOP)
	var saved_types := track.get_types()
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(main.in_title, "Zurück-Taste → Startbildschirm")
	check(not main.title.continue_button.disabled, "Weiterbauen möglich")
	main._leave_title("continue")
	check(track.get_types() == saved_types, "Weiterbauen stellt die Strecke wieder her")

	# Home-Button → Startmenü
	main._on_home()
	check(main.in_title, "Home-Button öffnet das Startmenü")
	main._leave_title("new")

	# Tutorial einmal komplett durchspielen
	main._enter_title()
	main._leave_title("tutorial")
	var tut: Tutorial = main.tutorial
	check(tut.active and tut.current_step() == 0, "Tutorial startet")
	tut.next()                                      # Willkommen
	main._build(CoasterTrack.Piece.STRAIGHT)        # grünes Feld
	check(tut.current_step() == 2, "Schritt 'grünes Feld' erkannt")
	main._build(CoasterTrack.Piece.STRAIGHT)        # keine Kurve → bleibt stehen
	check(tut.current_step() == 2, "Kurven-Schritt wartet auf eine Kurve")
	main._build(CoasterTrack.Piece.RIGHT)
	main._build(CoasterTrack.Piece.STRAIGHT)        # Leiste
	main._select_category(1)
	main._build(CoasterTrack.Piece.UP)
	main._on_undo()
	check(tut.current_step() == 7, "bis 'Ansicht' durchgelaufen (Schritt %d)" % tut.current_step())
	tut.next()
	tut.next()
	main._start_ride()
	main._stop_ride()
	check(tut.current_step() == 11, "Fahrt-Schritte erkannt")
	tut.next()
	check(not tut.active, "Tutorial beendet")

	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)

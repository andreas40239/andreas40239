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


func _initialize() -> void:
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

	track.build_demo()
	check(track.closed, "Demo-Strecke geschlossen (%d Teile, %.1f m)" % [track.pieces.size(), track.length])

	main._start_ride()
	var t := 0.0
	while t < 40.0:
		main._physics_ride(1.0 / 60.0)
		main._place_cart(main.ride_s)
		t += 1.0 / 60.0
	print("  info max %.1f km/h, Runden %d" % [main.ride_max_v * 3.6, main.ride_laps])
	check(main.ride_laps >= 1, "Wagen fährt Runden")
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

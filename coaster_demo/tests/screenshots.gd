extends SceneTree
## Rendert Kontroll-Screenshots (benötigt Grafik, z. B. xvfb-run):
##   SHOT_DIR=/tmp xvfb-run godot --path coaster_demo --rendering-driver opengl3 -s res://tests/screenshots.gd
var out_dir := OS.get_environment("SHOT_DIR") if OS.has_environment("SHOT_DIR") else "user://"
var main: Node3D


func shot(name: String) -> void:
	main.toast_label.visible = false
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	for i in 90:
		await process_frame   # Attract-Modus laufen lassen
	await shot("00_title")
	main._leave_title("new")
	for i in 30:
		await process_frame
	await shot("01_start")
	main.track.build_demo()
	main.rig.position = Vector3(40, 0, 60)
	await shot("02_demo_iso")
	main.rig.rotate_view(60, -10)
	main.rig.zoom_by(0.8)
	await shot("03_demo_rotated")

	# Speichern/Laden-Menü mit zwei belegten Plätzen (danach wieder löschen)
	await main._on_save_slot(0)
	main.track.load_types([1, 1, 4, 4, 2, 5, 5, 6, 1])
	main.rig.position = Vector3(40, 0, 50)
	await main._on_save_slot(2)
	main._open_save_menu()
	await shot("07_save_menu")
	main.save_menu.close()
	for i in 3:
		SaveSlots.erase(i)
	main.track.build_demo()

	main._start_ride()
	for i in 560:
		main._physics_ride(1.0 / 60.0)
	main._place_cart(main.ride_s)
	main._update_ride_cam()
	await shot("04_ride_first")

	# Scheitelpunkt des Loopings
	var t: CoasterTrack = main.track
	var top := 0
	for i in t.path_up.size():
		if t.pieces[t.path_piece[i]].type == CoasterTrack.Piece.LOOP and t.path_up[i].y < t.path_up[top].y:
			top = i
	main.ride_s = t.path_dist[top] - 1.0
	main._place_cart(main.ride_s)
	main._update_ride_cam()
	await shot("05_loop_first")
	main._toggle_view()
	main.ride_s = t.path_dist[top] - 3.0
	main._place_cart(main.ride_s)
	main._update_ride_cam()
	await shot("06_loop_third")
	quit()

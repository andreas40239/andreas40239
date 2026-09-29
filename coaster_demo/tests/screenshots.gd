extends SceneTree
## Rendert Kontroll-Screenshots (benötigt Grafik, z. B. xvfb-run).
var out_dir := OS.get_environment("SHOT_DIR") if OS.has_environment("SHOT_DIR") else "user://"

func shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await shot("01_start")
	main.track.build_demo()
	main.track.undo()
	main.track.undo()
	await shot("02_build")
	main.track.build_demo()
	main.rig.rotate_view(60, -10)
	main.rig.zoom_by(0.8)
	await shot("03_demo_rotated")
	main._start_ride()
	for i in 380:
		main._physics_ride(1.0 / 60.0)
	main._place_cart(main.ride_s)
	main._update_ride_cam()
	await shot("04_ride_first")
	main._toggle_view()
	await shot("05_ride_third")
	quit()

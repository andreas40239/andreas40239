extends SceneTree
## Screenshots: xvfb-run godot --path . -s res://tools/shots.gd -- <ausgabeordner>
var main: Node
var f := 0
var out := "/tmp"
var shots := []
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.input_enabled = false
func _snap(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
	print("shot ", name, " fps=", Engine.get_frames_per_second())
func _process(_d: float) -> bool:
	f += 1
	var c: Car = main.car
	if c:
		c.throttle = 1.0 if c.speed < 18.0 else 0.0
		var trk: Track = main.track
		var idx := trk.nearest_sample(c.global_position, main.progress_idx)
		var to := trk.centers[(idx + 9) % trk.centers.size()] - c.global_position
		var fwd := -c.global_transform.basis.z
		c.steer_input = clampf(-atan2(fwd.cross(to).y, fwd.dot(to)) * 2.5, -1, 1)
	match f:
		5: main.track.load_demo(); main._enter_edit()
		40: _snap("01_editor")
		41: main._on_overview()
		90: _snap("02_overview")
		91: main.car_type = 1; main._enter_drive()
		150: _snap("03_racer_start")
		330: _snap("04_racer_driving")
		331: main.car_type = 0; main._enter_drive()
		420: _snap("05_kart")
		421: main.car_type = 2; main._enter_drive()
		520: _snap("06_truck")
		521: main._cross_line(); main.lap_started = true; main.checkpoints = [true, true, true]; main._cross_line()
		545: _snap("07_lap_confetti")
		600: quit()
	return false

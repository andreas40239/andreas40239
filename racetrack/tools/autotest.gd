extends SceneTree
## Headless-Test: godot --headless --path . -s res://tools/autotest.gd
## Faehrt die Demo-Strecke mit einem einfachen Autopiloten ab.

var main: Node
var t := 0.0
var phase := 0
var car_type := 0
var max_speed := 0.0
var max_air := 0.0
var log_t := 0.0
var start_laps := 0
var dbg_car := -1
var dbg_t0 := 0.0
var dbg_t1 := 0.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() >= 3:
		dbg_car = int(a[0])
		dbg_t0 = float(a[1])
		dbg_t1 = float(a[2])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.input_enabled = false


func _physics_process(delta: float) -> bool:
	t += delta
	if phase == 0 and t > 0.5:
		main.track.load_demo()
		print("Demo: Teile=", main.track.piece_count(), " geschlossen=", main.track.closed,
			" Laenge=", snappedf(main.track.total_length, 0.1), " Samples=", main.track.centers.size())
		# Fehlerfaelle
		main.track.clear()
		print("Fehler-Test Rampe runter: '", main.track.add_piece(Track.RAMP_DOWN), "'")
		for i in 6:
			main.track.add_piece(Track.STRAIGHT)
		print("Fehler-Test Rand: '", main.track.add_piece(Track.STRAIGHT), "' / ", main.track.add_piece(Track.STRAIGHT))
		main.track.load_demo()
		_start_car(0)
		phase = 1
	elif phase == 1:
		_autopilot()
		var c: Car = main.car
		max_speed = maxf(max_speed, absf(c.speed))
		max_air = maxf(max_air, c.air_time)
		log_t += delta
		if log_t > 5.0:
			log_t = 0.0
			print("  t=%.0f %s pos=%s v=%.1f km/h laps=%d lap_time=%.1f up=%.2f contacts=%d" % [t, Car.NAMES[car_type],
				str(c.global_position.snapped(Vector3.ONE * 0.1)), c.speed * 3.6, main.lap_count, main.lap_time,
				c.global_transform.basis.y.y, c.contacts])
		if car_type == dbg_car and t > dbg_t0 and t < dbg_t1 and fmod(t, 0.25) < delta:
			var trk: Track = main.track
			var i := trk.nearest_sample(c.global_position)
			var lat := (c.global_position - trk.centers[i]).dot(trk.rights[i])
			print("   %.2f i=%d lat=%.2f h=%.2f v=%.1f up=%s fwd.t=%.2f st=%.2f thr=%.0f br=%.0f c=%d" % [t, i, lat, c.global_position.y, c.speed, str(c.global_transform.basis.y.snapped(Vector3.ONE*0.01)), (-c.global_transform.basis.z).dot(trk.tangents[i]), c.steer_input, c.throttle, c.brake_input, c.contacts])
		if car_type == dbg_car and absf(t - dbg_t1) < delta * 0.5:
			print("lin=", c.linear_velocity, " throttle=", c.throttle, " brake=", c.brake_input, " steer=", c.steer_input)
		if t > 70.0:
			print("ERGEBNIS ", Car.NAMES[car_type], ": Runden=", main.lap_count, " beste=", main._fmt(main.best_lap),
				" vmax=", int(max_speed * 3.6), " km/h, max Flugzeit=", snappedf(max_air, 0.01))
			if car_type < 2:
				_start_car(car_type + 1)
			else:
				_open_end_test()
				phase = 2
				t = 0.0
	elif phase == 2:
		var c: Car = main.car
		c.throttle = 1.0
		c.steer_input = 0.0
		max_air = maxf(max_air, c.air_time)
		max_speed = maxf(max_speed, c.global_position.y)
		if t > 8.0:
			print("Sprungtest (Strecke endet mit Rampe): max Hoehe=", snappedf(max_speed, 0.1), " max Flugzeit=",
				snappedf(max_air, 0.01), " Endpos=", c.global_position.snapped(Vector3.ONE * 0.1))
			quit()
	return false


func _start_car(type: int) -> void:
	car_type = type
	main.car_type = type
	main._enter_drive()
	t = 0.0
	max_speed = 0.0
	max_air = 0.0
	main.best_lap = INF


func _open_end_test() -> void:
	main._enter_edit()
	main.track.clear()
	for p in [Track.BOOST, Track.STRAIGHT, Track.BOOST, Track.RAMP_UP, Track.RAMP_UP]:
		main.track.add_piece(p)
	main.car_type = Car.RACER
	main._enter_drive()
	max_speed = 0.0
	max_air = 0.0


func _autopilot() -> void:
	var c: Car = main.car
	var trk: Track = main.track
	var idx := trk.nearest_sample(c.global_position, main.progress_idx)
	var n := trk.centers.size()
	var look := 7 + int(absf(c.speed) * 0.35)
	var target := trk.centers[(idx + look) % n]
	var to := target - c.global_position
	var fwd := -c.global_transform.basis.z
	var ang := atan2(fwd.cross(to).y, fwd.dot(to))
	c.steer_input = clampf(-ang * 2.5, -1.0, 1.0)
	# vor engen Kurven bremsen: kleinster Radius auf den naechsten ~30 m
	var limit := 60.0
	for k in range(2, 32, 3):
		var a0 := trk.tangents[(idx + k) % n]
		var a1 := trk.tangents[(idx + k + 4) % n]
		var dth := acos(clampf(Vector2(a0.x, a0.z).normalized().dot(Vector2(a1.x, a1.z).normalized()), -1.0, 1.0))
		if dth > 0.01:
			var rad := 4.0 / dth
			var vmax := sqrt(0.75 * 9.8 * rad)
			# Bremsweg beruecksichtigen
			limit = minf(limit, sqrt(vmax * vmax + 2.0 * 6.0 * k))
	c.throttle = 1.0 if c.speed < limit else 0.0
	c.brake_input = 1.0 if c.speed > limit + 2.0 else 0.0
	if c.speed < 0.5 and c.throttle == 0.0:
		c.throttle = 1.0
		c.brake_input = 0.0

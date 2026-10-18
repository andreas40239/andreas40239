extends SceneTree
## Faehrt mit Vollgas (ohne Lenken) in die Aussenbande einer engen Kurve.
var main: Node
var t := 0.0
var phase := 0
var type := 0
var vmax := 0.0
var worst_lat := 0.0
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.input_enabled = false
func _start() -> void:
	main._enter_edit()
	main.track.clear()
	for p in [Track.BOOST, Track.BOOST, Track.BOOST, Track.STRAIGHT, Track.TIGHT_L, Track.STRAIGHT, Track.STRAIGHT, Track.STRAIGHT]:
		main.track.add_piece(p)
	main.car_type = type
	main._enter_drive()
	t = 0.0
	vmax = 0.0
	worst_lat = 0.0
func _physics_process(delta: float) -> bool:
	t += delta
	if phase == 0:
		_start()
		phase = 1
		return false
	var c: Car = main.car
	c.throttle = 1.0
	c.steer_input = 0.0
	vmax = maxf(vmax, c.speed)
	var trk: Track = main.track
	var i := trk.nearest_sample(c.global_position)
	var lat := absf((c.global_position - trk.centers[i]).dot(trk.rights[i]))
	if i > 3 and i < trk.centers.size() - 3:
		worst_lat = maxf(worst_lat, lat)
	if t > 7.0:
		print("%s: vmax=%d km/h  max. Abstand zur Mitte=%.2f m (Bande innen bei %.2f m)  -> %s  pos=%s" % [Car.NAMES[type], int(vmax * 3.6), worst_lat, Track.WIDTH * 0.5, "OK" if worst_lat < Track.WIDTH * 0.5 else "DURCH DIE BANDE!", c.global_position.snapped(Vector3.ONE * 0.1)])
		type += 1
		if type > 2:
			quit()
		else:
			_start()
	return false

class_name Train
extends Node3D
## Der Zug: Dampflok mit zwei Personenwagen. Bewegt sich entlang der gebauten Gleise;
## Geschwindigkeit, Bremse und Fahrtrichtung steuert der Spieler.

signal crashed(reason: String)
signal arrived
signal chuff(strength: float)
signal bumped

enum State { RUN, CRASHED, DONE }

const BUFFER_GAP := 0.95          # Abstand Prellbock – Kachelkante
const ACCEL := 1.1
const DECEL := 1.7
const BRAKE := 3.6
const REVERSE_MAX := 0.45         # Anteil der Höchstgeschwindigkeit rückwärts
const BUFFER_CRASH_SPEED := 1.9
const ARRIVE_DEPTH := 7.0         # so weit muss die Zugspitze im Zielbahnhof stehen
const CHUFF_DIST := 1.45

var world: World
var state: int = State.RUN
var head := {}                    # {t: Vector2i, li: int, s: float, f: int}
var tail := {}
var speed := 0.0
var throttle := 0.0               # -1 … 1
var braking := false
var length := 0.0
var loco: Node3D
var vehicles: Array[Node3D] = []
var occupied := {}                # Kacheln unter dem Zug
var ahead: Array = []             # [Kachel, Einfahrkante] voraus (für Bahnübergänge/Weichen)
var end_ahead := -1.0             # Entfernung zum Gleisende voraus (-1 = keines in Sicht)
var goal_depth := 0.0             # wie weit die Zugspitze im Zielbahnhof steht
var distance := 0.0               # gefahrene Strecke
var top_speed := 0.0

var _offsets: Array = []          # je Fahrzeug [vorderes, hinteres Drehgestell] ab Zugspitze
var _wheel_phi := 0.0
var _chuff_acc := 0.0
var _puffs: Array = []
var _puff_i := 0
var _idle_t := 0.0
var _arrived_sent := false
var _crash_t := 0.0


func setup(w: World) -> void:
	world = w
	loco = Models.loco()
	add_child(loco)
	vehicles.append(loco)
	var c1 := Models.coach(0)
	var c2 := Models.coach(0, true)
	add_child(c1)
	add_child(c2)
	vehicles.append(c1)
	vehicles.append(c2)
	var half_l := 1.75
	var half_c := 1.67
	var pos := half_l
	_offsets.append([pos - 0.9, pos + 0.9])
	pos += half_l + 0.02 + half_c
	_offsets.append([pos - 0.9, pos + 0.9])
	pos += half_c * 2.0 + 0.02
	_offsets.append([pos - 0.9, pos + 0.9])
	length = pos + half_c
	# Dampfwolken
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	qm.material = Mats.get_mat("puff")
	for i in 22:
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		add_child(mi)
		_puffs.append({"n": mi, "life": 0.0, "max": 1.0, "vel": Vector3.ZERO, "size": 1.0})
	place_at_start()


## Stellt den Zug abfahrbereit in den Startbahnhof.
func place_at_start() -> void:
	state = State.RUN
	speed = 0.0
	throttle = 0.0
	braking = false
	distance = 0.0
	top_speed = 0.0
	_arrived_sent = false
	_crash_t = 0.0
	for v in vehicles:
		v.rotation = Vector3.ZERO
	var t: Vector2i = world.start_tiles.back()
	var p := world.piece_at(t)
	var l: Array = p.links[0]
	var ln := G.link_len(l[0], l[1])
	var f := 1 if l[1] == world.start_exit else -1
	# Zugspitze knapp vor dem Bahnhofsende
	var s := ln - 0.45 if f == 1 else 0.45
	head = {"t": t, "li": 0, "s": s, "f": f}
	tail = walk(head, -length, false)["pos"]
	_update_vehicles(0.0)
	_scan()


# ---------------------------------------------------------------- Bewegung auf dem Gleis

func pos_world(p: Dictionary) -> Array:
	var piece := world.piece_at(p["t"])
	var l: Array = piece.links[p["li"]]
	var pt := G.link_point(l[0], l[1], p["s"])
	return [G.tile_center(p["t"]) + (pt[0] as Vector3), (pt[1] as Vector3) * float(p["f"])]


func _buffer_edge(piece: World.Piece) -> int:
	if piece.kind != G.Kind.STATION:
		return -1
	if piece.tile == world.start_tiles[0]:
		return G.opp(world.start_exit)
	if piece.tile == world.goal_tiles.back():
		return G.opp(world.goal_open)
	return -1


## Bewegt eine Gleisposition um `dist` (vorzeichenbehaftet, in Zugrichtung).
## commit = true stellt stumpf befahrene Weichen um ("aufschneiden").
func walk(p: Dictionary, dist: float, commit: bool) -> Dictionary:
	var t: Vector2i = p["t"]
	var li: int = p["li"]
	var s: float = p["s"]
	var f: int = p["f"]
	var remaining := dist
	var out := {"end": false, "buffer": false, "entered": [], "moved": 0.0}
	var guard := 0
	while guard < 80:
		guard += 1
		var piece := world.piece_at(t)
		if piece == null or li >= piece.links.size():
			out["end"] = true
			break
		var l: Array = piece.links[li]
		var ln := G.link_len(l[0], l[1])
		var lo := 0.0
		var hi := ln
		var be := _buffer_edge(piece)
		if be == l[0]:
			lo = BUFFER_GAP
		elif be == l[1]:
			hi = ln - BUFFER_GAP
		var ns := s + remaining * f
		var exit_edge := -1
		var over := 0.0
		if ns > hi:
			exit_edge = l[1]
			over = ns - hi
			out["moved"] += (hi - s) * f
			s = hi
		elif ns < lo:
			exit_edge = l[0]
			over = lo - ns
			out["moved"] += (lo - s) * f
			s = lo
		else:
			out["moved"] += (ns - s) * f
			s = ns
			break
		if be == exit_edge:
			out["end"] = true
			out["buffer"] = true
			break
		var n := G.step(t, exit_edge)
		var e := G.opp(exit_edge)
		var np := world.piece_at(n)
		var cand: Array[int] = []
		if np != null:
			for i in np.links.size():
				if e in np.links[i]:
					cand.append(i)
		if cand.is_empty():
			out["end"] = true
			break
		var ni := cand[0]
		if cand.size() > 1:
			ni = clampi(np.state, 0, cand.size() - 1)
		elif np.kind == G.Kind.SWITCH and commit:
			world.set_switch(np, ni)
		var nl: Array = np.links[ni]
		var inc: bool = nl[0] == e
		var sgn := 1 if remaining >= 0.0 else -1
		f = sgn * (1 if inc else -1)
		s = 0.0 if inc else G.link_len(nl[0], nl[1])
		remaining = sgn * over
		t = n
		li = ni
		(out["entered"] as Array).append([n, e])
	out["pos"] = {"t": t, "li": li, "s": s, "f": f}
	return out


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	_update_puffs(dt)
	if state == State.CRASHED:
		_crash_anim(dt)
		return
	if state == State.DONE:
		_idle_steam(dt)
		return
	# Geschwindigkeit regeln
	var target := throttle * G.MAX_SPEED
	if target < 0.0:
		target *= REVERSE_MAX
	if braking:
		speed = move_toward(speed, 0.0, BRAKE * dt)
	else:
		var same_dir := signf(target) == signf(speed) or absf(speed) < 0.01
		var rate := ACCEL if (same_dir and absf(target) > absf(speed)) else DECEL
		speed = move_toward(speed, target, rate * dt)
	top_speed = maxf(top_speed, absf(speed))
	var d := speed * dt
	var moved := 0.0
	if d > 0.0:
		var res := walk(head, d, true)
		head = res["pos"]
		moved = res["moved"]
		tail = walk(tail, moved, false)["pos"]
		if res["end"]:
			_hit_end(res["buffer"], true)
	elif d < 0.0:
		var res := walk(tail, d, true)
		tail = res["pos"]
		moved = res["moved"]
		head = walk(head, moved, false)["pos"]
		if res["end"]:
			_hit_end(res["buffer"], false)
	distance += absf(moved)
	_update_vehicles(moved)
	_scan()
	# Dampfschläge
	if absf(moved) > 0.0:
		_chuff_acc += absf(moved)
		if _chuff_acc >= CHUFF_DIST:
			_chuff_acc = 0.0
			var pulling := absf(target) > absf(speed) + 0.05 and not braking
			var strength := 1.0 if pulling else 0.55
			chuff.emit(strength)
			_emit_puff(strength)
	else:
		_idle_steam(dt)
	# Ankunft
	_update_goal_depth()
	if not _arrived_sent and absf(speed) < 0.02 and goal_depth >= ARRIVE_DEPTH and (braking or absf(throttle) < 0.05):
		_arrived_sent = true
		state = State.DONE
		speed = 0.0
		arrived.emit()


func _hit_end(buffer: bool, front: bool) -> void:
	if buffer:
		if absf(speed) > BUFFER_CRASH_SPEED:
			_crash("Zu schnell! Der Zug ist auf den Prellbock geprallt.", front)
		else:
			if absf(speed) > 0.3:
				bumped.emit()
			speed = 0.0
	else:
		_crash("Entgleist! Hier endet das Gleis." if absf(speed) > 0.0 else "", front)


func _crash(reason: String, _front: bool) -> void:
	state = State.CRASHED
	_crash_t = 0.0
	speed = 0.0
	throttle = 0.0
	for i in 6:
		_emit_puff(1.0)
	crashed.emit(reason)


func _crash_anim(dt: float) -> void:
	_crash_t += dt
	var k := clampf(_crash_t / 0.7, 0.0, 1.0)
	var ease_k := 1.0 - pow(1.0 - k, 3.0)
	loco.rotation.z = deg_to_rad(16.0) * ease_k
	loco.rotation.x = deg_to_rad(-5.0) * ease_k
	if vehicles.size() > 1:
		vehicles[1].rotation.z = deg_to_rad(-7.0) * ease_k


func _update_goal_depth() -> void:
	goal_depth = 0.0
	if world.goal_tiles.has(head["t"]):
		var entry: Vector3 = G.tile_center(world.goal_tiles[0]) + G.dir_vec(world.goal_open) * (G.T * 0.5)
		var hp: Vector3 = pos_world(head)[0]
		goal_depth = (hp - entry).dot(G.dir_vec(G.opp(world.goal_open)))


func in_goal() -> bool:
	return goal_depth >= ARRIVE_DEPTH


func _update_vehicles(moved: float) -> void:
	occupied.clear()
	for i in vehicles.size():
		var off: Array = _offsets[i]
		var pf: Dictionary = walk(head, -off[0], false)["pos"]
		var pr: Dictionary = walk(head, -off[1], false)["pos"]
		occupied[pf["t"]] = true
		occupied[pr["t"]] = true
		var a: Vector3 = pos_world(pf)[0]
		var b: Vector3 = pos_world(pr)[0]
		var fwd := a - b
		if fwd.length_squared() < 1e-6:
			continue
		var v := vehicles[i]
		var keep := v.rotation
		v.global_transform = Transform3D(Basis.looking_at(fwd.normalized(), Vector3.UP), (a + b) * 0.5)
		if state == State.CRASHED:
			v.rotation.z = keep.z
			v.rotation.x = keep.x
	occupied[head["t"]] = true
	occupied[tail["t"]] = true
	# Räder und Kuppelstangen
	if moved != 0.0:
		for v in vehicles:
			var r: float = v.get_meta("wheel_r")
			var idx := 0
			for w in v.get_meta("wheels"):
				(w as Node3D).rotation.x -= moved / r
				idx += 1
		var lr: float = loco.get_meta("wheel_r")
		_wheel_phi -= moved / lr
		var rods: Array = loco.get_meta("rods")
		var ry: float = loco.get_meta("rod_y")
		for i in rods.size():
			var phi := _wheel_phi + (PI * 0.5 if i == 0 else 0.0)
			(rods[i] as Node3D).position.y = ry + 0.2 * cos(phi)
			(rods[i] as Node3D).position.z = 0.2 * sin(phi)


func init_wheel_phases() -> void:
	var wheels: Array = loco.get_meta("wheels")
	for i in wheels.size():
		(wheels[i] as Node3D).rotation.x = PI * 0.5 if i < 3 else 0.0


## Fahrtrichtung für Vorausschau: +1 vorwärts, -1 rückwärts, 0 Stillstand ohne Fahrbefehl.
func move_dir() -> int:
	if absf(speed) > 0.05:
		return 1 if speed > 0.0 else -1
	if absf(throttle) > 0.05 and not braking:
		return 1 if throttle > 0.0 else -1
	return 0


func _scan() -> void:
	ahead.clear()
	end_ahead = -1.0
	var dir := move_dir()
	if dir == 0:
		return
	var look := 8.0 + absf(speed) * 2.4
	var res := walk(head if dir > 0 else tail, look * dir, false)
	ahead = res["entered"]
	if res["end"] and not res["buffer"]:
		end_ahead = absf(res["moved"])


## Nächste spitz befahrene Weiche in Fahrtrichtung (oder null).
func next_switch(max_dist: float = 60.0) -> World.Piece:
	var dir := move_dir()
	if dir == 0:
		dir = 1
	var res := walk(head if dir > 0 else tail, max_dist * dir, false)
	for en in res["entered"]:
		var p := world.piece_at(en[0])
		if p != null and p.kind == G.Kind.SWITCH and TrackModels.switch_stem(p.links) == en[1]:
			return p
	return null


# ---------------------------------------------------------------- Dampf

func _emit_puff(strength: float) -> void:
	var p: Dictionary = _puffs[_puff_i]
	_puff_i = (_puff_i + 1) % _puffs.size()
	var n: MeshInstance3D = p["n"]
	n.global_position = loco.global_transform * (loco.get_meta("chimney") as Vector3)
	n.visible = true
	p["life"] = 0.0
	p["max"] = randf_range(1.5, 2.3)
	p["size"] = randf_range(0.7, 1.0) * (0.75 + 0.5 * strength)
	var back := loco.global_transform.basis.z * speed * 0.25
	p["vel"] = Vector3(randf_range(-0.25, 0.25), randf_range(1.6, 2.3) * (0.6 + 0.4 * strength), randf_range(-0.25, 0.25)) + back


func _idle_steam(dt: float) -> void:
	_idle_t += dt
	if _idle_t > 0.9:
		_idle_t = 0.0
		_emit_puff(0.25)


func _update_puffs(dt: float) -> void:
	for p in _puffs:
		var n: MeshInstance3D = p["n"]
		if not n.visible:
			continue
		p["life"] += dt
		var k: float = p["life"] / p["max"]
		if k >= 1.0:
			n.visible = false
			continue
		p["vel"] = (p["vel"] as Vector3) * (1.0 - 0.9 * dt) + Vector3(0.5, 0.0, 0.15) * dt
		n.global_position += (p["vel"] as Vector3) * dt
		var sz: float = p["size"] * (0.5 + 2.4 * k)
		n.scale = Vector3(sz, sz, sz)
		n.transparency = clampf(0.15 + k * k * 0.85, 0.0, 1.0)

class_name ZombieAI
extends Brain
## KI für Zombies: schlurfen, horchen, Geräuschen nachrennen, Verstecke absuchen, beißen.

enum S { WANDER, CHASE, SEARCH, INVESTIGATE, CHECK, LOOK, LISTEN, LURE }

var state := S.LOOK
var target: Character = null
var last_seen := Vector3.ZERO
var seen_t := 0.0
var spot: HidingSpot = null
var sniff_t := 0.0
var timer := 1.0
var listen_cd := 0.0
var think_t := 0.0
var repath_t := 0.0


func _init(p_char: Character, p_game) -> void:
	super(p_char, p_game)
	listen_cd = rng.randf_range(10.0, 20.0)


func think(delta: float) -> void:
	c.want_listen = false
	if not c.can_act():
		c.move_dir = Vector3.ZERO
		_clear_sniff()
		return

	# Knoblauch: Abstand halten
	var g := _garlic_threat()
	if g != null:
		var away := c.global_position - g.global_position
		away.y = 0
		c.move_dir = away.normalized() if away.length() > 0.05 else Vector3(1, 0, 0)
		walk_slow = false
		_clear_sniff()
		if target == g:
			target = null
		state = S.LOOK
		timer = 0.6
		return

	# Melone: alles andere ist egal
	if c.lure_t > 0.0:
		_clear_sniff()
		walk_slow = false
		if state != S.LURE:
			state = S.LURE
			go_to(c.lure_pos)
		if c.global_position.distance_to(c.lure_pos) > 1.1 and not arrived():
			follow(delta)
		else:
			c.move_dir = Vector3.ZERO
			c.face_towards(c.lure_pos)
		return
	elif state == S.LURE:
		state = S.LOOK
		timer = 1.0

	think_t -= delta
	if think_t <= 0.0:
		think_t = 0.15
		var t := _nearest_visible()
		if t != null and (state != S.CHASE or t != target):
			if state != S.CHASE or target == null or not game.can_see(c, target):
				_clear_sniff()
				target = t
				state = S.CHASE
				seen_t = 0.0
				repath_t = 0.0

	match state:
		S.CHASE:
			_chase(delta)
		S.SEARCH, S.INVESTIGATE:
			walk_slow = false
			follow(delta)
			if arrived():
				state = S.LOOK
				timer = rng.randf_range(1.0, 2.0)
		S.CHECK:
			_check(delta)
		S.LOOK:
			c.move_dir = Vector3.ZERO
			c.facing += delta * 1.6
			c.rotation.y = c.facing
			timer -= delta
			if timer <= 0.0:
				_pick_wander()
		S.LISTEN:
			c.move_dir = Vector3.ZERO
			c.want_listen = true
			timer -= delta
			if timer <= 0.0:
				_listen_result()
		S.WANDER:
			walk_slow = true
			follow(delta)
			listen_cd -= delta
			if listen_cd <= 0.0:
				listen_cd = rng.randf_range(14.0, 26.0)
				state = S.LISTEN
				timer = 1.8
				Sfx.play_at("listen", c.global_position, -6.0)
			elif arrived():
				state = S.LOOK
				timer = rng.randf_range(0.4, 1.4)


func _chase(delta: float) -> void:
	walk_slow = false
	if target == null or not target.is_active_human():
		target = null
		state = S.LOOK
		timer = 0.8
		return
	if target.hidden_in != null:
		if seen_t < 0.9:
			# hat gesehen, wie sich das Opfer versteckt
			spot = target.hidden_in
			sniff_t = 0.0
			state = S.CHECK
			go_to(spot.nearest_access(c.global_position))
		else:
			state = S.SEARCH
			go_to(last_seen)
		return
	if game.can_see(c, target):
		seen_t = 0.0
		last_seen = target.global_position
		var d := c.global_position.distance_to(target.global_position)
		if d < Cfg.BITE_RANGE * 0.9:
			c.move_dir = Vector3.ZERO
			c.face_towards(target.global_position)
			game.try_bite(c, target)
			return
		repath_t -= delta
		if repath_t <= 0.0:
			repath_t = 0.25
			go_to(target.global_position)
		follow(delta)
		if arrived():
			# direkt drauf zu
			var dv := target.global_position - c.global_position
			dv.y = 0
			c.move_dir = dv.normalized()
	else:
		seen_t += delta
		follow(delta)
		if seen_t > 0.4:
			state = S.SEARCH
			go_to(last_seen)


func _check(delta: float) -> void:
	walk_slow = c.sprint_t <= 0.0 and seen_t > 2.0
	seen_t += delta
	if spot == null:
		state = S.LOOK
		timer = 0.5
		return
	if not arrived():
		follow(delta)
		return
	c.move_dir = Vector3.ZERO
	c.face_towards(spot.global_position)
	if spot.sniffed_by == null:
		spot.sniffed_by = c
		Sfx.play_at("zombie_groan_%d" % rng.randi_range(1, 4), c.global_position, -2.0)
	sniff_t += delta
	if sniff_t >= Cfg.SNIFF_TIME:
		for v in spot.occupants():
			if game.try_bite(c, v):
				break
		_clear_sniff()
		state = S.LOOK
		timer = 1.0


func _clear_sniff() -> void:
	if spot != null and spot.sniffed_by == c:
		spot.sniffed_by = null
	sniff_t = 0.0
	if state == S.CHECK:
		spot = null
		state = S.LOOK
		timer = 0.5


func _pick_wander() -> void:
	target = null
	if rng.randf() < 0.3 and not game.spots.is_empty():
		spot = game.spots[rng.randi_range(0, game.spots.size() - 1)]
		sniff_t = 0.0
		seen_t = 10.0
		state = S.CHECK
		go_to(spot.nearest_access(c.global_position))
		return
	state = S.WANDER
	go_to(Nav.center(game.nav.random_free()))


func _listen_result() -> void:
	var best: Character = null
	var bd := 11.0
	for h in game.humans():
		if h.frozen:
			continue
		var d: float = c.global_position.distance_to(h.global_position)
		if d < bd:
			bd = d
			best = h
	if best == null:
		_pick_wander()
	elif best.hidden_in != null:
		spot = best.hidden_in
		sniff_t = 0.0
		seen_t = 10.0
		state = S.CHECK
		go_to(spot.nearest_access(c.global_position))
	else:
		state = S.INVESTIGATE
		go_to(best.global_position)


func _nearest_visible() -> Character:
	var best: Character = null
	var bd := INF
	for h in game.humans():
		if h.garlic_t > 0.0:
			continue
		if not game.can_see(c, h):
			continue
		var d: float = c.global_position.distance_squared_to(h.global_position)
		if d < bd:
			bd = d
			best = h
	return best


func _garlic_threat() -> Character:
	for h in game.humans():
		if h.garlic_t > 0.0 and h.hidden_in == null:
			if c.global_position.distance_to(h.global_position) < Cfg.GARLIC_RADIUS:
				return h
	return null


func on_noise(pos: Vector3, lure: bool) -> void:
	if lure or not c.can_act():
		return
	c.try_sprint()
	if state == S.CHASE and target != null and game.can_see(c, target):
		return
	_clear_sniff()
	state = S.INVESTIGATE
	go_to(pos)

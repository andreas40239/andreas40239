class_name HumanAI
extends Brain
## KI für Computerspieler (Menschen): herumlaufen, Upgrades holen, verstecken,
## still stehen, flüchten, Melone werfen.

enum S { PAUSE, WANDER, GO_HIDE, FLEE, GET_ITEM, FREEZE }

var state := S.PAUSE
var careless := 0.25          # Wahrscheinlichkeit, unnötig zu rennen
var timer := 0.5
var think_t := 0.0
var spot: HidingSpot = null
var item: Pickup = null
var threat: Character = null
var threat_d := INF
var no_threat_t := 99.0
var run := false
var flee_repick := 0.0
var bolt_t := -1.0
var bolt_decided := false
var prep_decided := false
var hide_time := 0.0


func _init(p_char: Character, p_game) -> void:
	super(p_char, p_game)
	careless = rng.randf_range(0.15, 0.45)
	timer = rng.randf_range(0.3, 1.5)


func think(delta: float) -> void:
	c.want_freeze = false
	timer -= delta
	think_t -= delta
	if think_t <= 0.0:
		think_t = 0.2
		_perceive()
	no_threat_t = 0.0 if threat != null else no_threat_t + delta

	if c.hidden_in != null:
		_think_hidden(delta)
		return

	# --- Reaktion auf Zombies
	if threat != null and state != S.FLEE and state != S.FREEZE:
		var chased := _is_chased()
		if threat_d < 6.5 or chased:
			if not chased and c.freeze_left > 4.0 and c.freeze_lock <= 0.0 and rng.randf() < 0.35:
				state = S.FREEZE
				timer = rng.randf_range(2.5, 5.0)
			else:
				_start_flee()
		elif state != S.GO_HIDE:
			# Zombie in der Ferne: leise verdrücken
			var s := _find_spot(8.0)
			if s != null:
				_go_hide(s, false)
			else:
				_start_flee()
				run = false

	match state:
		S.PAUSE:
			c.move_dir = Vector3.ZERO
			c.want_sneak = false
			if timer <= 0.0:
				_decide()
		S.WANDER:
			c.want_sneak = not run
			follow(delta)
			if arrived():
				state = S.PAUSE
				timer = rng.randf_range(0.4, 2.2)
			elif game.phase == game.Phase.PREP and game.prep_left < 7.0 and not prep_decided:
				prep_decided = true
				if rng.randf() < 0.75:
					var s := _find_spot(30.0)
					if s != null:
						_go_hide(s, true)
		S.GET_ITEM:
			c.want_sneak = not run
			if item == null or not is_instance_valid(item) or not game.pickups.has(item):
				item = null
				state = S.PAUSE
				timer = 0.3
			else:
				follow(delta)
				if arrived():
					go_to(item.global_position)
		S.GO_HIDE:
			c.want_sneak = not run
			if spot == null or not spot.has_room():
				state = S.PAUSE
				timer = 0.2
			else:
				follow(delta)
				if arrived():
					if game.hide_in(c, spot):
						hide_time = rng.randf_range(8.0, 22.0)
						bolt_decided = false
						bolt_t = -1.0
					state = S.PAUSE
					timer = 0.5
		S.FLEE:
			_flee(delta)
		S.FREEZE:
			c.move_dir = Vector3.ZERO
			c.want_freeze = true
			if timer <= 0.0 or c.freeze_left < 0.4 or no_threat_t > 1.5 or (threat != null and _is_chased()):
				if threat != null and threat_d < 7.0:
					_start_flee()
				else:
					state = S.PAUSE
					timer = 0.5


func _think_hidden(delta: float) -> void:
	c.move_dir = Vector3.ZERO
	hide_time -= delta
	var s := c.hidden_in
	if s.sniffed_by != null:
		if not bolt_decided:
			bolt_decided = true
			if rng.randf() < 0.6:
				bolt_t = rng.randf_range(0.2, 1.1)
	else:
		bolt_decided = false
	if bolt_t >= 0.0:
		bolt_t -= delta
		if bolt_t <= 0.0:
			bolt_t = -1.0
			game.hide_out(c)
			_start_flee()
			return
	if hide_time <= 0.0:
		if threat == null and no_threat_t > 2.0:
			game.hide_out(c)
			state = S.PAUSE
			timer = 0.3
		else:
			hide_time = 3.0


func on_bitten() -> void:
	bolt_t = -1.0
	_start_flee()


func _perceive() -> void:
	threat = null
	threat_d = INF
	for z in game.zombies():
		var d: float = c.global_position.distance_to(z.global_position)
		if d >= threat_d:
			continue
		if d < 3.0 or (d < 12.0 and game.nav.los(c.global_position, z.global_position)):
			threat = z
			threat_d = d


func _is_chased() -> bool:
	if threat == null:
		return false
	if threat.brain is ZombieAI:
		return threat.brain.target == c and threat.brain.state == ZombieAI.S.CHASE
	# Spieler-Zombie: kommt er auf mich zu?
	var to_me := (c.global_position - threat.global_position).normalized()
	return threat_d < 6.0 and threat.moving and threat.velocity.normalized().dot(to_me) > 0.5


func _decide() -> void:
	# Upgrade in der Nähe?
	if threat == null and not game.pickups.is_empty() and rng.randf() < 0.7:
		var best: Pickup = null
		var bd := 16.0
		for p in game.pickups:
			var d: float = c.global_position.distance_to(p.global_position)
			if d < bd:
				bd = d
				best = p
		if best != null:
			item = best
			state = S.GET_ITEM
			run = game.phase == game.Phase.PREP or rng.randf() < 0.5
			go_to(best.global_position)
			return
	if game.phase == game.Phase.HUNT and rng.randf() < 0.3:
		var s := _find_spot(12.0)
		if s != null:
			_go_hide(s, false)
			return
	state = S.WANDER
	run = rng.randf() < (0.6 if game.phase == game.Phase.PREP else careless)
	go_to(Nav.center(game.nav.random_free()))


func _go_hide(s: HidingSpot, p_run: bool) -> void:
	spot = s
	state = S.GO_HIDE
	run = p_run
	go_to(s.nearest_access(c.global_position))


func _find_spot(max_d: float) -> HidingSpot:
	var best: HidingSpot = null
	var bs := INF
	for s in game.spots:
		if not s.has_room():
			continue
		var d: float = s.global_position.distance_to(c.global_position)
		if d > max_d:
			continue
		var score := d + rng.randf() * 4.0
		if threat != null:
			# nicht auf den Zombie zu und nicht in seinem Blickfeld verstecken
			if s.global_position.distance_to(threat.global_position) < d:
				continue
			if game.nav.los(s.nearest_access(c.global_position), threat.global_position):
				score += 6.0
		if score < bs:
			bs = score
			best = s
	return best


func _start_flee() -> void:
	state = S.FLEE
	run = true
	flee_repick = 0.0


func _flee(delta: float) -> void:
	c.want_sneak = not run
	if threat != null:
		# Melone werfen, wenn es eng wird
		if c.has_melon and threat_d < 5.5:
			var dir := threat.global_position - c.global_position
			dir.y = 0
			game.throw_melon(c, dir.normalized())
		run = threat_d < 9.0 or _is_chased()
	flee_repick -= delta
	if flee_repick <= 0.0 or arrived():
		flee_repick = 1.0
		if threat != null:
			_pick_flee_goal()
		elif no_threat_t > 2.5:
			var s := _find_spot(10.0)
			if s != null and rng.randf() < 0.6:
				_go_hide(s, false)
			else:
				state = S.PAUSE
				timer = 0.5
			return
	follow(delta)


func _pick_flee_goal() -> void:
	var me := c.global_position
	var zp := threat.global_position
	var to_z := (zp - me).normalized()
	var cands: Array = []
	for i in 16:
		var p := Nav.center(game.nav.random_free())
		var dz := p.distance_to(zp)
		var dm := p.distance_to(me)
		var score := dz - 0.35 * dm
		if dm > 1.0 and (p - me).normalized().dot(to_z) > 0.5:
			score -= 6.0
		if not game.nav.los(p, zp):
			score += 3.0
		cands.append([score, p])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(4, cands.size()):
		var p: Vector3 = cands[i][1]
		var path: PackedVector3Array = game.nav.path(me, p)
		if path.is_empty():
			continue
		var first := (path[0] - me)
		first.y = 0
		if threat_d < 4.5 and first.length() > 0.1 and first.normalized().dot(to_z) > 0.6:
			continue   # der Weg führt direkt in den Zombie
		go_to(p)
		return
	go_to(cands[0][1])

class_name Traffic
extends Node3D
## Straßenverkehr: Autos fahren auf den Straßen, halten vor geschlossenen
## Bahnübergängen, hinter anderen Autos und an belegten Kreuzungen.

const LANE := 0.7
const RUNOUT := 64.0              # so weit außerhalb des Spielfelds starten/enden die Autos
const STOP_BEFORE := 3.0         # Haltelinie vor der Mitte des Bahnübergangs
const ACC := 3.2
const DEC := 7.0

class Car:
	var node: Node3D
	var road: int
	var dir: int                 # +1 / -1 entlang der Straßenachse
	var pos: float               # Koordinate entlang der Achse (Fahrzeugmitte)
	var speed: float
	var cruise: float
	var half: float
	var wait: float = 0.0
	var holds: Array = []        # reservierte Kreuzungen

var world: World
var cars: Array[Car] = []
var _inter: Dictionary = {}       # Kreuzungskachel -> {"axis": int, "n": int}
var _rng := RandomNumberGenerator.new()
var _seed := 1


func setup(w: World, count: int) -> void:
	world = w
	_rng.seed = 99 + w.index
	if world.roads.is_empty():
		return
	for i in count:
		var c := Car.new()
		_respawn(c, true)
		cars.append(c)


func _road_len(r: Dictionary) -> float:
	return (world.w if r["axis"] == 0 else world.h) * G.T


func _respawn(c: Car, anywhere: bool) -> void:
	if c.node != null:
		c.node.queue_free()
	_seed += 1
	c.node = Models.car(_seed * 31 + world.index)
	add_child(c.node)
	c.half = float(c.node.get_meta("length")) * 0.5
	for attempt in 12:
		c.road = _rng.randi() % world.roads.size()
		c.dir = 1 if _rng.randf() < 0.5 else -1
		var ln := _road_len(world.roads[c.road])
		if anywhere:
			c.pos = _rng.randf_range(-RUNOUT, ln + RUNOUT)
		else:
			c.pos = -RUNOUT if c.dir > 0 else ln + RUNOUT
		if _lane_free(c):
			break
		anywhere = false
	c.cruise = _rng.randf_range(4.4, 6.2)
	c.speed = c.cruise
	c.wait = 0.0
	c.holds.clear()
	_place(c)


func _lane_free(c: Car) -> bool:
	for o in cars:
		if o != c and o.road == c.road and o.dir == c.dir and absf(o.pos - c.pos) < 5.0:
			return false
	# nicht mitten auf einem Bahnübergang oder einer Kreuzung starten
	var r: Dictionary = world.roads[c.road]
	var tc := floori(c.pos / G.T)
	var t := Vector2i(tc, r["idx"]) if r["axis"] == 0 else Vector2i(r["idx"], tc)
	if world.in_bounds(t):
		var cell := world.cell(t)
		if cell.piece != null or cell.road_axis == 2:
			return false
	return true


func _place(c: Car) -> void:
	var r: Dictionary = world.roads[c.road]
	var center: float = (r["idx"] + 0.5) * G.T
	var p: Vector3
	var fwd: Vector3
	if r["axis"] == 0:
		p = Vector3(c.pos, 0.07, center + LANE * c.dir)
		fwd = Vector3(c.dir, 0, 0)
	else:
		p = Vector3(center - LANE * c.dir, 0.07, c.pos)
		fwd = Vector3(0, 0, c.dir)
	# über den Bahnübergang leicht anheben
	var tc := floori(c.pos / G.T)
	var t := Vector2i(tc, r["idx"]) if r["axis"] == 0 else Vector2i(r["idx"], tc)
	if world.in_bounds(t) and world.cell(t).piece != null:
		var local := absf(c.pos - (tc + 0.5) * G.T)
		p.y += 0.2 * clampf((2.0 - local) / 0.85, 0.0, 1.0)
	c.node.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), p)


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	for c in cars:
		_step(c, dt)


func _step(c: Car, dt: float) -> void:
	var r: Dictionary = world.roads[c.road]
	var axis: int = r["axis"]
	var idx: int = r["idx"]
	var ln := _road_len(r)
	var front := c.pos + c.dir * c.half
	var stop_dist := 1e9          # Strecke bis zum nächsten Haltepunkt (ab Fahrzeugfront)
	# Vorausfahrendes Auto
	for o in cars:
		if o == c or o.road != c.road or o.dir != c.dir:
			continue
		var gap := (o.pos - o.dir * o.half - front) * c.dir
		if gap > -1.0:
			stop_dist = minf(stop_dist, gap - 1.1)
	# Bahnübergänge und Kreuzungen auf den nächsten Kacheln
	var tile_now := floori(front / G.T)
	for k in range(0, 4):
		var tc := tile_now + k * c.dir
		var t := Vector2i(tc, idx) if axis == 0 else Vector2i(idx, tc)
		if not world.in_bounds(t):
			continue
		var cell := world.cell(t)
		var ctr := (tc + 0.5) * G.T
		if cell.piece != null and cell.piece.kind == G.Kind.CROSSING:
			var line := ctr - c.dir * STOP_BEFORE
			var d := (line - front) * c.dir
			var blocked := cell.piece.active or cell.piece.closed > 0.04
			if blocked and d > -0.4:
				stop_dist = minf(stop_dist, d)
		elif cell.road_axis == 2:
			var line := ctr - c.dir * 2.1
			var d := (line - front) * c.dir
			var rear_past := (c.pos - c.dir * c.half - (ctr + c.dir * 1.9)) * c.dir > 0.0
			if c.holds.has(t):
				if rear_past:
					_release(c, t)
			elif d > -0.5 and d < 3.5:
				var st: Dictionary = _inter.get(t, {"axis": axis, "n": 0})
				if st["n"] == 0 or st["axis"] == axis:
					if d < 1.2:
						st["axis"] = axis
						st["n"] += 1
						_inter[t] = st
						c.holds.append(t)
				else:
					stop_dist = minf(stop_dist, d)
	var target := c.cruise
	if stop_dist < 1e8:
		target = minf(target, sqrt(maxf(0.0, 2.0 * DEC * 0.55 * maxf(stop_dist, 0.0))))
		if stop_dist < 0.08:
			target = 0.0
	if target > c.speed:
		c.speed = minf(target, c.speed + ACC * dt)
	else:
		c.speed = maxf(target, c.speed - DEC * dt)
	c.pos += c.dir * c.speed * dt
	_place(c)
	if (c.dir > 0 and c.pos > ln + RUNOUT) or (c.dir < 0 and c.pos < -RUNOUT):
		for t in c.holds.duplicate():
			_release(c, t)
		_respawn(c, false)


func _release(c: Car, t: Vector2i) -> void:
	c.holds.erase(t)
	if _inter.has(t):
		_inter[t]["n"] = maxi(0, int(_inter[t]["n"]) - 1)

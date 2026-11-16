class_name Nav
extends RefCounted
## Wegfindung (A* auf dem Zellraster) und Sichtlinien auf Basis des Grundrisses.

var apt: ApartmentGen
var astar := AStar2D.new()
var free: Array[Vector2i] = []
var rng := RandomNumberGenerator.new()


func setup(p_apt: ApartmentGen) -> void:
	apt = p_apt
	rng.seed = apt.seed_used + 77
	astar.clear()
	free = apt.free_cells()
	for c in free:
		astar.add_point(_id(c.x, c.y), Vector2(c.x + 0.5, c.y + 0.5))
	for c in free:
		var x := c.x
		var y := c.y
		if _open(x, y, x + 1, y):
			astar.connect_points(_id(x, y), _id(x + 1, y))
		if _open(x, y, x, y + 1):
			astar.connect_points(_id(x, y), _id(x, y + 1))
		for dx in [-1, 1]:
			# Diagonale nur, wenn beide Wege um die Ecke frei sind
			var nx: int = x + dx
			var ny: int = y + 1
			if _open(x, y, nx, y) and _open(nx, y, nx, ny) and _open(x, y, x, ny) and _open(x, ny, nx, ny):
				astar.connect_points(_id(x, y), _id(nx, ny))


func _id(x: int, y: int) -> int:
	return y * apt.w + x


func _open(ax: int, ay: int, bx: int, by: int) -> bool:
	return not apt.is_blocked(ax, ay) and not apt.is_blocked(bx, by) and apt.passable(ax, ay, bx, by)


static func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))


static func center(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, 0.0, c.y + 0.5)


func is_free(c: Vector2i) -> bool:
	return apt.in_bounds(c.x, c.y) and not apt.is_blocked(c.x, c.y)


func nearest_free(p: Vector3) -> Vector2i:
	var c := cell_of(p)
	if is_free(c):
		return c
	var id := astar.get_closest_point(Vector2(p.x, p.z))
	return Vector2i(id % apt.w, id / apt.w)


func random_free() -> Vector2i:
	return free[rng.randi_range(0, free.size() - 1)]


func random_free_in_room(room_id: int) -> Vector2i:
	for i in 40:
		var c := random_free()
		if apt.room_at(c.x, c.y) == room_id:
			return c
	return random_free()


## Pfad als Liste von Wegpunkten (Weltkoordinaten, y = 0), ohne den Startpunkt.
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := nearest_free(from)
	var b := nearest_free(to)
	var out := PackedVector3Array()
	if a == b:
		out.append(Vector3(to.x, 0, to.z) if cell_of(to) == b else center(b))
		return out
	var pts := astar.get_point_path(_id(a.x, a.y), _id(b.x, b.y))
	for i in range(1, pts.size()):
		out.append(Vector3(pts[i].x, 0, pts[i].y))
	if out.size() > 0 and cell_of(to) == b:
		out[out.size() - 1] = Vector3(to.x, 0, to.z)
	return out


func path_len(from: Vector3, to: Vector3) -> float:
	var p := path(from, to)
	var d := 0.0
	var prev := Vector3(from.x, 0, from.z)
	for q in p:
		d += prev.distance_to(q)
		prev = q
	return d


## Sichtlinie: blockiert durch Wände (nicht durch Türöffnungen) und hohe Möbel.
func los(a: Vector3, b: Vector3) -> bool:
	return _trace(a, b, true)


## Freie Laufstrecke für eine Figur mit Radius r (Wände und alle Möbel blockieren).
func walk_clear(a: Vector3, b: Vector3, r := 0.3) -> bool:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	if d.length() < 0.01:
		return true
	var n := Vector3(-d.z, 0, d.x).normalized() * r
	return _trace(a, b, false) and _trace(a + n, b + n, false) and _trace(a - n, b - n, false)


func _trace(a: Vector3, b: Vector3, sight: bool) -> bool:
	var ax := a.x
	var az := a.z
	var dx := b.x - ax
	var dz := b.z - az
	var dist := sqrt(dx * dx + dz * dz)
	var steps := maxi(1, ceili(dist / 0.2))
	var cx := floori(ax)
	var cy := floori(az)
	if sight:
		if not apt.in_bounds(cx, cy):
			return false
	elif apt.is_blocked(cx, cy):
		return false
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var nx := floori(ax + dx * t)
		var ny := floori(az + dz * t)
		if nx == cx and ny == cy:
			continue
		if not apt.in_bounds(nx, ny):
			return false
		if nx != cx and ny != cy:
			# Diagonalsprung über eine Ecke
			var r1 := _step_ok(cx, cy, nx, cy, sight) and _step_ok(nx, cy, nx, ny, sight)
			var r2 := _step_ok(cx, cy, cx, ny, sight) and _step_ok(cx, ny, nx, ny, sight)
			if sight:
				if not (r1 or r2):
					return false
			elif not (r1 and r2):
				return false
		elif not _step_ok(cx, cy, nx, ny, sight):
			return false
		cx = nx
		cy = ny
	return true


func _step_ok(ax: int, ay: int, bx: int, by: int, sight: bool) -> bool:
	if not apt.passable(ax, ay, bx, by):
		return false
	if sight:
		# Start-/Zielzelle dürfen "hoch" sein (z. B. Blick auf einen Schrank), dazwischen nicht
		return not apt.is_tall(bx, by)
	return not apt.is_blocked(bx, by)

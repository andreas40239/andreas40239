extends Node2D
## Zeichnet alles Bewegte der Karte: Ringe, Feuer, Wasser, Tore, Fackeln, Portal.

const T := 32

var game: Node


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam: Vector2 = game.camera.get_screen_center_position()
	var half: Vector2 = get_viewport_rect().size * 0.5 / game.camera.zoom + Vector2(64, 64)
	var x0 := maxi(0, floori((cam.x - half.x) / T))
	var x1 := mini(game.map_w - 1, floori((cam.x + half.x) / T))
	var y0 := maxi(0, floori((cam.y - half.y) / T))
	var y1 := mini(game.map_h - 1, floori((cam.y + half.y) / T))
	var t: float = game.time
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			var ch: String = game.tile_at(tx, ty)
			match ch:
				"~":
					_water(tx, ty, t)
				"F":
					_fire(tx, ty, t)
				"a", "b", "c", "A", "B", "G":
					_gate(tx, ty, ch)
				"t":
					_torch(tx, ty, t)
				"E":
					_portal(tx, ty, t)
				"L":
					_door(tx, ty)
	if game.has_rings and cam.distance_to(game.ring_center) < 700.0:
		_rings()


func _water(tx: int, ty: int, t: float) -> void:
	var r := Rect2(tx * T, ty * T, T, T)
	draw_rect(r, Color(0.08, 0.2, 0.35))
	for i in 2:
		var y := ty * T + 8 + i * 14 + sin(t * 2.0 + tx * 0.9 + i) * 3.0
		var x := tx * T + 4 + fmod(t * 6.0 + ty * 7 + i * 11, 16.0)
		draw_line(Vector2(x, y), Vector2(x + 10, y), Color(0.4, 0.65, 0.9, 0.45), 1.5)
	# Ufer
	if game.tile_at(tx, ty - 1) != "~":
		draw_rect(Rect2(r.position, Vector2(T, 3)), Color(0.6, 0.8, 1.0, 0.35))


func _fire(tx: int, ty: int, t: float) -> void:
	var st: int = game.fire_burning_at(tx, ty)
	var c := Rect2(tx * T, ty * T, T, T).get_center()
	if st == 1:
		var a := 0.35 + 0.35 * sin(t * 25.0)
		draw_circle(c, 10, Color(1.0, 0.35, 0.05, a))
		for i in 3:
			draw_circle(c + Vector2(sin(t * 3.0 + i * 2.0) * 6.0, -fmod(t * 20.0 + i * 7.0, 18.0)), 2.5, Color(0.5, 0.5, 0.5, 0.4))
	elif st == 2:
		draw_circle(c, 14, Color(1.0, 0.3, 0.0, 0.35))
		for i in 4:
			var ph := t * 9.0 + i * 1.7 + tx * 1.3 + ty * 0.7
			var hgt := 18.0 + sin(ph) * 6.0
			var off := Vector2((i - 1.5) * 6.0, 4)
			var pts := PackedVector2Array([c + off + Vector2(-5, 6), c + off + Vector2(0, -hgt), c + off + Vector2(5, 6)])
			draw_colored_polygon(pts, Color(1.0, 0.45 + 0.1 * i, 0.05, 0.9))
		draw_circle(c + Vector2(0, 4), 5, Color(1, 0.95, 0.6, 0.9))


func _gate(tx: int, ty: int, ch: String) -> void:
	var solid: bool = game.is_solid(tx, ty)
	var r := Rect2(tx * T, ty * T, T, T)
	if solid:
		draw_rect(r, Color(0.3, 0.27, 0.3))
		for i in 4:
			draw_rect(Rect2(r.position.x + 3 + i * 7.5, r.position.y - 6, 4, T + 4), Color(0.5, 0.48, 0.52))
			draw_rect(Rect2(r.position.x + 3 + i * 7.5, r.position.y - 6, 4, 3), Color(0.75, 0.72, 0.78))
		draw_rect(Rect2(r.position.x, r.position.y + 10, T, 4), Color(0.4, 0.38, 0.42))
		if ch in ["A", "B", "G"]:
			# Siegel: oeffnet sich nach dem Bosssieg
			draw_circle(r.get_center(), 6, Color(0.6, 0.3, 0.9, 0.8))
	else:
		draw_rect(Rect2(r.position.x, r.position.y, T, 4), Color(0.4, 0.38, 0.42))


func _door(tx: int, ty: int) -> void:
	var r := Rect2(tx * T, ty * T, T, T)
	draw_rect(r, Color(0.45, 0.28, 0.12))
	for i in 3:
		draw_line(r.position + Vector2(4 + i * 10, 0), r.position + Vector2(4 + i * 10, T), Color(0.3, 0.18, 0.08), 2.0)
	draw_rect(Rect2(r.position + Vector2(0, 5), Vector2(T, 4)), Color(0.35, 0.35, 0.4))
	draw_rect(Rect2(r.position + Vector2(0, 23), Vector2(T, 4)), Color(0.35, 0.35, 0.4))
	# Schloss
	var c := r.get_center()
	draw_rect(Rect2(c - Vector2(6, 3), Vector2(12, 10)), Color(0.95, 0.8, 0.25))
	draw_arc(c - Vector2(0, 3), 4.5, PI, TAU, 8, Color(0.95, 0.8, 0.25), 2.0)
	draw_circle(c + Vector2(0, 2), 1.8, Color(0.2, 0.1, 0.0))


func _torch(tx: int, ty: int, t: float) -> void:
	var c := Vector2(tx * T + 16, ty * T + 14)
	var f := 1.0 + 0.15 * sin(t * 13.0 + tx) + 0.1 * sin(t * 23.0)
	draw_circle(c + Vector2(0, 16), 40 * f, Color(1, 0.6, 0.2, 0.06))
	draw_circle(c, 7 * f, Color(1, 0.45, 0.1, 0.9))
	draw_circle(c + Vector2(0, -3), 4 * f, Color(1, 0.9, 0.5))


func _portal(tx: int, ty: int, t: float) -> void:
	var c := Vector2(tx * T + 16, ty * T + 16)
	var active: bool = game.crystals >= 3
	var col := Color(0.5, 0.9, 1.0) if active else Color(0.5, 0.3, 0.7)
	for i in 4:
		var rr := 6.0 + i * 5.0
		var a0 := t * (2.0 + i) * (1 if i % 2 == 0 else -1)
		draw_arc(c, rr, a0, a0 + 4.2, 16, Color(col, 0.85 - i * 0.15), 2.5)
	for i in 3:
		var a := TAU * i / 3.0 + t * 0.5
		var lit: bool = game.crystals > i
		draw_circle(c + Vector2.from_angle(a) * 26.0, 4, Color(0.75, 0.55, 1.0) if lit else Color(0.2, 0.2, 0.25))


func _rings() -> void:
	var C: Vector2 = game.ring_center
	# Boden-Rune in der Mitte
	draw_circle(C, 20, Color(0.3, 0.4, 0.7, 0.25 + 0.1 * sin(game.time * 2.0)))
	draw_arc(C, 14, 0, TAU, 6, Color(0.5, 0.7, 1.0, 0.6), 2.0)
	for i in game.ring_radii.size():
		var rad: float = game.ring_radii[i]
		var gap_half: float = (game.RING_GAP * 0.5) / rad
		var a: float = game.ring_angles[i]
		var start := a + gap_half
		var end := a + TAU - gap_half
		var segs := int(rad * 0.4) + 12
		draw_arc(C + Vector2(0, 4), rad, start, end, segs, Color(0, 0, 0, 0.35), game.RING_HALF_THICK * 2.0 + 2.0)
		draw_arc(C, rad, start, end, segs, Color(0.42, 0.45, 0.6), game.RING_HALF_THICK * 2.0 + 2.0)
		draw_arc(C, rad, start, end, segs, Color(0.62, 0.7, 0.95), 2.0)
		# leuchtende Runen auf dem Ring
		for k in 6:
			var ra := start + (end - start) * (k + 0.5) / 6.0
			draw_circle(C + Vector2.from_angle(ra) * rad, 2.0, Color(0.5, 0.8, 1.0, 0.6 + 0.4 * sin(game.time * 3.0 + k + i)))
		# Endkappen
		draw_circle(C + Vector2.from_angle(start) * rad, game.RING_HALF_THICK + 1.0, Color(0.55, 0.6, 0.8))
		draw_circle(C + Vector2.from_angle(end) * rad, game.RING_HALF_THICK + 1.0, Color(0.55, 0.6, 0.8))

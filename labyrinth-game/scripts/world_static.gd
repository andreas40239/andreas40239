extends Node2D
## Zeichnet die unbewegliche Karte in Bloecken (fuer schnelles Culling).

const CHUNK := 16
const T := 32

var game: Node
var chunks: Array = []


class Chunk:
	extends Node2D
	var cx := 0
	var cy := 0
	var owner_static: Node2D

	func _draw() -> void:
		owner_static.draw_chunk(self, cx, cy)


func _ready() -> void:
	var nx := int(ceil(float(game.map_w) / CHUNK))
	var ny := int(ceil(float(game.map_h) / CHUNK))
	for cy in ny:
		for cx in nx:
			var c := Chunk.new()
			c.cx = cx
			c.cy = cy
			c.owner_static = self
			add_child(c)
			chunks.append(c)


func queue_redraw_all() -> void:
	for c in chunks:
		c.queue_redraw()


func region_floor(tx: int, ty: int) -> Color:
	for r in game.level["regions"]:
		if Rect2i(r[0]).has_point(Vector2i(tx, ty)):
			return r[1]
	return game.level["floor"]


func _hash(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(absi(h) % 1000) / 1000.0


func is_wallish(ch: String) -> bool:
	return ch == "#" or ch == "C" or ch == "t"


func draw_chunk(ci: CanvasItem, cx: int, cy: int) -> void:
	for ty in range(cy * CHUNK, mini((cy + 1) * CHUNK, game.map_h)):
		for tx in range(cx * CHUNK, mini((cx + 1) * CHUNK, game.map_w)):
			_draw_tile(ci, tx, ty)


func _draw_tile(ci: CanvasItem, tx: int, ty: int) -> void:
	var ch: String = game.tile_at(tx, ty)
	var r := Rect2(tx * T, ty * T, T, T)
	var h := _hash(tx, ty)
	if is_wallish(ch):
		var below: String = game.tile_at(tx, ty + 1)
		var open_near := false
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if not is_wallish(game.tile_at(tx + ox, ty + oy)):
					open_near = true
		if not open_near:
			ci.draw_rect(r, Color(0.05, 0.045, 0.06))
			return
		var top: Color = Color(game.level["wall"]).darkened(h * 0.15)
		ci.draw_rect(r, top)
		ci.draw_rect(Rect2(r.position, Vector2(T, 2)), top.lightened(0.15))
		if not is_wallish(below):
			# Vorderseite mit Ziegeln
			var face := Rect2(tx * T, ty * T + 14, T, 18)
			ci.draw_rect(face, top.darkened(0.4))
			ci.draw_line(Vector2(tx * T, ty * T + 23), Vector2(tx * T + T, ty * T + 23), Color(0.15, 0.13, 0.16), 1.0)
			var o := 8 if (tx % 2 == 0) else 20
			ci.draw_line(Vector2(tx * T + o, ty * T + 14), Vector2(tx * T + o, ty * T + 23), Color(0.15, 0.13, 0.16), 1.0)
			ci.draw_line(Vector2(tx * T + (o + 12) % 32, ty * T + 23), Vector2(tx * T + (o + 12) % 32, ty * T + 32), Color(0.15, 0.13, 0.16), 1.0)
			ci.draw_rect(Rect2(tx * T, ty * T + 30, T, 2), Color(0, 0, 0, 0.35))
		if ch == "C":
			var c0 := r.get_center()
			var crack := Color(0.1, 0.06, 0.04)
			ci.draw_rect(r.grow(-2), Color(0.42, 0.3, 0.22))
			ci.draw_polyline(PackedVector2Array([c0 + Vector2(-12, -10), c0 + Vector2(-3, -2), c0 + Vector2(-6, 6), c0 + Vector2(2, 13)]), crack, 2.0)
			ci.draw_polyline(PackedVector2Array([c0 + Vector2(-3, -2), c0 + Vector2(6, -6), c0 + Vector2(12, -12)]), crack, 2.0)
			ci.draw_polyline(PackedVector2Array([c0 + Vector2(6, -6), c0 + Vector2(9, 5)]), crack, 1.5)
		elif ch == "t":
			# Fackelhalter
			ci.draw_rect(Rect2(tx * T + 13, ty * T + 16, 6, 12), Color(0.35, 0.22, 0.1))
		return
	# Boden
	var base := region_floor(tx, ty)
	var fl := base.lightened(h * 0.06)
	ci.draw_rect(r, fl)
	if (tx + ty) % 2 == 0:
		ci.draw_rect(r, Color(0, 0, 0, 0.05))
	ci.draw_rect(Rect2(r.position, Vector2(T, 1)), Color(0, 0, 0, 0.18))
	ci.draw_rect(Rect2(r.position, Vector2(1, T)), Color(0, 0, 0, 0.18))
	if h > 0.85:
		ci.draw_circle(r.position + Vector2(8 + h * 10, 10 + h * 8), 2.0, base.darkened(0.3))
	# Schatten unter Waenden
	if is_wallish(game.tile_at(tx, ty - 1)) or game.tile_at(tx, ty - 1) == "P":
		ci.draw_rect(Rect2(r.position, Vector2(T, 6)), Color(0, 0, 0, 0.3))
	match ch:
		"P":
			# Saeule
			var pc: Color = game.level.get("pillar", Color(0.3, 0.2, 0.2))
			ci.draw_rect(Rect2(tx * T + 4, ty * T - 10, 24, 40), pc)
			ci.draw_rect(Rect2(tx * T + 2, ty * T - 14, 28, 6), pc.lightened(0.25))
			ci.draw_rect(Rect2(tx * T + 2, ty * T + 26, 28, 6), pc.darkened(0.35))
		"F":
			# Feuerduese: Gitter
			var c := r.get_center()
			ci.draw_rect(r.grow(-3), Color(0.12, 0.09, 0.08))
			for i in 4:
				ci.draw_line(Vector2(r.position.x + 7 + i * 6, r.position.y + 5), Vector2(r.position.x + 7 + i * 6, r.end.y - 5), Color(0.3, 0.25, 0.22), 2.0)
			ci.draw_arc(c, 11, 0, TAU, 16, Color(0.35, 0.18, 0.1), 1.5)
		"E":
			ci.draw_circle(r.get_center(), 15, Color(0.1, 0.05, 0.15))
		"I":
			# Rutscheis
			ci.draw_rect(r, Color(0.62, 0.8, 0.92))
			ci.draw_rect(Rect2(r.position, Vector2(T, 1)), Color(1, 1, 1, 0.35))
			ci.draw_line(r.position + Vector2(5 + h * 8, 8), r.position + Vector2(14 + h * 8, 4), Color(1, 1, 1, 0.7), 1.5)
			ci.draw_line(r.position + Vector2(18, 24 - h * 6), r.position + Vector2(26, 20 - h * 6), Color(1, 1, 1, 0.5), 1.0)
			if is_wallish(game.tile_at(tx, ty - 1)):
				ci.draw_rect(Rect2(r.position, Vector2(T, 6)), Color(0, 0, 0, 0.18))

class_name VillageView
extends Node2D
## Das Dorf am Pfadende: Torbogen "Willkommen!", Häuser und winkende Dorfbewohner.

var _t := 0.0
var _cheer := 0.0
var _surprise := 0.0
var _villagers := [
	{"p": Vector2(90, -80), "c": Color("ff8f6b"), "hair": Color("6b4a2f")},
	{"p": Vector2(100, 110), "c": Color("4f8fe8"), "hair": Color("2f2f3a")},
	{"p": Vector2(80, 30), "c": Color("5fc356"), "hair": Color("e0a84a")},
]


## Dorfbewohner jubeln (Freund angekommen).
func cheer() -> void:
	_cheer = 1.0


## Dorfbewohner sind überrascht (wildes Monster macht Trubel) - niemand wird verletzt.
func surprise() -> void:
	_surprise = 1.0


func _process(delta: float) -> void:
	_t += delta
	_cheer = maxf(0.0, _cheer - delta * 0.8)
	_surprise = maxf(0.0, _surprise - delta * 0.9)
	queue_redraw()


func _draw() -> void:
	# Dorfplatz
	Icons.ellipse(self, Vector2(120, 0), 150, 130, Color("e9d3a3"))
	Icons.ellipse_outline(self, Vector2(120, 0), 150, 130, Color("c99d62"), 6.0)
	# Brunnen
	var f := Vector2(150, 40)
	Icons.ellipse(self, f, 46, 22, Color("9aa3b5"))
	Icons.ellipse(self, f + Vector2(0, -4), 38, 16, Color("7cc8f0"))
	for i in 3:
		var ph := fmod(_t * 1.5 + i * 0.33, 1.0)
		draw_circle(f + Vector2(-10 + i * 10, -20 - sin(ph * PI) * 26), 4, Color(0.7, 0.9, 1.0, 0.9))
	# Häuser
	_house(Vector2(110, -190), Color("ffb36b"), Color("d9534f"))
	_house(Vector2(250, -120), Color("fff1c7"), Color("4f8fe8"))
	_house(Vector2(120, 260), Color("c6e5ff"), Color("9b59d0"))
	_house(Vector2(270, 190), Color("ffd6e8"), Color("5fc356"))
	# Dorfbewohner
	for i in _villagers.size():
		var v: Dictionary = _villagers[i]
		var jump := absf(sin(_t * 9.0 + i)) * 26.0 * _cheer
		_villager(v.p + Vector2(0, -jump), v.c, v.hair, i)
	# Torbogen
	_gate(Vector2(10, 0))


func _house(p: Vector2, wall: Color, roof: Color) -> void:
	Icons.ellipse(self, p + Vector2(0, 6), 80, 16, Color(0, 0, 0, 0.15))
	draw_rect(Rect2(p + Vector2(-60, -90), Vector2(120, 90)), wall)
	draw_rect(Rect2(p + Vector2(-60, -90), Vector2(120, 90)), wall.darkened(0.3), false, 4.0)
	var r := PackedVector2Array([p + Vector2(-78, -86), p + Vector2(0, -160), p + Vector2(78, -86)])
	draw_colored_polygon(r, roof)
	draw_polyline(PackedVector2Array([r[0], r[1], r[2], r[0]]), roof.darkened(0.3), 4.0, true)
	Icons.rounded_rect(self, Rect2(p + Vector2(-16, -52), Vector2(32, 52)), 12, Color("8d5f3a"))
	draw_rect(Rect2(p + Vector2(22, -70), Vector2(28, 26)), Color("bfe6ff"))
	draw_rect(Rect2(p + Vector2(22, -70), Vector2(28, 26)), wall.darkened(0.35), false, 3.0)
	draw_rect(Rect2(p + Vector2(-50, -70), Vector2(28, 26)), Color("bfe6ff"))
	draw_rect(Rect2(p + Vector2(-50, -70), Vector2(28, 26)), wall.darkened(0.35), false, 3.0)


func _villager(p: Vector2, shirt: Color, hair: Color, i: int) -> void:
	Icons.ellipse(self, p + Vector2(0, 4), 18, 6, Color(0, 0, 0, 0.15))
	Icons.rounded_rect(self, Rect2(p + Vector2(-14, -40), Vector2(28, 40)), 12, shirt)
	var head := p + Vector2(0, -56)
	draw_circle(head, 17, Color("ffd9b8"))
	draw_arc(head + Vector2(0, -3), 17, PI, TAU, 12, hair, 9.0, true)
	draw_circle(head + Vector2(-6, -1), 2.5, Color("2f2f3a"))
	draw_circle(head + Vector2(6, -1), 2.5, Color("2f2f3a"))
	if _surprise > 0.05:
		Icons.ellipse(self, head + Vector2(0, 8), 4, 5, Color("8c2b3c"))
		draw_arc(head + Vector2(0, -32), 8, 0, TAU, 10, Color(0.6, 0.35, 0.8, _surprise), 3.0, true)
	else:
		draw_arc(head + Vector2(0, 4), 7, 0.3, PI - 0.3, 8, Color("8c2b3c"), 2.5, true)
	var wave := sin(_t * (4.0 + 8.0 * _cheer) + i) * (0.4 + 0.5 * _cheer)
	var shoulder := p + Vector2(14, -34)
	var hand := shoulder + Vector2(cos(-1.2 + wave), sin(-1.2 + wave)) * 26.0
	Icons.thick_line(self, shoulder, hand, shirt.darkened(0.1), 8.0)
	draw_circle(hand, 6, Color("ffd9b8"))


func _gate(p: Vector2) -> void:
	var wood := Color("a8693a")
	var tops: Array[Vector2] = []
	for sy in [-1.0, 1.0]:
		var base: Vector2 = p + Vector2(0, sy * 82.0)
		Icons.ellipse(self, base + Vector2(0, 4), 20, 7, Color(0, 0, 0, 0.18))
		draw_rect(Rect2(base + Vector2(-11, -120), Vector2(22, 120)), wood)
		draw_rect(Rect2(base + Vector2(-11, -120), Vector2(22, 120)), wood.darkened(0.35), false, 3.0)
		draw_circle(base + Vector2(0, -126), 13, Color("ffd23f"))
		tops.append(base + Vector2(0, -118))
	# Girlande mit Herzen zwischen den Pfosten
	var pts := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		pts.append(tops[0].lerp(tops[1], k) + Vector2(sin(k * PI) * 34.0, 0))
	draw_polyline(pts, Color("5fc356"), 4.0, true)
	for i in range(1, 12, 2):
		Icons.heart(self, pts[i] + Vector2(0, 8 + sin(_t * 3.0 + i) * 2.0), 16, Color.from_hsv(i * 0.08, 0.5, 1.0))
	# Schild "Willkommen!" auf dem oberen Pfosten
	# Schild oben - liegt das Dorf weit oben, kommt es unter den unteren Pfosten (HUD-frei)
	var board := Rect2(tops[0] + Vector2(-112, -92), Vector2(224, 58))
	if position.y < 450.0:
		board = Rect2(p + Vector2(-112, 82 + 30), Vector2(224, 58))
	else:
		draw_line(tops[0] + Vector2(0, -36), tops[0] + Vector2(0, -10), wood, 6.0)
	Icons.rounded_rect(self, board.grow(4), 18, wood.darkened(0.35))
	Icons.rounded_rect(self, board, 14, Color("ffe7b0"))
	draw_string(UiTheme.get_bold(), board.position + Vector2(0, 41), "Willkommen!", HORIZONTAL_ALIGNMENT_CENTER,
		board.size.x, 32, Color("8d4a1f"))

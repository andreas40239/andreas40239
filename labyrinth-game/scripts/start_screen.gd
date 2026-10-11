extends Control
## Startbildschirm: Titel, Levelauswahl, Ton an/aus.

const Levels := preload("res://scripts/levels.gd")
const Progress := preload("res://scripts/progress.gd")
const AudioMgr := preload("res://scripts/audio.gd")
const GAME_SCENE := "res://scenes/main.tscn"

var audio: Node
var font: Font
var t := 0.0
var embers: Array = []
var pressed_card := -1
var leaving := -1.0
var chosen := 1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	audio = AudioMgr.new()
	add_child(audio)
	audio.play_music("title")
	for i in 40:
		embers.append([randf(), randf(), randf_range(0.02, 0.08), randf_range(1.5, 3.5)])


func _process(delta: float) -> void:
	t += delta
	for e in embers:
		e[1] -= e[2] * delta
		e[0] += sin(t + e[3]) * 0.002
		if e[1] < -0.05:
			e[1] = 1.05
			e[0] = randf()
	if leaving >= 0.0:
		leaving += delta
		if leaving > 0.6:
			Engine.set_meta("level", chosen)
			get_tree().change_scene_to_file(GAME_SCENE)
			leaving = -100.0
	queue_redraw()


# ------------------------------------------------------------ Layout
func screen() -> Vector2:
	return get_viewport_rect().size


func card_rect(i: int) -> Rect2:
	var s := screen()
	var w := minf(300.0, s.x * 0.36)
	var h := 150.0
	var gap := 30.0
	var x0 := s.x / 2 - w - gap / 2
	return Rect2(x0 + i * (w + gap), s.y * 0.52, w, h)


func sound_center() -> Vector2:
	var s := screen()
	return Vector2(s.x - 44, s.y - 44)


# ------------------------------------------------------------ Eingabe
func _input(event: InputEvent) -> void:
	if leaving >= 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_ENTER, KEY_SPACE:
				_start(1)
			KEY_2:
				_start(2)
		return
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed:
			pressed_card = -1
			for i in Levels.COUNT:
				if card_rect(i).grow(8).has_point(pos):
					pressed_card = i
			if pos.distance_to(sound_center()) < 32.0:
				var on := not Progress.sound_on()
				Progress.set_sound(on)
				if on:
					audio.sfx("pickup")
		else:
			if pressed_card >= 0 and card_rect(pressed_card).grow(8).has_point(pos):
				_start(pressed_card + 1)
			pressed_card = -1


func _start(n: int) -> void:
	chosen = n
	leaving = 0.0
	audio.sfx("powerup")


# ------------------------------------------------------------ Zeichnen
func _draw() -> void:
	var s := screen()
	# Hintergrund: Verlauf in Streifen
	for i in 24:
		var k := float(i) / 23.0
		draw_rect(Rect2(0, s.y * k, s.x, s.y / 23.0 + 1), Color(0.05, 0.03, 0.09).lerp(Color(0.16, 0.06, 0.08), k))
	_draw_rings(Vector2(s.x * 0.5, s.y * 0.36), minf(s.x, s.y) * 0.42)
	_draw_dragon(s)
	for e in embers:
		var a := 0.5 + 0.5 * sin(t * 3.0 + e[3] * 4.0)
		draw_circle(Vector2(e[0] * s.x, e[1] * s.y), e[3] * 0.8, Color(1.0, 0.55, 0.15, 0.5 * a))
	# Titel
	var bob := sin(t * 1.5) * 4.0
	_text_center("DRACHEN-LABYRINTH", Vector2(s.x / 2, s.y * 0.2 + bob), 60, Color(1.0, 0.78, 0.3), 8)
	_text_center("Ein Abenteuer mit Feuer, Eis und einem Endlos-Drachen", Vector2(s.x / 2, s.y * 0.2 + 42), 18, Color(0.9, 0.88, 1.0), 4)
	# Levelkarten
	for i in Levels.COUNT:
		_draw_card(i)
	_text_center("Tippe auf ein Level!", Vector2(s.x / 2, card_rect(0).end.y + 44), 20, Color(1, 1, 1, 0.55 + 0.45 * sin(t * 3.0)), 4)
	_draw_sound_button()
	if leaving >= 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, clampf(leaving / 0.6, 0.0, 1.0)))


func _text_center(txt: String, pos: Vector2, size: int, col: Color, outline := 4) -> void:
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(font, pos - Vector2(w / 2, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, col.a))
	draw_string(font, pos - Vector2(w / 2, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_rings(c: Vector2, r: float) -> void:
	for i in 4:
		var rad := r * (0.35 + i * 0.2)
		var a := t * (0.3 - i * 0.12) * (1 if i % 2 == 0 else -1)
		draw_arc(c, rad, a + 0.3, a + TAU - 0.3, 64, Color(0.4, 0.45, 0.75, 0.16), 6.0)
		draw_arc(c, rad, a + 0.3, a + TAU - 0.3, 64, Color(0.6, 0.7, 1.0, 0.12), 1.5)


func _draw_dragon(s: Vector2) -> void:
	var c := Vector2(s.x * 0.5, s.y * 0.4)
	var amp := Vector2(s.x * 0.42, s.y * 0.18)
	var n := 34
	var pts: Array = []
	for i in n:
		var p := t * 0.7 - i * 0.04
		pts.append(c + Vector2(amp.x * sin(p), amp.y * sin(2.0 * p)))
	for i in range(n - 1, 0, -1):
		var r := lerpf(16.0, 4.0, float(i) / n)
		var dd: Vector2 = (pts[i - 1] - pts[i]).normalized()
		var nn := dd.orthogonal()
		if i % 2 == 0:
			draw_colored_polygon(PackedVector2Array([pts[i] - nn * r * 0.5 - dd * 3, pts[i] - nn * (r + 7), pts[i] - nn * r * 0.5 + dd * 4]), Color(0.35, 0.05, 0.05, 0.9))
		draw_circle(pts[i], r, Color(0.62, 0.13, 0.1, 0.9))
		draw_circle(pts[i] + nn * r * 0.3, r * 0.45, Color(0.92, 0.55, 0.2, 0.9))
	var h: Vector2 = pts[0]
	var d: Vector2 = (pts[0] - pts[1]).normalized()
	var flap := sin(t * 6.0)
	for sgn in [-1.0, 1.0]:
		var nrm: Vector2 = d.orthogonal() * sgn
		var w: Vector2 = pts[6]
		draw_colored_polygon(PackedVector2Array([w + d * 8, w + nrm * (40 + flap * 10), w - d * 14 + nrm * 22, w - d * 10]), Color(0.45, 0.08, 0.08, 0.85))
	draw_circle(h, 14, Color(0.7, 0.15, 0.12))
	draw_colored_polygon(PackedVector2Array([h + d.orthogonal() * 10, h + d * 22 + d.orthogonal() * 4, h + d * 22 - d.orthogonal() * 4, h - d.orthogonal() * 10]), Color(0.7, 0.15, 0.12))
	draw_circle(h + d * 5 + d.orthogonal() * 6, 3, Color(1, 0.9, 0.1))
	draw_circle(h + d * 5 - d.orthogonal() * 6, 3, Color(1, 0.9, 0.1))
	if fmod(t, 4.0) < 0.8:
		for i in 6:
			var fp: Vector2 = h + d * (26 + i * 9) + Vector2(randf_range(-3, 3), randf_range(-3, 3))
			draw_circle(fp, 4 + i * 1.2, Color(1, 0.4 + i * 0.08, 0.05, 0.7 - i * 0.1))


func _draw_card(i: int) -> void:
	var r := card_rect(i)
	var lv := Levels.get_level(i + 1)
	var hover := pressed_card == i
	var base := Color(0.16, 0.12, 0.22, 0.92) if i == 0 else Color(0.12, 0.18, 0.26, 0.92)
	if hover:
		r = r.grow(4)
		base = base.lightened(0.15)
	draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.4))
	draw_rect(r, base)
	var edge := Color(1.0, 0.7, 0.3) if i == 0 else Color(0.55, 0.85, 1.0)
	draw_rect(r, edge, false, 3.0)
	# Bild
	var ic := r.position + Vector2(56, r.size.y / 2)
	if i == 0:
		draw_arc(ic, 34, t, t + TAU - 0.6, 24, Color(0.6, 0.65, 0.95), 4.0)
		draw_arc(ic, 22, -t * 1.3, -t * 1.3 + TAU - 0.8, 20, Color(0.6, 0.65, 0.95), 4.0)
		draw_circle(ic, 8, Color(1.0, 0.6, 0.2))
		draw_circle(ic + Vector2(0, -2), 3, Color(1, 0.95, 0.6))
	else:
		for k in 3:
			var cx := ic + Vector2((k - 1) * 18, 6 - (8 if k == 1 else 0))
			var hh := 30.0 if k == 1 else 22.0
			draw_colored_polygon(PackedVector2Array([cx + Vector2(0, -hh), cx + Vector2(8, 0), cx + Vector2(0, 10), cx + Vector2(-8, 0)]), Color(0.65, 0.85, 1.0, 0.9))
		draw_circle(ic + Vector2(0, 22), 7, Color(0.3, 0.2, 0.35))
		for sgn in [-1.0, 1.0]:
			for k in 3:
				draw_line(ic + Vector2(sgn * 3, 20 + k * 3), ic + Vector2(sgn * 13, 15 + k * 5), Color(0.3, 0.2, 0.35), 1.5)
	# Text
	var tx := r.position.x + 112
	draw_string(font, Vector2(tx, r.position.y + 44), "Level %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, edge)
	var name: String = lv["name"]
	var words := name.split(" ")
	# Name ggf. auf zwei Zeilen
	var line1 := name
	var line2 := ""
	if font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x > r.size.x - 122 and words.size() > 1:
		line1 = " ".join(words.slice(0, words.size() - 1))
		line2 = words[-1]
	draw_string(font, Vector2(tx, r.position.y + 74), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.95, 1.0))
	if line2 != "":
		draw_string(font, Vector2(tx, r.position.y + 96), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.95, 1.0))
	if Progress.is_done(i + 1):
		_star(Vector2(r.end.x - 26, r.position.y + 26), 14, Color(1, 0.85, 0.25))
		draw_string(font, Vector2(tx, r.end.y - 16), "Geschafft!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.85, 0.35))
	else:
		var a := 0.6 + 0.4 * sin(t * 4.0 + i)
		draw_string(font, Vector2(tx, r.end.y - 16), "Spielen  >", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 1.0, 0.7, a))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI / 2 + k * PI / 5) * rr)
	draw_colored_polygon(pts, col)


func _draw_sound_button() -> void:
	var c := sound_center()
	var on := Progress.sound_on()
	draw_circle(c, 28, Color(0, 0, 0, 0.4))
	draw_arc(c, 28, 0, TAU, 24, Color(1, 1, 1, 0.4), 2.0)
	var col := Color(1, 1, 1, 0.85)
	draw_rect(Rect2(c + Vector2(-13, -5), Vector2(7, 10)), col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -5), c + Vector2(3, -12), c + Vector2(3, 12), c + Vector2(-6, 5)]), col)
	if on:
		draw_arc(c + Vector2(4, 0), 7, -0.8, 0.8, 8, col, 2.0)
		draw_arc(c + Vector2(4, 0), 12, -0.8, 0.8, 8, col, 2.0)
	else:
		draw_line(c + Vector2(6, -6), c + Vector2(14, 6), Color(1, 0.4, 0.4), 3.0)
		draw_line(c + Vector2(14, -6), c + Vector2(6, 6), Color(1, 0.4, 0.4), 3.0)

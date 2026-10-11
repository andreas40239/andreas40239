extends CanvasLayer
## Anzeige (Herzen, Kristalle, Boss-Leiste, Meldungen) und Touch-Steuerung:
## linke Bildschirmhaelfte = Joystick, rechts = der eine Aktionsknopf.

var game: Node
var ui: Control
var vignette: GradientTexture2D
var font: Font

var message_title := ""
var message_sub := ""
var message_time := 0.0
var damage_flash := 0.0
var victory_time := -1.0

var joy_index := -1
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var action_index := -1
var action_glow := 0.0

const JOY_RADIUS := 60.0


func _ready() -> void:
	layer = 10
	font = ThemeDB.fallback_font
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ui)
	ui.draw.connect(_on_draw)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.8))
	g.add_point(0.55, Color(0, 0, 0, 0.0))
	vignette = GradientTexture2D.new()
	vignette.gradient = g
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5, 0.5)
	vignette.fill_to = Vector2(1.05, 0.5)
	vignette.width = 128
	vignette.height = 128


func _process(dt: float) -> void:
	message_time = maxf(0.0, message_time - dt)
	damage_flash = maxf(0.0, damage_flash - dt)
	action_glow = maxf(0.0, action_glow - dt)
	if victory_time >= 0.0:
		victory_time += dt
	ui.queue_redraw()


func show_message(title: String, sub: String) -> void:
	message_title = title
	message_sub = sub
	message_time = 3.5 if sub != "" else 2.0


func flash_damage() -> void:
	damage_flash = 0.3


func show_victory() -> void:
	victory_time = 0.0


func screen_size() -> Vector2:
	return ui.get_viewport_rect().size


func action_center() -> Vector2:
	var s := screen_size()
	return Vector2(s.x - 95.0, s.y - 95.0)


# ------------------------------------------------------------ Eingabe
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_J, KEY_ENTER, KEY_X]:
			_press_action()
		return
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed:
			if pos.x < screen_size().x * 0.5 and game.state == "play":
				joy_index = event.index
				joy_origin = pos
				joy_pos = pos
				_update_joy()
			else:
				action_index = event.index
				_press_action()
		else:
			if event.index == joy_index:
				joy_index = -1
				game.touch_dir = Vector2.ZERO
			if event.index == action_index:
				action_index = -1
	elif event is InputEventScreenDrag:
		if event.index == joy_index:
			joy_pos = event.position
			# Ursprung zieht mit, wenn der Finger weit wegwandert
			var off := joy_pos - joy_origin
			if off.length() > JOY_RADIUS * 1.4:
				joy_origin = joy_pos - off.normalized() * JOY_RADIUS * 1.4
			_update_joy()


func _update_joy() -> void:
	var off := (joy_pos - joy_origin) / JOY_RADIUS
	if off.length() < 0.15:
		game.touch_dir = Vector2.ZERO
	else:
		game.touch_dir = off.limit_length(1.0)


func _press_action() -> void:
	match game.state:
		"title":
			game.start_game()
		"won":
			if victory_time > 2.5:
				game.restart()
		"play":
			game.action_queued = true
			action_glow = 0.15


# ------------------------------------------------------------ Zeichnen
func _on_draw() -> void:
	var s := screen_size()
	ui.draw_texture_rect(vignette, Rect2(Vector2.ZERO, s), false)
	if damage_flash > 0.0:
		ui.draw_rect(Rect2(Vector2.ZERO, s), Color(0.8, 0, 0, damage_flash))
	match game.state:
		"title":
			_draw_title(s)
			return
		"won":
			_draw_victory(s)
			return
	_draw_status(s)
	_draw_boss_bar(s)
	_draw_message(s)
	_draw_controls(s)
	if game.state == "dead":
		var a := clampf((2.0 - game.dead_timer) / 1.0, 0.0, 0.8)
		ui.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, a))
		_text_center("Du bist gefallen...", Vector2(s.x / 2, s.y / 2), 36, Color(1, 0.4, 0.4, a / 0.8))


func _text_center(txt: String, pos: Vector2, size: int, col: Color) -> void:
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ui.draw_string_outline(font, pos - Vector2(w / 2, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, col.a))
	ui.draw_string(font, pos - Vector2(w / 2, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _heart(c: Vector2, sz: float, col: Color) -> void:
	ui.draw_circle(c + Vector2(-sz * 0.45, -sz * 0.2), sz * 0.52, col)
	ui.draw_circle(c + Vector2(sz * 0.45, -sz * 0.2), sz * 0.52, col)
	ui.draw_colored_polygon(PackedVector2Array([c + Vector2(-sz * 0.95, 0), c + Vector2(sz * 0.95, 0), c + Vector2(0, sz)]), col)


func _draw_status(_s: Vector2) -> void:
	var p: Node2D = game.player
	for i in p.max_hp:
		var c := Vector2(26 + i * 26, 26)
		_heart(c + Vector2(1, 2), 10, Color(0, 0, 0, 0.5))
		_heart(c, 10, Color(0.95, 0.2, 0.3) if i < p.hp else Color(0.25, 0.15, 0.18))
	# Kristalle
	for i in 3:
		var c := Vector2(30 + i * 24, 58)
		var col := Color(0.7, 0.5, 1.0) if game.crystals > i else Color(0.2, 0.18, 0.25)
		ui.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(7, 0), c + Vector2(0, 10), c + Vector2(-7, 0)]), col)
	# Waffe
	var wname: String = p.WEAPON_NAMES[p.weapon]
	if p.weapon == 2:
		wname = "Eis- & Feuerschwert"
	ui.draw_string_outline(font, Vector2(104, 64), wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
	ui.draw_string(font, Vector2(104, 64), wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, p.blade_color().lightened(0.3))


func _draw_boss_bar(s: Vector2) -> void:
	for i in range(1, 4):
		if game.boss_state[i] == game.BOSS_FIGHT and game.boss_nodes[i] != null:
			var b: Node2D = game.boss_nodes[i]
			var w := minf(420.0, s.x * 0.5)
			var r := Rect2(s.x / 2 - w / 2, 18, w, 14)
			ui.draw_rect(r.grow(3), Color(0, 0, 0, 0.7))
			ui.draw_rect(Rect2(r.position, Vector2(w * float(maxi(b.hp, 0)) / b.max_hp, 14)), Color(0.85, 0.15, 0.2))
			_text_center(game.BOSS_NAMES[i], Vector2(s.x / 2, 52), 18, Color(1, 0.85, 0.85))
			return


func _draw_message(s: Vector2) -> void:
	if message_time <= 0.0:
		return
	var a := clampf(message_time / 0.5, 0.0, 1.0)
	var y := s.y * 0.26
	_text_center(message_title, Vector2(s.x / 2, y), 30, Color(1, 0.9, 0.55, a))
	if message_sub != "":
		_text_center(message_sub, Vector2(s.x / 2, y + 30), 17, Color(0.95, 0.95, 1, a))


func _draw_controls(s: Vector2) -> void:
	# Joystick
	if joy_index >= 0:
		ui.draw_circle(joy_origin, JOY_RADIUS, Color(1, 1, 1, 0.08))
		ui.draw_arc(joy_origin, JOY_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.3), 2.0)
		ui.draw_circle(joy_origin + game.touch_dir * JOY_RADIUS, 24, Color(1, 1, 1, 0.35))
	else:
		var c := Vector2(110, s.y - 100)
		ui.draw_arc(c, JOY_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.12), 2.0)
		ui.draw_circle(c, 22, Color(1, 1, 1, 0.08))
	# Aktionsknopf
	var ac := action_center()
	var pressed := action_index >= 0 or action_glow > 0.0
	ui.draw_circle(ac, 58, Color(0.9, 0.3, 0.2, 0.45 if pressed else 0.25))
	ui.draw_arc(ac, 58, 0, TAU, 40, Color(1, 0.8, 0.6, 0.6), 3.0)
	var col: Color = game.player.blade_color().lightened(0.3)
	ui.draw_line(ac + Vector2(-18, 18), ac + Vector2(20, -20), col, 6.0)
	ui.draw_line(ac + Vector2(-24, 8), ac + Vector2(-8, 24), Color(0.85, 0.85, 0.85), 4.0)
	ui.draw_line(ac + Vector2(-18, 18), ac + Vector2(-26, 26), Color(0.55, 0.35, 0.15), 5.0)


func _draw_title(s: Vector2) -> void:
	ui.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.01, 0.04, 0.72))
	var t: float = game.time
	_text_center("DRACHEN-LABYRINTH", Vector2(s.x / 2, s.y * 0.3), 52, Color(1, 0.75, 0.3))
	_text_center("Entkomme den drehenden Scheiben, besiege drei Wächter", Vector2(s.x / 2, s.y * 0.3 + 46), 18, Color(0.9, 0.9, 1))
	_text_center("und bringe ihre Kristalle am Endlos-Drachen vorbei zum Portal.", Vector2(s.x / 2, s.y * 0.3 + 70), 18, Color(0.9, 0.9, 1))
	_text_center("Links ziehen = laufen      Rechts tippen = Schwert", Vector2(s.x / 2, s.y * 0.66), 20, Color(0.7, 0.9, 0.7))
	_text_center("Tippen zum Starten", Vector2(s.x / 2, s.y * 0.8), 26, Color(1, 1, 1, 0.6 + 0.4 * sin(t * 4.0)))


func _draw_victory(s: Vector2) -> void:
	var a := clampf(victory_time / 1.5, 0.0, 0.85)
	ui.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.03, 0.08, a))
	_text_center("GESCHAFFT!", Vector2(s.x / 2, s.y * 0.35), 60, Color(0.6, 0.95, 1.0, a / 0.85))
	var secs := int(game.play_time)
	var txt := "Zeit: %d:%02d     Niederlagen: %d" % [secs / 60, secs % 60, game.deaths]
	_text_center(txt, Vector2(s.x / 2, s.y * 0.35 + 56), 24, Color(1, 1, 1, a / 0.85))
	if victory_time > 2.5:
		_text_center("Tippen für ein neues Spiel", Vector2(s.x / 2, s.y * 0.75), 22, Color(1, 1, 1, 0.6 + 0.4 * sin(game.time * 4.0)))

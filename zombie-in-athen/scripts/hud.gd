extends CanvasLayer
## HUD: virtueller Joystick links, Aktions-Buttons rechts, Leben, Timer, Minimap,
## Ansagen und Endbildschirm. Alles wird in einem Control gezeichnet; Touch-Eingaben
## werden per Index verfolgt (Multitouch).

const JOY_RADIUS := 95.0

var game
var listen_held := false
var freeze_held := false
var sneak_on: bool:
	get:
		return _sneak_toggle or Input.is_key_pressed(KEY_SHIFT)
var aim_vector := Vector2.ZERO

var _c: Control
var _font: Font
var _title_font: Font
var _tex := {}
var _buttons: Array[Dictionary] = []
var _zombie_mode := false
var _sneak_toggle := false
var _joy_index := -1
var _joy_base := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _ann_title := ""
var _ann_sub := ""
var _ann_t := 0.0
var _ann_dur := 1.0
var _toasts: Array[Dictionary] = []
var _flash := Color(0, 0, 0, 0)
var _t := 0.0
var _end_panel: Control = null
var _pause_panel: Control = null
var _key_freeze := false
var _key_listen := false
var _btn_freeze := false
var _btn_listen := false


func setup(p_game) -> void:
	game = p_game
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	_title_font = _font
	if ResourceLoader.exists("res://assets/fonts/Creepster-Regular.ttf"):
		_title_font = load("res://assets/fonts/Creepster-Regular.ttf")
	for n in ["btn_freeze", "btn_sneak", "btn_hide", "btn_unhide", "btn_bite", "btn_sprint", "btn_listen",
			"item_garlic", "item_souvlaki", "item_melon", "heart_full", "heart_empty"]:
		_load_tex(n, "res://assets/icons/%s.png" % n)
	for n in ["button", "joystick_base", "joystick_knob", "vignette"]:
		_load_tex(n, "res://assets/ui/%s.png" % n)
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_c)
	_c.draw.connect(_on_draw)
	set_zombie_mode(game.player.is_zombie)


func _load_tex(key: String, path: String) -> void:
	if ResourceLoader.exists(path):
		_tex[key] = load(path)


func set_zombie_mode(z: bool) -> void:
	_zombie_mode = z
	_buttons.clear()
	_btn_freeze = false
	_btn_listen = false
	_sneak_toggle = false
	if z:
		_buttons.append({"id": "bite", "off": Vector2(125, 125), "r": 78.0, "icon": "btn_bite", "label": "Beißen"})
		_buttons.append({"id": "sprint", "off": Vector2(300, 95), "r": 60.0, "icon": "btn_sprint", "label": "Rennen"})
		_buttons.append({"id": "listen", "off": Vector2(105, 300), "r": 60.0, "icon": "btn_listen", "label": "Horchen"})
	else:
		_buttons.append({"id": "hide", "off": Vector2(125, 125), "r": 78.0, "icon": "btn_hide", "label": "Verstecken"})
		_buttons.append({"id": "sneak", "off": Vector2(300, 95), "r": 60.0, "icon": "btn_sneak", "label": "Leise"})
		_buttons.append({"id": "freeze", "off": Vector2(105, 300), "r": 60.0, "icon": "btn_freeze", "label": "Stillstehen"})
		_buttons.append({"id": "melon", "off": Vector2(275, 262), "r": 56.0, "icon": "item_melon", "label": "Werfen"})
	for b in _buttons:
		b["touch"] = -1
	_buttons.append({"id": "pause", "off": Vector2(-1, -1), "r": 28.0, "icon": "", "label": "II", "touch": -1})


# ------------------------------------------------------------------ Eingabe

func move_vector() -> Vector2:
	var v := Vector2(_joy_vec.x, -_joy_vec.y)
	var k := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		k.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		k.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		k.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		k.y -= 1
	if k != Vector2.ZERO:
		v = k.normalized()
	return v


func _btn_center(b: Dictionary) -> Vector2:
	if b.id == "pause":
		return Vector2(_c.size.x * 0.5 - 250.0, 34.0)
	return _c.size - (b.off as Vector2) - Vector2(20, 14)


func _btn_visible(b: Dictionary) -> bool:
	if b.id == "melon":
		return game.player.has_melon
	return true


func _input(event: InputEvent) -> void:
	if game == null or _end_panel != null or _pause_panel != null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)
	elif event is InputEventKey and not event.echo:
		_key(event)


func _key(e: InputEventKey) -> void:
	match e.keycode:
		KEY_E:
			if e.pressed:
				game.player_hide_toggle()
		KEY_SPACE:
			if _zombie_mode:
				if e.pressed:
					game.player_bite()
			else:
				_key_freeze = e.pressed
		KEY_Q:
			_key_listen = e.pressed
		KEY_SHIFT:
			if _zombie_mode and e.pressed:
				game.player_sprint()
		KEY_F:
			if e.pressed:
				aim_vector = Vector2.ZERO
				game.set_aiming(true)
			else:
				game.player_throw()
		KEY_ESCAPE:
			if e.pressed:
				_toggle_pause()


func _touch_down(index: int, pos: Vector2) -> void:
	for b in _buttons:
		if not _btn_visible(b):
			continue
		if pos.distance_to(_btn_center(b)) <= b.r * 1.15:
			b.touch = index
			_press(b)
			return
	if _joy_index < 0 and pos.x < _c.size.x * 0.5:
		_joy_index = index
		_joy_base = pos
		_joy_vec = Vector2.ZERO


func _touch_move(index: int, pos: Vector2) -> void:
	if index == _joy_index:
		var d := pos - _joy_base
		if d.length() > JOY_RADIUS:
			# Basis wandert mit, damit der Daumen nie "aus dem Stick" läuft
			_joy_base = pos - d.normalized() * JOY_RADIUS
			d = pos - _joy_base
		_joy_vec = d / JOY_RADIUS
		if _joy_vec.length() < 0.18:
			_joy_vec = Vector2.ZERO
		return
	for b in _buttons:
		if b.touch == index and b.id == "melon":
			var d := (pos - _btn_center(b)) / 70.0
			aim_vector = Vector2(d.x, -d.y).limit_length(1.0)


func _touch_up(index: int) -> void:
	if index == _joy_index:
		_joy_index = -1
		_joy_vec = Vector2.ZERO
		return
	for b in _buttons:
		if b.touch == index:
			b.touch = -1
			_release(b)


func _press(b: Dictionary) -> void:
	match b.id:
		"hide":
			Sfx.play("ui_click", -8.0)
			game.player_hide_toggle()
		"sneak":
			_sneak_toggle = not _sneak_toggle
			Sfx.play("ui_click", -8.0)
		"freeze":
			_btn_freeze = true
		"melon":
			aim_vector = Vector2.ZERO
			game.set_aiming(true)
		"bite":
			game.player_bite()
		"sprint":
			game.player_sprint()
		"listen":
			_btn_listen = true
			Sfx.play("listen", -6.0)
		"pause":
			_toggle_pause()


func _release(b: Dictionary) -> void:
	match b.id:
		"freeze":
			_btn_freeze = false
		"listen":
			_btn_listen = false
		"melon":
			game.player_throw()


func _process(delta: float) -> void:
	if game == null:
		return
	_t += delta
	freeze_held = _btn_freeze or _key_freeze
	listen_held = _btn_listen or _key_listen
	_ann_t = maxf(0.0, _ann_t - delta)
	for t in _toasts:
		t.t -= delta
	_toasts = _toasts.filter(func(t): return t.t > 0.0)
	_flash.a = maxf(0.0, _flash.a - delta * 0.9)
	_c.queue_redraw()


# ------------------------------------------------------------------ Meldungen

func announce(title: String, sub: String, dur := 2.5) -> void:
	_ann_title = title
	_ann_sub = sub
	_ann_t = dur
	_ann_dur = dur


func toast(text: String) -> void:
	_toasts.append({"text": text, "t": 3.5})
	if _toasts.size() > 4:
		_toasts.pop_front()


func flash(c: Color) -> void:
	_flash = c


# ------------------------------------------------------------------ Zeichnen

func _txt(pos: Vector2, text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, font: Font = null) -> void:
	var f := font if font != null else _font
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER and width > 0.0:
		p.x -= width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT and width > 0.0:
		p.x -= width
	_c.draw_string_outline(f, p, text, align, width, size, maxi(4, size / 5), Color(0, 0, 0, color.a * 0.85))
	_c.draw_string(f, p, text, align, width, size, color)


func _icon(key: String, center: Vector2, size: float, mod := Color.WHITE) -> void:
	if _tex.has(key):
		_c.draw_texture_rect(_tex[key], Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), false, mod)


func _fmt_time(s: float) -> String:
	var t := int(ceil(maxf(0.0, s)))
	return "%d:%02d" % [t / 60, t % 60]


func _on_draw() -> void:
	var sz := _c.size
	var p: Character = game.player
	if _tex.has("vignette"):
		_c.draw_texture_rect(_tex["vignette"], Rect2(Vector2.ZERO, sz), false, Color(1, 1, 1, 0.55))
	if _flash.a > 0.0:
		_c.draw_rect(Rect2(Vector2.ZERO, sz), _flash)
	_draw_status(p)
	_draw_timer(sz)
	_draw_minimap(sz, p)
	if game.phase != game.Phase.END:
		_draw_joystick()
		_draw_buttons(p)
	_draw_messages(sz, p)


func _draw_status(p: Character) -> void:
	var x := 22.0
	var y := 20.0
	if not p.is_zombie:
		for i in Cfg.MAX_LIVES:
			_icon("heart_full" if i < p.lives else "heart_empty", Vector2(x + 26 + i * 54, y + 26), 50)
		y += 62
		# Stillstehen-Budget
		var frac := p.freeze_left / Cfg.FREEZE_MAX
		_c.draw_rect(Rect2(x, y, 160, 12), Color(0, 0, 0, 0.5))
		var col := Color(0.55, 0.85, 1.0) if p.freeze_lock <= 0.0 else Color(0.5, 0.5, 0.55)
		_c.draw_rect(Rect2(x + 1, y + 1, 158 * frac, 10), col)
		_txt(Vector2(x + 168, y + 12), "Stillstehen %.0fs" % p.freeze_left, 14, Color(0.8, 0.9, 1.0))
		y += 26
	else:
		_txt(Vector2(x, y + 34), "ZOMBIE", 40, Color(0.75, 1.0, 0.4), HORIZONTAL_ALIGNMENT_LEFT, -1, _title_font)
		_txt(Vector2(x + 150, y + 32), "Bisse: %d" % p.bites, 24, Color(1, 0.85, 0.3))
		y += 52
		if p.stun_t > 0.0:
			_txt(Vector2(x, y + 16), "Kauen ... %.1fs" % p.stun_t, 18, Color(1, 0.5, 0.4))
			y += 24
	# aktive Upgrades
	var ex := x
	if p.garlic_t > 0.0:
		_icon("item_garlic", Vector2(ex + 22, y + 24), 44)
		_txt(Vector2(ex + 46, y + 32), "%ds" % int(ceil(p.garlic_t)), 20, Color(0.8, 1.0, 0.6))
		ex += 100
	if p.souvlaki_t > 0.0:
		_icon("item_souvlaki", Vector2(ex + 22, y + 24), 44)
		_txt(Vector2(ex + 46, y + 32), "%ds" % int(ceil(p.souvlaki_t)), 20, Color(1.0, 0.75, 0.3))
		ex += 100
	if ex > x:
		y += 50
	# Mitspieler-Liste
	y += 8
	for c in game.chars:
		var col: Color = c.shirt.lightened(0.3)
		_c.draw_circle(Vector2(x + 8, y + 9), 6, col)
		var state := ""
		if c.is_zombie:
			state = "Zombie · %d Bisse" % c.bites
			col = Color(0.7, 0.95, 0.5)
		elif c.turn_t > 0.0:
			state = "verwandelt sich ..."
			col = Color(1.0, 0.5, 0.4)
		else:
			state = "♥".repeat(c.lives)
		_txt(Vector2(x + 22, y + 15), "%s  %s" % [c.cname, state], 15, col)
		y += 21


func _draw_timer(sz: Vector2) -> void:
	var cx := sz.x * 0.5
	match game.phase:
		game.Phase.PREP:
			var urgent: bool = game.prep_left <= 5.0
			var col := Color(1, 0.3, 0.25) if urgent else Color(1, 0.9, 0.7)
			_txt(Vector2(cx, 34), "Zombies kommen in", 18, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 400)
			_txt(Vector2(cx, 78), _fmt_time(game.prep_left), 44 + (int(6 * absf(sin(_t * 6.0))) if urgent else 0), col, HORIZONTAL_ALIGNMENT_CENTER, 400, _title_font)
		game.Phase.HUNT:
			_txt(Vector2(cx, 34), "Menschen übrig: %d   ·   Zombies: %d" % [game.humans().size(), game.zombies().size()], 20, Color(1, 0.92, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 600)
			_txt(Vector2(cx, 62), "Sonnenaufgang in %s" % _fmt_time(game.match_left), 16, Color(1.0, 0.75, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 600)


func _draw_joystick() -> void:
	var base := _joy_base
	var alpha := 0.9
	if _joy_index < 0:
		base = Vector2(170, _c.size.y - 170)
		alpha = 0.35
	if _tex.has("joystick_base"):
		_icon("joystick_base", base, JOY_RADIUS * 2.3, Color(1, 1, 1, alpha))
	else:
		_c.draw_arc(base, JOY_RADIUS, 0, TAU, 40, Color(1, 1, 1, alpha * 0.5), 4.0)
	var knob := base + _joy_vec * JOY_RADIUS
	if _tex.has("joystick_knob"):
		_icon("joystick_knob", knob, 96, Color(1, 1, 1, alpha))
	else:
		_c.draw_circle(knob, 40, Color(1, 1, 1, alpha * 0.5))


func _draw_buttons(p: Character) -> void:
	for b in _buttons:
		if not _btn_visible(b):
			continue
		var c := _btn_center(b)
		var r: float = b.r
		var enabled := true
		var active: bool = b.touch >= 0
		var label: String = b.label
		var icon: String = b.icon
		var ring := -1.0          # 0..1 Fortschrittsring
		var ring_col := Color(1, 1, 1, 0.8)
		match b.id:
			"hide":
				if p.hidden_in != null:
					icon = "btn_unhide"
					label = "Raus"
					active = true
				else:
					var s: HidingSpot = game.nearest_spot_for(p)
					enabled = s != null
					if s != null:
						label = "%s (%d/%d)" % [s.label(), s.count(), s.capacity]
			"sneak":
				active = sneak_on
				enabled = p.hidden_in == null
			"freeze":
				enabled = p.freeze_left > 0.0 and p.freeze_lock <= 0.0 and p.hidden_in == null
				active = p.frozen
				ring = p.freeze_left / Cfg.FREEZE_MAX
				ring_col = Color(0.55, 0.85, 1.0, 0.9)
			"melon":
				enabled = p.hidden_in == null
			"bite":
				enabled = p.can_act()
				if p.stun_t > 0.0:
					ring = 1.0 - p.stun_t / Cfg.BITE_STUN
					ring_col = Color(1.0, 0.4, 0.3, 0.9)
			"sprint":
				enabled = p.heard_t > 0.0 and p.sprint_cd <= 0.0 and p.can_act()
				active = p.sprint_t > 0.0
				if p.sprint_t > 0.0:
					ring = p.sprint_t / Cfg.SPRINT_TIME
					ring_col = Color(1.0, 0.7, 0.2, 0.9)
				elif p.sprint_cd > 0.0:
					ring = 1.0 - p.sprint_cd / (Cfg.SPRINT_TIME + Cfg.SPRINT_COOLDOWN)
				elif enabled:
					label = "Rennen!"
			"listen":
				active = p.listening
				enabled = p.can_act()
			"pause":
				pass
		var a := 1.0 if enabled else 0.38
		if b.id == "pause":
			_c.draw_circle(c, r, Color(0, 0, 0, 0.45))
			_c.draw_rect(Rect2(c + Vector2(-9, -11), Vector2(6, 22)), Color(1, 1, 1, 0.85))
			_c.draw_rect(Rect2(c + Vector2(3, -11), Vector2(6, 22)), Color(1, 1, 1, 0.85))
			continue
		if _tex.has("button"):
			_icon("button", c, r * 2.0, Color(1, 1, 1, a))
		else:
			_c.draw_circle(c, r, Color(0, 0, 0, 0.5 * a))
		if active:
			_c.draw_arc(c, r - 3, 0, TAU, 48, Color(1.0, 0.95, 0.5, 0.95), 5.0, true)
		elif b.id == "sprint" and enabled:
			_c.draw_arc(c, r - 3, 0, TAU, 48, Color(1.0, 0.6, 0.1, 0.5 + 0.5 * absf(sin(_t * 7.0))), 6.0, true)
		if ring >= 0.0:
			_c.draw_arc(c, r + 5, -PI * 0.5, -PI * 0.5 + TAU * clampf(ring, 0, 1), 48, ring_col, 5.0, true)
		_icon(icon, c - Vector2(0, 6), r * 1.25, Color(1, 1, 1, a))
		_txt(Vector2(c.x, c.y + r - 8), label, 15, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, r * 3.0)


func _draw_messages(sz: Vector2, p: Character) -> void:
	# große Ansage
	if _ann_t > 0.0:
		var a := clampf(_ann_t / 0.5, 0.0, 1.0) * clampf((_ann_dur - _ann_t) / 0.2, 0.0, 1.0)
		var grow := 1.0 + 0.08 * (1.0 - clampf((_ann_dur - _ann_t) / 0.3, 0.0, 1.0))
		_txt(Vector2(sz.x * 0.5, sz.y * 0.3), _ann_title, int(70 * grow), Color(1.0, 0.25, 0.2, a), HORIZONTAL_ALIGNMENT_CENTER, sz.x, _title_font)
		if _ann_sub != "":
			_txt(Vector2(sz.x * 0.5, sz.y * 0.3 + 44), _ann_sub, 22, Color(1, 0.95, 0.85, a), HORIZONTAL_ALIGNMENT_CENTER, sz.x)
	# Hinweise
	var hint := ""
	var hint_col := Color(1, 1, 1)
	if game.phase != game.Phase.END:
		if p.turn_t > 0.0:
			hint = ""
		elif not p.is_zombie:
			if p.hidden_in != null:
				if p.hidden_in.sniffed_by != null:
					hint = "Ein Zombie schnüffelt an deinem Versteck – RAUS!"
					hint_col = Color(1.0, 0.3, 0.25, 0.6 + 0.4 * absf(sin(_t * 9.0)))
				else:
					hint = "Versteckt (%s). Tippe »Raus« zum Verlassen." % p.hidden_in.label()
					hint_col = Color(0.7, 1.0, 0.7)
			elif p.frozen:
				hint = "Bewegungslos – Zombies sehen dich nicht (%.0f s)" % p.freeze_left
				hint_col = Color(0.6, 0.9, 1.0)
			elif p.invuln_t > 0.0 and game.phase == game.Phase.HUNT:
				hint = "LAUF! (%.1f s)" % p.invuln_t
				hint_col = Color(1.0, 0.5, 0.3)
			elif p.moving and not p.sneaking and game.phase == game.Phase.HUNT:
				hint = "Du rennst – Zombies hören dich!"
				hint_col = Color(1.0, 0.8, 0.3, 0.9)
		else:
			if p.listening and not p.listen_active():
				hint = "Horchen ..."
			elif p.listen_active():
				hint = "Du hörst alle Menschen (gelbe Ovale)"
				hint_col = Color(1, 0.95, 0.3)
			elif p.heard_t > 0.0 and p.sprint_cd <= 0.0 and p.stun_t <= 0.0:
				hint = "GERÄUSCH! Jetzt kannst du rennen."
				hint_col = Color(1.0, 0.7, 0.2, 0.7 + 0.3 * absf(sin(_t * 8.0)))
	if hint != "":
		_txt(Vector2(sz.x * 0.5, sz.y - 150), hint, 22, hint_col, HORIZONTAL_ALIGNMENT_CENTER, sz.x * 0.6)
	# Kurzmeldungen
	var y := sz.y - 28.0
	for i in range(_toasts.size() - 1, -1, -1):
		var t: Dictionary = _toasts[i]
		_txt(Vector2(sz.x * 0.5, y), t.text, 17, Color(1, 1, 1, clampf(t.t, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, sz.x * 0.6)
		y -= 24.0


# ------------------------------------------------------------------ Minimap

func _map_xf(sz: Vector2) -> Dictionary:
	var s := 210.0
	var origin := Vector2(sz.x - s * 0.5 - 16.0, s * 0.5 + 12.0)
	var k: float = s / float(game.apt.w + game.apt.h)
	return {"o": origin, "k": k, "s": s}


func _w2m(xf: Dictionary, x: float, z: float) -> Vector2:
	var w: float = game.apt.w
	var h: float = game.apt.h
	var u := (x - z) - (w - h) * 0.5
	var v := (x + z) - (w + h) * 0.5
	return (xf.o as Vector2) + Vector2(u, v) * (xf.k as float)


func _draw_minimap(sz: Vector2, p: Character) -> void:
	var xf := _map_xf(sz)
	var apt: ApartmentGen = game.apt
	var zv: bool = game.zombie_view
	var outline := PackedVector2Array([_w2m(xf, -0.6, -0.6), _w2m(xf, apt.w + 0.6, -0.6), _w2m(xf, apt.w + 0.6, apt.h + 0.6), _w2m(xf, -0.6, apt.h + 0.6)])
	_c.draw_colored_polygon(outline, Color(0, 0, 0, 0.55))
	for r in apt.rooms:
		var rc: Rect2i = r.rect
		var poly := PackedVector2Array([_w2m(xf, rc.position.x, rc.position.y), _w2m(xf, rc.end.x, rc.position.y), _w2m(xf, rc.end.x, rc.end.y), _w2m(xf, rc.position.x, rc.end.y)])
		var col := Color(0.35, 0.3, 0.25, 0.75)
		match r.type:
			ApartmentGen.RoomType.BATH: col = Color(0.3, 0.45, 0.5, 0.75)
			ApartmentGen.RoomType.KITCHEN: col = Color(0.5, 0.45, 0.25, 0.75)
			ApartmentGen.RoomType.HALL: col = Color(0.42, 0.4, 0.36, 0.75)
			ApartmentGen.RoomType.LIVING: col = Color(0.3, 0.42, 0.3, 0.75)
			ApartmentGen.RoomType.OFFICE: col = Color(0.32, 0.34, 0.48, 0.75)
		if zv:
			var g := col.get_luminance()
			col = Color(g * 1.4, g * 0.25, g * 0.2, 0.75)
		_c.draw_colored_polygon(poly, col)
		poly.append(poly[0])
		_c.draw_polyline(poly, Color(0, 0, 0, 0.8), 1.5)
	# Verstecke
	for s in game.spots:
		var rc: Rect2i = s.rect
		var poly := PackedVector2Array([_w2m(xf, rc.position.x + 0.1, rc.position.y + 0.1), _w2m(xf, rc.end.x - 0.1, rc.position.y + 0.1), _w2m(xf, rc.end.x - 0.1, rc.end.y - 0.1), _w2m(xf, rc.position.x + 0.1, rc.end.y - 0.1)])
		_c.draw_colored_polygon(poly, Color(0.1, 0.08, 0.06, 0.7) if not zv else Color(0.2, 0.02, 0.02, 0.7))
	# Upgrades
	for pk in game.pickups:
		var mp := _w2m(xf, pk.global_position.x, pk.global_position.z)
		_c.draw_circle(mp, 4.0 + sin(_t * 5.0), Props.kind_color(pk.kind))
	# Geräusch-Pings
	for ping in game.noise_pings():
		var mp := _w2m(xf, ping.pos.x, ping.pos.z)
		var k: float = 1.0 - ping.t / 1.5
		_c.draw_arc(mp, 4.0 + k * 16.0, 0, TAU, 20, Color(1, 0.6, 0.2, 1.0 - k), 2.0)
	# Figuren
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	for c in game.chars:
		var mp := _w2m(xf, c.global_position.x, c.global_position.z)
		if c == p:
			_c.draw_circle(mp, 6.0, Color(0, 0, 0, 0.8))
			_c.draw_circle(mp, 4.5, Color(1, 1, 1) if not zv else Color(0.7, 1.0, 0.4))
			continue
		if zv:
			if c.is_zombie:
				_c.draw_circle(mp, 3.5, Color(0.6, 0.9, 0.3))
			elif c.is_active_human():
				if game.marker_on.get(c, false):
					# gelbes pulsierendes Oval
					_c.draw_set_transform(mp, 0.0, Vector2(1.5, 1.0))
					_c.draw_arc(Vector2.ZERO, 5.0 + 3.0 * pulse, 0, TAU, 20, Color(1, 0.92, 0.1, 0.6 + 0.4 * pulse), 2.5)
					_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				elif c.visible:
					_c.draw_circle(mp, 4.0, Color(1, 0.92, 0.1, 0.6 + 0.4 * pulse))
		else:
			if c.is_zombie:
				var d: float = c.global_position.distance_to(p.global_position)
				if d < 13.0 and game.nav.los(p.global_position, c.global_position):
					_c.draw_circle(mp, 5.0, Color(0, 0, 0, 0.8))
					_c.draw_circle(mp, 4.0, Color(1.0, 0.15, 0.1))
			elif c.turn_t > 0.0:
				_c.draw_circle(mp, 4.0, Color(1.0, 0.5, 0.2))
			else:
				_c.draw_circle(mp, 3.5, c.shirt.lightened(0.2))


# ------------------------------------------------------------------ Pause & Ende

func _panel(title: String, title_col: Color) -> VBoxContainer:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_override("font", _title_font)
	head.add_theme_font_size_override("font_size", 76)
	head.add_theme_color_override("font_color", title_col)
	head.add_theme_color_override("font_outline_color", Color.BLACK)
	head.add_theme_constant_override("outline_size", 12)
	box.add_child(head)
	box.set_meta("root", root)
	return box


func _label(box: Container, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	box.add_child(l)
	return l


func _button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 72)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(func():
		Sfx.play("ui_click", -6.0)
		cb.call())
	box.add_child(b)
	return b


func _toggle_pause() -> void:
	if _end_panel != null:
		return
	if _pause_panel != null:
		_pause_panel.queue_free()
		_pause_panel = null
		get_tree().paused = false
		return
	# im Netzwerkspiel läuft die Runde weiter – anhalten geht nur allein
	if not game.net:
		get_tree().paused = true
	_joy_index = -1
	_joy_vec = Vector2.ZERO
	_btn_freeze = false
	_btn_listen = false
	var box := _panel("MENÜ" if game.net else "PAUSE", Color(1, 0.9, 0.7))
	_pause_panel = box.get_meta("root")
	if game.net:
		_label(box, "Die Runde läuft weiter!", 20, Color(1, 0.8, 0.5))
	_button(box, "Weiter", _toggle_pause)
	if not game.net:
		_button(box, "Neu starten", func():
			get_tree().paused = false
			game.restart())
	_button(box, "Spiel verlassen" if game.net else "Hauptmenü", func():
		get_tree().paused = false
		game.to_menu())


func show_end(res: Dictionary) -> void:
	if _pause_panel != null:
		_pause_panel.queue_free()
		_pause_panel = null
		get_tree().paused = false
	_joy_index = -1
	_joy_vec = Vector2.ZERO
	var box := _panel(res.headline, Color(1.0, 0.85, 0.3) if res.player_wins else Color(0.9, 0.2, 0.15))
	_end_panel = box.get_meta("root")
	_label(box, res.sub, 22, Color(1, 0.95, 0.85))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 4)
	var gc := CenterContainer.new()
	gc.add_child(grid)
	box.add_child(gc)
	for head in ["Spieler", "Status", "Bisse verteilt", "gebissen"]:
		_label(grid, head, 16, Color(0.7, 0.7, 0.7))
	for c in game.chars:
		var col: Color = c.shirt.lightened(0.35)
		var status := "Mensch" if not c.is_zombie else ("Zombie" if not c.started_as_zombie else "Ur-Zombie")
		if res.top_zombie == c:
			status += "  ★ meiste Bisse"
		elif not c.is_zombie:
			status += "  ★ überlebt"
		_label(grid, c.cname, 20, col)
		_label(grid, status, 20, Color(0.75, 0.95, 0.5) if c.is_zombie else Color(1, 0.95, 0.85))
		_label(grid, str(c.bites), 20, Color.WHITE)
		_label(grid, "%d / %d" % [c.bites_taken, Cfg.MAX_LIVES] if not c.started_as_zombie else "–", 20, Color.WHITE)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	if game.is_client:
		_label(box, "Der Gastgeber kann eine neue Runde starten.", 18, Color(0.8, 0.8, 0.8))
		_button(row, "Spiel verlassen", func(): game.to_menu())
	else:
		_button(row, "Nochmal spielen", func(): game.restart())
		_button(row, "Spiel beenden" if game.net else "Hauptmenü", func(): game.to_menu())

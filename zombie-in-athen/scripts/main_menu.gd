extends Control
## Hauptmenü.

var _title_font: Font
var _help: Control
# Mehrspieler-Lobby
var _mp: Control
var _mp_box: VBoxContainer
var _mp_screen := ""
var _mp_status := ""
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _hosts_box: VBoxContainer
var _players_label: Label
var _start_btn: Button
var _zombie_btn: Button
var _level_btn: Button
# Figuren-Editor
var _fig_model: CharModel
var _fig_holder: Node3D
var _fig_labels := {}
var _test_started := false
var _test_retry := 0.0


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	Net.lobby_changed.connect(_on_lobby_changed)
	Net.hosts_changed.connect(_refresh_hosts)
	Net.join_ok.connect(_on_join_ok)
	Net.join_failed.connect(_on_join_failed)
	if GameState.net_name != "":
		Net.my_name = GameState.net_name
	# Startparameter für automatische Netzwerk-Tests
	if GameState.net_host > 0:
		print("NET host: ", Net.host_game())
		return
	if GameState.net_join == "auto":
		Net.start_search()
		return
	if GameState.net_join != "":
		Net.join_game(GameState.net_join)
		return
	if GameState.start_game:
		GameState.start_game = false
		get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")
		return
	_title_font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets/fonts/Creepster-Regular.ttf"):
		_title_font = load("res://assets/fonts/Creepster-Regular.ttf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	if ResourceLoader.exists("res://assets/ui/title_bg.png"):
		bg.texture = load("res://assets/ui/title_bg.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)

	var title := Label.new()
	title.text = "ZOMBIE IN ATHEN"
	title.add_theme_font_override("font", _title_font)
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", Color(0.72, 0.95, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.02))
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 7)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 50
	title.offset_bottom = 200
	add_child(title)

	var sub := Label.new()
	sub.text = "Verstecken. Schleichen. Überleben."
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(1, 0.92, 0.8))
	sub.add_theme_color_override("font_outline_color", Color.BLACK)
	sub.add_theme_constant_override("outline_size", 8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 195
	sub.offset_bottom = 235
	add_child(sub)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -200
	box.offset_right = 200
	box.offset_top = 90
	box.offset_bottom = 320
	add_child(box)
	_button(box, "Allein spielen", func(): _show_mp("levels"), 32, Vector2(400, 76))
	_button(box, "Mehrspieler (WLAN)", func(): _show_mp("choose"), 30, Vector2(400, 68))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	box.add_child(row2)
	_button(row2, "Meine Figur", func(): _show_mp("figure"), 23, Vector2(195, 56))
	_button(row2, "Anleitung", _show_help, 23, Vector2(195, 56))
	var mus := Button.new()
	mus.custom_minimum_size = Vector2(170, 50)
	mus.add_theme_font_size_override("font_size", 20)
	mus.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mus.offset_left = -190
	mus.offset_right = -20
	mus.offset_top = 16
	mus.offset_bottom = 66
	add_child(mus)
	mus.text = "Musik: an" if GameState.music_on else "Musik: aus"
	mus.pressed.connect(func():
		GameState.music_on = not GameState.music_on
		mus.text = "Musik: an" if GameState.music_on else "Musik: aus")

	var info := Label.new()
	info.text = "Allein mit Computerspielern oder zu 2–6 im WLAN · 4 Orte      v0.3"
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.offset_top = -34
	add_child(info)
	Sfx.reset_levels()
	Sfx.start_music()
	if Net.last_message != "":
		_mp_status = Net.last_message
		Net.last_message = ""
		_show_mp("choose")
	if GameState.shots_dir.ends_with("figure"):
		_show_mp("figure")
	if GameState.shots_dir.ends_with("levels"):
		_show_mp("levels")
	if GameState.shots_dir.ends_with("lobby"):
		# nur für automatische Tests: Lobby-Screenshot
		Net.my_name = "Andi"
		_mp_host()
		Net.players[2] = "Maria"
		Net.players[3] = "Jannis"
		_on_lobby_changed()
	if GameState.shots_dir != "":
		# nur für automatische Tests: Menü-Screenshot und beenden
		await get_tree().create_timer(0.6).timeout
		DirAccess.make_dir_recursive_absolute(GameState.shots_dir)
		get_viewport().get_texture().get_image().save_png(GameState.shots_dir.path_join("menu.png"))
		get_tree().quit()


func _button(box: Container, text: String, cb: Callable, fsize: int, minsize: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = minsize
	b.add_theme_font_size_override("font_size", fsize)
	b.pressed.connect(func():
		Sfx.play("ui_click", -6.0)
		cb.call())
	box.add_child(b)
	return b


func _process(delta: float) -> void:
	if _fig_model != null and is_instance_valid(_fig_model):
		_fig_model.rotation.y += delta * 0.9
		_fig_model.animate(delta, 0.0, "stand")
	# automatische Netzwerk-Tests: starten, sobald genug Spieler da sind / Beitritt wiederholen
	if GameState.net_host > 0 and not _test_started and Net.players.size() >= GameState.net_host:
		_test_started = true
		Net.start_match()
	if GameState.net_join != "" and not Net.active():
		_test_retry -= delta
		if _test_retry <= 0.0:
			_test_retry = 0.5
			if GameState.net_join != "auto":
				Net.join_game(GameState.net_join)
			elif not Net.found_hosts.is_empty():
				var ip: String = Net.found_hosts.keys()[0]
				print("NET found host %s (%s)" % [Net.found_hosts[ip].name, ip])
				Net.stop_search()
				Net.join_game(ip)


func _start(level_idx: int) -> void:
	Net.leave()
	GameState.set_level(level_idx)
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _show_help() -> void:
	if _help != null:
		return
	_help = Control.new()
	_help.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_help)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_help.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	_help.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 21)
	text.add_theme_font_size_override("bold_font_size", 21)
	text.text = """[b][color=#b8f24d]Als Mensch[/color][/b]
Du hast 30 Sekunden, dann brechen Zombies durch ein Fenster oder die Tür.
• [b]Joystick links:[/b] laufen. Du rennst immer – und Rennen macht [color=#ffcc55]Lärm[/color].
• [b]Leise:[/b] langsam und lautlos gehen (an/aus).
• [b]Stillstehen[/b] (halten): Zombies sehen dich nicht – höchstens 10 Sekunden.
• [b]Verstecken / Raus:[/b] im Schrank (1 Platz), unter dem Tisch (1) oder unter dem Bett (2).
  Vorsicht: Zombies schnüffeln manchmal an Verstecken!
• Nach einem Biss ist der Zombie 3 Sekunden abgelenkt: [color=#ff8855]lauf weg![/color] Nach 3 Bissen wirst du selbst zum Zombie.

[b][color=#b8f24d]Upgrades[/color][/b] (füllen immer auch die Lebensenergie auf)
• [b]Knoblauch:[/b] 20 s stinken – Zombies halten Abstand.
• [b]Souvlaki:[/b] 20 s schneller als jeder Zombie.
• [b]Wassermelone:[/b] Button halten, Richtung ziehen, loslassen – alle Zombies rennen zur Melone.

[b][color=#ff5544]Als Zombie[/color][/b]
Du siehst alles in Rot. Menschen siehst du nur, wenn sie sich in deinem Blickfeld bewegen (gelb pulsierend)
oder Lärm machen (gelbes Oval – auch auf der Karte).
• [b]Beißen:[/b] wenn du nah genug bist (auch an Verstecken).
• [b]Rennen:[/b] 3 Sekunden Sprint, sobald ein Mensch Lärm gemacht hat.
• [b]Horchen[/b] (halten): still stehen und alle Menschen als gelbes Oval sehen.

[b]Sieg:[/b] der letzte Mensch – oder der Zombie mit den meisten Bissen.

[b][color=#b8f24d]Mehrspieler[/color][/b]
Alle Handys ins selbe WLAN (oder ein Handy öffnet einen Hotspot). Einer tippt »Spiel eröffnen«, die anderen »Spiel suchen«.
Freie Plätze übernehmen Computerspieler. Verlässt der Gastgeber das Spiel, endet die Runde.
[color=#999999]Tastatur (Test am PC): WASD, Umschalt = leise / rennen, Leertaste = stillstehen / beißen, E = verstecken, F = Melone, Q = horchen.[/color]"""
	box.add_child(text)
	_button(box, "Zurück", func():
		_help.queue_free()
		_help = null, 26, Vector2(300, 64)).size_flags_horizontal = Control.SIZE_SHRINK_CENTER


# ------------------------------------------------------------------ Mehrspieler-Lobby

func _show_mp(screen: String) -> void:
	if _mp == null:
		_mp = Control.new()
		_mp.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_mp)
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.03, 0.06, 1.0)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_mp.add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		_mp.add_child(center)
		_mp_box = VBoxContainer.new()
		_mp_box.custom_minimum_size = Vector2(700, 0)
		_mp_box.add_theme_constant_override("separation", 12)
		center.add_child(_mp_box)
	for c in _mp_box.get_children():
		_mp_box.remove_child(c)
		c.queue_free()
	_mp_screen = screen
	_name_edit = null
	_zombie_btn = null
	_level_btn = null
	_fig_model = null
	_fig_holder = null
	_fig_labels.clear()
	_ip_edit = null
	_hosts_box = null
	_players_label = null
	_start_btn = null
	match screen:
		"choose":
			_mp_title("MEHRSPIELER IM WLAN")
			_mp_text("Alle Handys müssen im selben WLAN sein – oder ein Handy öffnet einen Hotspot und die anderen wählen sich dort ein. Internet wird nicht gebraucht.", 19, Color(0.85, 0.85, 0.85))
			var row := _mp_row()
			_mp_text("Dein Name:", 24, Color.WHITE, row)
			_name_edit = _mp_edit(row, Net.my_name, "Name", 12)
			_mp_status_label()
			_button(_mp_box, "Spiel eröffnen", _mp_host, 28, Vector2(0, 68))
			_button(_mp_box, "Spiel suchen", _mp_search, 28, Vector2(0, 68))
			_button(_mp_box, "Zurück", _close_mp, 22, Vector2(0, 52))
		"host":
			_mp_title("DEIN SPIEL IST OFFEN")
			var ips := Net.local_ips()
			_mp_text("Adresse: %s" % (ips[0] if not ips.is_empty() else "kein WLAN gefunden"), 34, Color(0.72, 0.95, 0.3))
			_mp_text("Die anderen tippen auf »Spiel suchen«. Erscheint dein Spiel dort nicht, geben sie diese Adresse ein.", 18, Color(0.8, 0.8, 0.8))
			_players_label = _mp_text("", 24, Color.WHITE)
			var orow := _mp_row()
			_level_btn = _button(orow, "", func():
				GameState.set_level((GameState.level_index + 1) % Cfg.LEVELS.size())
				_on_lobby_changed(), 22, Vector2(0, 58))
			_level_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_zombie_btn = _button(orow, "", func():
				Net.player_zombie = not Net.player_zombie
				_on_lobby_changed(), 22, Vector2(0, 58))
			_zombie_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_start_btn = _button(_mp_box, "Starten", _mp_start, 30, Vector2(0, 72))
			_button(_mp_box, "Abbrechen", _mp_leave, 22, Vector2(0, 50))
			_on_lobby_changed()
		"levels":
			_mp_title("WO SPIELEN WIR?")
			for i in Cfg.LEVELS.size():
				var lv: Dictionary = Cfg.LEVELS[i]
				var idx := i
				_button(_mp_box, "%s   –   %s" % [lv.name, lv.info], func(): _start(idx), 26, Vector2(0, 72))
			_button(_mp_box, "Zurück", _close_mp, 22, Vector2(0, 52))
		"figure":
			_build_figure_screen()
		"search":
			_mp_title("SPIEL SUCHEN")
			_mp_text("Gefundene Spiele im WLAN:", 22, Color.WHITE)
			_hosts_box = VBoxContainer.new()
			_hosts_box.add_theme_constant_override("separation", 8)
			_mp_box.add_child(_hosts_box)
			_refresh_hosts()
			_mp_text("Oder die Adresse des Gastgebers eingeben:", 19, Color(0.85, 0.85, 0.85))
			var row := _mp_row()
			_ip_edit = _mp_edit(row, GameState.last_ip, "192.168.…", 15)
			_ip_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
			var cb := _button(row, "Verbinden", func(): _mp_join(_ip_edit.text), 24, Vector2(200, 60))
			cb.size_flags_horizontal = Control.SIZE_SHRINK_END
			_mp_status_label()
			_button(_mp_box, "Zurück", _mp_leave, 22, Vector2(0, 52))
		"joined":
			_mp_title("VERBUNDEN")
			_players_label = _mp_text("", 24, Color.WHITE)
			_mp_text("Warte, bis der Gastgeber die Runde startet …", 22, Color(1.0, 0.85, 0.5))
			_button(_mp_box, "Verlassen", _mp_leave, 22, Vector2(0, 52))
			_on_lobby_changed()


func _mp_title(text: String) -> void:
	var l := _mp_text(text, 56, Color(0.72, 0.95, 0.3))
	l.add_theme_font_override("font", _title_font)


func _mp_text(text: String, size: int, col: Color, parent: Container = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if parent == null:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_mp_box.add_child(l)
	else:
		parent.add_child(l)
	return l


func _mp_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_mp_box.add_child(row)
	return row


func _mp_edit(parent: Container, text: String, hint: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = hint
	e.max_length = max_len
	e.custom_minimum_size = Vector2(0, 60)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.add_theme_font_size_override("font_size", 26)
	parent.add_child(e)
	return e


func _mp_status_label() -> void:
	if _mp_status != "":
		_mp_text(_mp_status, 20, Color(1.0, 0.45, 0.35))
		_mp_status = ""


func _close_mp() -> void:
	_take_name()
	Net.stop_search()
	Net.leave()
	if _mp != null:
		_mp.queue_free()
		_mp = null
	_mp_screen = ""


func _take_name() -> void:
	if _name_edit != null:
		var n := _name_edit.text.strip_edges()
		if n != "":
			Net.my_name = n
		GameState.save_settings()


func _mp_host() -> void:
	_take_name()
	var err := Net.host_game()
	if err != "":
		_mp_status = err
		_show_mp("choose")
		return
	_show_mp("host")


func _mp_search() -> void:
	_take_name()
	Net.start_search()
	_show_mp("search")


func _mp_join(ip: String) -> void:
	ip = ip.strip_edges()
	var err := Net.join_game(ip)
	if err != "":
		_mp_status = err
		_show_mp("search")
		return
	GameState.last_ip = ip
	GameState.save_settings()
	_mp_status = "Verbinde mit %s …" % ip
	_show_mp("search")


func _mp_leave() -> void:
	Net.stop_search()
	Net.leave()
	_show_mp("choose")


func _mp_start() -> void:
	Net.start_match()


func _on_join_ok() -> void:
	Net.stop_search()
	if _mp != null:
		_show_mp("joined")


func _on_join_failed(reason: String) -> void:
	if _mp == null:
		return
	_mp_status = reason
	Net.start_search()
	_show_mp("search")


func _on_lobby_changed() -> void:
	if _mp == null:
		return
	if _mp_screen == "joined" and not Net.active():
		_mp_status = Net.last_message
		Net.last_message = ""
		_show_mp("choose")
		return
	if _players_label != null:
		var names: Array = Net.players.values()
		_players_label.text = "Spieler (%d/%d): %s" % [names.size(), Net.MAX_PLAYERS, ", ".join(names)]
	if _start_btn != null:
		var n := Net.players.size()
		var lv: Dictionary = Cfg.LEVELS[GameState.level_index]
		var pz := Net.player_zombie and n >= 2
		var bots := maxi(0, 1 + int(lv.ai_humans) - (n - (1 if pz else 0)))
		_start_btn.text = "Starten (%d Spieler%s)" % [n, (" + %d Computer" % bots) if bots > 0 else ""]
		_level_btn.text = "Ort: %s  ▸" % lv.name
		if n < 2:
			_zombie_btn.text = "Start-Zombie: Computer"
			_zombie_btn.disabled = true
		else:
			_zombie_btn.disabled = false
			_zombie_btn.text = "Start-Zombie: %s  ▸" % ("ausgeloster Spieler" if Net.player_zombie else "Computer")


func _refresh_hosts() -> void:
	if _hosts_box == null:
		return
	for c in _hosts_box.get_children():
		_hosts_box.remove_child(c)
		c.queue_free()
	if Net.found_hosts.is_empty():
		var l := Label.new()
		l.text = "Suche läuft …"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_hosts_box.add_child(l)
		return
	for ip in Net.found_hosts:
		var h: Dictionary = Net.found_hosts[ip]
		var addr: String = ip
		_button(_hosts_box, "%s  ·  %d Spieler  ·  %s" % [h.name, h.count, addr], func(): _mp_join(addr), 24, Vector2(0, 64))


# ------------------------------------------------------------------ Meine Figur

func _build_figure_screen() -> void:
	_mp_title("MEINE FIGUR")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	_mp_box.add_child(row)
	# Vorschau: eigenes kleines 3D-Fenster mit der Figur
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(280, 380)
	svc.stretch = true
	row.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_2X
	svc.add_child(sv)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.08, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.9)
	env.ambient_light_energy = 0.9
	we.environment = env
	sv.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 30.0
	sv.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.35, 4.6), Vector3(0, 0.98, 0))
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.1
	sv.add_child(sun)
	sun.look_at_from_position(Vector3(2, 4, 4), Vector3.ZERO)
	_fig_holder = Node3D.new()
	sv.add_child(_fig_holder)
	# Auswahl rechts
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_fig_row(col, "Farbe", "color", Cfg.SHIRT_COLORS.size())
	_fig_row(col, "Frisur", "hair", Cfg.HAIR_NAMES.size())
	_fig_row(col, "Haarfarbe", "hair_color", Cfg.HAIR_COLORS.size())
	_fig_row(col, "Hut", "hat", Cfg.HAT_NAMES.size())
	_button(_mp_box, "Fertig", func():
		GameState.save_settings()
		_close_mp(), 26, Vector2(0, 62))
	_refresh_figure()


func _fig_row(parent: Container, title: String, key: String, count: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var name_l := Label.new()
	name_l.text = title
	name_l.custom_minimum_size = Vector2(120, 0)
	name_l.add_theme_font_size_override("font_size", 22)
	row.add_child(name_l)
	_button(row, "◀", func(): _fig_step(key, -1, count), 26, Vector2(64, 62))
	var val := Label.new()
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.add_theme_font_size_override("font_size", 22)
	row.add_child(val)
	_fig_labels[key] = val
	_button(row, "▶", func(): _fig_step(key, 1, count), 26, Vector2(64, 62))


func _fig_step(key: String, d: int, count: int) -> void:
	GameState.look[key] = posmod(int(GameState.look[key]) + d, count)
	_refresh_figure()


func _refresh_figure() -> void:
	if _fig_holder == null:
		return
	var lk: Dictionary = GameState.look
	var yaw := 0.4
	if _fig_model != null:
		yaw = _fig_model.rotation.y
		_fig_model.queue_free()
	_fig_model = CharModel.new()
	_fig_holder.add_child(_fig_model)
	_fig_model.setup(Cfg.SHIRT_COLORS[lk.color], 0, false, lk.hair, lk.hair_color, lk.hat)
	_fig_model.rotation.y = yaw
	var cl: Label = _fig_labels["color"]
	cl.text = "■■■■"
	cl.add_theme_color_override("font_color", Cfg.SHIRT_COLORS[lk.color])
	var hl: Label = _fig_labels["hair_color"]
	hl.text = "■■■■"
	hl.add_theme_color_override("font_color", Cfg.HAIR_COLORS[lk.hair_color])
	(_fig_labels["hair"] as Label).text = Cfg.HAIR_NAMES[lk.hair]
	(_fig_labels["hat"] as Label).text = Cfg.HAT_NAMES[lk.hat]

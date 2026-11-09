extends CanvasLayer
## HUD: Ressourcenleiste, Werkzeugleiste, Minimap, Infotafel, Meldungen und Menüs.

const GOLD := Color(0.95, 0.78, 0.35)
const R = Defs.R

var main
var root: Control
var lbl := {}
var tool_buttons := {}
var hint: Label
var info_panel: PanelContainer
var info: RichTextLabel
var msg_box: VBoxContainer
var minimap: TextureRect
var mini_img: Image
var mini_tex: ImageTexture
var cam_marker: Panel
var box_sel: Panel
var pause_label: Label
var btn_speed: Button
var overlay: ColorRect
var menus := {}
var end_title: Label
var end_text: Label
var opt := {}
var _menu_return := "main"


func setup(m) -> void:
	main = m
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_top()
	_build_toolbar()
	_build_minimap()
	_build_info()
	_build_messages()
	box_sel = Panel.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.3, 1.0, 0.4, 0.12)
	bs.border_color = Color(0.4, 1.0, 0.5, 0.9)
	bs.set_border_width_all(1)
	box_sel.add_theme_stylebox_override("panel", bs)
	box_sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_sel.visible = false
	root.add_child(box_sel)
	pause_label = Label.new()
	pause_label.text = "PAUSIERT  (P)"
	pause_label.add_theme_font_size_override("font_size", 34)
	pause_label.add_theme_color_override("font_color", GOLD)
	pause_label.add_theme_color_override("font_outline_color", Color.BLACK)
	pause_label.add_theme_constant_override("outline_size", 8)
	pause_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pause_label.position.y = 110
	pause_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_label.visible = false
	root.add_child(pause_label)
	_build_menus()


# ---------------------------------------------------------------- Theme
func _sb(bg: Color, border: Color, bw := 2, radius := 8, margin := 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	return s


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 17
	var panel := _sb(Color(0.07, 0.045, 0.05, 0.88), Color(0.5, 0.34, 0.15))
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("panel", "Panel", panel)
	th.set_stylebox("panel", "TooltipPanel", _sb(Color(0.05, 0.03, 0.04, 0.95), GOLD, 1, 6, 8.0))
	th.set_color("font_color", "TooltipLabel", Color(0.95, 0.9, 0.8))
	th.set_stylebox("normal", "Button", _sb(Color(0.17, 0.1, 0.09, 0.95), Color(0.42, 0.28, 0.13), 2, 6, 8.0))
	th.set_stylebox("hover", "Button", _sb(Color(0.28, 0.15, 0.11, 0.95), Color(0.8, 0.58, 0.25), 2, 6, 8.0))
	th.set_stylebox("pressed", "Button", _sb(Color(0.5, 0.13, 0.08, 0.95), Color(1.0, 0.8, 0.35), 2, 6, 8.0))
	th.set_stylebox("hover_pressed", "Button", _sb(Color(0.58, 0.16, 0.1, 0.95), Color(1.0, 0.85, 0.4), 2, 6, 8.0))
	th.set_stylebox("disabled", "Button", _sb(Color(0.1, 0.08, 0.08, 0.8), Color(0.25, 0.2, 0.15), 2, 6, 8.0))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color(0.95, 0.88, 0.72))
	th.set_color("font_hover_color", "Button", Color(1.0, 0.95, 0.8))
	th.set_color("font_pressed_color", "Button", Color(1.0, 1.0, 0.9))
	th.set_color("font_color", "Label", Color(0.95, 0.9, 0.82))
	th.set_color("font_outline_color", "Label", Color(0, 0, 0))
	th.set_constant("outline_size", "Label", 3)
	th.set_color("font_color", "CheckBox", Color(0.95, 0.9, 0.82))
	th.set_color("default_color", "RichTextLabel", Color(0.95, 0.9, 0.82))
	return th


# ---------------------------------------------------------------- Aufbau
func _label(parent: Node, txt: String, size := 17, col := Color(0.95, 0.9, 0.82)) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _button(parent: Node, txt: String, cb: Callable, tip := "", toggle := false) -> Button:
	var b := Button.new()
	b.text = txt
	b.tooltip_text = tip
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("ui", -6.0)
		cb.call())
	parent.add_child(b)
	return b


func _build_top() -> void:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	p.offset_left = 8
	p.offset_right = -8
	p.offset_top = 6
	root.add_child(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 26)
	p.add_child(hb)
	lbl["gold"] = _label(hb, "Gold", 19, GOLD)
	lbl["mana"] = _label(hb, "Mana", 19, Color(0.5, 0.75, 1.0))
	lbl["imps"] = _label(hb, "Wichtel", 18)
	lbl["crea"] = _label(hb, "Kreaturen", 18, Color(0.6, 1.0, 0.6))
	lbl["heart"] = _label(hb, "Herz", 18, Color(1.0, 0.45, 0.4))
	lbl["pay"] = _label(hb, "Zahltag", 16, Color(0.85, 0.8, 0.7))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(sp)
	lbl["wave"] = _label(hb, "Welle", 18, Color(0.75, 0.85, 1.0))
	_button(hb, "Welle rufen [N]", func(): main.call_wave_early(), "Ruft die nächste Heldenwelle sofort herbei.")
	btn_speed = _button(hb, "Tempo 1x", func(): main.cycle_speed(), "Spielgeschwindigkeit (+ / -)")
	_button(hb, "Menü [Esc]", func(): main.open_pause_menu())


func _build_toolbar() -> void:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_bottom = -8
	root.add_child(p)
	var vb := VBoxContainer.new()
	p.add_child(vb)
	hint = _label(vb, "", 15, Color(0.9, 0.85, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)
	tool_buttons["select"] = _button(hb, "Auswahl", func(): main.set_tool("select"), "Auswählen & Befehle [Esc]\nLinksklick/ziehen: Kreaturen wählen\nRechtsklick: Bewegen / Angreifen\nFels ziehen: Graben markieren", true)
	tool_buttons["dig"] = _button(hb, "Graben [F]", func(): main.set_tool("dig"), "Felsen zum Abbau markieren.\nZiehen markiert ein Rechteck,\nStart auf Markierung oder Shift entfernt.", true)
	hb.add_child(VSeparator.new())
	for r in [R.TREASURY, R.LAIR, R.FARM, R.TRAINING]:
		var ri: Dictionary = Defs.ROOM_INFO[r]
		var key := "room%d" % r
		tool_buttons[key] = _button(hb, "%s [%s]" % [ri["short"], ri["key"]], func(): main.set_tool(key), "%s – %d Gold/Feld\n%s" % [ri["name"], ri["cost"], ri["desc"]], true)
	tool_buttons["sell"] = _button(hb, "Verkaufen [X]", func(): main.set_tool("sell"), "Raumfelder verkaufen (50% zurück).", true)
	hb.add_child(VSeparator.new())
	for s in ["imp", "bolt", "heal"]:
		var si: Dictionary = Defs.SPELL_INFO[s]
		var cost := "variabel" if s == "imp" else "%d Mana" % si["cost"]
		tool_buttons["spell_" + s] = _button(hb, "%s [%s]" % [si["short"], si["key"]], func(): main.set_tool("spell_" + s), "%s – %s\n%s" % [si["name"], cost, si["desc"]], true)


func _build_minimap() -> void:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_left = 8
	p.offset_bottom = -8
	root.add_child(p)
	minimap = TextureRect.new()
	minimap.custom_minimum_size = Vector2(Defs.W, Defs.H) * 4.0
	minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	mini_img = Image.create(Defs.W, Defs.H, false, Image.FORMAT_RGBA8)
	mini_tex = ImageTexture.create_from_image(mini_img)
	minimap.texture = mini_tex
	minimap.gui_input.connect(_on_minimap_input)
	p.add_child(minimap)
	cam_marker = Panel.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(1, 1, 1, 0.05)
	cs.border_color = Color(1, 1, 1, 0.85)
	cs.set_border_width_all(1)
	cam_marker.add_theme_stylebox_override("panel", cs)
	cam_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.add_child(cam_marker)


func _on_minimap_input(e: InputEvent) -> void:
	var press: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
	if press:
		var lp: Vector2 = e.position / minimap.size * Vector2(Defs.W, Defs.H)
		main.rig.jump_to(Vector3(lp.x * Defs.TILE, 0, lp.y * Defs.TILE))
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		var lp2: Vector2 = e.position / minimap.size * Vector2(Defs.W, Defs.H)
		main.order_to_tile(Vector2i(int(lp2.x), int(lp2.y)))


func _build_info() -> void:
	info_panel = PanelContainer.new()
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info_panel.offset_right = -8
	info_panel.offset_bottom = -8
	info_panel.custom_minimum_size = Vector2(300, 0)
	root.add_child(info_panel)
	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.custom_minimum_size = Vector2(290, 40)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_child(info)
	info_panel.visible = false


func _build_messages() -> void:
	msg_box = VBoxContainer.new()
	msg_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	msg_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	msg_box.offset_top = 64
	msg_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg_box)


func message(txt: String, col := Color(0.95, 0.9, 0.8)) -> void:
	var l := _label(msg_box, txt, 19, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 6)
	while msg_box.get_child_count() > 6:
		var old := msg_box.get_child(0)
		msg_box.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------- Menüs
func _menu_panel(nm: String, title: String) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(c)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color(0.06, 0.035, 0.04, 0.96), GOLD, 2, 12, 28.0))
	c.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(420, 0)
	p.add_child(vb)
	if title != "":
		var t := _label(vb, title, 40, GOLD)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_constant_override("outline_size", 8)
	menus[nm] = c
	c.visible = false
	return vb


func _build_menus() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	# Hauptmenü
	var vb := _menu_panel("main", "")
	var t := _label(vb, "TIEFENHERR", 72, Color(0.95, 0.3, 0.2))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 12)
	t.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.0))
	var st := _label(vb, "Grabe. Herrsche. Verteidige das Herz.", 20, GOLD)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(HSeparator.new())
	_button(vb, "Neues Spiel", func(): main.start_game())
	_button(vb, "Steuerung & Anleitung", func(): show_menu("help", "main"))
	_button(vb, "Optionen", func(): show_menu("options", "main"))
	_button(vb, "Beenden", func(): main.get_tree().quit())
	# Pause
	vb = _menu_panel("pause", "Pause")
	_button(vb, "Fortsetzen", func(): main.close_menu())
	_button(vb, "Steuerung & Anleitung", func(): show_menu("help", "pause"))
	_button(vb, "Optionen", func(): show_menu("options", "pause"))
	_button(vb, "Neu starten", func(): main.restart())
	_button(vb, "Beenden", func(): main.get_tree().quit())
	# Optionen
	vb = _menu_panel("options", "Optionen")
	opt["master"] = _slider(vb, "Gesamtlautstärke", main.settings["master"], func(v): _set_opt("master", v))
	opt["music"] = _slider(vb, "Musik", main.settings["music"], func(v): _set_opt("music", v))
	opt["sfx"] = _slider(vb, "Effekte", main.settings["sfx"], func(v): _set_opt("sfx", v))
	var gh := HBoxContainer.new()
	vb.add_child(gh)
	var gl := _label(gh, "Grafikqualität", 17)
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ob := OptionButton.new()
	for q in ["Niedrig", "Mittel", "Hoch", "Ultra"]:
		ob.add_item(q)
	ob.selected = main.settings["quality"]
	ob.focus_mode = Control.FOCUS_NONE
	ob.item_selected.connect(func(i): _set_opt("quality", i))
	gh.add_child(ob)
	opt["fullscreen"] = _check(vb, "Vollbild", main.settings["fullscreen"], func(v): _set_opt("fullscreen", v))
	opt["edge"] = _check(vb, "Randscrollen mit der Maus", main.settings["edge"], func(v): _set_opt("edge", v))
	_button(vb, "Zurück", func(): main.save_settings(); show_menu(_menu_return))
	# Hilfe
	vb = _menu_panel("help", "Steuerung")
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(720, 0)
	rt.text = _help_text()
	vb.add_child(rt)
	_button(vb, "Zurück", func(): show_menu(_menu_return))
	# Spielende
	vb = _menu_panel("end", "")
	end_title = _label(vb, "", 60, GOLD)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_text = _label(vb, "", 19)
	end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(vb, "Neues Spiel", func(): main.restart())
	_button(vb, "Beenden", func(): main.get_tree().quit())


func _help_text() -> String:
	return """[color=#f2c75a][b]Kamera[/b][/color]
  WASD / Pfeiltasten / Bildschirmrand – bewegen (Shift = schneller)
  Mausrad – zoomen · Q/E oder mittlere Maustaste ziehen – drehen & neigen
  Leertaste – zum Dungeon-Herz · Minimap klicken – dorthin springen

[color=#f2c75a][b]Befehle[/b][/color]
  Linksklick / Rahmen ziehen – Kreaturen auswählen (Shift = hinzufügen, Strg+A = alle)
  Rechtsklick – ausgewählte Kreaturen bewegen bzw. Feind angreifen
  Fels mit Linksklick ziehen – Graben markieren (auch ohne Werkzeug)
  F Graben · 1-4 Räume · X Verkaufen · C/V/B Zauber · Rechtsklick/Esc – Werkzeug abbrechen
  P – Taktische Pause (Befehle & Bauen bleiben möglich) · +/- Spieltempo · N – Welle rufen

[color=#f2c75a][b]Ziel[/b][/color]
  Deine Grubenwichtel graben markierte Felsen ab, bringen Gold ins Lager,
  beanspruchen Boden und befestigen Wände. Beanspruche ein [color=#b070ff]Portal[/color] (lila),
  baue Hort + Pilzfarm, um Kreaturen anzulocken. Übungsraum & Schatzkammer
  locken stärkere Kreaturen an. Überstehe 6 Heldenwellen aus dem hellen Tor –
  wird dein Herz zerstört, ist das Spiel verloren."""


func _set_opt(k: String, v) -> void:
	main.settings[k] = v
	main.apply_settings()


func _slider(parent: Node, txt: String, val: float, cb: Callable) -> HSlider:
	var hb := HBoxContainer.new()
	parent.add_child(hb)
	var l := _label(hb, txt, 17)
	l.custom_minimum_size = Vector2(190, 0)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(cb)
	hb.add_child(s)
	return s


func _check(parent: Node, txt: String, val: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = txt
	c.button_pressed = val
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	parent.add_child(c)
	return c


func show_menu(nm: String, ret := "") -> void:
	if ret != "":
		_menu_return = ret
	overlay.visible = nm != ""
	for k in menus.keys():
		menus[k].visible = (k == nm)


func menu_visible() -> bool:
	return overlay.visible


func show_end(win: bool, stats: Dictionary, time_s: float) -> void:
	end_title.text = "SIEG!" if win else "NIEDERLAGE"
	end_title.add_theme_color_override("font_color", GOLD if win else Color(0.9, 0.2, 0.15))
	var head := "Alle Heldenwellen wurden zurückgeschlagen.\nDein Reich in der Tiefe ist sicher." if win else "Dein Dungeon-Herz wurde zerstört."
	end_text.text = "%s\n\nSpielzeit: %s\nHelden besiegt: %d\nEigene Verluste: %d\nFelder gegraben: %d\nGold abgebaut: %d" % [head, _fmt_time(time_s), stats["killed"], stats["lost"], stats["dug"], stats["gold_mined"]]
	show_menu("end")


# ---------------------------------------------------------------- Aktualisierung
func _fmt_time(s: float) -> String:
	var t := maxi(0, int(s))
	return "%d:%02d" % [t / 60, t % 60]


func update_stats() -> void:
	lbl["gold"].text = "Gold  %d / %d" % [main.total_gold(), main.gold_capacity()]
	lbl["mana"].text = "Mana  %d" % int(main.mana)
	lbl["imps"].text = "Wichtel  %d" % main.count_units("imp")
	lbl["crea"].text = "Kreaturen  %d / %d" % [main.creature_count(), main.world.room_count[R.LAIR]]
	lbl["heart"].text = "Herz  %d%%" % int(100.0 * main.heart_hp / Defs.HEART_HP)
	lbl["pay"].text = "Zahltag  %s" % _fmt_time(main.payday_t)
	if main.wave >= Defs.WAVES.size():
		lbl["wave"].text = "Letzte Welle! Helden übrig: %d" % main.hero_count()
	else:
		lbl["wave"].text = "Welle %d/%d in %s" % [main.wave + 1, Defs.WAVES.size(), _fmt_time(main.wave_timer)]
	btn_speed.text = "Tempo %dx" % int(Engine.time_scale)
	pause_label.visible = main.get_tree().paused and not menu_visible() and main.state == "play"


func set_tool(t: String) -> void:
	for k in tool_buttons.keys():
		tool_buttons[k].set_pressed_no_signal(k == t)


func set_hint(t: String) -> void:
	hint.text = t


func set_box(r: Rect2) -> void:
	if r.size.length() < 4.0:
		box_sel.visible = false
		return
	box_sel.visible = true
	box_sel.position = r.position
	box_sel.size = r.size


func update_info(sel: Array) -> void:
	if sel.is_empty():
		info_panel.visible = false
		return
	info_panel.visible = true
	if sel.size() == 1:
		var u: Unit = sel[0]
		var s := "[b][color=#f2c75a]%s[/color][/b]  Stufe %d\n" % [u.display_name(), u.level]
		s += "Leben: %d / %d\n" % [int(u.hp), int(u.max_hp)]
		s += "Zustand: %s\n" % u.state_text()
		if u.kind == "imp":
			s += "Trägt: %d Gold" % u.carried
		else:
			s += "Hunger: %d%%  ·  Müdigkeit: %d%%\n" % [int(minf(u.hunger, 1.0) * 100), int(minf(u.tired, 1.0) * 100)]
			s += "Gehalt: %d Gold  ·  Unmut: %d%%\n" % [u.wage(), int(minf(u.unhappy, 1.0) * 100)]
			s += "Erfahrung: %d / %d" % [int(u.xp), 40 * u.level]
		info.text = s
	else:
		var counts := {}
		for u in sel:
			counts[u.display_name()] = counts.get(u.display_name(), 0) + 1
		var s2 := "[b][color=#f2c75a]%d ausgewählt[/color][/b]\n" % sel.size()
		for k in counts.keys():
			s2 += "%d× %s\n" % [counts[k], k]
		s2 += "Rechtsklick: Bewegen / Angreifen"
		info.text = s2


func update_minimap() -> void:
	var w: World = main.world
	for y in Defs.H:
		for x in Defs.W:
			var i := y * Defs.W + x
			var c: Color
			match w.type[i]:
				Defs.T.BEDROCK: c = Color(0.03, 0.03, 0.04)
				Defs.T.ROCK: c = Color(0.27, 0.22, 0.18)
				Defs.T.GOLD: c = Color(0.85, 0.68, 0.15)
				Defs.T.GEM: c = Color(0.2, 0.85, 1.0)
				Defs.T.WALL: c = Color(0.5, 0.17, 0.14)
				Defs.T.HEART: c = Color(1.0, 0.15, 0.1)
				Defs.T.PORTAL: c = Color(0.7, 0.35, 1.0)
				Defs.T.GATE: c = Color(0.85, 0.95, 1.0)
				_:
					if w.room[i] != R.NONE:
						c = Defs.ROOM_INFO[w.room[i]]["color"].darkened(0.2)
					elif w.own[i] == 1:
						c = Color(0.55, 0.22, 0.2)
					else:
						c = Color(0.42, 0.34, 0.26)
			if w.marked.has(i):
				c = c.lerp(Color(1.0, 0.9, 0.3), 0.45)
			mini_img.set_pixel(x, y, c)
	for u in main.units:
		var t: Vector2i = u.tile
		if w.inb(t):
			var uc := Color(1.0, 1.0, 0.3) if u.kind == "imp" else (Color(0.3, 1.0, 0.4) if u.team == 1 else Color(0.4, 0.7, 1.0))
			mini_img.set_pixel(t.x, t.y, uc)
	mini_tex.update(mini_img)
	var f: Vector3 = main.rig.focus
	var span: float = main.rig.dist * 1.25 / Defs.TILE
	var sc := minimap.size / Vector2(Defs.W, Defs.H)
	cam_marker.size = Vector2(span * 1.6, span) * sc
	cam_marker.position = Vector2(f.x / Defs.TILE, f.z / Defs.TILE) * sc - cam_marker.size * 0.5

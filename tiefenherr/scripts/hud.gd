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
var mini_holder: Control
var slot_boxes := {}
var level_box: VBoxContainer
var btn_next: Button
const MINI := 186.0
const MINI_BOX := 264.0


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
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		th.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
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


func _tool_button(parent: Node, key: String, hotkey: String, tip: String) -> Button:
	var b := Button.new()
	b.icon = Icons.tex(key)
	b.text = hotkey
	b.tooltip_text = tip
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = Vector2(62, 76)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", _sb(Color(0.17, 0.1, 0.09, 0.95), Color(0.42, 0.28, 0.13), 2, 6, 4.0))
	b.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.17, 0.12, 0.95), Color(0.9, 0.66, 0.28), 2, 6, 4.0))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.55, 0.14, 0.08, 0.95), Color(1.0, 0.85, 0.4), 3, 6, 4.0))
	b.add_theme_stylebox_override("hover_pressed", _sb(Color(0.62, 0.18, 0.1, 0.95), Color(1.0, 0.9, 0.5), 3, 6, 4.0))
	b.pressed.connect(func():
		Sfx.play("ui", -6.0)
		main.set_tool(key))
	parent.add_child(b)
	tool_buttons[key] = b
	return b


func _group(parent: Node, title: String) -> HBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	parent.add_child(vb)
	var l := _label(vb, title, 12, Color(0.75, 0.62, 0.4))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	vb.add_child(hb)
	return hb


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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	var g := _group(row, "BEFEHLE")
	_tool_button(g, "select", "Esc", "Auswahl  [Esc]\nLinksklick / Rahmen ziehen: Kreaturen wählen\nRechtsklick: bewegen oder angreifen\nFels ziehen: zum Graben markieren")
	_tool_button(g, "dig", "F", "Graben  [F]\nFelsen zum Abbau markieren (Rechteck ziehen).\nStart auf einer Markierung oder Shift entfernt sie.")
	g = _group(row, "RÄUME")
	for r in [R.TREASURY, R.LAIR, R.FARM, R.TRAINING]:
		var ri: Dictionary = Defs.ROOM_INFO[r]
		_tool_button(g, "room%d" % r, ri["key"], "%s  [%s]\nKosten: %d Gold pro Feld\n%s" % [ri["name"], ri["key"], ri["cost"], ri["desc"]])
	_tool_button(g, "sell", "X", "Verkaufen  [X]\nRaumfelder und Fallen abreißen.\nDie Hälfte der Goldkosten wird erstattet.")
	g = _group(row, "FALLEN")
	for k in ["spike", "wallspike", "fire", "poison"]:
		var ti: Dictionary = Defs.TRAP_INFO[k]
		_tool_button(g, "trap_" + k, ti["key"], "%s  [%s]\nKosten: %d Gold + %d Mana\nSchaden: %d · Nachladezeit: %.1f s\n%s" % [ti["name"], ti["key"], ti["gold"], ti["mana"], int(ti["dmg"]), ti["cd"], ti["desc"]])
	g = _group(row, "ZAUBER")
	for sp in ["imp", "bolt", "heal"]:
		var si: Dictionary = Defs.SPELL_INFO[sp]
		var cost := "steigt mit jedem Wichtel" if sp == "imp" else "%d Mana" % si["cost"]
		_tool_button(g, "spell_" + sp, si["key"], "%s  [%s]\nKosten: %s\n%s" % [si["name"], si["key"], cost, si["desc"]])


func _build_minimap() -> void:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_left = 8
	p.offset_bottom = -8
	p.tooltip_text = "Minikarte – immer in Blickrichtung gedreht.\nLinksklick: Kamera dorthin · Rechtsklick: Auswahl dorthin schicken"
	root.add_child(p)
	mini_holder = Control.new()
	mini_holder.custom_minimum_size = Vector2(MINI_BOX, MINI_BOX)
	mini_holder.clip_contents = true
	mini_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(mini_holder)
	minimap = TextureRect.new()
	minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap.stretch_mode = TextureRect.STRETCH_SCALE
	minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	mini_img = Image.create(Defs.W, Defs.H, false, Image.FORMAT_RGBA8)
	mini_tex = ImageTexture.create_from_image(mini_img)
	minimap.texture = mini_tex
	minimap.gui_input.connect(_on_minimap_input)
	mini_holder.add_child(minimap)
	minimap.size = Vector2(MINI, MINI)
	minimap.position = Vector2.ONE * (MINI_BOX - MINI) * 0.5
	minimap.pivot_offset = Vector2.ONE * MINI * 0.5
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
	_button(vb, "Spielen – Level wählen", func(): show_menu("levels", "main"))
	_button(vb, "Spiel laden", func(): show_menu("load", "main"))
	_button(vb, "Steuerung & Anleitung", func(): show_menu("help", "main"))
	_button(vb, "Optionen", func(): show_menu("options", "main"))
	_button(vb, "Beenden", func(): main.get_tree().quit())
	# Pause
	vb = _menu_panel("pause", "Pause")
	_button(vb, "Fortsetzen", func(): main.close_menu())
	_button(vb, "Speichern", func(): show_menu("save", "pause"))
	_button(vb, "Laden", func(): show_menu("load", "pause"))
	_button(vb, "Steuerung & Anleitung", func(): show_menu("help", "pause"))
	_button(vb, "Optionen", func(): show_menu("options", "pause"))
	_button(vb, "Level neu starten", func(): main.restart())
	_button(vb, "Hauptmenü", func(): main.to_main_menu())
	_button(vb, "Beenden", func(): main.get_tree().quit())
	# Levelauswahl
	vb = _menu_panel("levels", "Level wählen")
	level_box = VBoxContainer.new()
	level_box.add_theme_constant_override("separation", 8)
	vb.add_child(level_box)
	_button(vb, "Zurück", func(): show_menu(_menu_return))
	# Speichern / Laden
	for mode in ["save", "load"]:
		vb = _menu_panel(mode, "Spiel speichern" if mode == "save" else "Spiel laden")
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		vb.add_child(grid)
		slot_boxes[mode] = grid
		var hl := _label(vb, "Schnellspeichern: F5 · Schnellladen: F9", 15, Color(0.8, 0.75, 0.6))
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_button(vb, "Zurück", func(): show_menu(_menu_return))
	# Optionen
	vb = _menu_panel("options", "Optionen")
	opt["gamma"] = _slider(vb, "Helligkeit (Gamma)", main.settings["gamma"], func(v): _set_opt("gamma", v), 0.6, 2.4)
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
	_button(vb, "Zurück", func():
		main.save_settings()
		show_menu(_menu_return))
	# Hilfe
	vb = _menu_panel("help", "Steuerung")
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(760, 0)
	rt.text = _help_text()
	vb.add_child(rt)
	_button(vb, "Zurück", func(): show_menu(_menu_return))
	# Spielende
	vb = _menu_panel("end", "")
	end_title = _label(vb, "", 60, GOLD)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_text = _label(vb, "", 19)
	end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_next = _button(vb, "Nächstes Level", func(): main.start_level(main.level_i + 1))
	_button(vb, "Level wiederholen", func(): main.restart())
	_button(vb, "Hauptmenü", func(): main.to_main_menu())
	_button(vb, "Beenden", func(): main.get_tree().quit())


func _fill_levels() -> void:
	for c in level_box.get_children():
		level_box.remove_child(c)
		c.queue_free()
	for i in Defs.LEVELS.size():
		var lv: Dictionary = Defs.LEVELS[i]
		var locked: bool = i > main.settings["progress"]
		var b := _button(level_box, "%d · %s%s\n%s" % [i + 1, lv["name"], "   (gesperrt)" if locked else "", lv["desc"]], func(): main.start_level(i),
			"%d Wellen · %d Tor(e) · %d Portal(e) · Startgold %d" % [lv["waves"].size(), lv["gates"].size(), lv["portals"].size(), lv["start_gold"]])
		b.disabled = locked
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(640, 0)


func _fill_slots(mode: String) -> void:
	var grid: GridContainer = slot_boxes[mode]
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var slots := []
	if mode == "load":
		slots.append("quick")
	for i in main.SLOTS:
		slots.append(str(i + 1))
	for slot in slots:
		var info: Dictionary = main.slot_info(slot)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(270, 218)
		b.disabled = mode == "load" and info.is_empty()
		var vb := VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(vb)
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(254, 143)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(tr)
		var nm: String = "Schnellspeicher" if slot == "quick" else "Platz " + slot
		var txt := nm + "\n– leer –"
		if not info.is_empty():
			tr.texture = info["tex"]
			txt = "%s · %s\nLevel %d: %s · Welle %d · %s" % [nm, info["date"], info["level"] + 1, Defs.LEVELS[info["level"]]["name"], info["wave"], _fmt_time(info["time"])]
		var l := _label(vb, txt, 13)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(func():
			Sfx.play("ui", -6.0)
			if mode == "save":
				main.save_game(slot)
				_fill_slots("save")
			else:
				main.load_game(slot))
		grid.add_child(b)


func _help_text() -> String:
	return """[color=#f2c75a][b]Kamera[/b][/color]
  WASD / Pfeiltasten / Bildschirmrand – bewegen (Shift = schneller)
  Mausrad – zoomen · Q/E oder mittlere Maustaste ziehen – drehen & neigen
  Leertaste – zum Dungeon-Herz · Minikarte (dreht sich mit der Blickrichtung) anklicken – dorthin springen

[color=#f2c75a][b]Befehle[/b][/color]
  Linksklick / Rahmen ziehen – Kreaturen auswählen (Shift = hinzufügen, Strg+A = alle)
  Rechtsklick – ausgewählte Kreaturen bewegen bzw. Feind angreifen
  Fels mit Linksklick ziehen – Graben markieren (auch ohne Werkzeug)
  F Graben · 1-4 Räume · 5-8 Fallen · X Verkaufen · C/V/B Zauber · Rechtsklick/Esc – abbrechen
  P – Taktische Pause (Befehle & Bauen bleiben möglich) · +/- Spieltempo · N – Welle rufen
  F5 Schnellspeichern · F9 Schnellladen · Speichern/Laden mit Vorschaubild im Pausemenü

[color=#f2c75a][b]Ziel[/b][/color]
  Deine Grubenwichtel graben markierte Felsen ab, bringen Gold ins Lager,
  beanspruchen Boden und befestigen Wände. Beanspruche ein [color=#b070ff]Portal[/color] (lila),
  baue Hort + Pilzfarm, um Kreaturen anzulocken. Übungsraum & Schatzkammer
  locken stärkere Kreaturen an. Ist das Lager voll, geht Gold verloren – baue Schatzkammern!

[color=#f2c75a][b]Fallen[/b][/color] (kosten Gold und Mana, lösen nur bei Helden aus)
  Bodenstachel und Feuerfalle auf eigenen Boden, Giftregen verätzt ein ganzes Gebiet,
  Wandstachel gehören in befestigte Wände entlang der Gänge.
  Überstehe alle Heldenwellen – wird dein Herz zerstört, ist das Level verloren."""


func _set_opt(k: String, v) -> void:
	main.settings[k] = v
	main.apply_settings()


func _slider(parent: Node, txt: String, val: float, cb: Callable, vmin := 0.0, vmax := 1.0) -> HSlider:
	var hb := HBoxContainer.new()
	parent.add_child(hb)
	var l := _label(hb, txt, 17)
	l.custom_minimum_size = Vector2(190, 0)
	var s := HSlider.new()
	s.min_value = vmin
	s.max_value = vmax
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
	if nm == "save" or nm == "load":
		_fill_slots(nm)
	elif nm == "levels":
		_fill_levels()
	# Bei offenen Optionen bleibt das Spielbild sichtbar, damit man die Helligkeit beurteilen kann
	overlay.color = Color(0, 0, 0, 0.12 if nm == "options" else 0.55)
	overlay.visible = nm != ""
	for k in menus.keys():
		menus[k].visible = (k == nm)


func menu_visible() -> bool:
	return overlay.visible


func show_end(win: bool, stats: Dictionary, time_s: float, has_next := false) -> void:
	end_title.text = "SIEG!" if win else "NIEDERLAGE"
	end_title.add_theme_color_override("font_color", GOLD if win else Color(0.9, 0.2, 0.15))
	var head := "Alle Heldenwellen wurden zurückgeschlagen." if win else "Dein Dungeon-Herz wurde zerstört."
	if win and not has_next:
		head += "\nDu hast das letzte Level gemeistert – dein Reich in der Tiefe ist sicher!"
	btn_next.visible = has_next
	end_text.text = "Level %d: %s\n%s\n\nSpielzeit: %s\nHelden besiegt: %d\nEigene Verluste: %d\nFelder gegraben: %d\nGold abgebaut: %d" % [main.level_i + 1, main.lvl["name"], head, _fmt_time(time_s), stats["killed"], stats["lost"], stats["dug"], stats["gold_mined"]]
	show_menu("end")


# ---------------------------------------------------------------- Aktualisierung
func _fmt_time(s: float) -> String:
	var t := maxi(0, int(s))
	return "%d:%02d" % [t / 60, t % 60]


func update_stats() -> void:
	var full: bool = main.total_gold() >= main.gold_capacity()
	lbl["gold"].text = "Gold  %d / %d%s" % [main.total_gold(), main.gold_capacity(), "  LAGER VOLL!" if full else ""]
	lbl["gold"].add_theme_color_override("font_color", Color(1.0, 0.35, 0.25) if full else GOLD)
	lbl["mana"].text = "Mana  %d" % int(main.mana)
	lbl["imps"].text = "Wichtel  %d" % main.count_units("imp")
	lbl["crea"].text = "Kreaturen  %d / %d" % [main.creature_count(), main.world.room_count[R.LAIR]]
	lbl["heart"].text = "Herz  %d%%" % int(100.0 * main.heart_hp / Defs.HEART_HP)
	lbl["pay"].text = "Zahltag  %s" % _fmt_time(main.payday_t)
	if main.wave >= main.waves.size():
		lbl["wave"].text = "Letzte Welle! Helden übrig: %d" % main.hero_count()
	else:
		lbl["wave"].text = "Welle %d/%d in %s" % [main.wave + 1, main.waves.size(), _fmt_time(main.wave_timer)]
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
	cam_marker.pivot_offset = cam_marker.size * 0.5
	cam_marker.position = Vector2(f.x / Defs.TILE, f.z / Defs.TILE) * sc - cam_marker.size * 0.5


func _process(_delta: float) -> void:
	# Minikarte immer in Blickrichtung drehen (oben = vorne)
	if main and main.rig and minimap:
		minimap.rotation = main.rig.yaw
		cam_marker.rotation = -main.rig.yaw

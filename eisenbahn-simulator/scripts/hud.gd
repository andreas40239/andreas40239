class_name Hud
extends CanvasLayer
## Gesamte Bedienoberfläche: Hauptmenü, Bau-Ansicht, Fahr-Ansicht und Dialoge.

signal level_chosen(index: int)
signal tool_selected(tool: int)
signal drive_pressed
signal build_pressed
signal menu_pressed
signal rotate_pressed
signal clear_pressed
signal camera_pressed
signal switch_pressed
signal whistle_pressed
signal brake_changed(down: bool)
signal throttle_changed(value: float)
signal settings_changed
signal ui_click

const TOOLS := [
	[G.Tool.VIEW, "view", "Ansicht", ""],
	[G.Tool.TRACK, "track", "Gleis", "10"],
	[G.Tool.SWITCH, "switch", "Weiche", "+30"],
	[G.Tool.BRIDGE, "bridge", "Brücke", "80"],
	[G.Tool.CROSSING, "crossing", "Übergang", "50"],
	[G.Tool.STATION, "station", "Bahnhof", "30"],
	[G.Tool.ERASE, "erase", "Abriss", ""],
]

var root: Control
var menu: Control
var build: Control
var drive: Control
var throttle: Throttle

var _tool_btns: Dictionary = {}
var _lbl_title: Label
var _lbl_money: Label
var _lbl_route: Label
var _route_icon: TextureRect
var _route_panel: PanelContainer
var _btn_drive: TButton
var _toast: PanelContainer
var _toast_lbl: Label
var _toast_tw: Tween
var _dialog: Control
var _lbl_speed: Label
var _lbl_drive_title: Label
var _lbl_drive_hint: Label
var _btn_switch: TButton
var _btn_cam: TButton
var _chip: PanelContainer
var _chip_lbl: Label
var _music_btns: Array[TButton] = []
var _sfx_btns: Array[TButton] = []
var _level_cards: Control
var _hint_panel: PanelContainer
var _hint_lbl: Label


func _ready() -> void:
	UI.init()
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_menu()
	_build_build()
	_build_drive()
	_build_toast()
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	show_screen("")


func _apply_safe_area() -> void:
	## Aussparungen (Notch, abgerundete Ecken) berücksichtigen.
	var win := Vector2(DisplayServer.window_get_size())
	var vp := get_viewport().get_visible_rect().size
	var l := 0.0
	var t := 0.0
	var r := 0.0
	var b := 0.0
	if OS.has_feature("mobile") and win.x > 0 and win.y > 0:
		var safe := DisplayServer.get_display_safe_area()
		var sx := vp.x / win.x
		var sy := vp.y / win.y
		l = maxf(0.0, safe.position.x * sx)
		t = maxf(0.0, safe.position.y * sy)
		r = maxf(0.0, (win.x - safe.end.x) * sx)
		b = maxf(0.0, (win.y - safe.end.y) * sy)
	root.offset_left = l
	root.offset_top = t
	root.offset_right = -r
	root.offset_bottom = -b


func _full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c


func _anchor(c: Control, preset: int, offset: Vector2, grow_h: int = Control.GROW_DIRECTION_END, grow_v: int = Control.GROW_DIRECTION_END) -> void:
	c.set_anchors_preset(preset)
	c.grow_horizontal = grow_h
	c.grow_vertical = grow_v
	c.position = Vector2.ZERO
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	c.offset_left += offset.x
	c.offset_right += offset.x
	c.offset_top += offset.y
	c.offset_bottom += offset.y


func _round(icon_name: String, size: float = 58.0, col: Color = UI.C_BTN) -> TButton:
	var b := TButton.make(TButton.Layout.ICON, icon_name, "", Vector2(size, size), col)
	b.radius = int(size * 0.5)
	b.icon_size = size * 0.52
	b.pressed_down.connect(func() -> void: ui_click.emit())
	return b


func show_screen(which: String) -> void:
	menu.visible = which == "menu"
	build.visible = which == "build"
	drive.visible = which == "drive"
	_hint_panel.visible = false


# ====================================================================== Hauptmenü

func _build_menu() -> void:
	menu = _full(Control.new())
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.1, 0.16, 0.38)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(shade)

	var col := UI.vbox(4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 18
	col.offset_bottom = -18
	var title := UI.label("Gleis frei!", 92, Color.WHITE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("17324a"))
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_outline_size", 18)
	col.add_child(title)
	var sub := UI.label("Der Eisenbahn-Simulator", 28, Color("ffe9a8"), true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", Color("17324a"))
	sub.add_theme_constant_override("outline_size", 10)
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	_level_cards = UI.hbox(22)
	(_level_cards as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_level_cards)
	refresh_menu()

	var bar := UI.hbox(10)
	menu.add_child(bar)
	var bm := _round("music")
	bm.tapped.connect(func() -> void:
		Save.music_on = not Save.music_on
		_settings())
	_music_btns.append(bm)
	bar.add_child(bm)
	var bs := _round("sound")
	bs.tapped.connect(func() -> void:
		Save.sfx_on = not Save.sfx_on
		_settings())
	_sfx_btns.append(bs)
	bar.add_child(bs)
	var bi := _round("help")
	bi.tapped.connect(show_credits)
	bar.add_child(bi)
	_anchor(bar, Control.PRESET_BOTTOM_RIGHT, Vector2(-16, -14), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	_refresh_toggles()


func refresh_menu() -> void:
	for c in _level_cards.get_children():
		c.queue_free()
	for i in Levels.count():
		var lv: Dictionary = Levels.LIST[i]
		var open := Save.unlocked(i)
		var card := UI.panel(18, UI.C_PANEL_SOLID if open else Color(0.11, 0.15, 0.2, 0.8), 24)
		card.custom_minimum_size = Vector2(270, 268)
		var v := UI.vbox(8)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(v)
		var n := UI.label("LEVEL %d" % (i + 1), 18, UI.C_YELLOW if open else UI.C_DIM, true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
		var nm := UI.label(lv["name"], 32, UI.C_TEXT if open else UI.C_DIM, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
		var stars := StarRow.new()
		stars.count = Save.stars[i]
		stars.star_size = 44.0
		stars.custom_minimum_size = Vector2(170, 52)
		stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(stars)
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, 6)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sp)
		if open:
			var b := TButton.make(TButton.Layout.HORIZONTAL, "play", "Spielen", Vector2(210, 66), UI.C_GREEN)
			b.font_size = 26
			b.icon_size = 26
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var idx := i
			b.pressed_down.connect(func() -> void: ui_click.emit())
			b.tapped.connect(func() -> void: level_chosen.emit(idx))
			v.add_child(b)
		else:
			var lock := UI.icon_rect("lock", 46, UI.C_DIM)
			lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(lock)
			var ll := UI.label("Schließe Level %d ab" % i, 16, UI.C_DIM)
			ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(ll)
		_level_cards.add_child(card)


func _settings() -> void:
	_refresh_toggles()
	settings_changed.emit()


func _refresh_toggles() -> void:
	for b in _music_btns:
		b.color = UI.C_BTN if Save.music_on else Color(0.35, 0.2, 0.2, 0.9)
		b.text_color = UI.C_TEXT if Save.music_on else Color(1, 1, 1, 0.4)
		b.queue_redraw()
	for b in _sfx_btns:
		b.color = UI.C_BTN if Save.sfx_on else Color(0.35, 0.2, 0.2, 0.9)
		b.text_color = UI.C_TEXT if Save.sfx_on else Color(1, 1, 1, 0.4)
		b.queue_redraw()


# ====================================================================== Bau-Ansicht

func _top_right_bar(parent: Control, with_rotate: bool) -> HBoxContainer:
	var bar := UI.hbox(8)
	parent.add_child(bar)
	if with_rotate:
		var br := _round("rotate")
		br.tapped.connect(func() -> void: rotate_pressed.emit())
		bar.add_child(br)
	var bm := _round("music")
	bm.tapped.connect(func() -> void:
		Save.music_on = not Save.music_on
		_settings())
	_music_btns.append(bm)
	bar.add_child(bm)
	var bs := _round("sound")
	bs.tapped.connect(func() -> void:
		Save.sfx_on = not Save.sfx_on
		_settings())
	_sfx_btns.append(bs)
	bar.add_child(bs)
	return bar


func _build_build() -> void:
	build = _full(Control.new())
	# Info oben links
	var info := UI.hbox(8)
	build.add_child(info)
	var p1 := UI.panel(12)
	_lbl_title = UI.label("Level", 22, UI.C_TEXT, true)
	p1.add_child(_lbl_title)
	info.add_child(p1)
	var p2 := UI.panel(12)
	var h2 := UI.hbox(8)
	h2.add_child(UI.icon_rect("coin", 26, UI.C_YELLOW))
	_lbl_money = UI.label("0 / 0", 22, UI.C_TEXT, true)
	h2.add_child(_lbl_money)
	p2.add_child(h2)
	info.add_child(p2)
	_route_panel = UI.panel(12)
	var h3 := UI.hbox(8)
	_route_icon = UI.icon_rect("warn", 24, UI.C_ORANGE)
	h3.add_child(_route_icon)
	_lbl_route = UI.label("Strecke offen", 20, UI.C_TEXT)
	h3.add_child(_lbl_route)
	_route_panel.add_child(h3)
	info.add_child(_route_panel)
	_anchor(info, Control.PRESET_TOP_LEFT, Vector2(14, 12))

	# Knöpfe oben rechts
	var bar := _top_right_bar(build, true)
	var bh := _round("help")
	bh.tapped.connect(show_help)
	bar.add_child(bh)
	var bhome := _round("home")
	bhome.tapped.connect(func() -> void: menu_pressed.emit())
	bar.add_child(bhome)
	_anchor(bar, Control.PRESET_TOP_RIGHT, Vector2(-14, 12), Control.GROW_DIRECTION_BEGIN)

	# Werkzeugleiste
	var tp := UI.panel(10, UI.C_PANEL, 24)
	var th := UI.hbox(8)
	tp.add_child(th)
	for td in TOOLS:
		var b := TButton.make(TButton.Layout.VERTICAL, td[1], td[2], Vector2(98, 86))
		b.sub = td[3]
		b.font_size = 17
		b.icon_size = 36
		var tool: int = td[0]
		b.pressed_down.connect(func() -> void: ui_click.emit())
		b.tapped.connect(func() -> void: tool_selected.emit(tool))
		th.add_child(b)
		_tool_btns[tool] = b
	build.add_child(tp)
	_anchor(tp, Control.PRESET_CENTER_BOTTOM, Vector2(0, -12), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)

	_btn_drive = TButton.make(TButton.Layout.VERTICAL, "play", "Abfahrt!", Vector2(150, 106), UI.C_GREEN)
	_btn_drive.font_size = 24
	_btn_drive.icon_size = 40
	_btn_drive.radius = 24
	_btn_drive.pressed_down.connect(func() -> void: ui_click.emit())
	_btn_drive.tapped.connect(func() -> void: drive_pressed.emit())
	build.add_child(_btn_drive)
	_anchor(_btn_drive, Control.PRESET_BOTTOM_RIGHT, Vector2(-14, -12), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)

	var bclear := _round("retry", 62)
	bclear.tapped.connect(func() -> void:
		confirm("Alles abreißen?", "Alle gebauten Teile dieses Levels werden entfernt und das Budget zurückerstattet.", "Abreißen",
			func() -> void: clear_pressed.emit()))
	build.add_child(bclear)
	_anchor(bclear, Control.PRESET_BOTTOM_LEFT, Vector2(14, -12), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)

	# Schritt-Hinweis (Tutorial)
	_hint_panel = UI.panel(12, Color(0.13, 0.32, 0.5, 0.94), 16)
	var hh := UI.hbox(10)
	hh.add_child(UI.icon_rect("flag", 24, UI.C_YELLOW))
	_hint_lbl = UI.label("", 20, UI.C_TEXT)
	hh.add_child(_hint_lbl)
	_hint_panel.add_child(hh)
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint_panel)
	_hint_panel.visible = false


func set_level_title(t: String) -> void:
	_lbl_title.text = t
	_lbl_drive_title.text = t


func set_tool(tool: int) -> void:
	for t in _tool_btns:
		(_tool_btns[t] as TButton).selected = (t == tool)


func set_money(spent: int, budget: int) -> void:
	_lbl_money.text = "%d / %d" % [spent, budget]
	_lbl_money.add_theme_color_override("font_color", UI.C_RED.lightened(0.3) if spent > budget * 0.9 else UI.C_TEXT)


func set_route(complete: bool, can_drive: bool) -> void:
	_lbl_route.text = "Strecke verbunden" if complete else "Strecke noch offen"
	_route_icon.texture = UI.icon("check" if complete else "warn")
	_route_icon.modulate = UI.C_GREEN.lightened(0.2) if complete else UI.C_ORANGE
	_btn_drive.disabled = not can_drive
	_btn_drive.color = UI.C_GREEN if complete else UI.C_BLUE


func set_hint(text: String) -> void:
	_hint_panel.visible = text != "" and build.visible
	if text == "":
		return
	_hint_lbl.text = text
	_hint_panel.reset_size()
	_anchor(_hint_panel, Control.PRESET_CENTER_BOTTOM, Vector2(0, -122), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)


# ====================================================================== Fahr-Ansicht

func _build_drive() -> void:
	drive = _full(Control.new())
	var info := UI.hbox(8)
	drive.add_child(info)
	var p1 := UI.panel(12)
	var v1 := UI.vbox(0)
	_lbl_drive_title = UI.label("Level", 20, UI.C_TEXT, true)
	v1.add_child(_lbl_drive_title)
	_lbl_drive_hint = UI.label("", 16, UI.C_DIM)
	v1.add_child(_lbl_drive_hint)
	p1.add_child(v1)
	info.add_child(p1)
	_anchor(info, Control.PRESET_TOP_LEFT, Vector2(14, 12))

	var bar := _top_right_bar(drive, false)
	_btn_cam = TButton.make(TButton.Layout.HORIZONTAL, "camera", "Übersicht", Vector2(196, 58))
	_btn_cam.font_size = 19
	_btn_cam.icon_size = 28
	_btn_cam.radius = 29
	_btn_cam.pressed_down.connect(func() -> void: ui_click.emit())
	_btn_cam.tapped.connect(func() -> void: camera_pressed.emit())
	bar.add_child(_btn_cam)
	bar.move_child(_btn_cam, 0)
	var bb := TButton.make(TButton.Layout.HORIZONTAL, "build", "Umbauen", Vector2(170, 58), UI.C_BLUE)
	bb.font_size = 19
	bb.icon_size = 26
	bb.radius = 29
	bb.pressed_down.connect(func() -> void: ui_click.emit())
	bb.tapped.connect(func() -> void: build_pressed.emit())
	bar.add_child(bb)
	_anchor(bar, Control.PRESET_TOP_RIGHT, Vector2(-14, 12), Control.GROW_DIRECTION_BEGIN)

	# Fahrregler rechts
	throttle = Throttle.new()
	throttle.changed.connect(func(v: float) -> void: throttle_changed.emit(v))
	drive.add_child(throttle)
	_anchor(throttle, Control.PRESET_BOTTOM_RIGHT, Vector2(-16, -14), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)

	# Bremse und Pfeife links
	var left := UI.hbox(14)
	left.alignment = BoxContainer.ALIGNMENT_END
	drive.add_child(left)
	var brake := TButton.make(TButton.Layout.VERTICAL, "brake", "Bremse", Vector2(128, 128), UI.C_RED)
	brake.font_size = 22
	brake.icon_size = 54
	brake.radius = 30
	brake.pressed_down.connect(func() -> void: brake_changed.emit(true))
	brake.released.connect(func() -> void: brake_changed.emit(false))
	left.add_child(brake)
	var wh := TButton.make(TButton.Layout.VERTICAL, "whistle", "Pfeife", Vector2(104, 104), UI.C_BTN)
	wh.font_size = 19
	wh.icon_size = 42
	wh.radius = 26
	wh.size_flags_vertical = Control.SIZE_SHRINK_END
	wh.pressed_down.connect(func() -> void: whistle_pressed.emit())
	left.add_child(wh)
	_anchor(left, Control.PRESET_BOTTOM_LEFT, Vector2(16, -14), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)

	# Tacho und Weichentaste unten Mitte
	var mid := UI.hbox(12)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	drive.add_child(mid)
	var sp := UI.panel(10, UI.C_PANEL, 22)
	sp.custom_minimum_size = Vector2(170, 76)
	var sh := UI.hbox(6)
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	_lbl_speed = UI.label("0", 44, UI.C_TEXT, true)
	_lbl_speed.custom_minimum_size = Vector2(70, 0)
	_lbl_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sh.add_child(_lbl_speed)
	var unit := UI.label("km/h", 18, UI.C_DIM, true)
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	sh.add_child(unit)
	sp.add_child(sh)
	mid.add_child(sp)
	_btn_switch = TButton.make(TButton.Layout.HORIZONTAL, "fork", "Weiche", Vector2(236, 76), UI.C_YELLOW.darkened(0.25))
	_btn_switch.font_size = 20
	_btn_switch.icon_size = 34
	_btn_switch.radius = 22
	_btn_switch.pressed_down.connect(func() -> void: ui_click.emit())
	_btn_switch.tapped.connect(func() -> void: switch_pressed.emit())
	mid.add_child(_btn_switch)
	_anchor(mid, Control.PRESET_CENTER_BOTTOM, Vector2(0, -14), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)

	# Hinweis-Chip oben Mitte
	_chip = UI.panel(12, UI.C_RED, 20)
	_chip_lbl = UI.label("", 22, Color.WHITE, true)
	_chip.add_child(_chip_lbl)
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drive.add_child(_chip)
	_chip.visible = false


func set_speed(kmh: float) -> void:
	_lbl_speed.text = str(int(round(absf(kmh))))


func set_drive_hint(t: String) -> void:
	_lbl_drive_hint.text = t


func set_camera_name(n: String) -> void:
	_btn_cam.text = n
	_btn_cam.queue_redraw()


## state: -1 = keine Weiche voraus, sonst 0/1; label = Beschriftung
func set_switch_info(show: bool, text: String) -> void:
	_btn_switch.visible = show
	if show and _btn_switch.text != text:
		_btn_switch.text = text
		_btn_switch.queue_redraw()


func set_chip(text: String, col: Color = UI.C_RED) -> void:
	if text == "":
		_chip.visible = false
		return
	if _chip_lbl.text != text or not _chip.visible:
		_chip_lbl.text = text
		(_chip.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = col
		_chip.visible = true
		_chip.reset_size()
		_anchor(_chip, Control.PRESET_CENTER_TOP, Vector2(0, 84), Control.GROW_DIRECTION_BOTH)


# ====================================================================== Meldungen

func _build_toast() -> void:
	_toast = UI.panel(14, Color(0.1, 0.12, 0.16, 0.94), 18)
	_toast_lbl = UI.label("", 21, UI.C_TEXT)
	_toast.add_child(_toast_lbl)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	root.add_child(_toast)


func toast(text: String, warn: bool = false) -> void:
	if text == "":
		return
	_toast_lbl.text = text
	(_toast.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0.45, 0.14, 0.12, 0.95) if warn else Color(0.1, 0.12, 0.16, 0.94)
	_toast.visible = true
	_toast.reset_size()
	_anchor(_toast, Control.PRESET_CENTER_TOP, Vector2(0, 80), Control.GROW_DIRECTION_BOTH)
	_toast.modulate.a = 1.0
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(2.2)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tw.tween_callback(func() -> void: _toast.visible = false)


# ====================================================================== Dialoge

func close_dialog() -> void:
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null


func has_dialog() -> bool:
	return _dialog != null


## Allgemeiner Dialog. buttons: Array von [Text, Farbe, Callable, Symbol].
func dialog(title: String, body: String, buttons: Array, extra: Control = null, width: float = 620.0) -> void:
	close_dialog()
	_dialog = Control.new()
	_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dialog)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.09, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.add_child(center)
	var p := UI.panel(26, UI.C_PANEL_SOLID, 28)
	p.custom_minimum_size = Vector2(width, 0)
	center.add_child(p)
	var v := UI.vbox(14)
	p.add_child(v)
	var tl := UI.label(title, 34, UI.C_YELLOW, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	if extra != null:
		extra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(extra)
	if body != "":
		var bl := UI.label(body, 21, UI.C_TEXT)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.custom_minimum_size = Vector2(width - 60, 0)
		v.add_child(bl)
	var row := UI.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for bd in buttons:
		var ic: String = bd[3] if bd.size() > 3 else ""
		var b := TButton.make(TButton.Layout.HORIZONTAL if ic != "" else TButton.Layout.TEXT, ic, bd[0], Vector2(maxf(170.0, 60.0 + 13.0 * (bd[0] as String).length()), 62), bd[1])
		b.font_size = 22
		b.icon_size = 26
		var cb: Callable = bd[2]
		b.pressed_down.connect(func() -> void: ui_click.emit())
		b.tapped.connect(func() -> void:
			close_dialog()
			if cb.is_valid():
				cb.call())
		row.add_child(b)
	p.pivot_offset = Vector2(width * 0.5, 120)
	p.scale = Vector2(0.9, 0.9)
	p.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.12)


func confirm(title: String, body: String, yes: String, on_yes: Callable) -> void:
	dialog(title, body, [["Abbrechen", UI.C_BTN, Callable()], [yes, UI.C_RED, on_yes]])


func show_help() -> void:
	dialog("So wird gebaut",
		"Gleis: mit dem Finger über die Felder ziehen – Kurven entstehen von selbst. Antippen dreht ein Gleisstück.\n" +
		"Weiche: auf ein vorhandenes Gleis tippen, erneut tippen wechselt die Richtung.\n" +
		"Brücke nur über Wasser, Bahnübergang nur auf Straßen, Bahnhof auf den markierten Feldern.\n" +
		"Zwei Finger: Karte verschieben und zoomen.\n" +
		"Steht der Startbahnhof, geht es mit „Abfahrt!“ auf die Strecke.",
		[["Verstanden", UI.C_GREEN, Callable()]], null, 760.0)


func show_credits() -> void:
	dialog("Gleis frei!",
		"Ein Eisenbahn-Simulator, gebaut mit der Godot Engine.\n\n" +
		"Grafik, 3D-Modelle und Musik: für dieses Spiel prozedural erzeugt.\n" +
		"Zug- und Bahnübergangsgeräusche: Joseph Sardin, BigSoundBank.com (CC0).\n" +
		"Schrift: Fredoka (SIL Open Font License).",
		[["Schließen", UI.C_GREEN, Callable()]], null, 720.0)


func show_result(success: bool, title: String, body: String, stars: int, buttons: Array) -> void:
	var extra: Control = null
	if success:
		var sr := StarRow.new()
		sr.count = stars
		sr.star_size = 72.0
		sr.custom_minimum_size = Vector2(270, 84)
		sr.animate = true
		extra = sr
	dialog(title, body, buttons, extra, 660.0)

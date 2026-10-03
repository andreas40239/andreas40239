class_name HUD
extends CanvasLayer
## Spiel-Oberfläche (GDD Kap. 6): oben links Chaos/Sonnenpunkte/Welle, oben rechts
## Tempo/Pause/Menü, unten Stationskarten bzw. Upgrade-Panel. Alles über Anker skaliert
## und innerhalb der Safe Area (AT-10).

signal card_pressed(station_id: StringName)
signal start_pressed
signal pause_pressed
signal speed_pressed
signal menu_opened
signal menu_closed
signal upgrade_pressed(path: StringName)
signal sell_pressed
signal station_panel_closed
signal retry_pressed
signal map_pressed
signal next_pressed
signal intro_closed

const MARGIN := 22.0
const SELL_CONFIRM_THRESHOLD := 150

var _root: Control
var _safe: Control
var _chaos_meter: ChaosMeter
var _currency_label: Label
var _wave_label: Label
var _speed_btn: IconButton
var _pause_btn: IconButton
var _menu_btn: IconButton
var _tray: PanelContainer
var _cards: Dictionary = {}
var _station_panel: PanelContainer
var _sp_preview: StationPreview
var _sp_title: Label
var _sp_info: Label
var _sp_range_btn: RichButton
var _sp_power_btn: RichButton
var _sp_sell_btn: RichButton
var _start_btn: IconButton
var _toast: PanelContainer
var _toast_label: Label
var _toast_left := 0.0
var _banner: Label
var _tutorial_panel: PanelContainer
var _tutorial_label: Label
var _tutorial_face: MonsterPreview
var _highlight: HighlightRing
var _pause_banner: PanelContainer
var _modal: Control
var _modal_content: Control
var _current_station: Station
var _level: LevelData
var _sell_confirm_left := 0.0
var _start_pulse := 0.0
var _start_state: StringName = &"hidden"


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_safe = Control.new()
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_safe)
	_build_top_bar()
	_build_tray_and_panel()
	_build_overlays()
	GameState.currency_changed.connect(_on_currency_changed)
	GameState.chaos_changed.connect(_on_chaos_changed)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


# --- Aufbau ----------------------------------------------------------------------

static func _anchor(c: Control, ax: float, ay: float, ox: float, oy: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	c.grow_horizontal = Control.GROW_DIRECTION_END if ax <= 0.0 else (Control.GROW_DIRECTION_BEGIN if ax >= 1.0 else Control.GROW_DIRECTION_BOTH)
	c.grow_vertical = Control.GROW_DIRECTION_END if ay <= 0.0 else (Control.GROW_DIRECTION_BEGIN if ay >= 1.0 else Control.GROW_DIRECTION_BOTH)


func _panel(bg: Color = Color(1, 1, 1, 0.92), radius: int = 30, margin: float = 22.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(bg, UiTheme.INK.lightened(0.45), radius, 4, 8, margin))
	return p


func _build_top_bar() -> void:
	var bar := _panel(Color(1, 1, 1, 0.9), 28, 20)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_anchor(bar, 0.0, 0.0, MARGIN, MARGIN)
	_safe.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	_chaos_meter = ChaosMeter.new()
	row.add_child(_chaos_meter)
	row.add_child(_vsep())
	row.add_child(IconRect.make(&"sun", 58))
	_currency_label = Label.new()
	_currency_label.label_settings = UiTheme.label_settings(44, UiTheme.INK, 0, Color.WHITE, true)
	_currency_label.custom_minimum_size.x = 96
	row.add_child(_currency_label)
	row.add_child(_vsep())
	row.add_child(IconRect.make(&"flag", 52))
	_wave_label = Label.new()
	_wave_label.label_settings = UiTheme.label_settings(40, UiTheme.INK, 0, Color.WHITE, true)
	row.add_child(_wave_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	_anchor(buttons, 1.0, 0.0, -MARGIN, MARGIN)
	_safe.add_child(buttons)
	_speed_btn = IconButton.make(&"fast", UiTheme.ORANGE)
	_speed_btn.pressed.connect(func() -> void: speed_pressed.emit())
	buttons.add_child(_speed_btn)
	_pause_btn = IconButton.make(&"pause", UiTheme.BLUE)
	_pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	buttons.add_child(_pause_btn)
	_menu_btn = IconButton.make(&"gear", Color("7d8bb0"))
	_menu_btn.pressed.connect(_open_menu)
	buttons.add_child(_menu_btn)


func _vsep() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.18, 0.23, 0.36, 0.15)
	c.custom_minimum_size = Vector2(3, 54)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _build_tray_and_panel() -> void:
	_tray = _panel(Color(1, 1, 1, 0.82), 32, 16)
	_anchor(_tray, 0.5, 1.0, 0, -MARGIN)
	_safe.add_child(_tray)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	_tray.add_child(cards)
	for id in DataRegistry.STATION_ORDER:
		var card := StationCard.make(id)
		card.pressed.connect(func() -> void: card_pressed.emit(id))
		cards.add_child(card)
		_cards[id] = card

	_station_panel = _panel(Color(1, 1, 1, 0.95), 32, 18)
	_anchor(_station_panel, 0.5, 1.0, 0, -MARGIN)
	_station_panel.visible = false
	_safe.add_child(_station_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_station_panel.add_child(row)
	_sp_preview = StationPreview.make(&"keksstand", Vector2(150, 150), 0.82)
	row.add_child(_sp_preview)
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.custom_minimum_size.x = 250
	row.add_child(info)
	_sp_title = Label.new()
	_sp_title.label_settings = UiTheme.label_settings(34, UiTheme.INK, 0, Color.WHITE, true)
	info.add_child(_sp_title)
	_sp_info = Label.new()
	_sp_info.label_settings = UiTheme.label_settings(26, UiTheme.INK.lightened(0.25))
	info.add_child(_sp_info)
	_sp_range_btn = RichButton.make(&"range", "Weiter", UiTheme.BLUE, Vector2(230, 128))
	_sp_range_btn.pressed.connect(func() -> void: upgrade_pressed.emit(&"range"))
	row.add_child(_sp_range_btn)
	_sp_power_btn = RichButton.make(&"power", "Stärker", UiTheme.ORANGE, Vector2(230, 128))
	_sp_power_btn.pressed.connect(func() -> void: upgrade_pressed.emit(&"power"))
	row.add_child(_sp_power_btn)
	_sp_sell_btn = RichButton.make(&"coins", "Verkaufen", Color("e8e2d4"), Vector2(250, 128), UiTheme.INK)
	_sp_sell_btn.pressed.connect(_on_sell_button)
	row.add_child(_sp_sell_btn)
	var close := IconButton.make(&"close", Color("f0f0f0"), Vector2(96, 96), "", UiTheme.INK)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: station_panel_closed.emit())
	row.add_child(close)

	_start_btn = IconButton.make(&"play", UiTheme.GREEN, Vector2(270, 150), "Los!", Color.WHITE, 52)
	_start_btn.icon_size = 64
	_anchor(_start_btn, 1.0, 1.0, -MARGIN, -MARGIN)
	_start_btn.pressed.connect(func() -> void: start_pressed.emit())
	_safe.add_child(_start_btn)


func _build_overlays() -> void:
	_tutorial_panel = _panel(Color(1.0, 0.97, 0.82, 0.93), 30, 18)
	_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(_tutorial_panel, 0.5, 0.0, 0, 150)
	_tutorial_panel.visible = false
	_safe.add_child(_tutorial_panel)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 18)
	_tutorial_panel.add_child(trow)
	_tutorial_face = MonsterPreview.make(&"knurri", Vector2(96, 110), 1.0, 1.15)
	trow.add_child(_tutorial_face)
	_tutorial_label = Label.new()
	_tutorial_label.label_settings = UiTheme.label_settings(38, UiTheme.INK, 0, Color.WHITE, true)
	_tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trow.add_child(_tutorial_label)

	_toast = _panel(Color(0.18, 0.23, 0.36, 0.9), 26, 18)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(_toast, 0.5, 0.0, 0, 330)
	_toast.visible = false
	_safe.add_child(_toast)
	_toast_label = Label.new()
	_toast_label.label_settings = UiTheme.label_settings(34, Color.WHITE, 0, Color.WHITE, true)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)

	_pause_banner = _panel(Color(1, 1, 1, 0.92), 26, 18)
	_pause_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(_pause_banner, 0.5, 0.0, 0, 150)
	_pause_banner.visible = false
	_safe.add_child(_pause_banner)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	_pause_banner.add_child(pv)
	var pl := Label.new()
	pl.text = "Pause"
	pl.label_settings = UiTheme.label_settings(52, UiTheme.BLUE, 0, Color.WHITE, true)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pl)
	var ps := Label.new()
	ps.text = "Bauen geht trotzdem!"
	ps.label_settings = UiTheme.label_settings(28, UiTheme.INK)
	ps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(ps)

	_banner = Label.new()
	_banner.label_settings = UiTheme.label_settings(110, Color.WHITE, 26, Color("2f3b5c"), true)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(_banner, 0.5, 0.42, 0, 0)
	_banner.modulate.a = 0.0
	_root.add_child(_banner)

	_highlight = HighlightRing.new()
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_highlight)

	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.visible = false
	_root.add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.12, 0.25, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(dim)


func _apply_safe_area() -> void:
	var margins := Vector4.ZERO  # links, oben, rechts, unten
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var safe := DisplayServer.get_display_safe_area()
		var vp := get_viewport().get_visible_rect().size
		if win.x > 0 and win.y > 0 and safe.size.x > 0:
			var k := vp / win
			margins = Vector4(safe.position.x * k.x, safe.position.y * k.y,
				(win.x - safe.end.x) * k.x, (win.y - safe.end.y) * k.y)
			margins = Vector4(maxf(margins.x, 0.0), maxf(margins.y, 0.0), maxf(margins.z, 0.0), maxf(margins.w, 0.0))
	_safe.offset_left = margins.x
	_safe.offset_top = margins.y
	_safe.offset_right = -margins.z
	_safe.offset_bottom = -margins.w


# --- Öffentliche API (wird von Game.gd verwendet) -------------------------------

func setup(level: LevelData, speed_unlocked: bool) -> void:
	_level = level
	for id in _cards:
		_cards[id].visible = level.available_station_ids.has(id)
	_speed_btn.visible = speed_unlocked
	if not level.new_monster_ids.is_empty():
		_tutorial_face.monster_id = level.new_monster_ids[0]
	_on_currency_changed(GameState.currency)
	_on_chaos_changed(GameState.chaos, GameState.chaos_limit)


func set_wave(index: int, total: int) -> void:
	_wave_label.text = "Welle %d/%d" % [maxi(index, 1), total]


func set_cards_active(active: bool) -> void:
	for id in _cards:
		_cards[id].active = active


func shake_card(id: StringName) -> void:
	if _cards.has(id):
		_cards[id].shake()


func show_station_panel(st: Station) -> void:
	_current_station = st
	_sell_confirm_left = 0.0
	_tray.visible = false
	_station_panel.visible = true
	update_station_panel()


func hide_station_panel() -> void:
	_current_station = null
	_station_panel.visible = false
	_tray.visible = true


func is_station_panel_open() -> bool:
	return _station_panel.visible


func update_station_panel() -> void:
	var st := _current_station
	if st == null or not is_instance_valid(st):
		return
	_sp_preview.station_id = st.data.id
	_sp_preview.level = st.level
	_sp_preview.upgrade_path = st.upgrade_path
	_sp_title.text = st.data.display_name
	if st.level >= 2:
		_sp_info.text = "Stufe 2 · " + ("mehr Reichweite" if st.upgrade_path == &"range" else "stärkere Hilfe")
	else:
		_sp_info.text = "Stufe 1 · " + st.data.description
	_sp_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sp_info.custom_minimum_size.x = 250
	var can_upgrade := st.level < 2
	_sp_range_btn.visible = can_upgrade
	_sp_power_btn.visible = can_upgrade
	if can_upgrade:
		var cost := st.data.upgrade_cost
		_sp_range_btn.set_cost(cost)
		_sp_power_btn.set_cost(cost)
		var afford := GameState.can_afford(cost)
		_sp_range_btn.modulate.a = 1.0 if afford else 0.55
		_sp_power_btn.modulate.a = 1.0 if afford else 0.55
	_sp_sell_btn.set_title("Sicher?" if _sell_confirm_left > 0.0 else "Verkaufen")
	_sp_sell_btn.set_cost(st.get_sell_value(), "+")


func _on_sell_button() -> void:
	var st := _current_station
	if st == null:
		return
	if st.invested >= SELL_CONFIRM_THRESHOLD and _sell_confirm_left <= 0.0:
		_sell_confirm_left = 3.0
		update_station_panel()
		return
	_sell_confirm_left = 0.0
	sell_pressed.emit()


## state: &"start", &"countdown", &"hidden"
func set_start_state(state: StringName, seconds: float = 0.0, can_press: bool = true) -> void:
	_start_state = state
	match state:
		&"hidden":
			_start_btn.visible = false
		&"start":
			_start_btn.visible = true
			_start_btn.disabled = false
			_start_btn.text = "Los!"
			_start_btn.icon_name = &"play"
		&"countdown":
			_start_btn.visible = true
			_start_btn.disabled = not can_press
			_start_btn.icon_name = &"play" if can_press else &"flag"
			_start_btn.text = ("Los! %d" if can_press else "Gleich %d") % ceili(maxf(seconds, 0.0))


func set_paused(paused: bool) -> void:
	_pause_btn.icon_name = &"play" if paused else &"pause"
	_pause_banner.visible = paused and not _tutorial_panel.visible


func set_speed(fast: bool) -> void:
	_speed_btn.icon_name = &"play" if fast else &"fast"


func toast(text: String, seconds: float = 2.6) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_left = seconds


func wave_banner(text: String) -> void:
	_banner.text = text
	_banner.pivot_offset = _banner.size * 0.5
	var tw := _banner.create_tween()
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(0.6, 0.6)
	tw.set_parallel(true)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.9)
	tw.chain().tween_property(_banner, "modulate:a", 0.0, 0.4)


## Zeigt einen Tutorial-Hinweis. target_provider: Callable() -> Vector2 (Vector2.INF = kein Ziel)
func show_tutorial(text: String, target_provider: Callable = Callable()) -> void:
	_tutorial_label.text = text
	_tutorial_panel.visible = true
	_pause_banner.visible = false
	_highlight.provider = target_provider
	var tw := _tutorial_panel.create_tween()
	_tutorial_panel.modulate.a = 0.0
	tw.tween_property(_tutorial_panel, "modulate:a", 1.0, 0.3)


func hide_tutorial() -> void:
	_tutorial_panel.visible = false
	_highlight.provider = Callable()


func get_card_center(id: StringName) -> Vector2:
	if _cards.has(id) and _cards[id].is_visible_in_tree():
		return _cards[id].get_global_rect().get_center()
	return Vector2.INF


func get_start_center() -> Vector2:
	return _start_btn.get_global_rect().get_center() if _start_btn.is_visible_in_tree() else Vector2.INF


func get_speed_center() -> Vector2:
	return _speed_btn.get_global_rect().get_center() if _speed_btn.is_visible_in_tree() else Vector2.INF


func get_upgrade_center() -> Vector2:
	if _sp_range_btn.is_visible_in_tree():
		return _sp_range_btn.get_global_rect().get_center().lerp(_sp_power_btn.get_global_rect().get_center(), 0.5)
	return Vector2.INF


func is_modal_open() -> bool:
	return _modal.visible


# --- Modale Fenster -------------------------------------------------------------

func _open_modal(content: Control) -> void:
	if _modal_content:
		_modal_content.queue_free()
	_modal_content = content
	_anchor(content, 0.5, 0.5, 0, 0)
	_modal.add_child(content)
	_modal.visible = true
	content.pivot_offset = content.get_combined_minimum_size() * 0.5
	content.scale = Vector2(0.8, 0.8)
	content.modulate.a = 0.0
	var tw := content.create_tween().set_parallel(true)
	tw.tween_property(content, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(content, "modulate:a", 1.0, 0.2)


func _close_modal() -> void:
	if _modal_content:
		_modal_content.queue_free()
		_modal_content = null
	_modal.visible = false


func _title_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = UiTheme.label_settings(size, color, 14, Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _text_label(text: String, size: int = 36) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = UiTheme.label_settings(size, UiTheme.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Infokarte vor Welle 1: neues Monster + passende Station.
func show_intro(monster_ids: Array[StringName], station_ids: Array[StringName]) -> void:
	var panel := _panel(Color(1, 1, 1, 0.97), 40, 34)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(_title_label("Neu!", 64, UiTheme.ORANGE))
	for mid in monster_ids:
		var md := DataRegistry.monster(mid)
		var helper: StationData = null
		for sid in station_ids:
			var sd := DataRegistry.station(sid)
			if sd.helps_need(md.need_type):
				helper = sd
				break
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 30)
		v.add_child(row)
		var mp := MonsterPreview.make(mid, Vector2(250, 250), 0.0, 2.3)
		mp.walking = true
		mp.show_need = true
		row.add_child(mp)
		if helper:
			row.add_child(IconRect.make(&"play", 70, UiTheme.GREEN))
			row.add_child(StationPreview.make(helper.id, Vector2(230, 250), 1.25))
			row.add_child(IconRect.make(&"play", 70, UiTheme.GREEN))
			row.add_child(MonsterPreview.make(mid, Vector2(200, 250), 1.0, 2.0))
		v.add_child(_text_label("%s %s." % [md.display_name, Needs.label_for(md.need_type)], 42))
		if helper:
			v.add_child(_text_label("%s hilft!" % helper.display_name, 36))
	var ok := IconButton.make(&"check", UiTheme.GREEN, Vector2(340, 120), "Los geht's!", Color.WHITE, 44)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func() -> void:
		_close_modal()
		intro_closed.emit())
	v.add_child(ok)
	_open_modal(panel)


func _open_menu() -> void:
	if _modal.visible:
		return
	menu_opened.emit()
	var panel := _panel(Color(1, 1, 1, 0.97), 40, 34)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)
	v.add_child(_title_label("Pause", 64, UiTheme.BLUE))
	var resume := IconButton.make(&"play", UiTheme.GREEN, Vector2(440, 116), "Weiter", Color.WHITE, 42)
	resume.pressed.connect(func() -> void:
		_close_modal()
		menu_closed.emit())
	v.add_child(resume)
	var retry := IconButton.make(&"retry", UiTheme.ORANGE, Vector2(440, 116), "Nochmal", Color.WHITE, 42)
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	v.add_child(retry)
	var map := IconButton.make(&"map", UiTheme.BLUE, Vector2(440, 116), "Zur Karte", Color.WHITE, 42)
	map.pressed.connect(func() -> void: map_pressed.emit())
	v.add_child(map)
	v.add_child(SettingsWidgets.volume_sliders())
	_open_modal(panel)


func close_menu_if_open() -> bool:
	if _modal.visible and _modal_content and not _result_shown:
		_close_modal()
		menu_closed.emit()
		return true
	return false


var _result_shown := false


func open_menu() -> void:
	_open_menu()


func show_result(won: bool, stars: int, friends: int, total: int, has_next: bool) -> void:
	_result_shown = true
	hide_station_panel()
	hide_tutorial()
	_tray.visible = false
	_start_btn.visible = false
	_pause_banner.visible = false
	var panel := _panel(Color(1, 1, 1, 0.97), 40, 36)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	if won:
		v.add_child(_title_label("Super gemacht!", 76, UiTheme.GREEN))
		v.add_child(StarsView.make(stars, 110, true))
		v.add_child(_text_label("%d von %d Monstern sind jetzt Freunde!" % [friends, total], 40))
	else:
		v.add_child(_title_label("Oh, so ein Trubel!", 70, UiTheme.PURPLE))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for id in [&"knurri", &"troepfli", &"matschi"]:
			row.add_child(MonsterPreview.make(id, Vector2(150, 170), 0.5, 1.6))
		v.add_child(row)
		v.add_child(_text_label("Die Monster brauchen noch ein bisschen Hilfe.\nProbier es gleich nochmal!", 38))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 22)
	v.add_child(buttons)
	var map := IconButton.make(&"map", UiTheme.BLUE, Vector2(270, 120), "Karte", Color.WHITE, 40)
	map.pressed.connect(func() -> void: map_pressed.emit())
	buttons.add_child(map)
	var retry := IconButton.make(&"retry", UiTheme.ORANGE, Vector2(300, 120), "Nochmal", Color.WHITE, 40)
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	buttons.add_child(retry)
	if won and has_next:
		var next := IconButton.make(&"play", UiTheme.GREEN, Vector2(290, 120), "Weiter", Color.WHITE, 40)
		next.pressed.connect(func() -> void: next_pressed.emit())
		buttons.add_child(next)
	_open_modal(panel)


func is_result_shown() -> bool:
	return _result_shown


# --- Laufende Updates -----------------------------------------------------------

func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left < 0.4:
			_toast.modulate.a = maxf(0.0, _toast_left / 0.4)
		if _toast_left <= 0.0:
			_toast.visible = false
	if _sell_confirm_left > 0.0:
		_sell_confirm_left -= delta
		if _sell_confirm_left <= 0.0:
			update_station_panel()
	if _start_state == &"start" and _start_btn.visible:
		_start_pulse += delta
		var s := 1.0 + 0.05 * sin(_start_pulse * 5.0)
		_start_btn.pivot_offset = _start_btn.size * 0.5
		_start_btn.scale = Vector2(s, s)
	else:
		_start_btn.scale = Vector2.ONE


func _on_currency_changed(value: int) -> void:
	_currency_label.text = str(value)
	for id in _cards:
		var card: StationCard = _cards[id]
		card.affordable = value >= card.data.cost
	if _station_panel.visible:
		update_station_panel()


func _on_chaos_changed(value: int, limit: int) -> void:
	_chaos_meter.set_value(value, limit)


# --- Kleine Zeichen-Controls ----------------------------------------------------

class ChaosMeter extends Control:
	## Chaos als Wirbel-Icon + 10 Punkte (ohne Lesen verständlich, keine Herzen).
	var value := 0
	var limit := 10
	var _bump := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(330, 66)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: int, l: int) -> void:
		if v > value:
			_bump = 1.0
		value = v
		limit = l
		queue_redraw()

	func _process(delta: float) -> void:
		if _bump > 0.0:
			_bump = maxf(0.0, _bump - delta * 2.0)
			queue_redraw()

	func _draw() -> void:
		var s := 56.0 * (1.0 + 0.3 * sin(_bump * PI))
		Icons.swirl(self, Vector2(30, size.y * 0.5), s, UiTheme.PURPLE)
		var per_row := 5
		for i in limit:
			var row := int(i / float(per_row))
			var col := i % per_row
			var c := Vector2(86 + col * 50, size.y * 0.5 + (row - 0.5) * 30)
			if i < value:
				draw_circle(c, 13, UiTheme.PURPLE)
				draw_circle(c + Vector2(-4, -4), 4, Color(1, 1, 1, 0.5))
			else:
				draw_circle(c, 13, Color(0.6, 0.55, 0.75, 0.18))
				draw_arc(c, 13, 0, TAU, 20, Color(0.6, 0.55, 0.75, 0.6), 2.5, true)


class HighlightRing extends Control:
	## Pulsierender Ring + Pfeil, der Kindern zeigt, wo sie tippen sollen.
	var provider := Callable()
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if not provider.is_valid():
			return
		var p: Vector2 = provider.call()
		if not p.is_finite():
			return
		var k := fmod(_t * 1.2, 1.0)
		draw_arc(p, 60 + k * 40, 0, TAU, 40, Color(1, 0.85, 0.2, 1.0 - k), 8.0, true)
		draw_arc(p, 62, 0, TAU, 40, Color(1, 0.85, 0.2, 0.9), 6.0, true)
		var bob := sin(_t * 6.0) * 12.0
		var tip := p + Vector2(0, -78 + bob)
		if p.y < 260:
			tip = p + Vector2(0, 78 - bob)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-30, 42), tip + Vector2(30, 42)]), Color("ff9f1c"))
			draw_rect(Rect2(tip + Vector2(-12, 40), Vector2(24, 36)), Color("ff9f1c"))
		else:
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-30, -42), tip + Vector2(30, -42)]), Color("ff9f1c"))
			draw_rect(Rect2(tip + Vector2(-12, -76), Vector2(24, 36)), Color("ff9f1c"))

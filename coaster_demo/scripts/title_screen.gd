class_name TitleScreen
extends Control
## Startbildschirm: Menü-Panel links, im Hintergrund fährt die Demo-Strecke.

signal continue_pressed
signal new_pressed
signal load_pressed
signal demo_pressed
signal tutorial_pressed
signal sound_pressed

var continue_button: Button
var sound_button: Button
var _panel: PanelContainer


func setup(can_continue: bool, muted: bool) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# leichter Verlauf von links, damit das Menü lesbar bleibt
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.08, 0.1, 0.14, 0.65))
	grad.set_color(1, Color(0.08, 0.1, 0.14, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.25, 0)
	gtex.fill_to = Vector2(0.75, 0)
	shade.texture = gtex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.17, 0.9)
	style.set_corner_radius_all(22)
	style.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.offset_left = 48
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.svg")
	logo.custom_minimum_size = Vector2(84, 84)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(logo)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(titles)
	titles.add_child(_label("COASTER DEMO", 50, Color(1, 1, 1)))
	titles.add_child(_label("Achterbahn bauen – und selbst fahren", 19, Color(0.75, 0.85, 0.95)))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	col.add_child(spacer)

	continue_button = _menu_button("continue", "Weiterbauen", continue_pressed, true)
	continue_button.disabled = not can_continue
	col.add_child(continue_button)
	col.add_child(_menu_button("plus", "Neue Strecke", new_pressed))
	col.add_child(_menu_button("load", "Strecke laden", load_pressed))
	col.add_child(_menu_button("demo", "Demo-Strecke fahren", demo_pressed))
	col.add_child(_menu_button("help", "Tutorial", tutorial_pressed))

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	col.add_child(foot)
	var ver := _label("v%s · Greybox-Prototyp" % ProjectSettings.get_setting("application/config/version", "0"),
		16, Color(0.6, 0.63, 0.68))
	ver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ver.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(ver)
	sound_button = Button.new()
	sound_button.custom_minimum_size = Vector2(56, 56)
	sound_button.expand_icon = true
	sound_button.focus_mode = Control.FOCUS_NONE
	sound_button.tooltip_text = "Ton an/aus"
	sound_button.pressed.connect(sound_pressed.emit)
	foot.add_child(sound_button)
	set_muted(muted)


func set_muted(muted: bool) -> void:
	sound_button.icon = load("res://icons/%s.svg" % ("sound_off" if muted else "sound_on"))


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _menu_button(icon_name: String, text: String, sig: Signal, primary := false) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.icon = load("res://icons/%s.svg" % icon_name)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(400, 60)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_constant_override("icon_max_width", 34)
	if primary:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.3, 0.72, 0.38, 0.95)
		st.set_corner_radius_all(12)
		st.set_content_margin_all(12)
		var hov := st.duplicate()
		hov.bg_color = Color(0.38, 0.8, 0.46, 0.95)
		var dis := st.duplicate()
		dis.bg_color = Color(0.3, 0.32, 0.35, 0.8)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", hov)
		b.add_theme_stylebox_override("disabled", dis)
	b.pressed.connect(sig.emit)
	return b


func show_animated() -> void:
	visible = true
	_panel.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func hide_animated() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # schon während des Ausblendens durchlassen
	_panel.visible = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): visible = false)

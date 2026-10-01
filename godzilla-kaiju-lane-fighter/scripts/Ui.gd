class_name Ui
## Small helpers for code-built retro UI.

static func font() -> Font:
	return load("res://assets/fonts/PressStart2P.ttf")

static func label(text: String, size := 8, color := Color(0.92, 0.94, 0.96)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func button(text: String, cb: Callable, size := 10, color := Color("2dd4bf")) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", color)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.13, 0.92)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10)
	b.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate()
	sb2.bg_color = Color(0.1, 0.16, 0.2)
	b.add_theme_stylebox_override("hover", sb2)
	b.add_theme_stylebox_override("pressed", sb2)
	b.add_theme_stylebox_override("focus", sb)
	b.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		cb.call())
	return b

static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.1, 0.94)
	sb.border_color = Color("2dd4bf")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(16)
	p.add_theme_stylebox_override("panel", sb)
	return p

static func center_overlay(root: Node, items: Array) -> CanvasLayer:
	## Full-screen dark overlay with a centered vbox of controls.
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	layer.add_child(center)
	var pan := panel()
	center.add_child(pan)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	pan.add_child(box)
	for it in items:
		box.add_child(it)
	root.add_child(layer)
	return layer

static func icon(name: String, px := 48.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://assets/sprites/ui/%s.png" % name)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Row of gem icons ("+ 💎💎💎") — readable without reading numbers.
static func gem_row(count: int, prefix := "") -> Control:
	var wrap := CenterContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	wrap.add_child(row)
	if prefix != "":
		row.add_child(label(prefix, 14, Color("22d3ee")))
	if count <= 6:
		for i in count:
			row.add_child(icon("icon_gem", 30))
	else:
		row.add_child(icon("icon_gem", 30))
		row.add_child(label("x%d" % count, 14, Color("22d3ee")))
	return wrap

static func icon_button(icon_name: String, text: String, cb: Callable, color := Color("2dd4bf")) -> Control:
	var wrap := CenterContainer.new()
	var b := button("", cb, 10, color)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon(icon_name, 24))
	var l := label(text, 10, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(row)
	b.custom_minimum_size = Vector2(190, 44)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(b)
	return wrap

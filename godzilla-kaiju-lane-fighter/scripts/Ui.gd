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

class_name UiTheme
extends RefCounted
## Globales, kindgerechtes UI-Theme: runde Formen, große Schrift, große Touch-Flächen.

const INK := Color("2f3b5c")
const GREEN := Color("5fc356")
const BLUE := Color("4f8fe8")
const ORANGE := Color("ff9f1c")
const PURPLE := Color("9b59d0")
const PANEL := Color(1, 1, 1, 0.94)

static var font: Font
static var font_bold: Font
static var theme: Theme


static func get_font() -> Font:
	if font == null:
		font = load("res://art/fonts/Fredoka-SemiBold.woff2")
	return font


static func get_bold() -> Font:
	if font_bold == null:
		font_bold = load("res://art/fonts/Fredoka-Bold.woff2")
	return font_bold


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 24, border_w: int = 0,
		shadow: int = 0, margin: float = 16.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.anti_aliasing = true
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = Color(0, 0, 0, 0.22)
		s.shadow_offset = Vector2(0, shadow * 0.6)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	return s


## Wendet Farben auf einen Button an (normal/hover/pressed/disabled).
static func style_button(b: Button, bg: Color, fg: Color = Color.WHITE, radius: int = 28) -> void:
	var border := bg.darkened(0.35)
	var normal := box(bg, border, radius, 4, 6, 20)
	normal.border_width_bottom = 9
	var hover := box(bg.lightened(0.1), border, radius, 4, 6, 20)
	hover.border_width_bottom = 9
	var pressed := box(bg.darkened(0.08), border, radius, 4, 2, 20)
	pressed.border_width_bottom = 4
	pressed.content_margin_top += 5
	var disabled := box(bg.lerp(Color(0.8, 0.8, 0.8), 0.6), border.lerp(Color(0.6, 0.6, 0.6), 0.6), radius, 4, 0, 20)
	disabled.border_width_bottom = 9
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, fg)
	b.add_theme_color_override("font_disabled_color", fg.lerp(Color(0.5, 0.5, 0.5), 0.5))
	b.add_theme_color_override("font_outline_color", bg.darkened(0.45))
	b.add_theme_constant_override("outline_size", 8 if fg == Color.WHITE else 0)


## Liefert das (einmal gebaute) Theme. Jeder Bildschirm setzt es auf seinem Wurzel-Control,
## da die Theme-Vererbung an Nicht-Control-Knoten endet.
static func get_theme() -> Theme:
	if theme == null:
		build()
	return theme


static func build() -> Theme:
	ThemeDB.fallback_font = get_font()
	var th := Theme.new()
	th.default_font = get_font()
	th.default_font_size = 36
	var normal := box(Color.WHITE, INK.lightened(0.3), 26, 4, 6, 20)
	normal.border_width_bottom = 8
	th.set_stylebox("normal", "Button", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("f3f7ff")
	th.set_stylebox("hover", "Button", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("e4ecfa")
	pressed.border_width_bottom = 4
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("hover_pressed", "Button", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.9, 0.9, 0.9)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", INK)
	th.set_color("font_hover_color", "Button", INK)
	th.set_color("font_pressed_color", "Button", INK)
	th.set_color("font_focus_color", "Button", INK)
	th.set_color("font_hover_pressed_color", "Button", INK)
	th.set_color("font_disabled_color", "Button", Color(0.55, 0.57, 0.62))
	th.set_color("font_color", "Label", INK)
	th.set_constant("outline_size", "Label", 0)
	th.set_stylebox("panel", "PanelContainer", box(PANEL, INK.lightened(0.45), 30, 4, 10, 24))
	th.set_stylebox("panel", "Panel", box(PANEL, INK.lightened(0.45), 30, 4, 10, 24))
	th.set_constant("separation", "HBoxContainer", 16)
	th.set_constant("separation", "VBoxContainer", 14)
	# Schieberegler mit großem Griff
	var track := box(Color("dfe6f2"), Color(0, 0, 0, 0), 12, 0, 0, 0)
	track.content_margin_top = 10
	track.content_margin_bottom = 10
	th.set_stylebox("slider", "HSlider", track)
	var fill := box(BLUE, Color(0, 0, 0, 0), 12, 0, 0, 0)
	fill.content_margin_top = 10
	fill.content_margin_bottom = 10
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _circle_texture(56, Color.WHITE, BLUE.darkened(0.2))
	th.set_icon("grabber", "HSlider", grab)
	th.set_icon("grabber_highlight", "HSlider", grab)
	theme = th
	return th


static func _circle_texture(size: int, fill: Color, ring: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	var r := size * 0.5 - 1.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(r - d + 0.5, 0.0, 1.0)
			var col: Color = fill if d < r - 6.0 else ring
			col.a *= a
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Label-Einstellungen mit Kontur (gut lesbar auf dem Spielfeld).
static func label_settings(size: int, color: Color = INK, outline: int = 0, outline_color: Color = Color.WHITE,
		bold: bool = false) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = get_bold() if bold else get_font()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = outline_color
	return ls

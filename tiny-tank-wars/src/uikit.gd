# Small helpers to build the kid-friendly UI in code.
class_name UIKit

const COL_PANEL := Color(1, 1, 1, 0.92)
const COL_TEXT := Color(0.16, 0.2, 0.3)
const COL_PRIMARY := Color(0.30, 0.65, 0.95)
const COL_GOOD := Color(0.35, 0.75, 0.35)
const COL_WARN := Color(0.95, 0.45, 0.35)
const PLAYER_COLORS: Array[Color] = [
	Color(0.92, 0.32, 0.30), Color(0.28, 0.55, 0.92),
	Color(0.32, 0.78, 0.42), Color(0.98, 0.75, 0.20),
]
const PLAYER_SYMBOLS := ["●", "▲", "■", "★"]

static func style(col: Color, radius := 18, border_col := Color(0, 0, 0, 0.15), border := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.border_color = border_col
	sb.set_border_width_all(border)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func button(text: String, col := COL_PRIMARY, font_size := 34, min_size := Vector2(220, 76)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	b.add_theme_constant_override("outline_size", 6)
	var sb := style(col)
	b.add_theme_stylebox_override("normal", sb)
	var sbp := style(col.darkened(0.2))
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("hover", style(col.lightened(0.08)))
	b.add_theme_stylebox_override("focus", sb)
	b.pressed.connect(func() -> void: A.click())
	return b

static func label(text: String, font_size := 30, col := COL_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

static func title_label(text: String, font_size := 64) -> Label:
	var l := label(text, font_size, Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.25, 0.4, 0.9))
	l.add_theme_constant_override("outline_size", 12)
	return l

static func panel(col := COL_PANEL, radius := 24) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(col, radius))
	return p

static func circle_tex(radius: int, col: Color, outline := Color(0, 0, 0, 0.2), outline_w := 3) -> ImageTexture:
	var size := radius * 2 + 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= radius - outline_w:
				img.set_pixel(x, y, col)
			elif d <= radius:
				img.set_pixel(x, y, outline)
	return ImageTexture.create_from_image(img)

static func hslider(min_v: float, max_v: float, value: float, width := 420.0) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.value = value
	s.custom_minimum_size = Vector2(width, 72)
	_style_slider(s)
	return s

static func vslider(min_v: float, max_v: float, value: float, height := 320.0) -> VSlider:
	var s := VSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.value = value
	s.custom_minimum_size = Vector2(72, height)
	_style_slider(s)
	return s

static func _style_slider(s: Slider) -> void:
	var groove := style(Color(1, 1, 1, 0.55), 12, Color(0, 0, 0, 0.2), 2)
	groove.content_margin_left = 8
	groove.content_margin_right = 8
	groove.content_margin_top = 8
	groove.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", groove)
	var fill := style(COL_PRIMARY, 12, Color(0, 0, 0, 0.0), 0)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var grab := circle_tex(26, Color.WHITE, Color(0.2, 0.3, 0.45), 5)
	s.add_theme_icon_override("grabber", grab)
	s.add_theme_icon_override("grabber_highlight", grab)
	s.add_theme_icon_override("grabber_disabled", grab)

static func vspace(h := 16.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

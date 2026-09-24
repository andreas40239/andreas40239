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

# --- Icon drawing (used by the picture-based player select) -----------

# Geometric player symbols: 0 circle, 1 triangle, 2 square, 3 star.
static func draw_symbol(ci: CanvasItem, c: Vector2, s: float, which: int, col: Color) -> void:
	match which:
		0:
			ci.draw_circle(c, s, col)
		1:
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -s), c + Vector2(s, s * 0.8), c + Vector2(-s, s * 0.8)]), col)
		2:
			ci.draw_rect(Rect2(c - Vector2(s * 0.85, s * 0.85), Vector2(s * 1.7, s * 1.7)), col)
		_:
			var pts := PackedVector2Array()
			for i in range(10):
				var a := -PI / 2.0 + TAU * float(i) / 10.0
				var rr := s * 1.2 if i % 2 == 0 else s * 0.5
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, col)

static func _rrect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	ci.draw_style_box(sb, r)

# A small cartoon tank icon. `robot` swaps the happy face for a robot face
# with an antenna, so kids can tell players from computer opponents at a glance.
static func draw_mini_tank(ci: CanvasItem, c: Vector2, s: float, col: Color,
		robot: bool, sym: int = -1) -> void:
	# Ground shadow.
	var shadow := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		shadow.append(c + Vector2(cos(a) * 30.0 * s, 20.0 * s + sin(a) * 6.0 * s))
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.13))
	# Barrel (behind the hull).
	var pivot := c + Vector2(0, -8.0 * s)
	var dirv := Vector2(0.72, -0.69)
	ci.draw_line(pivot, pivot + dirv * 34.0 * s, Color(0.36, 0.42, 0.52), 8.0 * s)
	ci.draw_circle(pivot + dirv * 34.0 * s, 4.5 * s, Color(0.36, 0.42, 0.52))
	# Tracks + wheels.
	_rrect(ci, Rect2(c.x - 27.0 * s, c.y + 4.0 * s, 54.0 * s, 15.0 * s), 7.0 * s, Color(0.32, 0.33, 0.4))
	for i in range(4):
		ci.draw_circle(Vector2(c.x - 18.0 * s + float(i) * 12.5 * s, c.y + 11.5 * s),
				4.2 * s, Color(0.62, 0.63, 0.7))
	# Hull.
	_rrect(ci, Rect2(c.x - 25.0 * s, c.y - 6.0 * s, 50.0 * s, 13.0 * s), 6.0 * s, col)
	# Turret dome.
	var dome := PackedVector2Array()
	dome.append(pivot + Vector2(14.0 * s, 2.0 * s))
	for i in range(16):
		var a := PI * float(i) / 15.0
		dome.append(pivot + Vector2(cos(a) * 14.0 * s, -sin(a) * 14.0 * s + 2.0 * s))
	dome.append(pivot + Vector2(-14.0 * s, 2.0 * s))
	ci.draw_colored_polygon(dome, col.lightened(0.12))
	if robot:
		# Antenna with a blinking bulb.
		ci.draw_line(pivot + Vector2(-2.0 * s, -13.0 * s), pivot + Vector2(-6.0 * s, -25.0 * s),
				Color(0.45, 0.48, 0.55), 2.5 * s)
		ci.draw_circle(pivot + Vector2(-6.0 * s, -26.0 * s), 3.6 * s, Color(1.0, 0.45, 0.35))
		# Square "screen" eyes.
		for ex in [-5.5, 5.5]:
			ci.draw_rect(Rect2(pivot.x + ex * s - 3.6 * s, pivot.y - 8.0 * s,
					7.2 * s, 6.0 * s), Color(0.95, 0.98, 1.0))
			ci.draw_rect(Rect2(pivot.x + ex * s - 1.6 * s, pivot.y - 6.6 * s,
					3.2 * s, 3.2 * s), Color(0.15, 0.6, 0.8))
		# Straight robot mouth.
		ci.draw_line(pivot + Vector2(-5.0 * s, -0.5 * s), pivot + Vector2(5.0 * s, -0.5 * s),
				Color(0.25, 0.3, 0.4), 2.2 * s)
	else:
		# Happy round eyes + smile.
		for ex in [-5.5, 5.5]:
			ci.draw_circle(pivot + Vector2(ex * s, -5.0 * s), 4.3 * s, Color.WHITE)
			ci.draw_circle(pivot + Vector2((ex + 0.8) * s, -5.0 * s), 2.1 * s, Color(0.15, 0.15, 0.25))
		ci.draw_arc(pivot + Vector2(0, -2.0 * s), 4.8 * s, 0.35, PI - 0.35, 12,
				Color(0.25, 0.1, 0.1), 2.0 * s)
	# Colour-blind-friendly badge above the tank.
	if sym >= 0:
		var bc := c + Vector2(0, -34.0 * s)
		ci.draw_circle(bc, 11.0 * s, col)
		ci.draw_arc(bc, 11.0 * s, 0, TAU, 20, Color(1, 1, 1, 0.9), 2.0 * s)
		draw_symbol(ci, bc, 6.0 * s, sym, Color.WHITE)

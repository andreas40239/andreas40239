class_name UI
extends RefCounted
## Gemeinsames Aussehen der Oberfläche: Farben, Schriften, Stilboxen.

const C_PANEL := Color(0.09, 0.14, 0.19, 0.88)
const C_PANEL_SOLID := Color(0.11, 0.17, 0.23, 0.97)
const C_BTN := Color(0.17, 0.25, 0.33, 0.96)
const C_TEXT := Color("f6f3ec")
const C_DIM := Color("a9b8c4")
const C_GREEN := Color("2fb863")
const C_ORANGE := Color("f59a1f")
const C_RED := Color("e0483f")
const C_YELLOW := Color("ffd23f")
const C_BLUE := Color("3d8bd9")

static var font: Font
static var font_bold: Font
static var _icons: Dictionary = {}


static func init() -> void:
	if font != null:
		return
	font = load("res://assets/fonts/Fredoka-Medium.ttf")
	font_bold = load("res://assets/fonts/Fredoka-Bold.ttf")
	TrackModels.font = font_bold


static func icon(icon_name: String) -> Texture2D:
	if not _icons.has(icon_name):
		_icons[icon_name] = load("res://assets/ui/ic_%s.svg" % icon_name)
	return _icons[icon_name]


static func box(col: Color, radius: int = 18, shadow: int = 6, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8
	sb.anti_aliasing = true
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.28)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, 2)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	return sb


static func label(text: String, size: int = 20, col: Color = C_TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold if bold else font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel(pad: int = 14, col: Color = C_PANEL, radius: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(col, radius)
	sb.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func icon_rect(icon_name: String, size: float, col: Color = C_TEXT) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(icon_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.modulate = col
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

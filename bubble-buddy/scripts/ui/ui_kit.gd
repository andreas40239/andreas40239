class_name BBUi
extends RefCounted
## Shared UI styling: big rounded touch targets, high contrast text, friendly
## colours. Every interactive control built here is at least 120px tall, well
## above the 72px minimum in the design doc.

const CREAM := Color(0.99, 0.97, 0.91)
const INK := Color(0.16, 0.26, 0.34)
const TEAL := Color(0.16, 0.66, 0.78)
const CORAL := Color(0.98, 0.48, 0.42)
const SUN := Color(1.0, 0.78, 0.26)
const LEAF := Color(0.38, 0.74, 0.48)

const FONT_TITLE := 108
const FONT_BIG := 64
const FONT_BODY := 44
const FONT_SMALL := 34


static func rounded_style(color: Color, radius := 48, border := 0.0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	if border > 0.0:
		sb.set_border_width_all(int(border))
		sb.border_color = border_color
	sb.shadow_color = Color(0.1, 0.2, 0.3, 0.18)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 6)
	return sb


static func button(text: String, color := TEAL, min_size := Vector2(520, 140)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", FONT_BIG)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", CREAM.darkened(0.1))
	b.add_theme_stylebox_override("normal", rounded_style(color, 64))
	b.add_theme_stylebox_override("hover", rounded_style(color.lightened(0.08), 64))
	b.add_theme_stylebox_override("pressed", rounded_style(color.darkened(0.12), 64))
	b.add_theme_stylebox_override("disabled", rounded_style(color.lerp(Color.GRAY, 0.5), 64))
	b.pressed.connect(func(): Sound.play("button"))
	return b


static func icon_button(symbol: String, color := CREAM, size := 132.0) -> Button:
	var b := button(symbol, color, Vector2(size, size))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_font_size_override("font_size", int(size * 0.44))
	for state in ["normal", "hover", "pressed"]:
		var sb := rounded_style(color if state == "normal" else color.darkened(0.08), int(size * 0.5))
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		b.add_theme_stylebox_override(state, sb)
	return b


## A label. `wrap` is opt-in: an unwrapped label inside a zero-width parent would
## otherwise wrap after every character.
static func label(text: String, size := FONT_BODY, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return l


static func panel(color := CREAM, radius := 56) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", rounded_style(color, radius))
	return p


static func spacer(height := 30.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


## A wide On/Off row. Deliberately not a CheckButton: the stock switch glyph is
## tiny on a tablet and its pressed-state font colour is invisible on a light
## card, so the state is spelled out in words instead.
static func toggle(text: String, state: bool) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = state
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 132)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", FONT_BODY)
	for color_name in ["font_color", "font_pressed_color", "font_hover_color",
			"font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(color_name, INK)

	var refresh := func() -> void:
		b.text = "%s      %s" % [text, "On" if b.button_pressed else "Off"]
		var base: Color = LEAF if b.button_pressed else Color(0.80, 0.83, 0.86)
		for state_name in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state_name, rounded_style(base.lerp(CREAM, 0.55), 44))
	refresh.call()
	b.toggled.connect(func(_on: bool) -> void:
		refresh.call()
		Sound.play("button"))
	return b


## A full-screen soft veil for overlays, so what is behind stays visible and calm.
static func veil(color := Color(0.06, 0.24, 0.32, 0.55)) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r

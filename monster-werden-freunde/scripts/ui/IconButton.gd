class_name IconButton
extends Button
## Großer, runder Button mit Vektor-Icon (optional mit Text rechts daneben).

var icon_name: StringName = &"play":
	set(value):
		icon_name = value
		queue_redraw()
var icon_tint: Color = Color.WHITE:
	set(value):
		icon_tint = value
		queue_redraw()
var icon_size: float = 56.0
var _press := 0.0


static func make(icon_id: StringName, bg: Color, btn_size: Vector2 = Vector2(108, 108), label: String = "",
		fg: Color = Color.WHITE, font_size: int = 40) -> IconButton:
	var b := IconButton.new()
	b.icon_name = icon_id
	b.icon_tint = fg
	b.text = label
	b.custom_minimum_size = btn_size
	b.icon_size = minf(btn_size.y * 0.52, 64.0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	UiTheme.style_button(b, bg, fg, int(minf(btn_size.y, btn_size.x) * 0.32))
	if label != "":
		for key in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var sb := b.get_theme_stylebox(key).duplicate() as StyleBoxFlat
			sb.content_margin_left += b.icon_size + 6.0
			b.add_theme_stylebox_override(key, sb)
	b.button_down.connect(func() -> void: AudioManager.play(&"tap"))
	return b


func _draw() -> void:
	var down: float = 4.0 if is_pressed() else 0.0
	var tint: Color = icon_tint if not disabled else icon_tint.lerp(Color(0.6, 0.6, 0.6), 0.6)
	if text == "":
		Icons.draw(self, icon_name, size * 0.5 + Vector2(0, down - 3.0), icon_size, tint)
	else:
		Icons.draw(self, icon_name, Vector2(22.0 + icon_size * 0.5, size.y * 0.5 + down - 3.0), icon_size, tint)

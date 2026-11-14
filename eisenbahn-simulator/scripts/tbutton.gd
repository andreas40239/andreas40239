class_name TButton
extends Control
## Touch-Schaltfläche. Verarbeitet Berührungen direkt (nicht über emulierte Mausklicks),
## damit mehrere Finger gleichzeitig funktionieren – z. B. Fahrregler und Bremse.

signal tapped
signal pressed_down
signal released

enum Layout { ICON, VERTICAL, HORIZONTAL, TEXT }

var text := ""
var sub := ""
var icon: Texture2D
var layout: int = Layout.ICON
var color := UI.C_BTN
var text_color := UI.C_TEXT
var radius := 18
var font_size := 18
var icon_size := 34.0
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		queue_redraw()
var is_down := false

var _touch := -1


static func make(p_layout: int, p_icon: String, p_text: String, size: Vector2, p_color: Color = UI.C_BTN) -> TButton:
	var b := TButton.new()
	b.layout = p_layout
	if p_icon != "":
		b.icon = UI.icon(p_icon)
	b.text = p_text
	b.custom_minimum_size = size
	b.size = size
	b.color = p_color
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	return b


func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			if _touch == -1 and not disabled:
				_touch = t.index
				is_down = true
				pressed_down.emit()
				queue_redraw()
		elif t.index == _touch:
			_touch = -1
			is_down = false
			released.emit()
			if Rect2(Vector2.ZERO, size).grow(12).has_point(t.position):
				tapped.emit()
			queue_redraw()
		accept_event()
	elif e is InputEventScreenDrag:
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and is_down:
		_touch = -1
		is_down = false
		released.emit()


func _draw() -> void:
	var col := color
	if selected:
		col = UI.C_GREEN
	if disabled:
		col = Color(col.r * 0.6 + 0.12, col.g * 0.6 + 0.12, col.b * 0.6 + 0.12, col.a * 0.7)
	if is_down:
		col = col.darkened(0.18)
	var r := Rect2(Vector2.ZERO, size)
	if is_down:
		r.position.y += 2.0
	var sb := UI.box(col, radius, 0 if is_down else 5)
	if selected:
		sb.border_color = Color(1, 1, 1, 0.9)
		sb.set_border_width_all(3)
	draw_style_box(sb, r)
	# Glanzkante oben
	var hl := UI.box(Color(1, 1, 1, 0.07), radius, 0)
	draw_style_box(hl, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)))
	var tc := text_color
	if disabled:
		tc.a = 0.45
	var f := UI.font_bold
	match layout:
		Layout.ICON:
			if icon:
				_icon_at(r.get_center(), icon_size, tc)
		Layout.VERTICAL:
			var has_sub := sub != ""
			var iy := r.position.y + r.size.y * (0.36 if has_sub else 0.4)
			if icon:
				_icon_at(Vector2(r.get_center().x, iy), icon_size, tc)
			var ty := r.position.y + r.size.y * (0.7 if has_sub else 0.8)
			draw_string(f, Vector2(r.position.x, ty + font_size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, font_size, tc)
			if has_sub:
				var sc := Color(tc, tc.a * 0.75)
				draw_string(UI.font, Vector2(r.position.x, r.position.y + r.size.y * 0.9 + 4.0), sub, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, font_size - 4, sc)
		Layout.HORIZONTAL:
			var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var total := tw + (icon_size + 10.0 if icon else 0.0)
			var x := r.get_center().x - total * 0.5
			if icon:
				_icon_at(Vector2(x + icon_size * 0.5, r.get_center().y), icon_size, tc)
				x += icon_size + 10.0
			draw_string(f, Vector2(x, r.get_center().y + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tc)
		Layout.TEXT:
			draw_string(f, Vector2(r.position.x, r.get_center().y + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, font_size, tc)


func _icon_at(center: Vector2, sz: float, col: Color) -> void:
	draw_texture_rect(icon, Rect2(center - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, col)

class_name RichButton
extends Button
## Button mit Icon + Titel und optional Kosten (Sonne + Zahl) darunter.

var _icon: IconRect
var _title: Label
var _cost_row: HBoxContainer
var _cost_icon: IconRect
var _cost: Label


static func make(icon_id: StringName, title: String, bg: Color, btn_size: Vector2, fg: Color = Color.WHITE) -> RichButton:
	var b := RichButton.new()
	b.custom_minimum_size = btn_size
	b.focus_mode = Control.FOCUS_NONE
	UiTheme.style_button(b, bg, fg, 26)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_bottom = -8
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	b.add_child(row)
	b._icon = IconRect.make(icon_id, 56, fg)
	row.add_child(b._icon)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	b._title = Label.new()
	b._title.text = title
	b._title.label_settings = UiTheme.label_settings(32, fg, 6 if fg == Color.WHITE else 0, bg.darkened(0.45), true)
	col.add_child(b._title)
	b._cost_row = HBoxContainer.new()
	b._cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b._cost_row.add_theme_constant_override("separation", 4)
	col.add_child(b._cost_row)
	b._cost_icon = IconRect.make(&"sun", 34)
	b._cost_row.add_child(b._cost_icon)
	b._cost = Label.new()
	b._cost.label_settings = UiTheme.label_settings(30, fg, 6 if fg == Color.WHITE else 0, bg.darkened(0.45), true)
	b._cost_row.add_child(b._cost)
	b._cost_row.visible = false
	b.button_down.connect(func() -> void: AudioManager.play(&"tap"))
	return b


func set_title(t: String) -> void:
	_title.text = t


## cost < 0 blendet die Kostenzeile aus. prefix z. B. "+" beim Verkaufen.
func set_cost(cost: int, prefix: String = "") -> void:
	_cost_row.visible = cost >= 0
	_cost.text = prefix + str(cost)


func set_icon(icon_id: StringName) -> void:
	_icon.icon = icon_id

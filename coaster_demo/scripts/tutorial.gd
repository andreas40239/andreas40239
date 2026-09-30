class_name Tutorial
extends Control
## Interaktives Tutorial: Karte oben mit Text, pulsierender Rahmen um das
## gemeinte Bedienelement. Schritte mit `wait` gehen automatisch weiter, sobald
## main.gd das passende Ereignis über notify() meldet.

signal finished

## Jeder Schritt: {title, text, target: Callable -> Rect2 (optional),
## wait: String (Ereignisname, optional), accept: Callable(arg) -> bool (optional)}
var steps: Array[Dictionary] = []
var active := false

var _index := 0
var _card: PanelContainer
var _title: Label
var _text: Label
var _counter: Label
var _next_btn: Button
var _time := 0.0


func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.2, 0.3, 0.94)
	style.border_color = Color(0.45, 0.95, 0.5)
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(16)
	_card.add_theme_stylebox_override("panel", style)
	_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_card.offset_left = -330
	_card.offset_right = 330
	_card.offset_top = 124
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_card.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	_title = _label(24, Color(1, 1, 1))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_counter = _label(16, Color(0.7, 0.8, 0.9))
	head.add_child(_counter)
	_text = _label(19, Color(0.9, 0.93, 0.97))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(620, 0)
	col.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	var skip := _text_button("Beenden", Color(0.3, 0.32, 0.36))
	skip.pressed.connect(stop)
	buttons.add_child(skip)
	_next_btn = _text_button("Weiter", Color(0.3, 0.72, 0.38))
	_next_btn.pressed.connect(next)
	buttons.add_child(_next_btn)
	visible = false


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _text_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(140, 52)
	b.add_theme_font_size_override("font_size", 20)
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(10)
	st.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", st)
	return b


func start() -> void:
	active = true
	visible = true
	_show(0)


func stop() -> void:
	if not active:
		return
	active = false
	visible = false
	finished.emit()


func next() -> void:
	if _index + 1 >= steps.size():
		stop()
	else:
		_show(_index + 1)


## Von main.gd aufgerufen, wenn etwas passiert (z. B. "piece_built", Teiltyp).
func notify_event(event_name: String, arg: Variant = null) -> void:
	if not active:
		return
	var step: Dictionary = steps[_index]
	if step.get("wait", "") != event_name:
		return
	var accept: Callable = step.get("accept", Callable())
	if accept.is_valid() and not accept.call(arg):
		return
	next()


func is_over_card(pos: Vector2) -> bool:
	return active and _card.get_global_rect().has_point(pos)


func current_step() -> int:
	return _index


func _show(i: int) -> void:
	_index = i
	var step: Dictionary = steps[i]
	_title.text = step.title
	_text.text = step.text
	_counter.text = "%d / %d" % [i + 1, steps.size()]
	var last := i == steps.size() - 1
	_next_btn.text = "Fertig" if last else ("Überspringen" if step.has("wait") else "Weiter")
	queue_redraw()


func _process(delta: float) -> void:
	if active:
		_time += delta
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	var target: Callable = steps[_index].get("target", Callable())
	if not target.is_valid():
		return
	var r: Rect2 = target.call()
	if r.size == Vector2.ZERO:
		return
	r = r.grow(8.0 + 4.0 * sin(_time * 5.0))
	var a := 0.65 + 0.35 * sin(_time * 5.0)
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(0.45, 0.95, 0.5, a)
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(16)
	draw_style_box(sb, Rect2(r.position - global_position, r.size))

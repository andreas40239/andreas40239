class_name Throttle
extends Control
## Fahrregler: senkrechter Schieber. Mitte = Halt, nach oben vorwärts, nach unten rückwärts.

signal changed(value: float)

var value := 0.0                 # -1 … 1
var _touch := -1


func _init() -> void:
	custom_minimum_size = Vector2(104, 320)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_value_silent(v: float) -> void:
	value = clampf(v, -1.0, 1.0)
	queue_redraw()


func _track() -> Rect2:
	return Rect2(size.x * 0.5 - 13.0, 44.0, 26.0, size.y - 88.0)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed and _touch == -1:
			_touch = t.index
			_set_from(t.position.y)
		elif not t.pressed and t.index == _touch:
			_touch = -1
		accept_event()
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _touch:
			_set_from(d.position.y)
		accept_event()


func _set_from(y: float) -> void:
	var tr := _track()
	var k := 1.0 - clampf((y - tr.position.y) / tr.size.y, 0.0, 1.0)   # 0 unten … 1 oben
	# Mitte bei 1/3 (rückwärts hat weniger Weg als vorwärts)
	var v := 0.0
	if k >= 0.36:
		v = (k - 0.36) / 0.64
	elif k <= 0.30:
		v = -(0.30 - k) / 0.30
	v = snappedf(v, 0.05)
	if v != value:
		value = v
		changed.emit(value)
		queue_redraw()


func _y_for(v: float) -> float:
	var tr := _track()
	var k := 0.33
	if v > 0.0:
		k = 0.36 + v * 0.64
	elif v < 0.0:
		k = 0.30 + v * 0.30
	return tr.position.y + (1.0 - k) * tr.size.y


func _draw() -> void:
	draw_style_box(UI.box(UI.C_PANEL, 22), Rect2(Vector2.ZERO, size))
	var tr := _track()
	draw_style_box(UI.box(Color(0, 0, 0, 0.45), 13, 0), tr)
	var y0 := _y_for(0.0)
	var yv := _y_for(value)
	if value > 0.0:
		draw_style_box(UI.box(UI.C_GREEN, 10, 0), Rect2(tr.position.x + 4, yv, tr.size.x - 8, y0 - yv))
	elif value < 0.0:
		draw_style_box(UI.box(UI.C_ORANGE, 10, 0), Rect2(tr.position.x + 4, y0, tr.size.x - 8, yv - y0))
	# Skala
	for i in 9:
		var v := -1.0 + i * 0.25
		if v < 0.0 and i % 2 == 1:
			continue
		var y := _y_for(v)
		var wd := 10.0 if i % 2 == 0 else 6.0
		draw_line(Vector2(tr.position.x - 6 - wd, y), Vector2(tr.position.x - 6, y), Color(1, 1, 1, 0.5), 2.0)
	var f := UI.font_bold
	draw_string(f, Vector2(0, 30), "V", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, UI.C_GREEN.lightened(0.3))
	draw_string(f, Vector2(0, size.y - 14), "R", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, UI.C_ORANGE.lightened(0.2))
	draw_string(f, Vector2(tr.end.x + 8, y0 + 6), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.C_DIM)
	# Griff
	var hr := Rect2(size.x * 0.5 - 36.0, yv - 19.0, 72.0, 38.0)
	var hc := Color("e9edf1") if _touch == -1 else Color("ffffff")
	draw_style_box(UI.box(hc, 12, 6), hr)
	for i in 3:
		var ly := hr.position.y + 11.0 + i * 8.0
		draw_line(Vector2(hr.position.x + 16, ly), Vector2(hr.end.x - 16, ly), Color(0.2, 0.25, 0.3, 0.55), 2.5)

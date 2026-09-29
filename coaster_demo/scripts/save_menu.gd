class_name SaveMenu
extends Control
## Speichern/Laden-Menü mit SaveSlots.SLOT_COUNT Plätzen.
## Überschreiben und Löschen brauchen einen zweiten Tipp zur Bestätigung.

signal save_requested(slot: int)
signal load_requested(slot: int)
signal closed
signal clicked   # für den UI-Klick-Sound

const CARD_W := 210.0

var _cards: Array[Dictionary] = []
var _pending := {}          # {"slot": int, "action": String}
var _hint: Label
var _make_button: Callable  # (icon, tooltip, callback, size) -> Button


func setup(make_button: Callable) -> void:
	_make_button = make_button
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.17, 0.19, 0.97)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	# CenterContainer hält das Panel unabhängig von seiner Größe mittig
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	var title := _label("Speichern & Laden", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_make_button.call("close", "Schließen", close, 56.0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	for i in SaveSlots.SLOT_COUNT:
		row.add_child(_build_card(i))

	_hint = _label("", 18)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	col.add_child(_hint)
	visible = false


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	return l


func _build_card(i: int) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.26, 0.27, 0.3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	v.add_child(_label("Platz %d" % (i + 1), 20))

	var thumb_bg := PanelContainer.new()
	var tb := StyleBoxFlat.new()
	tb.bg_color = Color(0.12, 0.12, 0.14)
	tb.set_corner_radius_all(6)
	thumb_bg.add_theme_stylebox_override("panel", tb)
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(CARD_W, CARD_W * 9.0 / 16.0)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb_bg.add_child(thumb)
	var empty := _label("leer", 18)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.62))
	thumb_bg.add_child(empty)
	v.add_child(thumb_bg)

	var date := _label("", 16)
	var info := _label("", 15)
	info.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
	v.add_child(date)
	v.add_child(info)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var b_save: Button = _make_button.call("save", "Speichern", _on_save.bind(i), 62.0)
	var b_load: Button = _make_button.call("load", "Laden", _on_load.bind(i), 62.0)
	var b_del: Button = _make_button.call("new", "Löschen", _on_delete.bind(i), 62.0)
	for b in [b_save, b_load, b_del]:
		buttons.add_child(b)
	v.add_child(buttons)
	_cards.append({
		"thumb": thumb, "empty": empty, "date": date, "info": info,
		"save": b_save, "load": b_load, "del": b_del,
	})
	return card


func open() -> void:
	_pending = {}
	_hint.text = "Tippe auf Speichern, um die aktuelle Strecke abzulegen"
	refresh()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func refresh() -> void:
	for i in _cards.size():
		var c: Dictionary = _cards[i]
		var data := SaveSlots.read(i)
		var used := not data.is_empty()
		var tex := SaveSlots.thumbnail(i) if used else null
		c.thumb.texture = tex
		c.empty.visible = tex == null
		c.empty.text = "leer" if not used else "kein Bild"
		c.date.text = str(data.get("saved_text", "–")) if used else "–"
		if used:
			var state := "geschlossen" if data.get("closed", false) else "offen"
			c.info.text = "%d Teile · %d m · %s" % [data.pieces.size(), int(data.get("length", 0)), state]
		else:
			c.info.text = ""
		c.load.disabled = not used
		c.del.disabled = not used
		_mark(c.save, false)
		_mark(c.del, false)


func _mark(b: Button, warn: bool) -> void:
	if warn:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.55, 0.2, 0.15, 0.95)
		st.set_corner_radius_all(12)
		st.set_content_margin_all(12)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
	else:
		b.remove_theme_stylebox_override("normal")
		b.remove_theme_stylebox_override("hover")


func _confirm(slot: int, action: String, msg: String, button: Button) -> bool:
	if _pending.get("slot", -1) == slot and _pending.get("action", "") == action:
		_pending = {}
		return true
	refresh()
	_pending = {"slot": slot, "action": action}
	_mark(button, true)
	_hint.text = msg
	clicked.emit()
	return false


func _on_save(slot: int) -> void:
	if not SaveSlots.read(slot).is_empty():
		if not _confirm(slot, "save", "Platz %d ist belegt – nochmal tippen zum Überschreiben" % (slot + 1), _cards[slot].save):
			return
	_hint.text = "Gespeichert auf Platz %d" % (slot + 1)
	save_requested.emit(slot)


func _on_load(slot: int) -> void:
	_pending = {}
	load_requested.emit(slot)


func _on_delete(slot: int) -> void:
	if not _confirm(slot, "delete", "Nochmal tippen, um Platz %d zu löschen" % (slot + 1), _cards[slot].del):
		return
	SaveSlots.erase(slot)
	refresh()
	_hint.text = "Platz %d gelöscht" % (slot + 1)
	clicked.emit()

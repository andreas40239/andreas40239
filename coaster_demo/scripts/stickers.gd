class_name Stickers
extends Control
## Sticker pro Bahn: Definitionen, Prüfung nach Fahrtdaten, Sticker-Buch und
## Belohnungs-Animation. Die Sticker gehören zur Strecke und werden mit ihr gespeichert.

## id, Name (Tooltip), Bedingung (siehe earned())
const DEFS := [
	["ride", "Erste Fahrt"], ["lap", "Eine ganze Runde"], ["laps5", "5 Runden am Stück"],
	["speed50", "50 km/h"], ["speed80", "80 km/h"], ["speed100", "100 km/h"],
	["loop", "Looping gefahren"], ["corkscrew", "Korkenzieher gefahren"], ["booster", "Abgeschossen"],
	["splash", "Splash!"], ["tunnel", "Durch den Tunnel"], ["high", "Höher als 15 m"],
	["airtime", "Schwerelos"], ["backwards", "Rückwärts gerollt"],
]

## Welche Sticker eine Fahrt mit diesen Daten verdient.
## stats: max_kmh, laps, types (Array der befahrenen Teiltypen), max_height,
##        airtime (bool), backwards (bool)
static func earned(stats: Dictionary) -> Array[String]:
	var out: Array[String] = ["ride"]
	var kmh: float = stats.get("max_kmh", 0.0)
	var types: Array = stats.get("types", [])
	var laps: int = stats.get("laps", 0)
	if laps >= 1: out.append("lap")
	if laps >= 5: out.append("laps5")
	if kmh >= 50.0: out.append("speed50")
	if kmh >= 80.0: out.append("speed80")
	if kmh >= 100.0: out.append("speed100")
	var P := CoasterTrack.Piece
	if P.LOOP in types: out.append("loop")
	if P.CORKSCREW in types: out.append("corkscrew")
	if P.BOOSTER in types: out.append("booster")
	if P.SPLASH in types: out.append("splash")
	if P.TUNNEL in types: out.append("tunnel")
	if stats.get("max_height", 0.0) > 15.0: out.append("high")
	if stats.get("airtime", false): out.append("airtime")
	if stats.get("backwards", false): out.append("backwards")
	return out


static func texture(id: String) -> Texture2D:
	return load("res://stickers/%s.svg" % id)


# ------------------------------------------------------------------ UI ---

signal closed

var _book: PanelContainer
var _grid: GridContainer
var _popup: TextureRect


func setup(make_button: Callable) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Belohnung: großer Sticker, der kurz aufploppt
	_popup = TextureRect.new()
	_popup.custom_minimum_size = Vector2(160, 160)
	_popup.size = Vector2(160, 160)
	_popup.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_popup.pivot_offset = Vector2(80, 80)
	_popup.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_popup.offset_left = -80
	_popup.offset_right = 80
	_popup.offset_top = 120
	_popup.offset_bottom = 280
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.visible = false
	add_child(_popup)

	# Sticker-Buch
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.name = "Dim"
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.name = "Center"
	add_child(center)
	_book = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.16, 0.17, 0.19, 0.97)
	st.set_corner_radius_all(18)
	st.set_content_margin_all(20)
	_book.add_theme_stylebox_override("panel", st)
	center.add_child(_book)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_book.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var icon := TextureRect.new()
	icon.texture = load("res://icons/stickers.svg")
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.add_child(icon)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(make_button.call("close", "Schließen", close_book, 56.0))
	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	col.add_child(_grid)
	for d in DEFS:
		var t := TextureRect.new()
		t.texture = texture(d[0])
		t.tooltip_text = d[1]
		t.custom_minimum_size = Vector2(110, 110)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.name = d[0]
		_grid.add_child(t)
	_set_book_visible(false)


func _set_book_visible(v: bool) -> void:
	get_node("Dim").visible = v
	get_node("Center").visible = v
	mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE


func is_book_open() -> bool:
	return get_node("Center").visible


## Zeigt alle Sticker; verdiente farbig, fehlende als graue Silhouette.
func open_book(have: Array) -> void:
	for t in _grid.get_children():
		var got: bool = String(t.name) in have
		t.modulate = Color(1, 1, 1) if got else Color(0.25, 0.25, 0.28, 0.6)
	_set_book_visible(true)


func close_book() -> void:
	if is_book_open():
		_set_book_visible(false)
		closed.emit()


var _queue: Array[String] = []

## Neue Sticker nacheinander groß einblenden.
func celebrate(ids: Array) -> void:
	for id in ids:
		_queue.append(id)
	if not _popup.visible:
		_next_popup()


func _next_popup() -> void:
	if _queue.is_empty():
		_popup.visible = false
		return
	_popup.texture = texture(_queue.pop_front())
	_popup.visible = true
	_popup.scale = Vector2(0.2, 0.2)
	_popup.rotation = -0.4
	_popup.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_popup, "scale", Vector2(1.15, 1.15), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_popup, "rotation", 0.0, 0.25)
	tw.tween_property(_popup, "scale", Vector2(1, 1), 0.15)
	tw.tween_interval(1.0)
	tw.tween_property(_popup, "modulate:a", 0.0, 0.35)
	tw.tween_callback(_next_popup)

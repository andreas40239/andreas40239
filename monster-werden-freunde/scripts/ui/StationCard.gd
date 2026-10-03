class_name StationCard
extends Button
## Große Stationskarte im Bau-Menü: Bild + kurzer Name + Kosten.

var station_id: StringName
var data: StationData
var active := false:
	set(value):
		active = value
		queue_redraw()
var affordable := true:
	set(value):
		affordable = value
		queue_redraw()
var _t := 0.0
var _shake := 0.0


static func make(id: StringName) -> StationCard:
	var c := StationCard.new()
	c.station_id = id
	c.data = DataRegistry.station(id)
	c.custom_minimum_size = Vector2(196, 168)
	c.focus_mode = Control.FOCUS_NONE
	var bg := Color("fff8ec")
	UiTheme.style_button(c, bg, UiTheme.INK, 26)
	c.button_down.connect(func() -> void: AudioManager.play(&"tap"))
	return c


func shake() -> void:
	_shake = 1.0


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 2.5)
	queue_redraw()


func _draw() -> void:
	var off := Vector2(sin(_shake * 40.0) * 8.0 * _shake, 0)
	var down: float = 4.0 if is_pressed() else 0.0
	if active and affordable:
		var glow := 0.5 + 0.5 * sin(_t * 5.0)
		draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 16)), Color(1.0, 0.85, 0.2, 0.18 + 0.15 * glow))
	var art_scale := 0.62
	draw_set_transform(Vector2(size.x * 0.5, 104 + down) + off, 0.0, Vector2(art_scale, art_scale))
	StationArt.draw_station(self, station_id, _t, 0.4 if active else 0.0, 1, &"", false)
	draw_set_transform(Vector2.ZERO)
	var f := UiTheme.get_bold()
	draw_string(f, Vector2(0, 132 + down) + off, data.short_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, UiTheme.INK)
	var cost_txt := str(data.cost)
	var w := f.get_string_size(cost_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var cx := size.x * 0.5 + 16.0
	Icons.sun(self, Vector2(cx - w * 0.5 - 22, 150 + down) + off, 30)
	var col: Color = UiTheme.INK if affordable else Color("c0392b")
	draw_string(f, Vector2(cx - w * 0.5, 161 + down) + off, cost_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
	if not affordable:
		draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 14)), Color(1, 1, 1, 0.45))

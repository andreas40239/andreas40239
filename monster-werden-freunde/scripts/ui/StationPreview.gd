class_name StationPreview
extends Control
## Zeigt eine animierte Station in einem Control.

var station_id: StringName = &"keksstand"
var level := 1
var upgrade_path: StringName = &""
var art_scale := 0.8
var _t := 0.0


static func make(id: StringName, min_size: Vector2, scale_factor: float = 0.8) -> StationPreview:
	var p := StationPreview.new()
	p.station_id = id
	p.art_scale = scale_factor
	p.custom_minimum_size = min_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(size.x * 0.5, size.y - 14.0), 0.0, Vector2(art_scale, art_scale))
	StationArt.draw_station(self, station_id, _t, 0.6, level, upgrade_path)
	draw_set_transform(Vector2.ZERO)

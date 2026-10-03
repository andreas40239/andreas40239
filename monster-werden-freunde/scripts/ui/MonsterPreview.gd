class_name MonsterPreview
extends Control
## Zeigt ein animiertes Monster (z. B. auf Infokarten und dem Titelbild).

var monster_id: StringName = &"knurri":
	set(value):
		monster_id = value
		_data = DataRegistry.monster(value)
var mood := 0.0
var walking := false
var art_scale := 1.0
var show_need := false
var _t := 0.0
var _data: MonsterData


static func make(id: StringName, min_size: Vector2, monster_mood: float = 0.0, scale_factor: float = 1.0) -> MonsterPreview:
	var p := MonsterPreview.new()
	p.monster_id = id
	p.mood = monster_mood
	p.art_scale = scale_factor
	p.custom_minimum_size = min_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _ready() -> void:
	_data = DataRegistry.monster(monster_id)
	_t = randf() * 4.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _data == null:
		return
	var base := Vector2(size.x * 0.5, size.y - 8.0)
	draw_set_transform(base, 0.0, Vector2(art_scale, art_scale))
	MonsterArt.draw_monster(self, monster_id, _data.body_color, 34.0 * _data.size_scale, mood, _t, 1.0, walking)
	if show_need:
		var c := Vector2(48, -96)
		draw_circle(c, 24, Color.WHITE)
		draw_arc(c, 24, 0, TAU, 24, Needs.color_for(_data.need_type).darkened(0.2), 3.0, true)
		Icons.draw(self, Needs.icon_for(_data.need_type), c, 32)
	draw_set_transform(Vector2.ZERO)

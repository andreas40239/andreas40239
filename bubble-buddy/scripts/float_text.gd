class_name BBFloatText
extends Node2D
## Short, kind words that drift upward. No numbers-only feedback: young players
## get a word or a symbol too.

var text := "+1"
var color := Color.WHITE
var duration := 1.0
var rise := 120.0
var font_size := 54
var _t := 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	z_index = 60


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / duration
	var a: float = 1.0 - ease(k, 2.2)
	var offset := Vector2(0, -rise * ease(k, 0.4))
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var pos := offset - Vector2(width * 0.5, 0)
	draw_string(_font, pos + Vector2(3, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.1, 0.2, 0.3, a * 0.35))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.r, color.g, color.b, a))

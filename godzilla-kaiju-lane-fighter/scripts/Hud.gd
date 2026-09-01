class_name Hud
extends Control
## HP / atomic meter / score / boss bar (GDD 9.5). Bars drawn in _draw.

var player: Player
var score := 0
var boss_ratio := -1.0
var _msg := ""
var _msg_t := 0.0
var _hp_flash := 0.0
var _last_hp := -1.0
var font: Font
var score_label: Label
var msg_label: Label

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://assets/fonts/PressStart2P.ttf")
	score_label = Label.new()
	score_label.add_theme_font_override("font", font)
	score_label.add_theme_font_size_override("font_size", 8)
	score_label.add_theme_color_override("font_color", G.COL_TEXT)
	score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	score_label.add_theme_constant_override("outline_size", 2)
	score_label.anchor_left = 0.5
	score_label.anchor_right = 0.5
	score_label.position = Vector2(-60, 8)
	score_label.size = Vector2(120, 12)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(score_label)
	msg_label = Label.new()
	msg_label.add_theme_font_override("font", font)
	msg_label.add_theme_font_size_override("font_size", 12)
	msg_label.add_theme_color_override("font_color", Color("fbbf24"))
	msg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	msg_label.add_theme_constant_override("outline_size", 3)
	msg_label.anchor_left = 0.0
	msg_label.anchor_right = 1.0
	msg_label.position.y = 150
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(msg_label)

func flash_message(text: String, dur := 1.6) -> void:
	_msg = text
	_msg_t = dur
	msg_label.text = text
	msg_label.visible = true

func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			msg_label.visible = false
	score_label.text = "%06d" % score
	if is_instance_valid(player):
		if _last_hp >= 0.0 and player.hp < _last_hp:
			_hp_flash = 0.25
		_last_hp = player.hp
	_hp_flash = maxf(0.0, _hp_flash - delta)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(player):
		return
	var vs := get_viewport_rect().size
	# HP bar top-left (96x8 at 2x GDD size for readability)
	var hp_pos := Vector2(8, 10)
	if _hp_flash > 0.0:
		hp_pos += Vector2(randf_range(-2, 2), randf_range(-2, 2))
	_bar(hp_pos, Vector2(110, 9), player.hp / player.max_hp,
		Color.WHITE if _hp_flash > 0.0 else G.COL_HP)
	# Atomic meter top-right, pulses when full
	var mcol := G.COL_METER
	if player.meter >= player.max_meter * 0.95:
		var p := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.012)
		mcol = Color(G.COL_METER.r * p + (1 - p), G.COL_METER.g * p + (1 - p), 1.0)
	_bar(Vector2(vs.x - 118, 10), Vector2(110, 9), player.meter / player.max_meter, mcol)
	# Boss bar with phase marker at 60%
	if boss_ratio >= 0.0:
		var bw := 240.0
		var bpos := Vector2((vs.x - bw) * 0.5, 34)
		_bar(bpos, Vector2(bw, 11), boss_ratio, Color("dc2626"))
		var mx := bpos.x + bw * 0.6
		draw_rect(Rect2(mx, bpos.y - 1, 2, 13), Color("fbbf24"))

func _bar(pos: Vector2, size: Vector2, ratio: float, color: Color) -> void:
	draw_rect(Rect2(pos - Vector2(2, 2), size + Vector2(4, 4)), Color.BLACK)
	draw_rect(Rect2(pos, size), Color(0.15, 0.15, 0.18))
	draw_rect(Rect2(pos, Vector2(size.x * clampf(ratio, 0, 1), size.y)), color)

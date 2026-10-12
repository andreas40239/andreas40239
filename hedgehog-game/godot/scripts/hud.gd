extends CanvasLayer
## Heads-up display, built in code for the prototype: hearts, dexterity,
## nest material, season dial, hidden-eye, context prompt, toasts, fact
## cards, the hibernation fade and the results panel.

const HELP_TEXT := "Move: WASD / arrows    Look: drag mouse or Z / X    Sniff: hold Space    Roll up: hold Shift    Interact: E    Restart: R"


class HeartRow extends Control:
	var current := 3
	var maximum := 3

	func _draw() -> void:
		for i in maximum:
			var color := Color(0.92, 0.22, 0.32) if i < current else Color(0.25, 0.25, 0.25, 0.6)
			var o := Vector2(i * 46 + 22, 22)
			draw_circle(o + Vector2(-8, -5), 10, color)
			draw_circle(o + Vector2(8, -5), 10, color)
			draw_colored_polygon(PackedVector2Array([o + Vector2(-17.6, -1), o + Vector2(17.6, -1), o + Vector2(0, 17)]), color)


class EyeIcon extends Control:
	var hidden_state := false

	func _draw() -> void:
		var c := size / 2.0
		if hidden_state:
			draw_arc(c + Vector2(0, -6), 24, 0.2 * PI, 0.8 * PI, 20, Color(0.3, 0.8, 0.4), 5.0)
			for i in 4:
				var a := lerpf(0.3, 0.7, i / 3.0) * PI
				var p := c + Vector2(0, -6) + Vector2(cos(a), sin(a)) * 24
				draw_line(p, p + Vector2(cos(a), sin(a)) * 8, Color(0.3, 0.8, 0.4), 3.0)
			return
		var points := PackedVector2Array()
		for i in 32:
			var a := TAU * i / 32.0
			points.append(c + Vector2(cos(a) * 30, sin(a) * 15))
		draw_colored_polygon(points, Color(1, 1, 1))
		points.append(points[0])
		draw_polyline(points, Color(0.9, 0.3, 0.2), 3.0)
		draw_circle(c, 11, Color(0.45, 0.3, 0.15))
		draw_circle(c, 5, Color(0.05, 0.05, 0.05))


class StarRow extends Control:
	var stars := 0

	func _draw() -> void:
		for i in 3:
			var color := Color(1.0, 0.82, 0.2) if i < stars else Color(0.3, 0.3, 0.35)
			var center := Vector2(size.x / 2.0 + (i - 1) * 80, size.y / 2.0)
			var points := PackedVector2Array()
			for k in 10:
				var r := 32.0 if k % 2 == 0 else 13.0
				var a := -PI / 2.0 + k * PI / 5.0
				points.append(center + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(points, color)


var _player: Hedgehog
var _hearts: HeartRow
var _dexterity_bar: ProgressBar
var _nest_label: Label
var _season_bar: ProgressBar
var _season_label: Label
var _eye: EyeIcon
var _eye_label: Label
var _prompt: Label
var _toast: Label
var _toast_tween: Tween
var _fact_panel: PanelContainer
var _fact_title: Label
var _fact_text: Label
var _fact_queue: Array = []
var _fact_timer := 0.0
var _overlay: ColorRect
var _results: PanelContainer
var _help: Label
var _sleeping := false
var _stats_box: VBoxContainer
var _bottom_box: VBoxContainer


func _ready() -> void:
	_build()
	Game.toast.connect(show_toast)
	Game.fact_unlocked.connect(_queue_fact)


func bind(player: Hedgehog) -> void:
	_player = player
	player.health_changed.connect(_on_health_changed)
	player.dexterity_changed.connect(func(value: float) -> void: _dexterity_bar.value = value)
	player.nest_material_changed.connect(func(count: int) -> void: _nest_label.text = "Nest material: %d" % count)
	player.hidden_changed.connect(_on_hidden_changed)
	player.prompt_changed.connect(func(text: String) -> void: _prompt.text = text)
	player.caught_by_animal.connect(_flash)
	_on_health_changed(player.health, player.max_health)
	_dexterity_bar.value = player.dexterity
	_on_hidden_changed(false)


func is_showing_results() -> bool:
	return _results.visible


func set_season(progress: float) -> void:
	_season_bar.value = progress * 100.0
	if progress >= 1.0:
		_season_label.text = "Winter is here!"
	elif progress > 0.8:
		_season_label.text = "Winter is coming"
	elif progress > 0.45:
		_season_label.text = "Late autumn"
	else:
		_season_label.text = "Autumn"


func show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.8)


## criteria: Array of [description: String, achieved: bool]
func play_hibernation(stars: int, criteria: Array, stats: Dictionary) -> void:
	for control in [_help, _stats_box, _bottom_box, _fact_panel]:
		control.visible = false
	_fact_queue.clear()
	_fact_timer = 0.0
	_sleeping = true
	var tween := create_tween()
	tween.tween_property(_overlay, "color", Color(0.15, 0.25, 0.5, 0.45), 3.0)
	tween.tween_callback(show_toast.bind("Zzz... Sweet dreams. Spring is on its way."))
	tween.tween_interval(3.0)
	tween.tween_callback(_show_results.bind(stars, criteria, stats))


func _process(delta: float) -> void:
	if _fact_timer > 0.0:
		_fact_timer -= delta
		if _fact_timer <= 0.0:
			_fact_panel.visible = false
	if _fact_timer <= 0.0 and not _fact_queue.is_empty() and not _sleeping:
		var fact: Array = _fact_queue.pop_front()
		_fact_title.text = "Hedgehog fact: " + fact[0]
		_fact_text.text = fact[1]
		_fact_panel.visible = true
		_fact_timer = 8.0


func _queue_fact(title: String, text: String) -> void:
	_fact_queue.append([title, text])


func _on_health_changed(current: int, maximum: int) -> void:
	_hearts.current = current
	_hearts.maximum = maximum
	_hearts.queue_redraw()


func _on_hidden_changed(is_hidden: bool) -> void:
	_eye.hidden_state = is_hidden
	_eye.queue_redraw()
	_eye_label.text = "Hidden" if is_hidden else "Visible"


func _flash() -> void:
	_overlay.color = Color(1, 1, 1, 0.7)
	create_tween().tween_property(_overlay, "color", Color(1, 1, 1, 0), 0.6)


func _show_results(stars: int, criteria: Array, stats: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_results.add_child(box)
	box.add_child(_label("Sweet dreams, little hedgehog!", 34, HORIZONTAL_ALIGNMENT_CENTER))
	var star_row := StarRow.new()
	star_row.stars = stars
	star_row.custom_minimum_size = Vector2(320, 80)
	box.add_child(star_row)
	for entry in criteria:
		var mark := "[x] " if entry[1] else "[  ] "
		var line := _label(mark + entry[0], 20)
		line.modulate = Color(1, 1, 1) if entry[1] else Color(0.75, 0.75, 0.8)
		box.add_child(line)
	box.add_child(_label("Food eaten: %d    Times hidden: %d    Times caught: %d" % [stats.food, stats.hidden, stats.caught], 18))
	box.add_child(_label("Facts discovered: %d / %d" % [Game.unlocked_facts.size(), Game.FACTS.size()], 18))
	var again := "Tap the screen to play again" if Game.touch_mode else "Press R to play again"
	box.add_child(_label(again, 22, HORIZONTAL_ALIGNMENT_CENTER))
	_results.visible = true
	_results.modulate.a = 0.0
	create_tween().tween_property(_results, "modulate:a", 1.0, 0.8)


func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(1, 1, 1, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	# Top-left: hearts, dexterity and nest material.
	var stats_box := VBoxContainer.new()
	stats_box.position = Vector2(20, 16)
	add_child(stats_box)
	_stats_box = stats_box
	_hearts = HeartRow.new()
	_hearts.custom_minimum_size = Vector2(160, 44)
	stats_box.add_child(_hearts)
	stats_box.add_child(_label("Dexterity", 16))
	_dexterity_bar = _bar(Color(0.95, 0.65, 0.25))
	stats_box.add_child(_dexterity_bar)
	_nest_label = _label("Nest material: 0", 18)
	stats_box.add_child(_nest_label)

	# Top-right: season dial (the winter clock).
	var season_box := VBoxContainer.new()
	_place(season_box, Control.PRESET_TOP_RIGHT, Vector2(-240, 16), Vector2(220, 0))
	add_child(season_box)
	_season_label = _label("Autumn", 20, HORIZONTAL_ALIGNMENT_RIGHT)
	season_box.add_child(_season_label)
	_season_bar = _bar(Color(0.55, 0.75, 1.0))
	_season_bar.custom_minimum_size = Vector2(220, 16)
	season_box.add_child(_season_bar)

	# Bottom-centre: hidden eye and context prompt.
	var bottom := VBoxContainer.new()
	_place(bottom, Control.PRESET_CENTER_BOTTOM, Vector2(-300, -160), Vector2(600, 120))
	bottom.alignment = BoxContainer.ALIGNMENT_END
	add_child(bottom)
	_bottom_box = bottom
	_prompt = _label("", 24, HORIZONTAL_ALIGNMENT_CENTER)
	bottom.add_child(_prompt)
	_eye = EyeIcon.new()
	_eye.custom_minimum_size = Vector2(600, 40)
	bottom.add_child(_eye)
	_eye_label = _label("Visible", 16, HORIZONTAL_ALIGNMENT_CENTER)
	bottom.add_child(_eye_label)

	# Top-centre: toast messages.
	_toast = _label("", 24, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_toast, Control.PRESET_CENTER_TOP, Vector2(-400, 70), Vector2(800, 40))
	add_child(_toast)

	# Bottom-left: fact card.
	_fact_panel = PanelContainer.new()
	# Top-right, under the season dial, clear of the thumb controls.
	_place(_fact_panel, Control.PRESET_TOP_RIGHT, Vector2(-380, 80), Vector2(360, 0))
	_fact_panel.visible = false
	_fact_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_fact_panel)
	var fact_box := VBoxContainer.new()
	_fact_panel.add_child(fact_box)
	_fact_title = _label("", 20)
	_fact_title.modulate = Color(1.0, 0.85, 0.4)
	fact_box.add_child(_fact_title)
	_fact_text = _label("", 17)
	_fact_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fact_text.custom_minimum_size = Vector2(324, 0)
	fact_box.add_child(_fact_text)

	# Bottom: controls help.
	_help = _label(HELP_TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_help, Control.PRESET_CENTER_BOTTOM, Vector2(-600, -30), Vector2(1200, 24))
	_help.modulate = Color(1, 1, 1, 0.8)
	_help.visible = not Game.touch_mode
	Game.input_mode_changed.connect(func(touch: bool) -> void: _help.visible = not touch and not _sleeping)
	add_child(_help)

	# Centre: results panel (shown after hibernation).
	_results = PanelContainer.new()
	_place(_results, Control.PRESET_CENTER, Vector2(-300, -220), Vector2(600, 0))
	_results.visible = false
	_results.add_theme_stylebox_override("panel", _panel_style())
	add_child(_results)


## Anchors `control` to `preset` and places it at `offset` from that anchor.
func _place(control: Control, preset: Control.LayoutPreset, offset: Vector2, min_size: Vector2) -> void:
	control.set_anchors_preset(preset)
	control.custom_minimum_size = min_size
	control.offset_left = offset.x
	control.offset_top = offset.y
	control.offset_right = offset.x + min_size.x
	control.offset_bottom = offset.y + min_size.y


func _label(text: String, font_size: int, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.2, 0.8)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	return style


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(160, 14)
	bar.show_percentage = false
	bar.max_value = 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.45)
	background.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	return bar

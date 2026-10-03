extends Control
## Weltkarte "Sonnental" mit Levelauswahl (Level 1-5), Sternen und Schlössern.

const NODE_POS: Array[Vector2] = [Vector2(300, 760), Vector2(640, 520), Vector2(980, 740), Vector2(1310, 500), Vector2(1630, 700)]

var _content: Control


func _ready() -> void:
	theme = UiTheme.get_theme()
	var bg := MapBackground.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.anchor_left = 0.5
	_content.anchor_right = 0.5
	_content.anchor_top = 0.5
	_content.anchor_bottom = 0.5
	_content.offset_left = -960
	_content.offset_right = 960
	_content.offset_top = -540
	_content.offset_bottom = 540
	add_child(_content)
	bg.content = _content

	for i in DataRegistry.level_count():
		var n := i + 1
		var b := LevelButton.make(n)
		b.position = NODE_POS[i] - b.custom_minimum_size * 0.5
		_content.add_child(b)
		b.pressed.connect(func() -> void:
			if SaveManager.is_level_unlocked(n):
				GameState.goto_screen(&"game", {"level": n}))

	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.92), UiTheme.INK.lightened(0.45), 30, 4, 8, 28))
	HUD._anchor(header, 0.5, 0.0, 0, 26)
	add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	header.add_child(row)
	var t := Label.new()
	t.text = "Welt 1 · Sonnental"
	t.label_settings = UiTheme.label_settings(52, UiTheme.GREEN.darkened(0.25), 0, Color.WHITE, true)
	row.add_child(t)
	row.add_child(IconRect.make(&"star", 60))
	var st := Label.new()
	st.text = "%d/%d" % [SaveManager.total_stars(), DataRegistry.level_count() * 3]
	st.label_settings = UiTheme.label_settings(44, UiTheme.INK, 0, Color.WHITE, true)
	row.add_child(st)

	var back := IconButton.make(&"back", UiTheme.BLUE)
	HUD._anchor(back, 0.0, 0.0, 28, 28)
	back.pressed.connect(go_back)
	add_child(back)


func go_back() -> void:
	GameState.goto_screen(&"title")


class LevelButton extends Button:
	var number := 1
	var unlocked := true
	var stars := 0
	var _t := 0.0
	var _data: LevelData

	static func make(n: int) -> LevelButton:
		var b := LevelButton.new()
		b.number = n
		b.unlocked = SaveManager.is_level_unlocked(n)
		b.stars = SaveManager.get_stars(n)
		b._data = DataRegistry.level(n)
		b.custom_minimum_size = Vector2(180, 180)
		b.size = b.custom_minimum_size
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not b.unlocked
		var col: Color = UiTheme.ORANGE if b.unlocked and b.stars == 0 else (UiTheme.GREEN if b.unlocked else Color("b9bfcc"))
		UiTheme.style_button(b, col, Color.WHITE, 90)
		b.button_down.connect(func() -> void: AudioManager.play(&"tap"))
		return b

	func _process(delta: float) -> void:
		_t += delta
		var next := unlocked and stars == 0
		var s: float = 1.0 + (0.06 * sin(_t * 4.0) if next else 0.0)
		pivot_offset = size * 0.5
		scale = Vector2(s, s)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0, -4)
		if unlocked:
			var f := UiTheme.get_bold()
			draw_string_outline(f, Vector2(0, c.y + 30), str(number), HORIZONTAL_ALIGNMENT_CENTER, size.x, 88, 14, Color(0, 0, 0, 0.25))
			draw_string(f, Vector2(0, c.y + 30), str(number), HORIZONTAL_ALIGNMENT_CENTER, size.x, 88, Color.WHITE)
			for i in 3:
				var p: Vector2 = Vector2(size.x * 0.5 + (i - 1) * 58, size.y + 34 + (0 if i == 1 else -10))
				Icons.star(self, p, 54, Color("ffd23f") if i < stars else Color(1, 1, 1, 0.75), i >= stars)
			# Name des Levels
			var name_w := size.x + 220
			draw_string_outline(f, Vector2(-110, -18), _data.display_name, HORIZONTAL_ALIGNMENT_CENTER, name_w, 30, 10, Color.WHITE)
			draw_string(f, Vector2(-110, -18), _data.display_name, HORIZONTAL_ALIGNMENT_CENTER, name_w, 30, UiTheme.INK)
		else:
			Icons.lock(self, c, 90)


class MapBackground extends Control:
	var content: Control
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("8fd16a"))
		var o: Vector2 = content.position if content else Vector2.ZERO
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		for i in 40:
			var p := Vector2(rng.randf_range(-400, 2300), rng.randf_range(-200, 1300)) + o
			Icons.ellipse(self, p, rng.randf_range(80, 200), rng.randf_range(40, 90), Color(0.62, 0.86, 0.5, 0.4))
		# Fluss
		var river := PackedVector2Array()
		for i in 30:
			var k := i / 29.0
			river.append(o + Vector2(lerpf(-300, 2200, k), 330 + sin(k * 7.0) * 60 - k * 140))
		draw_polyline(river, Color("6cc3ef"), 70, true)
		draw_polyline(river, Color("a8e0fa"), 26, true)
		# Weg zwischen den Leveln (gepunktet)
		for i in NODE_POS.size() - 1:
			var a := NODE_POS[i] + o
			var b := NODE_POS[i + 1] + o
			var mid: Vector2 = (a + b) * 0.5 + Vector2(0, 90 if i % 2 == 0 else -90)
			var prev := a
			for k in range(1, 21):
				var tt := k / 20.0
				var p := a.lerp(mid, tt).lerp(mid.lerp(b, tt), tt)
				if k % 2 == 1:
					draw_line(prev, p, Color("f3dfb0"), 18, true)
				prev = p
		# Bäume
		for i in 26:
			var p := Vector2(rng.randf_range(-300, 2200), rng.randf_range(80, 1050)) + o
			var ok := true
			for n in NODE_POS:
				if (n + o).distance_to(p) < 190:
					ok = false
			if ok and absf(p.y - (330 + o.y)) > 90:
				_tree(p, rng.randf_range(0.7, 1.1))
		# Brücke/Teaser Welt 2
		var sign_p := o + Vector2(1770, 400)
		draw_rect(Rect2(sign_p + Vector2(-6, -10), Vector2(12, 120)), Color("8d5f3a"))
		Icons.rounded_rect(self, Rect2(sign_p + Vector2(-110, -90), Vector2(220, 90)), 16, Color("ffe7b0"))
		var f := UiTheme.get_bold()
		draw_string(f, sign_p + Vector2(-110, -52), "Welt 2", HORIZONTAL_ALIGNMENT_CENTER, 220, 32, Color("8d4a1f"))
		draw_string(f, sign_p + Vector2(-110, -16), "bald!", HORIZONTAL_ALIGNMENT_CENTER, 220, 28, Color("8d4a1f"))

	func _tree(p: Vector2, s: float) -> void:
		draw_rect(Rect2(p + Vector2(-8, -40) * s, Vector2(16, 42) * s), Color("8d5f3a"))
		draw_circle(p + Vector2(-20, -54) * s, 28 * s, Color("3f9a52"))
		draw_circle(p + Vector2(20, -54) * s, 28 * s, Color("3f9a52"))
		draw_circle(p + Vector2(0, -76) * s, 32 * s, Color("4fa64a"))

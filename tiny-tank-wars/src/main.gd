# App entry: screen flow Main Menu -> Mode Select -> Level Select -> Battle (GDD 15.3).
extends Node

var screen: Node = null

func _ready() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_show_menu()

func _clear() -> void:
	if screen and is_instance_valid(screen):
		screen.queue_free()
	screen = null

func _menu_bg() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sky := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.40, 0.72, 0.98))
	grad.set_color(1, Color(0.78, 0.93, 1.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	sky.texture = gt
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(sky)
	var hills := MenuHills.new()
	hills.set_anchors_preset(Control.PRESET_FULL_RECT)
	hills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hills)
	return root

func _center_column(root: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(box)
	return box

func _show_menu() -> void:
	_clear()
	var root := _menu_bg()
	add_child(root)
	screen = root
	var box := _center_column(root)
	var title := UIKit.title_label("TINY TANK WARS", 84)
	box.add_child(title)
	box.add_child(UIKit.label("A friendly artillery game", 28, Color(1, 1, 1, 0.9)))
	box.add_child(UIKit.vspace(30))
	var play := UIKit.button("PLAY!", UIKit.COL_GOOD, 44, Vector2(320, 110))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_show_mode_select)
	box.add_child(play)
	box.add_child(UIKit.vspace(10))
	var mute := UIKit.button("Sound: ON" if not G.settings["muted"] else "Sound: OFF",
			Color(0.5, 0.55, 0.65), 24, Vector2(220, 66))
	mute.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mute.pressed.connect(func() -> void:
		G.settings["muted"] = not G.settings["muted"]
		mute.text = "Sound: ON" if not G.settings["muted"] else "Sound: OFF"
		A.refresh_music_volume()
		G.save_game())
	box.add_child(mute)
	box.add_child(UIKit.vspace(8))
	box.add_child(UIKit.label("No ads. No internet. Just fun!", 20, Color(1, 1, 1, 0.75)))

func _show_mode_select() -> void:
	_clear()
	var root := _menu_bg()
	add_child(root)
	screen = root
	var box := _center_column(root)
	box.add_child(UIKit.title_label("Who is playing?", 56))
	box.add_child(UIKit.vspace(16))
	var labels := ["1 Player  (you vs 3 robots)", "2 Players  (+ 2 robots)",
			"3 Players  (+ 1 robot)", "4 Players  (no robots)"]
	for i in range(4):
		var b := UIKit.button(labels[i], UIKit.PLAYER_COLORS[i], 32, Vector2(560, 88))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var n := i + 1
		b.pressed.connect(func() -> void: _show_level_select(n))
		box.add_child(b)
	box.add_child(UIKit.vspace(10))
	var back := UIKit.button("Back", Color(0.55, 0.6, 0.7), 28, Vector2(180, 70))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_show_menu)
	box.add_child(back)

func _show_level_select(humans: int) -> void:
	_clear()
	var root := _menu_bg()
	add_child(root)
	screen = root
	var box := _center_column(root)
	box.add_child(UIKit.title_label("Pick a level", 56))
	box.add_child(UIKit.vspace(10))
	var cont := UIKit.button("Continue  —  Level %d" % G.unlocked_level, UIKit.COL_GOOD, 34, Vector2(480, 96))
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cont.pressed.connect(func() -> void: _start_battle(humans, G.unlocked_level))
	box.add_child(cont)
	box.add_child(UIKit.vspace(10))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 240)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for lv in range(1, G.unlocked_level + 1):
		var b := UIKit.button(str(lv), UIKit.COL_PRIMARY, 30, Vector2(100, 84))
		var target := lv
		b.pressed.connect(func() -> void: _start_battle(humans, target))
		grid.add_child(b)
	scroll.add_child(grid)
	box.add_child(scroll)
	box.add_child(UIKit.vspace(8))
	var back := UIKit.button("Back", Color(0.55, 0.6, 0.7), 28, Vector2(180, 70))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_show_mode_select)
	box.add_child(back)

func _start_battle(humans: int, level: int) -> void:
	_clear()
	var b := Battle.new()
	b.humans = humans
	b.level = level
	b.exit_to_menu.connect(_show_menu)
	b.play_level.connect(func(lv: int) -> void: _start_battle(humans, lv))
	add_child(b)
	screen = b

class MenuHills extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array()
		pts.append(Vector2(0, h))
		for i in range(25):
			var x := w * float(i) / 24.0
			pts.append(Vector2(x, h * 0.78 - sin(float(i) * 0.9) * h * 0.06))
		pts.append(Vector2(w, h))
		draw_colored_polygon(pts, Color(0.45, 0.78, 0.4))
		# Two little decorative tanks.
		for info in [[w * 0.18, Color(0.92, 0.32, 0.30), 1.0], [w * 0.8, Color(0.28, 0.55, 0.92), -1.0]]:
			var cx: float = info[0]
			var col: Color = info[1]
			var dirv: float = info[2]
			var gy := h * 0.78
			draw_circle(Vector2(cx, gy + 6), 30, Color(0, 0, 0, 0.12))
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.32, 0.33, 0.4)
			sb.set_corner_radius_all(10)
			draw_style_box(sb, Rect2(cx - 34, gy - 14, 68, 20))
			var sb2 := StyleBoxFlat.new()
			sb2.bg_color = col
			sb2.set_corner_radius_all(8)
			draw_style_box(sb2, Rect2(cx - 30, gy - 28, 60, 18))
			draw_circle(Vector2(cx, gy - 32), 17, col.lightened(0.12))
			draw_line(Vector2(cx, gy - 36), Vector2(cx + dirv * 40, gy - 62), Color(0.36, 0.42, 0.52), 10)
			for ex in [-7.0, 7.0]:
				draw_circle(Vector2(cx + ex, gy - 36), 5, Color.WHITE)
				draw_circle(Vector2(cx + ex + dirv * 1.5, gy - 36), 2.4, Color(0.15, 0.15, 0.25))
			draw_arc(Vector2(cx, gy - 30), 6, 0.4, PI - 0.4, 10, Color(0.25, 0.1, 0.1), 2)

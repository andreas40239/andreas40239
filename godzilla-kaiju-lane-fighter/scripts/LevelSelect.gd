extends Control
## Level select: picture grid of all 8 levels (lock / check / boss icons).

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	var bg := ColorRect.new()
	bg.color = Color("0d1117")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_top = 14
	root.offset_bottom = -12
	root.offset_left = 8
	root.offset_right = -8
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	root.add_child(Ui.label("PICK A LEVEL", 14, Color("2dd4bf")))
	var train_label := "TRAINING" + ("  OK" if GameState.completed.get(0, false) else "  NEW!")
	root.add_child(Ui.icon_button("icon_hand", train_label, func():
		GameState.current_level = 0
		get_tree().change_scene_to_file("res://scenes/game.tscn"), Color("facc15")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var gw := CenterContainer.new()
	gw.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gw.add_child(grid)
	root.add_child(gw)
	for lv in range(1, GameState.MAX_LEVEL + 1):
		grid.add_child(_card(lv))
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 10)
	bottom.add_child(Ui.button("<", func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), 12, Color("6b7280")))
	bottom.add_child(Ui.icon_button("icon_gem", "POWER UP x%d" % GameState.ep, func(): get_tree().change_scene_to_file("res://scenes/upgrade_screen.tscn"), Color("a855f7")))
	root.add_child(bottom)
	AudioManager.play_music("menu")

func _card(lv: int) -> Control:
	var d: Dictionary = G.LEVELS[lv]
	var unlocked: bool = lv <= GameState.unlocked_level
	var done: bool = GameState.completed.get(lv, false)
	var b := Button.new()
	b.custom_minimum_size = Vector2(164, 96)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color("2dd4bf") if unlocked else Color(0.3, 0.32, 0.36)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	var thumb := TextureRect.new()
	thumb.texture = load("res://assets/sprites/ui/thumb_%s.png" % d["theme"])
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thumb.offset_left = 3
	thumb.offset_top = 3
	thumb.offset_right = -3
	thumb.offset_bottom = -3
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		thumb.modulate = Color(0.3, 0.3, 0.35)
	b.add_child(thumb)
	var num := Ui.label(str(lv), 22, Color.WHITE)
	num.position = Vector2(8, 6)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(num)
	var name_l := Ui.label(d["name"], 6, Color.WHITE)
	name_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_l.offset_top = -16
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_l)
	var corner := ""
	if not unlocked:
		corner = "icon_lock"
	elif done:
		corner = "icon_check"
	elif d.has("boss_name"):
		corner = "icon_boss"
	if corner != "":
		var ic := Ui.icon(corner, 32)
		ic.position = Vector2(126, 6)
		ic.size = Vector2(32, 32)
		b.add_child(ic)
	if d.has("boss_name") and corner != "icon_boss" and unlocked:
		var bi := Ui.icon("icon_boss", 22)
		bi.position = Vector2(132, 42)
		bi.size = Vector2(22, 22)
		b.add_child(bi)
	if unlocked:
		b.pressed.connect(func():
			AudioManager.play_sfx("ui_click")
			GameState.current_level = lv
			get_tree().change_scene_to_file("res://scenes/story_card.tscn"))
	else:
		b.pressed.connect(func(): AudioManager.play_sfx("gz_hurt", -14.0))
	return b

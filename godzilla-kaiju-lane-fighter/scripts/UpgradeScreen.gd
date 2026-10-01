extends Control
## POWER UP screen — picture-first so little kids can use it:
## big icon per power, stars show its level, a big green ➕ spends a gem.

var tip_icon: TextureRect
var tip_label: Label
var gem_box: Control
var list: VBoxContainer
var cards := {}

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
	root.offset_left = 10
	root.offset_right = -10
	root.offset_top = 14
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	root.add_child(Ui.label("POWER UP!", 18, Color("a855f7")))
	gem_box = CenterContainer.new()
	root.add_child(gem_box)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(list)
	for id in GameState.UPGRADES:
		list.add_child(_make_card(id))
	root.add_child(_make_tip())
	var back := Ui.icon_button("icon_check", "DONE", func(): get_tree().change_scene_to_file("res://scenes/level_select.tscn"))
	root.add_child(back)
	_refresh()
	_show_tip("gem")
	AudioManager.play_music("menu")

func _card_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.95)
	sb.border_color = color
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6)
	return sb

func _make_card(id: String) -> Control:
	var u: Dictionary = GameState.UPGRADES[id]
	var pan := PanelContainer.new()
	pan.add_theme_stylebox_override("panel", _card_style(u["color"]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pan.add_child(row)
	# big tappable icon → explains the power in the tip bubble
	var icon_btn := Button.new()
	icon_btn.flat = true
	icon_btn.custom_minimum_size = Vector2(60, 60)
	icon_btn.icon = load("res://assets/sprites/ui/icon_%s.png" % u["icon"])
	icon_btn.expand_icon = true
	icon_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		_show_tip(id))
	row.add_child(icon_btn)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 6)
	var name_l := Ui.label(u["name"], 12, u["color"])
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mid.add_child(name_l)
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 2)
	for i in GameState.MAX_UPGRADE:
		stars.add_child(Ui.icon("icon_star_empty", 22))
	mid.add_child(stars)
	row.add_child(mid)
	# big green plus button (costs one gem)
	var plus := Button.new()
	plus.custom_minimum_size = Vector2(64, 60)
	plus.icon = load("res://assets/sprites/ui/icon_plus.png")
	plus.expand_icon = true
	plus.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var on := StyleBoxFlat.new()
	on.bg_color = Color("16a34a")
	on.border_color = Color("86efac")
	on.set_border_width_all(3)
	on.set_corner_radius_all(30)
	on.set_content_margin_all(12)
	var off := on.duplicate()
	off.bg_color = Color(0.22, 0.25, 0.3)
	off.border_color = Color(0.35, 0.38, 0.42)
	plus.add_theme_stylebox_override("normal", on)
	plus.add_theme_stylebox_override("hover", on)
	plus.add_theme_stylebox_override("pressed", on)
	plus.add_theme_stylebox_override("focus", on)
	plus.add_theme_stylebox_override("disabled", off)
	plus.pressed.connect(func(): _buy(id))
	row.add_child(plus)
	cards[id] = {"stars": stars, "plus": plus, "icon": icon_btn}
	return pan

func _make_tip() -> Control:
	var pan := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.08)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	pan.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pan.add_child(row)
	tip_icon = Ui.icon("icon_gem", 36)
	row.add_child(tip_icon)
	tip_label = Ui.label("", 8, Color(0.85, 0.9, 0.95))
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_label.custom_minimum_size = Vector2(0, 36)
	row.add_child(tip_label)
	return pan

func _show_tip(id: String) -> void:
	if id == "gem":
		tip_icon.texture = load("res://assets/sprites/ui/icon_gem.png")
		tip_label.text = "Win levels to get gems. Tap a picture to learn what it does!"
		return
	var u: Dictionary = GameState.UPGRADES[id]
	tip_icon.texture = load("res://assets/sprites/ui/icon_%s.png" % u["icon"])
	tip_label.text = u["tip"]

func _buy(id: String) -> void:
	if GameState.buy_upgrade(id):
		AudioManager.play_sfx("ep_gain")
		var ic: Control = cards[id]["icon"]
		ic.pivot_offset = ic.size * 0.5
		var tw := create_tween()
		tw.tween_property(ic, "scale", Vector2(1.35, 1.35), 0.08)
		tw.tween_property(ic, "scale", Vector2.ONE, 0.15)
		_show_tip(id)
	else:
		AudioManager.play_sfx("gz_hurt", -12.0)
	_refresh()

func _refresh() -> void:
	for c in gem_box.get_children():
		c.queue_free()
	if GameState.ep > 0:
		gem_box.add_child(Ui.gem_row(GameState.ep))
	else:
		gem_box.add_child(Ui.label("NO GEMS - WIN A LEVEL!", 8, Color(0.6, 0.65, 0.7)))
	for id in cards:
		var n := GameState.lvl(id)
		var stars: HBoxContainer = cards[id]["stars"]
		for i in stars.get_child_count():
			var star: TextureRect = stars.get_child(i)
			star.texture = load("res://assets/sprites/ui/icon_%s.png" % ("star" if i < n else "star_empty"))
		var plus: Button = cards[id]["plus"]
		plus.disabled = not GameState.can_buy(id)
		plus.modulate = Color(1, 1, 1) if not plus.disabled else Color(1, 1, 1, 0.5)
		plus.visible = n < GameState.MAX_UPGRADE

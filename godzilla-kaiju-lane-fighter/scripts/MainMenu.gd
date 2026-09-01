extends Control
## Title screen.

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	var bg := TextureRect.new()
	bg.texture = load("res://assets/sprites/backgrounds/volcano_sky.png")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var far := TextureRect.new()
	far.texture = load("res://assets/sprites/backgrounds/volcano_far.png")
	far.anchor_top = 1.0
	far.anchor_right = 1.0
	far.anchor_bottom = 1.0
	far.offset_top = -260
	far.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(far)
	# big godzilla sprite
	var gz := TextureRect.new()
	gz.texture = load("res://assets/sprites/characters/godzilla.png")
	# crop first frame via atlas
	var at := AtlasTexture.new()
	at.atlas = gz.texture
	at.region = Rect2(0, 0, 48, 48)
	gz.texture = at
	gz.anchor_left = 0.5
	gz.anchor_top = 1.0
	gz.anchor_right = 0.5
	gz.anchor_bottom = 1.0
	gz.offset_left = -120
	gz.offset_top = -300
	gz.offset_right = 120
	gz.offset_bottom = -60
	gz.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gz.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(gz)
	var fins := TextureRect.new()
	var at2 := AtlasTexture.new()
	at2.atlas = load("res://assets/sprites/characters/godzilla_fins.png")
	at2.region = Rect2(0, 0, 48, 48)
	fins.texture = at2
	for prop in ["anchor_left", "anchor_top", "anchor_right", "anchor_bottom", "offset_left", "offset_top", "offset_right", "offset_bottom"]:
		fins.set(prop, gz.get(prop))
	fins.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fins.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fins.modulate = G.COL_FIN
	add_child(fins)

	var box := VBoxContainer.new()
	box.anchor_right = 1.0
	box.anchor_bottom = 0.55
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var t1 := Ui.label("GODZILLA", 26, Color("2dd4bf"))
	var t2 := Ui.label("KAIJU LANE FIGHTER", 11, Color("fbbf24"))
	box.add_child(t1)
	box.add_child(t2)
	box.add_child(Ui.label(" ", 8))
	var start := Ui.button("STOMP IN", func(): get_tree().change_scene_to_file("res://scenes/level_select.tscn"), 13)
	var wrap := CenterContainer.new()
	wrap.add_child(start)
	box.add_child(wrap)
	var wrap2 := CenterContainer.new()
	wrap2.add_child(Ui.button("EVOLVE", func(): get_tree().change_scene_to_file("res://scenes/upgrade_screen.tscn"), 9, Color("a855f7")))
	box.add_child(wrap2)
	var stats := Ui.label("HI-SCORE %06d    EP %d" % [GameState.high_score, GameState.ep], 7, Color(0.7, 0.75, 0.8))
	stats.anchor_top = 1.0
	stats.anchor_bottom = 1.0
	stats.anchor_right = 1.0
	stats.offset_top = -30
	add_child(stats)
	AudioManager.play_music("menu")

func _input(event: InputEvent) -> void:
	pass

extends Control
## Hauptmenü.

var _title_font: Font
var _help: Control


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	if GameState.start_game:
		GameState.start_game = false
		get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")
		return
	_title_font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets/fonts/Creepster-Regular.ttf"):
		_title_font = load("res://assets/fonts/Creepster-Regular.ttf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	if ResourceLoader.exists("res://assets/ui/title_bg.png"):
		bg.texture = load("res://assets/ui/title_bg.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)

	var title := Label.new()
	title.text = "ZOMBIE IN ATHEN"
	title.add_theme_font_override("font", _title_font)
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", Color(0.72, 0.95, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.02))
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 7)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 50
	title.offset_bottom = 200
	add_child(title)

	var sub := Label.new()
	sub.text = "Verstecken. Schleichen. Überleben."
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(1, 0.92, 0.8))
	sub.add_theme_color_override("font_outline_color", Color.BLACK)
	sub.add_theme_constant_override("outline_size", 8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 195
	sub.offset_bottom = 235
	add_child(sub)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -200
	box.offset_right = 200
	box.offset_top = 95
	box.offset_bottom = 310
	add_child(box)
	_button(box, "Testlevel starten", _start, 34, Vector2(400, 84))
	_button(box, "So wird gespielt", _show_help, 26, Vector2(400, 58))
	var mus := _button(box, "", func(): pass, 22, Vector2(400, 48))
	mus.text = "Musik: an" if GameState.music_on else "Musik: aus"
	mus.pressed.connect(func():
		GameState.music_on = not GameState.music_on
		mus.text = "Musik: an" if GameState.music_on else "Musik: aus")

	var info := Label.new()
	info.text = "Testlevel: 1 Spieler · 3 Computerspieler · 1 Zombie      v0.1"
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.offset_top = -34
	add_child(info)
	Sfx.reset_levels()
	Sfx.start_music()
	if GameState.shots_dir != "":
		# nur für automatische Tests: Menü-Screenshot und beenden
		await get_tree().create_timer(0.6).timeout
		DirAccess.make_dir_recursive_absolute(GameState.shots_dir)
		get_viewport().get_texture().get_image().save_png(GameState.shots_dir.path_join("menu.png"))
		get_tree().quit()


func _button(box: Container, text: String, cb: Callable, fsize: int, minsize: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = minsize
	b.add_theme_font_size_override("font_size", fsize)
	b.pressed.connect(func():
		Sfx.play("ui_click", -6.0)
		cb.call())
	box.add_child(b)
	return b


func _start() -> void:
	GameState.level = GameState.TEST_LEVEL.duplicate()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _show_help() -> void:
	if _help != null:
		return
	_help = Control.new()
	_help.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_help)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_help.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	_help.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 21)
	text.add_theme_font_size_override("bold_font_size", 21)
	text.text = """[b][color=#b8f24d]Als Mensch[/color][/b]
Du hast 30 Sekunden, dann brechen Zombies durch ein Fenster oder die Tür.
• [b]Joystick links:[/b] laufen. Du rennst immer – und Rennen macht [color=#ffcc55]Lärm[/color].
• [b]Leise:[/b] langsam und lautlos gehen (an/aus).
• [b]Stillstehen[/b] (halten): Zombies sehen dich nicht – höchstens 10 Sekunden.
• [b]Verstecken / Raus:[/b] im Schrank (1 Platz), unter dem Tisch (1) oder unter dem Bett (2).
  Vorsicht: Zombies schnüffeln manchmal an Verstecken!
• Nach einem Biss ist der Zombie 3 Sekunden abgelenkt: [color=#ff8855]lauf weg![/color] Nach 3 Bissen wirst du selbst zum Zombie.

[b][color=#b8f24d]Upgrades[/color][/b] (füllen immer auch die Lebensenergie auf)
• [b]Knoblauch:[/b] 20 s stinken – Zombies halten Abstand.
• [b]Souvlaki:[/b] 20 s schneller als jeder Zombie.
• [b]Wassermelone:[/b] Button halten, Richtung ziehen, loslassen – alle Zombies rennen zur Melone.

[b][color=#ff5544]Als Zombie[/color][/b]
Du siehst alles in Rot. Menschen siehst du nur, wenn sie sich in deinem Blickfeld bewegen (gelb pulsierend)
oder Lärm machen (gelbes Oval – auch auf der Karte).
• [b]Beißen:[/b] wenn du nah genug bist (auch an Verstecken).
• [b]Rennen:[/b] 3 Sekunden Sprint, sobald ein Mensch Lärm gemacht hat.
• [b]Horchen[/b] (halten): still stehen und alle Menschen als gelbes Oval sehen.

[b]Sieg:[/b] der letzte Mensch – oder der Zombie mit den meisten Bissen.
[color=#999999]Tastatur (Test am PC): WASD, Umschalt = leise / rennen, Leertaste = stillstehen / beißen, E = verstecken, F = Melone, Q = horchen.[/color]"""
	box.add_child(text)
	_button(box, "Zurück", func():
		_help.queue_free()
		_help = null, 26, Vector2(300, 64)).size_flags_horizontal = Control.SIZE_SHRINK_CENTER

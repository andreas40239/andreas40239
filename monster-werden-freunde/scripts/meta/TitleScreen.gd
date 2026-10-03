extends Control
## Titelbildschirm mit Monster-Parade, großem "Spielen"-Knopf und Einstellungen.

var _modal: Control
var _parade: Control


func _ready() -> void:
	theme = UiTheme.get_theme()
	var bg := SceneryBackground.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_parade = Parade.new()
	_parade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_parade)

	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 0)
	HUD._anchor(center, 0.5, 0.38, 0, 0)
	add_child(center)
	center.add_child(_title("Monster", 168, Color("ffa62b")))
	center.add_child(_title("werden", 84, Color("a463f2")))
	center.add_child(_title("Freunde", 168, Color("57c84d")))
	var ribbon := PanelContainer.new()
	ribbon.add_theme_stylebox_override("panel", UiTheme.box(Color("b5764b"), Color("7a4a26"), 22, 4, 6, 26))
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sub := Label.new()
	sub.text = "Ein fröhliches Tower-Defense-Abenteuer"
	sub.label_settings = UiTheme.label_settings(36, Color.WHITE, 8, Color("7a4a26"), true)
	ribbon.add_child(sub)
	center.add_child(ribbon)

	var play := IconButton.make(&"play", UiTheme.GREEN, Vector2(460, 150), "Spielen", Color.WHITE, 60)
	play.icon_size = 70
	HUD._anchor(play, 0.5, 0.755, 0, 0)
	play.pressed.connect(func() -> void: GameState.goto_screen(&"level_select"))
	add_child(play)

	var gear := IconButton.make(&"gear", Color("7d8bb0"))
	HUD._anchor(gear, 1.0, 0.0, -28, 28)
	gear.pressed.connect(_open_settings)
	add_child(gear)

	var info := Label.new()
	info.text = "Keine Werbung · Keine Käufe · Ganz ohne Internet"
	info.label_settings = UiTheme.label_settings(24, Color(1, 1, 1, 0.95), 6, Color(0.2, 0.4, 0.6, 0.6))
	HUD._anchor(info, 0.5, 1.0, 0, -18)
	add_child(info)


func _title(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	var ls := UiTheme.label_settings(size, color, maxi(16, size / 7), Color.WHITE, true)
	ls.shadow_size = 0
	ls.shadow_color = Color(0.25, 0.2, 0.4, 0.45)
	ls.shadow_offset = Vector2(0, 10)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _open_settings() -> void:
	if _modal:
		return
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.12, 0.25, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.97), UiTheme.INK.lightened(0.45), 40, 4, 10, 36))
	HUD._anchor(panel, 0.5, 0.5, 0, 0)
	_modal.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	panel.add_child(v)
	var t := Label.new()
	t.text = "Einstellungen"
	t.label_settings = UiTheme.label_settings(58, UiTheme.BLUE, 12, Color.WHITE, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(SettingsWidgets.volume_sliders())
	var reset := IconButton.make(&"retry", Color("e8e2d4"), Vector2(520, 104), "Fortschritt löschen", UiTheme.INK, 34)
	reset.pressed.connect(func() -> void:
		if reset.text == "Wirklich löschen?":
			SaveManager.reset_progress()
			reset.text = "Gelöscht!"
		else:
			reset.text = "Wirklich löschen?")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(reset)
	var ok := IconButton.make(&"check", UiTheme.GREEN, Vector2(300, 110), "Fertig", Color.WHITE, 42)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_close_settings)
	v.add_child(ok)


func _close_settings() -> void:
	if _modal:
		_modal.queue_free()
		_modal = null


func go_back() -> void:
	if _modal:
		_close_settings()
	else:
		get_tree().quit()


class Parade extends Control:
	## Glückliche Monster spazieren unten durchs Bild.
	const KINDS: Array[StringName] = [&"knurri", &"matschi", &"troepfli", &"schlummi", &"flitzi"]
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x + 400.0
		for i in KINDS.size():
			var d := DataRegistry.monster(KINDS[i])
			var x := fmod(_t * 70.0 + i * w / KINDS.size(), w) - 200.0
			var y := size.y * 0.955
			draw_set_transform(Vector2(x, y), 0.0, Vector2(1.6, 1.6))
			MonsterArt.draw_monster(self, d.id, d.body_color, 34.0 * d.size_scale, 1.0, _t + i, 1.0, true)
			Icons.heart(self, Vector2(0, -88 - absf(sin(_t * 4.0 + i)) * 8.0), 22, Color("ff5a87"))
		draw_set_transform(Vector2.ZERO)

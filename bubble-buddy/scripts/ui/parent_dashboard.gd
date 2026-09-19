class_name BBParentDashboard
extends Control
## The grown-ups screen: playtime limit, audio, accessibility and a plain
## statement of exactly what the app does and does not do with data.

signal back_requested

const LIMIT_OPTIONS := [0, 10, 15, 20, 30]
const SPEED_OPTIONS := [0.7, 0.85, 1.0, 1.15, 1.3]

var _limit_label: Label
var _speed_label: Label


var _bg: ColorRect
var _scroll: ScrollContainer
var _col: VBoxContainer
var _back: Button


func _ready() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.93, 0.95, 0.97)
	add_child(_bg)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	_scroll.add_child(col)
	_col = col

	col.add_child(BBUi.label("For grown-ups", BBUi.FONT_TITLE, BBUi.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_playtime_card())
	col.add_child(_audio_card())
	col.add_child(_access_card())
	col.add_child(_stats_card())
	col.add_child(_privacy_card())
	col.add_child(BBUi.spacer(30))

	_back = BBUi.button("Done", BBUi.TEAL, Vector2(420, 140))
	_back.pressed.connect(func():
		SaveData.save_game()
		back_requested.emit())
	add_child(_back)

	relayout(size if size.x > 1.0 else Vector2(1080, 1920))


func relayout(v: Vector2) -> void:
	_bg.size = v
	_scroll.position = Vector2(40, 40)
	_scroll.size = Vector2(v.x - 80.0, v.y - 250.0)
	_col.custom_minimum_size = Vector2(v.x - 120.0, 0)
	_back.position = Vector2((v.x - 420.0) * 0.5, v.y - 180.0)


func _card(title: String) -> VBoxContainer:
	var panel := BBUi.panel(Color.WHITE)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	col.add_child(BBUi.label(title, BBUi.FONT_BIG, BBUi.INK))
	# The caller receives the inner column; the panel is its parent.
	col.set_meta("panel", panel)
	return col


func _wrap(col: VBoxContainer) -> Control:
	return col.get_meta("panel")


func _playtime_card() -> Control:
	var col := _card("Playtime limit")
	var note := BBUi.label("When the limit is reached, Finley gets sleepy and the game says a gentle goodnight. Nothing is lost.",
		BBUi.FONT_SMALL, BBUi.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)

	_limit_label = BBUi.label(_limit_text(), BBUi.FONT_BODY, BBUi.TEAL)
	_limit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_limit_label)

	var minus := BBUi.icon_button("-", BBUi.CREAM, 120.0)
	minus.pressed.connect(func(): _step_limit(-1))
	row.add_child(minus)
	var plus := BBUi.icon_button("+", BBUi.CREAM, 120.0)
	plus.pressed.connect(func(): _step_limit(1))
	row.add_child(plus)
	return _wrap(col)


func _limit_text() -> String:
	if SaveData.session_limit_minutes <= 0:
		return "No limit"
	return "%d minutes" % SaveData.session_limit_minutes


func _step_limit(dir: int) -> void:
	var i := LIMIT_OPTIONS.find(SaveData.session_limit_minutes)
	if i == -1:
		i = 0
	i = clampi(i + dir, 0, LIMIT_OPTIONS.size() - 1)
	SaveData.session_limit_minutes = LIMIT_OPTIONS[i]
	SaveData.apply_settings()
	_limit_label.text = _limit_text()


func _audio_card() -> Control:
	var col := _card("Sound")
	var music := BBUi.toggle("Music", SaveData.music_enabled)
	music.toggled.connect(func(on):
		SaveData.music_enabled = on
		SaveData.apply_settings()
		Sound.refresh_settings())
	col.add_child(music)

	var sfx := BBUi.toggle("Sound effects", SaveData.sfx_enabled)
	sfx.toggled.connect(func(on):
		SaveData.sfx_enabled = on
		SaveData.apply_settings())
	col.add_child(sfx)
	col.add_child(BBUi.label("Turning both off gives a completely silent game.", BBUi.FONT_SMALL, BBUi.INK))
	return _wrap(col)


func _access_card() -> Control:
	var col := _card("Accessibility")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	_speed_label = BBUi.label("Swim speed: %s" % _speed_text(), BBUi.FONT_BODY, BBUi.TEAL)
	_speed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_speed_label)
	var slower := BBUi.icon_button("-", BBUi.CREAM, 120.0)
	slower.pressed.connect(func(): _step_speed(-1))
	row.add_child(slower)
	var faster := BBUi.icon_button("+", BBUi.CREAM, 120.0)
	faster.pressed.connect(func(): _step_speed(1))
	row.add_child(faster)

	var shapes := BBUi.toggle("Extra shape cues", SaveData.shape_cues)
	shapes.toggled.connect(func(on):
		SaveData.shape_cues = on
		SaveData.apply_settings())
	col.add_child(shapes)

	var tilt := BBUi.toggle("Tilt steering", SaveData.tilt_enabled)
	tilt.toggled.connect(func(on):
		SaveData.tilt_enabled = on
		SaveData.apply_settings())
	col.add_child(tilt)
	return _wrap(col)


func _speed_text() -> String:
	var s := SaveData.scroll_speed_scale
	if s <= 0.75:
		return "Very gentle"
	elif s <= 0.9:
		return "Gentle"
	elif s <= 1.05:
		return "Normal"
	elif s <= 1.2:
		return "Brisk"
	return "Zippy"


func _step_speed(dir: int) -> void:
	var best := 0
	for i in SPEED_OPTIONS.size():
		if absf(SPEED_OPTIONS[i] - SaveData.scroll_speed_scale) < absf(SPEED_OPTIONS[best] - SaveData.scroll_speed_scale):
			best = i
	best = clampi(best + dir, 0, SPEED_OPTIONS.size() - 1)
	SaveData.scroll_speed_scale = SPEED_OPTIONS[best]
	SaveData.apply_settings()
	_speed_label.text = "Swim speed: %s" % _speed_text()


func _stats_card() -> Control:
	var col := _card("On this device")
	var minutes := int(SaveData.playtime_seconds / 60.0)
	col.add_child(BBUi.label("Total playtime: %d min" % minutes, BBUi.FONT_BODY, BBUi.INK))
	col.add_child(BBUi.label("Swims: %d" % SaveData.sessions_played, BBUi.FONT_BODY, BBUi.INK))
	col.add_child(BBUi.label("Average swim: %d sec" % int(SaveData.average_session_seconds()), BBUi.FONT_BODY, BBUi.INK))
	col.add_child(BBUi.label("Pearls collected: %d" % SaveData.pearls_lifetime, BBUi.FONT_BODY, BBUi.INK))
	col.add_child(BBUi.label("Friends rescued: %d" % _total_friends(), BBUi.FONT_BODY, BBUi.INK))
	col.add_child(BBUi.label("Stickers found: %d of %d" % [SaveData.sticker_count(), SaveData.TOTAL_STICKERS], BBUi.FONT_BODY, BBUi.INK))
	var privacy_note := BBUi.label("These numbers are stored only on this device, for you. They are never sent anywhere.",
		BBUi.FONT_SMALL, BBUi.TEAL, HORIZONTAL_ALIGNMENT_LEFT, true)
	privacy_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(privacy_note)

	var reset := BBUi.button("Erase all progress", BBUi.CORAL, Vector2(560, 130))
	reset.add_theme_font_size_override("font_size", BBUi.FONT_BODY)
	reset.pressed.connect(_confirm_reset)
	col.add_child(reset)
	return _wrap(col)


func _total_friends() -> int:
	var total := 0
	for species in SaveData.friends_rescued.keys():
		total += int(SaveData.friends_rescued[species])
	return total


func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Erase every sticker, pearl and statistic on this device?"
	dialog.title = "Erase progress"
	dialog.ok_button_text = "Erase"
	dialog.cancel_button_text = "Keep"
	add_child(dialog)
	dialog.confirmed.connect(func():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.SAVE_PATH))
		var fresh := ConfigFile.new()
		fresh.save(SaveData.SAVE_PATH)
		SaveData.pearls_lifetime = 0
		SaveData.pearls_best_run = 0
		SaveData.gates_lifetime = 0
		SaveData.gates_best_run = 0
		SaveData.golden_shells = 0
		SaveData.friends_rescued = {}
		SaveData.stickers = {}
		SaveData.zone_badges = {}
		SaveData.playtime_seconds = 0.0
		SaveData.sessions_played = 0
		SaveData.hits_taken = 0
		SaveData.quits_after_hit = 0
		SaveData.session_lengths = []
		SaveData.save_game()
		back_requested.emit())
	dialog.popup_centered()


func _privacy_card() -> Control:
	var col := _card("Privacy")
	var lines := [
		"This game works completely offline. It does not request internet access.",
		"No analytics, no advertising, no tracking, no device identifiers.",
		"No accounts, no names, no email, no social features.",
		"No in-app purchases and no advertisements of any kind.",
		"Progress is saved in a single file on this device only.",
	]
	for line in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var dot := BBUi.label("+", BBUi.FONT_BODY, BBUi.LEAF)
		row.add_child(dot)
		var text := BBUi.label(line, BBUi.FONT_SMALL, BBUi.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size = Vector2(700, 0)
		row.add_child(text)
		col.add_child(row)
	return _wrap(col)

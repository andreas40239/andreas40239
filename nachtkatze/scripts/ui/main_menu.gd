extends Node3D
## Hauptmenue (GDD Abschnitt 12): Spielen, Levelauswahl, Einstellungen.
## Levels werden nacheinander freigeschaltet, der Stand kommt aus SaveGame.

@onready var main_panel: Control = %HauptPanel
@onready var level_panel: Control = %LevelPanel
@onready var settings_panel: Control = %EinstellungenPanel
@onready var level_list: VBoxContainer = %LevelListe
@onready var music_toggle: CheckButton = %MusikSchalter
@onready var sound_toggle: CheckButton = %SoundSchalter

func _ready() -> void:
	PlayerInput.reset()
	%SpielenButton.pressed.connect(Game.continue_game)
	%LevelauswahlButton.pressed.connect(_show_levels)
	%EinstellungenButton.pressed.connect(_show_settings)
	%ZurueckVonLevels.pressed.connect(_show_main)
	%ZurueckVonEinstellungen.pressed.connect(_show_main)

	music_toggle.button_pressed = SaveGame.music_on
	sound_toggle.button_pressed = SaveGame.sound_on
	music_toggle.toggled.connect(SaveGame.set_music_on)
	sound_toggle.toggled.connect(SaveGame.set_sound_on)

	_build_level_list()
	_show_main()

func _show_main() -> void:
	main_panel.visible = true
	level_panel.visible = false
	settings_panel.visible = false

func _show_levels() -> void:
	main_panel.visible = false
	level_panel.visible = true
	settings_panel.visible = false

func _show_settings() -> void:
	main_panel.visible = false
	level_panel.visible = false
	settings_panel.visible = true

## Je Level eine Schaltflaeche; noch gesperrte Levels sind nicht anwaehlbar.
func _build_level_list() -> void:
	for child in level_list.get_children():
		child.queue_free()
	for index in Game.level_count():
		var data := Game.catalog.get_level(index)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 58)
		button.add_theme_font_size_override("font_size", 26)
		var unlocked := SaveGame.is_unlocked(index)
		var mark := " ✓" if SaveGame.is_completed(index) else ""
		button.text = (data.display_name if data != null else "Level %d" % index) + mark
		button.disabled = not unlocked
		button.pressed.connect(Game.start_level.bind(index))
		level_list.add_child(button)

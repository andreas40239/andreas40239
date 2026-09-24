extends Node3D
## Hauptmenue (GDD Abschnitt 12): Spielen, Levelauswahl, Einstellungen.
## Levels werden nacheinander freigeschaltet, der Stand kommt aus SaveGame.

@onready var main_panel: Control = %HauptPanel
@onready var level_panel: Control = %LevelPanel
@onready var settings_panel: Control = %EinstellungenPanel
@onready var level_list: GridContainer = %LevelListe
@onready var music_toggle: CheckButton = %MusikSchalter
@onready var sound_toggle: CheckButton = %SoundSchalter

func _ready() -> void:
	PlayerInput.reset()
	# Im Menue nur Musik, das Ambient gehoert zu den Levels.
	Sfx.stop_ambient()
	%SpielenButton.pressed.connect(Game.continue_game)
	%LevelauswahlButton.pressed.connect(_show_levels)
	%EinstellungenButton.pressed.connect(_show_settings)
	%ZurueckVonLevels.pressed.connect(_show_main)
	%ZurueckVonEinstellungen.pressed.connect(_show_main)

	%MusikStueckButton.pressed.connect(_next_track)
	_update_track_label()
	Music.track_changed.connect(func(_index): _update_track_label())

	music_toggle.button_pressed = SaveGame.music_on
	sound_toggle.button_pressed = SaveGame.sound_on
	music_toggle.toggled.connect(SaveGame.set_music_on)
	sound_toggle.toggled.connect(SaveGame.set_sound_on)
	%AlleLevelSchalter.button_pressed = SaveGame.all_unlocked
	%AlleLevelSchalter.toggled.connect(_on_all_unlocked_toggled)

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

## Testmodus fuer Playtests: alle Level anwaehlbar, der Fortschritt bleibt.
func _on_all_unlocked_toggled(value: bool) -> void:
	SaveGame.set_all_unlocked(value)
	_build_level_list()

## Durch die drei Stuecke schalten (GDD Abschnitt 11).
func _next_track() -> void:
	Music.next_track()

func _update_track_label() -> void:
	%MusikStueckButton.text = "♪  " + Music.track_name(Music.current_track)

## Je Level eine Schaltflaeche; noch gesperrte Levels sind nicht anwaehlbar.
func _build_level_list() -> void:
	for child in level_list.get_children():
		child.queue_free()
	for index in Game.level_count():
		var data := Game.catalog.get_level(index)
		var button := Button.new()
		button.custom_minimum_size = Vector2(330, 60)
		button.add_theme_font_size_override("font_size", 20)
		button.clip_text = true
		var unlocked := SaveGame.is_unlocked(index)
		var mark := " ✓" if SaveGame.is_completed(index) else ""
		button.text = (data.display_name if data != null else "Level %d" % index) + mark
		button.disabled = not unlocked
		button.pressed.connect(Game.start_level.bind(index))
		level_list.add_child(button)

extends Node
## Autoload "SaveGame": Levelfortschritt und Toneinstellungen (GDD Abschnitt 13).
## Gespeichert wird per ConfigFile unter user://.

signal progress_changed()
signal audio_changed()

const SAVE_PATH := "user://nachtkatze.cfg"

var completed_levels: Array[int] = []
var music_on: bool = true
var sound_on: bool = true
## Gewaehltes Hintergrundstueck (Index in MusicPlayer.TRACKS).
var music_track: int = 0
## Testmodus: alle Level anwaehlbar (Einstellungen, fuer Playtests).
var all_unlocked: bool = false

func _ready() -> void:
	load_game()
	apply_audio()

# --- Fortschritt ------------------------------------------------------------

func is_completed(index: int) -> bool:
	return completed_levels.has(index)

## Levels werden nacheinander freigeschaltet (GDD Abschnitt 12).
func is_unlocked(index: int) -> bool:
	return all_unlocked or index <= 0 or is_completed(index - 1)

func set_all_unlocked(value: bool) -> void:
	all_unlocked = value
	save_game()
	progress_changed.emit()

func mark_completed(index: int) -> void:
	if index < 0 or is_completed(index):
		return
	completed_levels.append(index)
	completed_levels.sort()
	save_game()
	progress_changed.emit()

## Erstes noch nicht geschafftes Level - "Spielen" setzt hier fort.
func next_open_level(level_count: int) -> int:
	for index in level_count:
		if not is_completed(index):
			return index
	return maxi(level_count - 1, 0)

func reset_progress() -> void:
	completed_levels.clear()
	save_game()
	progress_changed.emit()

# --- Ton --------------------------------------------------------------------

func set_music_on(value: bool) -> void:
	music_on = value
	apply_audio()
	save_game()
	audio_changed.emit()

func set_music_track(index: int) -> void:
	music_track = index
	save_game()
	audio_changed.emit()

func set_sound_on(value: bool) -> void:
	sound_on = value
	apply_audio()
	save_game()
	audio_changed.emit()

## Schaltet die Busse stumm; das Ambient haengt am Bus "SFX".
func apply_audio() -> void:
	_mute_bus("Music", not music_on)
	_mute_bus("SFX", not sound_on)

func _mute_bus(bus_name: String, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_mute(index, muted)

# --- Datei ------------------------------------------------------------------

func load_game() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	completed_levels.clear()
	for value in config.get_value("fortschritt", "abgeschlossen", []):
		completed_levels.append(int(value))
	music_on = bool(config.get_value("audio", "musik", true))
	sound_on = bool(config.get_value("audio", "sound", true))
	music_track = int(config.get_value("audio", "stueck", 0))
	all_unlocked = bool(config.get_value("fortschritt", "alle_offen", false))

func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("fortschritt", "abgeschlossen", completed_levels)
	config.set_value("fortschritt", "alle_offen", all_unlocked)
	config.set_value("audio", "musik", music_on)
	config.set_value("audio", "sound", sound_on)
	config.set_value("audio", "stueck", music_track)
	config.save(SAVE_PATH)

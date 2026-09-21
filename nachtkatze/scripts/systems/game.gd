extends Node
## Autoload "Game": haelt den Levelzustand und steuert Neustart, Levelwechsel
## und die Wege ins Menue (GDD Abschnitt 3 und 12).

signal level_started(data: LevelData)
signal level_completed(data: LevelData)
signal level_failed(data: LevelData)

## Verzoegerung, bevor nach einem Game Over automatisch neu gestartet wird.
const AUTO_RESTART_DELAY := 1.6

const CATALOG_PATH := "res://resources/levels/level_catalog.tres"
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var catalog: LevelCatalog = null
var current_level: Node = null
var current_level_data: LevelData = null
## Platz im Katalog; -1 bei Levels ausserhalb des Katalogs (z. B. Tests).
var current_index: int = -1
var is_level_finished: bool = false

var _current_level_path: String = ""

func _ready() -> void:
	catalog = load(CATALOG_PATH) as LevelCatalog

func register_level(level: Node, data: LevelData) -> void:
	current_level = level
	current_level_data = data
	is_level_finished = false
	_current_level_path = level.scene_file_path
	current_index = catalog.index_of_scene(_current_level_path) if catalog != null else -1
	get_tree().paused = false
	level_started.emit(data)

func complete_level() -> void:
	if is_level_finished:
		return
	is_level_finished = true
	if current_index >= 0:
		SaveGame.mark_completed(current_index)
	level_completed.emit(current_level_data)

func fail_level() -> void:
	if is_level_finished:
		return
	is_level_finished = true
	level_failed.emit(current_level_data)

func restart_level() -> void:
	get_tree().paused = false
	is_level_finished = false
	if _current_level_path.is_empty():
		get_tree().reload_current_scene.call_deferred()
	else:
		get_tree().change_scene_to_file.call_deferred(_current_level_path)

# --- Levelwechsel -----------------------------------------------------------

func level_count() -> int:
	return catalog.size() if catalog != null else 0

func has_next_level() -> bool:
	return current_index >= 0 and current_index + 1 < level_count()

func load_next_level() -> void:
	if has_next_level():
		start_level(current_index + 1)
	else:
		open_menu()

## Startet ein Level aus dem Katalog.
func start_level(index: int) -> void:
	var path := catalog.get_scene_path(index) if catalog != null else ""
	if path.is_empty():
		open_menu()
		return
	get_tree().paused = false
	is_level_finished = false
	get_tree().change_scene_to_file.call_deferred(path)

## "Spielen" im Hauptmenue: weiter beim naechsten ungeloesten Level.
func continue_game() -> void:
	start_level(SaveGame.next_open_level(level_count()))

func open_menu() -> void:
	get_tree().paused = false
	is_level_finished = false
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)

func open_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)

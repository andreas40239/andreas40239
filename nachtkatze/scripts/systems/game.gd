extends Node
## Autoload "Game": haelt den Levelzustand und steuert Neustart / Levelwechsel
## (GDD Abschnitt 3 und 12). Bewusst schlank - die Darstellung uebernimmt das HUD.

signal level_started(data: LevelData)
signal level_completed(data: LevelData)
signal level_failed(data: LevelData)

## Verzoegerung, bevor nach einem Game Over automatisch neu gestartet wird.
const AUTO_RESTART_DELAY := 1.6

var current_level: Node = null
var current_level_data: LevelData = null
var is_level_finished: bool = false

var _current_level_path: String = ""

func register_level(level: Node, data: LevelData) -> void:
	current_level = level
	current_level_data = data
	is_level_finished = false
	_current_level_path = level.scene_file_path
	get_tree().paused = false
	level_started.emit(data)

func complete_level() -> void:
	if is_level_finished:
		return
	is_level_finished = true
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

func has_next_level() -> bool:
	return current_level_data != null \
		and not current_level_data.next_level_path.is_empty() \
		and ResourceLoader.exists(current_level_data.next_level_path)

func load_next_level() -> void:
	get_tree().paused = false
	if has_next_level():
		get_tree().change_scene_to_file.call_deferred(current_level_data.next_level_path)
	else:
		restart_level()

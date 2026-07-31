extends Node

const SAVE_PATH := "user://savegame.json"

func save_game() -> void:
	var data := {
		"growth_level": GameManager.growth_level,
		"satiety": GameManager.satiety,
		"run_complete": GameManager.run_complete,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	GameManager.growth_level = parsed.get("growth_level", 1)
	GameManager.satiety = parsed.get("satiety", 0.0)
	GameManager.run_complete = parsed.get("run_complete", false)

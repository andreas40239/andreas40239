extends Node

const SAVE_PATH := "user://savegame.json"

func save_game() -> void:
	var data := {
		"growth_level": GameManager.growth_level,
		"satiety": GameManager.satiety,
		"run_complete": GameManager.run_complete,
		"defense_level": GameManager.defense_level,
		"attack_level": GameManager.attack_level,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> void:
	# Always start from a clean slate before applying whatever the save file
	# has, so any field a future save format forgets to write still ends up
	# at its proper default instead of carrying over stale in-memory state
	# from a previous run (this is what let defense_level/attack_level
	# survive a restart while growth_level correctly went back to 1).
	GameManager.reset_progress()
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
	GameManager.defense_level = parsed.get("defense_level", 0)
	GameManager.attack_level = parsed.get("attack_level", 0)

extends Resource
class_name LevelCatalog
## Reihenfolge der Levels (GDD Abschnitt 6 und 12).
## Bestimmt Levelauswahl, Freischaltung und was nach einem Level kommt.

@export var levels: Array[LevelData] = []

func size() -> int:
	return levels.size()

func get_level(index: int) -> LevelData:
	if index < 0 or index >= levels.size():
		return null
	return levels[index]

func get_scene_path(index: int) -> String:
	var data := get_level(index)
	return data.scene_path if data != null else ""

func index_of_scene(scene_path: String) -> int:
	for index in levels.size():
		if levels[index] != null and levels[index].scene_path == scene_path:
			return index
	return -1

extends Node
## Lokales Speichern in user://save.json (atomisch über eine temporäre Datei).
## Keine personenbezogenen Daten, kein Netzwerk.

const SAVE_PATH := "user://save.json"
const TMP_PATH := "user://save.json.tmp"
const VERSION := 1

var data: Dictionary = {}


func _ready() -> void:
	load_game()


func _default_data() -> Dictionary:
	return {
		"version": VERSION,
		"stars": {},
		"settings": {"music": 0.7, "sfx": 0.9},
		"seen_intro": [],
	}


func load_game() -> void:
	data = _default_data()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for key in parsed:
			data[key] = parsed[key]
	if not data.get("stars") is Dictionary:
		data["stars"] = {}
	if not data.get("settings") is Dictionary:
		data["settings"] = {"music": 0.7, "sfx": 0.9}


func save_game() -> bool:
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Speichern nicht möglich: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	return dir.rename(TMP_PATH.get_file(), SAVE_PATH.get_file()) == OK


func get_stars(level_number: int) -> int:
	if data.is_empty():
		load_game()
	return int(data["stars"].get(str(level_number), 0))


func total_stars() -> int:
	var n := 0
	for k in data["stars"]:
		n += int(data["stars"][k])
	return n


func is_level_unlocked(level_number: int) -> bool:
	return level_number <= 1 or get_stars(level_number - 1) > 0


## 1x/2x wird nach Tutorial-Level 2 freigeschaltet (GDD 2.3).
func is_speed_unlocked() -> bool:
	return get_stars(2) > 0


## Speichert das Ergebnis; nur Verbesserungen überschreiben. Gibt true zurück, wenn neu freigeschaltet.
func record_result(level_number: int, stars: int) -> bool:
	var was_unlocked := is_level_unlocked(level_number + 1)
	if stars > get_stars(level_number):
		data["stars"][str(level_number)] = stars
	save_game()
	return not was_unlocked and is_level_unlocked(level_number + 1)


func get_setting(key: String, default_value: Variant) -> Variant:
	if data.is_empty():
		load_game()
	return data["settings"].get(key, default_value)


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save_game()


func has_seen_intro(monster_id: StringName) -> bool:
	return data.get("seen_intro", []).has(String(monster_id))


func mark_intro_seen(monster_id: StringName) -> void:
	var seen: Array = data.get("seen_intro", [])
	if not seen.has(String(monster_id)):
		seen.append(String(monster_id))
	data["seen_intro"] = seen
	save_game()


func reset_progress() -> void:
	var settings: Dictionary = data.get("settings", {})
	data = _default_data()
	data["settings"] = settings
	save_game()

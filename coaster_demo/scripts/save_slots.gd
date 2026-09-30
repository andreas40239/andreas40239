class_name SaveSlots
extends RefCounted
## Speicherplätze im Benutzerverzeichnis: slot_N.json (Strecke + Zeitstempel)
## und slot_N.png (Vorschaubild).

const SLOT_COUNT := 5
const DIR := "user://slots"
const VERSION := 1


static func _path(slot: int, ext: String) -> String:
	return "%s/slot_%d.%s" % [DIR, slot + 1, ext]


## Liefert {} für einen leeren Platz, sonst die gespeicherten Daten.
static func read(slot: int) -> Dictionary:
	var f := FileAccess.open(_path(slot, "json"), FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("pieces"):
		return {}
	return data


static func write(slot: int, types: Array, length_m: float, closed: bool, thumb: Image) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(DIR)
	var now := Time.get_datetime_dict_from_system()
	var data := {
		"version": VERSION,
		"pieces": types,
		"length": snappedf(length_m, 0.1),
		"closed": closed,
		"saved_unix": Time.get_unix_time_from_system(),
		"saved_text": "%02d.%02d.%04d  %02d:%02d" % [now.day, now.month, now.year, now.hour, now.minute],
	}
	var f := FileAccess.open(_path(slot, "json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if thumb != null and not thumb.is_empty():
		thumb.save_png(_path(slot, "png"))
	else:
		DirAccess.remove_absolute(_path(slot, "png"))
	return data


static func erase(slot: int) -> void:
	DirAccess.remove_absolute(_path(slot, "json"))
	DirAccess.remove_absolute(_path(slot, "png"))


static func thumbnail(slot: int) -> Texture2D:
	if not FileAccess.file_exists(_path(slot, "png")):
		return null
	var img := Image.load_from_file(_path(slot, "png"))
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------- Autosave ---
# Die zuletzt bearbeitete Strecke, für „Weiterbauen“ auf dem Startbildschirm.

const AUTOSAVE_PATH := "user://autosave.json"


static func write_autosave(types: Array) -> void:
	var f := FileAccess.open(AUTOSAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"version": VERSION, "pieces": types}))


static func read_autosave() -> Array:
	var f := FileAccess.open(AUTOSAVE_PATH, FileAccess.READ)
	if f == null:
		return []
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("pieces")) != TYPE_ARRAY:
		return []
	return data.pieces

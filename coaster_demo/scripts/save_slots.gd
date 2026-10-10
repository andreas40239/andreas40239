class_name SaveSlots
extends RefCounted
## Speicherplätze pro Spielerprofil (Tier-Symbol):
##   user://profiles/<tier>/slot_N.json (+ .png Vorschaubild)
##   user://profiles/<tier>/slot_N.bak.json (+ .bak.png) – Sicherung der vorherigen Version
##   user://profiles/<tier>/autosave.json – „Weiterbauen“

const SLOT_COUNT := 5
const VERSION := 2
const ROOT := "user://profiles"
const LEGACY_DIR := "user://slots"
const LEGACY_AUTOSAVE := "user://autosave.json"
## Spielerprofile: id, Icon, Name (der Name ist nur für Tooltips – Kinder erkennen das Tier)
const PROFILES := [
	["fox", "animal_fox", "Fuchs"], ["bear", "animal_bear", "Bär"], ["rabbit", "animal_rabbit", "Hase"],
	["cat", "animal_cat", "Katze"], ["frog", "animal_frog", "Frosch"], ["owl", "animal_owl", "Eule"],
]

static var profile := "fox"


static func profile_icon(id: String) -> String:
	for p in PROFILES:
		if p[0] == id:
			return p[1]
	return PROFILES[0][1]


static func _dir() -> String:
	return "%s/%s" % [ROOT, profile]


static func _path(slot: int, ext: String, backup := false) -> String:
	return "%s/slot_%d%s.%s" % [_dir(), slot + 1, ".bak" if backup else "", ext]


## Alte Spielstände (vor den Profilen) einmalig ins erste Profil übernehmen.
static func migrate_legacy() -> void:
	if DirAccess.dir_exists_absolute(ROOT):
		return
	var target := "%s/%s" % [ROOT, PROFILES[0][0]]
	DirAccess.make_dir_recursive_absolute(target)
	if DirAccess.dir_exists_absolute(LEGACY_DIR):
		for f in DirAccess.get_files_at(LEGACY_DIR):
			DirAccess.rename_absolute(LEGACY_DIR.path_join(f), target.path_join(f))
	if FileAccess.file_exists(LEGACY_AUTOSAVE):
		DirAccess.rename_absolute(LEGACY_AUTOSAVE, target.path_join("autosave.json"))


static func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("pieces")) != TYPE_ARRAY:
		return {}
	return data


## Liefert {} für einen leeren Platz, sonst die gespeicherten Daten.
static func read(slot: int) -> Dictionary:
	return _read_json(_path(slot, "json"))


static func has_backup(slot: int) -> bool:
	return FileAccess.file_exists(_path(slot, "json", true))


## Verschiebt die aktuelle Version in die Sicherung (überschreibt eine ältere Sicherung).
static func _backup(slot: int) -> void:
	if not FileAccess.file_exists(_path(slot, "json")):
		return
	for ext in ["json", "png"]:
		DirAccess.remove_absolute(_path(slot, ext, true))
		if FileAccess.file_exists(_path(slot, ext)):
			DirAccess.rename_absolute(_path(slot, ext), _path(slot, ext, true))


static func write(slot: int, types: Array, length_m: float, closed: bool, thumb: Image,
		stickers: Array = []) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(_dir())
	_backup(slot)
	var now := Time.get_datetime_dict_from_system()
	var data := {
		"version": VERSION,
		"pieces": types,
		"stickers": stickers,
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
	return data


## Löschen legt die Strecke ebenfalls in die Sicherung – sie lässt sich zurückholen.
static func erase(slot: int) -> void:
	_backup(slot)


## Tauscht aktuelle Version und Sicherung (ein zweites Mal tauscht zurück).
static func restore_backup(slot: int) -> bool:
	if not has_backup(slot):
		return false
	var tmp := "%s/slot_%d.tmp" % [_dir(), slot + 1]
	for ext in ["json", "png"]:
		var cur := _path(slot, ext)
		var bak := _path(slot, ext, true)
		var had_cur := FileAccess.file_exists(cur)
		var had_bak := FileAccess.file_exists(bak)
		if had_cur:
			DirAccess.rename_absolute(cur, tmp)
		if had_bak:
			DirAccess.rename_absolute(bak, cur)
		if had_cur:
			DirAccess.rename_absolute(tmp, bak)
	return true


## Nur für Tests/Aufräumen: Platz und Sicherung endgültig entfernen.
static func purge(slot: int) -> void:
	for ext in ["json", "png"]:
		DirAccess.remove_absolute(_path(slot, ext))
		DirAccess.remove_absolute(_path(slot, ext, true))


static func thumbnail(slot: int) -> Texture2D:
	if not FileAccess.file_exists(_path(slot, "png")):
		return null
	var img := Image.load_from_file(_path(slot, "png"))
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------- Autosave ---
# Die zuletzt bearbeitete Strecke des Profils, für „Weiterbauen“.

static func write_autosave(types: Array, stickers: Array = []) -> void:
	DirAccess.make_dir_recursive_absolute(_dir())
	var f := FileAccess.open(_dir().path_join("autosave.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"version": VERSION, "pieces": types, "stickers": stickers}))


## {"pieces": [...], "stickers": [...]} oder {} wenn nichts gesichert ist.
static func read_autosave() -> Dictionary:
	return _read_json(_dir().path_join("autosave.json"))

class_name Save
extends RefCounted
## Spielstand: Sterne je Level, Einstellungen und die gebauten Strecken.

const PATH := "user://gleisfrei.cfg"

static var stars: Array[int] = []
static var music_on := true
static var sfx_on := true
static var layouts: Dictionary = {}


static func load_all() -> void:
	stars.clear()
	for i in Levels.count():
		stars.append(0)
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for i in Levels.count():
		stars[i] = int(cf.get_value("progress", "stars_%d" % i, 0))
	music_on = bool(cf.get_value("settings", "music", true))
	sfx_on = bool(cf.get_value("settings", "sfx", true))
	var l: Variant = cf.get_value("layouts", "data", {})
	if l is Dictionary:
		layouts = l


static func store() -> void:
	var cf := ConfigFile.new()
	for i in stars.size():
		cf.set_value("progress", "stars_%d" % i, stars[i])
	cf.set_value("settings", "music", music_on)
	cf.set_value("settings", "sfx", sfx_on)
	cf.set_value("layouts", "data", layouts)
	cf.save(PATH)


static func unlocked(level: int) -> bool:
	return level == 0 or stars[level - 1] > 0


static func set_layout(level: int, data: Array) -> void:
	layouts[str(level)] = data


static func get_layout(level: int) -> Array:
	var v: Variant = layouts.get(str(level), [])
	return v if v is Array else []

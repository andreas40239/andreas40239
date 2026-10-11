extends RefCounted
## Speichert, welche Level geschafft sind, und die Ton-Einstellung.

const PATH := "user://fortschritt.cfg"


static func _load() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load(PATH)
	return cf


static func is_done(level: int) -> bool:
	return bool(_load().get_value("level", str(level), false))


static func mark_done(level: int) -> void:
	var cf := _load()
	cf.set_value("level", str(level), true)
	cf.save(PATH)


static func sound_on() -> bool:
	return bool(_load().get_value("settings", "sound", true))


static func set_sound(on: bool) -> void:
	var cf := _load()
	cf.set_value("settings", "sound", on)
	cf.save(PATH)
	AudioServer.set_bus_mute(0, not on)

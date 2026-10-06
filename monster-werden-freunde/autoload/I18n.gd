extends Node
## Sprachauswahl (Deutsch, Englisch, Griechisch) über den Godot-TranslationServer.
## Quelltexte sind Deutsch; Übersetzungen stehen in scripts/i18n/Strings.gd.

signal language_changed(lang: String)

const LANGUAGES: Array[String] = ["de", "en", "el"]


func _ready() -> void:
	_register()
	set_language(String(SaveManager.get_setting("lang", "de")), false)


func _register() -> void:
	# Schlüssel mit Kontext ("station|Flügel") brauchen auch eine deutsche Übersetzung.
	var de := Translation.new()
	de.locale = "de"
	for i in 2:
		var t := Translation.new()
		t.locale = LANGUAGES[i + 1]
		for key in Strings.TABLE:
			t.add_message(key, Strings.TABLE[key][i])
			var bar := String(key).find("|")
			if bar > 0 and i == 0:
				de.add_message(key, String(key).substr(bar + 1))
		TranslationServer.add_translation(t)
	TranslationServer.add_translation(de)


func set_language(lang: String, save: bool = true) -> void:
	if not LANGUAGES.has(lang):
		lang = "de"
	TranslationServer.set_locale(lang)
	if save:
		SaveManager.set_setting("lang", lang)
	language_changed.emit(lang)


func current() -> String:
	return TranslationServer.get_locale().substr(0, 2)

class_name SettingsWidgets
extends RefCounted
## Gemeinsame Einstellungs-Elemente (getrennte Musik- und Geräusch-Regler, GDD 10).


static func volume_sliders() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.add_child(_slider_row(&"note", "Musik", "music", 0.7, func(x: float) -> void: AudioManager.set_music_volume(x)))
	v.add_child(_slider_row(&"bubble", "Geräusche", "sfx", 0.9, func(x: float) -> void: AudioManager.set_sfx_volume(x)))
	return v


static func _slider_row(icon: StringName, title: String, key: String, def: float, apply: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(IconRect.make(icon, 58))
	var l := Label.new()
	l.text = title
	l.custom_minimum_size.x = 190
	l.label_settings = UiTheme.label_settings(34, UiTheme.INK, 0, Color.WHITE, true)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(300, 64)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	s.value = float(SaveManager.get_setting(key, def))
	s.value_changed.connect(func(x: float) -> void:
		apply.call(x)
		SaveManager.set_setting(key, x))
	row.add_child(s)
	return row

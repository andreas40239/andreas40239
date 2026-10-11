extends RefCounted
## Beschreibung aller Level: Karte, Bosse, Rätsel, Farben, Hinweise.

const L1 := preload("res://scripts/level1_data.gd")
const L2 := preload("res://scripts/level2_data.gd")
const T := 32
const COUNT := 2


static func tc(x: float, y: float) -> Vector2:
	return Vector2((x + 0.5) * T, (y + 0.5) * T)


static func get_level(n: int) -> Dictionary:
	if n == 2:
		return _level2()
	return _level1()


static func _level1() -> Dictionary:
	return {
		"number": 1,
		"name": "Das Drachen-Labyrinth",
		"intro": "Warte, bis sich die Lücken der Scheiben vor dir öffnen!",
		"map": L1.MAP,
		"start_weapon": 0,
		"rings": {
			"center": Vector2(15 * T, 8.5 * T),
			"radii": [42.0, 80.0, 118.0, 156.0],
			"speed": [0.9, -0.62, 0.44, -0.3],
		},
		"fire": {
			"x0": 6, "y0": 34,
			"area": Rect2i(0, 31, 22, 13),
			"respawn": tc(4, 36),
		},
		"bosses": [
			{"kind": "knight", "char": "K", "name": "Schattenritter", "trigger": Rect2i(10, 22, 9, 7)},
			{"kind": "octopus", "char": "O", "name": "Riesenkrake", "trigger": Rect2i(23, 32, 13, 10), "drop": tc(24, 36)},
			{"kind": "golem", "char": "M", "name": "Steingolem", "trigger": Rect2i(48, 33, 11, 9)},
		],
		"dragon": {
			"center": Vector2(46.5 * T, 7.0 * T),
			"amp": Vector2(440.0, 128.0),
			"hall": Rect2i(29, 0, 35, 12),
			"entry": tc(61, 12) + Vector2(16, 0),
		},
		"hints": [
			{"rect": Rect2i(3, 34, 3, 6), "title": "Feuer aus dem Boden!",
				"sub": "Die Flammen gehen zusammen an und aus. Warte, bis sie ausgehen - dann schnell hinüber!", "checkpoint": tc(4, 36)},
			{"rect": Rect2i(18, 34, 3, 6), "title": "", "sub": "", "checkpoint": tc(19, 36)},
		],
		"floor": Color(0.2, 0.19, 0.2),
		"regions": [
			[Rect2i(0, 0, 23, 15), Color(0.2, 0.22, 0.3)],
			[Rect2i(29, 0, 35, 12), Color(0.24, 0.13, 0.13)],
			[Rect2i(9, 21, 11, 9), Color(0.22, 0.2, 0.26)],
			[Rect2i(22, 31, 15, 13), Color(0.15, 0.22, 0.2)],
			[Rect2i(47, 32, 17, 12), Color(0.27, 0.22, 0.17)],
			[Rect2i(46, 18, 10, 7), Color(0.18, 0.23, 0.3)],
		],
		"wall": Color(0.36, 0.33, 0.38),
	}


static func _level2() -> Dictionary:
	return {
		"number": 2,
		"name": "Die Eishöhle",
		"intro": "Finde die Schlüssel für die Türen und besiege Spinne und Eisgolem!",
		"map": L2.MAP,
		"start_weapon": 1,
		"rings": null,
		"fire": null,
		"bosses": [
			{"kind": "spider", "char": "W", "name": "Riesenspinne", "trigger": Rect2i(37, 3, 15, 9)},
			{"kind": "icegolem", "char": "Y", "name": "Eisgolem", "trigger": Rect2i(5, 29, 14, 9)},
		],
		"dragon": null,
		"hints": [
			{"rect": Rect2i(18, 2, 2, 11), "title": "Rutschiges Eis!",
				"sub": "Du schlitterst weiter - lenke früh in die neue Richtung.", "checkpoint": tc(16, 4)},
		],
		"floor": Color(0.2, 0.23, 0.28),
		"regions": [
			[Rect2i(0, 0, 18, 10), Color(0.2, 0.24, 0.3)],
			[Rect2i(35, 1, 19, 13), Color(0.2, 0.16, 0.24)],
			[Rect2i(3, 27, 18, 13), Color(0.22, 0.28, 0.34)],
			[Rect2i(3, 18, 13, 9), Color(0.18, 0.16, 0.26)],
		],
		"wall": Color(0.38, 0.42, 0.5),
		"pillar": Color(0.45, 0.62, 0.78),
	}

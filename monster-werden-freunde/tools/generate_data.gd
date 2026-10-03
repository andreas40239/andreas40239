extends SceneTree
## Erzeugt die datengetriebenen Inhalte (data/**/*.tres) aus einer kompakten Definition.
## Aufruf:  godot --headless -s tools/generate_data.gd
## Die erzeugten .tres-Dateien sind danach die Quelle der Wahrheit und können im Editor
## weiter angepasst werden. Pfade/Bauplätze werden auf Abstände geprüft.

const H := Needs.Type.HUNGRY
const D := Needs.Type.DIRTY
const S := Needs.Type.SAD
const T := Needs.Type.TIRED
const Y := Needs.Type.HYPER


func _init() -> void:
	_make_monsters()
	_make_stations()
	_make_levels()
	print("Daten erzeugt.")
	quit()


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Speichern fehlgeschlagen: %s (%d)" % [path, err])


# --- Monster (GDD Kap. 3) -------------------------------------------------------

func _monster(id: StringName, name: String, need: int, max_need: float, speed: float, reward: int,
		color: Color, res: Dictionary, desc: String, scale := 1.0) -> void:
	var m := MonsterData.new()
	m.id = id
	m.display_name = name
	m.need_type = need
	m.max_need = max_need
	m.base_speed = speed
	m.chaos_value = 1
	m.reward = reward
	m.body_color = color
	m.size_scale = scale
	m.effect_resistances = res
	m.description = desc
	_save(m, "res://data/monsters/%s.tres" % id)


func _make_monsters() -> void:
	_monster(&"knurri", "Knurri", H, 100, 55, 25, Color("f0604d"), {}, "Sucht nach Essen. Kekse helfen!")
	_monster(&"matschi", "Matschi", D, 120, 45, 30, Color("9c7a54"), {&"slow": 0.5},
			"Ist ganz schmutzig. Seifenblasen helfen!", 1.08)
	_monster(&"troepfli", "Tröpfli", S, 90, 50, 25, Color("4f8fe8"), {&"music": -0.3},
			"Ist traurig. Musik hilft besonders gut!")
	_monster(&"schlummi", "Schlummi", T, 115, 40, 35, Color("9b6fdc"), {&"rest": -0.3},
			"Ist sehr müde. Die Ruhe-Station hilft!", 1.05)
	_monster(&"flitzi", "Flitzi", Y, 75, 74, 25, Color("f5b92e"), {},
			"Ist ganz überdreht. Der Ventilator bremst Flitzi.", 0.92)


# --- Stationen (GDD Kap. 4) -----------------------------------------------------

func _station(id: StringName, name: String, short: String, needs: Array[int], strengths: Dictionary,
		cost: int, upgrade: int, rng: float, cooldown: float, aura: bool, tag: StringName,
		projectile: StringName, color: Color, desc: String, slow := 0.0, slow_dur := 0.0) -> void:
	var s := StationData.new()
	s.id = id
	s.display_name = name
	s.short_name = short
	s.supported_needs = needs
	s.need_strengths = strengths
	s.cost = cost
	s.upgrade_cost = upgrade
	s.help_range = rng
	s.cooldown = cooldown
	s.is_aura = aura
	s.effect_tag = tag
	s.projectile = projectile
	s.color = color
	s.description = desc
	s.slow_amount = slow
	s.slow_duration = slow_dur
	s.target_strategy = StationData.TargetStrategy.MATCHING_FIRST
	_save(s, "res://data/stations/%s.tres" % id)


func _make_stations() -> void:
	_station(&"seifenblasen", "Seifenblasenmaschine", "Blasen", [D] as Array[int], {D: 14.0}, 100, 80,
			150, 0.45, false, &"soap", &"bubble", Color("7cc8f0"), "Macht schmutzige Monster sauber.")
	_station(&"musikbox", "Musikbox", "Musik", [S, Y] as Array[int], {S: 14.0, Y: 7.0}, 120, 100,
			135, 0.0, true, &"music", &"", Color("e98ad0"), "Beruhigt traurige und überdrehte Monster.")
	_station(&"keksstand", "Keksstand", "Keks", [H] as Array[int], {H: 20.0}, 150, 120,
			125, 0.6, false, &"food", &"cookie", Color("e8a24a"), "Füttert hungrige Monster.")
	_station(&"ventilator", "Ventilator", "Ventilator", [Y] as Array[int], {Y: 12.0}, 180, 140,
			165, 0.55, false, &"wind", &"wind", Color("8fd3c7"), "Pustet überdrehte Monster langsamer.", 0.25, 1.5)
	_station(&"ruhe", "Ruhe-Station", "Ruhe", [T] as Array[int], {T: 16.0}, 160, 130,
			140, 0.0, true, &"rest", &"", Color("b59cf0"), "Lässt müde Monster entspannen.")


# --- Level (GDD Kap. 5 und 9) ---------------------------------------------------

func _wave(parts: Array) -> WaveData:
	## parts: [[monster_id, count, interval, start_delay], ...]
	var w := WaveData.new()
	var entries: Array[SpawnEntry] = []
	for p in parts:
		var e := SpawnEntry.new()
		e.monster_id = p[0]
		e.count = p[1]
		e.spawn_interval = p[2]
		e.start_delay = p[3] if p.size() > 3 else 0.0
		entries.append(e)
	w.entries = entries
	return w


func _step(text: String, trigger: String, highlight := "") -> TutorialStep:
	var s := TutorialStep.new()
	s.text = text
	s.trigger = trigger
	s.highlight = highlight
	return s


func _level(n: int, name: String, start: int, path: Array, spots: Array, waves: Array,
		stations: Array[StringName], new_monsters: Array[StringName], steps: Array, early := false,
		wave_break := 7.0) -> void:
	var l := LevelData.new()
	l.id = StringName("level_%02d" % n)
	l.number = n
	l.display_name = name
	l.starting_currency = start
	l.chaos_limit = 10
	l.path_points = PackedVector2Array(path)
	l.build_spots = PackedVector2Array(spots)
	var wl: Array[WaveData] = []
	for w in waves:
		wl.append(w)
	l.waves = wl
	l.available_station_ids = stations
	l.new_monster_ids = new_monsters
	var sl: Array[TutorialStep] = []
	for s in steps:
		sl.append(s)
	l.tutorial_steps = sl
	l.star_thresholds = Vector3i(0, 3, 9)
	l.early_start = early
	l.wave_break = wave_break
	l.decor_seed = n * 1337
	_check_layout(l)
	_save(l, "res://data/levels/level_%02d.tres" % n)


func _check_layout(l: LevelData) -> void:
	for i in l.build_spots.size():
		var p := l.build_spots[i]
		var best := INF
		for k in l.path_points.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(p, l.path_points[k], l.path_points[k + 1])
			best = minf(best, p.distance_to(q))
		if best < 92.0 or best > 135.0:
			push_warning("Level %d: Bauplatz %d hat Pfadabstand %.0f" % [l.number, i, best])
		for j in range(i + 1, l.build_spots.size()):
			if p.distance_to(l.build_spots[j]) < 100.0:
				push_warning("Level %d: Bauplätze %d/%d zu nah" % [l.number, i, j])


func _make_levels() -> void:
	# Level 1 - Keksstand (GDD 9.3)
	_level(1, "Knurris Hunger", 300,
		[Vector2(-60, 330), Vector2(480, 330), Vector2(480, 700), Vector2(1000, 700), Vector2(1000, 380), Vector2(1450, 380), Vector2(1450, 620), Vector2(1760, 620)],
		[Vector2(380, 430), Vector2(580, 600), Vector2(900, 600), Vector2(1100, 480), Vector2(1350, 480), Vector2(1550, 520), Vector2(740, 590),
			Vector2(740, 810), Vector2(1220, 270), Vector2(230, 220), Vector2(1650, 730)],
		[_wave([[&"knurri", 4, 1.8]]), _wave([[&"knurri", 6, 1.5]]), _wave([[&"knurri", 8, 1.2]])],
		[&"keksstand"] as Array[StringName], [&"knurri"] as Array[StringName],
		[
			_step("Knurri hat Hunger!\nTippe auf ein  +", "spot_selected", "spot:0"),
			_step("Tippe auf den Keksstand.", "station_built", "card:keksstand"),
			_step("Super! Baue noch einen Keksstand.", "station_built", "spot:2"),
			_step("Tippe auf  Los!", "wave_started", "start"),
			_step("Kekse machen Knurri satt und froh!", "time:7"),
			_step("Freunde bringen dir Sonnenpunkte.\nDamit kannst du mehr bauen.", "time:8"),
		], false, 8.0)

	# Level 2 - Seifenblasen
	_level(2, "Matschis Pfützen", 320,
		[Vector2(-60, 560), Vector2(360, 560), Vector2(360, 250), Vector2(820, 250), Vector2(820, 760), Vector2(1300, 760), Vector2(1300, 300),
			Vector2(1620, 300), Vector2(1620, 560), Vector2(1760, 560)],
		[Vector2(260, 460), Vector2(460, 350), Vector2(720, 350), Vector2(920, 660), Vector2(1200, 660), Vector2(1400, 400), Vector2(1520, 400),
			Vector2(1720, 460), Vector2(590, 360), Vector2(1060, 650)],
		[
			_wave([[&"matschi", 4, 2.0]]),
			_wave([[&"knurri", 4, 1.6], [&"matschi", 3, 2.0, 1.0]]),
			_wave([[&"matschi", 3, 1.6], [&"knurri", 3, 1.4, 0.8], [&"matschi", 3, 1.6, 0.8]]),
			_wave([[&"knurri", 3, 1.2], [&"matschi", 3, 1.4, 0.6], [&"knurri", 3, 1.2, 0.6], [&"matschi", 3, 1.4, 0.6]]),
		],
		[&"seifenblasen", &"keksstand"] as Array[StringName], [&"matschi"] as Array[StringName],
		[
			_step("Matschi ist schmutzig.\nSeifenblasen helfen!", "station_built:seifenblasen", "card:seifenblasen"),
			_step("Das Bild über dem Monster zeigt,\nwas es braucht.", "time:7"),
			_step("Tippe auf  Los!", "wave_started", "start"),
			_step("Apfel = Hunger,  Blase = schmutzig.", "time:8"),
		], false, 7.0)

	# Level 3 - Musikbox, Reichweite
	_level(3, "Tröpflis Regentag", 340,
		[Vector2(-60, 250), Vector2(620, 250), Vector2(620, 520), Vector2(220, 520), Vector2(220, 790), Vector2(1080, 790), Vector2(1080, 430),
			Vector2(1480, 430), Vector2(1480, 690), Vector2(1760, 690)],
		[Vector2(520, 350), Vector2(320, 420), Vector2(320, 620), Vector2(110, 650), Vector2(650, 690), Vector2(980, 690), Vector2(1180, 530),
			Vector2(1380, 530), Vector2(1580, 590), Vector2(1280, 330)],
		[
			_wave([[&"troepfli", 5, 1.8]]),
			_wave([[&"knurri", 4, 1.5], [&"troepfli", 4, 1.6, 0.8]]),
			_wave([[&"matschi", 4, 1.8], [&"troepfli", 5, 1.4, 0.8]]),
			_wave([[&"troepfli", 6, 1.2], [&"knurri", 4, 1.3, 0.6]]),
			_wave([[&"knurri", 3, 1.3], [&"matschi", 3, 1.5, 0.5], [&"troepfli", 3, 1.3, 0.5],
				[&"knurri", 3, 1.2, 0.5], [&"troepfli", 3, 1.2, 0.5]]),
		],
		[&"seifenblasen", &"musikbox", &"keksstand"] as Array[StringName], [&"troepfli"] as Array[StringName],
		[
			_step("Tröpfli ist traurig.\nMusik hilft!", "station_built:musikbox", "card:musikbox"),
			_step("Der Kreis zeigt, wie weit\neine Station helfen kann.", "time:7"),
			_step("Tipp: Plätze in Kurven\nhelfen am längsten.", "time:7"),
			_step("Neu: Mit  ▶▶  geht es schneller.", "time:8", "speed"),
		], false, 7.0)

	# Level 4 - Ventilator, gemischte Wellen
	_level(4, "Flitzis Wirbelwind", 460,
		[Vector2(-60, 680), Vector2(380, 680), Vector2(380, 260), Vector2(860, 260), Vector2(860, 620), Vector2(1260, 620), Vector2(1260, 240),
			Vector2(1560, 240), Vector2(1560, 560), Vector2(1760, 560)],
		[Vector2(280, 580), Vector2(480, 360), Vector2(760, 360), Vector2(960, 520), Vector2(1160, 520), Vector2(1360, 340), Vector2(1460, 420),
			Vector2(1660, 460), Vector2(620, 380), Vector2(1060, 720), Vector2(150, 580)],
		[
			_wave([[&"flitzi", 4, 2.5]]),
			_wave([[&"knurri", 5, 1.8], [&"flitzi", 3, 2.2, 0.8]]),
			_wave([[&"troepfli", 4, 1.9], [&"flitzi", 4, 2.0, 0.6]]),
			_wave([[&"matschi", 5, 1.9], [&"flitzi", 5, 1.6, 0.6]]),
			_wave([[&"flitzi", 3, 1.5], [&"knurri", 3, 1.5, 0.5], [&"troepfli", 3, 1.5, 0.5], [&"matschi", 3, 1.8, 0.5]]),
			_wave([[&"knurri", 4, 1.2], [&"flitzi", 4, 1.4, 0.4], [&"matschi", 3, 1.6, 0.4], [&"troepfli", 4, 1.4, 0.4],
				[&"flitzi", 3, 1.2, 0.4]]),
		],
		[&"seifenblasen", &"musikbox", &"keksstand", &"ventilator"] as Array[StringName], [&"flitzi"] as Array[StringName],
		[
			_step("Flitzi ist überdreht.\nDer Ventilator bremst Flitzi!", "station_built:ventilator", "card:ventilator"),
			_step("Musik beruhigt Flitzi auch\nein kleines bisschen.", "time:7"),
			_step("Tippe auf  Los!", "wave_started", "start"),
			_step("Zwischen den Wellen kannst du\nmit  Los!  früher starten.", "time:9"),
		], true, 10.0)

	# Level 5 - Ruhe-Station, Upgrade und Verkaufen
	_level(5, "Schlummis Mittagsschlaf", 600,
		[Vector2(-60, 420), Vector2(300, 420), Vector2(300, 780), Vector2(760, 780), Vector2(760, 230), Vector2(1180, 230), Vector2(1180, 700),
			Vector2(1540, 700), Vector2(1540, 400), Vector2(1760, 400)],
		[Vector2(200, 520), Vector2(400, 680), Vector2(660, 680), Vector2(860, 330), Vector2(1080, 330), Vector2(1280, 600), Vector2(1440, 600),
			Vector2(1640, 500), Vector2(530, 680), Vector2(970, 330), Vector2(660, 420), Vector2(1640, 300)],
		[
			_wave([[&"schlummi", 4, 2.8]]),
			_wave([[&"schlummi", 4, 2.5], [&"knurri", 4, 1.8, 0.8]]),
			_wave([[&"flitzi", 4, 1.9], [&"troepfli", 4, 1.8, 0.6]]),
			_wave([[&"matschi", 5, 1.9], [&"schlummi", 4, 2.2, 0.6]]),
			_wave([[&"schlummi", 3, 2.0], [&"flitzi", 3, 1.5, 0.5], [&"knurri", 3, 1.5, 0.5], [&"troepfli", 3, 1.5, 0.5]]),
			_wave([[&"knurri", 3, 1.2], [&"matschi", 3, 1.6, 0.4], [&"schlummi", 3, 1.9, 0.4], [&"flitzi", 3, 1.2, 0.4],
				[&"troepfli", 3, 1.2, 0.4], [&"schlummi", 2, 1.9, 0.4]]),
		],
		[&"seifenblasen", &"musikbox", &"keksstand", &"ventilator", &"ruhe"] as Array[StringName],
		[&"schlummi"] as Array[StringName],
		[
			_step("Schlummi ist müde.\nDie Ruhe-Station hilft!", "station_built:ruhe", "card:ruhe"),
			_step("Tippe auf eine Station,\num sie zu verbessern.", "station_selected", "station"),
			_step("Wähle:  Weiter  oder  Stärker.", "station_upgraded", "upgrade"),
			_step("Verkaufen gibt dir 3/4\nder Punkte zurück.", "time:8"),
		], true, 10.0)

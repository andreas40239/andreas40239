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
const C := Needs.Type.CHARGE
const F := Needs.Type.FLY
const K := Needs.Type.COLD
const L := Needs.Type.LONELY


func _init() -> void:
	_make_monsters()
	_make_stations()
	_make_levels()
	_make_world2()
	_make_world3()
	print("Daten erzeugt.")
	quit()


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Speichern fehlgeschlagen: %s (%d)" % [path, err])


# --- Monster (GDD Kap. 3) -------------------------------------------------------

func _monster(id: StringName, name: String, need: int, max_need: float, speed: float, reward: int,
		color: Color, res: Dictionary, desc: String, scale := 1.0, friend_speed := 1.6, flies := false) -> void:
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
	m.friend_speed_mult = friend_speed
	m.friend_flies = flies
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
	# Welt 2 - Strand und Meer
	_monster(&"elektro", "Elektro", C, 100, 42, 25, Color("36c2b4"), {},
			"Ist ganz leer. Aufgeladen rennt es dreimal so schnell ins Dorf!", 1.0, 3.0)
	_monster(&"fluegel", "Flügel", F, 95, 50, 25, Color("ff8fb1"), {},
			"Möchte fliegen. Mit Flügeln fliegt es direkt ins Dorf!", 1.0, 1.6, true)
	# Welt 3 - Schnee und Berge
	_monster(&"bibber", "Bibber", K, 110, 46, 30, Color("9fd8f5"), {},
			"Friert ganz doll. Warmer Kakao hilft!", 1.02)
	_monster(&"flocki", "Flocki", L, 100, 50, 25, Color("e6e9ff"), {&"friends": -0.2},
			"Ist einsam. Ein Schneemann wird sein Freund!", 0.98)


# --- Stationen (GDD Kap. 4) -----------------------------------------------------

func _station(id: StringName, name: String, short: String, needs: Array[int], strengths: Dictionary,
		cost: int, upgrade: int, rng: float, cooldown: float, aura: bool, tag: StringName,
		projectile: StringName, color: Color, desc: String, slow := 0.0, slow_dur := 0.0, dance := 0.0) -> void:
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
	s.dance_duration = dance
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
	_station(&"batterie", "Batterieladen", "Batterie", [C] as Array[int], {C: 20.0}, 150, 120,
			130, 0.6, false, &"charge", &"battery", Color("3cc6a0"), "Lädt leere Monster wieder auf.")
	_station(&"fluegelladen", "Flügelladen", "Flügel", [F] as Array[int], {F: 19.0}, 150, 120,
			135, 0.6, false, &"wings", &"feather", Color("ff8fb1"), "Schenkt Monstern Flügel zum Fliegen.")
	_station(&"disco", "Disco", "Disco", [] as Array[int], {}, 140, 110,
			140, 4.0, false, &"dance", &"", Color("c86bfa"), "Monster bleiben stehen und tanzen eine Weile.", 0.0, 0.0, 2.5)
	_station(&"kakao", "Kakaostand", "Kakao", [K] as Array[int], {K: 20.0}, 150, 120,
			125, 0.6, false, &"warm", &"mug", Color("c98b4f"), "Wärmt frierende Monster mit Kakao.")
	_station(&"schneemann", "Schneemann-Werkstatt", "Schneemann", [L] as Array[int], {L: 15.0}, 160, 130,
			140, 0.0, true, &"friends", &"", Color("b8d8f0"), "Baut Schneemänner als Freunde für einsame Monster.")


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
	l.world = DataRegistry.world_of_level(n)
	l.world_name = DataRegistry.world_name(l.world)
	l.theme = DataRegistry.world_theme(l.world)
	if l.build_spots.is_empty():
		l.build_spots = _auto_spots(l.path_points)
	if l.monster_types().size() > 5:
		push_error("Level %d hat mehr als 5 Monstertypen: %s" % [n, l.monster_types()])
	if l.available_station_ids.size() > 5:
		push_error("Level %d hat mehr als 5 Stationen" % n)
	_check_layout(l)
	print("Level %d: %d Bauplätze, Typen %s" % [n, l.build_spots.size(), l.monster_types()])
	_save(l, "res://data/levels/level_%02d.tres" % n)


## Erzeugt Bauplätze automatisch: Innenseiten der Kurven zuerst, dann neben langen Geraden.
func _auto_spots(path: PackedVector2Array) -> PackedVector2Array:
	var cands: Array[Vector2] = []
	for i in range(1, path.size() - 1):
		var a := (path[i] - path[i - 1]).normalized()
		var b := (path[i + 1] - path[i]).normalized()
		cands.append(path[i] - a * 100.0 + b * 100.0)
	for i in path.size() - 1:
		var seg := path[i + 1] - path[i]
		var n := Vector2(-seg.y, seg.x).normalized()
		var ks: Array[float] = []
		if seg.length() >= 520.0:
			ks = [0.33, 0.67]
		elif seg.length() >= 250.0:
			ks = [0.5]
		for k in ks:
			for sgn in [1.0, -1.0]:
				cands.append(path[i].lerp(path[i + 1], k) + n * 108.0 * sgn)
	for i in range(1, path.size() - 1):
		var a := (path[i] - path[i - 1]).normalized()
		var b := (path[i + 1] - path[i]).normalized()
		cands.append(path[i] + a * 105.0 - b * 105.0)
	var result := PackedVector2Array()
	for p in cands:
		if result.size() >= 12:
			break
		if p.x < 70 or p.x > 1690 or p.y < 185 or p.y > 840:
			continue
		if p.y < 240 and (p.x < 900 or p.x > 1580):
			continue
		if p.y > 790 and p.x > 360 and p.x < 1580:
			continue
		var d := _path_distance(p, path)
		if d < 95.0 or d > 130.0:
			continue
		var ok := true
		for q in result:
			if q.distance_to(p) < 118.0:
				ok = false
				break
		if ok:
			result.append(p)
	return result


func _path_distance(p: Vector2, path: PackedVector2Array) -> float:
	var best := INF
	for k in path.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, path[k], path[k + 1])))
	return best


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
			_step("Neu: Der Knopf  >>  macht schneller.", "time:8", "speed"),
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



# --- Welt 2: Strand und Meer -----------------------------------------------------

func _make_world2() -> void:
	var start_hint := _step("Tippe auf  Los!", "wave_started", "start")
	_level(6, "Elektros Ladestation", 380,
		[Vector2(-60, 300), Vector2(400, 300), Vector2(400, 650), Vector2(800, 650), Vector2(800, 300), Vector2(1200, 300),
			Vector2(1200, 700), Vector2(1550, 700), Vector2(1550, 450), Vector2(1760, 450)], [],
		[
			_wave([[&"elektro", 4, 2.2]]),
			_wave([[&"knurri", 4, 1.6], [&"elektro", 3, 2.0, 0.8]]),
			_wave([[&"matschi", 4, 1.8], [&"elektro", 4, 1.8, 0.8]]),
			_wave([[&"elektro", 3, 1.6], [&"knurri", 3, 1.4, 0.6], [&"matschi", 3, 1.6, 0.6]]),
			_wave([[&"elektro", 5, 1.4], [&"knurri", 4, 1.3, 0.5], [&"matschi", 3, 1.5, 0.5]]),
		],
		[&"seifenblasen", &"keksstand", &"batterie"] as Array[StringName], [&"elektro"] as Array[StringName],
		[
			_step("Elektro ist ganz leer.\nDer Batterieladen lädt es auf!", "station_built:batterie", "card:batterie"),
			start_hint,
			_step("Aufgeladen rennt Elektro\ndreimal so schnell ins Dorf!", "time:8"),
		], true, 9.0)
	_level(7, "Flügels großer Traum", 540,
		[Vector2(-60, 700), Vector2(350, 700), Vector2(350, 330), Vector2(700, 330), Vector2(700, 620), Vector2(1050, 620),
			Vector2(1050, 250), Vector2(1420, 250), Vector2(1420, 560), Vector2(1760, 560)], [],
		[
			_wave([[&"fluegel", 3, 2.2]]),
			_wave([[&"fluegel", 3, 2.0], [&"troepfli", 3, 2.0, 1.0]]),
			_wave([[&"elektro", 3, 2.0], [&"fluegel", 3, 2.0, 1.0]]),
			_wave([[&"knurri", 3, 1.8], [&"troepfli", 2, 1.8, 1.0], [&"fluegel", 3, 1.8, 1.0]]),
			_wave([[&"fluegel", 3, 1.8], [&"elektro", 2, 1.8, 1.0], [&"knurri", 2, 1.8, 1.0], [&"troepfli", 2, 1.8, 1.0]]),
		],
		[&"musikbox", &"keksstand", &"batterie", &"fluegelladen"] as Array[StringName], [&"fluegel"] as Array[StringName],
		[
			_step("Flügel möchte fliegen.\nIm Flügelladen gibt es Flügel!", "station_built:fluegelladen", "card:fluegelladen"),
			start_hint,
			_step("Mit Flügeln fliegt es\ndirekt ins Dorf!", "time:8"),
		], true, 11.0)
	_level(8, "Disco am Strand", 660,
		[Vector2(-60, 450), Vector2(300, 450), Vector2(300, 220), Vector2(650, 220), Vector2(650, 760), Vector2(1000, 760),
			Vector2(1000, 420), Vector2(1350, 420), Vector2(1350, 720), Vector2(1600, 720), Vector2(1600, 380), Vector2(1760, 380)], [],
		[
			_wave([[&"flitzi", 3, 2.2], [&"elektro", 2, 2.2, 1.0]]),
			_wave([[&"matschi", 3, 2.0], [&"fluegel", 3, 2.0, 1.0]]),
			_wave([[&"flitzi", 3, 1.9], [&"elektro", 3, 1.9, 1.0]]),
			_wave([[&"fluegel", 3, 1.8], [&"matschi", 3, 1.8, 1.0], [&"flitzi", 2, 1.8, 1.0]]),
			_wave([[&"elektro", 3, 1.7], [&"flitzi", 2, 1.7, 1.0], [&"fluegel", 3, 1.7, 1.0], [&"matschi", 2, 1.8, 1.0]]),
		],
		[&"seifenblasen", &"ventilator", &"batterie", &"fluegelladen", &"disco"] as Array[StringName], [] as Array[StringName],
		[
			_step("Neu: die Disco!\nMonster bleiben stehen und tanzen.", "station_built:disco", "card:disco"),
			_step("Tanzende Monster laufen nicht weiter.\nSo hast du mehr Zeit zum Helfen!", "time:9"),
		], true, 11.0)
	_level(9, "Muschelsuche", 640,
		[Vector2(-60, 250), Vector2(500, 250), Vector2(500, 520), Vector2(150, 520), Vector2(150, 780), Vector2(900, 780),
			Vector2(900, 450), Vector2(1250, 450), Vector2(1250, 220), Vector2(1600, 220), Vector2(1600, 600), Vector2(1760, 600)], [],
		[
			_wave([[&"schlummi", 3, 2.6]]),
			_wave([[&"troepfli", 3, 2.0], [&"elektro", 2, 2.0, 1.0]]),
			_wave([[&"fluegel", 3, 2.0], [&"schlummi", 2, 2.4, 1.0]]),
			_wave([[&"elektro", 3, 1.9], [&"troepfli", 3, 1.9, 1.0], [&"schlummi", 2, 2.2, 1.0]]),
			_wave([[&"fluegel", 3, 1.8], [&"schlummi", 2, 2.0, 1.0], [&"elektro", 3, 1.8, 1.0], [&"troepfli", 2, 1.8, 1.0]]),
		],
		[&"musikbox", &"ruhe", &"batterie", &"fluegelladen", &"disco"] as Array[StringName], [] as Array[StringName],
		[
			_step("Tipp: Baue die Disco dort,\nwo viele Monster vorbeikommen.", "time:9"),
		], true, 11.0)
	_level(10, "Großes Strandfest", 700,
		[Vector2(-60, 600), Vector2(250, 600), Vector2(250, 250), Vector2(600, 250), Vector2(600, 780), Vector2(950, 780),
			Vector2(950, 330), Vector2(1300, 330), Vector2(1300, 700), Vector2(1560, 700), Vector2(1560, 300), Vector2(1760, 300)], [],
		[
			_wave([[&"elektro", 3, 2.0], [&"fluegel", 2, 2.0, 1.0]]),
			_wave([[&"matschi", 3, 2.0], [&"knurri", 3, 1.9, 1.0]]),
			_wave([[&"fluegel", 3, 1.9], [&"elektro", 3, 1.9, 1.0], [&"knurri", 2, 1.9, 1.0]]),
			_wave([[&"matschi", 3, 1.8], [&"fluegel", 3, 1.8, 1.0], [&"elektro", 3, 1.8, 1.0]]),
			_wave([[&"knurri", 3, 1.7], [&"elektro", 3, 1.7, 1.0], [&"matschi", 2, 1.8, 1.0], [&"fluegel", 3, 1.7, 1.0]]),
		],
		[&"seifenblasen", &"keksstand", &"batterie", &"fluegelladen", &"disco"] as Array[StringName], [] as Array[StringName],
		[], true, 11.0)


# --- Welt 3: Schnee und Berge ------------------------------------------------------

func _make_world3() -> void:
	var start_hint := _step("Tippe auf  Los!", "wave_started", "start")
	_level(11, "Bibbers kalte Füße", 580,
		[Vector2(-60, 700), Vector2(450, 700), Vector2(450, 300), Vector2(900, 300), Vector2(900, 700), Vector2(1350, 700),
			Vector2(1350, 350), Vector2(1760, 350)], [],
		[
			_wave([[&"bibber", 4, 2.2]]),
			_wave([[&"knurri", 4, 1.6], [&"bibber", 3, 2.0, 0.8]]),
			_wave([[&"troepfli", 4, 1.6], [&"bibber", 4, 1.8, 0.6]]),
			_wave([[&"bibber", 4, 1.5], [&"knurri", 3, 1.4, 0.5], [&"troepfli", 3, 1.4, 0.5]]),
			_wave([[&"bibber", 5, 1.3], [&"troepfli", 4, 1.2, 0.4], [&"knurri", 4, 1.2, 0.4]]),
		],
		[&"musikbox", &"keksstand", &"kakao"] as Array[StringName], [&"bibber"] as Array[StringName],
		[
			_step("Bibber friert.\nWarmer Kakao hilft!", "station_built:kakao", "card:kakao"),
			start_hint,
		], true, 9.0)
	_level(12, "Flockis Schneemann", 600,
		[Vector2(-60, 250), Vector2(350, 250), Vector2(350, 750), Vector2(700, 750), Vector2(700, 300), Vector2(1050, 300),
			Vector2(1050, 750), Vector2(1400, 750), Vector2(1400, 450), Vector2(1760, 450)], [],
		[
			_wave([[&"flocki", 4, 2.0]]),
			_wave([[&"bibber", 4, 1.8], [&"flocki", 3, 1.8, 0.6]]),
			_wave([[&"schlummi", 3, 2.2], [&"matschi", 4, 1.6, 0.6]]),
			_wave([[&"flocki", 4, 1.4], [&"bibber", 4, 1.5, 0.5], [&"matschi", 3, 1.5, 0.5]]),
			_wave([[&"schlummi", 3, 1.8], [&"flocki", 4, 1.2, 0.4], [&"bibber", 4, 1.3, 0.4], [&"matschi", 3, 1.4, 0.4]]),
		],
		[&"seifenblasen", &"ruhe", &"kakao", &"schneemann"] as Array[StringName], [&"flocki"] as Array[StringName],
		[
			_step("Flocki ist einsam.\nEin Schneemann wird sein Freund!", "station_built:schneemann", "card:schneemann"),
			start_hint,
		], true, 9.0)
	_level(13, "Lawinen-Disco", 500,
		[Vector2(-60, 500), Vector2(300, 500), Vector2(300, 220), Vector2(700, 220), Vector2(700, 780), Vector2(1100, 780),
			Vector2(1100, 420), Vector2(1450, 420), Vector2(1450, 740), Vector2(1760, 740)], [],
		[
			_wave([[&"bibber", 4, 2.0], [&"flitzi", 3, 2.0, 0.6]]),
			_wave([[&"elektro", 4, 1.7], [&"flocki", 4, 1.6, 0.6]]),
			_wave([[&"flitzi", 4, 1.4], [&"bibber", 4, 1.5, 0.5], [&"elektro", 3, 1.6, 0.5]]),
			_wave([[&"flocki", 4, 1.3], [&"elektro", 4, 1.3, 0.4], [&"flitzi", 4, 1.2, 0.4]]),
			_wave([[&"bibber", 4, 1.2], [&"flocki", 4, 1.2, 0.4], [&"elektro", 4, 1.2, 0.4], [&"flitzi", 4, 1.1, 0.4]]),
		],
		[&"ventilator", &"batterie", &"kakao", &"schneemann", &"disco"] as Array[StringName], [] as Array[StringName],
		[_step("Die Disco hält auch im Schnee\nalle Monster kurz an.", "time:8")], true, 9.0)
	_level(14, "Gipfelsturm", 600,
		[Vector2(-60, 230), Vector2(700, 230), Vector2(700, 480), Vector2(200, 480), Vector2(200, 780), Vector2(1000, 780),
			Vector2(1000, 450), Vector2(1350, 450), Vector2(1350, 250), Vector2(1760, 250)], [],
		[
			_wave([[&"flocki", 4, 1.9], [&"bibber", 3, 2.0, 0.6]]),
			_wave([[&"fluegel", 4, 1.6], [&"troepfli", 4, 1.5, 0.6]]),
			_wave([[&"knurri", 4, 1.4], [&"bibber", 4, 1.5, 0.5], [&"flocki", 3, 1.5, 0.5]]),
			_wave([[&"fluegel", 4, 1.3], [&"troepfli", 3, 1.3, 0.4], [&"bibber", 4, 1.3, 0.4], [&"knurri", 3, 1.2, 0.4]]),
			_wave([[&"flocki", 4, 1.2], [&"fluegel", 4, 1.2, 0.4], [&"bibber", 4, 1.2, 0.4], [&"knurri", 3, 1.1, 0.4]]),
			_wave([[&"bibber", 4, 1.1], [&"troepfli", 4, 1.1, 0.4], [&"flocki", 4, 1.1, 0.4], [&"fluegel", 4, 1.1, 0.4]]),
		],
		[&"musikbox", &"keksstand", &"fluegelladen", &"kakao", &"schneemann"] as Array[StringName], [] as Array[StringName],
		[], true, 10.0)
	_level(15, "Das große Schneefest", 600,
		[Vector2(-60, 760), Vector2(350, 760), Vector2(350, 240), Vector2(750, 240), Vector2(750, 560), Vector2(1050, 560),
			Vector2(1050, 240), Vector2(1400, 240), Vector2(1400, 740), Vector2(1760, 740)], [],
		[
			_wave([[&"bibber", 4, 1.8], [&"flocki", 4, 1.8, 0.6]]),
			_wave([[&"elektro", 4, 1.6], [&"fluegel", 4, 1.6, 0.6]]),
			_wave([[&"schlummi", 3, 2.0], [&"bibber", 4, 1.4, 0.5], [&"flocki", 3, 1.4, 0.5]]),
			_wave([[&"fluegel", 4, 1.3], [&"elektro", 4, 1.3, 0.4], [&"schlummi", 3, 1.8, 0.4]]),
			_wave([[&"bibber", 4, 1.2], [&"flocki", 4, 1.2, 0.4], [&"elektro", 4, 1.2, 0.4], [&"fluegel", 3, 1.2, 0.4]]),
			_wave([[&"schlummi", 3, 1.5], [&"bibber", 4, 1.1, 0.4], [&"fluegel", 4, 1.1, 0.4], [&"flocki", 4, 1.1, 0.4],
				[&"elektro", 3, 1.1, 0.4]]),
		],
		[&"ruhe", &"batterie", &"fluegelladen", &"kakao", &"schneemann"] as Array[StringName], [] as Array[StringName],
		[], true, 10.0)

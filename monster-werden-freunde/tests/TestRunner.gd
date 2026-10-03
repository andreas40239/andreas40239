extends Node
## Automatisierte Akzeptanztests (GDD Kap. 13).
## Aufruf:  godot --headless --path . res://tests/TestRunner.tscn
## Exit-Code 0 = alle Tests bestanden.

const GAME_SCENE := preload("res://scenes/game/Game.tscn")

var _failures := 0
var _passed := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  OK   ", name)
	else:
		_failures += 1
		printerr("  FAIL ", name)


func _new_game(level_number: int) -> Game:
	GameState.current_level = level_number
	var g: Game = GAME_SCENE.instantiate()
	g.skip_intro = true
	add_child(g)
	return g


func _free_game(g: Game) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	g.queue_free()
	await get_tree().process_frame


func _run() -> void:
	var saved := SaveManager.data.duplicate(true)
	print("Akzeptanztests - Monster werden Freunde")

	# AT-01: Bauen kostet Sonnenpunkte
	var g := _new_game(1)
	await get_tree().process_frame
	GameState.set_currency(300)
	var st := g.build_station(g.build_manager.spots[0], &"keksstand")
	check(st != null and GameState.currency == 150, "AT-01 Keksstand für 150 bei 300 -> Kontostand 150")

	# AT-02: Effekt 20 auf need 100 -> 80
	var m := g._spawn_monster(&"knurri")
	check(is_equal_approx(m.need_value, 100.0), "AT-02a Knurri startet mit need 100")
	m.apply_help(HelpEffect.simple(Needs.Type.HUNGRY, 20.0))
	check(is_equal_approx(m.need_value, 80.0) and m.state == Monster.State.WILD, "AT-02 need 100 - 20 = 80")

	# AT-03: need 10 + Effekt 20 -> 0, FRIEND, Event genau einmal
	var friend_events := [0]
	m.monster_became_friend.connect(func(_x: Monster) -> void: friend_events[0] += 1)
	m.need_value = 10.0
	m.state = Monster.State.HAPPY
	m.apply_help(HelpEffect.simple(Needs.Type.HUNGRY, 20.0))
	m.apply_help(HelpEffect.simple(Needs.Type.HUNGRY, 20.0))
	check(m.need_value == 0.0 and m.state == Monster.State.FRIEND and friend_events[0] == 1,
		"AT-03 need 10 -> 0, FRIEND, Ereignis genau einmal")

	# Unpassende Hilfe: kein Schaden, nur wenig Wirkung
	var mat := g._spawn_monster(&"matschi")
	var keks := DataRegistry.station(&"keksstand")
	var eff := st.make_effect()
	var applied := mat.apply_help(eff)
	check(applied > 0.0 and applied < keks.need_strengths[Needs.Type.HUNGRY] and mat.need_value < mat.data.max_need,
		"Unpassende Hilfe wirkt nur ein bisschen (%.1f)" % applied)

	# AT-04: FREUND erreicht Pfadende -> Chaos unverändert, Belohnung einmal
	var chaos_before := GameState.chaos
	var cur_before := GameState.currency
	m._arrive()
	check(GameState.chaos == chaos_before and GameState.currency == cur_before + m.data.reward,
		"AT-04 Freund am Ziel: Chaos gleich, +%d Sonnenpunkte" % m.data.reward)

	# AT-05: WILD erreicht Pfadende -> Chaos +1
	var wild := g._spawn_monster(&"knurri")
	cur_before = GameState.currency
	wild._arrive()
	check(GameState.chaos == chaos_before + 1 and GameState.currency == cur_before, "AT-05 Wildes Monster am Ziel: Chaos +1")
	check(wild.state == Monster.State.ARRIVED and wild.need_value > 0.0, "AT-05b Monster wird nicht 'besiegt', nur ARRIVED")

	# AT-07: Verkaufen gibt 75 % der kumulierten Investition
	GameState.set_currency(1000)
	g.build_manager.upgrade(st, &"power")
	var invested := st.invested
	cur_before = GameState.currency
	var refund := g.build_manager.sell(st)
	check(invested == 150 + keks.upgrade_cost and refund == roundi(invested * 0.75) and GameState.currency == cur_before + refund,
		"AT-07 Verkauf: %d von %d zurück" % [refund, invested])
	check(g.build_manager.spots[0].is_free(), "AT-07b Bauplatz ist wieder frei")

	# Upgrade-Werte: +20 % Reichweite / +25 % Wirkung
	var st2 := g.build_station(g.build_manager.spots[1], &"keksstand")
	g.build_manager.upgrade(st2, &"range")
	check(is_equal_approx(st2.get_range(), keks.help_range * 1.2), "Upgrade Weiter: +20 % Reichweite")
	var st3 := g.build_station(g.build_manager.spots[2], &"keksstand")
	g.build_manager.upgrade(st3, &"power")
	check(is_equal_approx(st3.make_effect().amount_for(Needs.Type.HUNGRY), 25.0), "Upgrade Stärker: +25 % Wirkung")

	# AT-08: Pause stoppt Monster und Wellen, UI bleibt bedienbar
	var walker := g._spawn_monster(&"flitzi")
	for i in 3:
		await get_tree().process_frame
	get_tree().paused = true
	var p0 := walker.progress
	var t0 := g.wave_manager._timer
	for i in 10:
		await get_tree().process_frame
	check(is_equal_approx(walker.progress, p0) and is_equal_approx(g.wave_manager._timer, t0), "AT-08 Pause stoppt Monster/Wellen")
	check(g.hud.process_mode == Node.PROCESS_MODE_ALWAYS and g.process_mode == Node.PROCESS_MODE_ALWAYS,
		"AT-08b HUD/Eingabe laufen in der Pause weiter")
	GameState.set_currency(500)
	var paused_build := g.build_station(g.build_manager.spots[3], &"keksstand")
	check(paused_build != null, "AT-08c Bauen ist während der Pause möglich")
	get_tree().paused = false
	await _free_game(g)

	# AT-06: Chaos erreicht 10 -> Level endet, ResultPanel mit Retry
	g = _new_game(1)
	await get_tree().process_frame
	var lose_stars := [-1]
	g.level_completed.connect(func(s: int, _c: int) -> void: lose_stars[0] = s)
	GameState.chaos = 9
	var last := g._spawn_monster(&"knurri")
	last._arrive()
	check(g.phase == Game.Phase.ENDED and g.hud.is_result_shown() and lose_stars[0] == 0, "AT-06 Chaos 10 -> Level endet mit Retry")
	await _free_game(g)

	# Sterne nach Chaos (GDD 2.1)
	var l1 := DataRegistry.level(1)
	check(l1.stars_for_chaos(0) == 3 and l1.stars_for_chaos(3) == 2 and l1.stars_for_chaos(9) == 1 and l1.stars_for_chaos(10) == 0,
		"Sterne: 0->3, 1-3->2, 4-9->1, 10->0")

	# AT-09: Speichern und Laden
	SaveManager.reset_progress()
	SaveManager.record_result(1, 2)
	SaveManager.record_result(1, 1)
	SaveManager.data = {}
	SaveManager.load_game()
	check(SaveManager.get_stars(1) == 2 and SaveManager.is_level_unlocked(2) and not SaveManager.is_level_unlocked(3),
		"AT-09 Sterne/Freischaltung werden geladen (beste Wertung bleibt)")

	# Datenmodell: 5 Monster, 5 Stationen, 5 Level
	check(DataRegistry.MONSTERS.size() == 5 and DataRegistry.STATIONS.size() == 5 and DataRegistry.level_count() == 5,
		"MVP-Inhalte: 5 Monster, 5 Stationen, 5 Level")
	for n in DataRegistry.level_count():
		var lv := DataRegistry.level(n + 1)
		check(lv.waves.size() >= 3 and lv.waves.size() <= 8 and lv.available_station_ids.size() <= 5,
			"Level %d: %d Wellen, %d Stationen" % [lv.number, lv.waves.size(), lv.available_station_ids.size()])

	SaveManager.data = saved
	SaveManager.save_game()
	print("Ergebnis: %d bestanden, %d fehlgeschlagen" % [_passed, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

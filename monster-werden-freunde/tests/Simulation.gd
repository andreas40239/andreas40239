extends Node
## Balancing-Simulation: ein einfacher Bot spielt alle Level (schnell, ohne Grafik).
## Aufruf:  godot --headless --fixed-fps 60 --path . res://tests/Simulation.tscn [-- <level> <strategie>]
## Strategien: greedy (gibt alles aus), modest (baut höchstens eine Station pro Welle + Start),
##             stress (10-Minuten-Stresstest: 2x Tempo, wildes Bauen/Verkaufen)

const GAME_SCENE := preload("res://scenes/game/Game.tscn")
const TIME_SCALE := 4.0

var _results: Array[String] = []
var _all_won := true


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var levels: Array[int] = [1, 2, 3, 4, 5]
	var strategies: Array[String] = ["greedy", "modest"]
	if args.size() >= 1:
		levels = [int(args[0])]
	if args.size() >= 2:
		strategies = [args[1]]
	var saved := SaveManager.data.duplicate(true)
	for strat in strategies:
		for n in levels:
			await _play(n, strat)
	SaveManager.data = saved
	SaveManager.save_game()
	print("\n=== Ergebnis ===")
	for r in _results:
		print(r)
	get_tree().quit(0)


func _play(n: int, strat: String) -> void:
	GameState.current_level = n
	var g: Game = GAME_SCENE.instantiate()
	g.skip_intro = true
	add_child(g)
	await get_tree().process_frame
	Engine.time_scale = TIME_SCALE
	var baked := g.path2d.curve.get_baked_points()
	var result := [-1, 0]
	g.level_completed.connect(func(s: int, c: int) -> void:
		result[0] = s
		result[1] = c)
	var builds_this_wave := 0
	var last_wave := 0
	var sim_time := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	# Startaufbau
	_bot_build(g, baked, strat, 99)
	g.start_next_wave()
	while result[0] < 0 and sim_time < 1200.0:
		await get_tree().process_frame
		sim_time += get_process_delta_time()
		if g.wave_manager.current_wave != last_wave:
			last_wave = g.wave_manager.current_wave
			if OS.has_environment("SIM_DEBUG"):
				var ids := []
				for st in g.build_manager.stations:
					ids.append("%s@%d" % [st.data.id, st.spot.index])
				print("  t=%.0f Welle %d Chaos %d Geld %d Freunde %d %s" % [sim_time, last_wave + 1, GameState.chaos, GameState.currency, g.friends_count, ids])
			builds_this_wave = 0
		match strat:
			"greedy":
				_bot_build(g, baked, strat, 99)
			"modest":
				if builds_this_wave < 1 and _bot_build(g, baked, strat, 1) > 0:
					builds_this_wave += 1
			"stress":
				if rng.randf() < 0.02:
					_bot_build(g, baked, "greedy", 1)
				if rng.randf() < 0.005 and not g.build_manager.stations.is_empty():
					g.build_manager.sell(g.build_manager.stations[rng.randi() % g.build_manager.stations.size()])
				if rng.randf() < 0.003:
					g.toggle_pause()
				if get_tree().paused and rng.randf() < 0.05:
					g.toggle_pause()
				if rng.randf() < 0.01:
					g.handle_tap(Vector2(rng.randf_range(0, 1920), rng.randf_range(0, 1080)))
	Engine.time_scale = 1.0
	get_tree().paused = false
	var line := "Level %d [%s]: %s, Sterne %d, Chaos %d, Freunde %d/%d, Stationen %d, Zeit %.0fs" % [
		n, strat, "GEWONNEN" if result[0] > 0 else ("VERLOREN" if result[0] == 0 else "TIMEOUT"),
		maxi(result[0], 0), result[1], g.friends_count, g.level.total_monsters(), g.build_manager.stations.size(), sim_time]
	print(line)
	_results.append(line)
	g.queue_free()
	await get_tree().process_frame


## Baut bis zu max_builds Stationen dort, wo sie am meisten nützen. Rückgabe: Anzahl gebaut.
func _bot_build(g: Game, baked: PackedVector2Array, strat: String, max_builds: int) -> int:
	var built := 0
	while built < max_builds:
		var demand := {}
		var first := maxi(g.wave_manager.current_wave, 0)
		if not g.wave_manager.spawning and g.wave_manager.has_next_wave() and g.wave_manager.current_wave >= 0:
			first += 1
		var weight := 1.0
		for wave in g.level.waves.slice(first):
			for e in wave.entries:
				var md := DataRegistry.monster(e.monster_id)
				demand[md.need_type] = demand.get(md.need_type, 0.0) + md.max_need * e.count * weight
			weight *= 0.4
		var supply := {}
		for st in g.build_manager.stations:
			for need in st.data.need_strengths:
				var per_s: float = st.data.need_strengths[need] * (1.0 if st.data.is_aura else 1.0 / st.data.cooldown)
				supply[int(need)] = supply.get(int(need), 0.0) + per_s * _coverage(st.position, st.get_range(), baked)
		var best_id: StringName = &""
		var best_score := 0.0
		for sid in g.level.available_station_ids:
			var sd := DataRegistry.station(sid)
			var score := 0.0
			for need in sd.supported_needs:
				var rate: float = sd.need_strengths[need] * (1.0 if sd.is_aura else 1.0 / sd.cooldown)
				score += demand.get(need, 0.0) / (1.0 + supply.get(need, 0.0)) * rate / sd.cost
			if score > best_score:
				best_score = score
				best_id = sid
		if best_id == &"":
			break
		var sd := DataRegistry.station(best_id)
		if not GameState.can_afford(sd.cost):
			break
		var best_spot: BuildSpot = null
		var best_cov := 0.0
		for s in g.build_manager.spots:
			if s.is_free():
				var cov := _coverage(s.position, sd.help_range, baked)
				if cov > best_cov:
					best_cov = cov
					best_spot = s
		if best_spot == null:
			# alle Plätze belegt: verbessern
			for st in g.build_manager.stations:
				if st.level < 2 and GameState.can_afford(st.data.upgrade_cost):
					g.build_manager.upgrade(st, &"power")
					built += 1
					break
			break
		if g.build_station(best_spot, best_id) == null:
			break
		built += 1
	return built


func _coverage(p: Vector2, r: float, baked: PackedVector2Array) -> float:
	var n := 0
	for q in baked:
		if q.distance_to(p) <= r:
			n += 1
	return n / 100.0

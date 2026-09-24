# Every map must be fair: from each spawn, a full-strength shot has to be able
# to reach every other spawn over whatever terrain sits between them.
#   godot --headless -s res://test/maps_reach.gd
extends SceneTree

const RADIUS := 40.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = root.get_node("G")  # the real autoload; script mode already created it
	var a = root.get_node("A")
	var main = load("res://src/main.gd").new()
	main.name = "Main"
	root.add_child(main)
	await process_frame
	var fails := 0
	for map_id in range(Terrain.MAPS.size()):
		var levels := [3] if map_id == 0 else [5]
		for lv in levels:
			for trial in range(6):
				g.settings["map"] = map_id
				main._start_battle(1, lv)
				await process_frame
				var b = main.screen
				var sp: Array = b.terrain.spawn_points
				for i in range(4):
					for j in range(i + 1, 4):
						if absf(sp[i].x - sp[j].x) < 200.0:
							fails += 1
							print("FAIL %s: spawns %d/%d too close" % [Terrain.MAPS[map_id]["name"], i, j])
				var worst := 0.0
				var unreachable := 0
				for s_i in range(4):
					for t_i in range(4):
						if s_i == t_i:
							continue
						var shooter = b.tanks[s_i]
						var target = b.tanks[t_i]
						shooter.personality = 0
						# Only the pair itself: this checks the terrain, not
						# whether a third tank happens to stand in the way.
						var pair := [shooter, target]
						var shot = AI._search(shooter, target, b.terrain, pair, 0.0, 0.0)
						var res = Sim.trace(shooter.barrel_tip_for(shot["angle"]), shot["angle"],
								shot["power"], 0.0, b.terrain, pair, shooter)
						var d: float = 0.0 if res["tank"] == target else res["impact"].distance_to(target.center())
						worst = maxf(worst, d)
						if d >= RADIUS:
							fails += 1
							unreachable += 1
							print("FAIL %s lv%d: tank %d cannot reach tank %d (best %.0f px)"
									% [Terrain.MAPS[map_id]["name"], lv, s_i, t_i, d])
				print("%-14s lv%-2d trial %d: %d/12 pairs reachable, worst miss %.0f px"
						% [Terrain.MAPS[map_id]["name"], lv, trial, 12 - unreachable, worst])
	print("MAPS REACH: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)

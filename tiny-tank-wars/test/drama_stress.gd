# Stress test for the "Ace" drama robot: across many random levels, its first
# seven shots must never damage anyone, and its later shots must connect.
#   godot --headless -s res://test/drama_stress.gd
extends SceneTree

const TRIALS := 40
const RADIUS := 40.0      # robots carry no upgrades
const BASE_DMG := 25.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = root.get_node("G")  # the real autoload; script mode already created it
	var a = root.get_node("A")
	var main = load("res://src/main.gd").new()
	main.name = "Main"
	root.add_child(main)
	await process_frame

	var early_damage_events := 0
	var late_damage_total := 0.0
	var late_hit_shots := 0
	var early_dists := []
	var late_dists := []
	var trials_run := 0

	for trial in range(TRIALS):
		var humans := 1 + (trial % 3)          # 1, 2 and 3 player games
		var level := 1 + (trial % 10)          # every level the showman appears on
		g.settings["map"] = trial % Terrain.MAPS.size()
		main._start_battle(humans, level)
		await process_frame
		var b = main.screen
		var ace = null
		for t in b.tanks:
			if t.drama:
				ace = t
		if ace == null:
			push_error("no drama robot at level %d" % level)
			continue
		trials_run += 1
		var target = AI.pick_target(ace, b.tanks)
		for shot_i in range(12):
			ace.shots_taken = shot_i
			var shot = AI.choose_shot(ace, b.tanks, b.terrain, b.eff_wind())
			var res = Sim.trace(ace.barrel_tip_for(shot["angle"]), shot["angle"],
					shot["power"], b.eff_wind(), b.terrain, b.tanks, ace)
			# Worst case over every living tank, not just the intended target:
			# a stray near miss must not clip a bystander either.
			var worst := 0.0
			for t in b.tanks:
				if not t.alive or t == ace:
					continue
				var d: float = 0.0 if res["tank"] == t else res["impact"].distance_to(t.center())
				var dmg: float = 0.0 if d >= RADIUS else floorf(BASE_DMG * (1.0 - d / RADIUS))
				worst = maxf(worst, dmg)
			var td: float = 0.0 if res["tank"] == target else res["impact"].distance_to(target.center())
			if shot_i < 7:
				early_dists.append(td)
				if worst > 0.0:
					early_damage_events += 1
					print("  MISS BROKEN level %d shot %d: %.0f dmg at %.0f px"
							% [level, shot_i + 1, worst, td])
			else:
				late_dists.append(td)
				late_damage_total += worst
				if worst > 0.0:
					late_hit_shots += 1

	var ea := 0.0
	for d in early_dists:
		ea += d
	ea /= maxf(1.0, float(early_dists.size()))
	var la := 0.0
	for d in late_dists:
		la += d
	la /= maxf(1.0, float(late_dists.size()))
	print("trials: %d   early shots: %d   late shots: %d" % [trials_run, early_dists.size(), late_dists.size()])
	print("mean distance  early: %.0f px   late: %.0f px" % [ea, la])
	print("late shots that connected: %d/%d   total damage: %d"
			% [late_hit_shots, late_dists.size(), int(late_damage_total)])
	var ok := true
	if early_damage_events != 0:
		print("FAIL: %d opening shots caused damage" % early_damage_events)
		ok = false
	if late_hit_shots < late_dists.size() / 2:
		print("FAIL: too few late shots connected")
		ok = false
	if la >= ea:
		print("FAIL: shots did not close in")
		ok = false
	print("DRAMA STRESS: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)

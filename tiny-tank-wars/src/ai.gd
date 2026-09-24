# AI aiming brains (GDD section 11), fair - they only use the same
# trajectory simulation a player could reason about, no cheating.
class_name AI

# How far from its target the "drama" robot lands its shot, by how many
# shots it has already taken. The first seven land close enough to be scary
# but outside the 40 px blast radius, so they do no damage at all. From the
# eighth shot on the gap closes and the hits start to hurt.
const DRAMA_MISS := [95.0, 88.0, 82.0, 75.0, 68.0, 60.0, 52.0, 34.0, 26.0, 18.0, 10.0]
const DRAMA_MISS_ROUNDS := 7  # shots that must stay harmless, however close
const DRAMA_SAFE_GAP := 48.0  # a guaranteed miss keeps at least this much room

# Returns {"angle": float, "power": float}
static func choose_shot(tank, all_tanks: Array, terrain, wind: float) -> Dictionary:
	var target = pick_target(tank, all_tanks)
	if target == null:
		return {"angle": 90.0, "power": 50.0}
	if tank.drama:
		return _drama(tank, target, terrain, all_tanks, wind)
	match tank.ai_tier:
		0:
			return _rookie(tank)
		1:
			return _semi_rookie(tank, target)
		2:
			return _cadet(tank, target, terrain, all_tanks, wind)
		_:
			return _veteran(tank, target, terrain, all_tanks, wind)

# Each robot is assigned its own human to duel (tank.target_seat). With two
# players that means one robot per player, so nobody feels ignored. Robots
# only fall back to another tank once their human is out.
static func pick_target(tank, all_tanks: Array):
	var enemies := []
	var humans := []
	for t in all_tanks:
		if t.alive and t != tank:
			enemies.append(t)
			if t.is_human:
				humans.append(t)
	if enemies.is_empty():
		return null
	if not humans.is_empty():
		for h in humans:
			if h.seat == tank.target_seat:
				return h
		return _nearest(tank, humans)
	return _nearest(tank, enemies)

static func _nearest(tank, candidates: Array):
	var best = candidates[0]
	for c in candidates:
		if absf(c.global_position.x - tank.global_position.x) \
				< absf(best.global_position.x - tank.global_position.x):
			best = c
	return best

static func _apply_personality(tank, shot: Dictionary) -> Dictionary:
	match tank.personality:
		1:  # High-Archer
			if shot["angle"] < 90.0:
				shot["angle"] = maxf(shot["angle"], 60.0)
			else:
				shot["angle"] = minf(shot["angle"], 120.0)
		2:  # Straight-Shooter
			if shot["angle"] < 90.0:
				shot["angle"] = minf(shot["angle"], 45.0)
			else:
				shot["angle"] = maxf(shot["angle"], 135.0)
		3:  # Power-Player
			shot["power"] = maxf(shot["power"], 80.0)
	shot["angle"] = clampf(shot["angle"], 5.0, 175.0)
	shot["power"] = clampf(shot["power"], 15.0, 100.0)
	return shot

static func _rookie(tank) -> Dictionary:
	return _apply_personality(tank, {
		"angle": randf_range(15.0, 165.0),
		"power": randf_range(20.0, 100.0),
	})

static func _semi_rookie(tank, target) -> Dictionary:
	# Aims toward the right side with a distance-based power guess, big error.
	var dx: float = target.global_position.x - tank.global_position.x
	var toward_right := dx > 0.0
	var base_angle := randf_range(35.0, 75.0)
	if not toward_right:
		base_angle = 180.0 - base_angle
	var guess_power: float = clampf(sqrt(absf(dx) * Sim.GRAVITY) / Sim.SPEED_PER_POWER, 25.0, 100.0)
	return _apply_personality(tank, {
		"angle": base_angle,
		"power": guess_power * randf_range(0.72, 1.28),
	})

static func _cadet(tank, target, terrain, all_tanks: Array, wind: float) -> Dictionary:
	var key := "t%d" % target.idx
	var shot: Dictionary
	if not tank.ai_memory.has(key):
		shot = _semi_rookie(tank, target)
		shot["power"] = clampf(shot["power"] * randf_range(0.85, 1.15), 15.0, 100.0)
	else:
		var mem: Dictionary = tank.ai_memory[key]
		var miss: float = target.global_position.x - mem["landing_x"]
		var dirv: float = 1.0 if mem["angle"] < 90.0 else -1.0
		var new_power: float = mem["power"] + clampf(miss * dirv * 0.055, -18.0, 18.0)
		shot = {
			"angle": mem["angle"] + randf_range(-6.0, 6.0),
			"power": new_power * randf_range(0.93, 1.07),
		}
	shot = _apply_personality(tank, shot)
	# Remember the predicted landing for next round's correction.
	var res := Sim.trace(tank.barrel_tip(), shot["angle"], shot["power"], wind,
			terrain, all_tanks, tank, 1.0 / 30.0)
	tank.ai_memory[key] = {
		"angle": shot["angle"], "power": shot["power"],
		"landing_x": res["impact"].x,
	}
	return shot

static func _veteran(tank, target, terrain, all_tanks: Array, wind: float) -> Dictionary:
	var best := _search(tank, target, terrain, all_tanks, wind, 0.0)
	var key := "vet_t%d" % target.idx
	if not tank.ai_memory.has(key):
		# First shot is a deliberate ranging shot: +-5% error (GDD 11).
		tank.ai_memory[key] = true
		best["angle"] = clampf(best["angle"] + randf_range(-6.0, 6.0), 5.0, 175.0)
		best["power"] = clampf(best["power"] * randf_range(0.95, 1.05) + randf_range(-3.0, 3.0), 15.0, 100.0)
	return best

# The star robot: a crack shot that keeps *just* missing, then slowly closes
# in. Built on the same search as the Veteran, but asked to land at a chosen
# distance from the target instead of on top of it.
static func _drama(tank, target, terrain, all_tanks: Array, wind: float) -> Dictionary:
	var i: int = tank.shots_taken
	var want: float = 0.0 if i >= DRAMA_MISS.size() else DRAMA_MISS[i]
	# Only the opening shots are forced to stay harmless. After that the
	# schedule walks the impact inside the blast radius on purpose, so the
	# damage ramps up shot by shot instead of staying a permanent tease.
	return _search(tank, target, terrain, all_tanks, wind, want, i < DRAMA_MISS_ROUNDS)

# Grid-search angle/power for the shot whose predicted impact lands closest
# to `want` pixels from the target (0 = hit it). Terrain is respected because
# a blocked shot simply impacts the hillside and scores badly.
#
# Two passes: a cheap coarse sweep to rank the field, then a full-resolution
# re-check of the best handful. The fine pass matters - it runs at the same
# Sim.DT the real shell flies at, so a planned near miss really does miss.
static func _search(tank, target, terrain, all_tanks: Array, wind: float,
		want := 0.0, must_miss := false) -> Dictionary:
	var tpos: Vector2 = target.center()
	var toward_right: bool = tpos.x > tank.center().x
	var coarse := []
	for ai in range(14):
		var ang := 22.0 + float(ai) * 4.6   # 22..82
		if not toward_right:
			ang = 180.0 - ang
		var eff_ang: float = ang if toward_right else 180.0 - ang
		if tank.personality == 1 and eff_ang < 55.0:
			continue
		if tank.personality == 2 and eff_ang > 50.0:
			continue
		for pi_ in range(16):
			var pw := 25.0 + float(pi_) * 5.0  # 25..100
			var res := Sim.trace(tank.barrel_tip_for(ang), ang, pw, wind,
					terrain, all_tanks, tank, 1.0 / 30.0)
			var dist: float = res["impact"].distance_to(tpos)
			if res["tank"] == target:
				dist = 0.0
			coarse.append({"err": absf(dist - want), "angle": ang, "power": pw})
	if coarse.is_empty():
		return {"angle": 60.0 if toward_right else 120.0, "power": 60.0}
	coarse.sort_custom(func(a, b): return a["err"] < b["err"])
	# Re-check the most promising shots at full resolution.
	var fine := []
	for i in range(mini(14, coarse.size())):
		var c: Dictionary = coarse[i]
		var res := Sim.trace(tank.barrel_tip_for(c["angle"]), c["angle"], c["power"],
				wind, terrain, all_tanks, tank)
		var dist: float = res["impact"].distance_to(tpos)
		if res["tank"] == target:
			dist = 0.0
		# A shot promised to miss must still miss after the exact simulation.
		if must_miss and dist < DRAMA_SAFE_GAP:
			continue
		fine.append({"err": absf(dist - want), "angle": c["angle"], "power": c["power"]})
	if fine.is_empty():
		# Nothing safe among the best shots: fall back to the coarse pick that
		# was furthest from the target, which is the safest miss available.
		var safest: Dictionary = coarse[coarse.size() - 1] if must_miss else coarse[0]
		return {"angle": safest["angle"], "power": safest["power"]}
	fine.sort_custom(func(a, b): return a["err"] < b["err"])
	# Vary which near-miss is chosen so the shots land on different sides
	# instead of repeating the same arc every round. The tolerance is wide
	# while missing on purpose and tight once the shots are meant to connect.
	if want > 0.0:
		var tol: float = 14.0 if must_miss else 5.0
		var pool := []
		for c in fine:
			if c["err"] <= fine[0]["err"] + tol:
				pool.append(c)
		var pick: Dictionary = pool[randi() % pool.size()]
		if must_miss:
			return {"angle": pick["angle"], "power": pick["power"]}
		return _refine(tank, target, terrain, all_tanks, wind, pick, want)
	return _refine(tank, target, terrain, all_tanks, wind, fine[0], want)

# Nudge the power of a chosen shot until it lands as close to `want` as the
# exact simulation allows. The search grid moves in 5% power steps, which on
# a steep lob over a mountain or pillar shifts the landing by ~35 px - wider
# than a direct hit - so without this the robots could only ever splash.
static func _refine(tank, target, terrain, all_tanks: Array, wind: float,
		shot: Dictionary, want: float) -> Dictionary:
	var best_ang: float = shot["angle"]
	var best_pw: float = shot["power"]
	var best_err := _fine_err(tank, target, terrain, all_tanks, wind, best_ang, best_pw, want)
	var step_pw := 2.5
	var step_ang := 2.3   # half the grid spacing, so the gap between rows is covered
	for i in range(8):
		if best_err < 2.0:
			break
		var improved := false
		for d in [Vector2(0, -step_pw), Vector2(0, step_pw), Vector2(-step_ang, 0), Vector2(step_ang, 0)]:
			var ang: float = clampf(best_ang + d.x, 5.0, 175.0)
			var pw: float = clampf(best_pw + d.y, 15.0, 100.0)
			var e := _fine_err(tank, target, terrain, all_tanks, wind, ang, pw, want)
			if e < best_err:
				best_err = e
				best_ang = ang
				best_pw = pw
				improved = true
		if not improved:
			step_pw *= 0.5
			step_ang *= 0.5
	return {"angle": best_ang, "power": best_pw}

static func _fine_err(tank, target, terrain, all_tanks: Array, wind: float,
		ang: float, pw: float, want: float) -> float:
	var res := Sim.trace(tank.barrel_tip_for(ang), ang, pw, wind, terrain, all_tanks, tank)
	var d: float = 0.0 if res["tank"] == target else res["impact"].distance_to(target.center())
	return absf(d - want)

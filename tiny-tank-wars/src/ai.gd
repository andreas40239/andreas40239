# AI aiming brains (GDD section 11), fair - they only use the same
# trajectory simulation a player could reason about, no cheating.
class_name AI

# Returns {"angle": float, "power": float}
static func choose_shot(tank, all_tanks: Array, terrain, wind: float) -> Dictionary:
	var enemies := []
	for t in all_tanks:
		if t.alive and t != tank:
			enemies.append(t)
	if enemies.is_empty():
		return {"angle": 90.0, "power": 50.0}
	# Nearest enemy is the target.
	var target = enemies[0]
	for e in enemies:
		if absf(e.global_position.x - tank.global_position.x) < absf(target.global_position.x - tank.global_position.x):
			target = e
	match tank.ai_tier:
		0:
			return _rookie(tank)
		1:
			return _semi_rookie(tank, target)
		2:
			return _cadet(tank, target, terrain, all_tanks, wind)
		_:
			return _veteran(tank, target, terrain, all_tanks, wind)

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
	var start: Vector2 = tank.center()
	var tpos: Vector2 = target.center()
	var best := {"angle": 60.0, "power": 60.0}
	var best_err := 1e18
	var toward_right: bool = tpos.x > start.x
	# Coarse grid search over arcs toward the target (respects terrain because
	# the simulation stops at hills).
	for ai in range(14):
		var ang := 22.0 + float(ai) * 4.6   # 22..82
		if not toward_right:
			ang = 180.0 - ang
		if tank.personality == 1 and (ang if toward_right else 180.0 - ang) < 55.0:
			continue
		if tank.personality == 2 and (ang if toward_right else 180.0 - ang) > 50.0:
			continue
		for pi_ in range(16):
			var pw := 25.0 + float(pi_) * 5.0  # 25..100
			var res := Sim.trace(start, ang, pw, wind, terrain, all_tanks, tank, 1.0 / 30.0)
			var err: float = res["impact"].distance_to(tpos)
			if res["tank"] == target:
				err = 0.0
			if err < best_err:
				best_err = err
				best = {"angle": ang, "power": pw}
	var key := "vet_t%d" % target.idx
	if not tank.ai_memory.has(key):
		# First shot is a deliberate ranging shot: +-5% error (GDD 11).
		tank.ai_memory[key] = true
		best["angle"] = clampf(best["angle"] + randf_range(-6.0, 6.0), 5.0, 175.0)
		best["power"] = clampf(best["power"] * randf_range(0.95, 1.05) + randf_range(-3.0, 3.0), 15.0, 100.0)
	return best

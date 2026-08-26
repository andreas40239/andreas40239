# Shared trajectory math (GDD section 8). Used by the aim preview,
# the exact Arc Toggle path, the AI and the live projectiles.
class_name Sim

const GRAVITY := 400.0        # px/s^2
const SPEED_PER_POWER := 9.0  # 100% power -> 900 px/s
const WIND_ACCEL := 3.0       # wind unit -> px/s^2
const TANK_RADIUS := 26.0

static func launch_velocity(angle_deg: float, power: float) -> Vector2:
	var sp := power * SPEED_PER_POWER
	var a := deg_to_rad(angle_deg)
	return Vector2(cos(a) * sp, -sin(a) * sp)

# Simulate a full flight. Returns:
#   points: PackedVector2Array of the path
#   impact: Vector2 where it explodes
#   tank:   the Tank hit directly (or null)
#   lost:   true when the shot left the world and fizzled
static func trace(start: Vector2, angle_deg: float, power: float, wind: float,
		terrain, tanks: Array, shooter, dt := 1.0 / 60.0, max_t := 10.0) -> Dictionary:
	var pos := start
	var vel := launch_velocity(angle_deg, power)
	var pts := PackedVector2Array()
	var t := 0.0
	var left_start := false
	while t < max_t:
		vel.x += wind * WIND_ACCEL * dt
		vel.y += GRAVITY * dt
		pos += vel * dt
		t += dt
		pts.append(pos)
		if not left_start and pos.distance_to(start) > TANK_RADIUS + 14.0:
			left_start = true
		# Direct tank hits (never the shooter until the shell has left its muzzle area).
		for tk in tanks:
			if not tk.alive:
				continue
			if tk == shooter and not left_start:
				continue
			if pos.distance_to(tk.center()) <= TANK_RADIUS:
				return {"points": pts, "impact": pos, "tank": tk, "lost": false}
		# Ground hit.
		if pos.y >= terrain.ground_y(pos.x):
			pos.y = terrain.ground_y(pos.x)
			return {"points": pts, "impact": pos, "tank": null, "lost": false}
		# Left the world sideways far enough - lost shot.
		if pos.x < -300.0 or pos.x > terrain.WORLD_W + 300.0 or pos.y > 1500.0:
			return {"points": pts, "impact": pos, "tank": null, "lost": true}
	return {"points": pts, "impact": pos, "tank": null, "lost": true}

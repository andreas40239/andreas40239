# Cannonball with custom kinematics (no physics bodies, GDD section 16).
class_name Projectile
extends Node2D

signal impact(pos: Vector2, direct_tank, lost: bool)

var vel := Vector2.ZERO
var wind := 0.0
var terrain
var tanks: Array = []
var shooter
var done := false
var _left_start := false
var _t := 0.0
var _trail := PackedVector2Array()

func launch(from: Vector2, angle_deg: float, power: float, p_wind: float,
		p_terrain, p_tanks: Array, p_shooter) -> void:
	position = from
	vel = Sim.launch_velocity(angle_deg, power)
	wind = p_wind
	terrain = p_terrain
	tanks = p_tanks
	shooter = p_shooter

func _physics_process(delta: float) -> void:
	if done:
		return
	# Substeps keep fast shells from tunneling through hilltops.
	var steps := 3
	var dt := delta / float(steps)
	for s in range(steps):
		vel.x += wind * Sim.WIND_ACCEL * dt
		vel.y += Sim.GRAVITY * dt
		position += vel * dt
		_t += dt
		if not _left_start and position.distance_to(shooter.center()) > Sim.TANK_RADIUS + 14.0:
			_left_start = true
		for tk in tanks:
			if not tk.alive:
				continue
			if tk == shooter and not _left_start:
				continue
			if position.distance_to(tk.center()) <= Sim.TANK_RADIUS:
				_finish(position, tk, false)
				return
		if position.y >= terrain.ground_y(position.x):
			position.y = terrain.ground_y(position.x)
			_finish(position, null, false)
			return
		if position.x < -300.0 or position.x > terrain.WORLD_W + 300.0 \
				or position.y > 1500.0 or _t > 12.0:
			_finish(position, null, true)
			return
	_trail.append(position)
	if _trail.size() > 14:
		_trail.remove_at(0)
	queue_redraw()

func _finish(pos: Vector2, tk, lost: bool) -> void:
	done = true
	impact.emit(pos, tk, lost)
	queue_free()

func _draw() -> void:
	for i in range(_trail.size()):
		var a := float(i) / float(maxi(1, _trail.size()))
		draw_circle(to_local(_trail[i]), 2.0 + a * 3.0, Color(1.0, 0.85, 0.5, a * 0.5))
	draw_circle(Vector2.ZERO, 8.0, Color(0.25, 0.28, 0.36))
	draw_circle(Vector2(-2.5, -2.5), 2.6, Color(1, 1, 1, 0.55))

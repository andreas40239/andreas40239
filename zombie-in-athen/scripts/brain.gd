class_name Brain
extends RefCounted
## Basis für die KI: Wegverfolgung auf dem Zellraster.

var c: Character
var game
var walk_slow := false
var rng := RandomNumberGenerator.new()
var _path := PackedVector3Array()
var _pi := 0
var _goal := Vector3.ZERO
var _has_goal := false
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO


func _init(p_char: Character, p_game) -> void:
	c = p_char
	game = p_game
	rng.seed = hash(p_char.cname) + p_game.apt.seed_used


func go_to(pos: Vector3) -> void:
	_goal = Vector3(pos.x, 0, pos.z)
	_has_goal = true
	_path = game.nav.path(c.global_position, _goal)
	_pi = 0
	_stuck_t = 0.0
	_last_pos = c.global_position


func stop() -> void:
	_has_goal = false
	c.move_dir = Vector3.ZERO


func arrived() -> bool:
	return not _has_goal


func goal() -> Vector3:
	return _goal


## Setzt c.move_dir in Richtung des nächsten Wegpunkts.
func follow(delta: float) -> void:
	if not _has_goal or _pi >= _path.size():
		stop()
		return
	var p := c.global_position
	# Wegpunkte überspringen, wenn der übernächste direkt erreichbar ist
	while _pi + 1 < _path.size() and game.nav.walk_clear(p, _path[_pi + 1]):
		_pi += 1
	var wp := _path[_pi]
	var d := Vector3(wp.x - p.x, 0, wp.z - p.z)
	if d.length() < maxf(0.18, c.current_speed() * delta * 0.75):
		_pi += 1
		if _pi >= _path.size():
			stop()
			return
		wp = _path[_pi]
		d = Vector3(wp.x - p.x, 0, wp.z - p.z)
	c.move_dir = d.normalized()
	_stuck_t += delta
	if _stuck_t > 0.7:
		if p.distance_to(_last_pos) < 0.12:
			# festgefahren: über die Zellmitte neu planen
			var cc := Nav.center(game.nav.nearest_free(p))
			_path = game.nav.path(cc, _goal)
			_path.insert(0, cc)
			_pi = 0
		_last_pos = p
		_stuck_t = 0.0

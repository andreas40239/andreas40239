class_name Dog
extends CharacterBody3D
## Biscuit, the allotment dog. Dogs hunt mostly by SMELL: a bush only helps
## while the dog is not right next to it, but a compost heap (or a hedgehog
## house) hides your smell completely. A rolled-up hedgehog gets a bark, a
## careful nudge, an "ouch!", and the dog gives up. Nudge a ball and the dog
## runs off to play with it.

enum State { PATROL, SNIFF, CHASE, BARK, PLAY, BORED }

## Node whose Node3D children are the patrol waypoints, visited in order.
@export var patrol_path: NodePath
@export var dog_name := "Biscuit"
@export var fur_color := Color(0.85, 0.68, 0.42)
@export var walk_speed := 1.5
@export var sniff_speed := 1.1
@export var chase_speed := 2.6
@export var smell_range := 5.0
## How close the dog must be to smell a hedgehog hiding in a bush.
@export var smell_range_in_bush := 1.6
@export var vision_range := 8.0
@export_range(10.0, 180.0) var vision_angle_degrees := 80.0
## Seconds of sniffing before the dog is sure and gives chase.
@export var notice_time := 1.6
@export var catch_distance := 0.6
@export var give_up_time := 4.0
@export var bored_time := 8.0
@export var play_time := 9.0

const BARK_TIME := 1.8

var state := State.PATROL
var detection := 0.0

var _points: Array[Vector3] = []
var _point_index := 0
var _timer := 0.0
var _unsensed_time := 0.0
var _last_known := Vector3.ZERO
var _time := 0.0
var _player: Hedgehog
var _ball: Node3D
var _visual: Node3D
var _tail: Node3D
var _label: Label3D
var _sniff_sound_timer := 0.0
var _yelped := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("animals")
	add_to_group("dogs")
	collision_layer = 4
	collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.36, 0.6, 0.8)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.3
	add_child(collision)
	_build_visual()

	var path := get_node_or_null(patrol_path)
	if path:
		for child in path.get_children():
			if child is Node3D:
				_points.append(child.global_position)
	if _points.is_empty():
		_points.append(global_position)

	var scent := Scent.new()
	scent.color = Scent.DANGER
	add_child(scent)


## Called (via the "dogs" group) when the hedgehog nudges a ball.
func chase_ball(ball: Node3D) -> void:
	if ball.global_position.distance_to(global_position) > 25.0:
		return
	_ball = ball
	_set_state(State.PLAY)


func _physics_process(delta: float) -> void:
	_time += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Hedgehog
		if _player == null:
			return
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var senses := _can_sense(_player)
	if senses:
		_last_known = _player.global_position
		_unsensed_time = 0.0
	else:
		_unsensed_time += delta
	var player_distance := _flat_distance(_player.global_position)
	var desired := Vector3.ZERO

	match state:
		State.PATROL:
			desired = _patrol(walk_speed)
			if senses:
				_set_state(State.SNIFF)

		State.SNIFF:
			# Nose down, following the scent towards the hedgehog.
			desired = _walk_towards(_last_known, sniff_speed)
			if senses:
				detection += delta / notice_time * (1.5 if _can_see(_player) else 1.0)
			else:
				detection -= delta * 0.4
			if detection >= 1.0:
				_set_state(State.CHASE)
			elif detection <= 0.0:
				_set_state(State.PATROL)

		State.CHASE:
			var target := _player.global_position if senses else _last_known
			desired = _walk_towards(target, chase_speed)
			if _player.is_rolled and player_distance < 1.3:
				_set_state(State.BARK)
			elif player_distance < catch_distance and _player.try_catch():
				_set_state(State.BORED)
			elif _unsensed_time > give_up_time:
				detection = 0.5
				_set_state(State.SNIFF)

		State.BARK:
			# Barks at the spiky ball, nudges it... ouch! Then backs off.
			_timer += delta
			_face(_player.global_position - global_position, delta)
			if _timer > BARK_TIME and not _yelped:
				_yelped = true
				Sound.play_at("yelp", global_position, 0.0, 0.05, 30.0)
				Game.show_toast("Ouch! %s got a spiky nose and gives up." % dog_name)
			if _timer > BARK_TIME:
				desired = (global_position - _player.global_position).normalized() * walk_speed
				desired.y = 0.0
			if _timer > BARK_TIME + 1.2:
				_set_state(State.BORED)

		State.PLAY:
			if _ball == null:
				_set_state(State.PATROL)
			else:
				_timer += delta
				if _flat_distance(_ball.global_position) > 0.7:
					desired = _walk_towards(_ball.global_position, chase_speed)
				if _timer > play_time:
					_ball = null
					_set_state(State.PATROL)

		State.BORED:
			_timer -= delta
			desired = _patrol(walk_speed * 0.7)
			if _timer <= 0.0:
				_set_state(State.PATROL)

	_update_sounds(delta)
	velocity.x = desired.x
	velocity.z = desired.z
	move_and_slide()
	if desired.length() > 0.1:
		_face(desired, delta)
	_update_visual(delta, desired)


## Smell (blocked only by compost heaps and hedgehog houses; a bush just
## means the dog has to be very close) or sight.
func _can_sense(player: Hedgehog) -> bool:
	if player.is_sleeping or player.is_scent_masked():
		return false
	var distance := _flat_distance(player.global_position)
	var smell := smell_range_in_bush if player.is_hidden() else smell_range
	if distance < smell:
		return true
	return _can_see(player)


func _can_see(player: Hedgehog) -> bool:
	if player.is_hidden():
		return false
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	if distance > vision_range:
		return false
	var forward := global_transform.basis.z
	forward.y = 0.0
	if distance > 0.3 and forward.angle_to(to_player) > deg_to_rad(vision_angle_degrees) * 0.5:
		return false
	var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 0.5, player.global_position + Vector3.UP * 0.15, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _set_state(new_state: State) -> void:
	var old_state := state
	state = new_state
	_timer = 0.0
	match new_state:
		State.PATROL:
			detection = 0.0
		State.CHASE:
			detection = 1.0
			_unsensed_time = 0.0
			Sound.play_at("woof", global_position, 0.0, 0.05, 40.0)
			Game.unlock_fact("dog")
			if old_state == State.SNIFF:
				Game.show_toast("%s smelled you! Hide in a compost heap or roll up!" % dog_name)
		State.BARK:
			_yelped = false
			Sound.play_at("woof", global_position, 0.0, 0.05, 40.0)
		State.PLAY:
			Sound.play_at("woof", global_position, -4.0, 0.15, 40.0)
			Game.unlock_fact("ball")
		State.BORED:
			detection = 0.0
			_timer = bored_time


func _update_sounds(delta: float) -> void:
	if state == State.SNIFF:
		_sniff_sound_timer -= delta
		if _sniff_sound_timer <= 0.0:
			_sniff_sound_timer = randf_range(0.7, 1.0)
			Sound.play_at("snuffle", global_position, 0.0, 0.1, 20.0)


func _patrol(speed: float) -> Vector3:
	var target := _points[_point_index]
	if _flat_distance(target) < 0.5:
		_point_index = (_point_index + 1) % _points.size()
		target = _points[_point_index]
	return _walk_towards(target, speed)


func _walk_towards(target: Vector3, speed: float) -> Vector3:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		return Vector3.ZERO
	return direction.normalized() * speed


func _face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-8.0 * delta))


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _update_visual(delta: float, desired: Vector3) -> void:
	# Tail wags faster when happy (playing) and when chasing.
	var wag_speed := 18.0 if state == State.PLAY or state == State.CHASE else 6.0
	_tail.rotation.y = sin(_time * wag_speed) * 0.6
	# Nose down while sniffing, a little bounce while running.
	var nose_down := 0.25 if state == State.SNIFF else 0.0
	_visual.rotation.x = lerpf(_visual.rotation.x, nose_down, 1.0 - exp(-8.0 * delta))
	_visual.position.y = absf(sin(_time * 12.0)) * 0.05 * minf(desired.length() / chase_speed, 1.0)

	match state:
		State.SNIFF:
			_set_label("?", Color(1.0, 0.85, 0.2), 0.6 + detection * 0.6)
		State.CHASE:
			_set_label("!", Color(1.0, 0.25, 0.2), 1.2)
		State.BARK:
			_set_label("ouch!" if _yelped else "WOOF", Color(1.0, 0.6, 0.3), 0.8)
		State.PLAY:
			_set_label("yay!", Color(0.5, 1.0, 0.5), 0.8)
		_:
			_label.text = ""
	_label.position.y = 1.05 + sin(_time * 4.0) * 0.03


func _set_label(text: String, color: Color, size: float) -> void:
	_label.text = text
	_label.modulate = color
	_label.scale = Vector3.ONE * size


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var fur := fur_color
	var dark := fur_color.darkened(0.35)
	MeshUtil.add(_visual, MeshUtil.capsule(0.17, 0.75), fur, Vector3(0, 0.4, 0), Vector3.ONE, Vector3(PI / 2, 0, 0))
	MeshUtil.add(_visual, MeshUtil.sphere(0.16), fur, Vector3(0, 0.6, 0.42))
	MeshUtil.add(_visual, MeshUtil.box(Vector3(0.12, 0.1, 0.18)), fur.lightened(0.2), Vector3(0, 0.55, 0.58))
	MeshUtil.add(_visual, MeshUtil.sphere(0.035), Color(0.05, 0.04, 0.04), Vector3(0, 0.58, 0.67))
	for side in [-1.0, 1.0]:
		# Floppy ears, eyes and legs.
		MeshUtil.add(_visual, MeshUtil.sphere(0.07), dark, Vector3(side * 0.14, 0.6, 0.38), Vector3(0.5, 1.4, 0.9), Vector3(0, 0, side * 0.3))
		MeshUtil.add(_visual, MeshUtil.sphere(0.022), Color(0.08, 0.06, 0.05), Vector3(side * 0.07, 0.66, 0.54))
		for front in [-1.0, 1.0]:
			MeshUtil.add(_visual, MeshUtil.cylinder(0.05, 0.05, 0.3), fur, Vector3(side * 0.1, 0.15, front * 0.24))
			MeshUtil.add(_visual, MeshUtil.sphere(0.055), fur.lightened(0.3), Vector3(side * 0.1, 0.03, front * 0.24 + 0.02))
	MeshUtil.add(_visual, MeshUtil.cylinder(0.13, 0.13, 0.04), Color(0.2, 0.4, 0.85), Vector3(0, 0.52, 0.32), Vector3.ONE, Vector3(1.2, 0, 0))
	MeshUtil.merge(_visual)

	# The tail wags, so it stays a separate piece.
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.5, -0.45)
	_visual.add_child(_tail)
	MeshUtil.add(_tail, MeshUtil.cylinder(0.025, 0.045, 0.35), fur, Vector3(0, 0.12, -0.08), Vector3.ONE, Vector3(-0.7, 0, 0))
	MeshUtil.merge(_tail)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 96
	_label.outline_size = 12
	_label.pixel_size = 0.004
	_label.no_depth_test = true
	_label.position.y = 1.05
	add_child(_label)

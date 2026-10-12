class_name Cat
extends CharacterBody3D
## A curious garden cat. It patrols, notices the hedgehog ("?"), stalks it
## ("!"), crouches and pounces. A rolled-up hedgehog is too spiky, so the
## cat gets bored and wanders off. Hiding breaks the cat's line of sight.

enum State { PATROL, SUSPICIOUS, STALK, POUNCE, BORED, SEARCH }

## Node whose Node3D children are the patrol waypoints, visited in order.
@export var patrol_path: NodePath
@export var fur_color := Color(0.9, 0.55, 0.22)
@export var walk_speed := 1.3
@export var stalk_speed := 1.1
@export var pounce_speed := 5.0
@export var vision_range := 7.0
@export_range(10.0, 180.0) var vision_angle_degrees := 110.0
## Seconds the hedgehog must be in plain view (up close) before the cat stalks.
@export var notice_time := 1.0
@export var pounce_distance := 1.6
@export var catch_distance := 0.5
@export var bored_time := 7.0
## A sleeping cat ignores everything until wake_up() (used by the tutorial).
@export var asleep := false
## Eyes that shine in the dark (for night gardens).
@export var glowing_eyes := false

const POUNCE_WINDUP := 0.4
const POUNCE_DURATION := 0.8

var state := State.PATROL
var detection := 0.0

var _points: Array[Vector3] = []
var _point_index := 0
var _timer := 0.0
var _unseen_time := 0.0
var _last_known := Vector3.ZERO
var _pounce_target := Vector3.ZERO
var _time := 0.0
var _player: Hedgehog
var _visual: Node3D
var _label: Label3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _purr: AudioStreamPlayer3D
var glow_eyes: Array = []
var _bell_timer := 0.0
var _meow_cooldown := 0.0


func _ready() -> void:
	add_to_group("animals")
	collision_layer = 4
	collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 0.55, 0.6)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.275
	add_child(collision)
	_build_visual()
	_purr = Sound.attach_loop("purr", self, -10.0, 10.0)

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


func _physics_process(delta: float) -> void:
	_time += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Hedgehog
		if _player == null:
			return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if asleep:
		if not _purr.playing:
			_purr.play()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_update_visual(delta)
		return

	var senses := _can_sense(_player)
	if senses:
		_last_known = _player.global_position
		_unseen_time = 0.0
	else:
		_unseen_time += delta
	var player_distance := _flat_distance(_player.global_position)
	var desired := Vector3.ZERO

	match state:
		State.PATROL:
			desired = _patrol()
			if senses:
				_set_state(State.SUSPICIOUS)

		State.SUSPICIOUS:
			_face(_last_known - global_position, delta)
			if senses:
				var closeness := clampf(1.5 - player_distance / vision_range, 0.4, 1.5)
				detection += delta / notice_time * closeness
			else:
				detection -= delta * 0.5
			if detection >= 1.0:
				_set_state(State.STALK)
			elif detection <= 0.0:
				_set_state(State.PATROL)

		State.STALK:
			desired = _walk_towards(_last_known, stalk_speed)
			if _player.is_rolled and player_distance < 1.0:
				_get_bored()
			elif senses and player_distance < pounce_distance:
				_set_state(State.POUNCE)
			elif _unseen_time > 2.0:
				_set_state(State.SEARCH)

		State.POUNCE:
			_timer += delta
			if _timer < POUNCE_WINDUP:
				_face(_pounce_target - global_position, delta)
			else:
				desired = _walk_towards(_pounce_target, pounce_speed)
				if player_distance < catch_distance:
					if _player.is_rolled:
						_get_bored()
					elif _player.try_catch():
						_get_bored()
			if state == State.POUNCE and _timer > POUNCE_WINDUP + POUNCE_DURATION:
				if _player.is_rolled and player_distance < 1.2:
					_get_bored()
				else:
					_set_state(State.STALK)

		State.BORED:
			_timer -= delta
			if _timer > bored_time - 1.5:
				_face(_player.global_position - global_position, delta)  # Pawing at the spiky ball.
			else:
				desired = _patrol() * 0.6
			if _timer <= 0.0:
				_set_state(State.PATROL)

		State.SEARCH:
			_timer += delta
			if _flat_distance(_last_known) > 0.4:
				desired = _walk_towards(_last_known, walk_speed)
			else:
				rotation.y += delta * 1.5  # Looking around.
			if senses:
				detection = 0.5
				_set_state(State.SUSPICIOUS)
			elif _timer > 4.0:
				_set_state(State.PATROL)

	_update_sounds(delta, desired)
	velocity.x = desired.x
	velocity.z = desired.z
	move_and_slide()
	if desired.length() > 0.1:
		_face(desired, delta)
	_update_visual(delta)


## Whether the cat can see or hear the hedgehog right now.
func _can_sense(player: Hedgehog) -> bool:
	if player.is_hidden() or player.is_sleeping:
		return false
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	if distance < player.noise_radius():
		return true
	if distance > vision_range:
		return false
	var forward := global_transform.basis.z
	forward.y = 0.0
	if distance > 0.3 and forward.angle_to(to_player) > deg_to_rad(vision_angle_degrees) * 0.5:
		return false
	return _has_line_of_sight(player)


func _has_line_of_sight(player: Hedgehog) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 0.4, player.global_position + Vector3.UP * 0.15, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func wake_up() -> void:
	if not asleep:
		return
	asleep = false
	_purr.stop()
	Sound.play_at("meow_sleepy", global_position, 0.0, 0.05, 40.0)
	_set_state(State.PATROL)


## The collar bell jingles as the cat walks (a handy warning!), it meows
## when it notices something, hisses as it pounces and says "meh" when bored.
func _update_sounds(delta: float, desired: Vector3) -> void:
	_meow_cooldown = maxf(_meow_cooldown - delta, 0.0)
	if desired.length() > 0.3:
		_bell_timer -= delta
		if _bell_timer <= 0.0:
			_bell_timer = randf_range(0.9, 1.6) * (2.0 if state == State.STALK else 1.0)
			Sound.play_at("bell", global_position + Vector3.UP * 0.35, -10.0, 0.1, 18.0)

func _set_state(new_state: State) -> void:
	var old_state := state
	state = new_state
	_timer = 0.0
	match new_state:
		State.SUSPICIOUS:
			if old_state == State.PATROL and _meow_cooldown <= 0.0:
				_meow_cooldown = 6.0
				Sound.play_at("meow", global_position, -2.0, 0.1, 35.0)
		State.PATROL:
			detection = 0.0
		State.STALK:
			detection = 1.0
			_unseen_time = 0.0
		State.POUNCE:
			var direction := (_last_known - global_position)
			direction.y = 0.0
			_pounce_target = _last_known + direction.normalized() * 0.4
			Sound.play_at("hiss", global_position, -4.0, 0.1, 25.0)
		State.BORED:
			detection = 0.0
			_timer = bored_time
			Sound.play_at("meh", global_position, -2.0, 0.08, 25.0)


func _get_bored() -> void:
	if _player.is_rolled:
		Game.show_toast("Too spiky! The cat loses interest.")
	_set_state(State.BORED)


func _patrol() -> Vector3:
	var target := _points[_point_index]
	if _flat_distance(target) < 0.4:
		_point_index = (_point_index + 1) % _points.size()
		target = _points[_point_index]
	return _walk_towards(target, walk_speed)


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


func _update_visual(delta: float) -> void:
	var crouch := 1.0
	var hop := 0.0
	if asleep:
		crouch = 0.6
		_label.text = "zzz"
		_label.modulate = Color(0.8, 0.85, 1.0)
		_label.scale = Vector3.ONE * 0.8
		_visual.scale.y = lerpf(_visual.scale.y, crouch, 1.0 - exp(-10.0 * delta))
		_label.position.y = 0.75 + sin(_time * 2.0) * 0.05
		return
	match state:
		State.STALK:
			crouch = 0.8
		State.POUNCE:
			if _timer < POUNCE_WINDUP:
				crouch = 0.65
			else:
				var t := clampf((_timer - POUNCE_WINDUP) / 0.4, 0.0, 1.0)
				hop = sin(t * PI) * 0.25
	_visual.scale.y = lerpf(_visual.scale.y, crouch, 1.0 - exp(-10.0 * delta))
	_visual.position.y = hop

	match state:
		State.SUSPICIOUS:
			_label.text = "?"
			_label.modulate = Color(1.0, 0.85, 0.2)
			_label.scale = Vector3.ONE * (0.6 + detection * 0.6)
		State.STALK, State.POUNCE:
			_label.text = "!"
			_label.modulate = Color(1.0, 0.25, 0.2)
			_label.scale = Vector3.ONE * 1.2
		State.SEARCH:
			_label.text = "?"
			_label.modulate = Color(0.8, 0.8, 0.8)
			_label.scale = Vector3.ONE * 0.8
		State.BORED:
			_label.text = "meh"
			_label.modulate = Color(0.8, 0.8, 0.9)
			_label.scale = Vector3.ONE * 0.8
		_:
			_label.text = ""
	_label.position.y = 0.95 + sin(_time * 4.0) * 0.03


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var fur := fur_color
	var light := fur_color.lightened(0.4)
	MeshUtil.add(_visual, MeshUtil.capsule(0.13, 0.55), fur, Vector3(0, 0.3, 0), Vector3.ONE, Vector3(PI / 2, 0, 0))
	MeshUtil.add(_visual, MeshUtil.sphere(0.12), fur, Vector3(0, 0.45, 0.3))
	MeshUtil.add(_visual, MeshUtil.sphere(0.06), light, Vector3(0, 0.41, 0.39), Vector3(1.2, 0.8, 0.8))
	MeshUtil.add(_visual, MeshUtil.sphere(0.015), Color(0.9, 0.5, 0.5), Vector3(0, 0.43, 0.44))
	for side in [-1.0, 1.0]:
		MeshUtil.add(_visual, MeshUtil.cylinder(0.0, 0.045, 0.1), fur, Vector3(side * 0.07, 0.58, 0.29), Vector3.ONE, Vector3(0, 0, -side * 0.25))
		var eye := MeshUtil.add(_visual, MeshUtil.sphere(0.022 if not glowing_eyes else 0.028), Color(0.35, 0.75, 0.25), Vector3(side * 0.05, 0.48, 0.4))
		if glowing_eyes:
			var mat: StandardMaterial3D = eye.mesh.material
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.7, 1.0, 0.3)
			glow_eyes.append(eye)
		MeshUtil.add(_visual, MeshUtil.sphere(0.011), Color(0.05, 0.05, 0.05), Vector3(side * 0.05, 0.48, 0.42))
		for front in [-1.0, 1.0]:
			MeshUtil.add(_visual, MeshUtil.cylinder(0.035, 0.035, 0.22), fur, Vector3(side * 0.08, 0.11, front * 0.17))
			MeshUtil.add(_visual, MeshUtil.sphere(0.04), light, Vector3(side * 0.08, 0.02, front * 0.17 + 0.02))
	# Tail and collar with a little bell.
	MeshUtil.add(_visual, MeshUtil.cylinder(0.025, 0.035, 0.45), fur, Vector3(0, 0.5, -0.4), Vector3.ONE, Vector3(-0.5, 0, 0))
	MeshUtil.add(_visual, MeshUtil.cylinder(0.1, 0.1, 0.03), Color(0.8, 0.15, 0.2), Vector3(0, 0.38, 0.25), Vector3.ONE, Vector3(1.2, 0, 0))
	MeshUtil.add(_visual, MeshUtil.sphere(0.025), Color(1.0, 0.85, 0.2), Vector3(0, 0.33, 0.32))

	MeshUtil.merge(_visual, glow_eyes)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 96
	_label.outline_size = 12
	_label.pixel_size = 0.004
	_label.no_depth_test = true
	_label.position.y = 0.95
	add_child(_label)

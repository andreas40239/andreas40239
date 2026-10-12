class_name Owl
extends Node3D
## A tawny owl hunting over the night garden. It circles high up and its
## shadow on the ground shows where it is. Before it swoops it hoots and its
## shadow turns red and slides towards the hedgehog: time to hide in a hedge
## or roll up! A hidden or rolled-up hedgehog is safe.

enum State { CIRCLE, WARN, SWOOP, CLIMB }

@export var circle_radius := 8.0
@export var height := 7.0
@export var circle_speed := 0.3
@export var first_swoop_delay := 20.0
@export var swoop_interval_min := 18.0
@export var swoop_interval_max := 30.0
@export var warn_time := 3.5
@export var swoop_time := 1.1
## The owl only hunts a hedgehog this close to the middle of its circle.
@export var hunt_range := 16.0
## Set by the level while the tutorial or an intro is showing.
var paused := false

var state := State.CIRCLE

var _angle := 0.0
var _timer := 0.0
var _target := Vector3.ZERO
var _swoop_from := Vector3.ZERO
var _time := 0.0
var _player: Hedgehog
var _bird: Node3D
var _wings: Array[Node3D] = []
var _shadow: MeshInstance3D
var _shadow_material: StandardMaterial3D
var _warned_once := false


func _ready() -> void:
	add_to_group("animals")
	_timer = first_swoop_delay
	_build_visual()


func _physics_process(delta: float) -> void:
	_time += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Hedgehog
		if _player == null:
			return
	var circle_pos := global_position + Vector3(cos(_angle) * circle_radius, height, sin(_angle) * circle_radius)

	match state:
		State.CIRCLE:
			_angle += circle_speed * delta
			_bird.global_position = circle_pos
			_face_along(Vector3(-sin(_angle), 0, cos(_angle)))
			_place_shadow(_bird.global_position, 0.0)
			if not paused:
				_timer -= delta
			if _timer <= 0.0 and _can_hunt():
				_start_warning()

		State.WARN:
			_angle += circle_speed * 0.6 * delta
			_bird.global_position = circle_pos
			_face_along(Vector3(-sin(_angle), 0, cos(_angle)))
			_timer += delta
			_target = _player.global_position  # It keeps watching the hedgehog...
			var t := clampf(_timer / warn_time, 0.0, 1.0)
			_place_shadow(_bird.global_position.lerp(_target, t), t)
			if _timer >= warn_time:
				state = State.SWOOP
				_timer = 0.0
				_swoop_from = _bird.global_position
				Sound.play_at("swoop", _target, 0.0, 0.1, 30.0)

		State.SWOOP:
			_timer += delta
			var t := clampf(_timer / swoop_time, 0.0, 1.0)
			var p := _swoop_from.lerp(_target + Vector3.UP * 0.4, t)
			p.y += sin(t * PI) * 1.0
			_bird.global_position = p
			_face_along(_target - _swoop_from)
			_place_shadow(_target, 1.0)
			if t >= 1.0:
				_strike()
				state = State.CLIMB
				_timer = 0.0

		State.CLIMB:
			_timer += delta
			var t := clampf(_timer / 2.0, 0.0, 1.0)
			_bird.global_position = _target.lerp(circle_pos, t)
			_face_along(circle_pos - _target)
			_place_shadow(_bird.global_position, 1.0 - t)
			if t >= 1.0:
				state = State.CIRCLE
				_timer = randf_range(swoop_interval_min, swoop_interval_max)

	# Flap faster when climbing, glide when circling.
	var flap := 14.0 if state == State.CLIMB else 4.0
	for i in _wings.size():
		_wings[i].rotation.z = (1 if i == 0 else -1) * (0.25 + sin(_time * flap) * 0.35)


func _can_hunt() -> bool:
	if _player.is_sleeping:
		return false
	var flat := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z)
	return flat.length() < hunt_range


func _start_warning() -> void:
	state = State.WARN
	_timer = 0.0
	Sound.play_at("hoot", _bird.global_position, 2.0, 0.03, 60.0)
	Game.unlock_fact("owl")
	if not _warned_once:
		_warned_once = true
		Game.show_toast("Hoo-hoo! The owl is hunting. Hide in a hedge or roll up!")


func _strike() -> void:
	var near := _player.global_position.distance_to(_target) < 1.4
	if not near:
		return
	if _player.is_hidden() or _player.is_rolled:
		Game.show_toast("Whoosh! The owl missed. Well hidden!")
	else:
		_player.try_catch()


## The shadow sits on the ground under `point`. `danger` (0..1) makes it
## darker, redder and bigger as the owl gets ready to swoop.
func _place_shadow(point: Vector3, danger: float) -> void:
	_shadow.global_position = Vector3(point.x, 0.03, point.z)
	var size := lerpf(1.0, 1.6, danger) + sin(_time * 10.0) * 0.08 * danger
	_shadow.scale = Vector3(size, 1.0, size)
	_shadow_material.albedo_color = Color(lerpf(0.0, 0.6, danger), 0.0, 0.0, lerpf(0.3, 0.6, danger))


func _face_along(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() > 0.01:
		_bird.rotation.y = atan2(direction.x, direction.z)


func _build_visual() -> void:
	_bird = Node3D.new()
	add_child(_bird)
	_bird.top_level = true
	var feathers := Color(0.45, 0.32, 0.2)
	var body := Node3D.new()
	_bird.add_child(body)
	MeshUtil.add(body, MeshUtil.sphere(0.28), feathers, Vector3.ZERO, Vector3(0.9, 0.8, 1.2))
	MeshUtil.add(body, MeshUtil.sphere(0.2), feathers.lightened(0.15), Vector3(0, 0.18, 0.28))
	MeshUtil.add(body, MeshUtil.cylinder(0.0, 0.03, 0.07), Color(0.85, 0.7, 0.3), Vector3(0, 0.14, 0.48), Vector3.ONE, Vector3(PI / 2, 0, 0))
	for side in [-1.0, 1.0]:
		MeshUtil.add(body, MeshUtil.sphere(0.05), Color(0.95, 0.75, 0.2), Vector3(side * 0.08, 0.22, 0.44))
		MeshUtil.add(body, MeshUtil.sphere(0.025), Color(0.05, 0.05, 0.05), Vector3(side * 0.08, 0.22, 0.48))
	MeshUtil.merge(body)
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.18, 0.05, 0)
		_bird.add_child(wing)
		MeshUtil.add(wing, MeshUtil.sphere(0.3), feathers.darkened(0.15), Vector3(side * 0.32, 0, 0), Vector3(1.4, 0.15, 0.7))
		MeshUtil.merge(wing)
		_wings.append(wing)

	var disc := MeshUtil.cylinder(0.7, 0.7, 0.01)
	_shadow_material = StandardMaterial3D.new()
	_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_material.albedo_color = Color(0, 0, 0, 0.3)
	disc.material = _shadow_material
	_shadow = MeshInstance3D.new()
	_shadow.mesh = disc
	_shadow.top_level = true
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)

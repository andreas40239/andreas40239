class_name Hedgehog
extends CharacterBody3D
## The player's hedgehog: walking, sniffing, rolling into a ball, eating,
## hiding, carrying nest material and getting caught.

signal health_changed(current: int, maximum: int)
signal dexterity_changed(value: float)
signal hidden_changed(is_hidden: bool)
signal nest_material_changed(count: int)
signal prompt_changed(text: String)
signal caught_by_animal

const MAX_DEXTERITY := 100.0
const BODY_COLOR := Color(0.78, 0.6, 0.42)
const SPINE_COLOR := Color(0.32, 0.22, 0.14)
const DARK := Color(0.08, 0.06, 0.05)

@export var max_health := 3
@export var start_dexterity := 50.0
## Speed at zero dexterity; dexterity adds up to `dexterity_speed_bonus`.
@export var base_speed := 2.0
@export var dexterity_speed_bonus := 2.2
@export var sniff_speed_factor := 0.4
@export var sniff_radius := 14.0
@export var rolled_dexterity_drain := 3.0
## Dexterity lost per second at full winter; scales with winter progress.
@export var winter_dexterity_drain := 0.5
@export var camera_path: NodePath

var health := 3
var dexterity := 50.0
var nest_material := 0
var winter_progress := 0.0
var is_rolled := false
var is_sniffing := false
var is_sleeping := false
var respawn_point := Vector3.ZERO
var stats := {"food": 0, "caught": 0, "hidden": 0}

var _hide_count := 0
var _interactables: Array[Interactable] = []
var _prompt := ""
var _invulnerable := 0.0
var _wobble := 0.0
var _time := 0.0
var _scents_shown := false
var _last_dexterity_shown := -1
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _camera: Node3D
var _visual: Node3D
var _walk_pose: Node3D
var _ball_pose: Node3D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.16
	shape.height = 0.34
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.17
	add_child(collision)

	health = max_health
	dexterity = start_dexterity
	respawn_point = global_position
	_camera = get_node_or_null(camera_path)
	_build_visual()


func _physics_process(delta: float) -> void:
	_time += delta
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var direction := Vector3.ZERO
	if not is_sleeping:
		_handle_actions()
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		direction = _camera_relative(input)

	var target := direction * current_speed()
	velocity.x = move_toward(velocity.x, target.x, 14.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 14.0 * delta)
	move_and_slide()

	if direction.length() > 0.1 and not is_rolled:
		var facing := atan2(direction.x, direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, facing, 1.0 - exp(-12.0 * delta))

	_update_stats(delta)
	_update_visual(delta)
	_update_scents()
	_update_prompt()
	if global_position.y < -5.0:
		_respawn()


# --- Queries used by animals, the HUD and the level -------------------------

func current_speed() -> float:
	if is_rolled or is_sleeping:
		return 0.0
	var speed := base_speed + dexterity_speed_bonus * dexterity / MAX_DEXTERITY
	if is_sniffing:
		speed *= sniff_speed_factor
	if _wobble > 0.0:
		speed *= 0.6
	return speed


func is_hidden() -> bool:
	return _hide_count > 0


## How far away an animal can hear the hedgehog. Standing still, sniffing
## (slow) or hiding is silent; clumsy (low dexterity) hedgehogs are louder.
func noise_radius() -> float:
	var moving := Vector2(velocity.x, velocity.z).length()
	if is_hidden() or moving < 1.2:
		return 0.0
	return lerpf(3.0, 1.2, dexterity / MAX_DEXTERITY)


func effective_sniff_radius() -> float:
	return sniff_radius * lerpf(0.75, 1.25, dexterity / MAX_DEXTERITY)


# --- Called by interactables and animals ------------------------------------

func add_interactable(item: Interactable) -> void:
	if not _interactables.has(item):
		_interactables.append(item)


func remove_interactable(item: Interactable) -> void:
	_interactables.erase(item)


func enter_hide() -> void:
	_hide_count += 1
	if _hide_count == 1:
		stats.hidden += 1
		hidden_changed.emit(true)
		Game.unlock_fact("hide")


func exit_hide() -> void:
	_hide_count = maxi(_hide_count - 1, 0)
	if _hide_count == 0:
		hidden_changed.emit(false)


## Bad food makes the hedgehog wobble but never takes its last heart.
func eat(health_delta: int, dexterity_delta: float, bad := false) -> void:
	stats.food += 1
	if bad:
		health = maxi(health + health_delta, 1)
		_wobble = 4.0
	else:
		health = mini(health + health_delta, max_health)
	dexterity = clampf(dexterity + dexterity_delta, 0.0, MAX_DEXTERITY)
	health_changed.emit(health, max_health)
	dexterity_changed.emit(dexterity)


func add_nest_material(amount: int) -> void:
	nest_material += amount
	nest_material_changed.emit(nest_material)


func take_nest_material() -> int:
	var amount := nest_material
	nest_material = 0
	nest_material_changed.emit(nest_material)
	return amount


## Returns true if the hedgehog was caught. A rolled-up, hidden or
## recently caught hedgehog cannot be caught.
func try_catch() -> bool:
	if is_rolled or is_sleeping or is_hidden() or _invulnerable > 0.0:
		return false
	stats.caught += 1
	health -= 1
	if health <= 0:
		health = max_health
		Game.show_toast("Phew! Back to the checkpoint with full hearts.")
	else:
		Game.show_toast("Caught! Back to the last checkpoint...")
	health_changed.emit(health, max_health)
	caught_by_animal.emit()
	_respawn()
	_invulnerable = 2.5
	return true


func start_sleep(nest_position: Vector3) -> void:
	is_sleeping = true
	_set_rolled(true)
	velocity = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(self, "global_position", nest_position + Vector3.UP * 0.05, 1.0)


# --- Internals -----------------------------------------------------------------

func _handle_actions() -> void:
	var sniffing := Input.is_action_pressed("sniff") and not is_rolled
	if sniffing and not is_sniffing:
		Game.unlock_fact("sniff")
	is_sniffing = sniffing

	var rolled := Input.is_action_pressed("roll")
	if rolled != is_rolled:
		_set_rolled(rolled)

	if Input.is_action_just_pressed("interact") and not is_rolled:
		var item := _nearest_interactable()
		if item:
			item.interact(self)


func _set_rolled(rolled: bool) -> void:
	is_rolled = rolled
	_walk_pose.visible = not rolled
	_ball_pose.visible = rolled
	if rolled:
		is_sniffing = false
		if not is_sleeping:
			Game.unlock_fact("roll")


func _camera_relative(input: Vector2) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var basis: Basis = _camera.global_transform.basis if _camera else Basis.IDENTITY
	var forward := -basis.z
	forward.y = 0.0
	var right := basis.x
	right.y = 0.0
	var direction := right.normalized() * input.x - forward.normalized() * input.y
	return direction.limit_length(1.0)


func _nearest_interactable() -> Interactable:
	var best: Interactable = null
	var best_distance := INF
	for item in _interactables:
		if not is_instance_valid(item) or item.get_prompt(self) == "":
			continue
		var distance := item.global_position.distance_to(global_position)
		if distance < best_distance:
			best = item
			best_distance = distance
	return best


func _update_stats(delta: float) -> void:
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_wobble = maxf(_wobble - delta, 0.0)
	if is_sleeping:
		return
	var drain := winter_dexterity_drain * winter_progress
	if is_rolled:
		drain += rolled_dexterity_drain
	dexterity = clampf(dexterity - drain * delta, 0.0, MAX_DEXTERITY)
	if int(dexterity) != _last_dexterity_shown:
		_last_dexterity_shown = int(dexterity)
		dexterity_changed.emit(dexterity)


func _update_visual(delta: float) -> void:
	# Blink while invulnerable after being caught.
	_visual.visible = _invulnerable <= 0.0 or fmod(_time, 0.2) < 0.12
	# Tummy-ache wobble after drinking milk.
	_visual.rotation.z = sin(_time * 12.0) * 0.25 * minf(_wobble, 1.0)
	# Little waddle while walking, a sniffing bob while sniffing.
	var moving := Vector2(velocity.x, velocity.z).length()
	var bob := absf(sin(_time * 14.0)) * 0.025 * minf(moving, 1.0)
	if is_sniffing:
		bob = absf(sin(_time * 20.0)) * 0.012
	_walk_pose.position.y = bob
	if is_rolled and not is_sleeping:
		_ball_pose.rotation.y += delta * 0.6
	if is_sleeping:
		# Gentle breathing.
		var breath := 1.0 + sin(_time * 1.6) * 0.04
		_ball_pose.scale = Vector3(breath, breath, breath)


func _update_scents() -> void:
	if not is_sniffing and not _scents_shown:
		return
	_scents_shown = is_sniffing
	var radius := effective_sniff_radius()
	for node in get_tree().get_nodes_in_group("scent"):
		var scent := node as Scent
		var near := scent.global_position.distance_to(global_position) <= radius
		scent.set_revealed(is_sniffing and near)


func _update_prompt() -> void:
	var text := ""
	if is_rolled and not is_sleeping:
		text = "Let go of [Shift] to uncurl"
	elif not is_sleeping:
		var item := _nearest_interactable()
		if item:
			text = "[E] " + item.get_prompt(self)
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)


func _respawn() -> void:
	global_position = respawn_point
	velocity = Vector3.ZERO


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.rotation.y = PI  # Start facing away from the camera, into the garden.
	add_child(_visual)

	# Walking pose: face towards +Z.
	_walk_pose = Node3D.new()
	_visual.add_child(_walk_pose)
	MeshUtil.add(_walk_pose, MeshUtil.sphere(0.16), BODY_COLOR, Vector3(0, 0.13, 0.02), Vector3(1.0, 0.72, 1.25))
	var back_center := Vector3(0, 0.14, -0.03)
	MeshUtil.add(_walk_pose, MeshUtil.sphere(0.16), SPINE_COLOR, back_center, Vector3(1.08, 0.85, 1.2))
	for point in MeshUtil.sphere_points(70):
		if point.y < -0.05 or point.z > 0.55:
			continue
		var base := back_center + Vector3(point.x * 0.16, point.y * 0.13, point.z * 0.18)
		var tint := SPINE_COLOR.lightened(randf() * 0.35)
		MeshUtil.add_spike(_walk_pose, base, point + Vector3(0, 0.2, -0.25), 0.1, tint)
	# Snout, nose, eyes, ears and feet.
	MeshUtil.add(_walk_pose, MeshUtil.sphere(0.065), BODY_COLOR, Vector3(0, 0.11, 0.2), Vector3(0.85, 0.75, 1.35))
	MeshUtil.add(_walk_pose, MeshUtil.sphere(0.024), DARK, Vector3(0, 0.12, 0.285))
	for side in [-1.0, 1.0]:
		MeshUtil.add(_walk_pose, MeshUtil.sphere(0.02), DARK, Vector3(side * 0.06, 0.16, 0.18))
		MeshUtil.add(_walk_pose, MeshUtil.sphere(0.028), BODY_COLOR.darkened(0.2), Vector3(side * 0.085, 0.2, 0.1))
		for front in [-1.0, 1.0]:
			MeshUtil.add(_walk_pose, MeshUtil.sphere(0.03), BODY_COLOR.darkened(0.35), Vector3(side * 0.08, 0.03, front * 0.08))

	# Rolled-up pose: a spiky ball.
	_ball_pose = Node3D.new()
	_ball_pose.position.y = 0.16
	_visual.add_child(_ball_pose)
	MeshUtil.add(_ball_pose, MeshUtil.sphere(0.14), SPINE_COLOR)
	for point in MeshUtil.sphere_points(90):
		var tint := SPINE_COLOR.lightened(randf() * 0.35)
		MeshUtil.add_spike(_ball_pose, point * 0.13, point, 0.09, tint)
	_ball_pose.visible = false

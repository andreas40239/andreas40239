extends CharacterBody2D
class_name Enemy

## Generic animal controller driven entirely by an EnemyData resource.
## State machine: PATROL <-> FLEE / CHASE -> ATTACK, plus RETURN to leash
## the animal back home when the player escapes.

enum State { PATROL, FLEE, CHASE, ATTACK, RETURN, DEAD }

@export var data: EnemyData

var state: State = State.PATROL
var home_position: Vector2
var target_position: Vector2
var player: Node2D = null

@onready var visual: Node2D = $Visual
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var detection_shape: CollisionShape2D = $DetectionArea/CollisionShape2D
@onready var hit_area: Area2D = $HitArea
@onready var hit_shape: CollisionShape2D = $HitArea/CollisionShape2D

func _ready() -> void:
	add_to_group("enemies")
	home_position = global_position
	_apply_visual()
	_apply_collision_shapes()
	_pick_new_patrol_target()
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	hit_area.body_entered.connect(_on_hit_area_body_entered)

func _apply_visual() -> void:
	visual.scale = Vector2.ONE * data.base_scale
	match data.shape:
		EnemyData.Shape.BLOB:
			CritterShapes.build_ant(visual, data.color)
		EnemyData.Shape.DIAMOND:
			CritterShapes.build_lizard(visual, data.color)
		EnemyData.Shape.TRIANGLE:
			CritterShapes.build_bird(visual, data.color)
		EnemyData.Shape.OVAL:
			CritterShapes.build_crab(visual, data.color)

func _apply_collision_shapes() -> void:
	# Resources declared inline in the .tscn are shared across all instances
	# of this scene, so each instance gets its own CircleShape2D here rather
	# than mutating the shared one.
	var new_body_shape := CircleShape2D.new()
	new_body_shape.radius = 14.0 * data.base_scale
	body_shape.shape = new_body_shape

	var new_detection_shape := CircleShape2D.new()
	new_detection_shape.radius = data.detection_radius
	detection_shape.shape = new_detection_shape

	var new_hit_shape := CircleShape2D.new()
	new_hit_shape.radius = 16.0 * data.base_scale
	hit_shape.shape = new_hit_shape

func _pick_new_patrol_target() -> void:
	var offset := Vector2(
		randf_range(-data.wander_radius, data.wander_radius),
		randf_range(-data.wander_radius, data.wander_radius)
	)
	target_position = home_position + offset

func _physics_process(_delta: float) -> void:
	if state == State.DEAD:
		return
	match state:
		State.PATROL:
			_process_patrol()
		State.FLEE:
			_process_flee()
		State.CHASE:
			_process_chase()
		State.ATTACK:
			_process_attack()
		State.RETURN:
			_process_return()
	move_and_slide()

func _process_patrol() -> void:
	_move_toward(target_position, data.move_speed * 0.5)
	if global_position.distance_to(target_position) < 10.0:
		_pick_new_patrol_target()

func _process_flee() -> void:
	if player == null or not is_instance_valid(player):
		state = State.PATROL
		return
	var away := global_position - player.global_position
	if away.length() < 1.0:
		away = Vector2.RIGHT
	_move_toward(global_position + away.normalized() * 50.0, data.move_speed)
	if global_position.distance_to(player.global_position) > data.detection_radius * 1.3:
		state = State.RETURN

func _process_chase() -> void:
	if player == null or not is_instance_valid(player):
		state = State.RETURN
		return
	var dist := global_position.distance_to(player.global_position)
	if dist <= data.attack_range:
		state = State.ATTACK
		velocity = Vector2.ZERO
		return
	if dist > data.detection_radius * 1.6:
		state = State.RETURN
		return
	_move_toward(player.global_position, data.move_speed)

func _process_attack() -> void:
	velocity = Vector2.ZERO
	if player == null or not is_instance_valid(player):
		state = State.RETURN
		return
	if global_position.distance_to(player.global_position) > data.attack_range * 1.5:
		state = State.CHASE

func _process_return() -> void:
	_move_toward(home_position, data.move_speed * 0.7)
	if global_position.distance_to(home_position) < 10.0:
		state = State.PATROL
		_pick_new_patrol_target()

func _move_toward(target: Vector2, speed: float) -> void:
	var dir := target - global_position
	if dir.length() > 1.0:
		velocity = dir.normalized() * speed
	else:
		velocity = Vector2.ZERO

func _on_detection_body_entered(body: Node) -> void:
	if state == State.DEAD or not body.is_in_group("player"):
		return
	player = body
	match data.category:
		EnemyData.Category.PREY:
			state = State.FLEE
		EnemyData.Category.RIVAL:
			state = State.FLEE if GameManager.can_eat_rival(data.rival_level) else State.CHASE
		EnemyData.Category.PREDATOR:
			state = State.CHASE

func _on_detection_body_exited(body: Node) -> void:
	if body == player and state != State.ATTACK and state != State.DEAD:
		state = State.RETURN

func _on_hit_area_body_entered(body: Node) -> void:
	if state == State.DEAD or not body.is_in_group("player"):
		return
	match data.category:
		EnemyData.Category.PREY:
			_get_eaten(body)
		EnemyData.Category.RIVAL:
			if GameManager.can_eat_rival(data.rival_level):
				_get_eaten(body)
			elif body.can_fend_off(data.rival_level):
				_get_fended_off(body)
			else:
				body.get_caught()
		EnemyData.Category.PREDATOR:
			if body.can_fend_off(data.threat_level):
				_get_fended_off(body)
			else:
				body.get_caught()

func _get_eaten(player_body: Node) -> void:
	state = State.DEAD
	player_body.eat(data.satiety_value)
	queue_free()

func _get_fended_off(_player_body: Node) -> void:
	state = State.FLEE

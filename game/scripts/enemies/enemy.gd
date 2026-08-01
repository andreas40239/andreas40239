extends CharacterBody2D
class_name Enemy

## Generic animal controller driven entirely by an EnemyData resource.
## Movement state machine: PATROL <-> FLEE / CHASE / ORBIT -> ATTACK, plus
## RETURN to leash the animal back home when the player escapes. Layered
## on top, independent of movement: contact resolution (eat / fight / deal
## damage / fend off), driven by whether the player is currently touching
## the HitArea.

enum State { PATROL, FLEE, CHASE, ATTACK, ORBIT, RETURN, DEAD }

## The den sits at the world origin (see main.tscn). Chasers give up and
## head home once they'd have to enter this radius around it, instead of
## camping at the entrance where a player leaving the den would walk
## straight back into their attack range.
const DEN_POSITION := Vector2.ZERO
const DEN_SAFE_MARGIN := 160.0

const MELEE_TICK_INTERVAL := 0.5

@export var data: EnemyData

var state: State = State.PATROL
var home_position: Vector2
var target_position: Vector2
var player: Node2D = null
var player_touching: bool = false
var current_health: float = 0.0
var _damage_cooldown: float = 0.0
var _shoot_cooldown: float = 0.0

@onready var visual: Node2D = $Visual
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var detection_shape: CollisionShape2D = $DetectionArea/CollisionShape2D
@onready var hit_area: Area2D = $HitArea
@onready var hit_shape: CollisionShape2D = $HitArea/CollisionShape2D

func _ready() -> void:
	add_to_group("enemies")
	home_position = global_position
	current_health = data.max_health
	_apply_visual()
	_apply_collision_shapes()
	_pick_new_patrol_target()
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	hit_area.body_entered.connect(_on_hit_area_body_entered)
	hit_area.body_exited.connect(_on_hit_area_body_exited)

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
		EnemyData.Shape.OVIRAPTOR:
			CritterShapes.build_oviraptor(visual, data.color, data.accent_color)
		EnemyData.Shape.HELICOPTER:
			CritterShapes.build_helicopter(visual, data.color)

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

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	# Checked every tick (not just from within _process_chase/_process_attack):
	# the detection Area2D's body_entered signal can arrive a frame late and
	# re-set state to CHASE right after we'd already bailed to RETURN, which
	# without this would make the animal flicker back and forth right at the
	# den's doorstep instead of actually leaving.
	if (state == State.CHASE or state == State.ATTACK or state == State.ORBIT) and _should_give_up_near_den():
		state = State.RETURN

	if player_touching and is_instance_valid(player) and state != State.RETURN:
		velocity = Vector2.ZERO
		_resolve_contact(delta)
	else:
		match state:
			State.PATROL:
				_process_patrol()
			State.FLEE:
				_process_flee()
			State.CHASE:
				_process_chase()
			State.ATTACK:
				_process_attack()
			State.ORBIT:
				_process_orbit(delta)
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

func _process_orbit(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		state = State.RETURN
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	if dist > data.detection_radius * 1.6:
		state = State.RETURN
		return
	var desired: float = data.preferred_range
	if dist > desired + 20.0:
		_move_toward(player.global_position, data.move_speed)
	elif dist < desired - 20.0 and dist > 1.0:
		_move_toward(global_position - to_player.normalized() * 40.0, data.move_speed)
	else:
		velocity = Vector2.ZERO
	_shoot_cooldown -= delta
	if _shoot_cooldown <= 0.0 and dist <= data.detection_radius:
		_shoot_cooldown = data.shoot_interval
		_fire_shot()

func _should_give_up_near_den() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if bool(player.get("in_den")):
		return true
	return global_position.distance_to(DEN_POSITION) < DEN_SAFE_MARGIN

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
			state = State.ORBIT if data.ranged else State.CHASE

func _on_detection_body_exited(body: Node) -> void:
	if body == player and state != State.ATTACK and state != State.DEAD:
		state = State.RETURN

func _on_hit_area_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	player = body
	player_touching = true

func _on_hit_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_touching = false

func _resolve_contact(delta: float) -> void:
	match data.category:
		EnemyData.Category.PREY:
			_get_eaten()
		EnemyData.Category.RIVAL:
			if GameManager.can_eat_rival(data.rival_level):
				_get_eaten()
			elif player.can_fend_off(data.rival_level):
				_get_fended_off()
			else:
				_tick_damage(delta)
		EnemyData.Category.PREDATOR:
			if data.unbeatable:
				_tick_damage(delta)
			elif data.has_health and data.edible_level > 0 and GameManager.growth_level >= data.edible_level:
				_tick_fight(delta)
			elif player.can_fend_off(data.threat_level):
				_get_fended_off()
			else:
				_tick_damage(delta)

func _tick_damage(delta: float) -> void:
	if data.damage_per_tick <= 0.0:
		return
	_damage_cooldown -= delta
	if _damage_cooldown <= 0.0:
		_damage_cooldown = MELEE_TICK_INTERVAL
		player.take_damage(data.damage_per_tick)

func _tick_fight(delta: float) -> void:
	current_health -= GameManager.get_bite_dps() * delta
	_tick_damage(delta)
	if current_health <= 0.0:
		_get_eaten()

func _get_eaten() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	player.eat(data.satiety_value)
	queue_free()

func _get_fended_off() -> void:
	state = State.FLEE

func _fire_shot() -> void:
	if player == null or not is_instance_valid(player):
		return
	if data.damage_per_tick > 0.0:
		player.take_damage(data.damage_per_tick)
	_show_tracer()

func _show_tracer() -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(1.0, 0.85, 0.2, 0.9)
	line.points = PackedVector2Array([Vector2.ZERO, to_local(player.global_position)])
	add_child(line)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(line):
		line.queue_free()

func get_incinerated() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	queue_free()

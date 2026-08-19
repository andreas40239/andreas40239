extends CharacterBody2D
class_name Lizard

## Player-controlled lizard. Movement input comes from a dynamic touch pad:
## the first touch of a gesture sets a new offset/center, and subsequent
## drag positions relative to that point define the movement vector. A
## keyboard fallback (arrow keys / WASD) is included for desktop testing.

signal caught
signal ate(amount: float)
signal health_changed(value: float, max_value: float)

@export var touch_deadzone: float = 8.0
@export var touch_max_radius: float = 90.0
@export var caught_invulnerability_time: float = 1.0
@export var health_regen_seconds: float = 3.0  # full heal in this long while safe in the den

const FIRE_BREATH_INTERVAL := 4.0
const FIRE_RANGE := 310.0
const FIRE_HALF_ANGLE_DEG := 38.0
const FIRE_REWARD := 15.0

var touch_index: int = -1
var touch_origin: Vector2 = Vector2.ZERO
var touch_vector: Vector2 = Vector2.ZERO
var invulnerable: bool = false
var in_den: bool = false
var speed_boost_multiplier: float = 1.0
var speed_boost_timer: float = 0.0
var den_position: Vector2 = Vector2.ZERO
var health: float = 0.0
var max_health: float = 0.0
var last_move_direction: Vector2 = Vector2.DOWN
var _fire_cooldown: float = 0.0

@onready var visual: Node2D = $Visual
@onready var touch_base: Polygon2D = $TouchIndicator/Base
@onready var touch_knob: Polygon2D = $TouchIndicator/Knob

func _ready() -> void:
	add_to_group("player")
	den_position = global_position
	GameManager.leveled_up.connect(_on_leveled_up)
	max_health = GameManager.get_max_health()
	health = max_health
	_apply_growth_visual()

func _apply_growth_visual() -> void:
	var stage: Dictionary = GameManager.get_current_stage()
	visual.scale = Vector2.ONE * float(stage["scale"])
	if stage["is_godzilla"]:
		CritterShapes.build_godzilla(visual, stage["color"])
	elif stage["is_trex"]:
		CritterShapes.build_trex(visual, stage["color"])
	else:
		CritterShapes.build_lizard(visual, stage["color"], stage["has_spikes"])

func _on_leveled_up(_new_level: int) -> void:
	max_health = GameManager.get_max_health()
	health = min(health, max_health)
	health_changed.emit(health, max_health)
	_apply_growth_visual()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_index = event.index
			touch_origin = event.position
			touch_vector = Vector2.ZERO
			_update_touch_indicator(true)
		elif event.index == touch_index:
			touch_index = -1
			touch_vector = Vector2.ZERO
			_update_touch_indicator(false)
	elif event is InputEventScreenDrag and event.index == touch_index:
		var offset: Vector2 = event.position - touch_origin
		if offset.length() < touch_deadzone:
			touch_vector = Vector2.ZERO
		else:
			touch_vector = (offset / touch_max_radius).limit_length(1.0)
		_update_touch_indicator(true)

func _update_touch_indicator(active: bool) -> void:
	touch_base.visible = active
	touch_knob.visible = active
	if active:
		touch_base.position = touch_origin
		touch_knob.position = touch_origin + touch_vector * touch_max_radius

func _get_keyboard_vector() -> Vector2:
	var vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		vec.x += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		vec.x -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		vec.y += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		vec.y -= 1.0
	return vec

func _physics_process(delta: float) -> void:
	if speed_boost_timer > 0.0:
		speed_boost_timer -= delta
		if speed_boost_timer <= 0.0:
			speed_boost_multiplier = 1.0

	var input_vector := touch_vector
	if touch_index == -1:
		input_vector = _get_keyboard_vector()
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	if input_vector.length() > 0.05:
		last_move_direction = input_vector.normalized()

	var stage: Dictionary = GameManager.get_current_stage()
	var speed: float = float(stage["speed"]) * speed_boost_multiplier
	velocity = input_vector * speed
	move_and_slide()

	if in_den and health < max_health and max_health > 0.0:
		health = min(max_health, health + (max_health / health_regen_seconds) * delta)
		health_changed.emit(health, max_health)

	if bool(stage["is_godzilla"]):
		_fire_cooldown -= delta
		if _fire_cooldown <= 0.0:
			_fire_cooldown = FIRE_BREATH_INTERVAL
			_breathe_fire()

## Quick lunge-and-snap pulse so the player can see the bite land, called
## periodically by an enemy's fight resolution (not every physics tick,
## which would just look like a flat strobe).
func play_attack_pulse() -> void:
	if not is_instance_valid(visual):
		return
	var base_scale: float = float(GameManager.get_current_stage()["scale"])
	visual.scale = Vector2.ONE * base_scale * 1.2
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector2.ONE * base_scale, 0.14)

func eat(amount: float) -> void:
	GameManager.add_satiety(amount)
	ate.emit(amount)
	AudioManager.play_eat()

func apply_fruit_boost(satiety_amount: float, boost_multiplier: float, boost_duration: float) -> void:
	GameManager.add_satiety(satiety_amount)
	speed_boost_multiplier = boost_multiplier
	speed_boost_timer = boost_duration

func can_fend_off(threat_level: int) -> bool:
	var stage: Dictionary = GameManager.get_current_stage()
	return bool(stage["has_spikes"]) and GameManager.growth_level > threat_level

func take_damage(amount: float) -> void:
	if invulnerable or in_den or amount <= 0.0:
		return
	var reduced := amount * GameManager.get_defense_multiplier()
	health = max(0.0, health - reduced)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		get_caught()

func get_caught() -> void:
	if invulnerable or in_den:
		return
	caught.emit()
	GameManager.notify_player_caught()
	_respawn_at_den()

func _respawn_at_den() -> void:
	invulnerable = true
	global_position = den_position
	velocity = Vector2.ZERO
	touch_index = -1
	touch_vector = Vector2.ZERO
	_update_touch_indicator(false)
	health = max_health
	health_changed.emit(health, max_health)
	await get_tree().create_timer(caught_invulnerability_time).timeout
	invulnerable = false

func set_den_position(pos: Vector2) -> void:
	den_position = pos

func set_in_den(value: bool) -> void:
	in_den = value

func _breathe_fire() -> void:
	_show_fire_visual()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		var dist := to_enemy.length()
		if dist > FIRE_RANGE or dist < 1.0:
			continue
		var angle := rad_to_deg(abs(last_move_direction.angle_to(to_enemy.normalized())))
		if angle <= FIRE_HALF_ANGLE_DEG and enemy.has_method("get_incinerated"):
			enemy.get_incinerated()
			GameManager.add_satiety(FIRE_REWARD)

func _show_fire_visual() -> void:
	var cone := Node2D.new()
	cone.rotation = last_move_direction.angle()
	cone.z_index = 5
	add_child(cone)

	var half_w := FIRE_RANGE * tan(deg_to_rad(FIRE_HALF_ANGLE_DEG))
	# Layered flame (outer haze / mid flame / bright core) instead of a
	# single flat triangle, so the breath reads as fire rather than a beam.
	var outer := Polygon2D.new()
	outer.polygon = PackedVector2Array([Vector2.ZERO, Vector2(FIRE_RANGE, -half_w), Vector2(FIRE_RANGE, half_w)])
	outer.color = Color(1.0, 0.35, 0.05, 0.55)
	cone.add_child(outer)

	var mid_w := half_w * 0.62
	var mid := Polygon2D.new()
	mid.polygon = PackedVector2Array([Vector2.ZERO, Vector2(FIRE_RANGE * 0.82, -mid_w), Vector2(FIRE_RANGE * 0.82, mid_w)])
	mid.color = Color(1.0, 0.6, 0.1, 0.72)
	cone.add_child(mid)

	var core_w := half_w * 0.3
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([Vector2.ZERO, Vector2(FIRE_RANGE * 0.5, -core_w), Vector2(FIRE_RANGE * 0.5, core_w)])
	core.color = Color(1.0, 0.92, 0.55, 0.9)
	cone.add_child(core)

	var embers := CPUParticles2D.new()
	embers.emitting = true
	embers.amount = 26
	embers.lifetime = 0.4
	embers.one_shot = true
	embers.explosiveness = 0.25
	embers.direction = Vector2.RIGHT
	embers.spread = FIRE_HALF_ANGLE_DEG
	embers.initial_velocity_min = FIRE_RANGE * 1.5
	embers.initial_velocity_max = FIRE_RANGE * 2.1
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 3.2
	embers.color = Color(1.0, 0.7, 0.15, 0.9)
	cone.add_child(embers)

	var tw := create_tween()
	tw.tween_property(cone, "modulate:a", 0.0, 0.4).from(1.0)
	await get_tree().create_timer(0.45).timeout
	if is_instance_valid(cone):
		cone.queue_free()

extends CharacterBody2D
class_name Lizard

## Player-controlled lizard. Movement input comes from a dynamic touch pad:
## the first touch of a gesture sets a new offset/center, and subsequent
## drag positions relative to that point define the movement vector. A
## keyboard fallback (arrow keys / WASD) is included for desktop testing.

signal caught
signal ate(amount: float)

@export var touch_deadzone: float = 8.0
@export var touch_max_radius: float = 90.0
@export var caught_invulnerability_time: float = 1.0

var touch_index: int = -1
var touch_origin: Vector2 = Vector2.ZERO
var touch_vector: Vector2 = Vector2.ZERO
var invulnerable: bool = false
var in_den: bool = false
var speed_boost_multiplier: float = 1.0
var speed_boost_timer: float = 0.0
var den_position: Vector2 = Vector2.ZERO

@onready var visual: Node2D = $Visual
@onready var touch_base: Polygon2D = $TouchIndicator/Base
@onready var touch_knob: Polygon2D = $TouchIndicator/Knob

func _ready() -> void:
	add_to_group("player")
	den_position = global_position
	GameManager.leveled_up.connect(_on_leveled_up)
	_apply_growth_visual()

func _apply_growth_visual() -> void:
	var stage: Dictionary = GameManager.get_current_stage()
	visual.scale = Vector2.ONE * float(stage["scale"])
	if stage["is_trex"]:
		CritterShapes.build_trex(visual, stage["color"])
	else:
		CritterShapes.build_lizard(visual, stage["color"], stage["has_spikes"])

func _on_leveled_up(_new_level: int) -> void:
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

	var stage: Dictionary = GameManager.get_current_stage()
	var speed: float = float(stage["speed"]) * speed_boost_multiplier
	velocity = input_vector * speed
	move_and_slide()

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
	await get_tree().create_timer(caught_invulnerability_time).timeout
	invulnerable = false

func set_den_position(pos: Vector2) -> void:
	den_position = pos

func set_in_den(value: bool) -> void:
	in_den = value

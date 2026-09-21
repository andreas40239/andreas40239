extends CharacterBody3D
class_name Player
## Spielerkatze (GDD Abschnitt 2 und 3).
##
## Meilenstein 1: Laufen, fester Sprung, Klettern an markierten Zonen,
## automatisches Festhalten an Kanten, gesperrte Z-Achse.
## Meilenstein 2: Lebenspunkte, Treffer mit Unverwundbarkeit und Rueckstoss,
## Fressen (Heilung), Levelziel und Neustart.

signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died()
signal state_changed(new_state: State)

enum State { IDLE, RUN, AIR, CLIMB, HANG, MANTLE, HURT, DEAD, VICTORY }

# --- Metriken aus dem GDD (1 Godot-Einheit = 1 m) ---------------------------
const RUN_SPEED := 4.0
const CLIMB_SPEED := 2.0
const JUMP_HEIGHT := 1.8
const JUMP_DISTANCE := 3.5
## Flugzeit eines vollen Sprungs aus dem Lauf: Weite / Laufgeschwindigkeit.
const AIR_TIME := JUMP_DISTANCE / RUN_SPEED
## Aus Sprunghoehe und Flugzeit abgeleitet, damit beide Metriken exakt stimmen.
const GRAVITY := 8.0 * JUMP_HEIGHT / (AIR_TIME * AIR_TIME)
const JUMP_VELOCITY := 4.0 * JUMP_HEIGHT / AIR_TIME
const MAX_FALL_SPEED := 20.0

# --- Fahrgefuehl ------------------------------------------------------------
const GROUND_ACCEL := 40.0
const AIR_ACCEL := 22.0
const GROUND_FRICTION := 34.0
const AIR_FRICTION := 6.0
## Kulanzzeit nach dem Verlassen einer Kante (Zielgruppe ab 5 Jahren).
const COYOTE_TIME := 0.12
## Zu frueh gedrueckter Sprung wird kurz gepuffert.
const JUMP_BUFFER_TIME := 0.15

# --- Klettern und Kanten ----------------------------------------------------
const CLIMB_ALIGN_SPEED := 8.0
const CLIMB_INPUT_THRESHOLD := 0.35
const WALL_JUMP_PUSH := 2.2
const MANTLE_TIME := 0.25
## Sperre nach dem Loslassen, damit nicht sofort wieder gegriffen wird.
const GRAB_COOLDOWN := 0.35

# --- Treffer (GDD Abschnitt 3) ---------------------------------------------
const INVULNERABLE_TIME := 1.0
const HURT_TIME := 0.3
const KNOCKBACK_SPEED := 3.5
const KNOCKBACK_LIFT := 3.0
const BLINK_INTERVAL := 0.08

@export var max_health: int = 3
## Tutorial-Modus: Lebenspunkte fallen nie unter 1 (GDD Abschnitt 7).
@export var no_fail: bool = false
## Unter dieser Hoehe gilt die Katze als abgestuerzt.
@export var fall_limit_y: float = -12.0

var health: int = 3
var state: State = State.IDLE
var facing: float = 1.0
var is_invulnerable: bool = false

@onready var visual: Node3D = $Visual
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var climb_sensor: Area3D = $ClimbSensor

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _hurt_timer := 0.0
var _invulnerable_timer := 0.0
var _blink_timer := 0.0
var _grab_cooldown_timer := 0.0

var _climb_zones: Array[Node] = []
var _ledge_zones: Array[Node] = []
var _active_climb_zone: Node = null
var _active_ledge_zone: Node = null

var _climb_blocked_timer := 0.0
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_progress := 0.0

var _spawn_position := Vector3.ZERO
## Letzte Position mit sicherem Boden unter den Pfoten - Ziel nach einem Absturz.
var _last_safe_position := Vector3.ZERO
var _safe_position_timer := 0.0

func _ready() -> void:
	add_to_group("player")
	health = max_health
	_spawn_position = global_position
	_last_safe_position = global_position
	climb_sensor.area_entered.connect(_on_zone_entered)
	climb_sensor.area_exited.connect(_on_zone_exited)
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	var move_input := PlayerInput.get_move_vector()
	if PlayerInput.consume_jump():
		_jump_buffer_timer = JUMP_BUFFER_TIME

	match state:
		State.MANTLE:
			_process_mantle(delta)
		State.CLIMB:
			_process_climb(delta, move_input)
		State.HANG:
			_process_hang(delta, move_input)
		State.HURT:
			_process_hurt(delta)
		State.DEAD, State.VICTORY:
			_process_locked(delta)
		_:
			_process_ground_and_air(delta, move_input)

	_lock_z_axis()
	_track_safe_position(delta)
	if global_position.y < fall_limit_y:
		_on_fell_out_of_level()

# --- Zustaende --------------------------------------------------------------

func _process_ground_and_air(delta: float, move_input: Vector2) -> void:
	if _try_grab_ledge():
		return
	if _try_start_climb(move_input):
		return

	var on_floor := is_on_floor()
	if on_floor:
		_coyote_timer = COYOTE_TIME
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL_SPEED)

	_apply_horizontal_input(delta, move_input.x, on_floor)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_jump()

	move_and_slide()

	if is_on_floor():
		_set_state(State.RUN if absf(velocity.x) > 0.1 else State.IDLE)
	else:
		_set_state(State.AIR)

func _process_climb(delta: float, move_input: Vector2) -> void:
	if _active_climb_zone == null or not _climb_zones.has(_active_climb_zone):
		_stop_climbing()
		return

	# Sprung von der Wand weg (GDD: Greifen automatisch, Loslassen per Sprung).
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = 0.0
		_grab_cooldown_timer = GRAB_COOLDOWN
		_active_climb_zone = null
		velocity = Vector3(-facing * WALL_JUMP_PUSH, JUMP_VELOCITY * 0.9, 0.0)
		_set_state(State.AIR)
		move_and_slide()
		return

	# Oben angekommen: automatisch auf die Kante ziehen.
	var top := _active_climb_zone.get_top_y() as float
	var head_y: float = global_position.y + _half_height()
	if move_input.y > 0.2 and head_y >= top - 0.05:
		_start_mantle(_active_climb_zone.get_exit_point())
		return

	# An der Kletterzone ausrichten und senkrecht bewegen.
	var align: float = _active_climb_zone.global_position.x - global_position.x
	velocity.x = clampf(align * CLIMB_ALIGN_SPEED, -RUN_SPEED, RUN_SPEED)
	velocity.y = move_input.y * CLIMB_SPEED
	if absf(move_input.x) > 0.6:
		facing = signf(move_input.x)

	var y_before := global_position.y
	move_and_slide()

	# Haengt die Katze unter einem Vorsprung fest, zieht sie sich trotzdem hoch,
	# sobald sie nah genug am oberen Ende ist.
	if move_input.y > 0.2 and absf(global_position.y - y_before) < 0.002:
		_climb_blocked_timer += delta
		if _climb_blocked_timer > 0.25 and head_y >= top - 1.0:
			_start_mantle(_active_climb_zone.get_exit_point())
			return
	else:
		_climb_blocked_timer = 0.0

	# Unten angekommen und weiter nach unten: loslassen.
	if is_on_floor() and move_input.y <= 0.0:
		_stop_climbing()

func _process_hang(_delta: float, move_input: Vector2) -> void:
	velocity = Vector3.ZERO
	if _active_ledge_zone == null:
		_set_state(State.AIR)
		return
	if _jump_buffer_timer > 0.0 or move_input.y > 0.5:
		_jump_buffer_timer = 0.0
		_start_mantle(_active_ledge_zone.get_exit_point())
		return
	if move_input.y < -0.5:
		_grab_cooldown_timer = GRAB_COOLDOWN
		_active_ledge_zone = null
		_set_state(State.AIR)

func _process_mantle(delta: float) -> void:
	_mantle_progress = minf(_mantle_progress + delta / MANTLE_TIME, 1.0)
	# Erst hoch, dann auf die Flaeche - fuehlt sich wie ein echtes Hochziehen an.
	var eased := ease(_mantle_progress, 0.5)
	var lift := Vector3(0.0, (_mantle_to.y - _mantle_from.y) * eased, 0.0)
	var shift := Vector3((_mantle_to.x - _mantle_from.x) * (eased * eased), 0.0, 0.0)
	global_position = _mantle_from + lift + shift
	velocity = Vector3.ZERO
	if _mantle_progress >= 1.0:
		global_position = _mantle_to
		_grab_cooldown_timer = GRAB_COOLDOWN
		_active_climb_zone = null
		_active_ledge_zone = null
		_set_state(State.IDLE)

func _process_hurt(delta: float) -> void:
	velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL_SPEED)
	velocity.x = move_toward(velocity.x, 0.0, AIR_FRICTION * delta)
	move_and_slide()
	if _hurt_timer <= 0.0:
		_set_state(State.AIR if not is_on_floor() else State.IDLE)

func _process_locked(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL_SPEED)
	else:
		velocity.y = 0.0
	move_and_slide()

# --- Bewegungsbausteine -----------------------------------------------------

func _apply_horizontal_input(delta: float, input_x: float, on_floor: bool) -> void:
	var target := input_x * RUN_SPEED
	var rate := (GROUND_ACCEL if on_floor else AIR_ACCEL) if not is_zero_approx(input_x) \
		else (GROUND_FRICTION if on_floor else AIR_FRICTION)
	velocity.x = move_toward(velocity.x, target, rate * delta)
	if not is_zero_approx(input_x):
		facing = signf(input_x)
		visual.rotation.y = 0.0 if facing > 0.0 else PI

func _jump() -> void:
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	velocity.y = JUMP_VELOCITY

func _try_start_climb(move_input: Vector2) -> bool:
	if _grab_cooldown_timer > 0.0 or _climb_zones.is_empty():
		return false
	if absf(move_input.y) < CLIMB_INPUT_THRESHOLD:
		return false
	# Am Boden stehend nach unten druecken startet kein Klettern.
	if is_on_floor() and move_input.y < 0.0:
		return false
	_active_climb_zone = _nearest_zone(_climb_zones)
	if _active_climb_zone == null:
		return false
	_climb_blocked_timer = 0.0
	velocity = Vector3.ZERO
	_set_state(State.CLIMB)
	return true

func _try_grab_ledge() -> bool:
	if _grab_cooldown_timer > 0.0 or _ledge_zones.is_empty():
		return false
	if is_on_floor() or velocity.y > 0.0:
		return false
	_active_ledge_zone = _nearest_zone(_ledge_zones)
	if _active_ledge_zone == null:
		return false
	global_position = _active_ledge_zone.get_hang_point()
	velocity = Vector3.ZERO
	_set_state(State.HANG)
	return true

func _stop_climbing() -> void:
	_active_climb_zone = null
	_grab_cooldown_timer = GRAB_COOLDOWN
	_set_state(State.AIR)

func _start_mantle(target: Vector3) -> void:
	_mantle_from = global_position
	_mantle_to = Vector3(target.x, target.y, 0.0)
	_mantle_progress = 0.0
	velocity = Vector3.ZERO
	_set_state(State.MANTLE)

func _nearest_zone(zones: Array[Node]) -> Node:
	var best: Node = null
	var best_distance := INF
	for zone in zones:
		if not is_instance_valid(zone):
			continue
		var distance: float = global_position.distance_squared_to(zone.global_position)
		if distance < best_distance:
			best_distance = distance
			best = zone
	return best

func _lock_z_axis() -> void:
	# GDD Abschnitt 8: nur eine Spielebene, Z-Achse der Figur gesperrt.
	global_position.z = 0.0
	velocity.z = 0.0

func _half_height() -> float:
	var shape := collision_shape.shape
	if shape is CapsuleShape3D:
		return shape.height * 0.5
	if shape is BoxShape3D:
		return shape.size.y * 0.5
	return 0.3

func _update_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	_grab_cooldown_timer = maxf(_grab_cooldown_timer - delta, 0.0)
	if is_invulnerable:
		_invulnerable_timer -= delta
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink_timer = BLINK_INTERVAL
			visual.visible = not visual.visible
		if _invulnerable_timer <= 0.0:
			is_invulnerable = false
			visual.visible = true

func _track_safe_position(delta: float) -> void:
	_safe_position_timer -= delta
	if _safe_position_timer > 0.0:
		return
	_safe_position_timer = 0.25
	if is_on_floor() and state in [State.IDLE, State.RUN]:
		_last_safe_position = global_position

# --- Lebenspunkte (GDD Abschnitt 3) ----------------------------------------

func take_damage(amount: int = 1, source_position: Vector3 = Vector3.ZERO) -> void:
	if is_invulnerable or state in [State.DEAD, State.VICTORY]:
		return
	var minimum := 1 if no_fail else 0
	health = maxi(health - amount, minimum)
	health_changed.emit(health, max_health)
	damaged.emit(amount)
	_start_invulnerability()
	_apply_knockback(source_position)
	if health <= 0:
		_die()
	else:
		_hurt_timer = HURT_TIME
		_set_state(State.HURT)

func heal(amount: int = 1) -> void:
	if state == State.DEAD:
		return
	var before := health
	health = mini(health + amount, max_health)
	if health != before:
		health_changed.emit(health, max_health)
		healed.emit(health - before)

func heal_full() -> void:
	heal(max_health)

func _start_invulnerability() -> void:
	is_invulnerable = true
	_invulnerable_timer = INVULNERABLE_TIME
	_blink_timer = BLINK_INTERVAL

func _apply_knockback(source_position: Vector3) -> void:
	var direction := -facing
	if not source_position.is_equal_approx(Vector3.ZERO):
		var delta_x := global_position.x - source_position.x
		direction = signf(delta_x) if not is_zero_approx(delta_x) else -facing
	_active_climb_zone = null
	_active_ledge_zone = null
	_grab_cooldown_timer = GRAB_COOLDOWN
	velocity = Vector3(direction * KNOCKBACK_SPEED, KNOCKBACK_LIFT, 0.0)

func _die() -> void:
	velocity = Vector3.ZERO
	is_invulnerable = true
	_invulnerable_timer = 9999.0
	_set_state(State.DEAD)
	died.emit()
	Game.fail_level()

## Zurueck auf den letzten sicheren Boden - kostet einen Lebenspunkt.
func _on_fell_out_of_level() -> void:
	if state == State.DEAD:
		global_position = _spawn_position
		velocity = Vector3.ZERO
		return
	var target := _last_safe_position if _last_safe_position != Vector3.ZERO else _spawn_position
	global_position = target + Vector3.UP * 0.5
	velocity = Vector3.ZERO
	_set_state(State.IDLE)
	var was_invulnerable := is_invulnerable
	is_invulnerable = false
	take_damage(1, global_position)
	if was_invulnerable:
		_start_invulnerability()

## Levelziel erreicht: Siegeszustand, keine Steuerung mehr (GDD Abschnitt 12).
func win() -> void:
	if state == State.DEAD:
		return
	velocity = Vector3.ZERO
	is_invulnerable = true
	_invulnerable_timer = 9999.0
	visual.visible = true
	_set_state(State.VICTORY)

func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)

# --- Zonen ------------------------------------------------------------------

func _on_zone_entered(area: Area3D) -> void:
	if area.is_in_group("climbable") and not _climb_zones.has(area):
		_climb_zones.append(area)
	elif area.is_in_group("ledge") and not _ledge_zones.has(area):
		_ledge_zones.append(area)

func _on_zone_exited(area: Area3D) -> void:
	_climb_zones.erase(area)
	_ledge_zones.erase(area)
	if area == _active_climb_zone and state == State.CLIMB:
		_stop_climbing()
	if area == _active_ledge_zone and state == State.HANG:
		_active_ledge_zone = null
		_set_state(State.AIR)

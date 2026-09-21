extends Enemy
class_name Dog
## Hund (GDD Abschnitt 4).
##
## Zustaende: Ruhen -> Patrouille -> Warnung -> Jagen -> Rueckkehr.
## Der kleine Hund ist schnell und sprintet kurz, der grosse ist langsam, hat
## aber einen groesseren Wahrnehmungsradius. Hunde klettern nicht und springen
## nicht; Zaunluecken und Autos blockieren sie schon durch ihre Groesse.

enum DogSize { KLEIN, GROSS }
enum State { SCHLAFEN, RUHEN, PATROUILLE, WARNUNG, JAGEN, BELLEN_NACH_OBEN, RUECKKEHR }

## Hoehenunterschied, ab dem die Katze als ausser Reichweite gilt.
const REACH_HEIGHT := 1.6
const CHASE_LIMIT := 9.0
const CHASE_TIME := 4.0
const BARK_UP_TIME := 1.0

const PARAMS := {
	DogSize.KLEIN: {
		"patrol_speed": 1.6, "chase_speed": 5.0, "perception": 6.0,
		"height": 0.75, "radius": 0.22, "scale": 0.8,
		"sprint_on": 0.9, "sprint_off": 0.35,
	},
	DogSize.GROSS: {
		"patrol_speed": 1.1, "chase_speed": 3.2, "perception": 10.0,
		"height": 1.15, "radius": 0.32, "scale": 1.25,
		"sprint_on": 99.0, "sprint_off": 0.0,
	},
}

@export var dog_size: DogSize = DogSize.KLEIN
@export var patrol_distance: float = 4.0
## Schlafender Hund fuer das Tutorial: weckt kurz auf, bellt und schlaeft weiter.
@export var start_sleeping: bool = false

var state: State = State.PATROUILLE

var _direction := 1.0
var _timer := 0.0
var _chase_timer := 0.0
var _sprint_timer := 0.0
var _sprinting := true

func _ready() -> void:
	super()
	_apply_size()
	state = State.SCHLAFEN if start_sleeping else State.PATROUILLE
	_timer = randf_range(3.0, 6.0)

func _physics_process(delta: float) -> void:
	_tick_common(delta)
	_apply_gravity(delta)
	_timer -= delta

	match state:
		State.SCHLAFEN:
			_process_sleeping()
		State.RUHEN:
			_process_resting()
		State.PATROUILLE:
			_process_patrol(delta)
		State.WARNUNG:
			_process_warning()
		State.JAGEN:
			_process_chase(delta)
		State.BELLEN_NACH_OBEN:
			_process_bark_up()
		State.RUECKKEHR:
			_process_return()

	_lock_z_axis()
	move_and_slide()

# --- Zustaende --------------------------------------------------------------

func _process_sleeping() -> void:
	velocity.x = 0.0
	# Kommt die Katze ganz nah, wacht der Hund kurz auf und bellt.
	if _player_in_range(2.2, 3.0) and _timer <= 0.0:
		_enter(State.BELLEN_NACH_OBEN, BARK_UP_TIME)

func _process_resting() -> void:
	velocity.x = 0.0
	if _notices_player():
		_enter(State.WARNUNG, warning_time)
		return
	if _timer <= 0.0:
		_enter(State.PATROUILLE, randf_range(4.0, 7.0))

func _process_patrol(_delta: float) -> void:
	if _notices_player():
		_enter(State.WARNUNG, warning_time)
		return
	var speed: float = PARAMS[dog_size]["patrol_speed"]
	if is_on_wall() or absf(global_position.x - home_position.x) > patrol_distance:
		_direction = signf(home_position.x - global_position.x)
		if is_zero_approx(_direction):
			_direction = 1.0
	velocity.x = _direction * speed
	_face(_direction)
	if _timer <= 0.0:
		_enter(State.RUHEN, randf_range(1.2, 2.5))

## Warnung: stehen bleiben, klaeffen bzw. knurren - der Spieler bekommt Zeit.
func _process_warning() -> void:
	velocity.x = 0.0
	_face(signf(_player_delta().x))
	_set_warning_visible(true)
	if _timer <= 0.0:
		_set_warning_visible(false)
		_chase_timer = CHASE_TIME
		_sprint_timer = PARAMS[dog_size]["sprint_on"]
		_sprinting = true
		_enter(State.JAGEN, 0.0)

func _process_chase(delta: float) -> void:
	var delta_to_player := _player_delta()
	_chase_timer -= delta

	# Katze ausser Reichweite: kurz nach oben bellen, dann zurueck.
	if absf(delta_to_player.y) > REACH_HEIGHT:
		_enter(State.BELLEN_NACH_OBEN, BARK_UP_TIME)
		return
	if _chase_timer <= 0.0 or absf(delta_to_player.x) > PARAMS[dog_size]["perception"] * 1.5 \
			or absf(global_position.x - home_position.x) > CHASE_LIMIT:
		_enter(State.RUECKKEHR, 0.0)
		return

	# Der kleine Hund jagt in kurzen Sprints.
	_sprint_timer -= delta
	if _sprint_timer <= 0.0:
		_sprinting = not _sprinting
		_sprint_timer = PARAMS[dog_size]["sprint_on"] if _sprinting \
			else PARAMS[dog_size]["sprint_off"]
	var direction := signf(delta_to_player.x)
	velocity.x = direction * PARAMS[dog_size]["chase_speed"] if _sprinting else 0.0
	_face(direction)

func _process_bark_up() -> void:
	velocity.x = 0.0
	_face(signf(_player_delta().x))
	if _timer <= 0.0:
		if start_sleeping:
			_enter(State.SCHLAFEN, 2.0)
		else:
			_enter(State.RUECKKEHR, 0.0)

func _process_return() -> void:
	_set_warning_visible(false)
	var to_home := home_position.x - global_position.x
	if absf(to_home) < 0.3:
		_direction = signf(to_home) if not is_zero_approx(to_home) else _direction
		_enter(State.PATROUILLE, randf_range(4.0, 7.0))
		return
	_direction = signf(to_home)
	velocity.x = _direction * PARAMS[dog_size]["patrol_speed"]
	_face(_direction)

# --- Hilfen -----------------------------------------------------------------

func _notices_player() -> bool:
	if passive:
		return false
	return _player_in_range(PARAMS[dog_size]["perception"], REACH_HEIGHT)

func _enter(new_state: State, duration: float) -> void:
	state = new_state
	_timer = duration
	if new_state != State.WARNUNG:
		_set_warning_visible(false)
	if visual != null:
		# Schlafender Hund liegt flach, wacher Hund steht.
		var lying := new_state == State.SCHLAFEN
		visual.scale = Vector3(1.0, 0.55, 1.0) if lying else Vector3.ONE

## Ein schlafender Hund tut niemandem weh - die Katze klettert ueber ihn hinweg.
func is_dangerous() -> bool:
	return super() and state != State.SCHLAFEN

func _apply_size() -> void:
	var params: Dictionary = PARAMS[dog_size]
	var shape := CapsuleShape3D.new()
	shape.height = params["height"]
	shape.radius = params["radius"]
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.shape = shape
		collision.position.y = 0.0
	var hit_shape := BoxShape3D.new()
	hit_shape.size = Vector3(params["radius"] * 2.4, params["height"], 1.0)
	var hit_collision := get_node_or_null("Hitbox/Collision") as CollisionShape3D
	if hit_collision != null:
		hit_collision.shape = hit_shape
	if visual != null:
		visual.scale = Vector3.ONE * params["scale"]
	# Grosse Hunde sind dunkler - im Graubox-Level sonst kaum zu unterscheiden.
	var body := get_node_or_null("Visual/Koerper") as MeshInstance3D
	if body != null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.62, 0.45, 0.28) if dog_size == DogSize.KLEIN \
			else Color(0.34, 0.29, 0.26)
		material.roughness = 0.95
		body.set_surface_override_material(0, material)

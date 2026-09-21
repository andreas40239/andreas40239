extends Enemy
class_name TerritoryCat
## Revierkatze (GDD Abschnitt 4).
##
## Zustaende: Sitzen -> Revier-Patrouille -> Warnung -> Angriff -> Rueckzug.
## Sie verteidigt nur ihr Revier; verlaesst die Spielerkatze das Gebiet, zieht
## sie sich zurueck. Das Revier ist an den Blumentoepfen an beiden Raendern
## erkennbar.

enum State { SITZEN, PATROUILLE, WARNUNG, ANGRIFF, RUECKZUG }

## Hoehenunterschied, ab dem die Spielerkatze nicht mehr als Eindringling gilt.
const REACH_HEIGHT := 2.2
const ATTACK_COOLDOWN := 0.6

@export var territory_half_width: float = 3.0
@export var patrol_speed: float = 1.6
@export var attack_speed_x: float = 3.2
@export var attack_speed_y: float = 4.2

var state: State = State.SITZEN

var _direction := 1.0
var _timer := 0.0

func _ready() -> void:
	super()
	_build_territory_markers()
	_enter(State.SITZEN, randf_range(1.5, 3.0))

func _physics_process(delta: float) -> void:
	_tick_common(delta)
	_apply_gravity(delta)
	_timer -= delta

	match state:
		State.SITZEN:
			_process_sitting()
		State.PATROUILLE:
			_process_patrol()
		State.WARNUNG:
			_process_warning()
		State.ANGRIFF:
			_process_attack()
		State.RUECKZUG:
			_process_retreat()

	_lock_z_axis()
	move_and_slide()

# --- Zustaende --------------------------------------------------------------

func _process_sitting() -> void:
	velocity.x = 0.0
	if _intruder_present():
		_enter(State.WARNUNG, warning_time)
		return
	if _timer <= 0.0:
		_enter(State.PATROUILLE, randf_range(3.0, 5.0))

func _process_patrol() -> void:
	if _intruder_present():
		_enter(State.WARNUNG, warning_time)
		return
	if is_on_wall() or absf(global_position.x - home_position.x) > territory_half_width:
		_direction = signf(home_position.x - global_position.x)
		if is_zero_approx(_direction):
			_direction = 1.0
	velocity.x = _direction * patrol_speed
	_face(_direction)
	if _timer <= 0.0:
		_enter(State.SITZEN, randf_range(1.5, 3.0))

## Warnung: Buckel machen und fauchen. Passive Revierkatzen bleiben dabei.
func _process_warning() -> void:
	velocity.x = 0.0
	_face(signf(_player_delta().x))
	_set_warning_visible(true)
	if visual != null:
		visual.scale = Vector3(1.0, 1.25, 1.0)
	if not _intruder_present():
		_enter(State.RUECKZUG, 0.0)
		return
	if _timer <= 0.0:
		if passive:
			_timer = warning_time   # faucht weiter, greift aber nie an
			return
		_enter(State.ANGRIFF, 1.5)
		var delta_to_player := _player_delta()
		velocity = Vector3(signf(delta_to_player.x) * attack_speed_x, attack_speed_y, 0.0)

func _process_attack() -> void:
	_face(signf(velocity.x))
	if is_on_floor() and velocity.y <= 0.0:
		velocity.x = 0.0
		if _intruder_present():
			_enter(State.WARNUNG, warning_time + ATTACK_COOLDOWN)
		else:
			_enter(State.RUECKZUG, 0.0)
	elif _timer <= 0.0:
		_enter(State.RUECKZUG, 0.0)

func _process_retreat() -> void:
	_set_warning_visible(false)
	var to_home := home_position.x - global_position.x
	if absf(to_home) < 0.3:
		_enter(State.SITZEN, randf_range(1.5, 3.0))
		return
	_direction = signf(to_home)
	velocity.x = _direction * patrol_speed
	_face(_direction)

# --- Hilfen -----------------------------------------------------------------

## Eindringling: die Spielerkatze steht im Revier und auf aehnlicher Hoehe.
func _intruder_present() -> bool:
	if _player == null or not is_instance_valid(_player) or is_recovering():
		return false
	if _player.state in [Player.State.DEAD, Player.State.VICTORY]:
		return false
	var in_territory := absf(_player.global_position.x - home_position.x) <= territory_half_width
	var same_level := absf(_player.global_position.y - home_position.y) <= REACH_HEIGHT
	return in_territory and same_level

## Nach einem Treffer zieht sich die Revierkatze zurueck.
func _on_hit_player() -> void:
	_enter(State.RUECKZUG, 0.0)

func _enter(new_state: State, duration: float) -> void:
	state = new_state
	_timer = duration
	if new_state != State.WARNUNG:
		_set_warning_visible(false)
		if visual != null:
			visual.scale = Vector3.ONE

## Blumentoepfe an den Revierraendern: das Gebiet muss sichtbar sein.
## Sie haengen nicht am bewegten Koerper, sondern stehen fest in der Welt.
func _build_territory_markers() -> void:
	for side in [-1.0, 1.0]:
		var pot := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.35, 0.35, 0.35)
		pot.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.45, 0.26, 0.18)
		material.roughness = 0.95
		pot.set_surface_override_material(0, material)
		add_child(pot)
		pot.top_level = true
		pot.global_position = home_position + Vector3(side * territory_half_width, 0.1, 0.0)

	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(territory_half_width * 2.0, 0.04, 2.2)
	strip.mesh = strip_mesh
	var strip_material := StandardMaterial3D.new()
	strip_material.albedo_color = Color(0.40, 0.34, 0.42)
	strip_material.roughness = 1.0
	strip.set_surface_override_material(0, strip_material)
	add_child(strip)
	strip.top_level = true
	strip.global_position = home_position + Vector3(0.0, -0.24, 0.0)

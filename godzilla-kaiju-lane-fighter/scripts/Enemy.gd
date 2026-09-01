class_name Enemy
extends Node2D
## MVP enemies: raptor / ptera / anky (GDD 5.1). One node, per-kind behavior.

signal enemy_died(enemy)

var game
var player: Player
var kind := "raptor"
var hp := 20.0
var dmg := 4.0
var speed := 90.0
var lane := G.LANE_GROUND
var state := "approach"   # approach|windup|attack|recover|scatter|stunned|grabbed|thrown|dead
var state_t := 0.0
var atk_cd := 1.5
var facing := -1.0        # -1 = moving left (toward player)
var spr: Sprite2D
var _anim_t := 0.0
var _swoop_from := Vector2.ZERO
var _swoop_to := Vector2.ZERO
var _hit_done := false
var _throw_dir := 1.0
var _base_y := 0.0
var heal_target = null   # boss-summoned raptors run to heal the boss (GDD 6.1)

const FRAMES := {"raptor": 4, "ptera": 4, "anky": 5}
const SCALES := {"raptor": 4.0, "ptera": 4.0, "anky": 4.0}
const HEIGHTS := {"raptor": 128.0, "ptera": 60.0, "anky": 128.0}

func setup(p_kind: String, p_game, from_left: bool) -> void:
	kind = p_kind
	game = p_game
	player = p_game.player
	var st: Dictionary = G.ENEMY[kind]
	hp = st["hp"]
	dmg = st["dmg"]
	speed = st["speed"]
	lane = st["lane"]
	spr = Sprite2D.new()
	spr.texture = load("res://assets/sprites/characters/%s.png" % ("pteranodon" if kind == "ptera" else ("ankylosaurus" if kind == "anky" else kind)))
	spr.hframes = FRAMES[kind]
	spr.scale = Vector2(SCALES[kind], SCALES[kind])
	spr.position = Vector2(0, -HEIGHTS[kind] * 0.5)
	if from_left:
		spr.flip_h = true
		facing = 1.0
	add_child(spr)
	position = Vector2(-30.0 if from_left else 390.0, G.LANE_Y[lane])
	if kind == "ptera":
		position.y = G.LANE_Y[G.LANE_HIGH] - 60.0
	_base_y = position.y
	z_index = 10 + lane
	atk_cd = randf_range(1.0, 2.5)

func _frame(i: int) -> void:
	spr.frame = clampi(i, 0, FRAMES[kind] - 1)

func _face_player() -> void:
	facing = -1.0 if player.position.x < position.x else 1.0
	spr.flip_h = facing > 0.0

func _process(delta: float) -> void:
	if state == "dead" or game.frozen:
		return
	state_t += delta
	_anim_t += delta
	atk_cd -= delta
	match kind:
		"raptor": _raptor(delta)
		"ptera": _ptera(delta)
		"anky": _anky(delta)
	# shared states
	match state:
		"stunned":
			_frame(FRAMES[kind] - 1)
			if state_t > 1.4:
				_goto("approach")
		"grabbed":
			_frame(FRAMES[kind] - 1)
		"thrown":
			position.x += _throw_dir * 700.0 * delta
			position.y = _base_y - 40.0 * sin(minf(state_t / 0.35, 1.0) * PI)
			rotation += 12.0 * delta * _throw_dir
			if not _hit_done:
				var n: int = game.melee_hit([lane], position.x - 40, position.x + 40, 15.0, {"knockdown": true, "exclude": self})
				if n > 0:
					AudioManager.play_sfx("hit")
			if state_t > 0.38 or position.x < -40 or position.x > 400:
				rotation = 0.0
				position.y = _base_y
				take_hit(20.0, {"pierce_armor": true})
				if state != "dead":
					_goto("stunned")

func _goto(s: String) -> void:
	state = s
	state_t = 0.0
	_hit_done = false

# ---------------- RAPTOR: rush + leap, scatter when pack-mate is hit ----------------
func _raptor(delta: float) -> void:
	match state:
		"approach":
			if heal_target != null and is_instance_valid(heal_target):
				var hx: float = heal_target.position.x
				facing = -1.0 if hx < position.x else 1.0
				spr.flip_h = facing > 0.0
				position.x += facing * speed * delta
				_frame(int(_anim_t * 8) % 2)
				if absf(hx - position.x) < 34.0:
					heal_target.heal(heal_target.max_hp * 0.05)
					state = "dead"
					emit_signal("enemy_died", self)
					queue_free()
				return
			_face_player()
			position.x += facing * speed * delta
			_frame(int(_anim_t * 8) % 2)
			var dist: float = absf(player.position.x - position.x)
			if dist < 95.0 and atk_cd <= 0.0 and player.lane == lane:
				_goto("windup")
		"windup":
			_frame(2)
			if state_t > 0.25:
				_goto("attack")
				AudioManager.play_sfx("dash", -8.0, 1.4)
		"attack":  # leap at godzilla
			_frame(2)
			position.x += facing * 340.0 * delta
			position.y = _base_y - 46.0 * sin(minf(state_t / 0.35, 1.0) * PI)
			if not _hit_done and absf(player.position.x - position.x) < 42.0 and player.lane == lane:
				_hit_done = true
				player.take_damage(dmg)
			if state_t > 0.35:
				position.y = _base_y
				atk_cd = randf_range(1.2, 2.2)
				_goto("scatter")
		"scatter":
			_face_player()
			position.x -= facing * speed * 1.1 * delta
			position.x = clampf(position.x, -20, 380)
			_frame(int(_anim_t * 10) % 2)
			if state_t > 0.7:
				_goto("approach")

# ---------------- PTERA: hover high, dive in an arc (GDD swoop) ----------------
func _ptera(delta: float) -> void:
	match state:
		"approach":
			_face_player()
			position.x += facing * speed * delta * 0.7
			position.y = _base_y + 8.0 * sin(_anim_t * 4.0)
			_frame(int(_anim_t * 6) % 2)
			if atk_cd <= 0.0 and absf(player.position.x - position.x) < 150.0:
				_goto("windup")
		"windup":
			_frame(0)
			spr.modulate = Color(1.6, 1.2, 1.2)
			if state_t > 0.3 + GameState.tell_bonus():
				spr.modulate = Color(1, 1, 1)
				_swoop_from = position
				_swoop_to = Vector2(player.position.x, G.LANE_Y[G.LANE_GROUND])
				_goto("attack")
		"attack":  # diagonal dive to ground lane, then climb back
			_frame(2)
			var t := minf(state_t / 0.55, 1.0)
			position = _swoop_from.lerp(_swoop_to, t)
			var cur_lane := G.LANE_GROUND if t > 0.66 else (G.LANE_MID if t > 0.33 else G.LANE_HIGH)
			z_index = 10 + cur_lane
			if not _hit_done and absf(player.position.x - position.x) < 40.0 and player.lane == cur_lane and not player.airborne:
				_hit_done = true
				player.take_damage(dmg)
			if t >= 1.0:
				_goto("recover")
		"recover":  # climb back up (2s cooldown per GDD)
			_frame(int(_anim_t * 6) % 2)
			position = position.lerp(Vector2(position.x + facing * 20.0, _base_y), 2.5 * delta)
			z_index = 10 + G.LANE_HIGH
			if state_t > 1.6:
				atk_cd = randf_range(2.0, 3.5)
				_goto("approach")

# ---------------- ANKY: slow wall, 180° tail-club spin hits behind ----------------
func _anky(delta: float) -> void:
	match state:
		"approach":
			_face_player()
			position.x += facing * speed * delta
			_frame(int(_anim_t * 3) % 2)
			if atk_cd <= 0.0 and absf(player.position.x - position.x) < 90.0:
				_goto("windup")
		"windup":
			_frame(2)
			spr.modulate = Color(1.6, 1.2, 1.2)  # 4px+ readable tell
			if state_t > 0.5 + GameState.tell_bonus():
				spr.modulate = Color(1, 1, 1)
				_goto("attack")
				AudioManager.play_sfx("tail_whip", -4.0, 0.7)
		"attack":  # spin — hits all around, stuns (GDD: 1s stun)
			_frame(2 + int(_anim_t * 12) % 2)
			if not _hit_done and state_t > 0.12:
				_hit_done = true
				if player.lane == lane and absf(player.position.x - position.x) < 78.0 and not player.airborne:
					player.take_damage(dmg, {"stun": 1.0})
			if state_t > 0.45:
				_goto("recover")  # recovery window = grabbable / punishable
		"recover":
			_frame(4)
			if state_t > 1.3:
				atk_cd = 3.0
				_goto("approach")

# ---------------- shared combat ----------------
func occupies(l: int) -> bool:
	# ptera crosses lanes during its swoop; z_index tracks the current lane
	return l == z_index - 10

func grabbable() -> bool:
	return state in ["stunned", "recover"] and kind != "ptera"

func begin_grabbed() -> void:
	_goto("grabbed")

func begin_thrown(dir: float) -> void:
	_throw_dir = dir
	_base_y = G.LANE_Y[lane]
	_goto("thrown")

func take_hit(amount: float, opts := {}) -> void:
	if state in ["dead", "grabbed"]:
		return
	# Anky armored front (GDD): frontal hits bounce unless breath/thrown pierce
	if kind == "anky" and not opts.get("pierce_armor", false):
		var from_front: bool = (player.position.x < position.x) == (not spr.flip_h)
		if from_front and state != "recover":
			amount *= 0.3
	hp -= amount
	AudioManager.play_sfx("hit", -4.0)
	spr.modulate = Color(3, 3, 3)
	var tw := create_tween()
	tw.tween_property(spr, "modulate", Color(1, 1, 1), 0.15)
	if hp <= 0.0:
		_die()
		return
	if opts.get("knockdown", false) and state != "thrown":
		position.x += 18.0 * (1.0 if position.x > player.position.x else -1.0)
		_goto("stunned")
	elif kind == "raptor" and state == "approach":
		_goto("scatter")  # pack scatters when one is hit

func _die() -> void:
	state = "dead"
	AudioManager.play_sfx({"raptor": "raptor_die", "ptera": "ptera_die", "anky": "anky_die"}[kind])
	game.spawn_explosion(position + Vector2(0, -30))
	game.add_score(G.SCORE[kind])
	emit_signal("enemy_died", self)
	var tw := create_tween()
	tw.tween_property(spr, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

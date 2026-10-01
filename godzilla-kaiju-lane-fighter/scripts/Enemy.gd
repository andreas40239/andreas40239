class_name Enemy
extends Node2D
## Regular enemies (GDD 5): raptor / ptera / anky / tank / heli / jetraptor / proto.

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
var facing := -1.0        # -1 = moving left
var spr: Sprite2D
var shield_spr: Sprite2D
var _anim_t := 0.0
var _swoop_from := Vector2.ZERO
var _swoop_to := Vector2.ZERO
var _hit_done := false
var _throw_dir := 1.0
var _base_y := 0.0
var _attack := ""
var shield_t := 0.0
var shield_cd := 4.0
var dizzy_forever := false  # training: stays grabbable until thrown
var heal_target = null   # boss-summoned raptors run to heal the boss (GDD 6.1)

const TEX := {"raptor": "raptor", "ptera": "pteranodon", "anky": "ankylosaurus", "tank": "tank",
	"heli": "helicopter", "jetraptor": "jetraptor", "proto": "mechagodzilla"}
const FRAMES := {"raptor": 4, "ptera": 4, "anky": 5, "tank": 3, "heli": 3, "jetraptor": 4, "proto": 8}
const FRAME_H := {"raptor": 32, "ptera": 24, "anky": 32, "tank": 24, "heli": 24, "jetraptor": 32, "proto": 72}
const FLYERS := ["ptera", "jetraptor"]

func setup(p_kind: String, p_game, from_left: bool) -> void:
	kind = p_kind
	game = p_game
	player = p_game.player
	var st: Dictionary = G.ENEMY[kind]
	hp = st["hp"]
	dmg = st["dmg"]
	speed = st["speed"]
	lane = st["lane"]
	var sc := 3.0 if kind == "proto" else 4.0
	spr = Sprite2D.new()
	spr.texture = load("res://assets/sprites/characters/%s.png" % TEX[kind])
	spr.hframes = FRAMES[kind]
	spr.scale = Vector2(sc, sc)
	spr.position = Vector2(0, -FRAME_H[kind] * sc * 0.5)
	if kind == "proto":
		spr.modulate = Color(0.85, 0.85, 1.0)
	if from_left:
		facing = 1.0
	spr.flip_h = facing > 0.0
	add_child(spr)
	position = Vector2(-30.0 if from_left else 390.0, G.LANE_Y[lane])
	if kind in FLYERS:
		position.y = G.LANE_Y[G.LANE_HIGH] - 60.0
	elif kind == "heli":
		position.y = G.LANE_Y[G.LANE_MID] - 40.0
	_base_y = position.y
	z_index = 10 + lane
	atk_cd = randf_range(1.0, 2.5)
	if kind == "proto":
		shield_spr = Sprite2D.new()
		shield_spr.texture = load("res://assets/sprites/fx/shield.png")
		shield_spr.scale = Vector2(5, 5)
		shield_spr.position = Vector2(0, -100)
		shield_spr.visible = false
		add_child(shield_spr)

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
		"ptera", "jetraptor": _flyer(delta)
		"anky": _anky(delta)
		"tank": _tank(delta)
		"heli": _heli(delta)
		"proto": _proto(delta)
	# shared states
	match state:
		"stunned":
			_frame(FRAMES[kind] - 1)
			if state_t > 1.4 and not dizzy_forever:
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
					_hit_done = true
					AudioManager.play_sfx("hit")
			if state_t > 0.38 or position.x < -40 or position.x > 400:
				rotation = 0.0
				position.y = _base_y
				position.x = clampf(position.x, -10.0, 370.0)
				take_hit(20.0, {"pierce_armor": true, "thrown": true})
				if state != "dead":
					_goto("stunned")

func _goto(s: String) -> void:
	state = s
	state_t = 0.0
	_hit_done = false

func _hit_player(amount: float, opts := {}) -> void:
	opts["src_x"] = position.x
	player.take_damage(amount, opts)

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
			if absf(player.position.x - position.x) < 95.0 and atk_cd <= 0.0 and player.lane == lane:
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
			if not _hit_done and absf(player.position.x - position.x) < 42.0 and player.lane == lane and not player.airborne:
				_hit_done = true
				_hit_player(dmg)
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

# ---------------- PTERA / JETPACK RAPTOR: hover high, dive in an arc ----------------
func _flyer(delta: float) -> void:
	var jet := kind == "jetraptor"
	match state:
		"approach":
			_face_player()
			position.x += facing * speed * delta * 0.7
			position.y = _base_y + 8.0 * sin(_anim_t * 4.0)
			_frame(int(_anim_t * 6) % 2)
			if atk_cd <= 0.0 and absf(player.position.x - position.x) < (180.0 if jet else 150.0):
				_goto("windup")
		"windup":
			_frame(0)
			spr.modulate = Color(1.6, 1.2, 1.2)
			if state_t > (0.25 if jet else 0.3) + GameState.tell_bonus():
				spr.modulate = Color(1, 1, 1)
				_swoop_from = position
				_swoop_to = Vector2(player.position.x, G.LANE_Y[player.lane] - (10.0 if jet else 0.0))
				_goto("attack")
		"attack":  # diagonal dive toward the player's lane, then climb back
			_frame(2)
			var t := minf(state_t / (0.45 if jet else 0.55), 1.0)
			position = _swoop_from.lerp(_swoop_to, t)
			var cur_lane := Projectile.nearest_lane(position.y + 40.0)
			z_index = 10 + cur_lane
			if not _hit_done and absf(player.position.x - position.x) < 40.0 and player.lane == cur_lane and not player.airborne:
				_hit_done = true
				_hit_player(dmg)
			if t >= 1.0:
				_goto("recover")
		"recover":  # climb back up (2s cooldown per GDD)
			_frame(int(_anim_t * 6) % 2)
			position = position.lerp(Vector2(position.x + facing * 20.0, _base_y), 2.5 * delta)
			z_index = 10 + G.LANE_HIGH
			if state_t > (1.1 if jet else 1.6):
				atk_cd = randf_range(1.5, 3.0) if jet else randf_range(2.0, 3.5)
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
					_hit_player(dmg, {"stun": 1.0})
			if state_t > 0.45:
				_goto("recover")  # recovery window = grabbable / punishable
		"recover":
			_frame(4)
			if state_t > 1.3:
				atk_cd = 3.0
				_goto("approach")

# ---------------- TANK: parks at the screen edge, laser lock-on, fires shells ----------------
func _tank(delta: float) -> void:
	var stop_x := 312.0 if facing < 0.0 else 48.0
	match state:
		"approach":
			_frame(0)
			if absf(position.x - stop_x) > 2.0:
				position.x = move_toward(position.x, stop_x, speed * delta)
			elif atk_cd <= 0.0:
				_goto("windup")
				# red laser lock-on warning 0.8s (GDD 5.2)
				var h: Hazard = game.spawn_hazard([lane], minf(position.x, player.position.x), maxf(position.x, player.position.x),
					0.8 + GameState.tell_bonus(), 0.0, 0.0, Color("ef4444"))
				h.thin = true
		"windup":
			_frame(0)
			if state_t > 0.8 + GameState.tell_bonus():
				_frame(1)
				AudioManager.play_sfx("shell")
				game.spawn_projectile("shell", lane, position.x + 40.0 * facing, Vector2(260.0 * facing, 0), dmg)
				atk_cd = 2.5
				_goto("recover")
		"recover":
			_frame(1 if state_t < 0.15 else 0)
			if state_t > 0.4:
				_goto("approach")

# ---------------- HELICOPTER: strafes a lane with guns, fires homing missiles ----------------
func _heli(delta: float) -> void:
	var hover_x := 270.0 if facing < 0.0 else 90.0
	match state:
		"approach":
			_frame(int(_anim_t * 16) % 2)
			position.x = move_toward(position.x, hover_x, speed * delta)
			position.y = _base_y + 6.0 * sin(_anim_t * 3.0)
			if atk_cd <= 0.0 and absf(position.x - hover_x) < 8.0:
				_attack = "gun" if randf() < 0.55 else "missiles"
				_goto("windup")
				spr.modulate = Color(1.6, 1.3, 1.1)
				if _attack == "gun":
					var tl := player.lane
					var x_a := 0.0 if facing < 0.0 else position.x
					var x_b := position.x if facing < 0.0 else 360.0
					var h: Hazard = game.spawn_hazard([tl], x_a, x_b, 0.7 + GameState.tell_bonus(), 0.8, dmg, Color("fbbf24"), true)
					h.src_x = position.x
		"windup":
			_frame(int(_anim_t * 16) % 2)
			if state_t > 0.5 + GameState.tell_bonus():
				spr.modulate = Color(1, 1, 1)
				if _attack == "missiles":
					AudioManager.play_sfx("shell", -2.0, 1.3)
					for i in 3:
						game.spawn_projectile("missile", lane, position.x, Vector2(150.0 * facing, -60.0 + 60.0 * i), 5.0, 2.0)
				else:
					AudioManager.play_sfx("explosion", -12.0, 2.0)
				atk_cd = randf_range(2.6, 3.6)
				_goto("recover")
		"recover":
			_frame(int(_anim_t * 16) % 2)
			if state_t > 1.0:
				_goto("approach")

# ---------------- MECHAGODZILLA PROTOTYPE (elite): jet dash, missiles, shield ----------------
func _proto(delta: float) -> void:
	shield_cd -= delta
	if shield_t > 0.0:
		shield_t -= delta
		shield_spr.visible = true
		shield_spr.modulate.a = 0.6 + 0.4 * sin(_anim_t * 10.0)
	else:
		shield_spr.visible = false
		if shield_cd <= 0.0 and state in ["approach", "recover"]:
			shield_t = 3.0
			shield_cd = 8.0
			AudioManager.play_sfx("checkpoint", -6.0, 0.6)
	match state:
		"approach":
			_face_player()
			_frame(int(_anim_t * 3) % 2)
			var want_x := player.position.x - facing * 120.0
			position.x = clampf(move_toward(position.x, want_x, speed * 0.5 * delta), 40.0, 320.0)
			if atk_cd <= 0.0:
				_attack = "dash" if randf() < 0.6 else "missiles"
				_goto("windup")
				if _attack == "dash":
					# telegraph the lane it is about to ram (0.5s, GDD)
					var tl := player.lane
					var h: Hazard = game.spawn_hazard([tl], 0.0, 360.0, 0.5 + GameState.tell_bonus(), 0.35, dmg, Color("a855f7"))
					h.src_x = position.x
					_swoop_to = Vector2(tl, 0)
				spr.modulate = Color(1.3, 1.0, 1.6)
		"windup":
			_frame(5)
			if state_t > 0.5 + GameState.tell_bonus():
				spr.modulate = Color(0.85, 0.85, 1.0)
				if _attack == "dash":
					lane = int(_swoop_to.x)
					z_index = 10 + lane
					position.y = G.LANE_Y[lane]
					_base_y = position.y
					AudioManager.play_sfx("dash", 0.0, 0.7)
					_goto("attack")
				else:
					AudioManager.play_sfx("shell", 0.0, 0.8)
					for l in 3:
						game.spawn_projectile("missile", l, position.x, Vector2(230.0 * facing, 0), 6.0)
					atk_cd = 2.5
					_goto("recover")
		"attack":  # jet dash across the lane
			_frame(3)
			position.x = clampf(position.x + facing * 520.0 * delta, 30.0, 330.0)
			if state_t > 0.4:
				atk_cd = 2.8
				_goto("recover")
		"recover":  # grab window (GDD: bait jet dash, grab during recovery)
			_frame(7)
			if state_t > 1.4 and not dizzy_forever:
				_goto("approach")

# ---------------- shared combat ----------------
func occupies(l: int) -> bool:
	# flyers cross lanes during their swoop; z_index tracks the current lane
	return l == z_index - 10

func hit_span() -> Vector2:
	var half := 40.0 if kind == "proto" else 20.0
	return Vector2(position.x - half, position.x + half)

func grabbable() -> bool:
	return state in ["stunned", "recover"] and not (kind in FLYERS) and kind != "heli"

func begin_grabbed() -> void:
	shield_t = 0.0  # grab drops the prototype's shield (GDD)
	_goto("grabbed")

func begin_thrown(dir: float) -> void:
	_throw_dir = dir
	if kind != "proto":
		lane = clampi(lane, 0, 2)
	_base_y = G.LANE_Y[lane]
	_goto("thrown")

func take_hit(amount: float, opts := {}) -> void:
	if state in ["dead", "grabbed"]:
		return
	if kind == "proto" and shield_t > 0.0:
		if opts.get("full", false) or opts.get("pulse", false):
			shield_t = 0.0  # full-charge breath breaks the shield
			AudioManager.play_sfx("explosion", -4.0, 1.4)
		elif not opts.get("thrown", false):
			AudioManager.play_sfx("hit", -6.0, 1.8)
			return
	# Anky armored front (GDD): frontal hits bounce unless breath/thrown pierce
	if kind == "anky" and not opts.get("pierce_armor", false):
		var from_front: bool = (player.position.x < position.x) == (not spr.flip_h)
		if from_front and state != "recover":
			amount *= 0.3
	hp -= amount
	AudioManager.play_sfx("hit", -4.0)
	var base_mod := spr.modulate if kind != "proto" else Color(0.85, 0.85, 1.0)
	spr.modulate = Color(3, 3, 3)
	var tw := create_tween()
	tw.tween_property(spr, "modulate", base_mod if base_mod.r < 2.0 else Color(1, 1, 1), 0.15)
	if hp <= 0.0:
		_die()
		return
	if opts.get("knockdown", false) and state != "thrown" and kind != "proto":
		if kind != "heli":
			position.x += 18.0 * (1.0 if position.x > player.position.x else -1.0)
		_goto("stunned")
	elif kind == "raptor" and state == "approach":
		_goto("scatter")  # pack scatters when one is hit

func _die() -> void:
	state = "dead"
	var sfx := {"raptor": "raptor_die", "ptera": "ptera_die", "anky": "anky_die", "jetraptor": "raptor_die"}
	AudioManager.play_sfx(sfx.get(kind, "explosion"))
	game.spawn_explosion(position + Vector2(0, -30))
	game.add_score(G.SCORE[kind])
	emit_signal("enemy_died", self)
	var tw := create_tween()
	tw.tween_property(spr, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

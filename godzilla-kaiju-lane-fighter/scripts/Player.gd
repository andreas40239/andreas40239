class_name Player
extends Node2D
## Godzilla. Lane-based movement + gesture-driven attacks (GDD 3, 4).

signal died
signal stats_changed

const WALK_SPEED := 110.0
const WHIP_FRONT := 82.0
const WHIP_BACK := 46.0

var game  # Game node (owns enemy list / fx / shake)

var lane := G.LANE_GROUND
var hp: float
var max_hp: float
var meter: float
var max_meter: float

var state := "idle"        # idle|walk|whip|charge|fire|jump|dive|throw|dead
var state_t := 0.0
var combo := 0
var combo_window := 0.0
var charge_t := 0.0
var airborne := false
var air_t := 0.0
var special_cd := 0.0
var stun_t := 0.0
var grabbed_enemy = null
var grab_hold_t := 0.0
var invuln_t := 0.0
var lane_tween: Tween

var body: Sprite2D
var fins: Sprite2D
var _anim := "idle"
var _anim_t := 0.0

const ANIMS := {
	"idle": {"frames": [0, 1], "fps": 2.5, "loop": true},
	"walk": {"frames": [2, 3, 4, 5], "fps": 8.0, "loop": true},
	"whip": {"frames": [6, 7, 8], "fps": 20.0, "loop": false},
	"jump": {"frames": [9], "fps": 1.0, "loop": true},
	"charge": {"frames": [10], "fps": 1.0, "loop": true},
	"fire": {"frames": [11], "fps": 1.0, "loop": true},
	"hurt": {"frames": [12], "fps": 1.0, "loop": true},
	"grab": {"frames": [13], "fps": 1.0, "loop": true},
	"throw": {"frames": [14], "fps": 1.0, "loop": true},
	"block": {"frames": [15], "fps": 1.0, "loop": true},
}

func _ready() -> void:
	max_hp = GameState.max_hp()
	max_meter = GameState.max_meter()
	hp = max_hp
	meter = max_meter * 0.4
	body = Sprite2D.new()
	body.texture = load("res://assets/sprites/characters/godzilla.png")
	body.hframes = 16
	body.scale = Vector2(4, 4)
	body.position = Vector2(0, -96)  # feet at node origin
	add_child(body)
	fins = Sprite2D.new()
	fins.texture = load("res://assets/sprites/characters/godzilla_fins.png")
	fins.hframes = 16
	fins.scale = Vector2(4, 4)
	fins.position = body.position
	fins.modulate = G.COL_FIN
	add_child(fins)
	position = Vector2(96, G.LANE_Y[lane])
	z_index = 10 + lane
	var ih := InputHandler
	ih.lane_up.connect(_on_lane_up)
	ih.lane_down.connect(_on_lane_down)
	ih.attack_tap.connect(_on_attack_tap)
	ih.attack_charge_start.connect(_on_charge_start)
	ih.attack_charge_release.connect(_on_charge_release)
	ih.attack_swipe.connect(_on_attack_swipe)
	ih.jump_tap.connect(_on_jump_tap)
	ih.jump_swipe.connect(_on_jump_swipe)
	ih.special_tap.connect(_on_special)

func is_blocking() -> bool:
	return InputHandler.move_axis < -0.5 and not airborne and _can_act()

func _can_act() -> bool:
	return state in ["idle", "walk"] and stun_t <= 0.0

func busy_attacking() -> bool:
	return state in ["whip", "charge", "fire", "dive", "throw"]

func _process(delta: float) -> void:
	if state == "dead" or (game != null and game.frozen):
		return
	state_t += delta
	special_cd = max(0.0, special_cd - delta)
	invuln_t = max(0.0, invuln_t - delta)
	combo_window = max(0.0, combo_window - delta)
	if combo_window <= 0.0:
		combo = 0
	meter = min(max_meter, meter + 3.0 * delta)  # slow passive regen
	if stun_t > 0.0:
		stun_t -= delta
		_play("hurt")
		emit_signal("stats_changed")
		return
	match state:
		"idle", "walk":
			var ax := InputHandler.move_axis
			if is_blocking():
				_play("block")
				state = "idle"
			elif absf(ax) > 0.2:
				position.x = clampf(position.x + ax * WALK_SPEED * delta, G.PLAY_LEFT, G.PLAY_RIGHT - 60.0)
				state = "walk"
				_play("walk")
				_try_grab()
			else:
				state = "idle"
				_play("idle" if grabbed_enemy == null else "grab")
		"whip":
			if state_t >= 0.18:
				state = "idle"
		"charge":
			charge_t += delta
			meter -= 32.0 * delta
			_play("charge")
			if meter <= 0.0 or charge_t >= 2.0:
				_fire_breath()
		"fire":
			if state_t >= 0.35:
				state = "idle"
		"jump":
			air_t -= delta
			if air_t <= 0.0:
				airborne = false
				state = "idle"
				AudioManager.play_sfx("land", -4.0)
				game.spawn_dust(position)
				game.melee_hit([lane], position.x - 55, position.x + 55, 8.0 * GameState.melee_mult(), {"knockdown": true})
		"dive":
			air_t -= delta
			if air_t <= 0.0:
				airborne = false
				state = "idle"
				AudioManager.play_sfx("land")
				AudioManager.play_sfx("stomp")
				game.shake(6.0)
				game.spawn_shockwave(position)
				game.melee_hit([G.LANE_GROUND], position.x - 95, position.x + 95, 15.0 * GameState.melee_mult(), {"knockdown": true})
		"throw":
			if state_t >= 0.2:
				state = "idle"
	if grabbed_enemy != null:
		grab_hold_t += delta
		if is_instance_valid(grabbed_enemy):
			grabbed_enemy.global_position = global_position + Vector2(34, -70)
		if grab_hold_t > 3.0:
			_do_throw()
	_animate(delta)
	emit_signal("stats_changed")

func _animate(delta: float) -> void:
	_anim_t += delta
	var a: Dictionary = ANIMS[_anim]
	var frames: Array = a["frames"]
	var idx := int(_anim_t * a["fps"])
	if a["loop"]:
		idx = idx % frames.size()
	else:
		idx = mini(idx, frames.size() - 1)
	body.frame = frames[idx]
	fins.frame = frames[idx]

func _play(anim: String) -> void:
	if _anim == anim:
		return
	_anim = anim
	_anim_t = 0.0

func fin_color() -> Color:
	# Fins ARE the HUD (GDD 4.4)
	if state == "charge":
		return Color(1, 1, 1)
	if hp < max_hp * 0.25:
		return Color(0.55, 0.6, 0.6)
	if meter >= max_meter * 0.95:
		var p := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.012)
		return Color(G.COL_FIN.r * p + (1.0 - p), G.COL_FIN.g, G.COL_FIN.b)
	if meter < max_meter * 0.3:
		return G.COL_FIN_DIM
	return G.COL_FIN

# ---------- lane movement ----------
func _switch_lane(dir: int) -> void:
	if airborne or not (_can_act() or state == "walk"):
		return
	var target: int = clampi(lane + dir, 0, 2)
	if target == lane:
		return
	lane = target
	z_index = 10 + lane
	AudioManager.play_sfx("lane_switch", -10.0)
	if lane_tween:
		lane_tween.kill()
	lane_tween = create_tween()
	lane_tween.tween_property(self, "position:y", G.LANE_Y[lane], GameState.lane_switch_time())

func _on_lane_up() -> void: _switch_lane(-1)
func _on_lane_down() -> void: _switch_lane(1)

# ---------- attacks ----------
func _on_attack_tap() -> void:
	if grabbed_enemy != null:
		_do_throw()
		return
	if not _can_act():
		return
	combo = (combo + 1) if combo_window > 0.0 else 1
	combo_window = 0.45
	state = "whip"
	state_t = 0.0
	_play("whip")
	AudioManager.play_sfx("tail_whip", 0.0, 1.0 + 0.08 * combo)
	var dmg := 10.0 * GameState.melee_mult()
	var opts := {}
	if combo >= 3:
		dmg *= 1.5
		opts = {"knockdown": true, "stun": 1.0}
		combo = 0
	var w := 6.0 if GameState.has_upg("claws") else 0.0
	var hits: int = game.melee_hit([lane], position.x - WHIP_BACK - w, position.x + WHIP_FRONT + w, dmg, opts)
	if hits > 0:
		meter = min(max_meter, meter + 4.0 * hits)

func _on_attack_swipe(dir: Vector2) -> void:
	if grabbed_enemy != null:
		_do_throw()
		return
	if not _can_act():
		return
	state = "whip"
	state_t = 0.0
	_play("whip")
	var dmg := 12.0 * GameState.melee_mult()
	var hits := 0
	if dir.x > 0:  # dash-claw: lunge forward
		AudioManager.play_sfx("dash")
		var from_x := position.x
		position.x = clampf(position.x + 90.0, G.PLAY_LEFT, G.PLAY_RIGHT - 40.0)
		hits = game.melee_hit([lane], from_x, position.x + 50.0, dmg, {})
	elif dir.y < 0:  # anti-air tail
		AudioManager.play_sfx("tail_whip", 0.0, 1.3)
		var lanes := [lane]
		if lane > 0:
			lanes.append(lane - 1)
		hits = game.melee_hit(lanes, position.x - 30.0, position.x + 80.0, dmg, {"knockdown": true})
	elif dir.y > 0:  # ground pound
		AudioManager.play_sfx("stomp")
		game.shake(3.0)
		var lanes2 := [lane]
		if lane < 2:
			lanes2.append(lane + 1)
		hits = game.melee_hit(lanes2, position.x - 55.0, position.x + 75.0, dmg, {"knockdown": true, "stun": 0.8})
	else:  # swipe left → quick back whip
		AudioManager.play_sfx("tail_whip")
		hits = game.melee_hit([lane], position.x - 95.0, position.x + 20.0, dmg, {})
	if hits > 0:
		meter = min(max_meter, meter + 4.0 * hits)

func _on_charge_start() -> void:
	if not _can_act() or meter < 12.0 or grabbed_enemy != null:
		return
	state = "charge"
	state_t = 0.0
	charge_t = 0.0
	AudioManager.play_sfx("breath_charge")

func _on_charge_release() -> void:
	if state == "charge":
		_fire_breath()

func _fire_breath() -> void:
	state = "fire"
	state_t = 0.0
	_play("fire")
	AudioManager.play_sfx("breath_fire")
	game.shake(4.0)
	var dmg := 15.0 + 22.0 * charge_t
	game.spawn_beam(position + Vector2(48, -108), lane)
	game.melee_hit([lane], position.x + 20.0, 999.0, dmg, {"pierce_armor": true, "breath": true})
	charge_t = 0.0

func _on_jump_tap() -> void:
	if not _can_act():
		return
	_start_air("jump", 0.5)
	AudioManager.play_sfx("jump", -4.0)

func _on_jump_swipe(dir: Vector2) -> void:
	if dir.y < 0:  # high leap
		if not _can_act():
			return
		_start_air("jump", 0.75)
		AudioManager.play_sfx("jump")
	elif dir.y > 0:  # dive slam → ground lane
		if not (_can_act() or state == "jump"):
			return
		lane = G.LANE_GROUND
		z_index = 10 + lane
		if lane_tween:
			lane_tween.kill()
		lane_tween = create_tween()
		lane_tween.tween_property(self, "position:y", G.LANE_Y[lane], 0.12)
		_start_air("dive", 0.16)

func _start_air(kind: String, dur: float) -> void:
	state = kind
	state_t = 0.0
	air_t = dur
	airborne = true
	_play("jump")
	var tw := create_tween()
	tw.tween_property(body, "position:y", -96.0 - 40.0, dur * 0.4)
	tw.tween_property(body, "position:y", -96.0, dur * 0.6)
	var tw2 := create_tween()
	tw2.tween_property(fins, "position:y", -96.0 - 40.0, dur * 0.4)
	tw2.tween_property(fins, "position:y", -96.0, dur * 0.6)

func _on_special() -> void:
	# 360° Nuclear Pulse (GDD 3.4): clears immediate lane, cooldown-based.
	if special_cd > 0.0 or not _can_act():
		return
	special_cd = 10.0
	AudioManager.play_sfx("pulse")
	AudioManager.play_sfx("gz_roar", -6.0)
	game.shake(8.0)
	game.spawn_pulse(position)
	var lanes := [lane]
	if lane > 0: lanes.append(lane - 1)
	if lane < 2: lanes.append(lane + 1)
	game.melee_hit(lanes, position.x - 130.0, position.x + 130.0, 30.0, {"knockdown": true, "pierce_armor": true})

# ---------- grab & throw (GDD 3.4: walk into stunned enemy) ----------
func _try_grab() -> void:
	if grabbed_enemy != null:
		return
	var e = game.find_grabbable(lane, position.x, 46.0)
	if e != null:
		grabbed_enemy = e
		grab_hold_t = 0.0
		e.begin_grabbed()
		AudioManager.play_sfx("grab")
		_play("grab")

func _do_throw() -> void:
	if grabbed_enemy == null:
		return
	state = "throw"
	state_t = 0.0
	_play("throw")
	AudioManager.play_sfx("throw")
	var e = grabbed_enemy
	grabbed_enemy = null
	if is_instance_valid(e):
		e.begin_thrown(1.0 if InputHandler.move_axis >= 0.0 else -1.0)

# ---------- damage ----------
func take_damage(dmg: float, opts := {}) -> void:
	if state == "dead" or invuln_t > 0.0:
		return
	if airborne and opts.get("dodge_air", false):
		return
	if GameState.mercy_active(GameState.current_level):
		dmg *= 0.7
	if is_blocking():
		dmg *= 0.6
		AudioManager.play_sfx("hit", -6.0)
	else:
		AudioManager.play_sfx("gz_hurt", -3.0)
		stun_t = maxf(stun_t, float(opts.get("stun", 0.25)))
		_flash()
	hp -= dmg
	game.shake(3.0)
	if grabbed_enemy != null:
		_do_throw()
	if hp <= 0.0:
		hp = 0.0
		state = "dead"
		_play("hurt")
		emit_signal("died")
	emit_signal("stats_changed")

func apply_stun(dur: float) -> void:
	if state == "dead":
		return
	if is_blocking():
		dur *= 0.4
	stun_t = maxf(stun_t, dur)

func _flash() -> void:
	body.modulate = Color(3, 3, 3)
	invuln_t = 0.35
	var tw := create_tween()
	tw.tween_property(body, "modulate", Color(1, 1, 1), 0.25)

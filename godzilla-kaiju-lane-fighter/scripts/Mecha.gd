class_name Mecha
extends BossBase
## MECHAGODZILLA — Level 8 final boss (GDD 6.3). Three phases.

var coat_t := 0.0
var _pending := ""

# frames: 0,1 idle | 2 chest missiles | 3 dash | 4 plasma breath | 5 eyes flash | 6 zero charge | 7 hurt

func setup(p_game) -> void:
	game = p_game
	player = p_game.player
	max_hp = G.BOSS_HP["mecha"]
	hp = max_hp
	phase_marks = [0.66, 0.33]
	_make_sprite("mechagodzilla", 8, 4.0, 72.0)
	position = Vector2(440.0, G.LANE_Y[G.LANE_GROUND])
	z_index = 14
	AudioManager.play_sfx("boss_roar", 0.0, 1.3)

func hit_span() -> Vector2:
	return Vector2(position.x - 80.0, position.x + 50.0)

func _face_player() -> void:
	spr.flip_h = player.position.x > position.x

func _process(delta: float) -> void:
	if state == "dead" or game.frozen:
		return
	state_t += delta
	_anim_t += delta
	atk_cd -= delta * _speed_mult
	if coat_t > 0.0:
		coat_t -= delta
		spr.modulate = Color(1.4, 1.6, 2.0) if int(_anim_t * 10) % 2 == 0 else Color(1, 1, 1.3)
		if coat_t <= 0.0:
			spr.modulate = base_mod
	match state:
		"intro":
			position.x = move_toward(position.x, 280.0, 70.0 * delta)
			spr.frame = int(_anim_t * 4) % 2
			if position.x <= 280.0:
				_goto("idle")
		"idle":
			spr.frame = int(_anim_t * 4) % 2
			_face_player()
			var side := 1.0 if position.x >= player.position.x else -1.0
			var tx := clampf(player.position.x + side * 120.0, 60.0, 310.0)
			position.x = move_toward(position.x, tx, 50.0 * _speed_mult * delta)
			if atk_cd <= 0.0:
				_choose_attack()
		"plasma_wind":  # mouth glows white, column beam through all 3 lanes
			spr.frame = 4
			if not _hit_done and state_t > _wind_time(0.8):
				_hit_done = true
				_clear_tell()
				AudioManager.play_sfx("breath_fire", 0.0, 0.8)
				game.shake(5.0)
			if state_t > _wind_time(0.8) + 0.45:
				_goto("recover")
		"barrage":
			spr.frame = 2
			if state_t > 0.6:
				_goto("recover")
		"fingers":
			spr.frame = 2
			if state_t > 0.8:
				_goto("recover")
		"teleport":  # static crackle → vanish → reappear behind → CLANG
			if state_t < 0.3:
				spr.modulate.a = 1.0 - state_t / 0.3
			elif not _hit_done:
				_hit_done = true
				position.x = clampf(player.position.x - player.facing * 90.0, 40.0, 320.0)
				_face_player()
				spr.modulate.a = 1.0
				spr.frame = 3
				AudioManager.play_sfx("grab", 0.0, 0.5)  # metallic clang = attack behind you
			elif state_t > 0.3 + 0.35 + GameState.tell_bonus():
				if player.lane in [G.LANE_MID, G.LANE_GROUND] \
						and absf(player.position.x - position.x) < 110.0 and not player.airborne:
					_hit_player(14.0, {"stun": 0.6})
				_goto("recover")
		"zero_wind":  # ABSOLUTE ZERO: 2s charge. Breath or Nuke cancels it!
			spr.frame = 6
			game.frost = minf(1.0, state_t / 2.0)
			if state_t > 2.0 + GameState.tell_bonus():
				game.frost = 0.0
				game.spawn_hazard([0, 1, 2], 0.0, 360.0, 0.05, 0.4, 12.0, Color("7dd3fc"), true).stun = 2.5
				AudioManager.play_sfx("pulse", 0.0, 1.5)
				game.shake(10.0)
				_goto("recover")
		"stunned":
			spr.frame = 7
			if state_t > 2.5:
				_goto("idle")
		"recover":
			spr.frame = 7 if state_t < 0.3 else int(_anim_t * 4) % 2
			if state_t > 1.3 / _speed_mult:
				atk_cd = randf_range(0.6, 1.4)
				_goto("idle")

func _choose_attack() -> void:
	var opts := ["plasma", "barrage", "coat"]
	if phase >= 2:
		opts += ["fingers", "teleport", "teleport"]
	if phase >= 3:
		opts += ["zero", "zero"]
	_pending = opts[randi() % opts.size()]
	if _pending == "coat" and coat_t > 0.0:
		_pending = "plasma"
	match _pending:
		"plasma":
			_tell("breath_charge", Color(1.6, 1.6, 2.0))
			var cx := player.position.x
			var h: Hazard = game.spawn_hazard([0, 1, 2], cx - 45.0, cx + 45.0, _wind_time(0.8), 0.45, 16.0, Color("e0f2fe"))
			h.src_x = position.x
			_goto("plasma_wind")
		"barrage":
			_tell("shell", Color(1.8, 1.4, 0.8))
			var dir := -1.0 if player.position.x < position.x else 1.0
			for l in 3:
				for k in 2:
					game.spawn_projectile("missile", l, position.x + dir * (40.0 + 30.0 * k), Vector2(dir * (200.0 + 40.0 * k), 0), 6.0)
			_goto("barrage")
		"coat":  # diamond coating: melee bounces back, use the breath!
			coat_t = 5.0
			AudioManager.play_sfx("checkpoint", -2.0, 1.4)
			game.flash_message("DIAMOND COATING!")
			_goto("recover")
		"fingers":
			_tell("shell", Color(1.8, 1.4, 0.8))
			for i in 6:
				game.spawn_projectile("missile", randi() % 3, position.x, Vector2(-120.0 if player.position.x < position.x else 120.0, -150.0 + 60.0 * i), 4.0, 3.0)
			_goto("fingers")
		"teleport":
			AudioManager.play_sfx("lane_switch", 4.0, 0.4)  # static crackle
			_goto("teleport")
		"zero":
			_tell("breath_charge", Color(0.7, 1.4, 2.2))
			game.flash_message("FREEZE BEAM! HIT IT NOW!")
			_goto("zero_wind")

func take_hit(amount: float, opts := {}) -> void:
	if state in ["dead", "intro"]:
		return
	if state == "zero_wind" and (opts.get("breath", false) or opts.get("pulse", false)):
		game.frost = 0.0
		AudioManager.play_sfx("explosion", 0.0, 0.8)
		game.flash_message("CANNON BROKEN!")
		_goto("stunned")
	if coat_t > 0.0:
		if opts.get("breath", false) or opts.get("pulse", false):
			coat_t = 0.0  # breath shatters the coating
			spr.modulate = base_mod
			AudioManager.play_sfx("explosion", -4.0, 1.5)
		elif not opts.get("reflected", false):
			AudioManager.play_sfx("hit", 0.0, 2.0)
			if not opts.get("thrown", false):
				_hit_player(3.0, {"unblockable": true})  # recoil
			return
	if not _apply_damage(amount):
		return
	if hp <= 0.0:
		game.frost = 0.0
		return
	if phase == 1 and hp <= max_hp * 0.66:
		phase = 2
		_speed_mult = 1.2
		game.flash_message("ENDOSKELETON REVEALED!")
		AudioManager.play_sfx("boss_roar", 0.0, 1.4)
		game.shake(8.0)
	elif phase == 2 and hp <= max_hp * 0.33:
		phase = 3
		_speed_mult = 1.35
		game.flash_message("CORE OVERLOAD!")
		AudioManager.play_sfx("boss_roar", 2.0, 1.5)
		game.shake(10.0)
	elif phase == 3 and hp <= max_hp * 0.1 and _speed_mult < 1.6:
		_speed_mult = 1.7  # final overdrive
		game.flash_message("FINAL OVERDRIVE!")

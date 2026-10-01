class_name Boss
extends BossBase
## TYRANNOKING — Level 3 boss (GDD 6.1). Two phases, pattern-based.
## With mini=true it is the smaller T-Rex mini-boss of Level 4.

var summons_alive := 0

# frames: 0,1 idle/walk | 2 bite windup | 3 bite | 4 tail windup | 5 tail spin | 6 roar | 7 hurt

func setup(p_game, p_mini := false, from_left := false) -> void:
	game = p_game
	player = p_game.player
	mini = p_mini
	max_hp = G.BOSS_HP["trex" if mini else "tyrannoking"]
	hp = max_hp
	phase_marks = [0.6]
	_make_sprite("tyrannoking", 8, 3.0 if mini else 4.0, 72.0)
	if mini:
		base_mod = Color(0.8, 1.0, 0.8)
		spr.modulate = base_mod
	position = Vector2(430.0, G.LANE_Y[G.LANE_GROUND])
	z_index = 14
	AudioManager.play_sfx("boss_roar", 0.0, 1.2 if mini else 1.0)

func hit_span() -> Vector2:
	return Vector2(position.x - (65.0 if mini else 90.0), position.x + 30.0)

func _process(delta: float) -> void:
	if state == "dead" or game.frozen:
		return
	state_t += delta
	_anim_t += delta
	atk_cd -= delta / _speed_mult
	var reach := 0.75 if mini else 1.0
	match state:
		"intro":
			position.x = move_toward(position.x, 268.0, 60.0 * delta)
			_frame_walk()
			if position.x <= 268.0:
				_goto("idle")
		"idle":
			_frame_walk()
			# stalk the player, staying on the side it came from
			var tx: float = clampf(player.position.x + 130.0 * reach, 120.0, 310.0)
			position.x = move_toward(position.x, tx, 42.0 * _speed_mult * delta)
			if atk_cd <= 0.0:
				_choose_attack()
		"bite_wind":  # jaws glow red, 0.6s (GDD tell)
			spr.frame = 2
			if state_t > _wind_time(0.6):
				_clear_tell()
				_goto("bite")
				AudioManager.play_sfx("bite")
		"bite":  # lunge forward in ground lane — dodge to high/mid
			spr.frame = 3
			position.x = maxf(40.0, position.x - 420.0 * _speed_mult * delta)
			if not _hit_done and player.lane == G.LANE_GROUND and absf(player.position.x - position.x + 40.0 * reach) < 78.0 * reach and not player.airborne:
				_hit_done = true
				_hit_player(12.0 if mini else 18.0)
			if state_t > 0.35 / _speed_mult:
				if phase == 2 and randf() < 0.5 and not _hit_done:
					_goto("bite")  # blood frenzy: chained bites
				else:
					_goto("recover")
		"tail_wind":  # tail trembles 0.5s
			spr.frame = 4
			if state_t > _wind_time(0.5):
				_clear_tell()
				_goto("tail")
				AudioManager.play_sfx("tail_whip", 0.0, 0.6)
		"tail":  # cyclone hits MID + HIGH — drop to ground!
			spr.frame = 5 if int(_anim_t * 14) % 2 == 0 else 4
			if state_t > 0.15 and not _hit_done and player.lane in [G.LANE_MID, G.LANE_HIGH] \
					and absf(player.position.x - position.x) < 150.0 * reach and not player.airborne:
				_hit_done = true
				_hit_player(11.0 if mini else 16.0, {"stun": 0.4})
			if state_t > 1.2 / _speed_mult:
				_goto("recover")
		"roar_wind":  # chest puffs 0.8s — interrupt with charged breath!
			spr.frame = 6
			if state_t > _wind_time(0.8):
				_clear_tell()
				_goto("roar")
				AudioManager.play_sfx("boss_roar")
				game.shake(7.0)
		"roar":  # stuns all lanes 1.2s unless you back away
			spr.frame = 6
			if not _hit_done and state_t > 0.1:
				_hit_done = true
				player.apply_stun(0.8 if mini else 1.2, position.x)
			if state_t > 0.9:
				_goto("recover")
		"quake_wind":  # phase 2: rears up 0.7s — be airborne!
			spr.frame = 6
			position.y = G.LANE_Y[G.LANE_GROUND] - 20.0
			if state_t > _wind_time(0.7):
				_clear_tell()
				position.y = G.LANE_Y[G.LANE_GROUND]
				_goto("quake")
				AudioManager.play_sfx("stomp")
				AudioManager.play_sfx("explosion", -6.0)
				game.shake(10.0)
				game.spawn_shockwave(position + Vector2(-60, 0))
		"quake":  # shockwave hits ALL lanes unless airborne
			spr.frame = 1
			if not _hit_done and state_t > 0.05:
				_hit_done = true
				if not player.airborne:
					_hit_player(20.0, {"stun": 0.5, "unblockable": true})
			if state_t > 0.5:
				_goto("recover")
		"summon":
			spr.frame = 6
			if not _hit_done and state_t > 0.4:
				_hit_done = true
				AudioManager.play_sfx("boss_roar", -8.0, 1.4)
				for i in 4:
					var r = game.spawn_enemy("raptor", i % 2 == 1)
					r.heal_target = self
					summons_alive += 1
					r.enemy_died.connect(func(_e): summons_alive -= 1)
			if state_t > 1.0:
				_goto("recover")
		"recover":  # 1.5s punish window (GDD strategy)
			_frame_walk()
			if state_t > 1.5 / _speed_mult:
				atk_cd = randf_range(0.8, 1.6) / _speed_mult
				_goto("idle")
		"stunned":  # breath-interrupted roar
			spr.frame = 7
			if state_t > 2.0:
				atk_cd = 1.0
				_goto("idle")

func _frame_walk() -> void:
	spr.frame = int(_anim_t * 4) % 2

func _choose_attack() -> void:
	var opts := ["bite", "tail", "roar"]
	if mini:
		opts = ["bite", "bite", "tail"]
	elif phase == 2:
		opts = ["bite", "tail", "quake", "quake"]
		if summons_alive <= 0 and randf() < 0.3:
			opts = ["summon"]
	match opts[randi() % opts.size()]:
		"bite":
			_goto("bite_wind")
			_tell("bite")  # audio tell before strike (GDD 10.5)
		"tail":
			_goto("tail_wind")
			_tell("tail_whip")
		"roar":
			_goto("roar_wind")
			_tell("breath_charge")
		"quake":
			_goto("quake_wind")
			_tell("stomp")
		"summon":
			_goto("summon")

func take_hit(amount: float, opts := {}) -> void:
	# charged atomic breath interrupts the roar windup (GDD counter)
	if (opts.get("breath", false) or opts.get("pulse", false)) and state == "roar_wind":
		_clear_tell()
		_goto("stunned")
		AudioManager.play_sfx("gz_hurt", 0.0, 0.6)
		game.shake(5.0)
	if not _apply_damage(amount):
		return
	if not mini and hp > 0.0 and hp <= max_hp * 0.6 and phase == 1:
		phase = 2
		_speed_mult = 1.4  # Blood Frenzy (GDD 6.1 phase 2)
		AudioManager.play_sfx("boss_roar", 2.0, 0.85)
		game.shake(8.0)
		game.flash_message("BLOOD FRENZY!")

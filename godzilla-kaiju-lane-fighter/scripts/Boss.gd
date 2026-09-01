class_name Boss
extends Node2D
## TYRANNOKING — Level 3 boss (GDD 6.1). Two phases, pattern-based.

signal boss_died
signal hp_changed(ratio: float)

var game
var player: Player
var hp := G.BOSS_HP
var max_hp := G.BOSS_HP
var phase := 1
var state := "intro"    # intro|idle|bite_wind|bite|tail_wind|tail|roar_wind|roar|quake_wind|quake|summon|stunned|recover|dead
var state_t := 0.0
var atk_cd := 2.0
var spr: Sprite2D
var _anim_t := 0.0
var _hit_done := false
var _speed_mult := 1.0
var summons_alive := 0

# frames: 0,1 idle/walk | 2 bite windup | 3 bite | 4 tail windup | 5 tail spin | 6 roar | 7 hurt

func setup(p_game) -> void:
	game = p_game
	player = p_game.player
	spr = Sprite2D.new()
	spr.texture = load("res://assets/sprites/characters/tyrannoking.png")
	spr.hframes = 8
	spr.scale = Vector2(4, 4)
	spr.position = Vector2(0, -144)
	add_child(spr)
	position = Vector2(430.0, G.LANE_Y[G.LANE_GROUND])
	z_index = 14
	AudioManager.play_sfx("boss_roar")

func occupies(l: int) -> bool:
	# occupies ground + mid (GDD 5.1); during tail spin it threatens mid+high
	return l in [G.LANE_MID, G.LANE_GROUND]

func grabbable() -> bool:
	return false

func _tell(sfx: String) -> void:
	AudioManager.play_sfx(sfx)
	spr.modulate = Color(1.7, 1.15, 1.15)

func _clear_tell() -> void:
	spr.modulate = Color(1, 1, 1)

func _wind_time(base: float) -> float:
	return (base + GameState.tell_bonus()) / _speed_mult

func _process(delta: float) -> void:
	if state == "dead" or game.frozen:
		return
	state_t += delta
	_anim_t += delta
	atk_cd -= delta / _speed_mult
	match state:
		"intro":
			position.x = move_toward(position.x, 268.0, 60.0 * delta)
			_frame_walk()
			if position.x <= 268.0:
				_goto("idle")
		"idle":
			_frame_walk()
			# stalk the player slowly
			var tx: float = clampf(player.position.x + 130.0, 220.0, 300.0)
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
			position.x -= 420.0 * _speed_mult * delta
			if not _hit_done and player.lane == G.LANE_GROUND and absf(player.position.x - position.x + 40.0) < 78.0 and not player.airborne:
				_hit_done = true
				player.take_damage(18.0)
			if state_t > 0.35 / _speed_mult:
				if phase == 2 and randf() < 0.5 and not _hit_done:
					_goto("bite")  # blood frenzy: chained bites
					_hit_done = false
				else:
					_goto("recover")
		"tail_wind":  # tail trembles 0.5s
			spr.frame = 4
			if state_t > _wind_time(0.5):
				_clear_tell()
				_goto("tail")
				AudioManager.play_sfx("tail_whip", 0.0, 0.6)
		"tail":  # cyclone hits MID + HIGH for 1.2s — drop to ground!
			spr.frame = 5 if int(_anim_t * 14) % 2 == 0 else 4
			if state_t > 0.15 and player.lane in [G.LANE_MID, G.LANE_HIGH] \
					and absf(player.position.x - position.x) < 150.0 and not player.airborne:
				if not _hit_done:
					_hit_done = true
					player.take_damage(16.0, {"stun": 0.4})
			if state_t > 1.2 / _speed_mult:
				_goto("recover")
		"roar_wind":  # chest puffs 0.8s — interrupt with charged breath!
			spr.frame = 6
			if state_t > _wind_time(0.8):
				_clear_tell()
				_goto("roar")
				AudioManager.play_sfx("boss_roar")
				game.shake(7.0)
		"roar":  # stuns all lanes 1.2s unless blocked
			spr.frame = 6
			if not _hit_done and state_t > 0.1:
				_hit_done = true
				player.apply_stun(1.2)
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
					player.take_damage(20.0, {"stun": 0.5})
			if state_t > 0.5:
				_goto("recover")
		"summon":
			spr.frame = 6
			if not _hit_done and state_t > 0.4:
				_hit_done = true
				AudioManager.play_sfx("boss_roar", -8.0, 1.4)
				for i in 4:
					var from_left := i % 2 == 1
					var r = game.spawn_enemy("raptor", from_left)
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

func _goto(s: String) -> void:
	state = s
	state_t = 0.0
	if s != "bite":
		_hit_done = false
	else:
		_hit_done = false

func _choose_attack() -> void:
	var opts := ["bite", "tail", "roar"]
	if phase == 2:
		opts = ["bite", "tail", "quake", "quake"]
		if summons_alive <= 0 and randf() < 0.3:
			opts = ["summon"]
	var pick: String = opts[randi() % opts.size()]
	match pick:
		"bite":
			_goto("bite_wind")
			_tell("bite")  # audio tell 0.3s+ before strike (GDD 10.5)
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

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	emit_signal("hp_changed", hp / max_hp)

func take_hit(amount: float, opts := {}) -> void:
	if state in ["dead", "intro"]:
		return
	# charged atomic breath interrupts the roar windup (GDD counter)
	if opts.get("breath", false) and state == "roar_wind":
		_clear_tell()
		_goto("stunned")
		AudioManager.play_sfx("gz_hurt", 0.0, 0.6)
		game.shake(5.0)
	hp -= amount
	AudioManager.play_sfx("hit", -2.0)
	var flash := spr.modulate
	spr.modulate = Color(3, 3, 3)
	var tw := create_tween()
	tw.tween_property(spr, "modulate", Color(1, 1, 1), 0.12)
	emit_signal("hp_changed", hp / max_hp)
	if hp <= max_hp * 0.6 and phase == 1:
		phase = 2
		_speed_mult = 1.4  # Blood Frenzy (GDD 6.1 phase 2)
		AudioManager.play_sfx("boss_roar", 2.0, 0.85)
		game.shake(8.0)
		game.flash_message("BLOOD FRENZY!")
	if hp <= 0.0:
		_die()

func _die() -> void:
	state = "dead"
	game.add_score(G.SCORE["boss"])
	AudioManager.play_sfx("boss_roar", 0.0, 0.7)
	game.shake(12.0)
	for i in 5:
		game.spawn_explosion(position + Vector2(randf_range(-60, 40), randf_range(-160, -20)))
	var tw := create_tween()
	tw.tween_property(spr, "modulate", Color(2, 0.5, 0.5, 0.0), 1.2)
	tw.tween_callback(func(): emit_signal("boss_died"); queue_free())

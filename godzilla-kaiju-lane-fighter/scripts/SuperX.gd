class_name SuperX
extends BossBase
## SUPER X — Level 6 boss (GDD 6.2). Flying fortress, ranged patterns.
## Phase 1 hovers in the HIGH lane, phase 2 descends to MID,
## phase 3 starts a self-destruct countdown (DPS race).
## Colour tells: red = laser, yellow = missiles, purple = gravity, green = drones.

var cur_lane := G.LANE_HIGH
var shield_t := 0.0
var shield_hits := 0
var countdown := -1.0
var shield_spr: Sprite2D
var _pending := ""
var _fired := 0

const TELL := {"laser": Color(2.0, 0.6, 0.6), "missiles": Color(2.0, 1.8, 0.5),
	"gravity": Color(1.6, 0.7, 2.0), "drones": Color(0.7, 2.0, 0.8), "shield": Color(0.7, 1.8, 1.8)}

func setup(p_game) -> void:
	game = p_game
	player = p_game.player
	max_hp = G.BOSS_HP["superx"]
	hp = max_hp
	phase_marks = [0.7, 0.35]
	_make_sprite("superx", 4, 3.0, 48.0)
	shield_spr = Sprite2D.new()
	shield_spr.texture = load("res://assets/sprites/fx/shield.png")
	shield_spr.scale = Vector2(7, 5)
	shield_spr.position = spr.position
	shield_spr.visible = false
	add_child(shield_spr)
	position = Vector2(470.0, G.LANE_Y[cur_lane] - 10.0)
	z_index = 14
	AudioManager.play_sfx("explosion", -4.0, 0.5)

func occupies(l: int) -> bool:
	return l == cur_lane

func hit_span() -> Vector2:
	return Vector2(position.x - 96.0, position.x + 96.0)

func _process(delta: float) -> void:
	if state == "dead" or game.frozen:
		return
	state_t += delta
	_anim_t += delta
	atk_cd -= delta * _speed_mult
	spr.position.y = -72.0 + 5.0 * sin(_anim_t * 2.0)
	shield_spr.position.y = spr.position.y
	if shield_t > 0.0:
		shield_t -= delta
		shield_spr.visible = true
		shield_spr.modulate.a = 0.5 + 0.4 * sin(_anim_t * 12.0)
		if shield_t <= 0.0:
			shield_spr.visible = false
	if countdown > 0.0:
		countdown -= delta
		game.hud.timer_text = "SELF-DESTRUCT %d" % ceili(countdown)
		if countdown <= 0.0:
			game.hud.timer_text = ""
			game.shake(14.0)
			AudioManager.play_sfx("explosion")
			player.take_damage(9999.0, {"unblockable": true})
	match state:
		"intro":
			spr.frame = 0
			position.x = move_toward(position.x, 270.0, 90.0 * delta)
			if position.x <= 270.0:
				_goto("idle")
		"idle":
			spr.frame = 0
			if atk_cd <= 0.0:
				_choose_attack()
		"tell":  # colour flash before each attack (0.3s in phase 3, GDD)
			if state_t > (0.3 if phase == 3 else 0.5) + GameState.tell_bonus():
				_clear_tell()
				_do_attack(_pending)
		"laser":  # lock-on reticle 1s, then sweep (dodge after lock completes)
			spr.frame = 2
			if state_t > (1.0 + 1.0) / _speed_mult + GameState.tell_bonus():
				_goto("recover")
		"missiles":
			spr.frame = 1
			var n := int(state_t / (0.15 / _speed_mult))
			var lanes := [2, 2, 1, 1, 0]
			while _fired < mini(n + 1, lanes.size()):
				var l: int = lanes[_fired]
				game.spawn_projectile("missile", l, position.x - 70.0, Vector2(-230.0 * _speed_mult, 0), 6.0)
				AudioManager.play_sfx("shell", -6.0, 1.2)
				_fired += 1
			if state_t > 1.0:
				_goto("recover")
		"drones":
			spr.frame = 1
			if state_t > 1.0:
				_goto("recover")
		"gravity":
			spr.frame = 2
			if state_t > 1.5:
				_goto("recover")
		"recover":
			spr.frame = 0
			if state_t > 1.2 / _speed_mult:
				atk_cd = randf_range(0.6, 1.4)
				_goto("idle")


func _choose_attack() -> void:
	var opts := ["laser", "missiles", "shield"]
	if phase >= 2:
		opts = ["laser", "missiles", "drones", "gravity", "shield"]
	_pending = opts[randi() % opts.size()]
	if _pending == "shield" and shield_t > 0.0:
		_pending = "laser"
	if _pending == "missiles":
		AudioManager.play_sfx("grab", 0.0, 0.5)  # "clank" of bay doors
	elif _pending == "laser":
		AudioManager.play_sfx("breath_charge", -4.0, 1.6)  # charging whine
	_tell("", TELL[_pending])
	_goto("tell")

func _do_attack(kind: String) -> void:
	match kind:
		"laser":
			var tl := player.lane
			var h: Hazard = game.spawn_hazard([tl], 0.0, position.x - 60.0, 1.0 / _speed_mult + GameState.tell_bonus(),
				1.0, 14.0 * (2.0 if phase == 3 else 1.0), Color("ef4444"), true)
			h.src_x = position.x
			_goto("laser")
		"missiles":
			_fired = 0
			_goto("missiles")
		"shield":  # projectiles bounce; 4 tail whips break it (GDD)
			shield_t = 4.0
			shield_hits = 4
			AudioManager.play_sfx("checkpoint", -4.0, 0.6)
			_goto("recover")
		"drones":
			for i in 4:
				game.spawn_projectile("drone", randi() % 3, position.x - 40.0,
					Vector2(-140.0, randf_range(-80.0, 80.0)), 5.0, 2.5)
			AudioManager.play_sfx("shell", 0.0, 1.6)
			_goto("drones")
		"gravity":  # pulls Godzilla to the centre lane + homing missiles
			player.force_lane(G.LANE_MID, 0.4)
			for i in 2:
				game.spawn_projectile("missile", G.LANE_MID, position.x - 50.0, Vector2(-160.0, -90.0 + 180.0 * i), 6.0, 2.0)
			_goto("gravity")

func take_hit(amount: float, opts := {}) -> void:
	if state in ["dead", "intro"]:
		return
	if shield_t > 0.0:
		if opts.get("breath", false) or opts.get("reflected", false):
			AudioManager.play_sfx("hit", -4.0, 1.8)  # reflected away — don't breathe on the shield!
			return
		shield_hits -= 1
		AudioManager.play_sfx("hit", -2.0, 1.5)
		if shield_hits <= 0 or opts.get("pulse", false):
			shield_t = 0.0
			shield_spr.visible = false
			AudioManager.play_sfx("explosion", -4.0, 1.3)
		return
	if not _apply_damage(amount):
		return
	if hp <= 0.0:
		game.hud.timer_text = ""
		return
	if phase == 1 and hp <= max_hp * 0.7:
		phase = 2
		cur_lane = G.LANE_MID
		var tw := create_tween()
		tw.tween_property(self, "position:y", G.LANE_Y[cur_lane] - 10.0, 1.0)
		game.flash_message("SUPER X DESCENDS!")
		AudioManager.play_sfx("explosion", 0.0, 0.6)
	elif phase == 2 and hp <= max_hp * 0.35:
		phase = 3
		_speed_mult = 1.6
		countdown = 40.0 if not GameState.mercy_active(GameState.current_level) else 60.0
		game.flash_message("SELF-DESTRUCT! HURRY!")
		game.shake(8.0)

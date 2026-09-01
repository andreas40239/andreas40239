extends Node2D
## Level orchestrator: parallax, segments (march/arena/boss), combat
## resolution, FX, checkpoints, overlays. (GDD 2, 7)

var level_id := 1
var level_def: Dictionary
var segment_i := 0
var seg_state := "march"      # march | arena | boss | done
var march_dist := 0.0
var spawn_timer := 0.0
var wave_i := 0
var wave_pending := []        # queued spawns for current wave
var wave_spawn_t := 0.0
var frozen := false

var player: Player
var enemies: Array = []
var boss: Boss = null
var parallax: ParallaxBackground
var hud: Hud
var controls: TouchControls
var world: Node2D
var shake_amt := 0.0
var overlay: CanvasLayer = null

func _ready() -> void:
	level_id = GameState.current_level
	level_def = G.LEVELS[level_id]
	_build_background(level_def["theme"])
	world = Node2D.new()
	add_child(world)
	player = Player.new()
	player.game = self
	world.add_child(player)
	player.died.connect(_on_player_died)
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	hud = Hud.new()
	hud.player = player
	ui_layer.add_child(hud)
	controls = TouchControls.new()
	controls.player = player
	ui_layer.add_child(controls)
	var pause_btn := Ui.button("II", _open_pause, 8)
	pause_btn.position = Vector2(4, 26)
	ui_layer.add_child(pause_btn)
	AudioManager.play_music("march")
	AudioManager.play_sfx("gz_roar", -4.0)
	hud.flash_message(level_def["name"], 2.0)
	_start_segment(0)

# ---------------- background ----------------
func _build_background(theme: String) -> void:
	parallax = ParallaxBackground.new()
	add_child(parallax)
	_layer("res://assets/sprites/backgrounds/%s_sky.png" % theme, 0.0, Vector2(0, 0), false)
	_layer("res://assets/sprites/backgrounds/%s_far.png" % theme, 0.2, Vector2(0, 105), true)
	_layer("res://assets/sprites/backgrounds/%s_ground.png" % theme, 1.0, Vector2(0, 238), true, Vector2(1, 3.0))
	_layer("res://assets/sprites/backgrounds/%s_near.png" % theme, 0.6, Vector2(0, 158), true)
	# subtle lane tint bands (GDD 2.2 visual coding)
	for i in 3:
		var band := ColorRect.new()
		band.color = G.LANE_TINT[i]
		band.position = Vector2(0, G.LANE_Y[i] - 14)
		band.size = Vector2(800, 20)
		band.z_index = 1
		add_child(band)

func _layer(tex_path: String, speed: float, pos: Vector2, mirror: bool, scale := Vector2.ONE) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(speed, 0)
	var spr := Sprite2D.new()
	spr.texture = load(tex_path)
	spr.centered = false
	spr.position = pos
	spr.scale = scale
	if mirror:
		layer.motion_mirroring = Vector2(spr.texture.get_width() * scale.x, 0)
	layer.add_child(spr)
	parallax.add_child(layer)

# ---------------- segment flow ----------------
func _start_segment(i: int) -> void:
	segment_i = i
	var segs: Array = level_def["segments"]
	if i >= segs.size():
		_victory()
		return
	var seg: Dictionary = segs[i]
	seg_state = seg["type"]
	match seg_state:
		"march":
			march_dist = 0.0
			spawn_timer = 1.2
			AudioManager.play_music("march")
			if i > 0:
				hud.flash_message("MARCH!")
				AudioManager.play_sfx("checkpoint", -4.0)
		"arena":
			wave_i = -1
			hud.flash_message("ARENA - CLEAR THEM ALL!")
			_next_wave()
		"boss":
			hud.flash_message("TYRANNOKING", 2.5)
			AudioManager.play_music("boss")
			boss = Boss.new()
			boss.setup(self)
			world.add_child(boss)
			hud.boss_ratio = 1.0
			boss.hp_changed.connect(func(r): hud.boss_ratio = r)
			boss.boss_died.connect(_on_boss_died)

func _process(delta: float) -> void:
	if shake_amt > 0.0:
		shake_amt = maxf(0.0, shake_amt - 30.0 * delta)
		world.position = Vector2(randf_range(-shake_amt, shake_amt), randf_range(-shake_amt, shake_amt))
	if frozen:
		return
	enemies = enemies.filter(func(e): return is_instance_valid(e) and e.state != "dead")
	match seg_state:
		"march":
			var seg: Dictionary = level_def["segments"][segment_i]
			parallax.scroll_offset -= Vector2(G.SCROLL_SPEED * delta, 0)
			march_dist += G.SCROLL_SPEED * delta
			spawn_timer -= delta
			if spawn_timer <= 0.0 and march_dist < seg["dist"] - 120.0:
				spawn_timer = seg["rate"] + randf_range(-0.5, 0.7)
				var kinds: Array = seg["spawn"]
				spawn_enemy(kinds[randi() % kinds.size()], false)
			if march_dist >= seg["dist"] and enemies.is_empty():
				_start_segment(segment_i + 1)
		"arena":
			wave_spawn_t -= delta
			if not wave_pending.is_empty() and wave_spawn_t <= 0.0:
				wave_spawn_t = 0.45
				var entry: Array = wave_pending.pop_front()
				spawn_enemy(entry[0], entry[1])
			elif wave_pending.is_empty() and enemies.is_empty():
				_next_wave()

func _next_wave() -> void:
	var seg: Dictionary = level_def["segments"][segment_i]
	wave_i += 1
	var waves: Array = seg["waves"]
	if wave_i >= waves.size():
		AudioManager.play_sfx("checkpoint")
		_start_segment(segment_i + 1)
		return
	if wave_i > 0:
		hud.flash_message("WAVE %d" % (wave_i + 1))
	wave_pending = waves[wave_i].duplicate()
	wave_spawn_t = 0.6

func spawn_enemy(kind: String, from_left: bool) -> Enemy:
	var e := Enemy.new()
	world.add_child(e)
	e.setup(kind, self, from_left)
	enemies.append(e)
	return e

# ---------------- combat resolution ----------------
func melee_hit(lanes: Array, x_min: float, x_max: float, dmg: float, opts := {}) -> int:
	var count := 0
	var exclude = opts.get("exclude", null)
	for e in enemies:
		if not is_instance_valid(e) or e == exclude or e.state in ["dead", "grabbed", "thrown"]:
			continue
		var in_lane := false
		for l in lanes:
			if e.occupies(l):
				in_lane = true
				break
		if in_lane and e.position.x >= x_min and e.position.x <= x_max:
			e.take_hit(dmg, opts)
			count += 1
	if boss != null and is_instance_valid(boss) and boss.state != "dead":
		var bl := false
		for l in lanes:
			if boss.occupies(l):
				bl = true
				break
		if bl and boss.position.x - 40.0 >= x_min - 60.0 and boss.position.x <= x_max + 40.0:
			boss.take_hit(dmg, opts)
			count += 1
	if count > 0:
		add_score(10 * count)
	return count

func find_grabbable(lane: int, x: float, range_px: float):
	for e in enemies:
		if is_instance_valid(e) and e.grabbable() and e.occupies(lane) and absf(e.position.x - x) < range_px:
			return e
	return null

func add_score(points: int) -> void:
	hud.score += points

func flash_message(text: String) -> void:
	hud.flash_message(text)

func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)

# ---------------- FX ----------------
func _one_shot(tex: String, pos: Vector2, hframes: int, fps: float, sc := 4.0) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/fx/%s.png" % tex)
	s.hframes = hframes
	s.scale = Vector2(sc, sc)
	s.position = pos
	s.z_index = 20
	world.add_child(s)
	var timer := 0.0
	s.set_process(true)
	var frames := hframes
	var tw := create_tween()
	for f in frames:
		tw.tween_callback(func(): s.frame = mini(f, frames - 1)).set_delay(0.0 if f == 0 else 1.0 / fps)
	tw.tween_interval(1.0 / fps)
	tw.tween_callback(s.queue_free)

func spawn_explosion(pos: Vector2) -> void:
	_one_shot("explosion", pos, 3, 12.0)
	AudioManager.play_sfx("explosion", -8.0, randf_range(0.9, 1.2))

func spawn_dust(pos: Vector2) -> void:
	_one_shot("dust", pos + Vector2(0, -10), 2, 10.0)

func spawn_shockwave(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/fx/shockwave.png")
	s.position = pos + Vector2(0, -8)
	s.z_index = 20
	s.scale = Vector2(2, 2)
	world.add_child(s)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2(9, 4), 0.3)
	tw.tween_property(s, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(s.queue_free)

func spawn_pulse(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/fx/fireball.png")
	s.position = pos + Vector2(0, -70)
	s.z_index = 20
	s.modulate = G.COL_FIN
	world.add_child(s)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2(26, 26), 0.35)
	tw.tween_property(s, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(s.queue_free)

func spawn_beam(pos: Vector2, lane: int) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/fx/beam.png")
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, 96, 8)
	s.centered = false
	s.position = pos - Vector2(0, 16)
	s.scale = Vector2(4, 4)
	s.z_index = 25
	world.add_child(s)
	var tw := create_tween()
	tw.tween_interval(0.22)
	tw.tween_property(s, "modulate:a", 0.0, 0.15)
	tw.tween_callback(s.queue_free)

# ---------------- death / victory / pause ----------------
func _on_player_died() -> void:
	frozen = true
	GameState.add_death(level_id)
	AudioManager.play_music("gameover", false)
	var items: Array = [Ui.label("GODZILLA HAS FALLEN", 12, Color("ef4444"))]
	if GameState.mercy_active(level_id):
		items.append(Ui.label("MERCY MODE ACTIVE:\nENEMIES -30% DAMAGE", 7, Color("fbbf24")))
	items.append(Ui.label("CONTINUE FROM CHECKPOINT?", 8))
	items.append(Ui.button("CONTINUE", _respawn))
	items.append(Ui.button("GIVE UP", func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), 10, Color("6b7280")))
	overlay = Ui.center_overlay(self, items)

func _respawn() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
		boss = null
		hud.boss_ratio = -1.0
	player.hp = player.max_hp
	player.meter = player.max_meter * 0.4
	player.state = "idle"
	player.stun_t = 0.0
	player.grabbed_enemy = null
	player.airborne = false
	player.lane = G.LANE_GROUND
	player.position = Vector2(96, G.LANE_Y[player.lane])
	frozen = false
	AudioManager.play_sfx("checkpoint")
	_start_segment(segment_i)

func _on_boss_died() -> void:
	hud.boss_ratio = -1.0
	boss = null
	await get_tree().create_timer(1.4).timeout
	_victory()

func _victory() -> void:
	if frozen:
		return
	frozen = true
	seg_state = "done"
	GameState.complete_level(level_id, hud.score)
	AudioManager.play_music("victory", false)
	AudioManager.play_sfx("gz_roar")
	var items: Array = [
		Ui.label("LEVEL COMPLETE!", 13, Color("2dd4bf")),
		Ui.label("SCORE  %06d" % hud.score, 9),
	]
	if GameState.last_ep_gain > 0:
		items.append(Ui.label("+%d EVOLUTION POINT%s" % [GameState.last_ep_gain, "S" if GameState.last_ep_gain > 1 else ""], 9, Color("fbbf24")))
	items.append(Ui.button("EVOLVE (UPGRADES)", func(): get_tree().change_scene_to_file("res://scenes/upgrade_screen.tscn"), 9, Color("a855f7")))
	if level_id < 3:
		items.append(Ui.button("NEXT LEVEL", func():
			GameState.current_level = level_id + 1
			get_tree().change_scene_to_file("res://scenes/story_card.tscn")))
	else:
		items.append(Ui.label("YOU ARE THE KING\nOF THE MONSTERS", 9, Color("fbbf24")))
	items.append(Ui.button("MAIN MENU", func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), 9, Color("6b7280")))
	overlay = Ui.center_overlay(self, items)
	if GameState.last_ep_gain > 0:
		AudioManager.play_sfx("ep_gain")

func _open_pause() -> void:
	if get_tree().paused or frozen:
		return
	get_tree().paused = true
	var pl := Ui.center_overlay(self, [
		Ui.label("PAUSED", 13),
		Ui.button("RESUME", func():
			get_tree().paused = false
			overlay.queue_free()
			overlay = null),
		Ui.button("RESTART LEVEL", func():
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/game.tscn"), 9),
		Ui.button("QUIT TO MENU", func():
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), 9, Color("6b7280")),
	])
	overlay = pl

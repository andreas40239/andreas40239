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
var frost := 0.0              # Mechagodzilla absolute-zero screen frost (0..1)

var player: Player
var enemies: Array = []
var boss: BossBase = null
var parallax: ParallaxBackground
var hud: Hud
var controls: TouchControls
var world: Node2D
var fx_root: Node2D           # projectiles + hazards (cleared on respawn)
var frost_rect: ColorRect
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
	fx_root = Node2D.new()
	world.add_child(fx_root)
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	frost_rect = ColorRect.new()
	frost_rect.color = Color(0.7, 0.9, 1.0, 0.0)
	frost_rect.anchor_right = 1.0
	frost_rect.anchor_bottom = 1.0
	frost_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(frost_rect)
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
	hud.flash_message("LEVEL %d\n%s" % [level_id, level_def["name"]], 2.2)
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
			hud.flash_message(level_def.get("boss_name", "BOSS"), 2.5)
			AudioManager.play_music("boss")
			match seg["boss"]:
				"superx":
					var sx := SuperX.new()
					sx.setup(self)
					boss = sx
				"mecha":
					var m := Mecha.new()
					m.setup(self)
					boss = m
				_:
					var t := Boss.new()
					t.setup(self)
					boss = t
			world.add_child(boss)
			hud.boss_ratio = 1.0
			hud.boss_marks = boss.phase_marks
			boss.hp_changed.connect(func(r): hud.boss_ratio = r)
			boss.boss_died.connect(_on_boss_died)

func _process(delta: float) -> void:
	if shake_amt > 0.0:
		shake_amt = maxf(0.0, shake_amt - 30.0 * delta)
		world.position = Vector2(randf_range(-shake_amt, shake_amt), randf_range(-shake_amt, shake_amt))
	frost_rect.color.a = frost * 0.45
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
				spawn_enemy(kinds[randi() % kinds.size()], randf() < 0.15)
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

func spawn_enemy(kind: String, from_left: bool):
	if kind == "trex":  # Level 4 mini-boss
		var t := Boss.new()
		t.setup(self, true)
		world.add_child(t)
		enemies.append(t)
		hud.flash_message("T-REX!")
		return t
	var e := Enemy.new()
	world.add_child(e)
	e.setup(kind, self, from_left)
	enemies.append(e)
	return e

func spawn_projectile(tex: String, lane: int, x: float, vel: Vector2, dmg: float, homing := 0.0) -> Projectile:
	var p := Projectile.new()
	fx_root.add_child(p)
	p.setup(self, tex, lane, x, vel, dmg, homing)
	return p

func spawn_hazard(lanes: Array, x0: float, x1: float, warn: float, active: float, dmg: float, color: Color, hits_air := false) -> Hazard:
	var h := Hazard.new()
	h.game = self
	h.lanes = lanes
	h.x0 = x0
	h.x1 = x1
	h.warn = warn
	h.active = active
	h.dmg = dmg
	h.color = color
	h.hits_air = hits_air
	fx_root.add_child(h)
	return h

## Everything the player (or a reflected missile) can damage.
func all_targets() -> Array:
	var out: Array = []
	for e in enemies:
		if is_instance_valid(e) and not (e.state in ["dead", "grabbed", "thrown"]):
			out.append(e)
	if boss != null and is_instance_valid(boss) and boss.state != "dead":
		out.append(boss)
	return out

func clear_projectiles_near(x: float, radius: float) -> void:
	for p in fx_root.get_children():
		if p is Projectile and not p.friendly and absf(p.position.x - x) < radius:
			p._explode()

# ---------------- combat resolution ----------------
func melee_hit(lanes: Array, x_min: float, x_max: float, dmg: float, opts := {}) -> int:
	var count := 0
	var exclude = opts.get("exclude", null)
	for e in all_targets():
		if e == exclude:
			continue
		var in_lane := false
		for l in lanes:
			if e.occupies(l):
				in_lane = true
				break
		var span: Vector2 = e.hit_span()
		if in_lane and span.y >= x_min and span.x <= x_max:
			e.take_hit(dmg, opts)
			count += 1
	# tail whips swat enemy missiles back (GDD 5.2)
	if exclude == null and not opts.get("breath", false):
		for p in fx_root.get_children():
			if p is Projectile and not p.friendly and p.swattable and p.lane in lanes \
					and p.position.x >= x_min - 10.0 and p.position.x <= x_max + 10.0:
				p.reflect(player.facing)
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
	var tw := create_tween()
	for f in hframes:
		tw.tween_callback(func(): s.frame = f).set_delay(0.0 if f == 0 else 1.0 / fps)
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

func spawn_beam(pos: Vector2, dir: float) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/fx/beam.png")
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, 96, 8)
	s.centered = false
	s.position = pos - Vector2(0, 16)
	s.scale = Vector2(4 * dir, 4)
	s.z_index = 25
	world.add_child(s)
	var tw := create_tween()
	tw.tween_interval(0.22)
	tw.tween_property(s, "modulate:a", 0.0, 0.15)
	tw.tween_callback(s.queue_free)

# ---------------- death / victory / pause ----------------
func _on_player_died() -> void:
	frozen = true
	frost = 0.0
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
	for c in fx_root.get_children():
		c.queue_free()
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	hud.boss_ratio = -1.0
	hud.timer_text = ""
	frost = 0.0
	player.reset_for_respawn()
	frozen = false
	AudioManager.play_sfx("checkpoint")
	_start_segment(segment_i)

func _on_boss_died() -> void:
	hud.boss_ratio = -1.0
	hud.timer_text = ""
	boss = null
	await get_tree().create_timer(1.4).timeout
	_victory()

func _victory() -> void:
	if frozen:
		return
	frozen = true
	seg_state = "done"
	for c in fx_root.get_children():
		c.queue_free()
	GameState.complete_level(level_id, hud.score)
	AudioManager.play_music("victory", false)
	AudioManager.play_sfx("gz_roar")
	var items: Array = [
		Ui.label("LEVEL COMPLETE!", 13, Color("2dd4bf")),
		Ui.label("SCORE  %06d" % hud.score, 9),
		Ui.gem_row(GameState.last_ep_gain, "+"),
	]
	items.append(Ui.icon_button("icon_plus", "POWER UP!", func(): get_tree().change_scene_to_file("res://scenes/upgrade_screen.tscn"), Color("a855f7")))
	if level_id < GameState.MAX_LEVEL:
		items.append(Ui.button("NEXT LEVEL", func():
			GameState.current_level = level_id + 1
			get_tree().change_scene_to_file("res://scenes/story_card.tscn")))
	else:
		items.append(Ui.label("YOU ARE THE KING\nOF THE MONSTERS!", 10, Color("fbbf24")))
	items.append(Ui.button("MAIN MENU", func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), 9, Color("6b7280")))
	overlay = Ui.center_overlay(self, items)
	AudioManager.play_sfx("ep_gain")

func _open_pause() -> void:
	if get_tree().paused or frozen:
		return
	get_tree().paused = true
	overlay = Ui.center_overlay(self, [
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

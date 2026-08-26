# The battle scene: world, HUD, turn loop, combat resolution, shop & panels.
class_name Battle
extends Node2D

signal exit_to_menu
signal play_level(level: int)

enum S { SETUP, PASS, AIM, CONFIRM, FLIGHT, RESOLVE, ENDED }

var humans := 1
var level := 1

var state: int = S.SETUP
var terrain: Terrain
var cam: BattleCam
var tanks: Array = []
var current_i := 0
var turn_count := 0
var wind := 0.0
var pending_shots := 0
var hold_time := 0.0
var fire_held := false
var timer_left := 30.0
var aim_touch := -1
var _preview_pts := PackedVector2Array()
var _arc_pts := PackedVector2Array()
var _arc_visible := false

# HUD nodes
var hud: CanvasLayer
var banner_label: Label
var banner_panel: PanelContainer
var angle_slider: HSlider
var power_slider: VSlider
var angle_label: Label
var power_label: Label
var fire_btn: Button
var fire_ring: Control
var confirm_bar: HBoxContainer
var arc_btn: Button
var aim_box: Control
var cloud: WindCloud
var hint_label: Label
var timer_label: Label
var big_banner: Label
var overlay_holder: Control
var preview_node: Node2D

const AI_NAMES := ["Beep", "Zippy", "Rusty"]

# ------------------------------------------------------------------ setup

func _ready() -> void:
	G.match_humans = humans
	G.match_level = level
	_build_world()
	_build_hud()
	_start_level()

func _build_world() -> void:
	# Sky.
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	var sky := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.45, 0.75, 0.98))
	grad.set_color(1, Color(0.72, 0.90, 1.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	sky.texture = gt
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_layer.add_child(sky)
	add_child(sky_layer)
	# Parallax mountains and clouds.
	var pbg := ParallaxBackground.new()
	add_child(pbg)
	var lay1 := ParallaxLayer.new()
	lay1.motion_scale = Vector2(0.25, 0.25)
	lay1.motion_mirroring = Vector2(2400, 0)
	lay1.add_child(Scenery.new(0))
	pbg.add_child(lay1)
	var lay2 := ParallaxLayer.new()
	lay2.motion_scale = Vector2(0.5, 0.5)
	lay2.motion_mirroring = Vector2(2400, 0)
	lay2.add_child(Scenery.new(1))
	pbg.add_child(lay2)
	# Terrain.
	terrain = Terrain.new()
	add_child(terrain)
	# Preview dots layer.
	preview_node = PreviewLine.new(self)
	add_child(preview_node)
	# Camera.
	cam = BattleCam.new()
	cam.world_w = Terrain.WORLD_W
	add_child(cam)

func _start_level() -> void:
	terrain.generate(level, randi())
	wind = G.roll_wind(level)
	for t in tanks:
		t.queue_free()
	tanks.clear()
	var spawns: Array = terrain.spawn_points.duplicate()
	spawns.shuffle()
	var ai_i := 0
	for i in range(4):
		var t := Tank.new()
		var sp: Vector2 = spawns[i]
		t.position = Vector2(sp.x, sp.y - 4.0)
		var is_h := i < humans
		var nm := "Player %d" % (i + 1)
		if not is_h:
			nm = AI_NAMES[ai_i % AI_NAMES.size()]
			t.ai_tier = G.ai_tier(level, ai_i)
			t.personality = randi_range(0, 3)
			ai_i += 1
		add_child(t)
		t.setup(i, i, is_h, nm)
		t.shield_active = G.has_cover(i, is_h)
		tanks.append(t)
	current_i = -1
	turn_count = 0
	cloud.set_wind(eff_wind())
	_show_big_banner("Level %d" % level)
	cam.position = Vector2(Terrain.WORLD_W * 0.5, 300)
	cam.zoom = Vector2.ONE * BattleCam.MIN_ZOOM
	state = S.SETUP
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(_next_turn)

func eff_wind() -> float:
	return 0.0 if G.settings["wind_off"] else wind

func alive_tanks() -> Array:
	return tanks.filter(func(t): return t.alive)

func current_tank() -> Tank:
	return tanks[current_i]

# ------------------------------------------------------------------ turns

func _next_turn() -> void:
	if alive_tanks().size() <= 1:
		_end_level()
		return
	# Advance to next living tank.
	for k in range(1, 5):
		var i := (current_i + k) % 4
		if tanks[i].alive:
			current_i = i
			break
	turn_count += 1
	# Wind change every 8 turns after level 20 (GDD 10.4).
	if G.wind_changes_mid_level(level) and turn_count > 1 and (turn_count - 1) % 8 == 0 \
			and not G.settings["wind_off"]:
		wind = float(randi_range(-30, 30))
		cloud.announce_change(eff_wind())
		_show_big_banner("The wind has changed!")
	cloud.set_wind(eff_wind())
	for t in tanks:
		t.set_my_turn(t == current_tank() and t.alive)
	var tk := current_tank()
	_update_banner()
	cam.fly_to(tk.position + Vector2(0, -60), 1.15, 0.8)
	timer_left = 30.0
	if tk.is_human:
		if humans > 1:
			state = S.PASS
			_show_pass_panel()
		else:
			_begin_aim()
	else:
		_begin_ai_turn()

func _begin_aim() -> void:
	state = S.AIM
	var tk := current_tank()
	aim_box.visible = true
	confirm_bar.visible = false
	fire_btn.visible = true
	_arc_visible = false
	angle_slider.set_value_no_signal(tk.angle)
	power_slider.set_value_no_signal(tk.power)
	_refresh_readouts()
	_update_preview()
	_set_hint()

func _begin_ai_turn() -> void:
	state = S.FLIGHT  # controls hidden while AI thinks
	aim_box.visible = false
	confirm_bar.visible = false
	fire_btn.visible = false
	preview_node.queue_redraw()
	var tk := current_tank()
	var shot := AI.choose_shot(tk, tanks, terrain, eff_wind())
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_method(func(v: float) -> void:
		tk.angle = lerpf(tk.angle, shot["angle"], v)
		tk.power = lerpf(tk.power, shot["power"], v),
		0.0, 1.0, 0.7)
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		tk.angle = shot["angle"]
		tk.power = shot["power"]
		_do_fire())

func _hold_to_confirm() -> void:
	state = S.CONFIRM
	A.haptic(40)
	fire_btn.visible = false
	confirm_bar.visible = true
	_arc_visible = false
	arc_btn.text = "Show Path"
	_compute_arc()
	_set_hint()

func _cancel_confirm() -> void:
	state = S.AIM
	confirm_bar.visible = false
	fire_btn.visible = true
	_arc_visible = false
	preview_node.queue_redraw()
	_set_hint()

func _do_fire() -> void:
	var tk := current_tank()
	state = S.FLIGHT
	aim_box.visible = false
	fire_btn.visible = false
	confirm_bar.visible = false
	_arc_visible = false
	hint_label.visible = false
	var n := G.shot_count(tk.seat, tk.is_human)
	pending_shots = 0
	var first: Projectile = null
	for s in range(n):
		var spread := 0.0
		if n > 1:
			spread = lerpf(-5.0, 5.0, float(s) / float(n - 1))
		var p := Projectile.new()
		add_child(p)
		p.launch(tk.barrel_tip(), tk.angle + spread, tk.power, eff_wind(), terrain, tanks, tk)
		p.impact.connect(_on_impact.bind(tk))
		pending_shots += 1
		if first == null:
			first = p
	# Muzzle flash + sounds. Deeper boom at higher power (GDD 14).
	_spawn_flash(tk.barrel_tip(), 14.0, Color(1.0, 0.9, 0.5))
	A.play("fire", 1.25 - tk.power / 100.0 * 0.45)
	A.play("whiz", randf_range(0.9, 1.1))
	A.haptic(50)
	cam.zoom_out_for_flight(tk.position)
	if first:
		var tw := create_tween()
		tw.tween_interval(0.5)
		tw.tween_callback(func() -> void:
			if is_instance_valid(first) and not first.done:
				cam.begin_follow(first))

func _on_impact(pos: Vector2, direct_tank, lost: bool, shooter: Tank) -> void:
	pending_shots -= 1
	cam.end_follow()
	if not lost:
		_resolve_explosion(pos, direct_tank, shooter)
	if pending_shots <= 0:
		state = S.RESOLVE
		var tw := create_tween()
		tw.tween_interval(1.0)  # linger on the explosion (GDD 7)
		tw.tween_callback(_next_turn)

# ------------------------------------------------------------------ combat

func _resolve_explosion(pos: Vector2, direct_tank, shooter: Tank) -> void:
	var radius := G.blast_radius(shooter.seat, shooter.is_human)
	var base_dmg := G.base_damage(shooter.seat, shooter.is_human)
	_spawn_explosion(pos, radius)
	A.play("explosion", clampf(1.15 - radius / 200.0, 0.6, 1.1))
	A.haptic(60)
	cam.shake(minf(4.0 + radius * 0.06, 10.0))
	for tk in alive_tanks():
		var d: float = tk.center().distance_to(pos)
		var is_direct: bool = (tk == direct_tank)
		if is_direct:
			d = 0.0
		if d >= radius:
			continue
		if is_direct and tk.shield_active:
			tk.shield_active = false
			tk.shield_cracked = true
			A.play("shield")
			_spawn_popup(tk.position + Vector2(0, -70), "Blocked!", Color(0.5, 0.9, 1.0))
			continue
		var dmg := floorf(base_dmg * (1.0 - d / radius))
		if dmg <= 0.0:
			continue
		tk.hp = maxf(0.0, tk.hp - dmg)
		tk.hurt_flash()
		if tk != shooter:
			shooter.damage_dealt += dmg
		A.play("hit_direct" if is_direct else "hit_splash")
		_spawn_popup(tk.position + Vector2(0, -70), "-%d" % int(dmg),
				Color(1.0, 0.35, 0.3) if is_direct else Color(1.0, 0.7, 0.3))
		if tk.hp <= 0.0:
			_kill_tank(tk)

func _kill_tank(tk: Tank) -> void:
	tk.alive = false
	tk.set_my_turn(false)
	tk.queue_redraw()
	_spawn_explosion(tk.center(), 60.0)
	_spawn_popup(tk.position + Vector2(0, -90), "%s is out!" % tk.display_name, Color.WHITE)
	A.play("explosion", 0.8)

# ------------------------------------------------------------------ effects

func _spawn_explosion(pos: Vector2, radius: float) -> void:
	_spawn_flash(pos, radius, Color(1.0, 0.75, 0.3))
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = 40
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = radius * 2.0
	p.initial_velocity_max = radius * 4.5
	p.gravity = Vector2(0, 500)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.5
	p.color = Color(0.65, 0.45, 0.3)
	add_child(p)
	var p2 := CPUParticles2D.new()
	p2.position = pos
	p2.one_shot = true
	p2.emitting = true
	p2.amount = 22
	p2.lifetime = 0.5
	p2.explosiveness = 1.0
	p2.spread = 180.0
	p2.initial_velocity_min = radius * 1.2
	p2.initial_velocity_max = radius * 2.6
	p2.gravity = Vector2(0, 120)
	p2.scale_amount_min = 3.0
	p2.scale_amount_max = 7.0
	p2.color = Color(1.0, 0.7, 0.25)
	add_child(p2)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(func() -> void:
		p.queue_free()
		p2.queue_free())

func _spawn_flash(pos: Vector2, radius: float, col: Color) -> void:
	var f := Flash.new()
	f.position = pos
	f.radius = radius
	f.col = col
	add_child(f)

func _spawn_popup(pos: Vector2, text: String, col: Color) -> void:
	var pp := Popup2D.new()
	pp.position = pos
	pp.text = text
	pp.col = col
	add_child(pp)

# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	# Player banner (top-left).
	banner_panel = UIKit.panel(Color(1, 1, 1, 0.9), 18)
	banner_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	banner_panel.position = Vector2(16, 12)
	banner_label = UIKit.label("Player 1", 30)
	banner_panel.add_child(banner_label)
	root.add_child(banner_panel)

	timer_label = UIKit.label("", 30, Color.WHITE)
	timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	timer_label.add_theme_constant_override("outline_size", 8)
	timer_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	timer_label.position = Vector2(24, 78)
	root.add_child(timer_label)

	# Wind cloud (top-center).
	cloud = WindCloud.new()
	cloud.custom_minimum_size = Vector2(340, 120)
	cloud.set_anchors_preset(Control.PRESET_CENTER_TOP)
	cloud.anchor_left = 0.5
	cloud.anchor_right = 0.5
	cloud.offset_left = -170
	cloud.offset_right = 170
	cloud.offset_top = 0
	cloud.offset_bottom = 120
	cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cloud)

	# Pause button (top-right).
	var pause_btn := UIKit.button("| |", Color(0.45, 0.5, 0.6), 26, Vector2(72, 72))
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.position = Vector2(-88, 12)
	pause_btn.pressed.connect(_show_pause_panel)
	root.add_child(pause_btn)

	# Aim controls.
	aim_box = Control.new()
	aim_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	aim_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(aim_box)

	angle_label = UIKit.label("45°", 40, Color.WHITE)
	angle_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	angle_label.add_theme_constant_override("outline_size", 10)
	angle_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	angle_label.position = Vector2(40, -240)
	aim_box.add_child(angle_label)

	angle_slider = UIKit.hslider(0, 180, 60, 430)
	angle_slider.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	angle_slider.position = Vector2(30, -186)
	angle_slider.value_changed.connect(_on_angle_changed)
	aim_box.add_child(angle_slider)

	power_label = UIKit.label("55%", 40, Color.WHITE)
	power_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	power_label.add_theme_constant_override("outline_size", 10)
	power_label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	power_label.position = Vector2(-104, -240)
	aim_box.add_child(power_label)

	power_slider = UIKit.vslider(0, 100, 55, 330)
	power_slider.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	power_slider.position = Vector2(-102, -180)
	power_slider.value_changed.connect(_on_power_changed)
	aim_box.add_child(power_slider)

	# Reset aim + snap camera.
	var reset_btn := UIKit.button("Reset", Color(0.55, 0.6, 0.7), 22, Vector2(110, 64))
	reset_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	reset_btn.position = Vector2(30, -96)
	reset_btn.pressed.connect(func() -> void:
		var tk := current_tank()
		angle_slider.value = 60.0 if tk.position.x < Terrain.WORLD_W / 2.0 else 120.0
		power_slider.value = 55.0)
	aim_box.add_child(reset_btn)

	var snap_btn := UIKit.button("Find me", Color(0.55, 0.6, 0.7), 22, Vector2(140, 64))
	snap_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	snap_btn.position = Vector2(152, -96)
	snap_btn.pressed.connect(func() -> void:
		cam.fly_to(current_tank().position + Vector2(0, -60), 1.15, 0.5))
	aim_box.add_child(snap_btn)

	# Fire button.
	fire_btn = UIKit.button("FIRE!", Color(0.9, 0.25, 0.2), 36, Vector2(170, 120))
	fire_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fire_btn.position = Vector2(-200, -150)
	fire_btn.button_down.connect(func() -> void:
		if state == S.AIM:
			fire_held = true
			hold_time = 0.0)
	fire_btn.button_up.connect(func() -> void:
		fire_held = false
		hold_time = 0.0
		fire_ring.queue_redraw())
	root.add_child(fire_btn)
	fire_ring = FireRing.new(self)
	fire_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	fire_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire_btn.add_child(fire_ring)

	# Confirm bar (after hold): Back / Show Path / GO!
	confirm_bar = HBoxContainer.new()
	confirm_bar.add_theme_constant_override("separation", 20)
	confirm_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	confirm_bar.anchor_left = 0.5
	confirm_bar.anchor_right = 0.5
	confirm_bar.offset_top = -160
	confirm_bar.offset_bottom = -40
	confirm_bar.offset_left = -330
	confirm_bar.offset_right = 330
	confirm_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	var back_btn := UIKit.button("Back", Color(0.55, 0.6, 0.7), 30, Vector2(150, 96))
	back_btn.pressed.connect(_cancel_confirm)
	confirm_bar.add_child(back_btn)
	arc_btn = UIKit.button("Show Path", Color(0.55, 0.4, 0.85), 30, Vector2(230, 96))
	arc_btn.pressed.connect(func() -> void:
		_arc_visible = not _arc_visible
		arc_btn.text = "Hide Path" if _arc_visible else "Show Path"
		if _arc_visible:
			_compute_arc()
		preview_node.queue_redraw())
	confirm_bar.add_child(arc_btn)
	var go_btn := UIKit.button("GO!", Color(0.3, 0.75, 0.35), 40, Vector2(190, 96))
	go_btn.pressed.connect(func() -> void:
		if state == S.CONFIRM:
			_do_fire())
	confirm_bar.add_child(go_btn)
	confirm_bar.visible = false
	root.add_child(confirm_bar)

	# Hint label for young players.
	hint_label = UIKit.label("", 26, Color.WHITE)
	hint_label.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.35, 0.8))
	hint_label.add_theme_constant_override("outline_size", 8)
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.anchor_left = 0.5
	hint_label.anchor_right = 0.5
	hint_label.offset_left = -400
	hint_label.offset_right = 400
	hint_label.offset_top = -230
	hint_label.offset_bottom = -190
	root.add_child(hint_label)

	# Big center banner.
	big_banner = UIKit.title_label("", 60)
	big_banner.set_anchors_preset(Control.PRESET_CENTER)
	big_banner.anchor_left = 0.5
	big_banner.anchor_right = 0.5
	big_banner.anchor_top = 0.35
	big_banner.anchor_bottom = 0.35
	big_banner.offset_left = -500
	big_banner.offset_right = 500
	big_banner.offset_top = -60
	big_banner.offset_bottom = 60
	big_banner.visible = false
	root.add_child(big_banner)

	# Overlay panels holder.
	overlay_holder = Control.new()
	overlay_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay_holder)

	aim_box.visible = false
	fire_btn.visible = false

func _update_banner() -> void:
	var tk := current_tank()
	banner_label.text = "%s  —  your turn!" % tk.display_name if tk.is_human else "%s is aiming..." % tk.display_name
	banner_panel.add_theme_stylebox_override("panel", UIKit.style(tk.color.lightened(0.35), 18))

func _refresh_readouts() -> void:
	angle_label.text = "%d°" % int(current_tank().angle)
	power_label.text = "%d%%" % int(current_tank().power)
	var pf: float = current_tank().power / 100.0
	var col := Color(0.35, 0.75, 0.35).lerp(Color(0.9, 0.3, 0.2), pf)
	power_slider.add_theme_stylebox_override("grabber_area", UIKit.style(col, 12, Color(0, 0, 0, 0), 0))
	power_slider.add_theme_stylebox_override("grabber_area_highlight", UIKit.style(col, 12, Color(0, 0, 0, 0), 0))

func _on_angle_changed(v: float) -> void:
	if state == S.AIM and current_tank().is_human:
		current_tank().angle = v
		_refresh_readouts()
		_update_preview()

func _on_power_changed(v: float) -> void:
	if state == S.AIM and current_tank().is_human:
		current_tank().power = v
		_refresh_readouts()
		_update_preview()

func _update_preview() -> void:
	var tk := current_tank()
	var res := Sim.trace(tk.barrel_tip(), tk.angle, tk.power, eff_wind(),
			terrain, tanks, tk, 1.0 / 30.0, 1.1)  # short, approximate preview
	_preview_pts = res["points"]
	preview_node.queue_redraw()

func _compute_arc() -> void:
	var tk := current_tank()
	var res := Sim.trace(tk.barrel_tip(), tk.angle, tk.power, eff_wind(),
			terrain, tanks, tk, 1.0 / 60.0, 10.0)  # exact full path
	_arc_pts = res["points"]
	preview_node.queue_redraw()

func _set_hint() -> void:
	hint_label.visible = level <= 3 and current_tank().is_human
	if not hint_label.visible:
		return
	match state:
		S.AIM:
			hint_label.text = "Move the sliders to aim, then hold FIRE!"
		S.CONFIRM:
			hint_label.text = "Tap Show Path to peek, then tap GO!"
		_:
			hint_label.visible = false

func _show_big_banner(text: String) -> void:
	big_banner.text = text
	big_banner.visible = true
	big_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(big_banner, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: big_banner.visible = false)

# ------------------------------------------------------------------ input

func _process(delta: float) -> void:
	if fire_held and state == S.AIM:
		hold_time += delta
		fire_ring.queue_redraw()
		if hold_time >= 0.5:
			fire_held = false
			_hold_to_confirm()
	if state == S.AIM and current_tank().is_human and G.settings["timer_on"]:
		timer_left -= delta
		timer_label.text = "Time: %d" % maxi(0, int(ceil(timer_left)))
		if timer_left <= 0.0:
			timer_label.text = ""
			_do_fire()
	else:
		timer_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if state == S.AIM and current_tank().is_human:
		if event is InputEventScreenTouch and event.pressed:
			var wp := _screen_to_world(event.position)
			if wp.distance_to(current_tank().center()) < 170.0:
				aim_touch = event.index
				return
		elif event is InputEventScreenTouch and not event.pressed:
			if event.index == aim_touch:
				aim_touch = -1
				return
		elif event is InputEventScreenDrag and event.index == aim_touch:
			# Drag the barrel directly: aim toward the finger (GDD 4).
			var wp := _screen_to_world(event.position)
			var v := wp - current_tank().center()
			if v.length() > 8.0:
				var ang := rad_to_deg(atan2(-v.y, v.x))
				angle_slider.value = clampf(ang, 0.0, 180.0)
			return
	cam.handle_touch(event)

func _screen_to_world(p: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * p

# ------------------------------------------------------------------ panels

func _dim_panel() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.15, 0.25, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_holder.add_child(dim)
	return dim

func _center_box(dim: Control, width := 640.0) -> VBoxContainer:
	var p := UIKit.panel()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(width, 0)
	dim.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	p.add_child(box)
	return box

func _show_pass_panel() -> void:
	var tk := current_tank()
	var dim := _dim_panel()
	var box := _center_box(dim)
	box.add_child(UIKit.label("Pass the phone to", 30))
	var nm := UIKit.label(tk.display_name, 52, tk.color)
	box.add_child(nm)
	box.add_child(UIKit.vspace())
	var ready := UIKit.button("I'm ready!", UIKit.COL_GOOD, 36, Vector2(300, 90))
	ready.pressed.connect(func() -> void:
		dim.queue_free()
		_begin_aim())
	box.add_child(ready)

func _toggle_row(box: VBoxContainer, text: String, value: bool, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l := UIKit.label(text, 28)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(l)
	var b := UIKit.button("ON" if value else "OFF",
			UIKit.COL_GOOD if value else Color(0.6, 0.6, 0.65), 26, Vector2(120, 64))
	b.pressed.connect(func() -> void:
		var nv: bool = on_change.call()
		b.text = "ON" if nv else "OFF"
		b.add_theme_stylebox_override("normal",
				UIKit.style(UIKit.COL_GOOD if nv else Color(0.6, 0.6, 0.65)))
		G.save_game())
	row.add_child(b)
	box.add_child(row)

func _slider_row(box: VBoxContainer, text: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UIKit.label(text, 26)
	l.custom_minimum_size = Vector2(130, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(l)
	var s := UIKit.hslider(0.0, 1.0, G.settings[key], 330)
	s.step = 0.05
	s.value_changed.connect(func(v: float) -> void:
		G.settings[key] = v
		A.refresh_music_volume()
		G.save_game())
	row.add_child(s)
	box.add_child(row)

func _show_pause_panel() -> void:
	if state == S.ENDED:
		return
	get_tree().paused = true
	var dim := _dim_panel()
	dim.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var box := _center_box(dim, 700.0)
	box.add_child(UIKit.label("Paused", 44))
	_slider_row(box, "Sounds", "sfx")
	_slider_row(box, "Music", "music")
	_toggle_row(box, "Wind", not G.settings["wind_off"], func() -> bool:
		G.settings["wind_off"] = not G.settings["wind_off"]
		cloud.set_wind(eff_wind())
		if state == S.AIM:
			_update_preview()
		return not G.settings["wind_off"])
	_toggle_row(box, "Turn timer (30s)", G.settings["timer_on"], func() -> bool:
		G.settings["timer_on"] = not G.settings["timer_on"]
		timer_left = 30.0
		return G.settings["timer_on"])
	_toggle_row(box, "Vibration", G.settings["haptics"], func() -> bool:
		G.settings["haptics"] = not G.settings["haptics"]
		return G.settings["haptics"])
	_toggle_row(box, "Screen shake", G.settings["shake"], func() -> bool:
		G.settings["shake"] = not G.settings["shake"]
		return G.settings["shake"])
	box.add_child(UIKit.vspace())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var resume := UIKit.button("Keep playing", UIKit.COL_GOOD, 28, Vector2(240, 80))
	resume.pressed.connect(func() -> void:
		get_tree().paused = false
		dim.queue_free())
	row.add_child(resume)
	var restart := UIKit.button("Restart", Color(0.9, 0.6, 0.2), 28, Vector2(180, 80))
	restart.pressed.connect(func() -> void:
		get_tree().paused = false
		G.save_game()
		play_level.emit(level))
	row.add_child(restart)
	var quit := UIKit.button("Menu", Color(0.6, 0.6, 0.65), 28, Vector2(150, 80))
	quit.pressed.connect(func() -> void:
		get_tree().paused = false
		G.save_game()
		exit_to_menu.emit())
	row.add_child(quit)
	box.add_child(row)

# ------------------------------------------------------------------ end of level

func _end_level() -> void:
	state = S.ENDED
	aim_box.visible = false
	fire_btn.visible = false
	confirm_bar.visible = false
	hint_label.visible = false
	var survivors := alive_tanks()
	var victory := false
	for t in survivors:
		if t.is_human:
			victory = true
	# Rank by damage dealt (GDD 12.1).
	var ranked := tanks.duplicate()
	ranked.sort_custom(func(a, b): return a.damage_dealt > b.damage_dealt)
	var pts := [3, 2, 1, 0]
	if victory:
		for r in range(4):
			var t: Tank = ranked[r]
			if t.is_human:
				G.seat(t.seat)["points"] += pts[r]
		if level >= G.unlocked_level:
			G.unlocked_level = level + 1
	G.save_game()
	A.play("victory" if victory else "defeat")
	var dim := _dim_panel()
	var box := _center_box(dim, 720.0)
	box.add_child(UIKit.label("You did it!" if victory else "Oh no! Try again!", 48,
			UIKit.COL_GOOD if victory else UIKit.COL_WARN))
	box.add_child(UIKit.label("Level %d" % level, 28, Color(0.4, 0.45, 0.55)))
	box.add_child(UIKit.vspace(6))
	for r in range(4):
		var t: Tank = ranked[r]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var medal := UIKit.label(["1st", "2nd", "3rd", "4th"][r], 26, Color(0.5, 0.55, 0.65))
		medal.custom_minimum_size = Vector2(70, 0)
		row.add_child(medal)
		var nm := UIKit.label(t.display_name, 28, t.color.darkened(0.15))
		nm.custom_minimum_size = Vector2(220, 0)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(nm)
		var dmg := UIKit.label("%d dmg" % int(t.damage_dealt), 26)
		dmg.custom_minimum_size = Vector2(140, 0)
		row.add_child(dmg)
		var ptxt := ""
		if victory and t.is_human:
			ptxt = "+%d pts" % pts[r]
		row.add_child(UIKit.label(ptxt, 26, UIKit.COL_PRIMARY))
		box.add_child(row)
	box.add_child(UIKit.vspace())
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	if victory:
		var next := UIKit.button("Next level", UIKit.COL_GOOD, 32, Vector2(260, 88))
		next.pressed.connect(func() -> void:
			dim.queue_free()
			if level % 5 == 0:
				_show_shop(0, level + 1)
			else:
				play_level.emit(level + 1))
		btns.add_child(next)
	else:
		var retry := UIKit.button("Try again!", Color(0.9, 0.6, 0.2), 32, Vector2(240, 88))
		retry.pressed.connect(func() -> void: play_level.emit(level))
		btns.add_child(retry)
	var menu := UIKit.button("Menu", Color(0.6, 0.6, 0.65), 32, Vector2(160, 88))
	menu.pressed.connect(func() -> void: exit_to_menu.emit())
	btns.add_child(menu)
	box.add_child(btns)

# ------------------------------------------------------------------ upgrade shop

func _show_shop(seat_idx: int, next_level: int) -> void:
	if seat_idx >= humans:
		play_level.emit(next_level)
		return
	var dim := _dim_panel()
	var box := _center_box(dim, 780.0)
	box.add_child(UIKit.label("Upgrade Hangar", 44, UIKit.COL_PRIMARY))
	box.add_child(UIKit.label("%s's tank" % ("Player %d" % (seat_idx + 1)), 30,
			UIKit.PLAYER_COLORS[seat_idx]))
	var pts_label := UIKit.label("Points: %d" % int(G.seat(seat_idx)["points"]), 30)
	box.add_child(pts_label)
	box.add_child(UIKit.vspace(4))
	for key in G.UPGRADES.keys():
		var info: Dictionary = G.UPGRADES[key]
		if level + 1 <= int(info["unlock"]) and int(info["unlock"]) > 1:
			continue  # Iron Cover appears only from level 20 on
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var nm := UIKit.label(String(info["name"]), 28)
		nm.custom_minimum_size = Vector2(230, 0)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(nm)
		var desc := UIKit.label(String(info["desc"]), 22, Color(0.45, 0.5, 0.6))
		desc.custom_minimum_size = Vector2(240, 0)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(desc)
		var lvl_label := UIKit.label("%d/%d" % [int(G.seat(seat_idx)[key]), int(info["max"])], 26)
		lvl_label.custom_minimum_size = Vector2(70, 0)
		row.add_child(lvl_label)
		var buy := UIKit.button("%d pts" % int(info["cost"]), UIKit.COL_GOOD, 24, Vector2(130, 66))
		var refresh := func() -> void:
			var owned := int(G.seat(seat_idx)[key])
			var can := int(G.seat(seat_idx)["points"]) >= int(info["cost"]) and owned < int(info["max"])
			buy.disabled = not can
			buy.modulate.a = 1.0 if can else 0.55
			lvl_label.text = "%d/%d" % [owned, int(info["max"])]
			pts_label.text = "Points: %d" % int(G.seat(seat_idx)["points"])
		buy.pressed.connect(func() -> void:
			var s := G.seat(seat_idx)
			if int(s["points"]) >= int(info["cost"]) and int(s[key]) < int(info["max"]):
				s["points"] = int(s["points"]) - int(info["cost"])
				s[key] = int(s[key]) + 1
				G.save_game()
				refresh.call())
		refresh.call()
		row.add_child(buy)
		box.add_child(row)
	box.add_child(UIKit.vspace())
	var done := UIKit.button("Done!", UIKit.COL_PRIMARY, 32, Vector2(220, 84))
	done.pressed.connect(func() -> void:
		dim.queue_free()
		_show_shop(seat_idx + 1, next_level))
	box.add_child(done)

# ------------------------------------------------------------------ inner drawing classes

class PreviewLine extends Node2D:
	var battle
	func _init(b) -> void:
		battle = b
	func _draw() -> void:
		if battle.state == battle.S.AIM and battle.current_i >= 0 \
				and battle.current_tank().is_human:
			var pts: PackedVector2Array = battle._preview_pts
			for i in range(0, pts.size(), 2):
				var a := 1.0 - float(i) / float(maxi(1, pts.size()))
				draw_circle(pts[i], 5.0, Color(1, 1, 1, 0.35 + 0.45 * a))
		if battle.state == battle.S.CONFIRM and battle._arc_visible:
			var pts2: PackedVector2Array = battle._arc_pts
			if pts2.size() >= 2:
				draw_polyline(pts2, Color(1.0, 0.55, 0.9, 0.95), 5.0)
				draw_circle(pts2[pts2.size() - 1], 10.0, Color(1.0, 0.4, 0.4, 0.9))
	func _process(_d: float) -> void:
		queue_redraw()

class FireRing extends Control:
	var battle
	func _init(b) -> void:
		battle = b
	func _draw() -> void:
		if battle.fire_held and battle.hold_time > 0.02:
			var frac: float = clampf(battle.hold_time / 0.5, 0.0, 1.0)
			var c := size / 2.0
			draw_arc(c, minf(size.x, size.y) * 0.62, -PI / 2.0,
					-PI / 2.0 + TAU * frac, 28, Color(1, 1, 1, 0.9), 7.0)

class Flash extends Node2D:
	var radius := 20.0
	var col := Color.WHITE
	var life := 0.0
	func _process(delta: float) -> void:
		life += delta
		if life > 0.25:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var f: float = 1.0 - life / 0.25
		draw_circle(Vector2.ZERO, radius * (0.6 + (1.0 - f) * 1.2), Color(col.r, col.g, col.b, 0.65 * f))

class Popup2D extends Node2D:
	var text := ""
	var col := Color.WHITE
	var life := 0.0
	func _process(delta: float) -> void:
		life += delta
		position.y -= 34.0 * delta
		if life > 1.3:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var a: float = clampf(1.6 - life, 0.0, 1.0)
		var f := ThemeDB.fallback_font
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 30).x
		draw_string_outline(f, Vector2(-w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8,
				Color(0, 0, 0, 0.6 * a))
		draw_string(f, Vector2(-w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
				Color(col.r, col.g, col.b, a))

class Scenery extends Node2D:
	# Parallax layer content: 0 = far mountains, 1 = near hills + clouds.
	var kind := 0
	func _init(k: int) -> void:
		kind = k
	func _ready() -> void:
		queue_redraw()
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234 + kind
		if kind == 0:
			var pts := PackedVector2Array()
			pts.append(Vector2(0, 900))
			for i in range(25):
				var x := 2400.0 * float(i) / 24.0
				pts.append(Vector2(x, 430.0 - sin(float(i) * 1.3) * 90.0 - rng.randf_range(0, 40)))
			pts.append(Vector2(2400, 900))
			draw_colored_polygon(pts, Color(0.62, 0.78, 0.92))
			for i in range(4):
				var cx := rng.randf_range(100, 2300)
				var cy := rng.randf_range(60, 200)
				for o in [Vector2(-34, 6), Vector2.ZERO, Vector2(34, 6), Vector2(0, 14)]:
					draw_circle(Vector2(cx, cy) + o, rng.randf_range(24, 34), Color(1, 1, 1, 0.75))
		else:
			var pts := PackedVector2Array()
			pts.append(Vector2(0, 900))
			for i in range(25):
				var x := 2400.0 * float(i) / 24.0
				pts.append(Vector2(x, 520.0 - sin(float(i) * 2.1 + 1.0) * 60.0 - rng.randf_range(0, 30)))
			pts.append(Vector2(2400, 900))
			draw_colored_polygon(pts, Color(0.55, 0.8, 0.62))

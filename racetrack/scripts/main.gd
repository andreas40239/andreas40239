extends Node3D
## Hauptszene: Editor-Modus (Strecke bauen) und Fahr-Modus.

enum Mode { EDIT, DRIVE }

const SAVE_PATH := "user://track.json"
const UI_FONT := 22

var mode := Mode.EDIT
var input_enabled := true
var landscape: Landscape
var track: Track
var cam: GameCamera
var audio: GameAudio
var car: Car = null
var car_type := Car.RACER

var ui_edit: Control
var ui_drive: Control
var touch: TouchControls
var fps_label: Label
var msg_label: Label
var info_label: Label
var lap_label: Label
var times_label: Label
var speed_label: Label
var big_label: Label
var hint_label: Label
var music_btns: Array[Button] = []
var car_btns: Array[Button] = []
var confetti: CPUParticles3D

# Runden
var lap_started := false
var lap_time := 0.0
var lap_count := 0
var best_lap := INF
var last_lap := -1.0
var progress_idx := -1
var checkpoints := [false, false, false]

# Editor-Kamera-Gesten
var _drag_touches := {}
var _pinch_dist := 0.0
var _msg_tween: Tween
var _big_tween: Tween

# Dynamische Aufloesung (FPS >= 35 halten)
var _res_scale := 0.9
var _res_timer := 0.0


func _ready() -> void:
	landscape = Landscape.new()
	add_child(landscape)
	track = Track.new()
	add_child(track)
	cam = GameCamera.new()
	add_child(cam)
	cam.current = true
	audio = GameAudio.new()
	add_child(audio)
	confetti = _make_confetti()
	add_child(confetti)
	_build_ui()
	_load_track()
	track.changed.connect(_on_track_changed)
	get_viewport().scaling_3d_scale = _res_scale
	_enter_edit()


# ---------------------------------------------------------------------------
# UI-Aufbau
# ---------------------------------------------------------------------------
func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = UI_FONT
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.12, 0.18, 0.82)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(8)
	normal.border_color = Color(1, 1, 1, 0.25)
	normal.set_border_width_all(2)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.22, 0.32, 0.9)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.95, 0.65, 0.1, 0.95)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBox = normal
		match st:
			"hover": sb = hover
			"pressed": sb = pressed
			"disabled": sb = disabled
			"focus": sb = StyleBoxEmpty.new()
		th.set_stylebox(st, "Button", sb)
	th.set_stylebox("hover_pressed", "Button", pressed)
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color(0.1, 0.1, 0.1))
	th.set_color("font_hover_pressed_color", "Button", Color(0.1, 0.1, 0.1))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.05, 0.07, 0.12, 0.55)
	panel.set_corner_radius_all(12)
	panel.set_content_margin_all(8)
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	th.set_constant("outline_size", "Label", 6)
	th.set_color("font_color", "Label", Color.WHITE)
	return th


func _btn(parent: Control, text: String, cb: Callable, min_size := Vector2(150, 62)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _label(parent: Control, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	layer.add_child(root)

	# ---------------- Editor ----------------
	ui_edit = Control.new()
	ui_edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ui_edit)

	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 6)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui_edit.add_child(bottom)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	bottom.add_child(grid)
	var row1 := [[Track.STRAIGHT, "Gerade"], [Track.BOOST, "Booster"], [Track.RAMP_UP, "Rampe hoch"],
		[Track.RAMP_DOWN, "Rampe runter"], [Track.TIGHT_L, "Kurve eng L"], [Track.TIGHT_R, "Kurve eng R"]]
	for it in row1:
		_btn(grid, it[1], _on_piece.bind(it[0]))
	_btn(grid, "Rückgängig", _on_undo)
	var row2 := [[Track.WIDE_L, "Kurve lang L"], [Track.WIDE_R, "Kurve lang R"],
		[Track.BANK_L, "Steilkurve L"], [Track.BANK_R, "Steilkurve R"]]
	for it in row2:
		_btn(grid, it[1], _on_piece.bind(it[0]))
	_btn(grid, "Demo-Strecke", _on_demo)
	_btn(grid, "Alles löschen", _on_clear)
	_btn(grid, "Übersicht", _on_overview)

	var right := VBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position.y = 46
	right.add_theme_constant_override("separation", 6)
	ui_edit.add_child(right)
	var group := ButtonGroup.new()
	for i in 3:
		var b := _btn(right, Car.NAMES[i], _on_car_select.bind(i), Vector2(210, 58))
		b.toggle_mode = true
		b.button_group = group
		car_btns.append(b)
	var go := _btn(right, "FAHREN  >", _enter_drive, Vector2(210, 80))
	go.add_theme_font_size_override("font_size", 30)
	var go_style := StyleBoxFlat.new()
	go_style.bg_color = Color(0.1, 0.65, 0.2, 0.95)
	go_style.set_corner_radius_all(12)
	go.add_theme_stylebox_override("normal", go_style)
	go.add_theme_stylebox_override("hover", go_style)

	var tl := VBoxContainer.new()
	tl.position = Vector2(14, 10)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_edit.add_child(tl)
	_label(tl, "Rennbahn-Baukasten", 30)
	info_label = _label(tl, "", 22)
	_label(tl, "Ziehen = Kamera drehen, Zwei Finger = Zoom", 16)
	var mb := _btn(tl, "Musik: an", _on_music, Vector2(150, 48))
	mb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	music_btns.append(mb)

	msg_label = _label(ui_edit, "", 28)
	msg_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	msg_label.position.y = 120
	msg_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))

	# ---------------- Fahren ----------------
	ui_drive = Control.new()
	ui_drive.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_drive.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ui_drive)
	touch = TouchControls.new()
	ui_drive.add_child(touch)
	var dtl := HBoxContainer.new()
	dtl.position = Vector2(12, 10)
	dtl.add_theme_constant_override("separation", 8)
	ui_drive.add_child(dtl)
	_btn(dtl, "< Editor", _enter_edit, Vector2(130, 56))
	_btn(dtl, "Neustart", _on_restart, Vector2(130, 56))
	_btn(dtl, "Aufstellen", _on_flip, Vector2(140, 56))
	music_btns.append(_btn(dtl, "Musik: an", _on_music, Vector2(140, 56)))

	var tc := VBoxContainer.new()
	tc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	tc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tc.position.y = 72
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.alignment = BoxContainer.ALIGNMENT_CENTER
	ui_drive.add_child(tc)
	lap_label = _label(tc, "", 36)
	lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	times_label = _label(tc, "", 22)
	times_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label = _label(tc, "", 20)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	speed_label = _label(ui_drive, "0 km/h", 46)
	speed_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	speed_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	speed_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.position.y -= 30

	big_label = _label(ui_drive, "", 64)
	big_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	big_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	big_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_label.position.y -= 90
	big_label.add_theme_color_override("font_color", Color(1, 0.85, 0.15))
	big_label.add_theme_constant_override("outline_size", 12)

	# ---------------- FPS (immer sichtbar, oben rechts) ----------------
	var top_layer := CanvasLayer.new()
	top_layer.layer = 10
	add_child(top_layer)
	fps_label = Label.new()
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fps_label.position = Vector2(-10, 6)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.add_theme_font_size_override("font_size", 22)
	fps_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 6)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_layer.add_child(fps_label)


func _make_confetti() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 320
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.9
	p.lifetime = 4.5
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.2)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(5.0, 0.6, 5.0)
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 15.0
	p.gravity = Vector3(0, -5.5, 0)
	p.damping_min = 1.0
	p.damping_max = 2.5
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -500.0
	p.angular_velocity_max = 500.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 0.15, 0.15), Color(1, 0.85, 0.1), Color(0.2, 0.9, 0.2),
		Color(0.1, 0.8, 1.0), Color(0.3, 0.3, 1.0), Color(1, 0.3, 0.9)])
	p.color_initial_ramp = g
	return p


# ---------------------------------------------------------------------------
# Modi
# ---------------------------------------------------------------------------
func _enter_edit() -> void:
	mode = Mode.EDIT
	if car:
		car.queue_free()
		car = null
	audio.stop_engine()
	touch.release_all()
	ui_edit.visible = true
	ui_drive.visible = false
	landscape.set_grid_visible(true)
	track.set_cursor_visible(true)
	cam.edit_mode(track.cursor_world())
	cam.dist_goal = 75.0
	_update_info()
	_update_car_buttons()


func _enter_drive() -> void:
	mode = Mode.DRIVE
	ui_edit.visible = false
	ui_drive.visible = true
	landscape.set_grid_visible(false)
	track.set_cursor_visible(false)
	if car:
		car.queue_free()
	car = Car.new()
	add_child(car)
	car.setup(car_type, track)
	car.boosted.connect(func(): audio.play("boost", -2.0))
	car.landed.connect(func(s: float): audio.play("landing", linear_to_db(clampf(s, 0.3, 1.0)) + 2.0))
	car.wall_hit.connect(func(s: float): audio.play("thud", linear_to_db(s) + 2.0, randf_range(0.85, 1.15)))
	_reset_car()
	cam.follow(car)
	audio.start_engine(car_type)
	_save_track()


func _reset_car() -> void:
	car.reset_to(track.sample_transform(0))
	lap_started = false
	lap_time = 0.0
	lap_count = 0
	progress_idx = -1
	checkpoints = [false, false, false]
	cam.follow(car)


# ---------------------------------------------------------------------------
# Editor-Aktionen
# ---------------------------------------------------------------------------
func _on_piece(type: int) -> void:
	var was_closed := track.closed
	var err := track.add_piece(type)
	if err != "":
		_message(err)
		audio.play("error", -4.0)
		return
	audio.play("click", -3.0)
	if track.closed and not was_closed:
		_message("Strecke geschlossen! Start/Ziel-Banner steht.")
		audio.play("fanfare", -6.0)


func _on_undo() -> void:
	if track.undo():
		audio.play("click", -6.0, 0.8)
	else:
		_message("Das Startstück bleibt.")


func _on_clear() -> void:
	track.clear()
	audio.play("click", -6.0, 0.7)


func _on_demo() -> void:
	track.load_demo()
	audio.play("click", -3.0)
	if track.closed:
		_message("Demo-Strecke geladen (geschlossen).")


func _on_overview() -> void:
	if cam.dist_goal < 150.0:
		cam.dist_goal = 260.0
		cam.orbit_goal = Vector3.ZERO
		cam.pitch = deg_to_rad(62.0)
	else:
		cam.dist_goal = 75.0
		cam.orbit_goal = track.cursor_world()
		cam.pitch = deg_to_rad(48.0)


func _on_car_select(i: int) -> void:
	car_type = i
	audio.play("click", -6.0)


func _update_car_buttons() -> void:
	for i in car_btns.size():
		car_btns[i].set_pressed_no_signal(i == car_type)


func _on_music() -> void:
	var on := audio.toggle_music()
	for b in music_btns:
		b.text = "Musik: an" if on else "Musik: aus"


func _on_restart() -> void:
	if car:
		_reset_car()


func _on_flip() -> void:
	if not car:
		return
	var i := track.nearest_sample(car.global_position)
	if i >= 0 and track.centers[i].distance_to(car.global_position) < 25.0:
		car.reset_to(track.sample_transform(i))
	else:
		car.flip_upright()


func _on_track_changed() -> void:
	track.set_cursor_visible(mode == Mode.EDIT)
	if mode == Mode.EDIT:
		if cam.dist_goal < 150.0:
			cam.orbit_goal = track.cursor_world()
	_update_info()
	_save_track()


func _update_info() -> void:
	var state := "geschlossen - Runden werden gezählt" if track.closed else "offen - freie Fahrt am Ende"
	info_label.text = "Teile: %d   |   Strecke %s" % [track.piece_count(), state]


func _message(t: String) -> void:
	msg_label.text = t
	msg_label.modulate.a = 1.0
	if _msg_tween:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_interval(1.8)
	_msg_tween.tween_property(msg_label, "modulate:a", 0.0, 0.6)


func _big(t: String) -> void:
	big_label.text = t
	big_label.modulate.a = 1.0
	big_label.scale = Vector2.ONE
	if _big_tween:
		_big_tween.kill()
	_big_tween = create_tween()
	_big_tween.tween_interval(2.6)
	_big_tween.tween_property(big_label, "modulate:a", 0.0, 0.8)


# ---------------------------------------------------------------------------
# Eingabe (Editor-Kamera)
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and car:
			_on_flip()
		elif event.keycode == KEY_ESCAPE and mode == Mode.DRIVE:
			_enter_edit()
	if mode != Mode.EDIT:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_drag_touches[event.index] = event.position
		else:
			_drag_touches.erase(event.index)
		_pinch_dist = 0.0
	elif event is InputEventScreenDrag:
		if not _drag_touches.has(event.index):
			return
		_drag_touches[event.index] = event.position
		if _drag_touches.size() == 1:
			cam.orbit_rotate(event.relative)
		elif _drag_touches.size() >= 2:
			var pts: Array = _drag_touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_dist > 0.0 and d > 1.0:
				cam.orbit_zoom(_pinch_dist / d)
			_pinch_dist = d
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.orbit_zoom(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.orbit_zoom(1.1)


# ---------------------------------------------------------------------------
# Spielschleife
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if mode != Mode.DRIVE or car == null:
		return
	if not input_enabled:
		_update_laps(delta)
		return
	var key_steer := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		key_steer -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		key_steer += 1.0
	var key_gas := Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)
	var key_brake := Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S) \
		or Input.is_physical_key_pressed(KEY_SPACE)
	car.steer_input = clampf(touch.steer + key_steer, -1.0, 1.0)
	car.throttle = 1.0 if (touch.gas or key_gas) else 0.0
	car.brake_input = 1.0 if (touch.brake or key_brake) else 0.0
	_update_laps(delta)


func _update_laps(delta: float) -> void:
	if not track.closed:
		return
	if lap_started:
		lap_time += delta
	var n := track.centers.size()
	var idx := track.nearest_sample(car.global_position, progress_idx)
	if idx < 0:
		return
	var p := posmod(idx - Track.LINE_INDEX, n)
	if progress_idx >= 0:
		var pp := posmod(progress_idx - Track.LINE_INDEX, n)
		if pp > n * 0.75 and p < n * 0.25:
			_cross_line()
		elif pp < n * 0.25 and p > n * 0.75:
			checkpoints = [false, false, false]
	for k in 3:
		if absf(p - (k + 1) * n / 4.0) < n * 0.07:
			checkpoints[k] = true
	progress_idx = idx


func _cross_line() -> void:
	if lap_started and checkpoints[0] and checkpoints[1] and checkpoints[2]:
		lap_count += 1
		last_lap = lap_time
		var record := lap_time < best_lap
		best_lap = minf(best_lap, lap_time)
		_big("RUNDE %d!\n%s%s" % [lap_count, _fmt(last_lap), "\nNEUE BESTZEIT!" if record and lap_count > 1 else ""])
		audio.play("fanfare", 0.0)
		# Konfetti-Regen ueber der Strecke vor dem Auto (und damit auch am Banner)
		var ahead := car.linear_velocity * 0.9
		ahead.y = 0.0
		confetti.global_position = car.global_position + ahead + Vector3.UP * 7.0
		confetti.restart()
		lap_time = 0.0
	elif not lap_started:
		lap_started = true
		lap_time = 0.0
		_big("LOS!")
	checkpoints = [false, false, false]


func _fmt(t: float) -> String:
	if t < 0.0 or t == INF:
		return "--:--.--"
	var m := int(t / 60.0)
	return "%d:%05.2f" % [m, t - m * 60.0]


func _process(delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	fps_label.text = "FPS %d" % fps
	fps_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3) if fps >= 35 else Color(1, 0.3, 0.2))
	_adapt_resolution(delta, fps)
	if mode == Mode.DRIVE and car:
		speed_label.text = "%d km/h" % int(absf(car.speed) * 3.6)
		if track.closed:
			lap_label.text = ("Runde %d   %s" % [lap_count + 1, _fmt(lap_time)]) if lap_started else "Fahr über die Startlinie!"
			times_label.text = "Letzte: %s    Beste: %s" % [_fmt(last_lap), _fmt(best_lap)]
			hint_label.text = ""
		else:
			lap_label.text = "Freie Fahrt"
			times_label.text = ""
			hint_label.text = "Strecke offen - schließe sie im Editor für Rundenzeiten"
		audio.update_engine(car.rpm, car.throttle, car.slip)
		if car.global_position.y < -30.0:
			_reset_car()


func _adapt_resolution(delta: float, fps: float) -> void:
	_res_timer += delta
	if _res_timer < 1.5:
		return
	_res_timer = 0.0
	var old := _res_scale
	if fps < 42.0:
		_res_scale = maxf(_res_scale - 0.1, 0.5)
	elif fps >= 58.0:
		_res_scale = minf(_res_scale + 0.05, 1.0)
	if not is_equal_approx(old, _res_scale):
		get_viewport().scaling_3d_scale = _res_scale


# ---------------------------------------------------------------------------
# Speichern / Laden
# ---------------------------------------------------------------------------
func _save_track() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"pieces": track.get_types(), "car": car_type}))


func _load_track() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if data is Dictionary and data.has("pieces"):
			track.load_types(data["pieces"])
			car_type = clampi(int(data.get("car", Car.RACER)), 0, 2)
			return
	track.load_demo()

extends Node3D
## Hauptszene: Welt, UI, Eingabe (Tap / Pinch / Pan / Joystick) und Fahrmodus.

const P := CoasterTrack.Piece
const G := 9.81
const TAP_MAX_MOVE := 24.0
const TAP_MAX_MS := 450
const SKY_COLOR := Color(0.62, 0.8, 0.96)
const GRASS_COLOR := Color(0.33, 0.62, 0.24)
const FORWARD_TYPES := [P.STRAIGHT, P.UP, P.DOWN, P.STEEP_UP, P.STEEP_DOWN, P.LOOP, P.CORKSCREW,
	P.BOOSTER, P.BRAKE, P.TUNNEL, P.SPLASH]
const TURN_PAIRS := [[P.LEFT, P.RIGHT], [P.BANK_LEFT, P.BANK_RIGHT], [P.WIDE_LEFT, P.WIDE_RIGHT]]
# Bauleiste: Kategorie-Reiter mit ihren Teilen (Icon, Teil)
const CATEGORIES := [
	["cat_turns", "Kurven", [["left", P.LEFT], ["right", P.RIGHT], ["bank_left", P.BANK_LEFT],
		["bank_right", P.BANK_RIGHT], ["wide_left", P.WIDE_LEFT], ["wide_right", P.WIDE_RIGHT]]],
	["cat_height", "Höhe", [["up", P.UP], ["down", P.DOWN], ["steep_up", P.STEEP_UP],
		["steep_down", P.STEEP_DOWN]]],
	["cat_special", "Spezial", [["loop", P.LOOP], ["corkscrew", P.CORKSCREW], ["booster", P.BOOSTER],
		["brake", P.BRAKE], ["tunnel", P.TUNNEL], ["splash", P.SPLASH]]],
]

var track: CoasterTrack
var rig: IsoCameraRig
var cart: Node3D                 # erster Wagen des Zugs
var train: CoasterTrain
var ride_cam: Camera3D
var env: Environment
var sfx: Sfx
var save_menu: SaveMenu
var title: TitleScreen
var tutorial: Tutorial
var ride_btn: Button
var undo_btn: Button
var save_btn: Button
signal category_changed(ci: int)
signal piece_built(type: int)
signal ride_started
signal ride_stopped

var in_title := true   # startet im Startbildschirm (verhindert Autosave der leeren Strecke)
var _autosave_timer := -1.0
var sound_btn: Button
var cursor_root: Node3D
var cursor_main: MeshInstance3D
var cursor_left: MeshInstance3D
var cursor_right: MeshInstance3D
var cursor_arrow: MeshInstance3D

# UI
var ui_root: Control
var build_bar: HBoxContainer
var action_bar: VBoxContainer
var ride_bar: HBoxContainer
var piece_buttons := {}          # Piece -> Button (für die Auswahl-Markierung)
var fps_label: Label
var _fps_timer := 0.0
var _frame_ms_max := 0.0
var joystick: VirtualJoystick
var status_label: Label
var toast_label: Label
var help_label: Label
var speed_label: Label
var _toast_time := 0.0

# Eingabe
var _touches := {}
var _tap_index := -1
var _tap_start := Vector2.ZERO
var _tap_time := 0
var _tap_valid := false
var _pinch_dist := 0.0
var _mouse_left := false
var _mouse_right := false

# Fahrt
var riding := false
var ride_s := 0.0
var ride_v := 0.0
var ride_max_v := 0.0
var ride_laps := 0
var view_mode := 0               # 0 = vorne, 1 = Mitte (mit Fahrgästen), 2 = Verfolger
const VIEW_NAMES := ["Vorne im Zug", "Mitte – mit Fahrgästen", "Verfolgerkamera"]
var _look := Vector2.ZERO        # Yaw/Pitch-Versatz des Blicks (Grad)
var _chase_eye := Vector3.INF    # geglättete Position der Verfolgerkamera
var _ride_end_timer := -1.0
var _last_forward := P.STRAIGHT
var _turn_pair := [P.LEFT, P.RIGHT]   # was ein Tippen aufs linke/rechte Seitenfeld setzt
var _category := 0
var _category_rows: Array[HBoxContainer] = []
var _category_tabs: Array[Button] = []
var _loop_warned := false
var _ride_piece := -1
var loop_entry_v := 0.0         # Tempo bei der letzten Looping-Einfahrt


func _ready() -> void:
	sfx = Sfx.new()
	add_child(sfx)
	_setup_world()
	track = CoasterTrack.new()
	add_child(track)
	track.changed.connect(_on_track_changed)
	_setup_cursor()
	_setup_cart()
	rig = IsoCameraRig.new()
	add_child(rig)
	var span := CoasterTrack.GRID * CoasterTrack.TILE
	rig.bounds = Rect2(0, 0, span, span)
	rig.position = CoasterTrack.cell_center(CoasterTrack.STATION_CELL) + Vector3(12, 0, 0)
	rig.make_current()
	_setup_ui()
	_on_track_changed()
	_enter_title()


# ------------------------------------------------------------------ Welt ---

func _setup_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.84, 0.92)
	env.ambient_light_energy = 0.4
	env.fog_enabled = false   # nur im Fahrmodus (die Iso-Kamera steht weit entfernt)
	env.fog_light_color = SKY_COLOR
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)

	# Boden mit Schachbrett-Raster (Greybox)
	var span := CoasterTrack.GRID * CoasterTrack.TILE
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, Color(0.46, 0.48, 0.46))
	img.set_pixel(1, 1, Color(0.46, 0.48, 0.46))
	img.set_pixel(1, 0, Color(0.41, 0.43, 0.41))
	img.set_pixel(0, 1, Color(0.41, 0.43, 0.41))
	var grid_mat := StandardMaterial3D.new()
	grid_mat.albedo_texture = ImageTexture.create_from_image(img)
	grid_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	grid_mat.uv1_scale = Vector3(CoasterTrack.GRID * 0.5, CoasterTrack.GRID * 0.5, 1)
	grid_mat.roughness = 1.0
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(span, span)
	plane.material = grid_mat
	ground.mesh = plane
	ground.position = Vector3(span * 0.5, 0, span * 0.5)
	add_child(ground)

	var outer := MeshInstance3D.new()
	var oplane := PlaneMesh.new()
	oplane.size = Vector2(span * 12, span * 12)
	var omat := StandardMaterial3D.new()
	omat.albedo_color = GRASS_COLOR
	omat.roughness = 1.0
	oplane.material = omat
	outer.mesh = oplane
	outer.position = Vector3(span * 0.5, -0.02, span * 0.5)
	add_child(outer)

	# Ein paar graue Platzhalter-Klötze als "Bäume/Gebäude" rund ums Baufeld
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var deco_mat := StandardMaterial3D.new()
	deco_mat.albedo_color = Color(0.42, 0.44, 0.45)
	for i in 40:
		var side := rng.randi() % 4
		var along := rng.randf_range(-8, span + 8)
		var off := rng.randf_range(6, 26)
		var pos := Vector3.ZERO
		match side:
			0: pos = Vector3(along, 0, -off)
			1: pos = Vector3(along, 0, span + off)
			2: pos = Vector3(-off, 0, along)
			3: pos = Vector3(span + off, 0, along)
		var mi := MeshInstance3D.new()
		if rng.randf() < 0.6:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.0
			cyl.bottom_radius = rng.randf_range(1.2, 2.2)
			cyl.height = rng.randf_range(4, 8)
			cyl.radial_segments = 8
			cyl.material = deco_mat
			mi.mesh = cyl
			pos.y = cyl.height * 0.5
		else:
			var b := BoxMesh.new()
			b.size = Vector3(rng.randf_range(3, 7), rng.randf_range(2, 6), rng.randf_range(3, 7))
			b.material = deco_mat
			mi.mesh = b
			pos.y = b.size.y * 0.5
		mi.position = pos
		add_child(mi)


func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	return m


func _setup_cursor() -> void:
	cursor_root = Node3D.new()
	add_child(cursor_root)
	var t := CoasterTrack.TILE
	cursor_main = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(t * 0.92, 0.12, t * 0.92)
	cursor_main.mesh = b
	cursor_root.add_child(cursor_main)
	cursor_left = MeshInstance3D.new()
	var bl := BoxMesh.new()
	bl.size = Vector3(t * 0.7, 0.08, t * 0.7)
	cursor_left.mesh = bl
	cursor_root.add_child(cursor_left)
	cursor_right = MeshInstance3D.new()
	cursor_right.mesh = bl
	cursor_root.add_child(cursor_right)
	cursor_arrow = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.6, 1.6, 0.2)
	cursor_arrow.mesh = prism
	cursor_arrow.material_override = _flat_mat(Color(1, 1, 1, 0.9))
	cursor_root.add_child(cursor_arrow)


func _setup_cart() -> void:
	train = CoasterTrain.new()
	add_child(train)
	cart = train.cars[0]
	ride_cam = Camera3D.new()
	ride_cam.fov = 80
	ride_cam.near = 0.05
	ride_cam.far = 600
	add_child(ride_cam)
	_place_cart(track.station_s())
	_update_ride_cam()


# -------------------------------------------------------------------- UI ---

func _make_button(icon_name: String, tip: String, cb: Callable, btn_size := 80.0) -> Button:
	var b := Button.new()
	b.icon = load("res://icons/%s.svg" % icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(btn_size, btn_size)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _piece_button(icon_name: String, type: int) -> Button:
	var b := _make_button(icon_name, CoasterTrack.PIECE_NAMES[type], _build.bind(type))
	piece_buttons[type] = b
	return b


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 22
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.23, 0.25, 0.88)
	normal.set_corner_radius_all(12)
	normal.set_content_margin_all(12)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.3, 0.31, 0.34, 0.92)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.45, 0.47, 0.5, 0.95)
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color(0.95, 0.95, 0.95))
	th.set_color("font_color", "Label", Color(0.1, 0.1, 0.12))
	var sel := normal.duplicate()
	sel.border_color = Color(0.45, 0.95, 0.5)
	sel.set_border_width_all(4)
	th.set_stylebox("selected", "Button", sel)
	return th


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = _make_theme()
	layer.add_child(ui_root)

	status_label = Label.new()
	status_label.position = Vector2(20, 14)
	status_label.add_theme_font_size_override("font_size", 24)
	ui_root.add_child(status_label)

	help_label = Label.new()
	help_label.position = Vector2(20, 52)
	help_label.add_theme_font_size_override("font_size", 16)
	help_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.18, 0.8))
	ui_root.add_child(help_label)

	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.offset_left = -400
	toast_label.offset_right = 400
	toast_label.offset_top = 70
	toast_label.offset_bottom = 110
	toast_label.add_theme_font_size_override("font_size", 24)
	var toast_bg := StyleBoxFlat.new()
	toast_bg.bg_color = Color(0.1, 0.1, 0.12, 0.75)
	toast_bg.set_corner_radius_all(10)
	toast_bg.set_content_margin_all(8)
	toast_label.add_theme_stylebox_override("normal", toast_bg)
	toast_label.add_theme_color_override("font_color", Color(1, 1, 1))
	toast_label.visible = false
	ui_root.add_child(toast_label)

	speed_label = Label.new()
	speed_label.position = Vector2(20, 14)
	speed_label.add_theme_font_size_override("font_size", 30)
	speed_label.add_theme_color_override("font_color", Color(1, 1, 1))
	speed_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	speed_label.add_theme_constant_override("outline_size", 6)
	speed_label.visible = false
	ui_root.add_child(speed_label)

	joystick = VirtualJoystick.new()
	ui_root.add_child(joystick)
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left = 16
	joystick.offset_right = 16 + joystick.size.x
	joystick.offset_top = -joystick.size.y - 16
	joystick.offset_bottom = -16

	build_bar = HBoxContainer.new()
	build_bar.add_theme_constant_override("separation", 8)
	build_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	build_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	build_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	build_bar.offset_right = -16
	build_bar.offset_bottom = -16
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = Color(0.2, 0.3, 0.42, 0.9)
	tab_style.set_corner_radius_all(12)
	tab_style.set_content_margin_all(14)
	for ci in CATEGORIES.size():
		var tab := _make_button(CATEGORIES[ci][0], CATEGORIES[ci][1], _select_category.bind(ci), 80.0)
		tab.custom_minimum_size = Vector2(62, 80)
		tab.add_theme_stylebox_override("normal", tab_style)
		_category_tabs.append(tab)
		build_bar.add_child(tab)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		for entry in CATEGORIES[ci][2]:
			row.add_child(_piece_button(entry[0], entry[1]))
		_category_rows.append(row)
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(6, 0)
	build_bar.add_child(sep)
	for row in _category_rows:
		build_bar.add_child(row)
	build_bar.add_child(_piece_button("straight", P.STRAIGHT))
	undo_btn = _make_button("undo", "Zurück", _on_undo)
	build_bar.add_child(undo_btn)
	ui_root.add_child(build_bar)

	# Aktionen rechts: Fahren, Demo-Strecke, Neu
	action_bar = VBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 8)
	action_bar.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	action_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	action_bar.grow_vertical = Control.GROW_DIRECTION_BOTH
	action_bar.offset_right = -16
	action_bar.offset_top = -30
	action_bar.offset_bottom = -30
	ride_btn = _make_button("play", "Fahren", _start_ride, 96)
	var ride_style := StyleBoxFlat.new()
	ride_style.bg_color = Color(0.45, 0.9, 0.5, 0.95)
	ride_style.set_corner_radius_all(52)
	ride_style.set_content_margin_all(18)
	ride_btn.add_theme_stylebox_override("normal", ride_style)
	var ride_hover := ride_style.duplicate()
	ride_hover.bg_color = Color(0.6, 0.97, 0.65, 0.95)
	ride_btn.add_theme_stylebox_override("hover", ride_hover)
	ride_btn.add_theme_stylebox_override("pressed", ride_hover)
	action_bar.add_child(ride_btn)
	sound_btn = _make_button("sound_off" if sfx.muted else "sound_on", "Ton an/aus", _on_toggle_sound)
	save_btn = _make_button("save", "Speichern & Laden", _open_save_menu)
	for b in [_make_button("demo", "Demo-Strecke", _on_demo), _make_button("new", "Neue Strecke", _on_new),
			save_btn, sound_btn]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		action_bar.add_child(b)
	ui_root.add_child(action_bar)

	fps_label = Label.new()
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.offset_left = -420
	fps_label.offset_right = -12
	fps_label.offset_top = 6
	fps_label.offset_bottom = 34
	fps_label.add_theme_font_size_override("font_size", 18)
	fps_label.add_theme_color_override("font_color", Color(1, 1, 1))
	fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	fps_label.add_theme_constant_override("outline_size", 5)
	ui_root.add_child(fps_label)

	ride_bar = HBoxContainer.new()
	ride_bar.add_theme_constant_override("separation", 8)
	ride_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ride_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ride_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ride_bar.offset_right = -16
	ride_bar.offset_bottom = -16
	ride_bar.add_child(_make_button("view", "Ansicht 1./3. Person", _toggle_view, 92))
	ride_bar.add_child(_make_button("stop", "Stopp", _stop_ride, 92))
	ride_bar.visible = false
	ui_root.add_child(ride_bar)

	save_menu = SaveMenu.new()
	ui_root.add_child(save_menu)
	save_menu.setup(_make_button)
	save_menu.save_requested.connect(_on_save_slot)
	save_menu.load_requested.connect(_on_load_slot)
	save_menu.closed.connect(_on_save_menu_closed)
	save_menu.clicked.connect(sfx.play.bind("click"))

	title = TitleScreen.new()
	ui_root.add_child(title)
	title.setup(false, sfx.muted)
	title.visible = false
	title.continue_pressed.connect(_leave_title.bind("continue"))
	title.new_pressed.connect(_leave_title.bind("new"))
	title.load_pressed.connect(_leave_title.bind("load"))
	title.demo_pressed.connect(_leave_title.bind("demo"))
	title.tutorial_pressed.connect(_leave_title.bind("tutorial"))

	tutorial = Tutorial.new()
	ui_root.add_child(tutorial)
	tutorial.setup()
	tutorial.steps = _tutorial_steps()
	tutorial.finished.connect(func(): _show_toast("Tutorial beendet – viel Spaß beim Bauen!", 3.0))
	piece_built.connect(func(t): tutorial.notify_event("piece_built", t))
	category_changed.connect(func(ci): tutorial.notify_event("category", ci))
	ride_started.connect(func(): tutorial.notify_event("ride_started"))
	ride_stopped.connect(func(): tutorial.notify_event("ride_stopped"))
	title.sound_pressed.connect(_on_toggle_sound)

	_update_help()
	_select_category(0, false)


## Markiert die Teile, die ein Tippen auf die Felder setzen würde.
func _select_category(ci: int, with_sound := true) -> void:
	_category = ci
	for i in _category_rows.size():
		_category_rows[i].visible = i == ci
		_category_tabs[i].modulate = Color(1, 1, 1) if i == ci else Color(1, 1, 1, 0.55)
	if with_sound:
		sfx.play("click")
	_refresh_selection()
	category_changed.emit(ci)


func _refresh_selection() -> void:
	for type in piece_buttons:
		var b: Button = piece_buttons[type]
		if type == _last_forward or type in _turn_pair:
			b.add_theme_stylebox_override("normal", b.get_theme_stylebox("selected"))
		else:
			b.remove_theme_stylebox_override("normal")


func _update_help() -> void:
	help_label.position.y = 110.0 if riding else 52.0   # im Fahrmodus unter der Tempoanzeige
	if riding:
		help_label.text = "Joystick / Wischen: umschauen\nAuge: vorne / Mitte / Verfolger"
	else:
		help_label.text = "Tippen: grünes Feld = markiertes Teil, helle Felder = Kurve\n1 Finger: verschieben · 2 Finger: zoomen\nJoystick: Ansicht drehen / kippen"


func _show_toast(msg: String, secs := 2.5) -> void:
	if in_title:
		return
	toast_label.text = msg
	toast_label.visible = true
	_toast_time = secs


func _is_over_ui(pos: Vector2) -> bool:
	if save_menu.visible or in_title or tutorial.is_over_card(pos):
		return true
	for c in [build_bar, action_bar, ride_bar, joystick]:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


# ---------------------------------------------------------------- Bauen ---

func _build(type: int) -> void:
	if riding:
		return
	var err := track.place(type)
	if err != "":
		_show_toast(err)
		sfx.play("error", -4.0)
		return
	var pitch := {P.LOOP: 0.75, P.CORKSCREW: 0.8, P.STEEP_DOWN: 0.85, P.UP: 1.1, P.STEEP_UP: 1.15}.get(type, 1.0) as float
	sfx.play("place", 0.0, pitch)
	if type in FORWARD_TYPES:
		_last_forward = type
	else:
		for pair in TURN_PAIRS:
			if type in pair:
				_turn_pair = pair
	_refresh_selection()
	piece_built.emit(type)
	if track.closed:
		_show_toast("Strecke geschlossen! Jetzt FAHREN drücken", 3.5)
		sfx.play("closed", -2.0, 1.0, 0.0)


func _on_undo() -> void:
	if not track.undo():
		_show_toast("Nichts zum Zurücknehmen")
		sfx.play("error", -4.0)
	else:
		sfx.play("undo")
		tutorial.notify_event("undo")


func _on_demo() -> void:
	track.build_demo()
	_show_toast("Demo-Strecke gebaut – FAHREN drücken")
	sfx.play("closed", -2.0, 1.0, 0.0)


func _on_new() -> void:
	track.reset()
	_show_toast("Neue Strecke")
	sfx.play("undo", 0.0, 0.8)


func _on_toggle_sound() -> void:
	sfx.set_muted(not sfx.muted)
	sound_btn.icon = load("res://icons/%s.svg" % ("sound_off" if sfx.muted else "sound_on"))
	title.set_muted(sfx.muted)
	sfx.play("click")
	if not in_title:
		_show_toast("Ton aus" if sfx.muted else "Ton an", 1.2)


# ------------------------------------------------------- Startbildschirm ---

## Zeigt den Startbildschirm; im Hintergrund fährt die Demo-Strecke.
func _enter_title() -> void:
	if riding:
		_stop_ride()
	if save_menu.visible:
		save_menu.visible = false
	_write_autosave()
	tutorial.stop()
	in_title = true
	for c in [build_bar, action_bar, ride_bar, joystick, status_label, help_label, speed_label, toast_label]:
		c.visible = false
	_touches.clear()
	_tap_valid = false
	track.build_demo()
	ride_s = track.station_s()
	ride_v = 2.0
	_ride_piece = -1
	var aabb := _track_bounds()
	rig.position = Vector3(aabb.get_center().x, 0, aabb.get_center().z)
	rig.zoom = maxf(aabb.size.x, aabb.size.z) * 1.3
	rig.zoom_by(1.0)
	rig.cam.h_offset = -rig.zoom * 0.3   # Strecke rechts neben dem Menü zeigen
	rig.make_current()
	title.continue_button.disabled = SaveSlots.read_autosave().is_empty()
	title.show_animated()


func _leave_title(action: String) -> void:
	if not in_title:
		return
	sfx.play("click")
	in_title = false
	title.hide_animated()
	rig.cam.h_offset = 0.0
	for c in [build_bar, action_bar, joystick, status_label, help_label]:
		c.visible = true
	ride_v = 0.0
	match action:
		"continue":
			track.load_types(SaveSlots.read_autosave())
			_show_toast("Weiter geht's!")
		"new":
			track.reset()
			_show_toast("Tippe auf das grüne Feld, um die Strecke zu verlängern")
		"load":
			track.reset()
			_open_save_menu()
		"demo":
			_start_ride()
		"tutorial":
			track.reset()
			_select_category(0, false)
			_turn_pair = TURN_PAIRS[0]
			_last_forward = P.STRAIGHT
			_refresh_selection()
			tutorial.start()
	if action != "demo":
		_place_cart(track.station_s())
		var aabb := _track_bounds()
		rig.position = Vector3(aabb.get_center().x, 0, aabb.get_center().z)
		rig.zoom = clampf(maxf(aabb.size.x, aabb.size.z) * 1.1, 40.0, 70.0)
		rig.zoom_by(1.0)


# ------------------------------------------------------------- Tutorial ---

func _tutorial_steps() -> Array[Dictionary]:
	return [
		{"title": "Willkommen!", "text": "Hier baust du deine eigene Achterbahn und fährst sie danach selbst. "
			+ "Die Strecke beginnt an der Station und wird Teil für Teil verlängert."},
		{"title": "Strecke verlängern", "text": "Tippe auf das grüne Feld vor der Strecke. "
			+ "Dort wird das grün umrandete Teil aus der Leiste gesetzt.",
			"target": _cursor_rect, "wait": "piece_built"},
		{"title": "Kurven", "text": "Tippe jetzt auf eines der hellen Felder links oder rechts – so entsteht eine Kurve.",
			"target": _side_rect, "wait": "piece_built", "accept": func(t): return not t in FORWARD_TYPES},
		{"title": "Bauteile-Leiste", "text": "Unten findest du alle Teile. Ein Tipp auf ein Teil setzt es sofort. "
			+ "Probier es aus!", "target": func(): return build_bar.get_global_rect(), "wait": "piece_built"},
		{"title": "Kategorien", "text": "Die drei blauen Reiter wechseln zwischen Kurven, Höhe und Spezialteilen "
			+ "(Looping, Korkenzieher, Booster, Bremse, Tunnel, Splash). Öffne die Kategorie „Höhe“.",
			"target": _tabs_rect, "wait": "category", "accept": func(ci): return ci == 1},
		{"title": "Bergauf", "text": "Setze ein Hoch-Teil. Bergauf zieht ein Kettenlift den Zug nach oben – "
			+ "Höhe bedeutet später Tempo!", "target": func(): return build_bar.get_global_rect(),
			"wait": "piece_built", "accept": func(t): return CoasterTrack.is_lift(t)},
		{"title": "Zurücknehmen", "text": "Der gebogene Pfeil ganz rechts nimmt das letzte Teil zurück. Tippe ihn einmal an.",
			"target": func(): return undo_btn.get_global_rect(), "wait": "undo"},
		{"title": "Ansicht", "text": "Ein Finger verschiebt die Ansicht, zwei Finger zoomen. "
			+ "Mit dem Joystick unten links drehst und kippst du die Kamera.",
			"target": func(): return joystick.get_global_rect()},
		{"title": "Strecke schließen", "text": "Führe die Strecke in Fahrtrichtung zurück in die Station – dann fährt "
			+ "der Zug endlos Runden. Offene Strecken kannst du trotzdem schon testen."},
		{"title": "Losfahren!", "text": "Tippe auf den grünen Play-Knopf und fahr deine Strecke selbst.",
			"target": func(): return ride_btn.get_global_rect(), "wait": "ride_started"},
		{"title": "Während der Fahrt", "text": "Das Auge wechselt die Kamera, mit Joystick oder Wischen schaust du "
			+ "dich um. Das Quadrat beendet die Fahrt.", "target": func(): return ride_bar.get_global_rect(),
			"wait": "ride_stopped"},
		{"title": "Speichern", "text": "Mit der Diskette legst du deine Strecke auf einem von 5 Speicherplätzen ab. "
			+ "Deine letzte Strecke wird außerdem automatisch gesichert. Viel Spaß!",
			"target": func(): return save_btn.get_global_rect()},
	]


func _screen_rect_of(world_pos: Vector3, half: float) -> Rect2:
	if riding or not cursor_root.visible:
		return Rect2()
	var p := rig.cam.unproject_position(world_pos)
	return Rect2(p - Vector2(half, half), Vector2(half, half) * 2.0)


func _cursor_rect() -> Rect2:
	return _screen_rect_of(cursor_main.global_position, 55.0)


func _side_rect() -> Rect2:
	var r := Rect2()
	for m in [cursor_left, cursor_right]:
		if m.visible:
			var mr := _screen_rect_of(m.global_position, 45.0)
			r = mr if r.size == Vector2.ZERO else r.merge(mr)
	return r


func _tabs_rect() -> Rect2:
	var r := _category_tabs[0].get_global_rect()
	for t in _category_tabs:
		r = r.merge(t.get_global_rect())
	return r


func _write_autosave() -> void:
	_autosave_timer = -1.0
	if not in_title and track != null:
		SaveSlots.write_autosave(track.get_types())


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			_write_autosave()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android-Zurück: Menü schließen → Fahrt beenden → Startbildschirm → App beenden
			if save_menu.visible:
				save_menu.close()
			elif riding:
				_stop_ride()
			elif not in_title:
				_enter_title()
			else:
				get_tree().quit()


# ------------------------------------------------------- Speichern/Laden ---

func _open_save_menu() -> void:
	if riding:
		return
	sfx.play("click")
	joystick.visible = false
	_touches.clear()
	_tap_valid = false
	save_menu.open()


func _on_save_menu_closed() -> void:
	joystick.visible = true
	sfx.play("click")


func _on_save_slot(slot: int) -> void:
	var thumb := await _capture_thumbnail()
	SaveSlots.write(slot, track.get_types(), track.length, track.closed, thumb)
	save_menu.refresh()
	sfx.play("save", 0.0, 1.0, 0.0)


func _on_load_slot(slot: int) -> void:
	var data := SaveSlots.read(slot)
	if data.is_empty():
		return
	var ok := track.load_types(data.pieces)
	save_menu.close()
	sfx.play("load", 0.0, 1.0, 0.0)
	_show_toast("Platz %d geladen" % (slot + 1) if ok else "Platz %d nur teilweise geladen" % (slot + 1))
	# Ansicht auf die Strecke zentrieren
	var aabb := _track_bounds()
	rig.position = Vector3(aabb.get_center().x, 0, aabb.get_center().z)


func _track_bounds() -> AABB:
	var aabb := AABB(track.path_points[0], Vector3.ZERO)
	for pt in track.path_points:
		aabb = aabb.expand(pt)
	return aabb


## Rendert ein kleines Vorschaubild der Strecke (eigene Kamera, ohne UI/Cursor).
func _capture_thumbnail() -> Image:
	if DisplayServer.get_name() == "headless":
		return null  # ohne Renderer (Tests) gibt es kein Bild
	var vp := SubViewport.new()
	vp.size = Vector2i(384, 216)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.5
	cam.far = 600.0
	vp.add_child(cam)
	add_child(vp)
	var aabb := _track_bounds()
	var view := Basis.from_euler(Vector3(deg_to_rad(rig.pitch), deg_to_rad(rig.yaw), 0))
	cam.global_transform = Transform3D(view, aabb.get_center() + view.z * 200.0)
	# Ortho-Größe so wählen, dass alle Ecken der Strecken-Box ins Bild passen
	var half := Vector2.ZERO
	for i in 8:
		var p := view.inverse() * (aabb.get_endpoint(i) - aabb.get_center())
		half = Vector2(maxf(half.x, absf(p.x)), maxf(half.y, absf(p.y)))
	var aspect := float(vp.size.x) / vp.size.y
	cam.size = maxf(half.y * 2.0, half.x * 2.0 / aspect) * 1.08 + 2.0
	cam.current = true
	var cursor_was := cursor_root.visible
	cursor_root.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	cursor_root.visible = cursor_was
	vp.queue_free()
	return img


func _on_track_changed() -> void:
	if status_label == null:
		return
	var n := track.pieces.size() - CoasterTrack.STATION_LEN
	var state := "GESCHLOSSEN" if track.closed else "offen"
	status_label.text = "Teile: %d   Höhe: %d   Länge: %d m   Strecke: %s" % [n, track.cursor_h, int(track.length), state]
	_update_cursor()
	if not riding:
		_place_cart(track.station_s())
	if not in_title:
		_autosave_timer = 1.0


func _update_cursor() -> void:
	cursor_root.visible = not track.closed and not riding
	if not cursor_root.visible:
		return
	var c := track.cursor_cell
	var d := track.cursor_dir
	var y := track.cursor_h * CoasterTrack.LEVEL + 0.08
	cursor_main.position = CoasterTrack.cell_center(c) + Vector3(0, y, 0)
	var lc := c + CoasterTrack.DIRS[(d + 3) % 4]
	var rc := c + CoasterTrack.DIRS[(d + 1) % 4]
	cursor_left.position = CoasterTrack.cell_center(lc) + Vector3(0, y, 0)
	cursor_right.position = CoasterTrack.cell_center(rc) + Vector3(0, y, 0)
	var ok_fwd := track.can_place(_last_forward) == ""
	cursor_main.material_override = _flat_mat(Color(0.2, 0.85, 0.3, 0.55) if ok_fwd else Color(0.9, 0.2, 0.2, 0.55))
	var lok := track.can_place(_turn_pair[0]) == ""
	var rok := track.can_place(_turn_pair[1]) == ""
	cursor_left.visible = lok
	cursor_right.visible = rok
	var side_mat := _flat_mat(Color(0.75, 0.95, 0.75, 0.4))
	cursor_left.material_override = side_mat
	cursor_right.material_override = side_mat
	# Pfeil zeigt die Fahrtrichtung, liegt flach über dem Cursor
	var dv := CoasterTrack.dir_vec3(d)
	cursor_arrow.position = cursor_main.position + Vector3(0, 0.15, 0)
	cursor_arrow.basis = Basis.looking_at(Vector3.DOWN, dv)


func _on_tap(pos: Vector2) -> void:
	if riding:
		return
	var cam := rig.cam
	var o := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	if absf(dir.y) < 0.0001:
		return
	var plane_y := track.cursor_h * CoasterTrack.LEVEL
	var t := (plane_y - o.y) / dir.y
	if t < 0:
		return
	var hit := o + dir * t
	var cell := Vector2i(floori(hit.x / CoasterTrack.TILE), floori(hit.z / CoasterTrack.TILE))
	var c := track.cursor_cell
	var d := track.cursor_dir
	if track.closed:
		_show_toast("Strecke ist geschlossen – FAHREN oder Zurück")
		sfx.play("error", -4.0)
	elif cell == c or cell == c + CoasterTrack.DIRS[d]:
		_build(_last_forward)
	elif cell == c + CoasterTrack.DIRS[(d + 3) % 4]:
		_build(_turn_pair[0])
	elif cell == c + CoasterTrack.DIRS[(d + 1) % 4]:
		_build(_turn_pair[1])


# --------------------------------------------------------------- Eingabe ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_over_ui(event.position) or joystick.owns_touch(event.index):
				return
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_tap_index = event.index
				_tap_start = event.position
				_tap_time = Time.get_ticks_msec()
				_tap_valid = true
			else:
				_tap_valid = false
				_pinch_dist = _pinch_distance()
		else:
			if not _touches.has(event.index):
				return
			_touches.erase(event.index)
			if _tap_valid and event.index == _tap_index:
				if event.position.distance_to(_tap_start) < TAP_MAX_MOVE and Time.get_ticks_msec() - _tap_time < TAP_MAX_MS:
					_on_tap(event.position)
			if event.index == _tap_index:
				_tap_valid = false
			_pinch_dist = _pinch_distance() if _touches.size() >= 2 else 0.0
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index):
			return
		_touches[event.index] = event.position
		if _touches.size() == 1:
			if _tap_valid and event.position.distance_to(_tap_start) >= TAP_MAX_MOVE:
				_tap_valid = false
			if not _tap_valid:
				_drag(event.relative)
		else:
			var dist := _pinch_distance()
			if _pinch_dist > 0.0 and dist > 0.0 and not riding:
				rig.zoom_by(_pinch_dist / dist)
			_pinch_dist = dist
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed and not riding:
					rig.zoom_by(0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed and not riding:
					rig.zoom_by(1.1)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_mouse_left = true
					_tap_start = event.position
					_tap_time = Time.get_ticks_msec()
					_tap_valid = true
				elif _mouse_left:
					_mouse_left = false
					if _tap_valid and event.position.distance_to(_tap_start) < TAP_MAX_MOVE:
						_on_tap(event.position)
					_tap_valid = false
			MOUSE_BUTTON_RIGHT:
				_mouse_right = event.pressed
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _mouse_left:
			if _tap_valid and event.position.distance_to(_tap_start) >= TAP_MAX_MOVE:
				_tap_valid = false
			if not _tap_valid:
				_drag(event.relative)
		elif _mouse_right and not riding:
			rig.rotate_view(-event.relative.x * 0.3, -event.relative.y * 0.2)


func _drag(rel: Vector2) -> void:
	if riding:
		_look.x = clampf(_look.x - rel.x * 0.25, -150, 150)
		_look.y = clampf(_look.y - rel.y * 0.2, -70, 60)
	else:
		rig.pan(rel)


func _pinch_distance() -> float:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1])


# ----------------------------------------------------------------- Fahrt ---

func _start_ride() -> void:
	if riding:
		return
	if track.pieces.size() <= CoasterTrack.STATION_LEN:
		_show_toast("Baue zuerst ein paar Streckenteile")
		return
	riding = true
	ride_s = track.station_s()
	ride_v = 2.0
	ride_max_v = 0.0
	ride_laps = 0
	_look = Vector2.ZERO
	_ride_end_timer = -1.0
	_loop_warned = false
	_ride_piece = -1
	build_bar.visible = false
	action_bar.visible = false
	ride_bar.visible = true
	status_label.visible = false
	speed_label.visible = true
	cursor_root.visible = false
	_update_ride_cam()
	ride_cam.make_current()
	sfx.play("bell", -3.0, 1.0, 0.0)
	sfx.start_ride()
	ride_started.emit()
	env.fog_enabled = true
	_update_help()
	if not track.closed:
		_show_toast("Strecke offen: Fahrt endet am letzten Teil")


func _stop_ride() -> void:
	if not riding:
		return
	riding = false
	build_bar.visible = true
	action_bar.visible = true
	ride_bar.visible = false
	status_label.visible = true
	speed_label.visible = false
	rig.make_current()
	sfx.stop_ride()
	sfx.play("click")
	ride_stopped.emit()
	env.fog_enabled = false
	_place_cart(track.station_s())
	_update_cursor()
	_update_help()
	_show_toast("Höchstgeschwindigkeit: %d km/h" % int(ride_max_v * 3.6))


func _toggle_view() -> void:
	sfx.play("click")
	view_mode = (view_mode + 1) % VIEW_NAMES.size()
	_show_toast(VIEW_NAMES[view_mode], 1.5)
	_chase_eye = Vector3.INF
	_update_ride_cam()


func _update_ride_cam(delta := 0.0) -> void:
	if view_mode == 2 and riding:
		# Verfolgerkamera mit Welt-Oben, weich nachgeführt – bleibt auch im Looping außerhalb
		var smp := track.sample(ride_s)
		var piece: Dictionary = track.pieces[smp.piece]
		var fwd: Vector3 = smp.tangent
		fwd.y = 0.0
		if piece.type == P.LOOP or fwd.length() < 0.3:
			fwd = CoasterTrack.dir_vec3(piece.dir)
		fwd = fwd.normalized()
		var mid := track.sample(ride_s - CoasterTrain.CAR_SPACING)
		var target: Vector3 = mid.pos + Vector3.UP * 1.0
		var eye: Vector3 = smp.pos - fwd * 13.0 + Vector3.UP * 5.0
		if piece.type == P.LOOP:
			eye.y = maxf(eye.y, piece.h * CoasterTrack.LEVEL + CoasterTrack.LOOP_RADIUS + 2.0)
		if delta <= 0.0 or _chase_eye == Vector3.INF:
			_chase_eye = eye
		else:
			_chase_eye = _chase_eye.lerp(eye, 1.0 - exp(-4.0 * delta))
		var xf := Transform3D(Basis.IDENTITY, _chase_eye).looking_at(target, Vector3.UP)
		xf.basis = xf.basis * Basis.from_euler(Vector3(deg_to_rad(_look.y), deg_to_rad(_look.x), 0))
		ride_cam.global_transform = xf
		train.hide_rider_at(-1, 0, 0)
		return
	# Ego-Sicht: Kamera sitzt auf dem linken Platz der ersten Reihe (Wagen 1 oder 2)
	var car := 0 if view_mode == 0 else 1
	train.hide_rider_at(car, 0, 0)
	var eye := train.eye_transform(car, 0, 0)
	eye.basis = eye.basis * Basis.from_euler(Vector3(deg_to_rad(-6.0 + _look.y), deg_to_rad(_look.x), 0))
	ride_cam.global_transform = eye


func _physics_ride(dt: float) -> void:
	var steps := 4
	var h := dt / steps
	for _i in steps:
		var smp := track.sample(ride_s)
		var tan: Vector3 = smp.tangent
		var piece: Dictionary = track.pieces[smp.piece]
		var a := -G * train.mean_slope(track, ride_s)   # Hangabtrieb, gemittelt über den Zug
		a -= 0.004 * ride_v * ride_v + 0.08         # Luftwiderstand + Rollreibung
		ride_v += a * h
		match piece.type:
			P.BOOSTER:
				if smp.piece != _ride_piece and not in_title:
					sfx.play("boost", 0.0, 1.0, 0.03)
				ride_v = move_toward(ride_v, maxf(ride_v, 22.0), 30.0 * h)  # Abschuss (~3 g) bis 80 km/h
			P.BRAKE:
				if smp.piece != _ride_piece and ride_v > 8.0 and not in_title:
					sfx.play("brake", -2.0)
				if ride_v > 6.0:
					ride_v = move_toward(ride_v, 6.0, 14.0 * h)
			P.SPLASH:
				if smp.piece != _ride_piece and not in_title:
					_splash()
				ride_v = move_toward(ride_v, minf(ride_v, 5.0), 16.0 * h)
			P.STATION:
				ride_v = move_toward(ride_v, 4.0, 8.0 * h)  # Bremse / Antrieb
			P.LOOP:
				# Für den Looping braucht es bei der Einfahrt etwa v² ≥ 5·g·r
				if smp.piece != _ride_piece:
					loop_entry_v = ride_v
					if not _loop_warned and ride_v * ride_v < 5.0 * G * CoasterTrack.LOOP_RADIUS * 0.8:
						_loop_warned = true
						_show_toast("Zu langsam für den Looping – mehr Höhe davor bauen!")
		if train.any_on(track, ride_s, [P.UP, P.STEEP_UP]):
			ride_v = maxf(ride_v, 3.0)             # Kettenlift zieht den ganzen Zug
		ride_v = maxf(ride_v, 1.0)                  # Antriebsreifen verhindern Stillstand
		if piece.type == P.STATION and _ride_piece >= 0 and not in_title \
				and track.pieces[_ride_piece].type != P.STATION and ride_v > 5.0:
			sfx.play("brake", -2.0)
		_ride_piece = smp.piece
		var prev_s := ride_s
		ride_s += ride_v * h
		if track.closed and fposmod(prev_s, track.length) > fposmod(ride_s, track.length):
			ride_laps += 1
	ride_max_v = maxf(ride_max_v, ride_v)
	if not track.closed and ride_s >= track.length - 0.5:
		ride_s = track.length - 0.5
		ride_v = 0.0
		if _ride_end_timer < 0.0:
			_ride_end_timer = 2.0
			_show_toast("Ende der Strecke erreicht")


## Wasserfontäne + Sound beim Durchfahren des Splash-Teils.
func _splash() -> void:
	sfx.play("splash", 0.0, 1.0, 0.05)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 90
	p.lifetime = 1.2
	p.explosiveness = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	var drop := SphereMesh.new()
	drop.radius = 0.5
	drop.height = 1.0
	drop.radial_segments = 6
	drop.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.85, 1.0, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = m
	p.mesh = drop
	add_child(p)
	p.global_position = cart.global_position + Vector3.UP * 0.5
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _place_cart(s: float) -> void:
	if train == null or track == null:
		return
	train.place(track, s)


func _update_fps(delta: float) -> void:
	_frame_ms_max = maxf(_frame_ms_max, delta * 1000.0)
	_fps_timer -= delta
	if _fps_timer > 0.0:
		return
	_fps_timer = 0.5
	var fps := Engine.get_frames_per_second()
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	fps_label.text = "%d FPS · max %.0f ms · %d Draw Calls" % [fps, _frame_ms_max, draws]
	fps_label.add_theme_color_override("font_color",
		Color(0.6, 1, 0.6) if fps >= 55 else (Color(1, 0.9, 0.4) if fps >= 30 else Color(1, 0.5, 0.45)))
	_frame_ms_max = 0.0


func _process(delta: float) -> void:
	_update_fps(delta)
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			toast_label.visible = false

	if _autosave_timer > 0.0:
		_autosave_timer -= delta
		if _autosave_timer <= 0.0:
			_write_autosave()
	if in_title:
		# Attract-Modus: Wagen fährt, Kamera kreist langsam
		_physics_ride(delta)
		_place_cart(ride_s)
		_animate_riders(delta)
		rig.rotate_view(6.0 * delta, 0.0)
		return

	var j := joystick.output
	if riding:
		_physics_ride(delta)
		_place_cart(ride_s)
		if j != Vector2.ZERO:
			_look.x = clampf(_look.x - j.x * 120.0 * delta, -150, 150)
			_look.y = clampf(_look.y - j.y * 80.0 * delta, -70, 60)
		elif _touches.is_empty() and not _mouse_left:
			_look = _look.move_toward(Vector2.ZERO, 60.0 * delta)
		_animate_riders(delta)
		_update_ride_cam(delta)
		var on_chain: bool = ride_v < 3.3 and train.any_on(track, ride_s, [P.UP, P.STEEP_UP])
		sfx.update_ride(ride_v, on_chain, delta)
		speed_label.text = "%d km/h\nRunden: %d" % [int(ride_v * 3.6), ride_laps]
		if _ride_end_timer >= 0.0:
			_ride_end_timer -= delta
			if _ride_end_timer < 0.0:
				_stop_ride()
	else:
		train.animate(delta, 0.0, false)
		if j != Vector2.ZERO:
			rig.rotate_view(-j.x * 90.0 * delta, -j.y * 45.0 * delta)


func _animate_riders(delta: float) -> void:
	var front := track.sample(ride_s)
	train.animate(delta, ride_v, front.tangent.y < -0.35)

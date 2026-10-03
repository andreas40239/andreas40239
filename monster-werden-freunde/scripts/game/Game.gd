class_name Game
extends Node2D
## Level-Laufzeit (GDD Kap. 2, 8): verbindet Karte, Wellen, Bauen, HUD und Tutorial.
## Sieg/Niederlage hängen nur von Chaos-Punkten ab - niemals von Schaden oder Toden.

signal level_completed(stars: int, chaos: int)

enum Phase { PREP, RUNNING, BREAK, ENDED }

const MONSTER_SCENE := preload("res://scenes/monster/Monster.tscn")
const REF_SIZE := Vector2(1920, 1080)
const SPOT_TAP_RADIUS := 74.0
const STATION_TAP_RADIUS := 72.0
const MONSTER_TAP_RADIUS := 62.0

@onready var world: Node2D = $World
@onready var map_view: MapView = $World/Map
@onready var spots_root: Node2D = $World/Spots
@onready var range_indicator: RangeIndicator = $World/Range
@onready var field: Node2D = $World/Field
@onready var path2d: Path2D = $World/Field/Path2D
@onready var stations_root: Node2D = $World/Field/Stations
@onready var projectiles_root: Node2D = $World/Field/Projectiles
@onready var fx_root: Node2D = $World/Field/Fx
@onready var ui_fx_root: Node2D = $World/UiFx
@onready var wave_manager: WaveManager = $WaveManager
@onready var build_manager: BuildManager = $BuildManager
@onready var hud: HUD = $HUD

var level: LevelData
var phase: Phase = Phase.PREP
var monsters_alive: int = 0
var friends_count: int = 0
var break_left: float = 0.0
var selected_spot: BuildSpot
var selected_station: Station
var fast_mode := false
## Für Tests/Simulation: keine Intro-Karte, kein Tutorial.
var skip_intro := false

var _all_spawned := false
var _menu_open := false
var _paused_before_menu := false
var _intro_open := false
var _tutorial_index := -1
var _tutorial_time := 0.0
var _weak_hint_cooldown := 0.0


func _ready() -> void:
	level = DataRegistry.level(GameState.current_level)
	GameState.reset_for_level(level)
	_layout_world()
	var smooth := _build_path()
	map_view.setup(smooth, level.build_spots, level.decor_seed)
	build_manager.setup(spots_root, stations_root, projectiles_root, fx_root)
	build_manager.create_spots(level.build_spots)
	wave_manager.setup(level.waves, _spawn_monster)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_spawned)
	hud.setup(level, SaveManager.is_speed_unlocked())
	hud.set_wave(0, level.waves.size())
	hud.set_start_state(&"start")
	hud.card_pressed.connect(_on_card_pressed)
	hud.start_pressed.connect(_on_start_pressed)
	hud.pause_pressed.connect(toggle_pause)
	hud.speed_pressed.connect(toggle_speed)
	hud.menu_opened.connect(_on_menu_opened)
	hud.menu_closed.connect(_on_menu_closed)
	hud.upgrade_pressed.connect(_on_upgrade_pressed)
	hud.sell_pressed.connect(_on_sell_pressed)
	hud.station_panel_closed.connect(_deselect_all)
	hud.retry_pressed.connect(func() -> void: GameState.goto_screen(&"game", {"level": level.number}))
	hud.map_pressed.connect(func() -> void: GameState.goto_screen(&"level_select"))
	hud.next_pressed.connect(func() -> void: GameState.goto_screen(&"game", {"level": level.number + 1}))
	hud.intro_closed.connect(_on_intro_closed)
	if not skip_intro and not level.new_monster_ids.is_empty():
		_intro_open = true
		hud.show_intro(level.new_monster_ids, level.available_station_ids)
	elif not skip_intro:
		_start_tutorial()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if get_tree():
		get_tree().paused = false


# --- Aufbau ----------------------------------------------------------------------

func _layout_world() -> void:
	var vp := get_viewport_rect().size
	world.position = ((vp - REF_SIZE) * 0.5).floor()


## Baut die Kurve des Pfads mit abgerundeten Ecken; verlängert den Start bis zum Bildschirmrand.
func _build_path() -> PackedVector2Array:
	var pts := level.path_points.duplicate()
	pts[0] = Vector2(-maxf(0.0, world.position.x) - 90.0, pts[0].y)
	var curve := Curve2D.new()
	curve.bake_interval = 6.0
	curve.add_point(pts[0])
	for i in range(1, pts.size() - 1):
		var p := pts[i]
		var d_in := (p - pts[i - 1])
		var d_out := (pts[i + 1] - p)
		var r := minf(70.0, minf(d_in.length(), d_out.length()) * 0.45)
		var a := p - d_in.normalized() * r
		var b := p + d_out.normalized() * r
		curve.add_point(a, Vector2.ZERO, d_in.normalized() * r * 0.55)
		curve.add_point(b, -d_out.normalized() * r * 0.55, Vector2.ZERO)
	curve.add_point(pts[pts.size() - 1])
	path2d.curve = curve
	return curve.get_baked_points()


func _spawn_monster(id: StringName) -> Monster:
	var data := DataRegistry.monster(id)
	var m: Monster = MONSTER_SCENE.instantiate()
	m.setup(data)
	path2d.add_child(m)
	m.monster_became_friend.connect(_on_monster_friend)
	m.monster_arrived.connect(_on_monster_arrived)
	m.weak_help.connect(_on_weak_help)
	monsters_alive += 1
	return m


# --- Ablauf ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if phase == Phase.ENDED or get_tree().paused:
		return
	_weak_hint_cooldown -= delta
	if phase == Phase.BREAK:
		break_left -= delta
		hud.set_start_state(&"countdown", break_left, level.early_start)
		if break_left <= 0.0:
			start_next_wave()
	_tutorial_process(delta)


func _on_start_pressed() -> void:
	if phase == Phase.PREP or (phase == Phase.BREAK and level.early_start):
		start_next_wave()


func start_next_wave() -> void:
	if phase == Phase.ENDED or not wave_manager.has_next_wave():
		return
	phase = Phase.RUNNING
	hud.set_start_state(&"hidden")
	wave_manager.start_next_wave()


func _on_wave_started(index: int, total: int) -> void:
	hud.set_wave(index, total)
	hud.wave_banner("Welle %d" % index)
	AudioManager.play(&"wave", 0.0)
	_tutorial_event("wave_started")


func _on_wave_spawned(_index: int) -> void:
	if wave_manager.has_next_wave():
		phase = Phase.BREAK
		break_left = level.wave_break
		hud.set_start_state(&"countdown", break_left, level.early_start)
	else:
		_all_spawned = true
		_check_level_done()


func _on_monster_friend(m: Monster) -> void:
	friends_count += 1
	Fx.spawn(fx_root, Fx.Kind.HEARTS, m.position + Vector2(0, -50))
	AudioManager.play(&"friend", 0.08, -3.0)
	_tutorial_event("friend")


## GDD 2.1 / AT-04 / AT-05: Freunde bringen Sonnenpunkte, wilde Monster nur Chaos.
func _on_monster_arrived(m: Monster, was_friend: bool) -> void:
	monsters_alive -= 1
	var pos := m.position + Vector2(40, -90)
	if was_friend:
		GameState.earn(m.data.reward)
		Fx.spawn(ui_fx_root, Fx.Kind.TEXT, pos, {"text": "+%d" % m.data.reward, "icon": &"sun", "color": Color("ffe066")})
		map_view.village.cheer()
		AudioManager.play(&"arrive", 0.05, -2.0)
	else:
		GameState.add_chaos(m.data.chaos_value)
		Fx.spawn(ui_fx_root, Fx.Kind.POOF, m.position + Vector2(60, -40))
		Fx.spawn(ui_fx_root, Fx.Kind.TEXT, pos, {"text": "Trubel!", "color": Color("e0c3ff")})
		map_view.village.surprise()
		AudioManager.play(&"chaos", 0.05)
		if GameState.is_chaos_full():
			end_level(false)
			return
	_check_level_done()


func _check_level_done() -> void:
	if phase != Phase.ENDED and _all_spawned and monsters_alive <= 0:
		end_level(true)


func end_level(won: bool) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	Engine.time_scale = 1.0
	get_tree().paused = false
	field.process_mode = Node.PROCESS_MODE_DISABLED
	wave_manager.process_mode = Node.PROCESS_MODE_DISABLED
	_deselect_all()
	var stars: int = level.stars_for_chaos(GameState.chaos) if won else 0
	if won:
		SaveManager.record_result(level.number, stars)
		Fx.spawn(ui_fx_root, Fx.Kind.CONFETTI, Vector2(960, 0))
	level_completed.emit(stars, GameState.chaos)
	hud.show_result(won, stars, friends_count, level.total_monsters(), won and level.number < DataRegistry.level_count())
	AudioManager.play(&"win" if won else &"lose", 0.0)


# --- Eingabe ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.ENDED or _menu_open or _intro_open or hud.is_modal_open():
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * mb.position
		handle_tap(p)
		get_viewport().set_input_as_handled()


func handle_tap(p: Vector2) -> void:
	var st := build_manager.station_at(p, STATION_TAP_RADIUS)
	if st:
		_select_station(st)
		return
	var spot := build_manager.free_spot_at(p, SPOT_TAP_RADIUS)
	if spot:
		select_spot(spot)
		return
	var m := _monster_at(p)
	if m:
		_show_monster_info(m)
		return
	_deselect_all()


func _monster_at(p: Vector2) -> Monster:
	var best: Monster = null
	var best_d := MONSTER_TAP_RADIUS
	for node in get_tree().get_nodes_in_group(&"monsters"):
		var m := node as Monster
		var d := (m.position + Vector2(0, -40)).distance_to(p)
		if d < best_d:
			best = m
			best_d = d
	return best


func _show_monster_info(m: Monster) -> void:
	var txt := "%s %s" % [m.data.display_name, Needs.label_for(m.data.need_type)]
	Fx.spawn(ui_fx_root, Fx.Kind.TEXT, m.position + Vector2(0, -150), {"text": txt, "size": 32, "life": 1.8,
		"icon": Needs.icon_for(m.data.need_type)})
	AudioManager.play(&"need_info")


func select_spot(spot: BuildSpot) -> void:
	if selected_spot == spot:
		_deselect_all()
		return
	_deselect_all()
	selected_spot = spot
	spot.selected = true
	hud.set_cards_active(true)
	AudioManager.play(&"tap")
	_tutorial_event("spot_selected")


func _select_station(st: Station) -> void:
	if selected_station == st:
		_deselect_all()
		return
	_deselect_all()
	selected_station = st
	st.selected = true
	range_indicator.show_range(st.position, st.get_range(), st.data.color)
	hud.show_station_panel(st)
	AudioManager.play(&"tap")
	_tutorial_event("station_selected")


func _deselect_all() -> void:
	if selected_spot and is_instance_valid(selected_spot):
		selected_spot.selected = false
	selected_spot = null
	if selected_station and is_instance_valid(selected_station):
		selected_station.selected = false
	selected_station = null
	hud.set_cards_active(false)
	hud.hide_station_panel()
	range_indicator.hide_range()


func _on_card_pressed(id: StringName) -> void:
	var data := DataRegistry.station(id)
	if selected_spot == null:
		hud.toast("Tippe zuerst auf ein  +  auf der Wiese.")
		build_manager.pulse_free_spots()
		AudioManager.play(&"deny")
		return
	if not GameState.can_afford(data.cost):
		hud.toast("Dafür fehlen noch Sonnenpunkte.\nHilf Monstern, dann bekommst du mehr!", 3.2)
		hud.shake_card(id)
		AudioManager.play(&"deny")
		return
	build_station(selected_spot, id)


## Baut eine Station (auch von Tests genutzt). Gibt die Station oder null zurück.
func build_station(spot: BuildSpot, id: StringName) -> Station:
	var st := build_manager.build(spot, DataRegistry.station(id))
	if st == null:
		return null
	_deselect_all()
	range_indicator.show_range(st.position, st.get_range(), st.data.color, 2.5)
	Fx.spawn(ui_fx_root, Fx.Kind.SPARKLE, st.position + Vector2(0, -50))
	AudioManager.play(&"build", 0.0)
	_tutorial_event("station_built:%s" % id)
	return st


func _on_upgrade_pressed(path: StringName) -> void:
	var st := selected_station
	if st == null:
		return
	if not GameState.can_afford(st.data.upgrade_cost):
		hud.toast("Dafür fehlen noch Sonnenpunkte.", 2.4)
		AudioManager.play(&"deny")
		return
	if build_manager.upgrade(st, path):
		range_indicator.show_range(st.position, st.get_range(), st.data.color)
		hud.update_station_panel()
		Fx.spawn(ui_fx_root, Fx.Kind.SPARKLE, st.position + Vector2(0, -60))
		AudioManager.play(&"upgrade", 0.0)
		_tutorial_event("station_upgraded")


func _on_sell_pressed() -> void:
	var st := selected_station
	if st == null:
		return
	var pos := st.position + Vector2(0, -90)
	var refund := build_manager.sell(st)
	selected_station = null
	_deselect_all()
	Fx.spawn(ui_fx_root, Fx.Kind.TEXT, pos, {"text": "+%d" % refund, "icon": &"sun", "color": Color("ffe066")})
	AudioManager.play(&"sell", 0.0)
	_tutorial_event("station_sold")


func _on_weak_help(m: Monster) -> void:
	if _weak_hint_cooldown > 0.0:
		return
	_weak_hint_cooldown = 7.0
	Fx.spawn(ui_fx_root, Fx.Kind.TEXT, m.position + Vector2(0, -150),
		{"text": "Das hilft %s nur ein bisschen." % m.data.display_name, "size": 30, "life": 2.2})


# --- Pause / Tempo / Menü --------------------------------------------------------

func toggle_pause() -> void:
	if phase == Phase.ENDED:
		return
	get_tree().paused = not get_tree().paused
	hud.set_paused(get_tree().paused)


func toggle_speed() -> void:
	fast_mode = not fast_mode
	Engine.time_scale = 2.0 if fast_mode else 1.0
	hud.set_speed(fast_mode)


func _on_menu_opened() -> void:
	_menu_open = true
	_paused_before_menu = get_tree().paused
	get_tree().paused = true


func _on_menu_closed() -> void:
	_menu_open = false
	get_tree().paused = _paused_before_menu
	hud.set_paused(_paused_before_menu)


## Android-Zurück-Taste: Menü öffnen bzw. schließen.
func go_back() -> void:
	if hud.is_result_shown():
		GameState.goto_screen(&"level_select")
	elif not hud.close_menu_if_open():
		hud.open_menu()


# --- Tutorial (GDD 5.2) ----------------------------------------------------------

func _on_intro_closed() -> void:
	_intro_open = false
	_start_tutorial()


func _start_tutorial() -> void:
	_tutorial_index = -1
	_advance_tutorial()


func _advance_tutorial() -> void:
	_tutorial_index += 1
	_tutorial_time = 0.0
	if _tutorial_index >= level.tutorial_steps.size():
		hud.hide_tutorial()
		return
	var step := level.tutorial_steps[_tutorial_index]
	if step.trigger == "wave_started" and phase != Phase.PREP:
		_advance_tutorial()
		return
	hud.show_tutorial(step.text, _highlight_provider(step.highlight))


func _tutorial_event(ev: String) -> void:
	if _tutorial_index < 0 or _tutorial_index >= level.tutorial_steps.size():
		return
	var trigger := level.tutorial_steps[_tutorial_index].trigger
	if ev == trigger or ev.begins_with(trigger + ":"):
		_advance_tutorial()


func _tutorial_process(delta: float) -> void:
	if _tutorial_index < 0 or _tutorial_index >= level.tutorial_steps.size():
		return
	var trigger := level.tutorial_steps[_tutorial_index].trigger
	if trigger.begins_with("time:"):
		_tutorial_time += delta / maxf(Engine.time_scale, 1.0)
		if _tutorial_time >= trigger.substr(5).to_float():
			_advance_tutorial()


func _highlight_provider(h: String) -> Callable:
	if h.begins_with("spot:"):
		var idx := h.substr(5).to_int()
		return func() -> Vector2:
			if selected_spot:
				return Vector2.INF
			var s := build_manager.first_free_spot(idx)
			return _to_canvas(s.position + Vector2(0, -8)) if s else Vector2.INF
	if h.begins_with("card:"):
		var id := StringName(h.substr(5))
		return func() -> Vector2: return hud.get_card_center(id) if selected_spot else Vector2.INF
	match h:
		"start":
			return func() -> Vector2: return hud.get_start_center()
		"speed":
			return func() -> Vector2: return hud.get_speed_center()
		"upgrade":
			return func() -> Vector2: return hud.get_upgrade_center()
		"station":
			return func() -> Vector2:
				if selected_station or build_manager.stations.is_empty():
					return Vector2.INF
				return _to_canvas(build_manager.stations[0].position + Vector2(0, -50))
	return Callable()


func _to_canvas(p: Vector2) -> Vector2:
	return world.get_global_transform_with_canvas() * p

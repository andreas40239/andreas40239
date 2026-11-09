extends Node3D
## Spielsteuerung: Eingabe, Werkzeuge, Jobs, Wirtschaft, Portale, Heldenwellen, Zauber, Optionen.

const R = Defs.R
const T = Defs.T
const INVALID := Vector2i(-1, -1)
const RigScript := preload("res://scripts/camera_rig.gd")
const HudScript := preload("res://scripts/hud.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const SETTINGS_PATH := "user://settings.cfg"

var world: World
var rig
var hud
var env: Environment
var sun: DirectionalLight3D
var units: Array = []
var units_root: Node3D
var fx_root: Node3D

var heart_hp := Defs.HEART_HP
var heart_gold := Defs.START_GOLD
var mana := Defs.START_MANA
var game_time := 0.0
var state := "menu"
var tool := "select"
var selected: Array = []
var dragging := false
var drag_start := Vector2.ZERO
var drag_tile := INVALID
var hover_tile := INVALID
var wave := 0
var wave_timer := Defs.FIRST_WAVE
var wave_warned := false
var hero_queue: Array = []
var hero_spawn_t := 0.0
var payday_t := 180.0
var portal_t := 20.0
var jobs_t := 0.0
var claim_cands: Array = []
var fort_cands: Array = []
var reserved := {}
var hud_t := 0.0
var mini_t := 0.0
var msg_cool := {}
var heart_alarm_t := 0.0
var speed_levels := [1.0, 2.0, 3.0]
var speed_i := 0
var stats := {"killed": 0, "lost": 0, "dug": 0, "gold_mined": 0}
var settings := {"master": 0.8, "music": 0.6, "sfx": 0.8, "quality": 2, "fullscreen": false, "edge": true}
var autotest := false
var _at_t := 0.0
var _at_step := 0


# ================================================================ Start
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	autotest = "--autotest" in OS.get_cmdline_user_args()
	_load_settings()
	_setup_env()
	world = World.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.generate(randi())
	world.build_visuals()
	units_root = Node3D.new()
	units_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(units_root)
	fx_root = Node3D.new()
	fx_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fx_root)
	rig = RigScript.new()
	add_child(rig)
	rig.bounds = Rect2(0, 0, Defs.W * Defs.TILE, Defs.H * Defs.TILE)
	rig.jump_to(world.tile_center(world.heart_tile) + Vector3(0, 0, 3), true)
	hud = HudScript.new()
	add_child(hud)
	hud.setup(self)
	for i in 4:
		spawn_unit("imp", world.free_tile_near(world.heart_tile, 3))
	_refresh_jobs()
	apply_settings()
	set_tool("select")
	var showcase := ""
	var menushot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--showcase="):
			showcase = a.substr(11)
		elif a.begins_with("--menushot="):
			menushot = a.substr(11)
	if autotest:
		start_game()
		Engine.time_scale = 8.0
	elif showcase != "":
		_showcase(showcase)
	else:
		state = "menu"
		get_tree().paused = true
		rig.attract = true
		rig.input_enabled = false
		hud.show_menu("main")
		if menushot != "":
			await get_tree().create_timer(4.0, true).timeout
			get_viewport().get_texture().get_image().save_png(menushot)
			get_tree().quit()


func start_game() -> void:
	state = "play"
	get_tree().paused = false
	rig.attract = false
	rig.input_enabled = true
	hud.show_menu("")
	rig.jump_to(world.tile_center(world.heart_tile) + Vector3(0, 0, 3))
	message("Willkommen, Tiefenherr! Markiere Felsen zum Graben (Linksklick ziehen).", Color(1.0, 0.85, 0.45))
	message("Beanspruche das lila Portal und baue Hort + Pilzfarm.", Color(0.8, 0.7, 1.0))


func restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


func open_pause_menu() -> void:
	if state != "play":
		return
	get_tree().paused = true
	rig.input_enabled = false
	hud.show_menu("pause")


func close_menu() -> void:
	hud.show_menu("")
	get_tree().paused = false
	rig.input_enabled = true


func _setup_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.006, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.36, 0.5)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.03, 0.06)
	env.fog_density = 0.004
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.7, 0.6, 0.65)
	env.volumetric_fog_length = 80.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.1
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 35, 0)
	sun.light_color = Color(0.55, 0.62, 0.9)
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


# ================================================================ Optionen
func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cf.get_value("settings", k, settings[k])


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("settings", k, settings[k])
	cf.save(SETTINGS_PATH)


func apply_settings() -> void:
	Sfx.set_volume("Master", settings["master"])
	Sfx.set_volume("Music", settings["music"])
	Sfx.set_volume("SFX", settings["sfx"])
	if rig:
		rig.edge_scroll = settings["edge"]
	if not autotest and DisplayServer.get_name() != "headless":
		var fs: bool = settings["fullscreen"]
		var cur := DisplayServer.window_get_mode()
		var is_fs := cur == DisplayServer.WINDOW_MODE_FULLSCREEN or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if fs != is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
	var q: int = settings["quality"]
	var vp := get_viewport()
	env.ssao_enabled = q >= 1
	env.ssil_enabled = q >= 3
	env.glow_enabled = true
	env.volumetric_fog_enabled = q >= 2
	env.sdfgi_enabled = false
	sun.shadow_enabled = q >= 1
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q <= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = q >= 3
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096, 4096][q], true)


# ================================================================ Hauptschleife
func _process(delta: float) -> void:
	_update_hover()
	hud_t -= delta
	if hud_t <= 0.0:
		hud_t = 0.2
		hud.update_stats()
		hud.update_info(_valid_selection())
	mini_t -= delta
	if mini_t <= 0.0:
		mini_t = 0.4
		hud.update_minimap()
	if autotest:
		_autotest(delta)
	if get_tree().paused or state != "play":
		return
	game_time += delta
	mana = minf(mana + delta * (1.0 + 0.03 * world.claimed_count), Defs.MANA_MAX)
	heart_hp = minf(Defs.HEART_HP, heart_hp + delta * 1.5)
	heart_alarm_t -= delta
	for k in msg_cool.keys():
		msg_cool[k] -= delta
	jobs_t -= delta
	if jobs_t <= 0.0:
		jobs_t = 0.6
		_refresh_jobs()
	portal_t -= delta
	if portal_t <= 0.0:
		portal_t = randf_range(22.0, 38.0)
		_try_portal_spawn()
	payday_t -= delta
	if payday_t <= 0.0:
		payday_t = 180.0
		_payday()
	_update_waves(delta)
	_separate(delta)
	Sfx.battle_target = 1.0 if hero_count() > 0 else 0.0


func _valid_selection() -> Array:
	var out := []
	for u in selected:
		if is_instance_valid(u) and not u.dead:
			out.append(u)
	selected = out
	return out


func message(txt: String, col := Color(0.95, 0.9, 0.8)) -> void:
	if autotest:
		print("[MSG] ", txt)
	hud.message(txt, col)


func message_once(key: String, txt: String, col := Color(0.95, 0.9, 0.8), cool := 25.0) -> void:
	if msg_cool.get(key, 0.0) > 0.0:
		return
	msg_cool[key] = cool
	message(txt, col)


# ================================================================ Einheiten
func spawn_unit(kind: String, t: Vector2i, lvl := 1) -> Unit:
	if t == INVALID:
		return null
	var u := Unit.new()
	units_root.add_child(u)
	u.setup(self, kind, t, lvl)
	units.append(u)
	return u


func count_units(kind: String) -> int:
	var c := 0
	for u in units:
		if u.kind == kind and not u.dead:
			c += 1
	return c


func creature_count() -> int:
	var c := 0
	for u in units:
		if u.team == 1 and u.kind != "imp" and not u.dead:
			c += 1
	return c


func hero_count() -> int:
	var c := len(hero_queue)
	for u in units:
		if u.team == 2 and not u.dead:
			c += 1
	return c


func find_enemy(u: Unit, radius: float) -> Unit:
	var best: Unit = null
	var bd := radius * Defs.TILE
	for o in units:
		if o.team == u.team or o.dead:
			continue
		var d: float = Vector2(o.position.x - u.position.x, o.position.z - u.position.z).length()
		if d < bd:
			bd = d
			best = o
	return best


func on_unit_died(u: Unit, _killer: Unit) -> void:
	units.erase(u)
	selected.erase(u)
	release_job(u)
	if u.team == 2:
		stats["killed"] += 1
		var bounty := 50 * u.level
		add_gold(bounty)
		message_once("bounty", "Held besiegt! +%d Gold Kopfgeld" % bounty, Color(1.0, 0.85, 0.4), 3.0)
	else:
		stats["lost"] += 1
		if u.kind != "imp":
			message("%s ist gefallen." % u.display_name(), Color(1.0, 0.5, 0.4))


func creature_left(u: Unit) -> void:
	if u.dead:
		return
	u.dead = true
	units.erase(u)
	selected.erase(u)
	world.burst(u.global_position + Vector3(0, 0.8, 0), Color(0.7, 0.35, 1.0), 20, 3.0, 0.8)
	u.queue_free()


func spawn_projectile(src: Unit, tgt: Unit, pos) -> void:
	var p := Node3D.new()
	p.set_script(ProjectileScript)
	fx_root.add_child(p)
	p.setup(self, src, tgt, pos, src.kind)


func hero_heal(h: Unit) -> void:
	for o in units:
		if o.team == 2 and not o.dead and o.hp < o.max_hp * 0.8 and h.dist_tiles(o) <= 4.5:
			o.heal(30.0 + 8.0 * h.level)
			world.burst(o.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.95, 0.6), 10, 2.0, 0.7)
			Sfx.play_at("heal", h.global_position, -8.0)
			return


func _separate(delta: float) -> void:
	var n := units.size()
	var k := minf(1.0, delta * 6.0)
	for a in n:
		var ua: Unit = units[a]
		for b in range(a + 1, n):
			var ub: Unit = units[b]
			var dx := ub.position.x - ua.position.x
			var dz := ub.position.z - ua.position.z
			var l2 := dx * dx + dz * dz
			if l2 < 0.64 and l2 > 0.0001:
				var l := sqrt(l2)
				var push := Vector3(dx / l, 0, dz / l) * (0.8 - l) * 0.5 * k
				ua.nudge(-push)
				ub.nudge(push)


func random_own_tile_near(t: Vector2i, r: int) -> Vector2i:
	for i in 14:
		var c := t + Vector2i(randi_range(-r, r), randi_range(-r, r))
		if world.is_own_floor(c):
			return c
	return INVALID


func random_room_tile(r: int, from: Vector2i) -> Vector2i:
	var tiles := world.room_tiles(r)
	if tiles.is_empty():
		return INVALID
	tiles.sort_custom(func(a, b): return (a - from).length_squared() < (b - from).length_squared())
	var n := mini(tiles.size(), 6)
	return tiles[randi() % n]


func get_lair_tile(u: Unit) -> Vector2i:
	if u.lair_idx >= 0 and world.room[u.lair_idx] == R.LAIR:
		return world.to_t(u.lair_idx)
	u.lair_idx = -1
	var used := {}
	for o in units:
		if o.lair_idx >= 0:
			used[o.lair_idx] = true
	var best := INVALID
	var bd := 1e9
	for t in world.room_tiles(R.LAIR):
		var i := world.idx(t)
		if used.has(i):
			continue
		var d := float((t - u.tile).length_squared())
		if d < bd:
			bd = d
			best = t
	if best != INVALID:
		u.lair_idx = world.idx(best)
	return best


func portal_exit_tile() -> Vector2i:
	for p in world.portals:
		if p["claimed"]:
			return world.free_tile_near(p["center"], 3)
	return INVALID


# ================================================================ Gold & Mana
func total_gold() -> int:
	var s := heart_gold
	for v in world.store.values():
		s += v
	return s


func gold_capacity() -> int:
	return Defs.HEART_CAP + Defs.TREASURY_CAP * world.room_count[R.TREASURY]


func add_gold(a: int) -> int:
	var room := gold_capacity() - total_gold()
	var add := clampi(a, 0, maxi(0, room))
	var rest := add
	var hc := mini(rest, Defs.HEART_CAP - heart_gold)
	if hc > 0:
		heart_gold += hc
		rest -= hc
	if rest > 0:
		for t in world.room_tiles(R.TREASURY):
			var i := world.idx(t)
			var cur: int = world.store.get(i, 0)
			var put := mini(rest, Defs.TREASURY_CAP - cur)
			if put > 0:
				world.store[i] = cur + put
				rest -= put
				world.refresh_tile(t)
			if rest <= 0:
				break
	return add - rest


func spend_gold(a: int) -> bool:
	if total_gold() < a:
		return false
	var rest := a
	for i in world.store.keys():
		var cur: int = world.store[i]
		var take := mini(cur, rest)
		world.store[i] = cur - take
		rest -= take
		world.refresh_tile(world.to_t(i))
		if rest <= 0:
			break
	heart_gold -= rest
	return true


func deposit_gold(imp: Unit, t: Vector2i) -> void:
	var amount := imp.carried
	var stored := 0
	var i := world.idx(t)
	if world.room[i] == R.TREASURY:
		var cur: int = world.store.get(i, 0)
		var put := mini(amount, Defs.TREASURY_CAP - cur)
		if put > 0:
			world.store[i] = cur + put
			stored += put
			world.refresh_tile(t)
	stored += add_gold(amount - stored)
	imp.carried = 0
	if stored > 0:
		Sfx.play_at("gold", imp.global_position, -2.0)
	if stored < amount:
		message_once("full", "Deine Lager sind voll! Baue eine größere Schatzkammer.", Color(1.0, 0.7, 0.3))


func imp_cost() -> int:
	return 60 + 20 * count_units("imp")


func _payday() -> void:
	var paid := 0
	var unpaid := 0
	for u in units:
		if u.team != 1 or u.kind == "imp" or u.dead:
			continue
		var w: int = u.wage()
		if spend_gold(w):
			paid += w
		else:
			u.unhappy += 0.45
			unpaid += 1
	if paid > 0 or unpaid > 0:
		Sfx.play("gold", -3.0)
		if unpaid > 0:
			message("Zahltag: %d Gold gezahlt – %d Kreaturen gingen leer aus!" % [paid, unpaid], Color(1.0, 0.5, 0.3))
		else:
			message("Zahltag: %d Gold an deine Kreaturen gezahlt." % paid, Color(1.0, 0.85, 0.4))


# ================================================================ Jobs der Wichtel
func _refresh_jobs() -> void:
	claim_cands.clear()
	fort_cands.clear()
	for y in range(1, Defs.H - 1):
		for x in range(1, Defs.W - 1):
			var i := y * Defs.W + x
			var ty := world.type[i]
			if ty == T.FLOOR and world.own[i] != 1:
				if _has_own_neighbor(Vector2i(x, y)):
					claim_cands.append(Vector2i(x, y))
			elif ty == T.ROCK and world.own[i] == 0 and not world.marked.has(i):
				if _has_own_neighbor(Vector2i(x, y)):
					fort_cands.append(Vector2i(x, y))


func _has_own_neighbor(t: Vector2i) -> bool:
	for nb in world.neighbors4(t):
		if world.is_own_floor(nb):
			return true
	return false


func get_imp_job(imp: Unit) -> Dictionary:
	if imp.carried >= Defs.IMP_CARRY or (imp.carried > 0 and world.marked.is_empty()):
		var d := _deposit_job(imp)
		if not d.is_empty():
			return d
	var order := ["dig", "claim", "fortify"] if (imp.uid % 3) != 0 else ["claim", "dig", "fortify"]
	for kind in order:
		var j := _find_job(imp, kind)
		if not j.is_empty():
			reserved[world.idx(j["tile"])] = imp
			return j
	if imp.carried > 0:
		return _deposit_job(imp)
	return {}


func _deposit_job(imp: Unit) -> Dictionary:
	var cands := []
	if heart_gold < Defs.HEART_CAP:
		cands.append_array(world.heart_ring())
	for t in world.room_tiles(R.TREASURY):
		if world.store.get(world.idx(t), 0) < Defs.TREASURY_CAP:
			cands.append(t)
	if cands.is_empty():
		cands = world.heart_ring()
	cands.sort_custom(func(a, b): return (a - imp.tile).length_squared() < (b - imp.tile).length_squared())
	for k in mini(5, cands.size()):
		var t: Vector2i = cands[k]
		if t == imp.tile or not world.find_path(imp.tile, t).is_empty():
			return {"type": "deposit", "tile": t, "stand": t}
	return {}


func _find_job(imp: Unit, kind: String) -> Dictionary:
	var cands: Array
	match kind:
		"dig":
			cands = []
			for i in world.marked.keys():
				cands.append(world.to_t(i))
		"claim":
			cands = claim_cands
		"fortify":
			cands = fort_cands
	if cands.is_empty():
		return {}
	var scored := []
	for t in cands:
		var i := world.idx(t)
		if reserved.has(i) and is_instance_valid(reserved[i]) and reserved[i] != imp:
			continue
		scored.append([(t - imp.tile).length_squared(), t])
	if scored.is_empty():
		return {}
	scored.sort_custom(func(a, b): return a[0] < b[0])
	for k in mini(6, scored.size()):
		var t: Vector2i = scored[k][1]
		var stand := t if kind == "claim" else _best_stand(imp.tile, t)
		if stand == INVALID:
			continue
		if stand != imp.tile and world.find_path(imp.tile, stand).is_empty():
			continue
		return {"type": kind, "tile": t, "stand": stand}
	return {}


func _best_stand(from: Vector2i, t: Vector2i) -> Vector2i:
	var best := INVALID
	var bd := 1e9
	for nb in world.neighbors4(t):
		if world.is_walkable(nb):
			var d := float((nb - from).length_squared())
			if d < bd:
				bd = d
				best = nb
	return best


func job_valid(imp: Unit) -> bool:
	var j := imp.job
	if j.is_empty():
		return false
	var t: Vector2i = j["tile"]
	if not world.is_walkable(j["stand"]):
		return false
	match j["type"]:
		"dig":
			return world.marked.has(world.idx(t)) and world.is_player_diggable(t)
		"claim":
			return world.get_type(t) == T.FLOOR and world.get_own(t) != 1
		"fortify":
			return world.get_type(t) == T.ROCK and world.get_own(t) == 0
		"deposit":
			return imp.carried > 0
	return false


func release_job(u: Unit) -> void:
	if u.job.is_empty():
		return
	var i := world.idx(u.job["tile"])
	if reserved.get(i) == u:
		reserved.erase(i)


func claim_tile(t: Vector2i) -> void:
	if world.get_type(t) != T.FLOOR:
		return
	world.set_tile(t, T.FLOOR, 1)
	Sfx.play_at("claim", world.tile_center(t), -6.0)
	world.burst(world.tile_center(t) + Vector3(0, 0.2, 0), Color(0.9, 0.15, 0.1), 10, 2.0, 0.6)
	mana = minf(mana + 3.0, Defs.MANA_MAX)
	for p in world.portals:
		if p["claimed"]:
			continue
		var c: Vector2i = p["center"]
		if absi(t.x - c.x) <= 2 and absi(t.y - c.y) <= 2:
			world.activate_portal(p)
			Sfx.play_at("spawn", world.tile_center(c))
			message("Portal beansprucht! Kreaturen können nun eintreffen.", Color(0.8, 0.6, 1.0))


func fortify_tile(t: Vector2i) -> void:
	if world.get_type(t) != T.ROCK:
		return
	world.set_tile(t, T.WALL, 1)
	Sfx.play_at("build", world.tile_center(t), -6.0)
	world.burst(world.tile_center(t) + Vector3(0, 1.2, 0), Color(0.6, 0.3, 0.25), 8, 2.0, 0.6)


# ================================================================ Portale & Wellen
func _try_portal_spawn() -> void:
	var claimed := []
	for p in world.portals:
		if p["claimed"]:
			claimed.append(p)
	if claimed.is_empty():
		return
	var crea := creature_count()
	var lair: int = world.room_count[R.LAIR]
	var farm: int = world.room_count[R.FARM]
	var train: int = world.room_count[R.TRAINING]
	var treas: int = world.room_count[R.TREASURY]
	if crea >= lair:
		if lair == 0:
			message_once("nolair", "Kreaturen brauchen einen Hort zum Schlafen.", Color(1.0, 0.8, 0.5), 60.0)
		else:
			message_once("lairfull", "Dein Hort ist voll – vergrößere ihn für neue Kreaturen.", Color(1.0, 0.8, 0.5), 60.0)
		return
	if crea >= 30:
		return
	var options := []
	if farm >= 1:
		options.append_array(["worm", "worm"])
	if lair >= 4:
		options.append("bat")
	if train >= 4:
		options.append_array(["kobold", "kobold"])
	if train >= 9 and treas >= 9:
		options.append_array(["brute", "brute"])
	if options.is_empty():
		message_once("noopt", "Kreaturen meiden deinen Dungeon – baue eine Pilzfarm.", Color(1.0, 0.8, 0.5), 60.0)
		return
	var kind: String = options.pick_random()
	var p: Dictionary = claimed.pick_random()
	var t := world.free_tile_near(p["center"], 3)
	if t == INVALID:
		return
	spawn_unit(kind, t)
	Sfx.play_at("spawn", world.tile_center(p["center"]))
	world.burst(world.tile_center(t) + Vector3(0, 0.8, 0), Color(0.7, 0.35, 1.0), 30, 4.0, 1.0)
	message("Ein %s ist durch das Portal gekommen." % Defs.UNITS[kind]["name"], Color(0.75, 1.0, 0.7))


func call_wave_early() -> void:
	if state == "play" and wave < Defs.WAVES.size():
		wave_timer = minf(wave_timer, 5.0)
		wave_warned = true


func _update_waves(delta: float) -> void:
	if wave < Defs.WAVES.size():
		wave_timer -= delta
		if wave_timer <= 30.0 and not wave_warned:
			wave_warned = true
			Sfx.play("alarm", -2.0)
			message("Die Helden sammeln sich am Tor! Angriff in 30 Sekunden.", Color(0.7, 0.85, 1.0))
		if wave_timer <= 0.0:
			wave += 1
			hero_queue = Defs.WAVES[wave - 1].duplicate()
			wave_timer = Defs.WAVE_GAP
			wave_warned = false
			Sfx.play("alarm")
			message("Welle %d von %d: Die Helden greifen an!" % [wave, Defs.WAVES.size()], Color(0.6, 0.8, 1.0))
	if not hero_queue.is_empty():
		hero_spawn_t -= delta
		if hero_spawn_t <= 0.0:
			hero_spawn_t = 1.4
			var kind: String = hero_queue.pop_front()
			var t := world.free_tile_near(world.gate_tile, 3)
			var lvl := 1 + (wave - 1) / 2
			var h := spawn_unit(kind, t, lvl)
			if h:
				world.burst(h.global_position + Vector3(0, 0.8, 0), Color(0.8, 0.9, 1.0), 24, 3.0, 0.9)
				Sfx.play_at("spawn", h.global_position)
	elif wave >= Defs.WAVES.size() and hero_count() == 0 and state == "play":
		_end(true)


func damage_heart(a: float) -> void:
	if state != "play":
		return
	heart_hp -= a
	world.heart_hit()
	if heart_alarm_t <= 0.0:
		heart_alarm_t = 8.0
		Sfx.play("heart")
		message("Dein Dungeon-Herz wird angegriffen!", Color(1.0, 0.3, 0.25))
	if heart_hp <= 0.0:
		heart_hp = 0.0
		world.burst(world.tile_center(world.heart_tile) + Vector3(0, 2.2, 0), Color(1.0, 0.2, 0.1), 120, 9.0, 2.0)
		_end(false)


func _end(win: bool) -> void:
	state = "won" if win else "lost"
	Engine.time_scale = 1.0
	Sfx.battle_target = 0.0
	Sfx.play("victory" if win else "defeat")
	if autotest:
		print("[END] ", state, " t=", int(game_time), " stats=", stats)
		return
	await get_tree().create_timer(1.5, true).timeout
	get_tree().paused = true
	rig.input_enabled = false
	hud.show_end(win, stats, game_time)


# ================================================================ Werkzeuge & Eingabe
func set_tool(t: String) -> void:
	tool = t
	hud.set_tool(t)
	dragging = false
	hud.set_box(Rect2())
	Input.set_default_cursor_shape(Input.CURSOR_ARROW if t == "select" else Input.CURSOR_CROSS)
	_update_hint()


func cycle_speed(dir := 1) -> void:
	speed_i = clampi(speed_i + dir, 0, speed_levels.size() - 1) if dir != 0 else (speed_i + 1) % speed_levels.size()
	Engine.time_scale = speed_levels[speed_i]


func _update_hint() -> void:
	var h := ""
	match tool:
		"select":
			h = "Linksklick: Auswählen · Rechtsklick: Befehl · Fels ziehen: Graben"
		"dig":
			h = "Graben: Felsen mit Linksklick ziehen · Shift = Markierung entfernen · Rechtsklick: Abbrechen"
		"sell":
			h = "Verkaufen: Raumfelder ziehen (50% Erstattung)"
		_:
			if tool.begins_with("room"):
				var r := int(tool.substr(4))
				var ri: Dictionary = Defs.ROOM_INFO[r]
				h = "%s bauen: %d Gold/Feld · auf eigenem Boden ziehen" % [ri["name"], ri["cost"]]
			elif tool == "spell_imp":
				h = "Wichtel beschwören: %d Mana · Klick auf eigenen Boden" % imp_cost()
			elif tool.begins_with("spell_"):
				var s := tool.substr(6)
				h = "%s: %d Mana · Klick auf Ziel" % [Defs.SPELL_INFO[s]["name"], Defs.SPELL_INFO[s]["cost"]]
	if hover_tile != INVALID and world.inb(hover_tile):
		h += "      [%s]" % _tile_desc(hover_tile)
	hud.set_hint(h)


func _tile_desc(t: Vector2i) -> String:
	var i := world.idx(t)
	match world.type[i]:
		T.BEDROCK: return "Urgestein (unzerstörbar)"
		T.ROCK: return "Fels"
		T.GOLD: return "Goldader (Rest: %d)" % int(world.dig_hp[i] * 25.0)
		T.GEM: return "Edelsteinader (unerschöpflich)"
		T.WALL: return "Befestigte Wand"
		T.HEART: return "Dungeon-Herz (%d / %d)" % [int(heart_hp), int(Defs.HEART_HP)]
		T.PORTAL: return "Portal"
		T.GATE: return "Heldentor"
	if world.room[i] != R.NONE:
		var s: String = Defs.ROOM_INFO[world.room[i]]["name"]
		if world.room[i] == R.TREASURY:
			s += " (%d Gold)" % world.store.get(i, 0)
		return s
	return "Eigener Boden" if world.own[i] == 1 else "Unbeanspruchter Boden"


func _mouse_tile() -> Vector2i:
	var mp := get_viewport().get_mouse_position()
	var cam: Camera3D = rig.cam
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	if absf(d.y) < 0.001:
		return INVALID
	var ta := (Defs.WALL_H - o.y) / d.y
	var tb := (0.0 - o.y) / d.y
	for s in 33:
		var tt := lerpf(ta, tb, s / 32.0)
		var t := world.pos_to_tile(o + d * tt)
		if world.is_tall(t):
			return t
	var tf := world.pos_to_tile(o + d * tb)
	return tf if world.inb(tf) else INVALID


func _drag_rect() -> Rect2i:
	var a := drag_tile
	var b := hover_tile
	if a == INVALID or b == INVALID:
		return Rect2i()
	var p := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var q := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(p, q - p + Vector2i.ONE)


func _is_dig_drag() -> bool:
	return tool == "dig" or (tool == "select" and drag_tile != INVALID and world.is_player_diggable(drag_tile))


func _update_hover() -> void:
	var nt := _mouse_tile() if state == "play" and not hud.menu_visible() else INVALID
	if nt != hover_tile:
		hover_tile = nt
		_update_hint()
	if hover_tile == INVALID:
		world.set_preview(Rect2i(), Color.WHITE, false)
		return
	var mp := get_viewport().get_mouse_position()
	if dragging:
		if _is_dig_drag():
			var unmark := Input.is_key_pressed(KEY_SHIFT) or world.marked.has(world.idx(drag_tile))
			world.set_preview(_drag_rect(), Color(1.0, 0.3, 0.2) if unmark else Color(1.0, 0.85, 0.2), true)
		elif tool == "select":
			world.set_preview(Rect2i(), Color.WHITE, false)
			hud.set_box(Rect2(Vector2(minf(drag_start.x, mp.x), minf(drag_start.y, mp.y)), (mp - drag_start).abs()))
		elif tool.begins_with("room"):
			world.set_preview(_drag_rect(), Defs.ROOM_INFO[int(tool.substr(4))]["color"], false)
		elif tool == "sell":
			world.set_preview(_drag_rect(), Color(1.0, 0.25, 0.2), false)
		return
	var col := Color(1, 1, 1)
	var tall := world.is_tall(hover_tile)
	match tool:
		"dig":
			col = Color(1.0, 0.85, 0.2)
		"sell":
			col = Color(1.0, 0.25, 0.2)
		"spell_bolt":
			col = Color(0.6, 0.8, 1.0)
		"spell_heal":
			col = Color(0.4, 1.0, 0.5)
		"spell_imp":
			col = Color(0.9, 0.3, 0.2)
		_:
			if tool.begins_with("room"):
				col = Defs.ROOM_INFO[int(tool.substr(4))]["color"]
	if tool == "spell_bolt" or tool == "spell_heal":
		var rr := 1 if tool == "spell_bolt" else 4
		world.set_preview(Rect2i(hover_tile - Vector2i(rr, rr), Vector2i(rr * 2 + 1, rr * 2 + 1)), col, false)
	else:
		world.set_preview(Rect2i(hover_tile, Vector2i.ONE), col, tall and (tool == "dig" or tool == "select"))


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		_on_key(e as InputEventKey)
		return
	if state != "play" or hud.menu_visible():
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if tool.begins_with("spell_"):
					_cast(tool.substr(6), hover_tile)
					return
				dragging = true
				drag_start = mb.position
				drag_tile = hover_tile
			elif dragging:
				dragging = false
				hud.set_box(Rect2())
				_on_left_release(mb.position, mb.shift_pressed)
				_update_hover()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if dragging:
				dragging = false
				hud.set_box(Rect2())
				return
			if tool != "select":
				set_tool("select")
			else:
				_order(mb.position)


func _on_key(k: InputEventKey) -> void:
	var code := k.keycode
	if code == KEY_ESCAPE:
		if hud.menu_visible():
			if state == "play":
				close_menu()
			return
		if tool != "select":
			set_tool("select")
		elif not _valid_selection().is_empty():
			_set_selection([])
		else:
			open_pause_menu()
		return
	if state != "play" or hud.menu_visible():
		return
	if k.ctrl_pressed and code == KEY_A:
		var all := []
		for u in units:
			if u.team == 1 and u.kind != "imp":
				all.append(u)
		_set_selection(all)
		return
	match code:
		KEY_F: set_tool("dig")
		KEY_1: set_tool("room%d" % R.TREASURY)
		KEY_2: set_tool("room%d" % R.LAIR)
		KEY_3: set_tool("room%d" % R.FARM)
		KEY_4: set_tool("room%d" % R.TRAINING)
		KEY_X: set_tool("sell")
		KEY_C: set_tool("spell_imp")
		KEY_V: set_tool("spell_bolt")
		KEY_B: set_tool("spell_heal")
		KEY_P, KEY_PAUSE:
			get_tree().paused = not get_tree().paused
		KEY_SPACE, KEY_H:
			rig.jump_to(world.tile_center(world.heart_tile))
		KEY_N: call_wave_early()
		KEY_PLUS, KEY_EQUAL, KEY_KP_ADD: cycle_speed(1)
		KEY_MINUS, KEY_KP_SUBTRACT: cycle_speed(-1)
		KEY_F1:
			hud.show_menu("help", "pause")
			get_tree().paused = true
			rig.input_enabled = false


func _on_left_release(pos: Vector2, shift: bool) -> void:
	var is_drag := pos.distance_to(drag_start) > 8.0
	if hover_tile == INVALID and not (tool == "select" and is_drag):
		return
	if _is_dig_drag():
		var r := _drag_rect()
		var unmark := shift or world.marked.has(world.idx(drag_tile))
		var c := world.toggle_marks(r, not unmark)
		if c > 0:
			Sfx.play("ui", -4.0)
		elif tool == "dig":
			Sfx.play("error", -6.0)
		return
	match tool:
		"select":
			if is_drag:
				_box_select(Rect2(Vector2(minf(drag_start.x, pos.x), minf(drag_start.y, pos.y)), (pos - drag_start).abs()), shift)
			else:
				var u := _pick_unit(pos, 1)
				if u:
					if shift:
						var s := _valid_selection().duplicate()
						if u in s:
							s.erase(u)
						else:
							s.append(u)
						_set_selection(s)
					else:
						_set_selection([u])
					Sfx.play("ui", -6.0)
				elif not shift:
					_set_selection([])
		"sell":
			_sell(_drag_rect())
		_:
			if tool.begins_with("room"):
				_build(_drag_rect(), int(tool.substr(4)))


func _set_selection(arr: Array) -> void:
	for u in _valid_selection():
		u.set_selected(false)
	selected = arr
	for u in selected:
		u.set_selected(true)
	hud.update_info(_valid_selection())


func _pick_unit(sp: Vector2, team: int) -> Unit:
	var best: Unit = null
	var bd := 34.0
	var cam: Camera3D = rig.cam
	for u in units:
		if u.team != team or u.dead:
			continue
		var wp: Vector3 = u.global_position + Vector3(0, 0.7 + u.hover_y, 0)
		if cam.is_position_behind(wp):
			continue
		var d := cam.unproject_position(wp).distance_to(sp)
		if d < bd:
			bd = d
			best = u
	return best


func _box_select(r: Rect2, add: bool) -> void:
	var cam: Camera3D = rig.cam
	var fighters := []
	var imps := []
	for u in units:
		if u.team != 1 or u.dead:
			continue
		var wp: Vector3 = u.global_position + Vector3(0, 0.5, 0)
		if cam.is_position_behind(wp):
			continue
		if r.has_point(cam.unproject_position(wp)):
			if u.kind == "imp":
				imps.append(u)
			else:
				fighters.append(u)
	var pick := fighters if not fighters.is_empty() else imps
	if add:
		var s := _valid_selection().duplicate()
		for u in pick:
			if not u in s:
				s.append(u)
		pick = s
	_set_selection(pick)
	if not pick.is_empty():
		Sfx.play("ui", -6.0)


func _order(sp: Vector2) -> void:
	var sel := _valid_selection()
	if sel.is_empty():
		return
	var enemy := _pick_unit(sp, 2)
	if enemy:
		for u in sel:
			u.order_attack(enemy)
		Sfx.play("order", -4.0)
		world.burst(enemy.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.3, 0.2), 12, 2.0, 0.5)
		return
	order_to_tile(hover_tile)


func order_to_tile(t: Vector2i) -> void:
	var sel := _valid_selection()
	if sel.is_empty():
		return
	if not world.is_walkable(t):
		Sfx.play("error", -6.0)
		return
	var spots := world.spread_tiles(t, sel.size())
	for k in sel.size():
		sel[k].order_move(spots[k])
	Sfx.play("order", -4.0)
	world.burst(world.tile_center(t) + Vector3(0, 0.2, 0), Color(0.4, 1.0, 0.5), 14, 2.0, 0.5)


func _build(r: Rect2i, room_type: int) -> void:
	if r.size == Vector2i.ZERO:
		return
	var cost: int = Defs.ROOM_INFO[room_type]["cost"]
	var placed := 0
	var broke := false
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var t := Vector2i(x, y)
			if world.is_own_floor(t) and world.get_room(t) == R.NONE:
				if not spend_gold(cost):
					broke = true
					break
				world.set_room(t, room_type)
				placed += 1
		if broke:
			break
	if placed > 0:
		Sfx.play("build", -2.0)
		world.burst(world.tile_center(r.get_center()) + Vector3(0, 0.3, 0), Defs.ROOM_INFO[room_type]["color"], 20, 3.0, 0.6)
	if broke:
		message_once("nogold", "Nicht genug Gold!", Color(1.0, 0.5, 0.3), 3.0)
		Sfx.play("error", -4.0)
	elif placed == 0:
		message_once("noroom", "Räume nur auf eigenem, freiem Boden bauen.", Color(1.0, 0.7, 0.4), 3.0)
		Sfx.play("error", -4.0)


func _sell(r: Rect2i) -> void:
	var refund := 0
	var sold := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var t := Vector2i(x, y)
			var rm := world.get_room(t)
			if rm == R.NONE:
				continue
			var i := world.idx(t)
			var g: int = world.store.get(i, 0)
			world.set_room(t, R.NONE)
			for u in units:
				if u.lair_idx == i:
					u.lair_idx = -1
			refund += Defs.ROOM_INFO[rm]["cost"] / 2 + g
			sold += 1
	if sold > 0:
		add_gold(refund)
		Sfx.play("gold", -3.0)


func _cast(spell: String, t: Vector2i) -> void:
	if t == INVALID:
		return
	var pos := world.tile_center(t)
	match spell:
		"imp":
			var cost := imp_cost()
			if not world.is_own_floor(t):
				message_once("spellpos", "Nur auf eigenem Boden möglich.", Color(1.0, 0.6, 0.4), 2.0)
				Sfx.play("error", -4.0)
				return
			if mana < cost:
				message_once("nomana", "Nicht genug Mana!", Color(0.5, 0.7, 1.0), 2.0)
				Sfx.play("error", -4.0)
				return
			mana -= cost
			spawn_unit("imp", t)
			Sfx.play_at("spawn", pos)
			world.burst(pos + Vector3(0, 0.6, 0), Color(1.0, 0.3, 0.15), 30, 3.5, 0.8)
			_update_hint()
		"bolt", "heal":
			var cost2: int = Defs.SPELL_INFO[spell]["cost"]
			if world.is_tall(t):
				Sfx.play("error", -4.0)
				return
			if mana < cost2:
				message_once("nomana", "Nicht genug Mana!", Color(0.5, 0.7, 1.0), 2.0)
				Sfx.play("error", -4.0)
				return
			mana -= cost2
			if spell == "bolt":
				world.lightning(pos)
				Sfx.play_at("zap", pos, 2.0)
				for u in units.duplicate():
					if u.team == 2 and not u.dead and Vector2(u.position.x - pos.x, u.position.z - pos.z).length() <= 1.9 * Defs.TILE:
						u.take_damage(140.0, null)
			else:
				Sfx.play_at("heal", pos)
				world.burst(pos + Vector3(0, 0.5, 0), Color(0.4, 1.0, 0.5), 50, 5.0, 1.2)
				for u in units:
					if u.team == 1 and not u.dead and Vector2(u.position.x - pos.x, u.position.z - pos.z).length() <= 4.5 * Defs.TILE:
						u.heal(u.max_hp * 0.6)
						world.burst(u.global_position + Vector3(0, 1.0, 0), Color(0.4, 1.0, 0.5), 10, 2.0, 0.8)


# ================================================================ Showcase (Screenshots für Tests)
func _showcase(dir: String) -> void:
	start_game()
	for y in range(8, 13):
		for x in range(14, 22):
			if world.get_type(Vector2i(x, y)) != T.GEM:
				world.set_tile(Vector2i(x, y), T.FLOOR, 1)
	for y in range(10, 15):
		for x in range(22, 27):
			if world.get_type(Vector2i(x, y)) == T.FLOOR:
				world.set_tile(Vector2i(x, y), T.FLOOR, 1)
	world.activate_portal(world.portals[0])
	for y in range(5, 17):
		for x in range(5, 28):
			var t := Vector2i(x, y)
			if world.get_type(t) == T.ROCK and _has_own_neighbor(t):
				world.set_tile(t, T.WALL, 1)
	heart_gold = 2000
	_build(Rect2i(14, 8, 3, 2), R.TREASURY)
	_build(Rect2i(17, 8, 3, 2), R.LAIR)
	_build(Rect2i(14, 11, 3, 2), R.FARM)
	_build(Rect2i(17, 11, 4, 2), R.TRAINING)
	add_gold(1500)
	world.toggle_marks(Rect2i(8, 15, 3, 3), true)
	for k in ["worm", "bat", "kobold", "brute", "worm", "kobold"]:
		spawn_unit(k, world.free_tile_near(Vector2i(19, 10), 2))
	for k in ["knight", "archer", "priest", "dwarf"]:
		spawn_unit(k, world.free_tile_near(Vector2i(24, 12), 2), 2)
	_set_selection([units[units.size() - 7]])
	var shots := [
		[world.tile_center(Vector2i(17, 10)), 0.35, 26.0, 57.0],
		[world.tile_center(Vector2i(11, 11)), 2.2, 20.0, 45.0],
		[world.tile_center(Vector2i(22, 11)), -0.6, 16.0, 40.0],
	]
	for k in shots.size():
		var s: Array = shots[k]
		rig.jump_to(s[0], true)
		rig.yaw = s[1]
		rig.yaw_target = s[1]
		rig.dist = s[2]
		rig.dist_target = s[2]
		rig.pitch = deg_to_rad(s[3])
		rig.pitch_target = rig.pitch
		await get_tree().create_timer(2.5, true).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("shot_%d.png" % k))
		print("[SHOT] ", k)
	get_tree().quit()


# ================================================================ Autotest (headless)
func _autotest(delta: float) -> void:
	_at_t += delta
	if _at_step == 0:
		_at_step = 1
		# Tunnel zum ersten Portal und Goldadern markieren
		world.toggle_marks(Rect2i(14, 10, 8, 1), true)
		world.toggle_marks(Rect2i(15, 8, 2, 3), true)
		world.toggle_marks(Rect2i(8, 14, 3, 3), true)
	if _at_step == 1 and _at_t > 40.0:
		_at_step = 2
		_build(Rect2i(7, 7, 3, 2), R.LAIR)
		_build(Rect2i(12, 7, 2, 2), R.FARM)
		_build(Rect2i(7, 12, 2, 2), R.TREASURY)
		_build(Rect2i(12, 12, 2, 2), R.TRAINING)
		_cast("imp", Vector2i(8, 10))
		print("[AT] rooms ", world.room_count, " gold=", total_gold())
	if int(_at_t) % 30 == 0 and int(_at_t - delta) % 30 != 0:
		var claimed_p := 0
		for p in world.portals:
			if p["claimed"]:
				claimed_p += 1
		print("[AT] t=%d gold=%d mana=%d imps=%d crea=%d heroes=%d claimed=%d marked=%d portals=%d wave=%d heart=%d fps=%d" % [
			int(game_time), total_gold(), int(mana), count_units("imp"), creature_count(), hero_count(),
			world.claimed_count, world.marked.size(), claimed_p, wave, int(heart_hp), Engine.get_frames_per_second()])
	if _at_t > 1500.0 or state != "play":
		print("[AT] done state=", state, " stats=", stats)
		get_tree().quit()

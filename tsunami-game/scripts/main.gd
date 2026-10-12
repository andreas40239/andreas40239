extends Node2D
## Spiellogik und Benutzeroberfläche von "Tsunami Mauerbau".
##
## Ablauf pro Level: Erdbeben → Countdown (bauen, Höhe aus Hinweisen schätzen) → Tsunami mit
## einer oder mehreren Wellen (Risse flicken, Treibgut zerstören) → Auswertung → nächstes Level.

const WorldScript := preload("res://scripts/world.gd")
const OceanAudioScript := preload("res://scripts/ocean_audio.gd")

const RES_ORDER := ["stone", "wood", "sand", "concrete"]
const RES_NAMES := {"stone": "Steine", "wood": "Holz", "sand": "Sand", "concrete": "Beton"}
const RES_COLORS := {
	"stone": Color(0.8, 0.82, 0.88), "wood": Color(0.95, 0.7, 0.45),
	"sand": Color(1.0, 0.88, 0.55), "concrete": Color(0.85, 0.85, 0.78),
}
const TOOL_ORDER := ["pickaxe", "axe", "shovel"]
const MACHINE_ORDER := ["excavator", "harvester", "mixer", "crane"]
const DEFENSE_ORDER := ["breakwater", "forest", "buoy"]
const MAT_ORDER := ["wood", "stone", "concrete"]
## Stabilität (HP) pro Meter Mauer
const MATERIALS := {
	"wood": {"name": "Holz", "hp": 12.0},
	"stone": {"name": "Stein", "hp": 30.0},
	"concrete": {"name": "Beton", "hp": 70.0},
}
const HOUSE_X := [482.0, 526.0, 570.0, 614.0]
const RESIDENTS := 5
const BUOY_UNCERTAINTY := [0.35, 0.2, 0.1, 0.0]

enum State { PREP, TSUNAMI, RESULT, GAME_OVER }

var state := State.PREP
var level := 1
var res := {"stone": 30.0, "wood": 40.0, "sand": 20.0, "concrete": 0.0}
var tools := {
	"pickaxe": {"name": "Spitzhacke", "res": "stone", "level": 1},
	"axe": {"name": "Axt", "res": "wood", "level": 1},
	"shovel": {"name": "Schaufel", "res": "sand", "level": 1},
}
var machines := {
	"excavator": {"name": "Bagger", "level": 0, "max": 12},
	"harvester": {"name": "Holzernter", "level": 0, "max": 12},
	"mixer": {"name": "Betonmischer", "level": 0, "max": 12},
	"crane": {"name": "Kran", "level": 0, "max": 6},
}
var defenses := {
	"breakwater": {"name": "Wellenbrecher", "level": 0, "max": 5},
	"forest": {"name": "Schutzwald", "level": 0, "max": 5},
	"buoy": {"name": "Warnboje", "level": 0, "max": 3},
}
var layers: Array = []          # [{m: Material, h: Höhe}]
var wall_height := 0.0
var wall_hp := 0.0
var wall_max_hp := 0.0
var houses: Array = []          # [{x, alive}]
var stars_total := 0

# Aktueller Tsunami
var countdown := 0.0
var quake_mag := 0.0
var raw_height := 0.0           # höchste Welle ohne Schutzanlagen
var wave_factors: Array = []
var last_height := -1.0         # tatsächliche Höhe nach dem Tsunami (für die Anzeige)
var _est_off := 0.0
var _last_wave_dmg := 0.0
var _houses_lost := 0
var _breached := false
var _wave_no := 0
var _breach_wave := -1
var _first_crack_hint := true

var world: Node2D
var audio: Node
var _rng := RandomNumberGenerator.new()
var _labels := {}
var _hp_bar: ProgressBar
var _tool_buttons := {}
var _machine_buttons := {}
var _defense_buttons := {}
var _house_button: Button
var _mat_buttons := {}
var _build_title: Label
var _play_button: Button
var _countdown_label: Label
var _message: Label
var _ui_timer := 0.0
var _build_boost := 0.0


func _ready() -> void:
	_rng.randomize()
	for x in HOUSE_X:
		houses.append({"x": x, "alive": true})
	audio = OceanAudioScript.new()
	add_child(audio)
	world = WorldScript.new()
	world.game = self
	world.audio = audio
	add_child(world)
	world.resource_clicked.connect(_on_resource_clicked)
	world.wave_impact.connect(_on_wave_impact)
	world.crack_fixed.connect(_on_crack_fixed)
	world.crack_failed.connect(_on_crack_failed)
	world.debris_hit.connect(_on_debris_hit)
	world.debris_destroyed.connect(_on_debris_destroyed)
	world.house_flooded.connect(_on_house_flooded)
	world.tsunami_finished.connect(_on_tsunami_finished)
	_build_ui()
	_start_level()


# ---------------------------------------------------------------- Formeln

func tool_yield(id: String) -> int:
	var l: int = tools[id].level
	return 1 + l * (l - 1)


func tool_cost(id: String) -> Dictionary:
	var f := pow(1.9, tools[id].level - 1)
	var c := {}
	match id:
		"pickaxe": c = {"stone": 10, "wood": 6}
		"axe": c = {"wood": 10, "stone": 6}
		"shovel": c = {"sand": 10, "wood": 6}
	return _scale(c, f)


func machine_cost(id: String) -> Dictionary:
	var f := pow(2.0, machines[id].level)
	var c := {}
	match id:
		"excavator": c = {"stone": 40, "wood": 30}
		"harvester": c = {"stone": 30, "wood": 40}
		"mixer": c = {"stone": 60, "wood": 30, "sand": 40}
		"crane": c = {"stone": 100, "wood": 80, "concrete": 20}
	return _scale(c, f)


func defense_cost(id: String) -> Dictionary:
	var f := pow(2.1, defenses[id].level)
	var c := {}
	match id:
		"breakwater": c = {"concrete": 25, "stone": 40}
		"forest": c = {"wood": 50, "sand": 40}
		"buoy": c = {"stone": 40, "wood": 30, "concrete": 10}
	return _scale(c, f)


func house_cost() -> Dictionary:
	return _scale({"wood": 30 + 12 * level, "stone": 20 + 10 * level}, 1.0)


func machine_rate(id: String) -> float:
	var l: int = machines[id].level
	var base := l * (l + 1) / 2.0
	match id:
		"excavator", "harvester": return base
		"mixer": return base * 0.5
	return 0.0


func layer_height() -> float:
	return 0.5 + 0.25 * machines.crane.level


func layer_cost(mat: String) -> Dictionary:
	var h := wall_height
	var c := {}
	match mat:
		"wood": c = {"wood": 6.0 + 1.5 * h}
		"stone": c = {"stone": 10.0 + 3.0 * h, "sand": 3.0 + 1.0 * h}
		"concrete": c = {"concrete": 4.0 + 1.5 * h, "stone": 4.0 + 1.0 * h}
	return _scale(c, 1.0)


## Anteil der Wellenhöhe, der nach Wellenbrechern und Schutzwald übrig bleibt
func protection_factor() -> float:
	return 1.0 - 0.06 * defenses.breakwater.level - 0.04 * defenses.forest.level


func effective_height() -> float:
	return snappedf(raw_height * protection_factor(), 0.1)


## Geschätzte Höhe der größten Welle (min, max) – je besser die Warnboje, desto genauer
func estimate() -> Vector2:
	var eff := effective_height()
	var u: float = BUOY_UNCERTAINTY[defenses.buoy.level]
	if u <= 0.0:
		return Vector2(eff, eff)
	var center := eff * (1.0 + u * _est_off)
	return Vector2(snappedf(center * (1.0 - u), 0.1), snappedf(center * (1.0 + u), 0.1))


func _scale(c: Dictionary, f: float) -> Dictionary:
	var out := {}
	for k in c:
		out[k] = int(round(c[k] * f))
	return out


func can_afford(c: Dictionary) -> bool:
	for k in c:
		if res[k] < c[k]:
			return false
	return true


func pay(c: Dictionary) -> void:
	for k in c:
		res[k] -= c[k]


func cost_text(c: Dictionary) -> String:
	var parts := []
	for k in RES_ORDER:
		if c.has(k) and c[k] > 0:
			parts.append("%d %s" % [c[k], RES_NAMES[k]])
	return ", ".join(parts)


func houses_alive() -> int:
	var n := 0
	for hs in houses:
		if hs.alive:
			n += 1
	return n


# ---------------------------------------------------------------- Level-Ablauf

func _start_level() -> void:
	state = State.PREP
	raw_height = 3.0 + 2.2 * (level - 1) + _rng.randf_range(-0.3, 0.9)
	_est_off = _rng.randf_range(-0.6, 0.6)
	quake_mag = snappedf(6.4 + raw_height * 0.09 + _rng.randf_range(-0.15, 0.15), 0.1)
	countdown = 90.0 if level == 1 else 60.0 + 6.0 * mini(level, 6)
	if level <= 1:
		wave_factors = [1.0]
	elif level <= 3:
		wave_factors = [0.65, 1.0]
	else:
		wave_factors = [0.6, 1.0, 0.75] if _rng.randf() < 0.5 else [1.0, 0.7, 0.85]
	wall_hp = wall_max_hp
	_houses_lost = 0
	_breached = false
	last_height = -1.0
	world.start_quake()
	_vibrate(400)
	var waves_text := "1 Welle" if wave_factors.size() == 1 else "%d Wellen" % wave_factors.size()
	_show_message("Level %d: Erdbeben der Stärke %.1f! Ein Tsunami (%s) kommt. Bau schnell!" % [level, quake_mag, waves_text])
	_refresh_ui()


func _launch_tsunami() -> void:
	if state != State.PREP:
		return
	var bonus := int(countdown * (0.5 + 0.3 * level))
	if bonus > 0:
		for k in ["stone", "wood", "sand"]:
			res[k] += bonus
		world.spawn_floater(Vector2(560, 210), "Mutig! +%d Steine, Holz, Sand" % bonus, Color(1, 0.9, 0.4))
	state = State.TSUNAMI
	countdown = 0.0
	audio.siren = 0.0
	var heights := []
	for f in wave_factors:
		heights.append(effective_height() * f)
	world.start_tsunami(heights, mini(3, level / 2))
	_show_message("Das Meer zieht sich zurück … gleich kommt die Welle!")
	_refresh_ui()


func _on_wave_impact(index: int, height: float) -> void:
	_vibrate(300)
	_wave_no += 1
	var dmg := 1.2 * height * height
	_last_wave_dmg = dmg
	if wall_height > 0.3:
		var n := clampi(1 + int(dmg / maxf(wall_max_hp, 1.0) * 6.0), 1, 5)
		world.add_cracks(n, maxf(1.6, 2.8 - level * 0.12))
		if _first_crack_hint:
			_first_crack_hint = false
			_show_message("Risse in der Mauer! Schnell darauf TIPPEN, bevor sie aufbrechen!")
		else:
			_show_message("Welle %d/%d: %.1f m hoch!" % [index + 1, wave_factors.size(), height])
	_damage_wall(dmg)


func _on_crack_fixed(_pos: Vector2) -> void:
	pass


func _on_crack_failed(pos: Vector2) -> void:
	world.spawn_floater(pos + Vector2(-70, 0), "Riss bricht auf!", Color(1, 0.4, 0.3))
	_vibrate(120)
	_damage_wall(_last_wave_dmg * 0.35 + 5.0)


func _on_debris_hit(kind: String) -> void:
	_show_message("Treibgut kracht gegen die Mauer!")
	_vibrate(200)
	_damage_wall(wall_max_hp * 0.08 + 10.0)
	world.add_cracks(1, 2.4)


func _on_debris_destroyed(kind: String, pos: Vector2) -> void:
	var r := "wood" if kind != "container" else "stone"
	var amount := 4 * level
	res[r] += amount
	world.spawn_floater(pos + Vector2(-40, -30), "Zerstört! +%d %s" % [amount, RES_NAMES[r]], RES_COLORS[r])


func _on_house_flooded(index: int) -> void:
	if not houses[index].alive:
		return
	houses[index].alive = false
	_houses_lost += 1
	_vibrate(250)
	_show_message("Ein Haus wurde weggespült! %d Bewohner verlieren ihr Zuhause." % RESIDENTS)


func _damage_wall(amount: float) -> void:
	if wall_height <= 0.0:
		return
	wall_hp -= amount
	if wall_hp <= 0.0:
		if _breach_wave == _wave_no:
			wall_hp = 1.0   # pro Welle bricht die Mauer höchstens einmal
		else:
			_breach()
	_refresh_ui()


## Die Mauer bricht: die oberen Schichten stürzen ein.
func _breach() -> void:
	var target := wall_height * 0.65
	while not layers.is_empty() and wall_height > target + 0.01:
		layers.pop_back()
		_recompute_wall()
	wall_hp = wall_max_hp * 0.6
	_breached = true
	_breach_wave = _wave_no
	world.on_breach()
	audio.impact(1.0)
	_vibrate(600)
	_show_message("MAUERBRUCH! Die Mauer ist nur noch %.1f m hoch!" % wall_height)


func _recompute_wall() -> void:
	wall_height = 0.0
	wall_max_hp = 0.0
	for layer in layers:
		wall_height += layer.h
		wall_max_hp += MATERIALS[layer.m].hp * layer.h
	wall_height = snappedf(wall_height, 0.01)


func _on_tsunami_finished() -> void:
	last_height = effective_height()
	var stars := 0
	if _houses_lost == 0:
		stars = 2 if _breached else 3
	elif _houses_lost == 1:
		stars = 1
	stars_total += stars
	if houses_alive() == 0:
		state = State.GAME_OVER
		_show_message("GAME OVER – das ganze Dorf wurde weggespült. Du hast %d Level geschafft (%d Sterne)." % [level - 1, stars_total])
		_refresh_ui()
		return
	state = State.RESULT
	world.cheer = 3.0 if _houses_lost == 0 else 0.0
	var bonus := 10 * level * stars
	for k in ["stone", "wood", "sand"]:
		res[k] += bonus
	var verdict := "Perfekt! Die Mauer hat gehalten." if stars == 3 else \
		("Dorf gerettet, aber die Mauer ist gebrochen." if stars == 2 else "%d Haus/Häuser verloren." % _houses_lost)
	_show_message("Level %d: %d von 3 Sternen. %s Bonus: je %d Rohstoffe." % [level, stars, verdict, bonus])
	_refresh_ui()
	await get_tree().create_timer(4.0).timeout
	if state == State.RESULT:
		level += 1
		_start_level()


# ---------------------------------------------------------------- Aktionen

func _on_resource_clicked(kind: String, pos: Vector2) -> void:
	for id in TOOL_ORDER:
		if tools[id].res == kind:
			var amount := tool_yield(id)
			res[kind] += amount
			world.spawn_floater(pos + Vector2(-10, -10), "+%d %s" % [amount, RES_NAMES[kind]], RES_COLORS[kind])
	_refresh_ui()


func _upgrade_tool(id: String) -> void:
	var c := tool_cost(id)
	if not can_afford(c):
		return
	pay(c)
	tools[id].level += 1
	_show_message("%s auf Level %d verbessert! Jetzt +%d pro Tipp." % [tools[id].name, tools[id].level, tool_yield(id)])
	_refresh_ui()


func _upgrade_machine(id: String) -> void:
	var m: Dictionary = machines[id]
	if m.level >= m.max:
		return
	var c := machine_cost(id)
	if not can_afford(c):
		return
	pay(c)
	m.level += 1
	_show_message("%s %s! (Level %d)" % [m.name, "gekauft" if m.level == 1 else "verbessert", m.level])
	_refresh_ui()


func _upgrade_defense(id: String) -> void:
	var d: Dictionary = defenses[id]
	if d.level >= d.max or state != State.PREP:
		return
	var c := defense_cost(id)
	if not can_afford(c):
		return
	pay(c)
	d.level += 1
	match id:
		"breakwater", "forest":
			_show_message("%s Level %d: Wellen werden jetzt um %d%% gebremst." % [d.name, d.level, roundi((1.0 - protection_factor()) * 100.0)])
		"buoy":
			_show_message("Warnboje Level %d: Die Wellenhöhe wird genauer gemessen." % d.level)
	_refresh_ui()


func _rebuild_house() -> void:
	if state != State.PREP:
		return
	var c := house_cost()
	if not can_afford(c):
		return
	for hs in houses:
		if not hs.alive:
			pay(c)
			hs.alive = true
			_show_message("Haus wieder aufgebaut! Die Bewohner ziehen zurück.")
			break
	_refresh_ui()


func _build_wall(mat: String) -> void:
	if state != State.PREP:
		return
	var c := layer_cost(mat)
	if not can_afford(c):
		return
	pay(c)
	var lh := layer_height()
	layers.append({"m": mat, "h": lh})
	_recompute_wall()
	wall_hp += MATERIALS[mat].hp * lh
	world.notify_built()
	_build_boost = 0.8
	_refresh_ui()


func _on_play_pressed() -> void:
	match state:
		State.PREP:
			_launch_tsunami()
		State.GAME_OVER:
			get_tree().reload_current_scene()


func _vibrate(ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# ---------------------------------------------------------------- Ablauf

func _process(delta: float) -> void:
	res.stone += machine_rate("excavator") * delta
	res.sand += machine_rate("excavator") * 0.5 * delta
	res.wood += machine_rate("harvester") * delta
	var mix := machine_rate("mixer") * delta
	if mix > 0.0:
		mix = minf(mix, minf(res.sand / 2.0, res.stone))
		res.sand -= mix * 2.0
		res.stone -= mix
		res.concrete += mix

	if state == State.PREP:
		countdown -= delta
		# Hinweis: Kurz vor dem Tsunami zieht sich das Meer zurück, je höher, desto weiter
		world.pre_retreat = clampf((15.0 - countdown) / 15.0, 0.0, 1.0) * (0.3 + effective_height() * 0.08)
		audio.siren = 1.0 if countdown < 10.0 else 0.0
		if countdown <= 0.0:
			_launch_tsunami()
	else:
		world.pre_retreat = 0.0
		audio.siren = 0.0

	var owned := 0
	for id in MACHINE_ORDER:
		if machines[id].level > 0:
			owned += 1
	_build_boost = maxf(0.0, _build_boost - delta)
	audio.machine_level = clampf(owned * 0.15 + _build_boost, 0.0, 1.0)

	_update_countdown_label()
	_ui_timer -= delta
	if _ui_timer <= 0.0:
		_ui_timer = 0.1
		_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _build_wall("wood")
			KEY_2: _build_wall("stone")
			KEY_3: _build_wall("concrete")
			KEY_P, KEY_ENTER: _on_play_pressed()


# ---------------------------------------------------------------- UI

func _show_message(s: String) -> void:
	if _message:
		_message.text = s


func _update_countdown_label() -> void:
	if not _countdown_label:
		return
	match state:
		State.PREP:
			var s := int(ceil(countdown))
			_countdown_label.text = "TSUNAMI IN %d:%02d" % [s / 60, s % 60]
			var urgent := countdown < 10.0
			var blink := urgent and fmod(countdown, 0.5) < 0.25
			_countdown_label.add_theme_color_override("font_color", Color(1, 0.25, 0.2) if blink else (Color(1, 0.6, 0.3) if urgent else Color.WHITE))
		State.TSUNAMI:
			_countdown_label.text = "TSUNAMI!"
			_countdown_label.add_theme_color_override("font_color", Color(1, 0.3, 0.25))
		State.RESULT:
			_countdown_label.text = "GESCHAFFT"
			_countdown_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		State.GAME_OVER:
			_countdown_label.text = "GAME OVER"
			_countdown_label.add_theme_color_override("font_color", Color(1, 0.3, 0.25))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	layer.add_child(root)

	# Kopfzeile
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(hb)
	for key in ["level"] + RES_ORDER + ["wall"]:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 16)
		if RES_COLORS.has(key):
			l.add_theme_color_override("font_color", RES_COLORS[key])
		hb.add_child(l)
		_labels[key] = l
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(90, 14)
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_hp_bar)
	for key in ["village", "stars"]:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 16)
		hb.add_child(l)
		_labels[key] = l
	_labels.stars.add_theme_color_override("font_color", Color(1, 0.85, 0.3))

	_countdown_label = Label.new()
	_countdown_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_countdown_label.offset_top = 34
	_countdown_label.offset_bottom = 74
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 32)
	_countdown_label.add_theme_constant_override("outline_size", 8)
	_countdown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	root.add_child(_countdown_label)

	_message = Label.new()
	_message.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_message.offset_top = 76
	_message.offset_bottom = 104
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 18)
	_message.add_theme_constant_override("outline_size", 6)
	_message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	root.add_child(_message)

	# Steuerleiste unten
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -180
	root.add_child(bottom)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	bottom.add_child(cols)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_stretch_ratio = 2.0
	cols.add_child(tabs)

	var tool_row := _grid(tabs, "Werkzeuge", 3)
	for id in TOOL_ORDER:
		var b := _button(tool_row)
		b.pressed.connect(_upgrade_tool.bind(id))
		_tool_buttons[id] = b

	var machine_grid := _grid(tabs, "Baumaschinen", 2)
	for id in MACHINE_ORDER:
		var b := _button(machine_grid)
		b.pressed.connect(_upgrade_machine.bind(id))
		_machine_buttons[id] = b

	var defense_grid := _grid(tabs, "Schutz & Dorf", 2)
	for id in DEFENSE_ORDER:
		var b := _button(defense_grid)
		b.pressed.connect(_upgrade_defense.bind(id))
		_defense_buttons[id] = b
	_house_button = _button(defense_grid)
	_house_button.pressed.connect(_rebuild_house)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	cols.add_child(right)
	_build_title = Label.new()
	_build_title.add_theme_font_size_override("font_size", 14)
	_build_title.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	right.add_child(_build_title)
	var mats := HBoxContainer.new()
	mats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mats.add_theme_constant_override("separation", 6)
	right.add_child(mats)
	for mat in MAT_ORDER:
		var b := _button(mats)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_build_wall.bind(mat))
		_mat_buttons[mat] = b
	_play_button = _button(right)
	_play_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_button.custom_minimum_size = Vector2(0, 46)
	_play_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_play_button.add_theme_font_size_override("font_size", 17)
	_play_button.add_theme_stylebox_override("normal", _box(Color(0.75, 0.2, 0.15)))
	_play_button.add_theme_stylebox_override("hover", _box(Color(0.9, 0.3, 0.2)))
	_play_button.add_theme_stylebox_override("pressed", _box(Color(0.6, 0.15, 0.1)))
	_play_button.pressed.connect(_on_play_pressed)


func _grid(tabs: TabContainer, title: String, columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.name = title
	g.columns = columns
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 6)
	tabs.add_child(g)
	return g


func _button(parent: Control) -> Button:
	var b := Button.new()
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


func _box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(6)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 13
	var panel := _box(Color(0.05, 0.1, 0.18, 0.9))
	panel.content_margin_top = 4
	panel.content_margin_bottom = 4
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("normal", "Button", _box(Color(0.16, 0.32, 0.5)))
	th.set_stylebox("hover", "Button", _box(Color(0.22, 0.42, 0.65)))
	th.set_stylebox("pressed", "Button", _box(Color(0.12, 0.25, 0.4)))
	th.set_stylebox("disabled", "Button", _box(Color(0.18, 0.2, 0.24)))
	th.set_color("font_disabled_color", "Button", Color(0.55, 0.58, 0.62))
	var tab_panel := StyleBoxEmpty.new()
	tab_panel.content_margin_top = 4
	th.set_stylebox("panel", "TabContainer", tab_panel)
	th.set_stylebox("tab_selected", "TabContainer", _box(Color(0.22, 0.42, 0.65)))
	th.set_stylebox("tab_unselected", "TabContainer", _box(Color(0.1, 0.18, 0.28)))
	th.set_stylebox("tab_hovered", "TabContainer", _box(Color(0.16, 0.32, 0.5)))
	th.set_font_size("font_size", "TabContainer", 15)
	var bar_bg := _box(Color(0.25, 0.1, 0.1))
	var bar_fill := _box(Color(0.3, 0.8, 0.35))
	th.set_stylebox("background", "ProgressBar", bar_bg)
	th.set_stylebox("fill", "ProgressBar", bar_fill)
	return th


func _refresh_ui() -> void:
	if _labels.is_empty():
		return
	var prep := state == State.PREP
	_labels.level.text = "Level %d" % level
	for k in RES_ORDER:
		_labels[k].text = "%s: %d" % [RES_NAMES[k], int(res[k])]
	_labels.wall.text = "Mauer: %.1f m" % wall_height
	_hp_bar.max_value = maxf(wall_max_hp, 1.0)
	_hp_bar.value = maxf(wall_hp, 0.0)
	var ratio := wall_hp / maxf(wall_max_hp, 1.0)
	(_hp_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(0.3, 0.8, 0.35).lerp(Color(0.9, 0.25, 0.2), 1.0 - ratio)
	_labels.village.text = "Dorf: %d/%d Häuser (%d Bewohner)" % [houses_alive(), houses.size(), houses_alive() * RESIDENTS]
	_labels.stars.text = "Sterne: %d" % stars_total

	for id in TOOL_ORDER:
		var tl: Dictionary = tools[id]
		var c := tool_cost(id)
		var b: Button = _tool_buttons[id]
		b.text = "%s  Lv %d\n+%d %s pro Tipp\nUpgrade: %s" % [tl.name, tl.level, tool_yield(id), RES_NAMES[tl.res], cost_text(c)]
		b.disabled = not can_afford(c)

	for id in MACHINE_ORDER:
		var m: Dictionary = machines[id]
		var b: Button = _machine_buttons[id]
		var effect := ""
		match id:
			"excavator": effect = "%.1f Steine + %.1f Sand/s" % [machine_rate(id), machine_rate(id) * 0.5] if m.level > 0 else "baut Steine + Sand ab"
			"harvester": effect = "%.1f Holz/s" % machine_rate(id) if m.level > 0 else "fällt automatisch Bäume"
			"mixer": effect = "%.1f Beton/s aus Sand + Steinen" % machine_rate(id) if m.level > 0 else "mischt Beton"
			"crane": effect = "Schicht %.2f m" % layer_height()
		_set_upgrade_button(b, m, effect, machine_cost(id), true)

	for id in DEFENSE_ORDER:
		var d: Dictionary = defenses[id]
		var effect := ""
		match id:
			"breakwater": effect = "bremst Wellen um %d%%" % (6 * d.level) if d.level > 0 else "bremst Wellen um 6% je Stufe"
			"forest": effect = "bremst Wellen um %d%%" % (4 * d.level) if d.level > 0 else "Palmen bremsen Wellen um 4% je Stufe"
			"buoy": effect = "Höhe: ±%d%%" % roundi(BUOY_UNCERTAINTY[d.level] * 100.0) if d.level < d.max else "misst exakte Höhe"
		_set_upgrade_button(_defense_buttons[id], d, effect, defense_cost(id), prep)

	var hc := house_cost()
	var missing := houses.size() - houses_alive()
	_house_button.text = "Haus wiederaufbauen\n%d zerstört\nKosten: %s" % [missing, cost_text(hc)]
	_house_button.disabled = missing == 0 or not prep or not can_afford(hc)

	_build_title.text = "Mauer bauen (+%.2f m pro Schicht)  [1] [2] [3]" % layer_height()
	for mat in MAT_ORDER:
		var c := layer_cost(mat)
		var b: Button = _mat_buttons[mat]
		b.text = "%s\n+%d Stabilität\n%s" % [MATERIALS[mat].name, roundi(MATERIALS[mat].hp * layer_height()), cost_text(c).replace(", ", "\n")]
		b.disabled = not prep or not can_afford(c)

	match state:
		State.PREP:
			var bonus := int(countdown * (0.5 + 0.3 * level))
			_play_button.text = "JETZT auslösen  (+%d Bonus)  [P]" % bonus
			_play_button.disabled = false
		State.GAME_OVER:
			_play_button.text = "Neues Spiel"
			_play_button.disabled = false
		_:
			_play_button.text = "Tsunami läuft …" if state == State.TSUNAMI else "Nächstes Level …"
			_play_button.disabled = true


func _set_upgrade_button(b: Button, d: Dictionary, effect: String, c: Dictionary, allowed: bool) -> void:
	if d.level >= d.max:
		b.text = "%s  Lv %d (max)\n%s" % [d.name, d.level, effect]
		b.disabled = true
		return
	var action := "Kaufen" if d.level == 0 else "Upgrade"
	b.text = "%s  Lv %d  –  %s\n%s: %s" % [d.name, d.level, effect, action, cost_text(c)]
	b.disabled = not allowed or not can_afford(c)

extends Node2D
## Spiellogik und Benutzeroberfläche von "Tsunami Mauerbau".

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
const CONCRETE_FROM := 4.0   # ab dieser Mauerhöhe (m) wird Beton benötigt

var level := 1
var res := {"stone": 0.0, "wood": 0.0, "sand": 0.0, "concrete": 0.0}
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
var wall_height := 0.0
var tsunami_height := 0.0
var tsunami_known := false
var tsunami_running := false

var world: Node2D
var audio: Node
var _rng := RandomNumberGenerator.new()
var _labels := {}
var _tool_buttons := {}
var _machine_buttons := {}
var _build_button: Button
var _play_button: Button
var _message: Label
var _ui_timer := 0.0
var _build_boost := 0.0


func _ready() -> void:
	_rng.randomize()
	audio = OceanAudioScript.new()
	add_child(audio)
	world = WorldScript.new()
	world.game = self
	world.audio = audio
	add_child(world)
	world.resource_clicked.connect(_on_resource_clicked)
	world.tsunami_impact.connect(_on_tsunami_impact)
	world.tsunami_finished.connect(_on_tsunami_finished)
	_build_ui()
	_new_tsunami()
	_show_message("Level 1 – Sammle Rohstoffe und baue eine Mauer! Mit PLAY testest du den Tsunami.")
	_refresh_ui()


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


## Produktion pro Sekunde einer Maschine
func machine_rate(id: String) -> float:
	var l: int = machines[id].level
	var base := l * (l + 1) / 2.0
	match id:
		"excavator", "harvester": return base
		"mixer": return base * 0.5
	return 0.0


func layer_height() -> float:
	return 0.5 + 0.25 * machines.crane.level


func wall_cost() -> Dictionary:
	var h := wall_height
	var c := {"stone": 10.0 + 4.0 * h, "wood": 3.0 + 1.5 * h, "sand": 2.0 + 1.0 * h}
	if h >= CONCRETE_FROM - 0.001:
		c["concrete"] = 3.0 + 2.0 * (h - CONCRETE_FROM)
	return _scale(c, 1.0)


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


func _new_tsunami() -> void:
	tsunami_height = snappedf(3.0 + 2.2 * (level - 1) + _rng.randf_range(-0.3, 0.9), 0.1)
	tsunami_known = false


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
	_show_message("%s auf Level %d verbessert! Jetzt +%d pro Klick." % [tools[id].name, tools[id].level, tool_yield(id)])
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


func _build_wall() -> void:
	if tsunami_running:
		return
	var c := wall_cost()
	if not can_afford(c):
		return
	pay(c)
	wall_height = snappedf(wall_height + layer_height(), 0.01)
	world.notify_built()
	_build_boost = 0.8
	_refresh_ui()


func _play() -> void:
	if tsunami_running or world.is_busy():
		return
	tsunami_running = true
	_show_message("Achtung! Das Meer zieht sich zurück … ein Tsunami kommt!")
	world.start_tsunami(tsunami_height, wall_height)
	_refresh_ui()


func _on_tsunami_impact() -> void:
	tsunami_known = true
	if wall_height >= tsunami_height:
		_show_message("BOOM! Der Tsunami (%.1f m) zerschellt an deiner Mauer!" % tsunami_height)
	else:
		_show_message("Überflutet! Der Tsunami war %.1f m hoch – deine Mauer nur %.1f m." % [tsunami_height, wall_height])


func _on_tsunami_finished(survived: bool) -> void:
	if not survived:
		tsunami_running = false
		_show_message("Es fehlen noch %.1f m. Sammle weiter und bau die Mauer höher!" % (tsunami_height - wall_height))
		_refresh_ui()
		return
	var bonus := 15 * level
	res.stone += bonus
	res.wood += bonus
	res.sand += bonus
	_show_message("Level %d geschafft! Bonus: je %d Steine, Holz und Sand. Nächstes Level startet …" % [level, bonus])
	_refresh_ui()
	await get_tree().create_timer(3.0).timeout
	level += 1
	_new_tsunami()
	tsunami_running = false
	_show_message("Level %d – Ein neuer, noch höherer Tsunami naht. Wie hoch? Drück PLAY!" % level)
	_refresh_ui()


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

	var owned := 0
	for id in MACHINE_ORDER:
		if machines[id].level > 0:
			owned += 1
	_build_boost = maxf(0.0, _build_boost - delta)
	audio.machine_level = clampf(owned * 0.2 + _build_boost, 0.0, 1.0)

	_ui_timer -= delta
	if _ui_timer <= 0.0:
		_ui_timer = 0.1
		_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B: _build_wall()
			KEY_P, KEY_ENTER: _play()


# ---------------------------------------------------------------- UI

func _show_message(s: String) -> void:
	if _message:
		_message.text = s


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
	hb.add_theme_constant_override("separation", 26)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(hb)
	for key in ["level"] + RES_ORDER + ["wall", "tsunami"]:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 17)
		if RES_COLORS.has(key):
			l.add_theme_color_override("font_color", RES_COLORS[key])
		hb.add_child(l)
		_labels[key] = l
	_labels.tsunami.add_theme_color_override("font_color", Color(1, 0.6, 0.55))

	_message = Label.new()
	_message.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_message.offset_top = 44
	_message.offset_bottom = 74
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 20)
	_message.add_theme_constant_override("outline_size", 6)
	_message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	root.add_child(_message)

	# Steuerleiste unten
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -176
	root.add_child(bottom)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	bottom.add_child(cols)

	var tool_box := _section(cols, "Werkzeuge", 1.0)
	for id in TOOL_ORDER:
		var b := _button(tool_box)
		b.pressed.connect(_upgrade_tool.bind(id))
		_tool_buttons[id] = b

	var machine_section := _section(cols, "Baumaschinen", 1.8)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	machine_section.add_child(grid)
	for id in MACHINE_ORDER:
		var b := _button(grid)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_upgrade_machine.bind(id))
		_machine_buttons[id] = b

	var wall_box := _section(cols, "Mauer", 1.0)
	_build_button = _button(wall_box)
	_build_button.pressed.connect(_build_wall)
	_play_button = _button(wall_box)
	_play_button.add_theme_font_size_override("font_size", 20)
	_play_button.add_theme_stylebox_override("normal", _box(Color(0.75, 0.2, 0.15)))
	_play_button.add_theme_stylebox_override("hover", _box(Color(0.9, 0.3, 0.2)))
	_play_button.add_theme_stylebox_override("pressed", _box(Color(0.6, 0.15, 0.1)))
	_play_button.pressed.connect(_play)


func _section(parent: Control, title: String, ratio: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_stretch_ratio = ratio
	v.add_theme_constant_override("separation", 3)
	parent.add_child(v)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	v.add_child(l)
	return v


func _button(parent: Control) -> Button:
	var b := Button.new()
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


func _box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(6)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 13
	var panel := _box(Color(0.05, 0.1, 0.18, 0.88))
	panel.content_margin_top = 4
	panel.content_margin_bottom = 4
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("normal", "Button", _box(Color(0.16, 0.32, 0.5)))
	th.set_stylebox("hover", "Button", _box(Color(0.22, 0.42, 0.65)))
	th.set_stylebox("pressed", "Button", _box(Color(0.12, 0.25, 0.4)))
	th.set_stylebox("disabled", "Button", _box(Color(0.18, 0.2, 0.24)))
	th.set_color("font_disabled_color", "Button", Color(0.55, 0.58, 0.62))
	return th


func _refresh_ui() -> void:
	if _labels.is_empty():
		return
	_labels.level.text = "Level %d" % level
	for k in RES_ORDER:
		_labels[k].text = "%s: %d" % [RES_NAMES[k], int(res[k])]
	_labels.wall.text = "Mauer: %.1f m" % wall_height
	_labels.tsunami.text = "Tsunami: %s" % ("%.1f m" % tsunami_height if tsunami_known else "??? m")

	for id in TOOL_ORDER:
		var tl: Dictionary = tools[id]
		var c := tool_cost(id)
		var b: Button = _tool_buttons[id]
		b.text = "%s  Lv %d   (+%d %s/Klick)\nVerbessern: %s" % [tl.name, tl.level, tool_yield(id), RES_NAMES[tl.res], cost_text(c)]
		b.disabled = not can_afford(c)

	for id in MACHINE_ORDER:
		var m: Dictionary = machines[id]
		var b: Button = _machine_buttons[id]
		var effect := ""
		match id:
			"excavator": effect = "%.1f Steine + %.1f Sand/s" % [machine_rate(id), machine_rate(id) * 0.5]
			"harvester": effect = "%.1f Holz/s" % machine_rate(id)
			"mixer": effect = "%.1f Beton/s (aus Sand + Steinen)" % machine_rate(id)
			"crane": effect = "Mauerschicht %.2f m" % layer_height()
		if m.level >= m.max:
			b.text = "%s  Lv %d (max)\n%s" % [m.name, m.level, effect]
			b.disabled = true
			continue
		var c := machine_cost(id)
		var action := "Kaufen" if m.level == 0 else "Verbessern"
		var info := effect if m.level > 0 else _machine_hint(id)
		b.text = "%s  Lv %d   –  %s\n%s: %s" % [m.name, m.level, info, action, cost_text(c)]
		b.disabled = not can_afford(c)

	var wc := wall_cost()
	_build_button.text = "Mauer bauen  (+%.2f m)  [B]\n%s" % [layer_height(), cost_text(wc)]
	_build_button.disabled = tsunami_running or not can_afford(wc)
	_play_button.text = "PLAY  –  Tsunami starten  [P]" if not tsunami_running else "Tsunami läuft …"
	_play_button.disabled = tsunami_running


func _machine_hint(id: String) -> String:
	match id:
		"excavator": return "baut automatisch Steine + Sand ab"
		"harvester": return "fällt automatisch Bäume"
		"mixer": return "mischt Beton (ab 4 m nötig)"
		"crane": return "baut dickere Mauerschichten"
	return ""

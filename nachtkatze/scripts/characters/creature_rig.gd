extends Node3D
class_name CreatureRig
## Prozedurale Low-Poly-Figur mit Gliedern: Spielerkatze, Revierkatze, kleiner
## und grosser Hund (GDD Abschnitt 9 und 10).
##
## Wie das Asset-Kit entsteht alles aus Code - keine Modelldateien, keine
## Texturen: Rumpf in zwei Haelften (fuer den Katzenbuckel), Hals, Kopf mit
## Ohren, Augen und Kiefer, Schwanz in Gliedern und vier zweigliedrige Beine.
## Die Farben liegen auf den Eckpunkten, das Material ist der Toon-Shader.
##
## Animiert wird ebenfalls prozedural: jede Animation ist eine Funktion, die
## aus der Zeit eine Pose (Gelenkwinkel) berechnet. Beim Wechsel wird kurz
## ueberblendet. Vorwaerts ist +X; der Ursprung liegt in der Mitte der
## Kollisionskapsel, die Pfoten stehen bei `feet`.

enum Preset { SPIELERKATZE, REVIERKATZE, KLEINER_HUND, GROSSER_HUND }

## Masse und Farben je Figur. Laengen in Metern.
const SPECS := {
	Preset.SPIELERKATZE: {
		"dog": false, "feet": -0.275, "upper": 0.10, "lower": 0.10,
		"half_length": 0.20, "radius": 0.08, "leg_z": 0.05,
		"fur": Color(0.92, 0.50, 0.19), "dark": Color(0.72, 0.32, 0.11),
		"belly": Color(0.98, 0.91, 0.79), "paw": Color(0.98, 0.94, 0.86),
		"nose": Color(0.95, 0.60, 0.60), "eye": Color(0.42, 0.78, 0.38),
		"eye_glow": 0.7, "glow": 0.22, "stripes": true,
	},
	Preset.REVIERKATZE: {
		"dog": false, "feet": -0.275, "upper": 0.10, "lower": 0.10,
		"half_length": 0.20, "radius": 0.08, "leg_z": 0.05,
		"fur": Color(0.40, 0.41, 0.48), "dark": Color(0.27, 0.27, 0.33),
		"belly": Color(0.52, 0.53, 0.60), "paw": Color(0.46, 0.47, 0.54),
		"nose": Color(0.20, 0.18, 0.20), "eye": Color(0.80, 1.0, 0.42),
		"eye_glow": 3.2, "glow": 0.12, "stripes": true,
	},
	Preset.KLEINER_HUND: {
		"dog": true, "feet": -0.465, "upper": 0.14, "lower": 0.14,
		"half_length": 0.25, "radius": 0.10, "leg_z": 0.065,
		"fur": Color(0.80, 0.60, 0.37), "dark": Color(0.52, 0.34, 0.20),
		"belly": Color(0.95, 0.88, 0.75), "paw": Color(0.95, 0.88, 0.75),
		"nose": Color(0.14, 0.12, 0.12), "eye": Color(0.14, 0.11, 0.10),
		"eye_glow": 0.0, "glow": 0.12, "collar": Color(0.82, 0.20, 0.18),
	},
	Preset.GROSSER_HUND: {
		"dog": true, "feet": -0.465, "upper": 0.14, "lower": 0.14,
		"half_length": 0.25, "radius": 0.10, "leg_z": 0.065,
		"fur": Color(0.33, 0.28, 0.25), "dark": Color(0.20, 0.17, 0.16),
		"belly": Color(0.62, 0.47, 0.32), "paw": Color(0.62, 0.47, 0.32),
		"nose": Color(0.10, 0.09, 0.09), "eye": Color(0.85, 0.62, 0.25),
		"eye_glow": 0.5, "glow": 0.10, "collar": Color(0.25, 0.42, 0.72),
	},
}

## Alle Gelenkwerte einer Pose mit ihrer Ruhestellung.
const NEUTRAL := {
	&"x": 0.0, &"y": 0.0, &"pitch": 0.0, &"roll": 0.0, &"turn": 0.0, &"squash": 1.0,
	&"arch": 0.0, &"neck": 0.0, &"head": 0.0, &"jaw": 0.0, &"ears": 0.0, &"eyes": 1.0,
	&"tail1": 0.6, &"tail2": 0.3, &"tail3": 0.2, &"tail_sway": 0.0, &"tail_puff": 0.0,
	&"fl": 0.0, &"fr": 0.0, &"bl": 0.0, &"br": 0.0,
	&"fl_k": 0.0, &"fr_k": 0.0, &"bl_k": 0.0, &"br_k": 0.0, &"splay": 0.0,
}

const LEGS := [&"fl", &"fr", &"bl", &"br"]
const KNEES := [&"fl_k", &"fr_k", &"bl_k", &"br_k"]
const BLEND_TIME := 0.12
## Schrittfolge je Sekunde bei voller Geschwindigkeit (Bogenmass).
const RUN_RATE := 17.0
const WALK_RATE := 9.0
const CLIMB_RATE := 9.0

## Einmalige Ueberlagerungen und ihre Dauer.
const OVERLAYS := {&"land": 0.2, &"eat": 0.55, &"bark": 0.3}

static var _mesh_cache := {}

var preset: Preset = Preset.SPIELERKATZE
var animation: StringName = &"idle"
## Relative Laufgeschwindigkeit (1 = volles Tempo) - bestimmt den Schritttakt.
var move_speed := 0.0
## Senkrechte Geschwindigkeit in m/s: steigend streckt sich die Katze, fallend
## sucht sie mit den Vorderpfoten den Boden.
var vertical_speed := 0.0
## Klettertempo mit Vorzeichen (hoch = positiv).
var climb_speed := 0.0

var _spec: Dictionary = {}
var _is_dog := false
var _time := 0.0
var _phase := 0.0
var _blend := 1.0
var _pose := {}
var _from := {}
var _overlay_timers := {}

var _root: Node3D
var _hips: Node3D
var _chest: Node3D
var _neck: Node3D
var _head: Node3D
var _jaw: Node3D
var _eyes: Node3D
var _ears: Array[Node3D] = []
var _tail: Array[Node3D] = []
var _upper := {}
var _lower := {}

func _init() -> void:
	_pose = NEUTRAL.duplicate()
	_from = NEUTRAL.duplicate()

# --- Aufbau -----------------------------------------------------------------

## Baut die Figur. Mehrfacher Aufruf ersetzt die bisherige.
func setup(new_preset: Preset) -> void:
	preset = new_preset
	_spec = SPECS[preset]
	_is_dog = _spec["dog"]
	for child in get_children():
		child.queue_free()
	_ears.clear()
	_tail.clear()
	_upper.clear()
	_lower.clear()

	var hip_y: float = _spec["feet"] + _spec["upper"] + _spec["lower"]
	var radius: float = _spec["radius"]
	var half: float = _spec["half_length"]
	var torso_y := hip_y + radius * 0.7

	_root = _pivot(self, "Rumpf", Vector3(0, torso_y, 0))
	_hips = _pivot(_root, "Becken", Vector3.ZERO)
	_chest = _pivot(_root, "Brust", Vector3.ZERO)
	_part(_hips, &"hips")
	_part(_chest, &"chest")
	# Mittelstueck: schliesst die Fuge, wenn sich der Ruecken kruemmt.
	_part(_root, &"waist")

	_neck = _pivot(_chest, "Hals", Vector3(half - 0.01, radius * 0.65, 0))
	_head = _pivot(_neck, "Kopf", Vector3(0.02, 0.02, 0))
	# Etwas zu grosser Kopf: freundlicher und aus der Ferne besser lesbar.
	_head.scale = Vector3.ONE * (1.1 if _is_dog else 1.2)
	_part(_head, &"head")
	_eyes = _pivot(_head, "Augen", Vector3(0.115, 0.06, 0) if _is_dog else Vector3(0.105, 0.042, 0))
	_part(_eyes, &"eyes")
	_jaw = _pivot(_head, "Kiefer", Vector3(0.12, -0.045, 0) if _is_dog else Vector3(0.11, -0.04, 0))
	_part(_jaw, &"jaw")
	for side in [1.0, -1.0]:
		var ear := _pivot(_head, "Ohr", Vector3(0.03, 0.105, side * 0.09) if _is_dog
			else Vector3(0.04, 0.085, side * 0.05))
		_part(ear, &"ear")
		_ears.append(ear)

	var tail_count := 2 if _is_dog else 3
	var tail_step := 0.11 if _is_dog else 0.13
	var parent: Node3D = _hips
	for i in tail_count:
		var joint := _pivot(parent, "Schwanz%d" % (i + 1),
			Vector3(-half, radius * 0.4, 0) if i == 0 else Vector3(-tail_step, 0, 0))
		_part(joint, StringName("tail%d" % i))
		_tail.append(joint)
		parent = joint

	var leg_z: float = _spec["leg_z"]
	var leg_y := -radius * 0.7
	for leg in LEGS:
		var front := String(leg).begins_with("f")
		var side := 1.0 if String(leg).ends_with("l") else -1.0
		var x := (half - 0.06) if front else -(half - 0.05)
		var upper := _pivot(_chest if front else _hips, "Bein_" + String(leg),
			Vector3(x, leg_y, side * leg_z))
		_part(upper, &"upper_front" if front else &"upper_hind")
		var lower := _pivot(upper, "Unterbein", Vector3(0, -_spec["upper"], 0))
		_part(lower, &"lower")
		_upper[leg] = upper
		_lower[leg] = lower
	_apply_pose()

func _pivot(parent: Node3D, node_name: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = at
	parent.add_child(node)
	return node

func _part(parent: Node3D, part: StringName) -> void:
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = _mesh_for(part)
	instance.material_override = AssetKit.get_character_material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func _mesh_for(part: StringName) -> ArrayMesh:
	var key := "%d_%s" % [preset, part]
	if not _mesh_cache.has(key):
		var surface := MeshBuilder.create()
		_build_part(surface, part)
		_mesh_cache[key] = MeshBuilder.finish(surface)
	return _mesh_cache[key]

func _color(key: String, glow_scale: float = 1.0) -> Color:
	var color: Color = _spec[key]
	return Color(color.r, color.g, color.b, float(_spec["glow"]) * glow_scale)

## Zylinder entlang der X-Achse (Rumpf).
func _along_x() -> Basis:
	return Basis(Vector3(0, 0, 1), -PI * 0.5)

func _build_part(surface: SurfaceTool, part: StringName) -> void:
	var radius: float = _spec["radius"]
	var half: float = _spec["half_length"]
	var fur := _color("fur")
	var dark := _color("dark")
	var belly := _color("belly")
	var paw := _color("paw")
	match part:
		&"chest":
			MeshBuilder.add_cylinder(surface, Vector3(half * 0.5, 0, 0), radius, radius * 0.86,
				half, 8, fur, _along_x())
			# Heller Latz vorn unten
			MeshBuilder.add_box(surface, Vector3(half - 0.02, -radius * 0.4, 0),
				Vector3(0.06, radius, radius * 1.2), belly)
			if _spec.get("stripes", false):
				MeshBuilder.add_cylinder(surface, Vector3(half * 0.3, 0, 0), radius * 1.02,
					radius * 0.99, 0.028, 8, dark, _along_x())
			if _spec.has("collar"):
				var collar: Color = _spec["collar"]
				MeshBuilder.add_cylinder(surface, Vector3(half - 0.04, 0.01, 0), radius * 0.98,
					radius * 0.96, 0.035, 8, Color(collar.r, collar.g, collar.b, 0.15), _along_x())
		&"waist":
			MeshBuilder.add_cylinder(surface, Vector3.ZERO, radius * 1.0, radius * 1.0,
				radius * 1.1, 8, fur, _along_x())
		&"hips":
			MeshBuilder.add_cylinder(surface, Vector3(-half * 0.5, 0, 0), radius * 0.9, radius,
				half, 8, fur, _along_x())
			if _spec.get("stripes", false):
				for x in [-half * 0.3, -half * 0.72]:
					MeshBuilder.add_cylinder(surface, Vector3(x, 0, 0), radius * 0.99,
						radius * 1.02, 0.028, 8, dark, _along_x())
		&"head":
			if _is_dog:
				MeshBuilder.add_box(surface, Vector3(0.07, 0.03, 0), Vector3(0.17, 0.16, 0.17), fur)
				MeshBuilder.add_box(surface, Vector3(0.19, -0.005, 0), Vector3(0.12, 0.085, 0.10), belly)
				MeshBuilder.add_box(surface, Vector3(0.255, 0.02, 0), Vector3(0.022, 0.035, 0.05),
					_color("nose", 0.0))
				MeshBuilder.add_box(surface, Vector3(0.17, -0.05, 0), Vector3(0.10, 0.012, 0.07),
					Color(0.45, 0.12, 0.14, 0.0))
			else:
				MeshBuilder.add_box(surface, Vector3(0.06, 0.02, 0), Vector3(0.15, 0.13, 0.16), fur)
				MeshBuilder.add_box(surface, Vector3(0.145, -0.012, 0), Vector3(0.05, 0.06, 0.10), belly)
				MeshBuilder.add_box(surface, Vector3(0.173, 0.006, 0), Vector3(0.012, 0.02, 0.03),
					_color("nose", 0.0))
				MeshBuilder.add_box(surface, Vector3(0.135, -0.043, 0), Vector3(0.05, 0.01, 0.06),
					Color(0.45, 0.12, 0.14, 0.0))
				if _spec.get("stripes", false):
					MeshBuilder.add_box(surface, Vector3(0.06, 0.088, 0), Vector3(0.10, 0.008, 0.05), dark)
		&"eyes":
			var eye: Color = _spec["eye"]
			var eye_color := Color(eye.r, eye.g, eye.b, _spec["eye_glow"])
			# Die Augen sitzen seitlich am Kopf - das Spiel zeigt die Figuren im Profil.
			var spread := 0.086 if _is_dog else 0.081
			for side in [1.0, -1.0]:
				MeshBuilder.add_box(surface, Vector3(0, 0, side * spread),
					Vector3(0.04, 0.04, 0.012), eye_color)
				if not _is_dog:
					# Schlitzpupille
					MeshBuilder.add_box(surface, Vector3(0.004, 0, side * (spread + 0.005)),
						Vector3(0.012, 0.034, 0.008), Color(0.05, 0.05, 0.06, 0.0))
				else:
					MeshBuilder.add_box(surface, Vector3(0.008, 0.008, side * (spread + 0.005)),
						Vector3(0.012, 0.012, 0.008), Color(1.0, 1.0, 1.0, 0.3))
		&"jaw":
			if _is_dog:
				MeshBuilder.add_box(surface, Vector3(0.06, -0.012, 0), Vector3(0.12, 0.025, 0.085), belly)
				MeshBuilder.add_box(surface, Vector3(0.07, 0.003, 0), Vector3(0.08, 0.008, 0.05),
					Color(0.92, 0.50, 0.55, 0.0))
			else:
				MeshBuilder.add_box(surface, Vector3(0.03, -0.008, 0), Vector3(0.065, 0.02, 0.085), belly)
		&"ear":
			if _is_dog:
				MeshBuilder.add_box(surface, Vector3(0, -0.06, 0), Vector3(0.065, 0.13, 0.028), dark)
			else:
				MeshBuilder.add_cylinder(surface, Vector3(0, 0.035, 0), 0.038, 0.0, 0.075, 4, fur)
				MeshBuilder.add_box(surface, Vector3(0.012, 0.022, 0), Vector3(0.012, 0.035, 0.03),
					_color("nose", 0.0))
		&"tail0", &"tail1", &"tail2":
			var index := int(String(part).right(1))
			var length := 0.12 if _is_dog else 0.14
			var thickness: float = [0.046, 0.040, 0.034][index]
			var last := index == (1 if _is_dog else 2)
			var tip := paw if (last and not _spec.get("stripes", false)) else fur
			MeshBuilder.add_box(surface, Vector3(-length * 0.5 + 0.005, 0, 0),
				Vector3(length, thickness, thickness), tip)
			if _spec.get("stripes", false):
				MeshBuilder.add_box(surface, Vector3(-length * 0.55, 0, 0),
					Vector3(0.03, thickness * 1.06, thickness * 1.06), dark)
		&"upper_front", &"upper_hind":
			var upper: float = _spec["upper"]
			var width := 0.05 if not _is_dog else 0.06
			if part == &"upper_hind":
				width *= 1.35   # kraeftiger Oberschenkel
			MeshBuilder.add_box(surface, Vector3(0, -upper * 0.5, 0),
				Vector3(width, upper + 0.02, 0.05 if not _is_dog else 0.06), fur)
		&"lower":
			var lower: float = _spec["lower"]
			var width := 0.04 if not _is_dog else 0.05
			MeshBuilder.add_box(surface, Vector3(0, -lower * 0.47, 0),
				Vector3(width, lower * 0.94, width), fur)
			MeshBuilder.add_box(surface, Vector3(0.013, -lower + 0.012, 0),
				Vector3(width + 0.026, 0.026, width + 0.016), paw)

# --- Steuerung --------------------------------------------------------------

## Wechselt die Animation; die bisherige Pose blendet weich hinueber.
func play(new_animation: StringName, restart: bool = false) -> void:
	if new_animation == animation and not restart:
		return
	animation = new_animation
	_from = _pose.duplicate()
	_blend = 0.0
	_time = 0.0

## Kurze Ueberlagerung ueber die laufende Animation: &"land", &"eat", &"bark".
func trigger(overlay: StringName) -> void:
	if OVERLAYS.has(overlay):
		_overlay_timers[overlay] = 0.0

func is_overlay_active(overlay: StringName) -> bool:
	return _overlay_timers.has(overlay)

## Aktueller Wert eines Gelenks - fuer Tests und Feinabstimmung.
func get_pose_value(joint: StringName) -> float:
	return _pose.get(joint, 0.0)

func _process(delta: float) -> void:
	advance(delta)

## Schreibt die Animation um delta weiter (auch direkt aus Tests aufrufbar).
func advance(delta: float) -> void:
	if _root == null:
		return
	_time += delta
	match animation:
		&"run", &"chase":
			_phase += delta * RUN_RATE * clampf(move_speed, 0.35, 1.4)
		&"walk", &"retreat", &"balance":
			_phase += delta * WALK_RATE * clampf(move_speed, 0.4, 1.6)
		&"climb":
			_phase += delta * CLIMB_RATE * clampf(climb_speed, -1.5, 1.5)
	for overlay in _overlay_timers.keys():
		_overlay_timers[overlay] += delta
		if _overlay_timers[overlay] >= OVERLAYS[overlay]:
			_overlay_timers.erase(overlay)

	var target := _compute_pose()
	_blend = minf(_blend + delta / BLEND_TIME, 1.0)
	var weight := smoothstep(0.0, 1.0, _blend)
	for joint in target:
		_pose[joint] = lerpf(_from.get(joint, target[joint]), target[joint], weight) \
			if _blend < 1.0 else target[joint]
	_apply_pose()

# --- Posen ------------------------------------------------------------------

func _compute_pose() -> Dictionary:
	var p := NEUTRAL.duplicate()
	if _is_dog:
		p[&"tail1"] = 0.9
		p[&"tail2"] = 0.3
	var t := _time
	match animation:
		&"idle": _pose_idle(p, t)
		&"walk": _pose_walk(p, 0.42, 0.7)
		&"retreat": _pose_retreat(p)
		&"run": _pose_run(p)
		&"chase": _pose_chase(p)
		&"jump": _pose_jump(p)
		&"attack": _pose_attack(p)
		&"climb": _pose_climb(p)
		&"hang": _pose_hang(p, t)
		&"mantle": _pose_mantle(p, t)
		&"balance": _pose_balance(p, t)
		&"hurt": _pose_hurt(p, t)
		&"victory": _pose_sit(p, t, true)
		&"sit": _pose_sit(p, t, false)
		&"dead": _pose_dead(p)
		&"warn": _pose_warn(p, t)
		&"sleep": _pose_sleep(p, t)
		&"rest": _pose_rest(p, t)
		&"bark_up": _pose_bark_up(p, t)
		_: _pose_idle(p, t)
	_apply_overlays(p)
	return p

## Stehen: atmen, Schwanz pendelt, ab und zu zuckt ein Ohr.
func _pose_idle(p: Dictionary, t: float) -> void:
	p[&"squash"] = 1.0 + sin(t * 2.2) * 0.012
	p[&"tail1"] = (0.9 if not _is_dog else 0.8) + sin(t * 1.3) * 0.15
	p[&"tail2"] = 0.45
	p[&"tail3"] = 0.4 + sin(t * 1.7 + 1.0) * 0.3
	p[&"tail_sway"] = sin(t * (0.9 if not _is_dog else 5.0)) * (0.25 if not _is_dog else 0.4)
	p[&"head"] = sin(t * 0.8) * 0.05
	p[&"ears"] = pow(maxf(sin(t * 0.7), 0.0), 20.0) * 0.4

## Schrittfolge im Kreuzgang: diagonale Beine bewegen sich gemeinsam.
func _legs_cycle(p: Dictionary, swing: float, lift: float, offsets: Array) -> void:
	for i in LEGS.size():
		var angle: float = _phase + offsets[i]
		p[LEGS[i]] = sin(angle) * swing
		p[KNEES[i]] = maxf(cos(angle), 0.0) * lift

func _pose_walk(p: Dictionary, swing: float, lift: float) -> void:
	_legs_cycle(p, swing, lift, [0.0, PI, PI, 0.0])
	p[&"y"] = cos(_phase * 2.0) * 0.006
	p[&"head"] = sin(_phase * 2.0) * 0.04
	p[&"tail1"] = 1.0 if not _is_dog else 0.9
	p[&"tail2"] = 0.3
	p[&"tail3"] = 0.3
	p[&"tail_sway"] = sin(_phase) * (0.2 if not _is_dog else 0.55)

## Rueckzug bzw. Rueckkehr: gleicher Gang, aber Kopf und Schwanz haengen.
func _pose_retreat(p: Dictionary) -> void:
	_pose_walk(p, 0.4, 0.6)
	p[&"tail1"] = 0.05
	p[&"tail2"] = -0.1
	p[&"tail3"] = 0.0
	p[&"tail_sway"] = 0.0
	p[&"neck"] = -0.2

## Laufen im Galopp: Vorder- und Hinterbeine paarweise, der Rumpf wippt.
func _pose_run(p: Dictionary) -> void:
	_legs_cycle(p, 0.85, 1.1, [0.0, 0.55, PI, PI + 0.55])
	p[&"pitch"] = sin(_phase + 0.3) * 0.10
	p[&"y"] = 0.012 + cos(_phase) * 0.014
	p[&"arch"] = sin(_phase) * 0.12
	p[&"head"] = -sin(_phase + 0.3) * 0.08
	p[&"tail1"] = 0.25 + sin(_phase) * 0.12
	p[&"tail2"] = 0.1
	p[&"tail3"] = 0.05 + sin(_phase + 1.0) * 0.15
	p[&"ears"] = 0.25

func _pose_chase(p: Dictionary) -> void:
	_pose_run(p)
	p[&"ears"] = 0.5 + sin(_phase * 2.0) * 0.3
	p[&"jaw"] = 0.25
	p[&"neck"] = -0.1

## Springen: steigend gestreckt, fallend mit den Vorderpfoten voraus.
func _pose_jump(p: Dictionary) -> void:
	var rise := clampf(vertical_speed / 7.0, -1.0, 1.0)
	var up := maxf(rise, 0.0)
	var down := maxf(-rise, 0.0)
	p[&"pitch"] = up * 0.38 - down * 0.32
	p[&"fl"] = 0.6 + up * 0.5 + down * 0.1
	p[&"fr"] = 0.45 + up * 0.5 + down * 0.1
	p[&"fl_k"] = 0.25 + down * 0.3
	p[&"fr_k"] = 0.25 + down * 0.3
	p[&"bl"] = -0.9 * up + 0.5 * down
	p[&"br"] = -0.75 * up + 0.4 * down
	p[&"bl_k"] = 0.2 + down * 0.9
	p[&"br_k"] = 0.2 + down * 0.9
	p[&"tail1"] = 0.3 + down * 0.7
	p[&"tail2"] = 0.1 + down * 0.3
	p[&"tail3"] = 0.1
	p[&"ears"] = 0.3
	p[&"head"] = -up * 0.2 + down * 0.25

## Angriffssprung der Revierkatze: wie ein Sprung, Krallen und Maul voraus.
func _pose_attack(p: Dictionary) -> void:
	_pose_jump(p)
	p[&"fl"] = 1.15
	p[&"fr"] = 0.95
	p[&"fl_k"] = 0.1
	p[&"fr_k"] = 0.1
	p[&"jaw"] = 0.6
	p[&"ears"] = 1.0
	p[&"tail_puff"] = 0.6

## Klettern: Ruecken zur Kamera, die Beine greifen abwechselnd nach oben.
func _pose_climb(p: Dictionary) -> void:
	p[&"turn"] = 1.0
	p[&"splay"] = 0.95
	var reach := sin(_phase)
	p[&"fl"] = 0.35 + reach * 0.55
	p[&"fr"] = 0.35 - reach * 0.55
	p[&"bl"] = -0.1 - reach * 0.45
	p[&"br"] = -0.1 + reach * 0.45
	p[&"fl_k"] = 0.5 - reach * 0.3
	p[&"fr_k"] = 0.5 + reach * 0.3
	p[&"bl_k"] = 0.6 + reach * 0.3
	p[&"br_k"] = 0.6 - reach * 0.3
	p[&"y"] = absf(cos(_phase)) * 0.012
	p[&"tail1"] = 0.1
	p[&"tail2"] = 0.1
	p[&"tail3"] = 0.1
	p[&"tail_sway"] = sin(_phase * 0.5) * 0.45
	p[&"head"] = 0.15

## An der Kante haengen: Vorderpfoten oben, Hinterbeine baumeln.
func _pose_hang(p: Dictionary, t: float) -> void:
	p[&"pitch"] = 1.3
	p[&"x"] = -0.05
	p[&"fl"] = 1.25
	p[&"fr"] = 1.15
	p[&"fl_k"] = 0.2
	p[&"fr_k"] = 0.2
	var swing := sin(t * 3.2) * 0.18
	p[&"bl"] = -0.25 + swing
	p[&"br"] = -0.1 - swing
	p[&"bl_k"] = 0.5
	p[&"br_k"] = 0.4
	p[&"neck"] = -0.5
	p[&"head"] = -0.4
	p[&"tail1"] = -0.2
	p[&"tail2"] = 0.2
	p[&"tail3"] = 0.3
	p[&"tail_sway"] = swing * 2.0
	p[&"ears"] = 0.3

## Hochziehen: aus dem Haengen in die Hocke.
func _pose_mantle(p: Dictionary, t: float) -> void:
	var done := clampf(t / 0.25, 0.0, 1.0)
	p[&"pitch"] = lerpf(1.1, 0.15, done)
	p[&"fl"] = lerpf(1.2, 0.5, done)
	p[&"fr"] = lerpf(1.1, 0.4, done)
	p[&"fl_k"] = lerpf(0.3, 0.9, done)
	p[&"fr_k"] = lerpf(0.3, 0.9, done)
	p[&"bl"] = lerpf(-0.3, 0.7, done)
	p[&"br"] = lerpf(-0.2, 0.6, done)
	p[&"bl_k"] = 1.2
	p[&"br_k"] = 1.2
	p[&"tail1"] = 0.4
	p[&"ears"] = 0.4

## Balancieren: geduckt, kleine Schritte, der Schwanz gleicht aus.
func _pose_balance(p: Dictionary, t: float) -> void:
	_legs_cycle(p, 0.3, 0.5, [0.0, PI, PI, 0.0])
	for i in LEGS.size():
		p[LEGS[i]] += 0.22
		p[KNEES[i]] += 0.45
	p[&"y"] = -0.012
	p[&"roll"] = sin(t * 5.0) * 0.09
	p[&"tail1"] = 1.25
	p[&"tail2"] = 0.25
	p[&"tail3"] = 0.2
	p[&"tail_sway"] = sin(t * 5.0 + PI) * 0.7
	p[&"neck"] = -0.15
	p[&"ears"] = 0.2

## Treffer: zusammenzucken, Ohren angelegt, Schwanz gestraeubt.
func _pose_hurt(p: Dictionary, t: float) -> void:
	p[&"pitch"] = 0.35
	p[&"arch"] = -0.25
	p[&"fl"] = 0.8
	p[&"fr"] = 0.6
	p[&"bl"] = -0.6
	p[&"br"] = -0.45
	p[&"fl_k"] = 0.3
	p[&"br_k"] = 0.3
	p[&"ears"] = 1.0
	p[&"eyes"] = 0.2
	p[&"jaw"] = 0.55
	p[&"tail1"] = 1.4
	p[&"tail2"] = 0.2
	p[&"tail_puff"] = 0.8
	p[&"x"] = sin(t * 50.0) * 0.006

## Sitzen. Als Sieg sitzt die Katze am Napf, frisst und schnurrt.
func _pose_sit(p: Dictionary, t: float, eating: bool) -> void:
	p[&"pitch"] = 0.55
	p[&"y"] = -0.045
	p[&"x"] = -0.02
	p[&"bl"] = 1.0
	p[&"br"] = 1.0
	p[&"bl_k"] = 2.3
	p[&"br_k"] = 2.3
	p[&"fl"] = -0.55
	p[&"fr"] = -0.55
	p[&"neck"] = -0.35
	p[&"tail1"] = -0.35
	p[&"tail2"] = 0.2
	p[&"tail3"] = 0.3
	p[&"tail_sway"] = 1.1 + sin(t * 1.4) * 0.12
	if eating:
		var dip := 0.5 + 0.5 * sin(t * 2.0)
		p[&"neck"] = -0.55 - dip * 0.35
		p[&"head"] = -0.45 - dip * 0.25
		p[&"jaw"] = absf(sin(t * 11.0)) * 0.3 * dip
		p[&"eyes"] = 0.25
		# Schnurren: ganz leichtes, schnelles Beben
		p[&"squash"] = 1.0 + sin(t * 4.0) * 0.02 + sin(t * 55.0) * 0.004
		p[&"tail3"] = 0.3 + sin(t * 2.5) * 0.3
	else:
		p[&"head"] = -0.15 + sin(t * 0.7) * 0.08
		p[&"squash"] = 1.0 + sin(t * 2.0) * 0.012
		p[&"tail3"] = 0.3 + pow(maxf(sin(t * 1.1), 0.0), 6.0) * 0.6
		p[&"ears"] = pow(maxf(sin(t * 0.6 + 2.0), 0.0), 20.0) * 0.4

## Am Boden: alle viere von sich, Augen zu.
func _pose_dead(p: Dictionary) -> void:
	var drop: float = _spec["upper"] + _spec["lower"] - 0.035
	p[&"y"] = -drop
	p[&"fl"] = 1.45
	p[&"fr"] = 1.35
	p[&"bl"] = -1.4
	p[&"br"] = -1.3
	p[&"neck"] = -0.45
	p[&"head"] = -0.25
	p[&"ears"] = 1.0
	p[&"eyes"] = 0.08
	p[&"tail1"] = -0.1
	p[&"tail2"] = 0.0
	p[&"tail3"] = 0.0

## Warnung. Katze: Buckel und Fauchen. Kleiner Hund: Klaeffen. Grosser: Knurren.
func _pose_warn(p: Dictionary, t: float) -> void:
	if not _is_dog:
		p[&"arch"] = 0.55
		p[&"y"] = 0.04
		p[&"fl"] = 0.5
		p[&"fr"] = 0.5
		p[&"bl"] = -0.5
		p[&"br"] = -0.5
		p[&"neck"] = -0.25
		p[&"head"] = 0.2
		p[&"ears"] = 1.0
		p[&"jaw"] = 0.5 + sin(t * 30.0) * 0.08
		p[&"tail1"] = 1.5
		p[&"tail2"] = 0.05
		p[&"tail3"] = -0.1
		p[&"tail_puff"] = 1.0
		p[&"x"] = sin(t * 42.0) * 0.005
	elif preset == Preset.KLEINER_HUND:
		var yap := maxf(sin(t * 16.0), 0.0)
		p[&"y"] = yap * 0.03
		p[&"pitch"] = 0.08 + yap * 0.1
		p[&"head"] = 0.2 + yap * 0.25
		p[&"jaw"] = yap * 0.75
		p[&"tail1"] = 1.3
		p[&"tail_sway"] = sin(t * 30.0) * 0.15
		p[&"ears"] = 0.4 + yap * 0.3
	else:
		p[&"neck"] = -0.4
		p[&"head"] = 0.2
		p[&"jaw"] = 0.22
		p[&"arch"] = 0.18
		p[&"fl"] = 0.3
		p[&"fr"] = 0.3
		p[&"bl"] = -0.18
		p[&"br"] = -0.18
		p[&"ears"] = 0.6
		p[&"tail1"] = 0.15
		p[&"tail2"] = 0.0
		p[&"x"] = sin(t * 45.0) * 0.004

## Schlafender Hund: flach am Boden, ruhiger Atem.
func _pose_sleep(p: Dictionary, t: float) -> void:
	var drop: float = _spec["upper"] + _spec["lower"] - 0.04
	p[&"y"] = -drop
	p[&"fl"] = 1.5
	p[&"fr"] = 1.45
	p[&"fl_k"] = 0.1
	p[&"bl"] = 1.3
	p[&"br"] = 1.3
	p[&"bl_k"] = 2.5
	p[&"br_k"] = 2.5
	p[&"neck"] = -0.55
	p[&"head"] = -0.2
	p[&"eyes"] = 0.06
	p[&"tail1"] = -0.1
	p[&"tail2"] = 0.2
	p[&"squash"] = 1.0 + sin(t * 1.6) * 0.045

## Ruhen: stehen, hecheln, wedeln.
func _pose_rest(p: Dictionary, t: float) -> void:
	_pose_idle(p, t)
	p[&"jaw"] = 0.22 + sin(t * 9.0) * 0.1
	p[&"head"] = sin(t * 0.6) * 0.15

## Bellen nach oben: vorn hochgestemmt, Maul im Takt.
func _pose_bark_up(p: Dictionary, t: float) -> void:
	var bark := maxf(sin(t * 13.0), 0.0)
	p[&"pitch"] = 0.5 + bark * 0.06
	p[&"y"] = 0.05
	p[&"bl"] = -0.5
	p[&"br"] = -0.5
	p[&"fl"] = 0.5 + sin(t * 9.0) * 0.3
	p[&"fr"] = 0.5 - sin(t * 9.0) * 0.3
	p[&"fl_k"] = 0.6
	p[&"fr_k"] = 0.6
	p[&"neck"] = 0.25
	p[&"head"] = 0.3 + bark * 0.15
	p[&"jaw"] = bark * 0.8
	p[&"tail1"] = 1.1
	p[&"tail_sway"] = sin(t * 16.0) * 0.5

func _apply_overlays(p: Dictionary) -> void:
	if _overlay_timers.has(&"land"):
		# Landen: kurz in die Knie gehen.
		var done: float = _overlay_timers[&"land"] / OVERLAYS[&"land"]
		var crouch := sin(done * PI)
		for i in LEGS.size():
			p[LEGS[i]] += 0.45 * crouch
			p[KNEES[i]] += 0.9 * crouch
		p[&"y"] -= 0.02 * crouch
		p[&"squash"] *= 1.0 - 0.12 * crouch
	if _overlay_timers.has(&"eat"):
		# Fressen: Kopf runter, kauen.
		var done: float = _overlay_timers[&"eat"] / OVERLAYS[&"eat"]
		var dip := sin(done * PI)
		p[&"neck"] -= 0.5 * dip
		p[&"head"] -= 0.35 * dip
		p[&"jaw"] = maxf(p[&"jaw"], absf(sin(done * 16.0)) * 0.4 * dip)
		p[&"eyes"] = minf(p[&"eyes"], 1.0 - 0.6 * dip)
	if _overlay_timers.has(&"bark"):
		var done: float = _overlay_timers[&"bark"] / OVERLAYS[&"bark"]
		var open := sin(done * PI)
		p[&"jaw"] = maxf(p[&"jaw"], open * 0.8)
		p[&"head"] += open * 0.2

# --- Pose anwenden ------------------------------------------------------------

func _apply_pose() -> void:
	var p := _pose
	# Beim Klettern dreht die Figur der Kamera den Ruecken zu; ist die Figur
	# gespiegelt (Blick nach links), muss die Drehung andersherum laufen.
	var flipped := false
	var holder := get_parent() as Node3D
	if holder != null:
		flipped = absf(wrapf(holder.rotation.y, -PI, PI)) > PI * 0.5
	var climb := Basis(Vector3(0, 0, 1), PI * 0.5) * Basis(Vector3(1, 0, 0), -PI * 0.5 if flipped else PI * 0.5)
	var turned := Basis.IDENTITY.slerp(climb, clampf(p[&"turn"], 0.0, 1.0))
	var radius: float = _spec["radius"]
	var hip_y: float = _spec["feet"] + _spec["upper"] + _spec["lower"]
	_root.basis = turned * Basis(Vector3(0, 0, 1), p[&"pitch"]) * Basis(Vector3(1, 0, 0), p[&"roll"])
	_root.scale = Vector3(1.0, p[&"squash"], 1.0)
	_root.position = Vector3(p[&"x"], hip_y + radius * 0.7 + p[&"y"] + absf(p[&"arch"]) * 0.05, 0)
	_chest.rotation.z = -p[&"arch"]
	_hips.rotation.z = p[&"arch"]
	_neck.rotation.z = p[&"neck"]
	_head.rotation.z = p[&"head"]
	_jaw.rotation.z = -p[&"jaw"]
	_eyes.scale = Vector3(1.0, lerpf(0.1, 1.0, clampf(p[&"eyes"], 0.0, 1.0)), 1.0)
	for i in _ears.size():
		if _is_dog:
			_ears[i].rotation.z = p[&"ears"] * 0.9
		else:
			_ears[i].rotation.z = p[&"ears"] * 1.1
			_ears[i].rotation.x = (0.25 if i == 0 else -0.25) * (1.0 + p[&"ears"])
	var tail_keys := [&"tail1", &"tail2", &"tail3"]
	var puff: float = 1.0 + float(p[&"tail_puff"]) * 0.7
	for i in _tail.size():
		_tail[i].rotation.z = -p[tail_keys[i]]
		(_tail[i].get_child(0) as Node3D).scale = Vector3(1.0, puff, puff)
	if not _tail.is_empty():
		_tail[0].rotation.y = p[&"tail_sway"]
	for i in LEGS.size():
		var leg: StringName = LEGS[i]
		var side := 1.0 if String(leg).ends_with("l") else -1.0
		var upper: Node3D = _upper[leg]
		upper.rotation = Vector3(-side * p[&"splay"], 0.0, p[leg])
		(_lower[leg] as Node3D).rotation.z = -p[KNEES[i]]

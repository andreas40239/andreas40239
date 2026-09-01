class_name TouchControls
extends Control
## Touch gestures → InputHandler signals (GDD 3, 11.6).
## D-pad = movement/lanes. Swipes ON the action buttons = directional attacks.

const DPAD_HALF := 62.0
const BTN_R := 24.0
const HIT_PAD := 12.0
const SWIPE_MIN := 15.0
const CHARGE_HOLD := 0.32

var fingers := {}  # index -> {zone, start, time, charging, dpad_dir}
var player: Player
var dpad_center := Vector2(71, 566)
var atk_c := Vector2(302, 468)
var jmp_c := Vector2(302, 528)
var spc_c := Vector2(294, 592)

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()
	get_viewport().size_changed.connect(_layout)

func _layout() -> void:
	# anchor cluster to the real screen corners (expand stretch adds space)
	var vs := get_viewport_rect().size
	dpad_center = Vector2(71, vs.y - 74)
	atk_c = Vector2(vs.x - 58, vs.y - 186)
	jmp_c = Vector2(vs.x - 58, vs.y - 122)
	spc_c = Vector2(vs.x - 66, vs.y - 46)
	for c in get_children():
		c.queue_free()
	var dpad := TextureRect.new()
	dpad.texture = load("res://assets/sprites/ui/dpad.png")
	dpad.position = dpad_center - Vector2(DPAD_HALF, DPAD_HALF)
	dpad.size = Vector2(DPAD_HALF * 2, DPAD_HALF * 2)
	dpad.stretch_mode = TextureRect.STRETCH_SCALE
	dpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dpad)
	_mk_btn("btn_attack", atk_c, BTN_R)
	_mk_btn("btn_jump", jmp_c, BTN_R)
	_mk_btn("btn_special", spc_c, BTN_R + 4)

func _mk_btn(tex: String, center: Vector2, r: float) -> void:
	var b := TextureRect.new()
	b.texture = load("res://assets/sprites/ui/%s.png" % tex)
	b.position = center - Vector2(r, r)
	b.size = Vector2(r * 2, r * 2)
	b.stretch_mode = TextureRect.STRETCH_SCALE
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.name = tex
	add_child(b)

func _process(delta: float) -> void:
	for id in fingers:
		var f: Dictionary = fingers[id]
		f["time"] += delta
		if f["zone"] == "attack" and not f["charging"] and f["time"] > CHARGE_HOLD:
			f["charging"] = true
			InputHandler.attack_charge_start.emit()
	# dim special while on cooldown
	var spc := get_node_or_null("btn_special")
	if spc and is_instance_valid(player):
		spc.modulate = Color(1, 1, 1) if player.special_cd <= 0.0 else Color(0.5, 0.5, 0.5, 0.7)

func _to_local_pos(pos: Vector2) -> Vector2:
	# convert window coords to 360x640 canvas coords under canvas_items scaling
	return get_global_transform_with_canvas().affine_inverse() * pos

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos := _to_local_pos(event.position)
		if event.pressed:
			_press(event.index, pos)
		else:
			_release(event.index, pos)
	elif event is InputEventScreenDrag:
		_drag(event.index, _to_local_pos(event.position))
	elif event is InputEventKey:
		_keyboard(event)

func _zone_at(pos: Vector2) -> String:
	if pos.distance_to(atk_c) < BTN_R + HIT_PAD:
		return "attack"
	if pos.distance_to(jmp_c) < BTN_R + HIT_PAD:
		return "jump"
	if pos.distance_to(spc_c) < BTN_R + HIT_PAD + 4:
		return "special"
	if pos.x < 190 and pos.y > get_viewport_rect().size.y - 170:
		return "dpad"
	return ""

func _press(id: int, pos: Vector2) -> void:
	var zone := _zone_at(pos)
	if zone == "":
		return
	fingers[id] = {"zone": zone, "start": pos, "time": 0.0, "charging": false, "dpad_dir": 0}
	if zone == "dpad":
		_dpad_update(id, pos)

func _dpad_update(id: int, pos: Vector2) -> void:
	var d := pos - dpad_center
	var f: Dictionary = fingers[id]
	if absf(d.y) > absf(d.x) and absf(d.y) > 14.0:
		var dir := -1 if d.y < 0 else 1
		if f["dpad_dir"] != dir:
			f["dpad_dir"] = dir
			if dir < 0:
				InputHandler.lane_up.emit()
			else:
				InputHandler.lane_down.emit()
		InputHandler.move_axis = 0.0
	elif absf(d.x) > 12.0:
		f["dpad_dir"] = 0
		InputHandler.move_axis = signf(d.x)
	else:
		f["dpad_dir"] = 0
		InputHandler.move_axis = 0.0

func _drag(id: int, pos: Vector2) -> void:
	if not fingers.has(id):
		return
	if fingers[id]["zone"] == "dpad":
		_dpad_update(id, pos)

func _release(id: int, pos: Vector2) -> void:
	if not fingers.has(id):
		return
	var f: Dictionary = fingers[id]
	fingers.erase(id)
	var swipe: Vector2 = pos - f["start"]
	match f["zone"]:
		"dpad":
			InputHandler.move_axis = 0.0
		"attack":
			if f["charging"]:
				InputHandler.attack_charge_release.emit()
			elif swipe.length() > SWIPE_MIN:
				InputHandler.attack_swipe.emit(_dominant(swipe))
			else:
				InputHandler.attack_tap.emit()
		"jump":
			if swipe.length() > SWIPE_MIN:
				InputHandler.jump_swipe.emit(_dominant(swipe))
			else:
				InputHandler.jump_tap.emit()
		"special":
			InputHandler.special_tap.emit()

func _dominant(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2(signf(v.x), 0)
	return Vector2(0, signf(v.y))

# ---------- keyboard fallback (desktop testing) ----------
var _z_held_t := -1.0

func _keyboard(e: InputEventKey) -> void:
	if e.echo:
		return
	match e.keycode:
		KEY_UP:
			if e.pressed: InputHandler.lane_up.emit()
		KEY_DOWN:
			if e.pressed: InputHandler.lane_down.emit()
		KEY_LEFT:
			InputHandler.move_axis = -1.0 if e.pressed else 0.0
		KEY_RIGHT:
			InputHandler.move_axis = 1.0 if e.pressed else 0.0
		KEY_Z:
			if e.pressed:
				InputHandler.attack_tap.emit()
		KEY_A:
			if e.pressed:
				InputHandler.attack_charge_start.emit()
			else:
				InputHandler.attack_charge_release.emit()
		KEY_Q:
			if e.pressed: InputHandler.attack_swipe.emit(Vector2.UP)
		KEY_E:
			if e.pressed: InputHandler.attack_swipe.emit(Vector2.DOWN)
		KEY_R:
			if e.pressed: InputHandler.attack_swipe.emit(Vector2.RIGHT)
		KEY_X:
			if e.pressed: InputHandler.jump_tap.emit()
		KEY_V:
			if e.pressed: InputHandler.jump_swipe.emit(Vector2.UP)
		KEY_C:
			if e.pressed: InputHandler.jump_swipe.emit(Vector2.DOWN)
		KEY_SPACE:
			if e.pressed: InputHandler.special_tap.emit()

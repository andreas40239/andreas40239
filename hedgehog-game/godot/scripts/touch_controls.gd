extends Control
## On-screen controls for phones and tablets.
##  - Left thumb: a floating joystick that appears wherever the thumb lands.
##  - Right thumb: hold-buttons for Sniff and Roll.
##  - Tap an item in the garden (when the hedgehog is close) to use it.
##  - Swipe on empty screen space to look around.
## Shown only in touch mode (see Game.touch_mode).

const JOYSTICK_RADIUS := 90.0
const KNOB_RADIUS := 42.0
const BUTTON_RADIUS := 82.0
## A touch shorter and stiller than this counts as a tap.
const TAP_TIME := 0.35
const TAP_MOVE := 24.0
## How far from an item's screen position a tap may land and still count.
const TAP_PICK_RADIUS := 110.0
const SWIPE_SENSITIVITY := 0.008
const EDGE_MARGIN := 24.0

const SNIFF_COLOR := Color(0.35, 0.8, 0.45)
const ROLL_COLOR := Color(0.75, 0.5, 0.3)
const HIGHLIGHT_COLOR := Color(1.0, 0.85, 0.2)

@export var player_path: NodePath
@export var camera_rig_path: NodePath
@export var hud_path: NodePath

## Set by the tutorial to make one control pulse:
## "", "joystick", "look", "sniff", "roll" or "tap".
var highlight := ""

var _player: Hedgehog
var _rig: Node
var _hud: Node
var _font: Font
var _time := 0.0
## finger index -> {"role": String, "start": Vector2, "time": float, "moved": float}
var _touches := {}
var _joy_finger := -1
var _joy_center := Vector2.ZERO
var _joy_vector := Vector2.ZERO
var _sniff_pressed := false
var _roll_pressed := false
var _taps: Array = []  # [position, time] for the little tap ripple
var _inset_left := 0.0
var _inset_right := 0.0


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_player = get_node(player_path)
	_rig = get_node(camera_rig_path)
	_hud = get_node_or_null(hud_path)
	_font = ThemeDB.fallback_font
	Game.input_mode_changed.connect(_on_input_mode_changed)
	_on_input_mode_changed(Game.touch_mode)


# --- Layout --------------------------------------------------------------------

func sniff_center() -> Vector2:
	return Vector2(size.x - _inset_right - EDGE_MARGIN - BUTTON_RADIUS - 10.0, size.y - 290.0)


func roll_center() -> Vector2:
	return Vector2(size.x - _inset_right - EDGE_MARGIN - BUTTON_RADIUS * 3.0 - 10.0, size.y - EDGE_MARGIN - BUTTON_RADIUS - 30.0)


## Where the joystick rests (and is drawn faintly) when no thumb is on it.
func joystick_home() -> Vector2:
	return Vector2(_inset_left + EDGE_MARGIN + JOYSTICK_RADIUS + 60.0, size.y - EDGE_MARGIN - JOYSTICK_RADIUS - 50.0)


func joystick_vector() -> Vector2:
	return _joy_vector


# --- Input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not visible:
		# The first touch switches touch mode on; don't lose that touch.
		Game.set_touch_mode(true)
	if not visible or (_hud and _hud.is_showing_results()):
		return  # The results screen handles its own taps.
	if event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
	elif event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
		_touch_drag(event.index, event.position, event.relative)


func _exit_tree() -> void:
	# Don't leave Sniff/Roll/movement "held down" when the level restarts.
	_release_all()


func _touch_down(finger: int, pos: Vector2) -> void:
	var role := "look"
	if pos.distance_to(sniff_center()) <= BUTTON_RADIUS * 1.15:
		role = "sniff"
		_sniff_pressed = true
		Input.action_press("sniff")
	elif pos.distance_to(roll_center()) <= BUTTON_RADIUS * 1.15:
		role = "roll"
		_roll_pressed = true
		Input.action_press("roll")
	elif pos.x < size.x * 0.45 and _joy_finger == -1:
		role = "joystick"
		_joy_finger = finger
		_joy_center = pos
		_joy_vector = Vector2.ZERO
	_touches[finger] = {"role": role, "start": pos, "time": _time, "moved": 0.0}


func _touch_drag(finger: int, pos: Vector2, relative: Vector2) -> void:
	if not _touches.has(finger):
		return
	var touch: Dictionary = _touches[finger]
	touch["moved"] = maxf(touch["moved"], pos.distance_to(touch["start"]))
	match touch["role"]:
		"joystick":
			var offset := pos - _joy_center
			if offset.length() > JOYSTICK_RADIUS:
				# The base follows the thumb, so it never "runs out" of stick.
				_joy_center = pos - offset.normalized() * JOYSTICK_RADIUS
			_joy_vector = (pos - _joy_center) / JOYSTICK_RADIUS
			_apply_joystick()
		"look":
			if touch["moved"] > TAP_MOVE:
				_rig.rotate_by(relative * SWIPE_SENSITIVITY)


func _touch_up(finger: int, pos: Vector2) -> void:
	if not _touches.has(finger):
		return
	var touch: Dictionary = _touches[finger]
	_touches.erase(finger)
	match touch["role"]:
		"sniff":
			_sniff_pressed = false
			Input.action_release("sniff")
		"roll":
			_roll_pressed = false
			Input.action_release("roll")
		"joystick":
			_joy_finger = -1
			_joy_vector = Vector2.ZERO
			_apply_joystick()
	var is_tap: bool = _time - touch["time"] <= TAP_TIME and touch["moved"] <= TAP_MOVE
	if is_tap and (touch["role"] == "joystick" or touch["role"] == "look"):
		tap(pos)


## Handles a tap at a screen position: uses the item under the finger.
func tap(pos: Vector2) -> void:
	_taps.append([pos, _time])
	var item := item_at(pos)
	if item == null:
		return
	if not _player.try_interact(item):
		if _player.is_rolled:
			Game.show_toast("Uncurl first, then tap it!")
		else:
			Game.show_toast("Walk closer, then tap it!")


## The usable item whose screen position is nearest to `pos`, or null.
func item_at(pos: Vector2) -> Interactable:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var best: Interactable = null
	var best_distance := TAP_PICK_RADIUS
	for node in get_tree().get_nodes_in_group("interactables"):
		var item := node as Interactable
		if item.get_prompt(_player) == "":
			continue
		var world := item.global_position + Vector3.UP * 0.15
		if camera.is_position_behind(world):
			continue
		var distance := camera.unproject_position(world).distance_to(pos)
		if distance < best_distance:
			best = item
			best_distance = distance
	return best


func _apply_joystick() -> void:
	_set_axis("move_left", "move_right", _joy_vector.x)
	_set_axis("move_forward", "move_back", _joy_vector.y)


func _set_axis(negative: String, positive: String, value: float) -> void:
	if value > 0.0:
		Input.action_press(positive, value)
		Input.action_release(negative)
	elif value < 0.0:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func _on_input_mode_changed(touch: bool) -> void:
	visible = touch
	if not touch:
		_release_all()


func _release_all() -> void:
	_touches.clear()
	_joy_finger = -1
	_joy_vector = Vector2.ZERO
	_apply_joystick()
	if _sniff_pressed:
		Input.action_release("sniff")
	if _roll_pressed:
		Input.action_release("roll")
	_sniff_pressed = false
	_roll_pressed = false


# --- Drawing ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_update_safe_area()
	while not _taps.is_empty() and _time - _taps[0][1] > 0.5:
		_taps.pop_front()
	if visible:
		queue_redraw()


func _update_safe_area() -> void:
	var window := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if window.x <= 0 or safe.size.x <= 0:
		return
	var scale := size.x / window.x
	_inset_left = maxf(safe.position.x, 0.0) * scale
	_inset_right = maxf(window.x - safe.end.x, 0.0) * scale


func _draw() -> void:
	if _player.is_sleeping:
		return
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)

	# Joystick: faint "home" hint when idle, real stick while a thumb is down.
	if _joy_finger == -1:
		var home := joystick_home()
		draw_circle(home, JOYSTICK_RADIUS, Color(1, 1, 1, 0.08))
		draw_arc(home, JOYSTICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.3), 3.0)
		draw_circle(home, KNOB_RADIUS, Color(1, 1, 1, 0.2))
		_draw_text("Move", home + Vector2(0, JOYSTICK_RADIUS + 28), 20, Color(1, 1, 1, 0.6))
		if highlight == "joystick":
			_draw_highlight(home, JOYSTICK_RADIUS + 12, pulse)
			_draw_text("Left thumb here!", home + Vector2(0, -JOYSTICK_RADIUS - 26), 24, HIGHLIGHT_COLOR)
	else:
		draw_circle(_joy_center, JOYSTICK_RADIUS, Color(1, 1, 1, 0.15))
		draw_arc(_joy_center, JOYSTICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
		draw_circle(_joy_center + _joy_vector * JOYSTICK_RADIUS, KNOB_RADIUS, Color(1, 1, 1, 0.6))

	_draw_sniff_button(sniff_center(), _sniff_pressed)
	_draw_roll_button(roll_center(), _roll_pressed)
	if highlight == "sniff":
		_draw_highlight(sniff_center(), BUTTON_RADIUS + 12, pulse)
		_draw_text("Hold me!", sniff_center() + Vector2(0, -BUTTON_RADIUS - 24), 24, HIGHLIGHT_COLOR)
	elif highlight == "roll":
		_draw_highlight(roll_center(), BUTTON_RADIUS + 12, pulse)
		_draw_text("Hold me!", roll_center() + Vector2(0, -BUTTON_RADIUS - 24), 24, HIGHLIGHT_COLOR)
	elif highlight == "look":
		var center := Vector2(size.x * 0.68, size.y * 0.42)
		var sway := sin(_time * 3.0) * 60.0
		draw_arc(center, 70, PI * 1.15, PI * 1.85, 24, HIGHLIGHT_COLOR, 6.0)
		draw_circle(center + Vector2(sway, -70), 22, Color(HIGHLIGHT_COLOR, 0.8))
		_draw_text("Swipe here to look around", center + Vector2(0, 10), 24, HIGHLIGHT_COLOR)

	# "Tap!" ring on the item the hedgehog can use right now.
	var item := _player.nearest_interactable() if not _player.is_rolled else null
	var camera := get_viewport().get_camera_3d()
	if item and camera:
		var world := item.global_position + Vector3.UP * 0.15
		if not camera.is_position_behind(world):
			var screen := camera.unproject_position(world)
			var strength := 1.0 if highlight == "tap" else 0.7
			draw_arc(screen, 46 + pulse * 10, 0, TAU, 40, Color(1, 1, 1, strength), 5.0)
			_draw_text("Tap!", screen + Vector2(0, -66), 26, Color(1, 1, 1, strength))

	for entry in _taps:
		var age: float = (_time - entry[1]) / 0.5
		draw_arc(entry[0], 20 + age * 40, 0, TAU, 32, Color(1, 1, 1, 1.0 - age), 4.0)


func _draw_sniff_button(center: Vector2, pressed: bool) -> void:
	draw_circle(center, BUTTON_RADIUS, Color(SNIFF_COLOR, 0.65 if pressed else 0.35))
	draw_arc(center, BUTTON_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.7), 3.0)
	# A little snout with smell waves.
	var snout := center + Vector2(-14, -8)
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		points.append(snout + Vector2(cos(a) * 26, sin(a) * 16))
	draw_colored_polygon(points, Color(0.85, 0.7, 0.55))
	draw_circle(snout + Vector2(24, -2), 9, Color(0.1, 0.08, 0.06))
	for i in 3:
		draw_arc(snout + Vector2(30, -2), 18 + i * 10, -0.6, 0.6, 10, Color(1, 1, 1, 0.8 - i * 0.2), 3.0)
	_draw_text("Sniff", center + Vector2(0, 44), 22, Color.WHITE)


func _draw_roll_button(center: Vector2, pressed: bool) -> void:
	draw_circle(center, BUTTON_RADIUS, Color(ROLL_COLOR, 0.65 if pressed else 0.35))
	draw_arc(center, BUTTON_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.7), 3.0)
	# A spiky ball.
	var ball := center + Vector2(0, -10)
	for i in 12:
		var a := TAU * i / 12.0 + (_time if pressed else 0.0)
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([ball + dir * 34, ball + dir * 18 + side * 7, ball + dir * 18 - side * 7]),
				Color(0.3, 0.2, 0.12))
	draw_circle(ball, 22, Color(0.4, 0.28, 0.18))
	_draw_text("Roll", center + Vector2(0, 50), 22, Color.WHITE)


func _draw_highlight(center: Vector2, radius: float, pulse: float) -> void:
	draw_arc(center, radius + pulse * 10.0, 0, TAU, 48, Color(HIGHLIGHT_COLOR, 0.5 + pulse * 0.5), 6.0)


func _draw_text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := center - Vector2(width / 2.0, -font_size / 3.0)
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.7))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

extends CanvasLayer
## Step-by-step tutorial for the first garden. Each step explains one
## control (touch or keyboard, matching how the player is playing), makes
## the matching on-screen control pulse, and waits until the player has
## tried it. The cat sleeps and the winter clock waits until it is done.

signal tutorial_finished

@export var enabled := true
@export var player_path: NodePath
@export var camera_rig_path: NodePath
@export var touch_controls_path: NodePath
@export var cat_path: NodePath

## Each step: id, highlight (touch control to pulse), touch text, keyboard text.
const STEPS := [
	{"id": "move", "highlight": "joystick",
		"touch": "Put your LEFT thumb on the left side of the screen and slide it to walk.",
		"keys": "Walk with W A S D or the arrow keys."},
	{"id": "look", "highlight": "look",
		"touch": "Swipe with your RIGHT thumb on the empty right side of the screen to look around.",
		"keys": "Look around: drag with the mouse, or press Z / X."},
	{"id": "sniff", "highlight": "sniff",
		"touch": "HOLD the Sniff button with your right thumb. Green clouds show where food is!",
		"keys": "HOLD Space to sniff. Green clouds show where food is!"},
	{"id": "eat", "highlight": "tap",
		"touch": "Walk to some food. When it says Tap!, TAP the food on the screen to eat it.",
		"keys": "Walk to some food and press E to eat it."},
	{"id": "roll", "highlight": "roll",
		"touch": "Uh-oh, the cat woke up! HOLD the Roll button to curl into a spiky ball. Cats don't like spikes!",
		"keys": "Uh-oh, the cat woke up! HOLD Shift to curl into a spiky ball. Cats don't like spikes!"},
	{"id": "hide", "highlight": "joystick",
		"touch": "Bushes are great hiding places. Walk into a bush to hide from the cat.",
		"keys": "Bushes are great hiding places. Walk into a bush to hide from the cat."},
	{"id": "nest", "highlight": "tap",
		"touch": "Winter is coming! Sniff for YELLOW clouds, then TAP dry leaves or moss to pick them up.",
		"keys": "Winter is coming! Sniff for YELLOW clouds, then press E to pick up dry leaves or moss."},
	{"id": "goal", "highlight": "",
		"touch": "Bring nest material to a safe spot (BLUE cloud), like under the shed. Then tap the nest to hibernate!",
		"keys": "Bring nest material to a safe spot (BLUE cloud), like under the shed. Then press E to hibernate!"},
]
const GOAL_SHOW_TIME := 10.0
const DONE_PAUSE := 1.2

var active := false
var step := -1

var _player: Hedgehog
var _rig: Node
var _touch: Node
var _cat: Cat
var _step_time := 0.0
var _progress := 0.0
var _done_timer := 0.0
var _start_position := Vector3.ZERO
var _start_yaw := 0.0
var _start_food := 0
var _panel: PanelContainer
var _counter: Label
var _text: Label
var _style: StyleBoxFlat


func _ready() -> void:
	layer = 3
	_player = get_node(player_path)
	_rig = get_node(camera_rig_path)
	_touch = get_node_or_null(touch_controls_path)
	_cat = get_node_or_null(cat_path) as Cat
	_build_panel()
	Game.input_mode_changed.connect(func(_touch_mode: bool) -> void: _show_text())
	if enabled:
		active = true
		if _cat:
			_cat.asleep = true
		_start_step(0)
	else:
		_panel.visible = false


func _process(delta: float) -> void:
	if not active:
		return
	_step_time += delta
	if _done_timer > 0.0:
		_done_timer -= delta
		if _done_timer <= 0.0:
			_start_step(step + 1)
		return
	if _step_done(delta):
		_complete_step()


func skip() -> void:
	if active:
		_finish()


func current_id() -> String:
	return STEPS[step]["id"] if active else ""


func _step_done(delta: float) -> bool:
	match STEPS[step]["id"]:
		"move":
			return _flat_distance(_player.global_position, _start_position) > 2.0
		"look":
			return absf(angle_difference(_rig.yaw, _start_yaw)) > 0.6 or _step_time > 12.0
		"sniff":
			if _player.is_sniffing:
				_progress += delta
			return _progress > 1.0
		"eat":
			return _player.stats.food > _start_food
		"roll":
			if _player.is_rolled:
				_progress += delta
			return _progress > 1.0
		"hide":
			return _player.is_hidden()
		"nest":
			return _player.nest_material > 0
		"goal":
			return _step_time > GOAL_SHOW_TIME
	return false


func _start_step(index: int) -> void:
	if index >= STEPS.size():
		_finish()
		return
	step = index
	_step_time = 0.0
	_progress = 0.0
	_start_position = _player.global_position
	_start_yaw = _rig.yaw
	_start_food = _player.stats.food
	if STEPS[step]["id"] == "roll" and _cat:
		_cat.wake_up()
	_style.bg_color = Color(0.1, 0.12, 0.2, 0.85)
	_show_text()


func _complete_step() -> void:
	if STEPS[step]["id"] == "goal":
		_finish()
		return
	_text.text = "Great job!"
	Sound.play("chime_step", -8.0)
	_style.bg_color = Color(0.15, 0.45, 0.2, 0.9)
	_set_highlight("")
	_done_timer = DONE_PAUSE


func _finish() -> void:
	active = false
	_panel.visible = false
	_set_highlight("")
	if _cat:
		_cat.wake_up()
	tutorial_finished.emit()


func _show_text() -> void:
	if not active or _done_timer > 0.0:
		return
	var entry: Dictionary = STEPS[step]
	_counter.text = "Tutorial  %d / %d" % [step + 1, STEPS.size()]
	_text.text = entry["touch"] if Game.touch_mode else entry["keys"]
	_set_highlight(entry["highlight"])


func _set_highlight(name: String) -> void:
	if _touch:
		_touch.highlight = name


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.offset_left = -280
	_panel.offset_right = 280
	_panel.offset_top = 112
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.set_corner_radius_all(14)
	_style.set_content_margin_all(16)
	_style.border_color = Color(1.0, 0.85, 0.2)
	_style.set_border_width_all(3)
	_panel.add_theme_stylebox_override("panel", _style)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_counter = Label.new()
	_counter.add_theme_font_size_override("font_size", 16)
	_counter.modulate = Color(1.0, 0.85, 0.4)
	box.add_child(_counter)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 24)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(528, 0)
	box.add_child(_text)

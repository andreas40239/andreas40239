extends Node
## Global helpers, autoloaded as "Game".
## Registers the input actions, holds the hedgehog fact library and relays
## short messages (toasts and fact cards) to the HUD.

signal fact_unlocked(title: String, text: String)
signal toast(text: String)
## Emitted when the player switches between touch and keyboard/gamepad.
signal input_mode_changed(touch: bool)

## Fact id -> [title, text]. Facts unlock once per session the first time
## the player does or finds the matching thing.
## TODO: have the facts reviewed by a hedgehog charity before release.
const FACTS := {
	"start": ["Hedgehog highways", "Hedgehogs can walk a long way every night. Small holes in garden fences, called hedgehog highways, help them travel from garden to garden."],
	"sniff": ["Super nose", "Hedgehogs can't see very well, but they have a brilliant sense of smell. They sniff out food hidden under leaves and soil."],
	"roll": ["Spiky ball", "When a hedgehog is scared, it rolls into a tight ball. Its thousands of spines keep it safe."],
	"hide": ["Hide and seek", "Hedgehogs love hedges, bushes and wild corners. Leaving a messy corner in your garden gives them a place to hide."],
	"beetle": ["Crunchy beetles", "Beetles are one of a hedgehog's favourite foods. They are full of energy!"],
	"worm": ["Wiggly worms", "Earthworms come up to the surface on damp nights. That's a feast for a hungry hedgehog."],
	"slug": ["Garden helpers", "Hedgehogs eat slugs and snails, which is why many gardeners are happy to see them."],
	"apple": ["Fruity snack", "Hedgehogs mostly eat insects. Fallen fruit is only an occasional snack."],
	"milk": ["No milk, please!", "Milk gives hedgehogs a tummy ache, because they can't digest it. A shallow dish of fresh water is the best drink for them."],
	"nest": ["Building a nest", "Before winter, hedgehogs build a cosy nest from dry leaves, grass and moss. A winter nest is called a hibernaculum."],
	"bonfire": ["Check before you burn", "Hedgehogs often sleep in piles of sticks and leaves. Always check bonfire piles for sleeping hedgehogs before lighting them!"],
	"shed": ["Safe and dry", "Dry, sheltered spots under sheds, log piles or a hedgehog house make perfect places to hibernate."],
	"winter": ["Getting sleepy", "When it gets cold and food runs out, hedgehogs hibernate. They sleep through winter and wake up in spring."],
	"caterpillar": ["Wriggly snack", "Caterpillars are full of protein, which makes them a great hedgehog snack."],
	"compost": ["Cosy compost", "Compost heaps are warm and full of bugs, so hedgehogs love them. Always check a compost heap before digging into it with a fork!"],
	"dog": ["Super sniffers", "A dog's nose is many thousands of times better than ours. Dogs find things by smell much more than by sight."],
	"ball": ["Playtime!", "Dogs love to chase and play. Keeping dogs busy and on a lead near wild corners helps hedgehogs stay safe."],
	"hedgehog_house": ["A house for a hedgehog", "You can build or buy a hedgehog house. Put it in a quiet, shady corner with some dry leaves inside."],
	"night": ["Night owls", "Hedgehogs are nocturnal: they sleep during the day and come out at night to look for food."],
	"owl": ["Silent wings", "Owls fly almost silently thanks to soft, fringed feathers. That's why their shadow is the best warning!"],
}

## The gardens, in order. Each one unlocks when the one before is finished.
const LEVELS := [
	{"scene": "res://scenes/garden_1.tscn", "title": "The Cottage Garden"},
	{"scene": "res://scenes/garden_2.tscn", "title": "The Allotments"},
	{"scene": "res://scenes/garden_3.tscn", "title": "The Night Garden"},
]
const TITLE_SCENE := "res://scenes/title.tscn"
const SAVE_PATH := "user://progress.cfg"

## Best star rating per garden (0 = not finished yet).
var best_stars: Array = [0, 0, 0]

var unlocked_facts: Dictionary = {}
## True when on-screen touch controls should be shown and touch hints used.
var touch_mode := false

## Run with `-- --touch` to try the touch controls on a desktop with the mouse.
var _force_touch := false


func _ready() -> void:
	_setup_input()
	_force_touch = OS.get_cmdline_user_args().has("--touch")
	if _force_touch:
		Input.emulate_touch_from_mouse = true
	touch_mode = _force_touch or DisplayServer.is_touchscreen_available()
	_load_progress()


# --- Gardens and progress ------------------------------------------------------

func is_unlocked(index: int) -> bool:
	return index == 0 or (index < LEVELS.size() and best_stars[index - 1] > 0)


func has_level(index: int) -> bool:
	return index >= 0 and index < LEVELS.size()


func complete_level(index: int, stars: int) -> void:
	best_stars[index] = maxi(best_stars[index], stars)
	_save_progress()


func go_to_level(index: int) -> void:
	get_tree().change_scene_to_file(LEVELS[index]["scene"])


func go_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)


func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for i in LEVELS.size():
		best_stars[i] = int(config.get_value("stars", str(i), 0))


func _save_progress() -> void:
	var config := ConfigFile.new()
	for i in LEVELS.size():
		config.set_value("stars", str(i), best_stars[i])
	config.save(SAVE_PATH)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		set_touch_mode(true)
	elif event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		return  # A touch, translated into a click so buttons work.
	elif not _force_touch and (event is InputEventKey or event is InputEventJoypadButton
			or event is InputEventMouseButton):
		set_touch_mode(false)


func set_touch_mode(touch: bool) -> void:
	if touch == touch_mode:
		return
	touch_mode = touch
	input_mode_changed.emit(touch)


func unlock_fact(id: String) -> void:
	if unlocked_facts.has(id) or not FACTS.has(id):
		return
	unlocked_facts[id] = true
	var entry: Array = FACTS[id]
	fact_unlocked.emit(entry[0], entry[1])


func show_toast(text: String) -> void:
	toast.emit(text)


func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_add_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_add_action("move_forward", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_add_action("move_back", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_add_action("cam_left", [KEY_Z], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_add_action("cam_right", [KEY_X], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_add_action("sniff", [KEY_SPACE], [JOY_BUTTON_A])
	_add_action("roll", [KEY_SHIFT], [JOY_BUTTON_B])
	_add_action("interact", [KEY_E, KEY_ENTER], [JOY_BUTTON_X])
	_add_action("restart", [KEY_R], [JOY_BUTTON_START])


func _add_action(action: String, keys: Array, buttons: Array = [], axes: Array = []) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for key in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(action, key_event)
	for button in buttons:
		var button_event := InputEventJoypadButton.new()
		button_event.button_index = button
		InputMap.action_add_event(action, button_event)
	for axis in axes:
		var axis_event := InputEventJoypadMotion.new()
		axis_event.axis = axis[0]
		axis_event.axis_value = axis[1]
		InputMap.action_add_event(action, axis_event)

extends Node
## Headless smoke test that plays through the core loop: eat, sniff, collect
## nest material, hide, get caught by the cat, roll up, build a nest, hibernate.
## A second pass plays the tutorial with simulated touch-screen input.
## Run from the project folder:
##   godot --headless --fixed-fps 60 res://tests/smoke_test.tscn

var main: Node3D
var player: Hedgehog
var cat: Cat
var failures := 0
var touch_controls: Control


func _ready() -> void:
	print("Sounds:")
	var missing := []
	for sound in Sound.ALL:
		if Sound.stream(sound) == null:
			missing.append(sound)
	_check(missing.is_empty(), "all %d sounds load %s" % [Sound.ALL.size(), missing])

	print("Core loop (keyboard):")
	_load_level(false)
	cat.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(30)
	await _run()

	print("Tutorial (touch screen):")
	main.queue_free()
	await _frames(2)
	_load_level(true)
	await _frames(30)
	await _run_touch_tutorial()
	print("\n%s: %d failure(s)" % ["FAILED" if failures else "ALL PASSED", failures])
	get_tree().quit(1 if failures else 0)


func _run() -> void:
	_check(player.is_on_floor(), "hedgehog stands on the ground")

	# Eating good food raises dexterity; the food disappears.
	var beetle: Food = main.get_node("Food/Beetle0")
	var dexterity := player.dexterity
	await _teleport(beetle.global_position + Vector3(0, 0.05, 0.3))
	await _press("interact")
	_check(player.dexterity > dexterity + 10.0, "eating a beetle raises dexterity")
	_check(not beetle.is_available(), "eaten beetle disappears")

	# Milk is bad but never takes the last heart.
	var milk: Food = main.get_node("Food/Milk14")
	var health := player.health
	await _teleport(milk.global_position + Vector3(0, 0.05, 0.3))
	await _press("interact")
	_check(player.health == maxi(health - 1, 1), "milk costs a heart (but not the last one)")
	_check(Game.unlocked_facts.has("milk"), "milk unlocks its fact")
	player.health = player.max_health

	# Sniffing reveals nearby scents.
	await _teleport(Vector3(-10, 0.05, 8))
	Input.action_press("sniff")
	await _frames(5)
	_check(_visible_scents() > 0, "sniffing reveals nearby scents")
	_check(player.current_speed() < player.base_speed, "sniffing slows the hedgehog down")
	Input.action_release("sniff")
	await _frames(3)
	_check(_visible_scents() == 0, "scents disappear when sniffing stops")

	# Collect all nest material.
	var materials := main.get_node("NestMaterials").get_children()
	for item in materials:
		await _teleport(item.global_position + Vector3(0, 0.05, 0.2))
		await _press("interact")
	_check(player.nest_material == materials.size(), "collected all %d nest materials" % materials.size())

	# Hiding in a bush.
	await _teleport(main.get_node("HideSpots/Bush1").global_position + Vector3(0, 0.05, 0))
	_check(player.is_hidden(), "hedgehog is hidden inside a bush")
	await _teleport(Vector3(0, 0.05, 3))
	_check(not player.is_hidden(), "hedgehog is visible outside the bush")

	# The cat notices, stalks and catches a visible hedgehog.
	cat.process_mode = Node.PROCESS_MODE_INHERIT
	await _place_cat_facing_player()
	var caught := await _wait_for(func() -> bool: return player.stats.caught > 0, 8.0)
	_check(caught, "cat catches a visible hedgehog")
	_check(player.global_position.distance_to(player.respawn_point) < 0.5, "caught hedgehog goes back to the checkpoint")
	await _frames(200)  # Let the post-catch blink wear off.

	# A rolled-up hedgehog is too spiky: the cat gets bored.
	Input.action_press("roll")
	await _place_cat_facing_player()
	var bored := await _wait_for(func() -> bool: return cat.state == Cat.State.BORED, 10.0)
	_check(bored, "cat gets bored of a rolled-up hedgehog")
	_check(player.stats.caught == 1, "rolled-up hedgehog is not caught")
	Input.action_release("roll")
	cat.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)

	# The bonfire pile is not a safe place to sleep.
	await _teleport(main.get_node("HibernationSpots/BonfirePile").global_position + Vector3(0, 0.05, 0.6))
	await _press("interact")
	_check(not main.finished, "cannot hibernate in the bonfire pile")
	_check(Game.unlocked_facts.has("bonfire"), "bonfire pile unlocks its fact")

	# The hedgehog fits through the gap in the shed skirting; the cat does not.
	var shed: HibernationSpot = main.get_node("HibernationSpots/UnderShed")
	cat.process_mode = Node.PROCESS_MODE_INHERIT
	cat.global_position = shed.global_position + Vector3(0, 0.1, 2.6)
	cat._last_known = shed.global_position
	cat._set_state(Cat.State.SEARCH)
	await _teleport(shed.global_position + Vector3(0, 0.05, 2.2))
	main.get_node("CameraRig").yaw = 0.0  # Camera looks towards -Z, at the shed.
	Input.action_press("move_forward")
	await _frames(90)
	Input.action_release("move_forward")
	_check(player.global_position.z < shed.global_position.z + 1.2, "hedgehog walks through the gap under the shed")
	_check(cat.global_position.z > shed.global_position.z + 1.5, "cat is too big to follow under the shed")
	cat.process_mode = Node.PROCESS_MODE_DISABLED

	# Build the nest under the shed and hibernate.
	await _teleport(shed.global_position + Vector3(0, 0.05, 0.3))
	_check(player.is_hidden(), "under the shed counts as hidden")
	await _press("interact")
	_check(shed.nest_amount == materials.size(), "nest material goes into the nest")
	await _press("interact")
	_check(main.finished, "hibernating ends the level")
	_check(player.is_sleeping, "hedgehog is asleep")
	_check(main.stars >= 2, "safe spot + cosy nest earn at least 2 stars (got %d)" % main.stars)
	await _frames(500)
	_check(main.get_node("HUD")._results.visible, "results panel is shown")


func _load_level(with_tutorial: bool) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.get_node("Tutorial").enabled = with_tutorial
	add_child(main)
	player = main.get_node("Player")
	cat = main.get_node("Cat")


func _run_touch_tutorial() -> void:
	var tutorial = main.get_node("Tutorial")
	var touch = main.get_node("TouchLayer/TouchControls")
	touch_controls = touch
	var rig = main.get_node("CameraRig")
	_check(tutorial.active and tutorial.current_id() == "move", "tutorial starts with the move step")
	_check(cat.asleep, "cat sleeps during the first tutorial steps")
	await _frames(60)
	_check(main.elapsed == 0.0, "winter clock waits for the tutorial")

	# Left thumb: floating joystick.
	var home: Vector2 = touch.joystick_home()
	_touch(0, home, true)
	await _frames(2)
	_check(Game.touch_mode and touch.visible, "a touch switches on the touch controls")
	_check(touch.highlight == "joystick", "tutorial highlights the joystick")
	_drag(0, home + Vector2(0, -80), Vector2(0, -80))
	await _frames(100)
	_check(touch.joystick_vector().y < -0.8, "dragging the thumb up pushes the joystick forward")
	_touch(0, home + Vector2(0, -80), false)
	await _wait_for(func() -> bool: return tutorial.current_id() == "look", 4.0)
	_check(tutorial.current_id() == "look", "walking with the joystick completes the move step")

	# Swipe on the right side to look around.
	var swipe_start := Vector2(touch.size.x * 0.65, touch.size.y * 0.4)
	_touch(1, swipe_start, true)
	for i in 12:
		_drag(1, swipe_start + Vector2(20 * (i + 1), 0), Vector2(20, 0))
		await _frames(1)
	_touch(1, swipe_start + Vector2(240, 0), false)
	await _wait_for(func() -> bool: return tutorial.current_id() == "sniff", 4.0)
	_check(tutorial.current_id() == "sniff", "swiping turns the camera and completes the look step")

	# Right thumb: hold Sniff.
	_touch(2, touch.sniff_center(), true)
	await _frames(20)
	_check(player.is_sniffing, "holding the Sniff button sniffs")
	await _frames(60)
	_touch(2, touch.sniff_center(), false)
	await _frames(3)
	_check(not player.is_sniffing, "letting go of Sniff stops sniffing")
	await _wait_for(func() -> bool: return tutorial.current_id() == "eat", 4.0)
	_check(tutorial.current_id() == "eat", "sniffing completes the sniff step")

	# Tap food on the screen.
	var beetle: Food = main.get_node("Food/Beetle1")
	await _teleport(beetle.global_position + Vector3(0, 0.05, 0.3))
	await _frames(40)  # Let the camera catch up.
	_check(player.prompt_changed.get_connections().size() > 0 and player.nearest_interactable() == beetle, "beetle is in reach")
	await _tap_world(beetle.global_position)
	_check(not beetle.is_available(), "tapping the beetle on screen eats it")
	await _wait_for(func() -> bool: return tutorial.current_id() == "roll", 4.0)
	_check(tutorial.current_id() == "roll" and not cat.asleep, "eating completes the eat step and the cat wakes up")

	# Right thumb: hold Roll.
	_touch(3, touch.roll_center(), true)
	await _frames(20)
	_check(player.is_rolled, "holding the Roll button rolls up")
	await _frames(60)
	_touch(3, touch.roll_center(), false)
	await _frames(3)
	_check(not player.is_rolled, "letting go of Roll uncurls")
	await _wait_for(func() -> bool: return tutorial.current_id() == "hide", 4.0)
	_check(tutorial.current_id() == "hide", "rolling completes the roll step")

	cat.process_mode = Node.PROCESS_MODE_DISABLED  # Keep the rest of the test predictable.
	await _teleport(main.get_node("HideSpots/Bush1").global_position + Vector3(0, 0.05, 0))
	await _wait_for(func() -> bool: return tutorial.current_id() == "nest", 4.0)
	_check(tutorial.current_id() == "nest", "hiding completes the hide step")

	# Tap nest material on the screen.
	var leaves: NestMaterial = main.get_node("NestMaterials/Leaves3")
	await _teleport(leaves.global_position + Vector3(0, 0.05, 0.3))
	await _frames(40)
	await _tap_world(leaves.global_position)
	_check(leaves.is_taken() and player.nest_material == 1, "tapping leaves on screen picks them up")
	await _wait_for(func() -> bool: return tutorial.current_id() == "goal", 4.0)
	_check(tutorial.current_id() == "goal", "picking up material completes the nest step")
	await _wait_for(func() -> bool: return not tutorial.active, 15.0)
	_check(not tutorial.active, "tutorial finishes after the goal message")
	await _frames(30)
	_check(main.elapsed > 0.0, "winter clock starts after the tutorial")

	# Tapping an item that is too far away does nothing.
	var far_food: Food = main.get_node("Food/Apple12")
	var before: int = player.stats.food
	await _tap_world(far_food.global_position)
	_check(player.stats.food == before, "tapping food that is out of reach does not eat it")

	# Building the nest by tapping, with touch-friendly hints.
	var toasts := []
	Game.toast.connect(func(text: String) -> void: toasts.append(text))
	var shed: HibernationSpot = main.get_node("HibernationSpots/UnderShed")
	player.add_nest_material(3)
	await _teleport(shed.global_position + Vector3(0, 0.05, 0.3))
	await _frames(40)
	await _tap_world(shed.global_position)
	_check(shed.nest_amount >= 3, "tapping the nest adds the nest material")
	_check(toasts.any(func(t: String) -> bool: return t.contains("Tap the nest again")), "touch players are told to tap (not press E) to hibernate")
	_check(not toasts.any(func(t: String) -> bool: return t.contains("[E]")), "no keyboard hints are shown to touch players")
	await _tap_world(shed.global_position)
	_check(main.finished, "tapping the nest again hibernates")
	await _frames(30)



func _tap_world(world: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	var screen := camera.unproject_position(world + Vector3.UP * 0.15)
	_touch(9, screen, true)
	await _frames(3)
	_touch(9, screen, false)
	await _frames(3)


func _touch(finger: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = position
	event.pressed = pressed
	_send(event)


func _drag(finger: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = position
	event.relative = relative
	_send(event)


## Delivers a touch event straight to the touch controls. (Headless runs have a
## zero-size window, so events sent through the viewport get rescaled.)
func _send(event: InputEvent) -> void:
	Game._input(event)
	touch_controls._input(event)


func _place_cat_facing_player() -> void:
	await _teleport(Vector3(0, 0.05, 3.5))
	cat.global_position = Vector3(0, 0.1, -1)
	cat.rotation.y = 0.0  # Facing +Z, towards the hedgehog.
	cat.velocity = Vector3.ZERO
	cat._set_state(Cat.State.PATROL)
	await _frames(2)


func _visible_scents() -> int:
	var count := 0
	for scent in get_tree().get_nodes_in_group("scent"):
		if scent.visible:
			count += 1
	return count


func _wait_for(condition: Callable, seconds: float) -> bool:
	for i in int(seconds * 60.0):
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _teleport(position: Vector3) -> void:
	player.global_position = position
	player.velocity = Vector3.ZERO
	await _frames(4)


func _press(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, description: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + description)
	if not condition:
		failures += 1

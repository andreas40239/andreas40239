extends Node
## Headless smoke test that plays through the core loop: eat, sniff, collect
## nest material, hide, get caught by the cat, roll up, build a nest, hibernate.
## Run from the project folder:
##   godot --headless --fixed-fps 60 res://tests/smoke_test.tscn

var main: Node3D
var player: Hedgehog
var cat: Cat
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	player = main.get_node("Player")
	cat = main.get_node("Cat")
	cat.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(30)
	await _run()
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

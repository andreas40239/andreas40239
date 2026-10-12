extends Node
## Tests the dog (garden 2) and the owl (garden 3).
## Run: godot --headless --fixed-fps 60 res://tests/creatures_test.tscn

var failures := 0
var level: Node3D
var player: Hedgehog


func _ready() -> void:
	print("Dog (garden 2):")
	await _load("res://scenes/garden_2.tscn")
	await _test_dog()
	print("Owl (garden 3):")
	await _load("res://scenes/garden_3.tscn")
	await _test_owl()
	print("\n%s: %d failure(s)" % ["FAILED" if failures else "ALL PASSED", failures])
	get_tree().quit(1 if failures else 0)


func _test_dog() -> void:
	var dog: Dog = level.get_node("Dog")
	_check(level.get_node("HideSpots/Compost0").masks_scent, "compost heaps hide the hedgehog's smell")

	# Smell: a visible hedgehog behind the dog (out of sight) is still noticed.
	await _place_dog(Vector3(-1, 0.1, 0.8), PI)  # Facing away (-Z).
	await _teleport(Vector3(-1, 0.05, 3.5))
	_check(dog._can_sense(player), "the dog smells a hedgehog behind it")

	# A bush only helps from a distance; a compost heap always helps.
	var bush: Node3D = level.get_node("HideSpots/Bush3")
	await _teleport(bush.global_position + Vector3(0, 0.05, 0))
	await _place_dog(bush.global_position + Vector3(3, 0.1, 0), -PI / 2)
	_check(not dog._can_sense(player), "hiding in a bush works while the dog is a few steps away")
	await _place_dog(bush.global_position + Vector3(1.0, 0.1, 0), -PI / 2)
	_check(dog._can_sense(player), "...but the dog sniffs you out right next to the bush")
	var compost: Node3D = level.get_node("HideSpots/Compost0")
	await _teleport(compost.global_position + Vector3(0, 0.05, 0))
	await _place_dog(compost.global_position + Vector3(0.8, 0.1, 0), -PI / 2)
	_check(player.is_scent_masked() and not dog._can_sense(player), "the dog can't smell you in a compost heap")

	# The dog chases and catches a hedgehog in the open.
	var caught_before: int = player.stats.caught
	await _teleport(Vector3(-4, 0.05, 1.0))
	await _place_dog(Vector3(-7, 0.1, 1.0), PI / 2)
	dog._set_state(Dog.State.PATROL)
	var caught := await _wait_for(func() -> bool: return player.stats.caught > caught_before, 10.0)
	_check(caught, "the dog chases and catches a hedgehog in the open")
	await _frames(200)  # Let the hedgehog's post-catch blink wear off.

	# A rolled-up hedgehog: woof, nudge, ouch, the dog gives up.
	caught_before = player.stats.caught
	await _teleport(Vector3(-4, 0.05, 1.0))
	Input.action_press("roll")
	await _place_dog(Vector3(-7, 0.1, 1.0), PI / 2)
	dog._set_state(Dog.State.CHASE)
	var barked := await _wait_for(func() -> bool: return dog.state == Dog.State.BARK, 6.0)
	_check(barked, "the dog stops to bark at a rolled-up hedgehog")
	var gave_up := await _wait_for(func() -> bool: return dog.state == Dog.State.BORED, 6.0)
	_check(gave_up and player.stats.caught == caught_before, "...gets a spiky nose and gives up without catching it")
	Input.action_release("roll")
	await _frames(3)

	# Nudging a ball sends the dog off to play.
	var ball: Ball = level.get_node("Ball0")
	await _teleport(ball.global_position + Vector3(0.6, 0.05, 0))
	dog._set_state(Dog.State.CHASE)
	var ball_start := ball.global_position
	_check(player.try_interact(ball), "the hedgehog can nudge the ball")
	_check(dog.state == Dog.State.PLAY, "the dog drops the chase to play with the ball")
	await _frames(120)
	_check(ball.global_position.distance_to(ball_start) > 2.0, "the ball rolls away")
	_check(dog.global_position.distance_to(ball.global_position) < 4.0 or dog.state == Dog.State.PLAY, "the dog runs after the ball")

	# Hedgehog house: safe from smell and a secure place to hibernate.
	var house: HibernationSpot = level.get_node("HibernationSpots/HedgehogHouse")
	await _teleport(house.global_position + Vector3(0, 0.05, 0.2))
	_check(player.is_scent_masked(), "inside the hedgehog house the dog can't smell you")
	player.add_nest_material(3)
	house.interact(player)
	house.interact(player)
	_check(level.finished, "the hedgehog can hibernate in the hedgehog house")


func _test_owl() -> void:
	var owl: Owl = level.get_node("Owl")
	_check(level.night and player.get_child_count() > 0, "the night garden is dark and the hedgehog has a soft glow")
	_check(level.get_node("Cat").glow_eyes.size() == 2, "the night cat has glowing eyes")

	# Standing in the open when the owl swoops: caught.
	await _teleport(Vector3(1, 0.05, 6))
	var caught_before: int = player.stats.caught
	owl._player = player
	owl._start_warning()
	var struck := await _wait_for(func() -> bool: return owl.state == Owl.State.CLIMB, 8.0)
	_check(struck and player.stats.caught == caught_before + 1, "the owl catches a hedgehog standing in the open")
	await _frames(240)

	# Rolled up: the owl misses.
	await _teleport(Vector3(1, 0.05, 6))
	caught_before = player.stats.caught
	Input.action_press("roll")
	owl._start_warning()
	await _wait_for(func() -> bool: return owl.state == Owl.State.CLIMB, 8.0)
	_check(player.stats.caught == caught_before, "the owl misses a rolled-up hedgehog")
	Input.action_release("roll")
	await _frames(3)

	# In a hedge: the owl misses.
	var hedge: Node3D = level.get_node("HideSpots/HedgeB3")
	await _teleport(hedge.global_position + Vector3(0, 0.05, 0))
	owl._start_warning()
	await _wait_for(func() -> bool: return owl.state == Owl.State.CLIMB, 8.0)
	_check(player.stats.caught == caught_before, "the owl misses a hedgehog hiding in a hedge")

	# Running away during the warning also works.
	await _teleport(Vector3(1, 0.05, 6))
	owl._start_warning()
	await _frames(30)
	await _teleport(Vector3(1, 0.05, 2.5))
	owl._target = Vector3(1, 0, 6)
	owl.state = Owl.State.SWOOP
	owl._timer = 0.0
	owl._swoop_from = owl._bird.global_position
	await _wait_for(func() -> bool: return owl.state == Owl.State.CLIMB, 4.0)
	_check(player.stats.caught == caught_before, "a hedgehog that ran away is missed")

	var deck: HibernationSpot = level.get_node("HibernationSpots/UnderDecking")
	await _teleport(deck.global_position + Vector3(0, 0.05, 0.3))
	_check(player.is_hidden(), "under the decking counts as hidden")
	player.add_nest_material(3)
	deck.interact(player)
	deck.interact(player)
	_check(level.finished, "the hedgehog can hibernate under the decking")


func _load(path: String) -> void:
	if level:
		level.queue_free()
		await _frames(2)
	level = load(path).instantiate()
	add_child(level)
	player = level.get_node("Player")
	await _frames(30)


func _place_dog(position: Vector3, facing: float) -> void:
	var dog: Dog = level.get_node("Dog")
	dog.global_position = position
	dog.rotation.y = facing
	dog.velocity = Vector3.ZERO
	await _frames(2)


func _teleport(position: Vector3) -> void:
	player.global_position = position
	player.velocity = Vector3.ZERO
	await _frames(4)


func _wait_for(condition: Callable, seconds: float) -> bool:
	for i in int(seconds * 60.0):
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, description: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + description)
	if not condition:
		failures += 1

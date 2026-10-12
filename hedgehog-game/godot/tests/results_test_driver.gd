extends Node

var failures := 0


func _ready() -> void:
	await _frames(20)
	var main := get_tree().current_scene
	Game.set_touch_mode(true)
	main.get_node("Tutorial").skip()
	var player: Hedgehog = main.get_node("Player")
	var shed: HibernationSpot = main.get_node("HibernationSpots/UnderShed")
	player.global_position = shed.global_position + Vector3(0, 0.05, 0.3)
	player.add_nest_material(4)
	await _frames(5)
	shed.interact(player)
	shed.interact(player)
	var hud = main.get_node("HUD")
	for i in 600:
		if hud.is_showing_results():
			break
		await get_tree().physics_frame
	_check(hud.is_showing_results(), "results screen appears")

	# A tap the moment the screen appears is ignored...
	await _tap()
	_check(get_tree().current_scene == main, "an immediate tap does not skip the results")
	# ...but a tap a moment later plays again.
	await _frames(70)
	await _tap()
	await _frames(10)
	_check(get_tree().current_scene != null and get_tree().current_scene != main, "tapping the results screen restarts the level")
	var new_main := get_tree().current_scene
	_check(not Input.is_action_pressed("sniff") and not Input.is_action_pressed("move_forward"), "no controls stay held after restarting")
	_check(new_main.get_node("Tutorial").active, "the restarted level begins with the tutorial")

	print("\n%s: %d failure(s)" % ["FAILED" if failures else "ALL PASSED", failures])
	get_tree().quit(1 if failures else 0)


func _tap() -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = Vector2(640, 360)
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, description: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + description)
	if not condition:
		failures += 1

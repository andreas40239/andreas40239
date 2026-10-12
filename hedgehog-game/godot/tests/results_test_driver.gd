extends Node
## Plays garden 1 for real, hibernates, and uses the results screen buttons:
## "Play again" restarts the garden, "Next garden" opens garden 2, and
## "All gardens" goes back to the title screen.

var failures := 0


func _ready() -> void:
	await _frames(20)
	Game.set_touch_mode(true)
	var main := await _finish_level()
	var hud = main.get_node("HUD")
	_check(hud.is_showing_results(), "results screen appears")
	_check(Game.best_stars[0] >= 1 and Game.is_unlocked(1), "finishing garden 1 unlocks garden 2")
	var buttons: Array = hud._result_buttons
	_check(buttons.size() == 3, "results show Play again, Next garden and All gardens")
	_check(buttons.all(func(b: Button) -> bool: return b.disabled), "buttons ignore taps for the first moment")
	await _frames(70)
	_check(not buttons[0].disabled, "buttons wake up after a second")

	# Play again.
	buttons[0].pressed.emit()
	await _frames(10)
	var again := get_tree().current_scene
	_check(again != main and again.name == "Main" and again.level_index == 0, "Play again restarts garden 1")
	_check(not Input.is_action_pressed("sniff") and not Input.is_action_pressed("move_forward"), "no controls stay held after restarting")
	_check(not again.get_node("Tutorial").active, "the tutorial is skipped once garden 1 has been finished")

	# Next garden.
	main = await _finish_level()
	await _frames(70)
	main.get_node("HUD")._result_buttons[1].pressed.emit()
	await _frames(10)
	_check(get_tree().current_scene.level_index == 1, "Next garden opens garden 2")

	# All gardens.
	main = await _finish_level()
	await _frames(70)
	main.get_node("HUD")._result_buttons[2].pressed.emit()
	await _frames(10)
	_check(get_tree().current_scene.name == "Title", "All gardens goes to the title screen")
	var title := get_tree().current_scene
	_check(not title.cards[2].disabled, "garden 3 is unlocked after finishing garden 2")

	print("\n%s: %d failure(s)" % ["FAILED" if failures else "ALL PASSED", failures])
	get_tree().quit(1 if failures else 0)


## Hibernates in the current garden's first safe spot and waits for results.
func _finish_level() -> Node:
	var main := get_tree().current_scene
	if main.get_node("Tutorial").active:
		main.get_node("Tutorial").skip()
	var player: Hedgehog = main.get_node("Player")
	var spot: HibernationSpot
	for candidate in get_tree().get_nodes_in_group("hibernation_spots"):
		if candidate.secure:
			spot = candidate
			break
	player.global_position = spot.global_position + Vector3(0, 0.05, 0.3)
	player.add_nest_material(4)
	await _frames(5)
	spot.interact(player)
	spot.interact(player)
	var hud = main.get_node("HUD")
	for i in 600:
		if hud.is_showing_results():
			break
		await get_tree().physics_frame
	return main


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, description: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + description)
	if not condition:
		failures += 1

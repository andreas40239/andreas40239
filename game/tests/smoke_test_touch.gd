extends SceneTree

## Regression test for the touch-input bug: HUD's full-screen Control
## defaulted to mouse_filter=STOP and silently absorbed every touch event
## before it reached the player. This pushes *real* input events through
## the viewport (not direct method calls) to catch that class of bug.

func _initialize() -> void:
	var main_scene: PackedScene = load("res://scenes/world/main.tscn")
	var main := main_scene.instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame

	var player = main.get_node("Player")
	var start_pos: Vector2 = player.global_position

	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.pressed = true
	touch_down.position = Vector2(640, 360)
	get_root().push_input(touch_down)
	await process_frame

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(640, 460)
	get_root().push_input(drag)
	await process_frame

	assert(player.touch_index == 0, "player should have latched onto the touch")
	assert(player.touch_vector.length() > 0.0, "drag should produce a nonzero movement vector")

	for i in 30:
		await process_frame
		await physics_frame

	var moved: float = player.global_position.distance_to(start_pos)
	print("moved distance after touch-drag=", moved)
	assert(moved > 5.0, "player should have physically moved from touch input")

	print("ALL TOUCH SMOKE TESTS PASSED")
	quit(0)

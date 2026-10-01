extends Node
## Verifies Godzilla can walk left, turns around, and isn't stuck at the right edge.
var game
var t := 0.0
var x_right := 0.0
var ok := true

func _ready() -> void:
	GameState.current_level = 1
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child.call_deferred(game)

func _process(delta: float) -> void:
	t += delta
	if game.player == null:
		return
	if t < 3.0:
		InputHandler.move_axis = 1.0          # walk right to the wall
		if t > 1.0 and int(t * 10) % 5 == 0:
			InputHandler.attack_swipe.emit(Vector2.RIGHT)  # dash-claw spam
	elif t < 3.1:
		x_right = game.player.position.x
		print("MOVETEST: at right edge x=%.0f facing=%.0f" % [x_right, game.player.facing])
	elif t < 5.5:
		InputHandler.move_axis = -1.0         # now walk back left
	else:
		InputHandler.move_axis = 0.0
		var p = game.player
		print("MOVETEST: after walking left x=%.0f facing=%.0f" % [p.position.x, p.facing])
		ok = p.position.x < x_right - 150.0 and p.facing < 0.0
		print("MOVETEST: " + ("PASS" if ok else "FAIL"))
		get_tree().quit(0 if ok else 1)

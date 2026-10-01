extends Node
## Bot plays the training level by performing each move; checks every step completes.
var game
var t := 0.0
var last_step := -2
var step_t := 0.0
var acted := 0.0

func _ready() -> void:
	GameState.current_level = 0
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child.call_deferred(game)

func _process(delta: float) -> void:
	t += delta
	if t > 150.0:
		print("TRAINTEST: TIMEOUT at step %d" % last_step)
		get_tree().quit(1)
		return
	if game.trainer == null:
		return
	var tr: Training = game.trainer
	if game.frozen and game.seg_state == "done":
		print("TRAINTEST: PASS - all %d steps done in %.1fs, gems=%d" % [tr.STEPS.size(), t, GameState.ep])
		get_tree().quit(0)
		return
	if tr.step != last_step:
		if last_step >= 0:
			print("TRAINTEST: step %d done (%s)" % [last_step, tr.STEPS[last_step]["need"]])
		last_step = tr.step
		step_t = 0.0
		acted = 0.0
	step_t += delta
	if tr.waiting:
		InputHandler.move_axis = 0.0
		return
	var p: Player = game.player
	var need: String = tr.STEPS[tr.step]["need"]
	acted -= delta
	match need:
		"walk":
			InputHandler.move_axis = 1.0
		"throw":
			if p.grabbed_enemy != null:
				InputHandler.move_axis = 0.0
				if acted <= 0.0:
					InputHandler.attack_tap.emit(); acted = 0.5
			else:
				for e in game.enemies:
					if is_instance_valid(e) and e is Enemy and e.dizzy_forever:
						InputHandler.move_axis = signf(e.position.x - p.position.x)
		"swat":
			for c in game.fx_root.get_children():
				if c is Projectile and not c.friendly and c.lane == p.lane and absf(c.position.x - p.position.x) < 70.0 and acted <= 0.0:
					InputHandler.attack_tap.emit(); acted = 0.4
		_:
			if acted > 0.0:
				return
			acted = 1.2
			match need:
				"lane": InputHandler.lane_up.emit() if p.lane > 0 else InputHandler.lane_down.emit()
				"whip": InputHandler.attack_tap.emit()
				"combo":
					for i in 3:
						InputHandler.attack_tap.emit()
						await get_tree().create_timer(0.22).timeout
				"dash": InputHandler.attack_swipe.emit(Vector2.LEFT)
				"antiair": InputHandler.attack_swipe.emit(Vector2.UP)
				"pound": InputHandler.attack_swipe.emit(Vector2.DOWN)
				"breath":
					InputHandler.attack_charge_start.emit()
					await get_tree().create_timer(0.6).timeout
					InputHandler.attack_charge_release.emit()
				"jump": InputHandler.jump_tap.emit()
				"leap": InputHandler.jump_swipe.emit(Vector2.UP)
				"dive": InputHandler.jump_swipe.emit(Vector2.DOWN)
				"pulse": InputHandler.special_tap.emit()

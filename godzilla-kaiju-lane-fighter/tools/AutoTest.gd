extends Node
## Headless smoke test: simulates chaotic play to flush out runtime errors.
## Run: godot --headless tools/test_scene.tscn -- [level]

var game
var t := 0.0
var phase := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 1234
	var level := 1
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			level = int(arg)
	GameState.current_level = level
	var packed: PackedScene = load("res://scenes/game.tscn")
	game = packed.instantiate()
	get_tree().root.add_child.call_deferred(game)
	print("AUTOTEST: level %d started" % level)

func _process(delta: float) -> void:
	t += delta
	if game == null or not is_instance_valid(game) or game.player == null:
		return
	if not is_instance_valid(game.player):
		return
	# random input chaos
	if rng.randf() < 0.15:
		var r := rng.randi() % 10
		match r:
			0: InputHandler.lane_up.emit()
			1: InputHandler.lane_down.emit()
			2: InputHandler.attack_tap.emit()
			3: InputHandler.attack_swipe.emit(Vector2.RIGHT)
			4: InputHandler.attack_swipe.emit(Vector2.UP)
			5: InputHandler.attack_swipe.emit(Vector2.DOWN)
			6: InputHandler.jump_tap.emit()
			7: InputHandler.jump_swipe.emit(Vector2.DOWN)
			8: InputHandler.special_tap.emit()
			9:
				InputHandler.attack_charge_start.emit()
				await get_tree().create_timer(0.5).timeout
				InputHandler.attack_charge_release.emit()
	InputHandler.move_axis = [0.0, 1.0, -1.0][rng.randi() % 3]
	# staged scenario events
	if phase == 0 and t > 5.0:
		phase = 1
		if GameState.current_level == 3:
			print("AUTOTEST: jumping to boss segment")
			game._start_segment(1)
	if phase == 1 and t > 8.0:
		phase = 2
		if game.boss != null and is_instance_valid(game.boss):
			print("AUTOTEST: hammering boss")
	if phase >= 1 and game.boss != null and is_instance_valid(game.boss) and rng.randf() < 0.2:
		game.boss.take_hit(12.0, {"breath": rng.randf() < 0.3})
	if phase == 2 and t > 18.0:
		phase = 3
		print("AUTOTEST: killing player to test death overlay")
		if game.player.state != "dead":
			game.player.take_damage(9999.0)
	if phase == 3 and t > 20.0:
		phase = 4
		print("AUTOTEST: respawning")
		game._respawn()
	if OS.has_environment("SCREENSHOT_DIR") and (absf(t - 4.0) < delta or absf(t - 10.0) < delta or absf(t - 16.0) < delta):
		var img := get_viewport().get_texture().get_image()
		if img != null:
			var p := "%s/shot_l%d_t%d.png" % [OS.get_environment("SCREENSHOT_DIR"), GameState.current_level, int(t)]
			img.save_png(p)
			print("AUTOTEST: screenshot " + p)
	if t > 34.0:
		print("AUTOTEST: OK — score %d, segment %d, enemies %d" % [game.hud.score, game.segment_i, game.enemies.size()])
		get_tree().quit(0)

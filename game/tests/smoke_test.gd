extends SceneTree

## Headless regression check for the vertical slice's core mechanics.
## Run with a fresh save file, e.g.:
##   rm -f "$HOME/.local/share/godot/app_userdata/Eidechsen-Spiel (Vertical Slice)/savegame.json"
##   godot --headless --path . --script tests/smoke_test.gd

var GameManager: Node
var SaveManager: Node

func _initialize() -> void:
	GameManager = get_root().get_node("GameManager")
	SaveManager = get_root().get_node("SaveManager")

	var main_scene: PackedScene = load("res://scenes/world/main.tscn")
	var main := main_scene.instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame

	var player = main.get_node("Player")
	var den = main.get_node("World/Den")
	var barrier1 = main.get_node("World/Barrier1")
	var barrier2 = main.get_node("World/Barrier2")
	var zone2 = main.get_node("World/Zone2Enemies")
	var zone3 = main.get_node("World/Zone3Enemies")
	var ant1 = main.get_node("World/Zone1Enemies/Ant1")
	var rival1 = main.get_node("World/Zone1Enemies/Rival1")

	print("== eat via physics overlap ==")
	player.global_position = ant1.global_position
	for i in 10:
		await process_frame
		await physics_frame
	assert(GameManager.satiety > 0.0, "eating an ant should raise satiety")
	assert(not is_instance_valid(ant1), "eaten prey should be freed")
	print("OK: satiety=", GameManager.satiety, " ant freed")

	print("== fruit boost ==")
	player.apply_fruit_boost(25.0, 1.6, 5.0)
	assert(player.speed_boost_multiplier == 1.6)
	print("OK: satiety=", GameManager.satiety, " boost=", player.speed_boost_multiplier)

	print("== level-up 1 -> 2 (den + satiety threshold) ==")
	GameManager.satiety = GameManager.get_satiety_threshold()
	den._on_body_entered(player)
	await process_frame
	assert(GameManager.growth_level == 2)
	assert(barrier1.visible == false and zone2.visible == true)
	assert(player.get_node("Camera2D").limit_right == 1700)
	print("OK: level=", GameManager.growth_level, " zone2 unlocked")

	print("== rival becomes edible once player outgrows it ==")
	assert(GameManager.can_eat_rival(rival1.data.rival_level) == true)
	print("OK")

	print("== level-up 2 -> 3 ==")
	GameManager.satiety = GameManager.get_satiety_threshold()
	den._on_body_entered(player)
	await process_frame
	assert(GameManager.growth_level == 3 and GameManager.run_complete == true)
	assert(barrier2.visible == false and zone3.visible == true)
	print("OK: level=", GameManager.growth_level, " run_complete=", GameManager.run_complete)

	print("== predator/rival catch respawns player at den, no progress lost ==")
	GameManager.growth_level = 1  # re-enable the rival as a threat for this check
	var den_pos: Vector2 = player.den_position
	player.global_position = rival1.global_position + Vector2(140, 0)
	for i in 200:
		await process_frame
		await physics_frame
		if player.global_position.distance_to(den_pos) < 5.0 and i > 5:
			break
	assert(player.global_position.distance_to(den_pos) < 5.0, "player should be returned to the den")
	print("OK: respawned at den, invulnerable=", player.invulnerable)

	print("== save / load ==")
	GameManager.growth_level = 3
	SaveManager.save_game()
	GameManager.growth_level = 1
	GameManager.satiety = 0.0
	SaveManager.load_game()
	assert(GameManager.growth_level == 3)
	print("OK: reloaded growth_level=", GameManager.growth_level)

	print("ALL SMOKE TESTS PASSED")
	quit(0)

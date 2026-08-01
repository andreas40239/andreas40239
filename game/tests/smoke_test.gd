extends SceneTree

## Headless regression check for the vertical slice's core mechanics.
## Run with a fresh save file, e.g.:
##   rm -f "$HOME/.local/share/godot/app_userdata/Eidechsen-Spiel (Vertical Slice)/savegame.json"
##   godot --headless --path . --script tests/smoke_test.gd

var GameManager: Node
var SaveManager: Node

var ENEMY_SCENE: PackedScene
var ANT_DATA: Resource
var RIVAL_DATA: Resource
var BIRD_DATA: Resource
var CRAB_DATA: Resource

func _initialize() -> void:
	GameManager = get_root().get_node("GameManager")
	SaveManager = get_root().get_node("SaveManager")

	# Loaded at runtime (not preloaded as top-level consts): preloading here
	# would force enemy.gd to compile during this entrypoint script's own
	# special compile phase, before autoload globals like GameManager are
	# bound, which fails with "Identifier not found: GameManager".
	ENEMY_SCENE = load("res://scenes/enemies/enemy.tscn")
	ANT_DATA = load("res://resources/enemies/ant.tres")
	RIVAL_DATA = load("res://resources/enemies/rival_lizard.tres")
	BIRD_DATA = load("res://resources/enemies/bird.tres")
	CRAB_DATA = load("res://resources/enemies/crab.tres")

	var main_scene: PackedScene = load("res://scenes/world/main.tscn")
	var main := main_scene.instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame

	var player = main.get_node("Player")
	var den = main.get_node("World/Den")
	var spawner = main.get_node("World/EnemySpawner")
	var camera = player.get_node("Camera2D")
	var world = main.get_node("World")

	print("== spawner produced enemies (incl. ants) ==")
	assert(spawner.get_child_count() > 0, "spawner should have spawned enemies on _ready")
	var ant_count := 0
	for child in spawner.get_children():
		if child.data.category == EnemyData.Category.PREY:
			ant_count += 1
	print("spawned=", spawner.get_child_count(), " ants=", ant_count)
	assert(ant_count > 0, "spawner should include ants")

	print("== den safety ==")
	den._on_body_entered(player)
	assert(player.in_den == true, "player should be marked safe inside the den")
	var bird := ENEMY_SCENE.instantiate()
	bird.data = BIRD_DATA
	world.add_child(bird)
	bird.global_position = player.global_position
	var pos_before: Vector2 = player.global_position
	bird._on_hit_area_body_entered(player)
	assert(player.global_position == pos_before, "player should be untouched while in the den")
	assert(player.invulnerable == false, "den safety should not trigger the caught/respawn path")
	bird.queue_free()
	den._on_body_exited(player)
	assert(player.in_den == false, "leaving the den should clear the safe flag")

	print("== chasing predators give up instead of camping at the den ==")
	var bird3 := ENEMY_SCENE.instantiate()
	bird3.data = BIRD_DATA
	world.add_child(bird3)
	await process_frame  # let _ready() (home_position, signal hookups) settle first
	await physics_frame
	bird3.global_position = Vector2(400, 0)
	player.global_position = Vector2(420, 0)
	bird3._on_detection_body_entered(player)
	assert(bird3.state == 2, "bird should start chasing (State.CHASE)")
	# Note: set_in_den() directly rather than den._on_body_entered(), and
	# check within a single physics tick. The player is nowhere near the
	# den here, so the den's *real* Area2D would otherwise emit its own
	# (a-frame-late) body_exited and overwrite this before we can observe
	# the reaction we're actually testing.
	player.set_in_den(true)
	await physics_frame
	assert(bird3.state == 4, "bird should give up on a player safe in the den (State.RETURN)")
	bird3.queue_free()
	player.set_in_den(false)

	var bird4 := ENEMY_SCENE.instantiate()
	bird4.data = BIRD_DATA
	world.add_child(bird4)
	await process_frame
	await physics_frame
	bird4.global_position = Vector2(100, 0)  # inside DEN_SAFE_MARGIN (160)
	bird4.state = 2  # force CHASE, as if it had wandered too close
	bird4.player = player
	player.global_position = Vector2(650, 0)  # far away, chase target still valid
	for i in 3:
		await physics_frame
	assert(bird4.state == 4, "a chaser that ends up near the den should retreat, not camp there")
	bird4.queue_free()

	print("== eat via physics overlap ==")
	var ant := ENEMY_SCENE.instantiate()
	ant.data = ANT_DATA
	world.add_child(ant)
	player.global_position = ant.global_position
	for i in 10:
		await process_frame
		await physics_frame
	assert(GameManager.satiety > 0.0, "eating an ant should raise satiety")
	assert(not is_instance_valid(ant), "eaten prey should be freed")
	print("OK: satiety=", GameManager.satiety)

	print("== fruit boost ==")
	player.apply_fruit_boost(25.0, 1.6, 5.0)
	assert(player.speed_boost_multiplier == 1.6)
	print("OK: satiety=", GameManager.satiety, " boost=", player.speed_boost_multiplier)

	print("== leveling to 5 (spikes) grows the map in all directions ==")
	var half_before: Vector2 = GameManager.get_map_half_extent()
	for target in range(2, 6):
		GameManager.satiety = GameManager.get_satiety_threshold()
		den._on_body_entered(player)
		assert(GameManager.growth_level == target)
	var half_after: Vector2 = GameManager.get_map_half_extent()
	assert(half_after.x > half_before.x and half_after.y > half_before.y, "map should grow in both axes")
	assert(int(camera.limit_right) == int(half_after.x), "camera limit should track map growth")
	assert(GameManager.get_current_stage()["has_spikes"] == true, "level 5 should have spikes")
	print("OK: level=", GameManager.growth_level, " half_extent=", half_after)

	print("== spikes fend off an old threat instead of getting caught ==")
	var bird2 := ENEMY_SCENE.instantiate()
	bird2.data = BIRD_DATA
	world.add_child(bird2)
	var pos_before2: Vector2 = player.global_position
	bird2.global_position = pos_before2
	bird2._on_hit_area_body_entered(player)
	assert(player.global_position == pos_before2, "spiked player should not be caught by an old threat")
	assert(bird2.state == 1, "fended-off predator should flee (State.FLEE)")
	bird2.queue_free()

	print("== rival becomes edible once player outgrows it ==")
	assert(GameManager.can_eat_rival(RIVAL_DATA.rival_level) == true)

	print("== leveling to 10 turns the player into a T-Rex ==")
	for target in range(6, 11):
		GameManager.satiety = GameManager.get_satiety_threshold()
		den._on_body_entered(player)
		assert(GameManager.growth_level == target)
	assert(GameManager.get_current_stage()["is_trex"] == true, "level 10 should be a T-Rex")
	print("OK: level=", GameManager.growth_level)

	print("== predator catch (no spikes yet) still respawns player at the den ==")
	GameManager.growth_level = 1
	GameManager.satiety = 0.0
	den._on_body_exited(player)
	var far_pos: Vector2 = den.global_position + Vector2(900, 900)
	player.global_position = far_pos
	var crab := ENEMY_SCENE.instantiate()
	crab.data = CRAB_DATA
	world.add_child(crab)
	crab.global_position = far_pos
	crab._on_hit_area_body_entered(player)
	await process_frame
	assert(player.global_position == player.den_position, "player should respawn at the den when caught")
	crab.queue_free()

	print("== save / load ==")
	GameManager.growth_level = 10
	SaveManager.save_game()
	GameManager.growth_level = 1
	GameManager.satiety = 0.0
	SaveManager.load_game()
	assert(GameManager.growth_level == 10)
	print("OK: reloaded growth_level=", GameManager.growth_level)

	print("ALL SMOKE TESTS PASSED")
	quit(0)

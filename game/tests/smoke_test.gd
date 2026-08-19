extends SceneTree

## Headless regression check for the vertical slice's core mechanics.
## Run with a fresh save file, e.g.:
##   rm -f "$HOME/.local/share/godot/app_userdata/Eidechsen-Spiel (Vertical Slice)/savegame.json"
##   godot --headless --path . --script tests/smoke_test.gd

var GameManager: Node
var SaveManager: Node

var ENEMY_SCENE: PackedScene
var ANT_DATA: Resource
var BIG_ANT_DATA: Resource
var RIVAL_DATA: Resource
var BIRD_DATA: Resource
var CRAB_DATA: Resource
var OVIRAPTOR_DATA: Resource
var HELICOPTER_DATA: Resource

## GameManager.add_satiety() always emits level_up_ready when the
## threshold is hit, and the real popup independently reacts to it by
## showing itself and pausing the tree. When a test wants to skip clicking
## the popup and call GameManager.choose_upgrade() directly (to level up
## repeatedly without going through the UI each time), it must also close
## the popup and unpause here, or the game stays paused - which silently
## stops every regular node's _physics_process (they default to
## PROCESS_MODE_PAUSABLE), producing very confusing "nothing is moving"
## failures far downstream, not at the point the pause got stuck.
func _bypass_choose(level_up_popup: CanvasLayer, upgrade: String) -> void:
	GameManager.choose_upgrade(upgrade)
	level_up_popup.visible = false
	paused = false

func _initialize() -> void:
	GameManager = get_root().get_node("GameManager")
	SaveManager = get_root().get_node("SaveManager")

	# Loaded at runtime (not preloaded as top-level consts): preloading here
	# would force enemy.gd to compile during this entrypoint script's own
	# special compile phase, before autoload globals like GameManager are
	# bound, which fails with "Identifier not found: GameManager".
	ENEMY_SCENE = load("res://scenes/enemies/enemy.tscn")
	ANT_DATA = load("res://resources/enemies/ant.tres")
	BIG_ANT_DATA = load("res://resources/enemies/big_ant.tres")
	RIVAL_DATA = load("res://resources/enemies/rival_lizard.tres")
	BIRD_DATA = load("res://resources/enemies/bird.tres")
	CRAB_DATA = load("res://resources/enemies/crab.tres")
	OVIRAPTOR_DATA = load("res://resources/enemies/oviraptor.tres")
	HELICOPTER_DATA = load("res://resources/enemies/helicopter.tres")

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
	var level_up_popup = main.get_node("LevelUpPopup")

	print("== spawner produced enemies (incl. ants) ==")
	assert(spawner.get_child_count() > 0, "spawner should have spawned enemies on _ready")
	var ant_count := 0
	for child in spawner.get_children():
		if child.data.category == EnemyData.Category.PREY:
			ant_count += 1
	print("spawned=", spawner.get_child_count(), " ants=", ant_count)
	assert(ant_count > 0, "spawner should include ants")

	# The rest of this suite plants specific enemies at specific positions
	# and asserts precisely what happens to them/the player - stop the
	# spawner and clear its ambient wildlife first, or a stray real ant/bird
	# wandering into a hand-placed encounter could flakily contribute
	# damage/eating that the test didn't cause and isn't asserting about.
	spawner.set_process(false)
	for child in spawner.get_children():
		child.queue_free()
	await process_frame

	print("== den safety blocks the damage-tick path too ==")
	den._on_body_entered(player)
	assert(player.in_den == true, "player should be marked safe inside the den")
	var bird := ENEMY_SCENE.instantiate()
	bird.data = BIRD_DATA
	world.add_child(bird)
	await process_frame
	await physics_frame
	bird.global_position = player.global_position
	bird._on_hit_area_body_entered(player)
	var health_before_den_test: float = player.health
	for i in 3:
		await physics_frame
	assert(player.health == health_before_den_test, "player should take no damage while in the den")
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
	assert(bird3.state == 5, "bird should give up on a player safe in the den (State.RETURN)")
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
	assert(bird4.state == 5, "a chaser that ends up near the den should retreat, not camp there")
	bird4.queue_free()

	print("== eat via physics overlap (small prey, instant) ==")
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

	print("== level 4: big ants must be fought (~2s) before they can be eaten ==")
	GameManager.growth_level = 4
	player._on_leveled_up(4)
	var big_ant := ENEMY_SCENE.instantiate()
	big_ant.data = BIG_ANT_DATA
	world.add_child(big_ant)
	await process_frame
	await physics_frame
	player.global_position = big_ant.global_position + Vector2(700, 700)  # clear of the den
	big_ant.global_position = player.global_position
	# The player started this test overlapping the den (it spawns there by
	# design) - give the den's real body_exited signal (which lags a frame
	# or two, same as any Area2D) a moment to actually clear in_den before
	# taking the health snapshot below, or a stray tick of den regen from
	# the stale flag would throw off the "harmless" assertion.
	for i in 5:
		await physics_frame
	big_ant._on_hit_area_body_entered(player)
	var satiety_before_fight: float = GameManager.satiety
	var health_before_fight: float = player.health
	var fight_seconds := 0.0
	while is_instance_valid(big_ant) and fight_seconds < 5.0:
		await physics_frame
		fight_seconds += 1.0 / 60.0
	assert(not is_instance_valid(big_ant), "big ant should eventually be defeated")
	assert(fight_seconds > 1.5 and fight_seconds < 2.5, "the fight should take about 2 seconds at level 4")
	assert(GameManager.satiety - satiety_before_fight == BIG_ANT_DATA.satiety_value, "defeating it should grant its satiety reward")
	assert(player.health == health_before_fight, "the plain big ant should be harmless (damage_per_tick=0)")
	print("OK: fight took ~", fight_seconds, "s")

	print("== level 1 (no spikes, not yet edible): a dangerous predator deals repeated damage ==")
	GameManager.growth_level = 1
	player._on_leveled_up(1)
	player.health = player.max_health
	var crab := ENEMY_SCENE.instantiate()
	crab.data = CRAB_DATA
	world.add_child(crab)
	await process_frame
	await physics_frame
	var far_pos: Vector2 = Vector2(1600, 1600)
	player.global_position = far_pos
	crab.global_position = far_pos
	crab._on_hit_area_body_entered(player)
	var health_before_crab: float = player.health
	for i in 90:  # 1.5s: enough for a couple of damage ticks (0.5s cooldown)
		await physics_frame
	assert(player.health < health_before_crab, "sustained contact with a dangerous predator should chip health")
	assert(is_instance_valid(crab), "the crab shouldn't be defeated - the player isn't strong enough to eat it yet")

	print("== health reaching zero respawns the player at the den and fully heals ==")
	player.take_damage(player.health)
	await process_frame
	assert(player.global_position == player.den_position, "zero health should send the player back to the den")
	assert(player.health == player.max_health, "respawning should fully heal")
	crab.queue_free()

	print("== the den also recharges health over time ==")
	player.health = player.max_health * 0.4
	den._on_body_entered(player)
	for i in 240:  # 4s, comfortably more than health_regen_seconds (3s default)
		await physics_frame
	assert(player.health >= player.max_health * 0.99, "staying in the den should recharge health to full")
	den._on_body_exited(player)

	print("== leveling no longer requires visiting the den: satiety alone triggers the popup ==")
	player.global_position = Vector2(1500, 1500)  # far from the den - this is the point of the test
	for i in 5:
		await physics_frame
	assert(player.global_position.distance_to(Vector2.ZERO) > 300.0, "player should be far from the den for this check")
	var level_before_popup_test: int = GameManager.growth_level
	assert(level_up_popup.visible == false and not paused)
	player.eat(GameManager.get_satiety_threshold())
	await process_frame
	assert(GameManager.pending_level_up == true, "reaching the satiety threshold should flag a pending level-up immediately")
	assert(GameManager.growth_level == level_before_popup_test, "the level shouldn't advance until a power is chosen")
	assert(level_up_popup.visible == true, "the real popup should have shown itself, with fireworks, via the level_up_ready signal")
	assert(paused == true, "the popup should pause the game while the player decides")
	level_up_popup.defense_button.emit_signal("pressed")
	await process_frame
	assert(GameManager.growth_level == level_before_popup_test + 1, "pressing a power's button should be what applies the level-up")
	assert(GameManager.defense_level == 1)
	assert(GameManager.pending_level_up == false)
	assert(level_up_popup.visible == false and not paused, "choosing should close the popup and resume the game")

	print("== leveling to 5 (spikes) grows the map in all directions ==")
	var half_before: Vector2 = GameManager.get_map_half_extent()
	for target in range(GameManager.growth_level + 1, 6):
		GameManager.add_satiety(GameManager.get_satiety_threshold())
		_bypass_choose(level_up_popup, "defense")
		assert(GameManager.growth_level == target)
	var half_after: Vector2 = GameManager.get_map_half_extent()
	assert(half_after.x > half_before.x and half_after.y > half_before.y, "map should grow in both axes")
	assert(int(camera.limit_right) == int(half_after.x), "camera limit should track map growth")
	assert(GameManager.get_current_stage()["has_spikes"] == true, "level 5 should have spikes")
	print("OK: level=", GameManager.growth_level, " half_extent=", half_after, " defense_level=", GameManager.defense_level)

	print("== spikes fend off an old threat instead of dealing damage ==")
	player.global_position = Vector2(-1600, 1600)
	for i in 5:
		await physics_frame
	var bird2 := ENEMY_SCENE.instantiate()
	bird2.data = BIRD_DATA
	world.add_child(bird2)
	await process_frame
	await physics_frame
	var pos_before2: Vector2 = player.global_position
	bird2.global_position = pos_before2
	bird2._on_hit_area_body_entered(player)
	var health_before_fendoff: float = player.health
	# A couple of extra ticks of margin: the real DetectionArea overlapping
	# at the same instant can independently (and correctly) fire its own
	# body_entered a tick later and briefly relabel the movement state back
	# to CHASE before _resolve_contact (which runs every tick regardless of
	# that label while player_touching is true, so this never affects
	# velocity or damage) reasserts FLEE.
	for i in 8:
		await physics_frame
	assert(player.health == health_before_fendoff, "spiked player should take no damage from an old threat")
	assert(bird2.state == 1, "fended-off predator should flee (State.FLEE)")
	bird2.queue_free()

	print("== rival becomes edible once player outgrows it ==")
	assert(GameManager.can_eat_rival(RIVAL_DATA.rival_level) == true)

	print("== level 7: gulls become fightable/edible ==")
	var attack_level_before: int = GameManager.attack_level
	for target in range(GameManager.growth_level + 1, 8):
		GameManager.add_satiety(GameManager.get_satiety_threshold())
		_bypass_choose(level_up_popup, "attack")
	assert(GameManager.growth_level == 7)
	assert(GameManager.attack_level > attack_level_before, "choosing 'attack' should have raised attack_level")
	var bird5 := ENEMY_SCENE.instantiate()
	bird5.data = BIRD_DATA
	world.add_child(bird5)
	await process_frame
	await physics_frame
	player.global_position = Vector2(1700, -1700)
	bird5.global_position = player.global_position
	bird5._on_hit_area_body_entered(player)
	var satiety_before_bird: float = GameManager.satiety
	for i in 400:
		await physics_frame
		if not is_instance_valid(bird5):
			break
	assert(not is_instance_valid(bird5), "gull should eventually be defeated once fightable")
	assert(GameManager.satiety - satiety_before_bird == BIRD_DATA.satiety_value, "defeating it should grant its satiety reward")

	print("== leveling to 10 turns the player into a T-Rex ==")
	for target in range(8, 11):
		GameManager.add_satiety(GameManager.get_satiety_threshold())
		_bypass_choose(level_up_popup, "attack")
		assert(GameManager.growth_level == target)
	assert(GameManager.get_current_stage()["is_trex"] == true, "level 10 should be a T-Rex")
	print("OK: level=", GameManager.growth_level)

	print("== level 17: Oviraptors are fast, deal damage, and can never be eaten ==")
	GameManager.growth_level = 17
	player._on_leveled_up(17)
	player.health = player.max_health
	var ovi := ENEMY_SCENE.instantiate()
	ovi.data = OVIRAPTOR_DATA
	ovi.global_position = Vector2(1900, 0)
	world.add_child(ovi)
	await process_frame
	await physics_frame
	player.global_position = ovi.global_position
	ovi._on_detection_body_entered(player)
	var health_before_ovi: float = player.health
	for i in 90:
		await physics_frame
	assert(player.health < health_before_ovi, "the Oviraptor should deal damage on contact")
	assert(is_instance_valid(ovi) and ovi.state != 6, "the Oviraptor should never be defeated (State.DEAD == 6)")
	ovi.queue_free()

	print("== level 20: the player becomes Godzilla and its fire breath instantly destroys anything ==")
	GameManager.growth_level = 20
	player._on_leveled_up(20)
	assert(GameManager.get_current_stage()["is_godzilla"] == true)
	var ovi2 := ENEMY_SCENE.instantiate()
	ovi2.data = OVIRAPTOR_DATA
	ovi2.global_position = Vector2(2100, 100)
	world.add_child(ovi2)
	await process_frame
	await physics_frame
	player.global_position = Vector2(2100 - 150, 100)
	player.last_move_direction = Vector2(1, 0)
	var satiety_before_fire: float = GameManager.satiety
	player._fire_cooldown = 0.0
	for i in 10:
		await physics_frame
		if not is_instance_valid(ovi2):
			break
	assert(not is_instance_valid(ovi2), "fire breath should incinerate even an unbeatable Oviraptor")
	assert(GameManager.satiety > satiety_before_fire, "incinerating something should grant satiety")

	print("== level 21: helicopters keep their distance and shoot ==")
	GameManager.growth_level = 21
	player._on_leveled_up(21)
	player.health = player.max_health
	player.global_position = Vector2(2300, 0)
	var heli := ENEMY_SCENE.instantiate()
	heli.data = HELICOPTER_DATA
	heli.global_position = player.global_position + Vector2(200, 0)
	world.add_child(heli)
	await process_frame
	await physics_frame
	heli._on_detection_body_entered(player)
	assert(heli.state == 4, "ranged predators should use ORBIT, not CHASE (State.ORBIT == 4)")
	var health_before_heli: float = player.health
	for i in 200:
		await physics_frame
	assert(player.health < health_before_heli, "the helicopter should have shot the player at least once")
	var final_dist: float = heli.global_position.distance_to(player.global_position)
	assert(final_dist > 30.0, "the helicopter should keep some distance rather than closing to melee range")
	heli.queue_free()

	print("== save / load ==")
	GameManager.growth_level = 15
	SaveManager.save_game()
	GameManager.growth_level = 1
	GameManager.satiety = 0.0
	SaveManager.load_game()
	assert(GameManager.growth_level == 15)
	print("OK: reloaded growth_level=", GameManager.growth_level)

	print("== restarting the game resets growth AND the upgrade levels together ==")
	GameManager.growth_level = 12
	GameManager.satiety = 40.0
	GameManager.defense_level = 3
	GameManager.attack_level = 4
	GameManager.run_complete = true
	GameManager.restart_game()
	assert(GameManager.growth_level == 1, "restart should reset growth_level")
	assert(GameManager.satiety == 0.0, "restart should reset satiety")
	assert(GameManager.defense_level == 0, "restart must not leave defense_level from the previous run")
	assert(GameManager.attack_level == 0, "restart must not leave attack_level from the previous run")
	assert(not GameManager.run_complete, "restart should clear run_complete")
	# Also verify the reset was actually persisted, not just held in memory -
	# a real app relaunch would only see it via a reload of the save file.
	GameManager.defense_level = 7
	GameManager.attack_level = 9
	SaveManager.load_game()
	assert(GameManager.defense_level == 0, "the restart's fresh state should have been written to disk")
	assert(GameManager.attack_level == 0, "the restart's fresh state should have been written to disk")
	print("OK: restart_game() resets growth_level, satiety, defense_level, attack_level and run_complete together")

	print("ALL SMOKE TESTS PASSED")
	quit(0)

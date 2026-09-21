extends Node
## Kopflose Funktionspruefung fuer Meilenstein 1 und 2.
##
## Start:  godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn
## Beendet sich mit Exit-Code 0 (alles gruen) oder 1 (mindestens ein Fehler).

const LEVEL_PATH := "res://scenes/levels/level_greybox.tscn"
const TUTORIAL_PATH := "res://scenes/levels/level_00_tutorial.tscn"
const PHYSICS_FPS := 60.0

var _failures: Array[String] = []
var _checks := 0

func _ready() -> void:
	# Erst einen Frame abwarten: waehrend _ready baut der Baum noch auf und
	# add_child() auf die Wurzel schlaegt fehl.
	await get_tree().process_frame
	# Der Testlauf schliesst Levels ab - den echten Spielstand nicht veraendern.
	var saved_progress := SaveGame.completed_levels.duplicate()
	var saved_music := SaveGame.music_on
	var saved_sound := SaveGame.sound_on
	await _run_all()
	SaveGame.completed_levels = saved_progress
	SaveGame.music_on = saved_music
	SaveGame.sound_on = saved_sound
	SaveGame.save_game()
	SaveGame.apply_audio()
	print("")
	print("--- Ergebnis: %d Pruefungen, %d Fehler ---" % [_checks, _failures.size()])
	for failure in _failures:
		print("FEHLER: ", failure)
	get_tree().quit(1 if _failures.size() > 0 else 0)

func _run_all() -> void:
	_test_metrics()
	await _test_running()
	await _test_jump_height()
	await _test_climbing()
	await _test_ledge_grab()
	await _test_hard_gap()
	await _test_food()
	await _test_camera_follows_fall()
	await _test_damage_and_invulnerability()
	await _test_dog_states()
	await _test_territory_cat()
	await _test_car()
	await _test_car_is_jumpable()
	await _test_car_jump_tolerance()
	await _test_flight_from_enemies()
	await _test_hit_recovery()
	await _test_level_catalog()
	await _test_save_and_progress()
	await _test_menu_screens()
	await _test_tutorial_level()
	await _test_hud_paws()
	await _test_goal()
	await _test_game_over()

# --- Einzelpruefungen -------------------------------------------------------

## GDD Abschnitt 2: Sprunghoehe 1,8 m und Sprungweite 3,5 m aus dem Lauf.
func _test_metrics() -> void:
	var apex: float = Player.JUMP_VELOCITY * Player.JUMP_VELOCITY / (2.0 * Player.GRAVITY)
	_check(absf(apex - Player.JUMP_HEIGHT) < 0.01,
		"Sprunghoehe aus den Konstanten: %.3f m (erwartet 1,8 m)" % apex)
	var distance: float = Player.RUN_SPEED * 2.0 * Player.JUMP_VELOCITY / Player.GRAVITY
	_check(absf(distance - Player.JUMP_DISTANCE) < 0.01,
		"Sprungweite aus den Konstanten: %.3f m (erwartet 3,5 m)" % distance)

func _test_running() -> void:
	var level := await _spawn_level()
	var player: Player = level.get_node("Player")
	# Freies Strassenstueck ohne Hindernisse waehlen.
	player.global_position = Vector3(16.0, 0.4, 0.0)
	await _wait(0.2)
	var start_x := player.global_position.x
	PlayerInput.set_touch_move(Vector2.RIGHT)
	await _wait(1.0)
	var travelled := player.global_position.x - start_x
	_check(travelled > 3.5 and travelled < 4.1,
		"Laufstrecke in 1 s: %.2f m (erwartet ~3,8 m inkl. Beschleunigung)" % travelled)
	_check(player.facing > 0.0, "Blickrichtung nach rechts")
	PlayerInput.set_touch_move(Vector2.LEFT)
	await _wait(0.5)
	_check(player.facing < 0.0, "Blickrichtung nach links")
	await _despawn(level)

func _test_jump_height() -> void:
	var level := await _spawn_level()
	var player: Player = level.get_node("Player")
	PlayerInput.set_touch_move(Vector2.ZERO)
	await _wait(0.3)
	var ground_y := player.global_position.y
	PlayerInput.press_jump()
	var apex := ground_y
	for i in int(1.2 * PHYSICS_FPS):
		await get_tree().physics_frame
		apex = maxf(apex, player.global_position.y)
	var height := apex - ground_y
	_check(absf(height - Player.JUMP_HEIGHT) < 0.2,
		"Gemessene Sprunghoehe: %.2f m (erwartet ~1,8 m)" % height)
	_check(player.is_on_floor(), "Nach dem Sprung wieder auf dem Boden")
	await _despawn(level)

## GDD Abschnitt 2: Klettern mit 2 m/s, oben automatisch auf die Kante ziehen.
func _test_climbing() -> void:
	var level := await _spawn_level()
	var player: Player = level.get_node("Player")
	var zone: ClimbZone = level.get_node("Kletterzonen/Regenrinne1")
	player.global_position = Vector3(zone.global_position.x, 0.4, 0.0)
	await _wait(0.2)
	var start_y := player.global_position.y
	# Achtung: Vector2.UP waere (0, -1); der Joystick liefert "hoch" als +1.
	PlayerInput.set_touch_move(Vector2(0.0, 1.0))
	await _wait(0.8)
	_check(player.state == Player.State.CLIMB, "Zustand ist KLETTERN")
	var climbed := player.global_position.y - start_y
	_check(climbed > 1.2 and climbed < 2.0,
		"Kletterstrecke in 0,8 s: %.2f m (erwartet ~1,6 m)" % climbed)
	await _wait(1.5)
	PlayerInput.set_touch_move(Vector2.ZERO)
	await _wait(0.5)
	_check(player.global_position.y > 2.9,
		"Oben auf dem Balkon angekommen: y = %.2f" % player.global_position.y)
	_check(player.state != Player.State.CLIMB, "Klettern oben beendet")

	await _check_climb_zones(level, player)
	await _despawn(level)

## GDD Abschnitt 2: automatisches Festhalten an greifbaren Kanten.
func _test_ledge_grab() -> void:
	var level := await _spawn_level()
	var player: Player = level.get_node("Player")
	var ledge: LedgeZone = level.get_node("Kanten/KanteDachC")
	player.global_position = ledge.get_hang_point() + Vector3(0.0, 1.2, 0.0)
	player.velocity = Vector3.ZERO
	PlayerInput.set_touch_move(Vector2.ZERO)
	var grabbed := false
	for i in int(1.5 * PHYSICS_FPS):
		await get_tree().physics_frame
		if player.state == Player.State.HANG:
			grabbed = true
			break
	_check(grabbed, "Katze haelt sich automatisch an der Kante fest")
	if grabbed:
		PlayerInput.press_jump()
		await _wait(1.0)
		_check(player.global_position.y > 5.9,
			"Nach dem Hochziehen auf dem Dach: y = %.2f" % player.global_position.y)
	await _despawn(level)

## GDD Abschnitt 2: die schwerste Dachluecke (3,2 m) muss aus dem Lauf
## ueberwindbar sein - notfalls faengt die Kante am anderen Rand die Katze auf.
func _test_hard_gap() -> void:
	var level := await _spawn_level()
	var player: Player = level.get_node("Player")
	var roof_b: Node3D = level.get_node("Welt/DachB")
	var roof_c: Node3D = level.get_node("Welt/DachC")
	var edge_b: float = roof_b.global_position.x + roof_b.size.x * 0.5
	var edge_c: float = roof_c.global_position.x - roof_c.size.x * 0.5
	_check(absf((edge_c - edge_b) - 3.2) < 0.05,
		"Dachluecke misst %.2f m (geplant 3,2 m)" % (edge_c - edge_b))

	player.global_position = Vector3(edge_b - 3.0, 6.4, 0.0)
	player.velocity = Vector3.ZERO
	await _wait(0.2)
	PlayerInput.set_touch_move(Vector2.RIGHT)
	var jumped := false
	for i in int(3.0 * PHYSICS_FPS):
		await get_tree().physics_frame
		if not jumped and player.global_position.x >= edge_b - 0.25:
			PlayerInput.press_jump()
			jumped = true
		if jumped and player.is_on_floor() and player.global_position.x > edge_c:
			break
	PlayerInput.set_touch_move(Vector2.ZERO)
	await _wait(0.6)
	# Die Luecke liegt bewusst am Limit der Sprungweite: entweder landet die
	# Katze auf dem Dach oder die Kante faengt sie auf - beides ist gewollt.
	var landed := player.global_position.x > edge_c and player.global_position.y > 5.9
	var hanging := player.state == Player.State.HANG
	_check(landed or hanging,
		"Sprung ueber die 3,2-m-Luecke endet auf dem Dach oder an der Kante (x = %.2f, y = %.2f)"
			% [player.global_position.x, player.global_position.y])
	if hanging:
		PlayerInput.press_jump()
		await _wait(1.0)
		_check(player.global_position.x > edge_c and player.global_position.y > 5.9,
			"Nach dem Hochziehen steht die Katze auf dem Dach (x = %.2f, y = %.2f)"
				% [player.global_position.x, player.global_position.y])
	await _despawn(level)

## GDD Abschnitt 3: Fischgraete +1 LP, ganzer Fisch fuellt auf, Maximum gilt.
func _test_food() -> void:
	var level := await _spawn_level()
	var player: Player = level.get_node("Player")
	var bone: Collectible = level.get_node("Futter/Graete1")
	player.health = 1
	player.global_position = bone.global_position
	await _wait(0.2)
	_check(player.health == 2, "Fischgraete gibt +1 LP (ist %d)" % player.health)

	var fish: Collectible = level.get_node("Futter/GanzerFisch")
	player.health = 1
	player.global_position = fish.global_position
	await _wait(0.2)
	_check(player.health == player.max_health,
		"Ganzer Fisch fuellt auf %d LP (ist %d)" % [player.max_health, player.health])

	var bone2: Collectible = level.get_node("Futter/Graete2")
	player.global_position = bone2.global_position
	await _wait(0.2)
	_check(player.health == player.max_health,
		"LP ueberschreiten das Maximum nicht (ist %d)" % player.health)
	await _despawn(level)

## GDD Abschnitt 3: Treffer -1 LP, 1 s Unverwundbarkeit, Rueckstoss.
func _test_damage_and_invulnerability() -> void:
	var level := await _spawn_level(LEVEL_PATH, true)
	var player: Player = level.get_node("Player")
	var dog: Dog = level.get_node("Gegner/KleinerHund")
	var before := player.health
	player.global_position = dog.global_position
	await _wait(0.1)
	_check(player.health == before - 1,
		"Treffer kostet genau 1 LP (%d -> %d)" % [before, player.health])
	_check(player.is_invulnerable, "Nach dem Treffer unverwundbar")
	_check(absf(player.velocity.x) > 0.5 and player.velocity.y > 0.0,
		"Rueckstoss weg vom Gegner wirkt")

	# Waehrend der Unverwundbarkeit darf kein zweiter Treffer zaehlen.
	var during := player.health
	player.global_position = dog.global_position
	await _wait(0.3)
	_check(player.health == during, "Kein zweiter Treffer waehrend der Unverwundbarkeit")

	# Nach 1 s laeuft die Unverwundbarkeit ab. Dafuer muessen die Gegner
	# stillstehen, sonst trifft der Hund sofort wieder - was richtig waere.
	level.get_node("Gegner").process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(5.0, 0.4, 0.0)
	await _wait(1.2)
	_check(not player.is_invulnerable, "Unverwundbarkeit endet nach 1 s")
	_check(player.visual.visible, "Figur ist nach dem Blinken wieder sichtbar")
	await _despawn(level)

## Aus dem Spieltest: beim Fallen und Herunterklettern muss die Kamera
## schnell genug mitgehen, damit der Landeplatz sichtbar bleibt.
func _test_camera_follows_fall() -> void:
	var level := await _spawn_level()
	var player: Player = level.get_node("Player")
	var camera: FollowCamera = level.get_node("Camera3D")
	# Freier Fall aus 9 m ueber einem leeren Strassenstueck.
	player.global_position = Vector3(15.0, 9.0, 0.0)
	player.velocity = Vector3.ZERO
	await _wait(0.3)
	var worst_lag := 0.0
	for i in int(2.0 * PHYSICS_FPS):
		await get_tree().physics_frame
		var lag: float = camera.global_position.y - (player.global_position.y + camera.offset.y)
		worst_lag = maxf(worst_lag, lag)
		if player.is_on_floor():
			break
	_check(worst_lag < 2.0,
		"Kamera bleibt beim Fallen dran (groesster Rueckstand %.2f m)" % worst_lag)
	await _wait(1.0)
	var settled: float = absf(camera.global_position.y - (player.global_position.y + camera.offset.y))
	_check(settled < 0.5,
		"Kamera hat nach der Landung aufgeschlossen (%.2f m Abstand)" % settled)

	# Herunterklettern zaehlt genauso als Fallen.
	var zone: ClimbZone = level.get_node("Kletterzonen/Strommast")
	player.global_position = Vector3(zone.global_position.x, zone.get_top_y() - 0.3, 0.0)
	await _wait(0.3)
	PlayerInput.set_touch_move(Vector2(0.0, -1.0))
	await _wait(1.2)
	var climb_lag: float = camera.global_position.y - (player.global_position.y + camera.offset.y)
	PlayerInput.set_touch_move(Vector2.ZERO)
	_check(climb_lag < 0.8,
		"Kamera folgt beim Herunterklettern (Rueckstand %.2f m)" % climb_lag)
	await _despawn(level)

## GDD Abschnitt 4: Hunde warnen erst, jagen dann, koennen aber nicht klettern.
func _test_dog_states() -> void:
	var level := await _spawn_level(LEVEL_PATH, true)
	var player: Player = level.get_node("Player")
	var dog: Dog = level.get_node("Gegner/KleinerHund")
	player.global_position = Vector3(5.0, 0.4, 0.0)
	await _wait(0.5)
	_check(dog.state in [Dog.State.PATROUILLE, Dog.State.RUHEN],
		"Ohne Katze patrouilliert der Hund (Zustand %d)" % dog.state)

	player.global_position = Vector3(dog.global_position.x + 3.5, 0.4, 0.0)
	await _wait(0.25)
	_check(dog.state == Dog.State.WARNUNG,
		"Hund warnt erst (Zustand %d)" % dog.state)
	await _wait(dog.warning_time + 0.3)
	_check(dog.state == Dog.State.JAGEN,
		"Nach der Warnzeit jagt der Hund (Zustand %d)" % dog.state)

	# Katze bringt sich auf der Fassade in Sicherheit.
	player.global_position = Vector3(dog.global_position.x + 1.5, 4.0, 0.0)
	await _wait(0.4)
	_check(dog.state in [Dog.State.BELLEN_NACH_OBEN, Dog.State.RUECKKEHR],
		"Ausser Reichweite bellt der Hund nach oben (Zustand %d)" % dog.state)
	await _wait(2.0)
	_check(dog.global_position.y < 1.2,
		"Hund bleibt auf Strassenebene (y = %.2f)" % dog.global_position.y)
	await _despawn(level)

## GDD Abschnitt 4: Revierkatzen verteidigen nur ihr Gebiet.
func _test_territory_cat() -> void:
	var level := await _spawn_level(LEVEL_PATH, true)
	var player: Player = level.get_node("Player")
	var cat: TerritoryCat = level.get_node("Gegner/Revierkatze")
	player.global_position = Vector3(5.0, 0.4, 0.0)
	await _wait(0.4)
	_check(cat.state != TerritoryCat.State.ANGRIFF,
		"Ohne Eindringling kein Angriff (Zustand %d)" % cat.state)

	player.global_position = Vector3(cat.home_position.x + 1.0, cat.home_position.y + 0.1, 0.0)
	await _wait(0.25)
	_check(cat.state == TerritoryCat.State.WARNUNG,
		"Revierkatze macht erst Buckel (Zustand %d)" % cat.state)
	var attacked := false
	for i in int((cat.warning_time + 1.2) * PHYSICS_FPS):
		await get_tree().physics_frame
		if cat.state == TerritoryCat.State.ANGRIFF:
			attacked = true
			break
	_check(attacked, "Nach der Warnzeit springt die Revierkatze an")

	# Revier verlassen: die Revierkatze zieht sich zurueck.
	player.global_position = Vector3(5.0, 0.4, 0.0)
	await _wait(2.5)
	_check(cat.state in [TerritoryCat.State.RUECKZUG, TerritoryCat.State.SITZEN,
			TerritoryCat.State.PATROUILLE],
		"Ausserhalb des Reviers zieht sie sich zurueck (Zustand %d)" % cat.state)
	_check(absf(cat.global_position.x - cat.home_position.x) <= cat.territory_half_width + 1.0,
		"Revierkatze bleibt in ihrem Revier (x = %.2f)" % cat.global_position.x)
	await _despawn(level)

## GDD Abschnitt 4: Autos kuendigen sich per Scheinwerfer an und kosten 1 LP.
func _test_car() -> void:
	var level := await _spawn_level(LEVEL_PATH, true)
	var player: Player = level.get_node("Player")
	var car: Car = level.get_node("Gegner/Auto")
	player.global_position = Vector3(20.0, 0.4, 0.0)
	car.pause_time = 0.3
	car.warning_time = 0.4
	car.restart_cycle(0.15)
	await _wait(0.3)
	_check(car.state == Car.State.WARNUNG,
		"Auto kuendigt sich mit Scheinwerferlicht an (Zustand %d)" % car.state)
	await _wait(0.5)
	_check(car.state == Car.State.FAHREN,
		"Nach der Warnung faehrt das Auto los (Zustand %d)" % car.state)

	var before := player.health
	car.global_position = Vector3(player.global_position.x, car.global_position.y, 0.0)
	await _wait(0.2)
	_check(player.health == before - 1,
		"Auto kostet einen Lebenspunkt (%d -> %d)" % [before, player.health])
	await _despawn(level)

## GDD Abschnitt 7: Level 0 erklaert nur ueber Symbole und kann nicht scheitern.
## Der Sprung ueber das Auto muss Timingfehler verzeihen - ein Fenster von
## Sekundenbruchteilen waere fuer die Zielgruppe ab 5 Jahren unbrauchbar.
func _test_car_jump_tolerance() -> void:
	var level := await _spawn_level(LEVEL_PATH, true)
	var player: Player = level.get_node("Player")
	var car: Car = level.get_node("Gegner/Auto")
	level.get_node("Gegner/KleinerHund").free()
	level.get_node("Gegner/GrosserHund").free()
	level.get_node("Gegner/Revierkatze").free()

	var trigger_points := [2.4, 3.0, 3.6, 4.2, 4.8]
	var successes := 0
	for trigger in trigger_points:
		player.global_position = Vector3(20.0, 0.4, 0.0)
		player.velocity = Vector3.ZERO
		player.health = player.max_health
		player.is_invulnerable = false
		car.warning_time = 0.2
		car.restart_cycle(0.1)
		await _wait(0.25)
		var jumped := false
		for i in int(4.0 * PHYSICS_FPS):
			await get_tree().physics_frame
			if car.state != Car.State.FAHREN:
				continue
			var gap: float = car.global_position.x - player.global_position.x
			if not jumped and gap > 0.0 and gap <= trigger:
				PlayerInput.press_jump()
				jumped = true
			if jumped and car.global_position.x < player.global_position.x - 3.0:
				break
		if player.health == player.max_health:
			successes += 1
	_check(successes >= 3,
		"Der Sprung verzeiht Timingfehler (%d von %d Absprungpunkten gelingen)"
			% [successes, trigger_points.size()])
	await _despawn(level)

## Aus dem Spieltest: die Katze muss weglaufen koennen. Kein Gegner darf
## ihre Laufgeschwindigkeit erreichen.
func _test_flight_from_enemies() -> void:
	_check(Dog.PARAMS[Dog.DogSize.KLEIN]["chase_speed"] < Player.RUN_SPEED,
		"Kleiner Hund jagt langsamer als die Katze laeuft (%.1f < %.1f m/s)"
			% [Dog.PARAMS[Dog.DogSize.KLEIN]["chase_speed"], Player.RUN_SPEED])
	_check(Dog.PARAMS[Dog.DogSize.GROSS]["chase_speed"] < Player.RUN_SPEED,
		"Grosser Hund jagt langsamer als die Katze laeuft (%.1f < %.1f m/s)"
			% [Dog.PARAMS[Dog.DogSize.GROSS]["chase_speed"], Player.RUN_SPEED])

	var level := await _spawn_level(LEVEL_PATH, true)
	var player: Player = level.get_node("Player")
	var dog: Dog = level.get_node("Gegner/KleinerHund")
	# Nur den kleinen Hund pruefen, sonst mischen Auto und grosser Hund mit.
	level.get_node("Gegner/Auto").free()
	level.get_node("Gegner/GrosserHund").free()
	level.get_node("Gegner/Revierkatze").free()
	player.global_position = Vector3(dog.global_position.x + 2.5, 0.4, 0.0)
	await _wait(0.4)
	var health_before := player.health
	PlayerInput.set_touch_move(Vector2.RIGHT)
	await _wait(3.0)
	PlayerInput.set_touch_move(Vector2.ZERO)
	var distance: float = absf(player.global_position.x - dog.global_position.x)
	_check(player.health == health_before,
		"Wegrennen gelingt ohne Treffer (LP %d -> %d)" % [health_before, player.health])
	_check(distance > 6.0, "Der Abstand waechst beim Weglaufen (%.1f m)" % distance)
	await _despawn(level)

## Nach einem Treffer laesst der Gegner los, damit die Katze wegkommt.
func _test_hit_recovery() -> void:
	var level := await _spawn_level(LEVEL_PATH, true)
	var player: Player = level.get_node("Player")
	var dog: Dog = level.get_node("Gegner/KleinerHund")
	level.get_node("Gegner/Auto").free()
	player.global_position = dog.global_position
	await _wait(0.2)
	var after_hit := player.health
	_check(after_hit == player.max_health - 1,
		"Erster Treffer kostet einen Lebenspunkt (LP %d)" % after_hit)
	# Selbst wenn die Katze liegen bleibt, folgt kein sofortiger zweiter Treffer.
	await _wait(1.4)
	_check(player.health == after_hit,
		"Kein zweiter Treffer in der Erholungszeit (LP %d)" % player.health)
	await _despawn(level)

## Aus dem Spieltest: wer rechtzeitig springt, nimmt vom Auto keinen Schaden.
func _test_car_is_jumpable() -> void:
	var level := await _spawn_level(LEVEL_PATH, true)
	var player: Player = level.get_node("Player")
	var car: Car = level.get_node("Gegner/Auto")
	level.get_node("Gegner/KleinerHund").free()
	level.get_node("Gegner/GrosserHund").free()
	level.get_node("Gegner/Revierkatze").free()
	player.global_position = Vector3(20.0, 0.4, 0.0)
	await _wait(0.3)
	var health_before := player.health
	car.warning_time = 0.3
	car.restart_cycle(0.1)

	var jumped := false
	var passed := false
	for i in int(5.0 * PHYSICS_FPS):
		await get_tree().physics_frame
		if car.state != Car.State.FAHREN:
			continue
		var gap: float = car.global_position.x - player.global_position.x
		if not jumped and gap > 0.0 and gap <= 3.4:
			PlayerInput.press_jump()
			jumped = true
		if jumped and car.global_position.x < player.global_position.x - 3.0:
			passed = true
			break
	_check(jumped, "Auto kam in Sprungweite")
	_check(passed, "Auto ist unter der Katze durchgefahren")
	_check(player.health == health_before,
		"Rechtzeitiger Sprung ueber das Auto kostet nichts (LP %d -> %d)"
			% [health_before, player.health])
	await _despawn(level)

## GDD Abschnitt 12: Levels werden nacheinander freigeschaltet.
func _test_level_catalog() -> void:
	_check(Game.catalog != null, "Levelkatalog ist geladen")
	_check(Game.level_count() >= 2, "Katalog kennt Tutorial und Graubox (%d)" % Game.level_count())
	var all_present := true
	for index in Game.level_count():
		var data := Game.catalog.get_level(index)
		if data == null or not ResourceLoader.exists(data.scene_path):
			all_present = false
	_check(all_present, "Jeder Katalogeintrag zeigt auf eine vorhandene Szene")
	_check(Game.catalog.index_of_scene(TUTORIAL_PATH) == 0, "Das Tutorial steht an erster Stelle")

## GDD Abschnitt 13: Fortschritt und Toneinstellungen per ConfigFile.
func _test_save_and_progress() -> void:
	SaveGame.reset_progress()
	_check(SaveGame.is_unlocked(0), "Level 0 ist immer offen")
	_check(not SaveGame.is_unlocked(1), "Das zweite Level ist zuerst gesperrt")
	SaveGame.mark_completed(0)
	_check(SaveGame.is_unlocked(1), "Nach dem Tutorial ist das naechste Level frei")
	_check(SaveGame.next_open_level(Game.level_count()) == 1,
		"\"Spielen\" setzt beim naechsten ungeloesten Level fort")

	SaveGame.set_music_on(false)
	# Neu einlesen: kommt alles aus der Datei zurueck?
	SaveGame.completed_levels.clear()
	SaveGame.music_on = true
	SaveGame.load_game()
	_check(SaveGame.is_completed(0), "Fortschritt uebersteht das Neuladen")
	_check(not SaveGame.music_on, "Toneinstellung uebersteht das Neuladen")

	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	_check(music_bus > 0 and sfx_bus > 0, "Audio-Busse Music und SFX sind angelegt")
	SaveGame.apply_audio()
	_check(AudioServer.is_bus_mute(music_bus), "Der Musikschalter stummt den Bus")
	SaveGame.set_music_on(true)
	_check(not AudioServer.is_bus_mute(music_bus), "Und schaltet ihn wieder ein")

## GDD Abschnitt 12: Startbild und Hauptmenue.
func _test_menu_screens() -> void:
	var title: Node = load("res://scenes/ui/title_screen.tscn").instantiate()
	get_tree().root.add_child(title)
	await get_tree().process_frame
	_check(title.get_node_or_null("Vignette/Kirchturm") != null,
		"Startbild zeigt die Daemmerungsszene mit Kirchturm")
	_check(title.get_node_or_null("Vignette/Katze") != null,
		"Die Katze sitzt als Silhouette auf dem Dach")
	title.free()
	await get_tree().process_frame

	SaveGame.reset_progress()
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	var list: VBoxContainer = menu.get_node("UI/Root/LevelPanel/LevelListe")
	_check(list.get_child_count() == Game.level_count(),
		"Levelauswahl listet alle %d Levels" % Game.level_count())
	if list.get_child_count() >= 2:
		_check(not (list.get_child(0) as Button).disabled, "Level 0 ist anwaehlbar")
		_check((list.get_child(1) as Button).disabled,
			"Noch gesperrte Levels sind nicht anwaehlbar")
	menu.free()
	await get_tree().process_frame

func _test_tutorial_level() -> void:
	var level := await _spawn_level(TUTORIAL_PATH, true)
	var player: Player = level.get_node("Player")
	var hud: HUD = level.get_node("HUD")
	_check(player.no_fail, "Im Tutorial ist Scheitern ausgeschlossen")

	player.global_position = Vector3(1.5, 0.4, 0.0)
	await _wait(0.3)
	_check(hud.hint_overlay.current_hint() == HintOverlay.Hint.LAUFEN,
		"Laufen-Symbol erscheint am Start")
	player.global_position = Vector3(9.6, 0.4, 0.0)
	await _wait(0.3)
	_check(hud.hint_overlay.current_hint() == HintOverlay.Hint.KLETTERN,
		"Klettern-Symbol erscheint an der Regenrinne")

	# Der schlafende Hund ist ungefaehrlich - die Katze klettert ueber ihn hinweg.
	var dog: Dog = level.get_node("Gegner/SchlafenderHund")
	var before := player.health
	player.global_position = dog.global_position
	await _wait(0.5)
	_check(player.health == before, "Schlafender Hund tut der Katze nichts")
	_check(dog.state in [Dog.State.SCHLAFEN, Dog.State.BELLEN_NACH_OBEN],
		"Schlafender Hund wacht hoechstens kurz auf (Zustand %d)" % dog.state)

	# Die passive Revierkatze faucht nur.
	var cat: TerritoryCat = level.get_node("Gegner/PassiveRevierkatze")
	player.global_position = Vector3(cat.home_position.x + 1.0, cat.home_position.y + 0.1, 0.0)
	await _wait(cat.warning_time + 0.8)
	_check(cat.state == TerritoryCat.State.WARNUNG,
		"Passive Revierkatze faucht nur und greift nicht an (Zustand %d)" % cat.state)
	_check(player.health == before, "Passive Revierkatze kostet keinen Lebenspunkt")

	# Auch im Tutorial muss jede Rinne bis nach oben fuehren.
	level.get_node("Gegner").process_mode = Node.PROCESS_MODE_DISABLED
	await _check_climb_zones(level, player)

	# Die kleine Dachluecke muss aus dem Lauf zu schaffen sein.
	var roof_a: Node3D = level.get_node("Welt/DachA")
	var roof_b: Node3D = level.get_node("Welt/DachB")
	var gap: float = (roof_b.global_position.x - roof_b.size.x * 0.5) \
		- (roof_a.global_position.x + roof_a.size.x * 0.5)
	_check(gap > 1.0 and gap < 1.8,
		"Tutorial-Dachluecke ist klein gehalten (%.2f m)" % gap)

	# Ziel des Tutorials.
	var bowl: FoodBowl = level.get_node("Futternapf")
	player.global_position = bowl.global_position + Vector3(0.0, 0.4, 0.0)
	await _wait(0.3)
	_check(Game.is_level_finished, "Futternapf beendet auch das Tutorial")
	await _despawn(level)

func _test_hud_paws() -> void:
	var level := await _spawn_level()
	var player: Player = level.get_node("Player")
	var hud: HUD = level.get_node("HUD")
	var paws: HBoxContainer = hud.paw_container
	_check(paws.get_child_count() == player.max_health,
		"HUD zeigt %d Pfoten (sind %d)" % [player.max_health, paws.get_child_count()])
	player.take_damage(1, Vector3(5.0, 0.0, 0.0))
	await _wait(0.1)
	var filled := 0
	for paw in paws.get_children():
		if (paw as PawIcon).filled:
			filled += 1
	_check(filled == player.health,
		"HUD zeigt %d gefuellte Pfoten (LP: %d)" % [filled, player.health])
	await _despawn(level)

## GDD Abschnitt 5: Futternapf auf dem beleuchteten Balkon beendet das Level.
func _test_goal() -> void:
	var level := await _spawn_level()
	var player: Player = level.get_node("Player")
	level.get_node("HUD").queue_free()   # kein automatisches Pausieren im Test
	await get_tree().process_frame
	var bowl: FoodBowl = level.get_node("Futternapf")
	player.global_position = bowl.global_position + Vector3(0.0, 0.4, 0.0)
	await _wait(0.2)
	_check(Game.is_level_finished, "Levelziel erreicht meldet das Level als beendet")
	_check(player.state == Player.State.VICTORY, "Katze ist im Siegeszustand")
	await _despawn(level)

## GDD Abschnitt 3: bei 0 LP Game Over; im Tutorial-Modus unmoeglich.
func _test_game_over() -> void:
	var level := await _spawn_level()
	var player: Player = level.get_node("Player")
	level.get_node("HUD").queue_free()   # kein automatischer Neustart im Test
	await get_tree().process_frame
	# Lambdas in GDScript fangen Variablen als Kopie ein - daher ein Array.
	var failed := [false]
	var on_failed := func(_d): failed[0] = true
	Game.level_failed.connect(on_failed)
	for i in player.max_health:
		player.is_invulnerable = false
		player.take_damage(1, Vector3(player.global_position.x + 2.0, 0.0, 0.0))
		await _wait(0.1)
	_check(player.health == 0, "LP auf 0 (ist %d)" % player.health)
	_check(player.state == Player.State.DEAD, "Zustand ist TOT")
	_check(failed[0], "Game Over wird gemeldet")
	Game.level_failed.disconnect(on_failed)
	await _despawn(level)

	# Tutorial-Modus (Level 0): Scheitern ist unmoeglich.
	var level2 := await _spawn_level()
	var player2: Player = level2.get_node("Player")
	level2.get_node("HUD").queue_free()
	await get_tree().process_frame
	player2.no_fail = true
	for i in 5:
		player2.is_invulnerable = false
		player2.take_damage(1, Vector3(player2.global_position.x + 2.0, 0.0, 0.0))
		await _wait(0.1)
	_check(player2.health == 1, "Im Tutorial-Modus bleibt 1 LP (ist %d)" % player2.health)
	_check(player2.state != Player.State.DEAD, "Im Tutorial-Modus kein Game Over")
	await _despawn(level2)

# --- Hilfen -----------------------------------------------------------------

## Jede Kletterzone eines Levels muss tatsaechlich bis nach oben fuehren -
## eine Platte ueber der Rinne wuerde die Katze sonst blockieren.
func _check_climb_zones(level: Node, player: Player) -> void:
	var zones := level.get_node_or_null("Kletterzonen")
	if zones == null:
		return
	for child in zones.get_children():
		var climb := child as ClimbZone
		var bottom: float = climb.global_position.y - climb.height * 0.5
		player.global_position = Vector3(climb.global_position.x, bottom + 0.4, 0.0)
		player.velocity = Vector3.ZERO
		await _wait(0.2)
		PlayerInput.set_touch_move(Vector2(0.0, 1.0))
		await _wait(climb.height / 2.0 + 2.0)
		PlayerInput.set_touch_move(Vector2.ZERO)
		await _wait(0.4)
		_check(player.global_position.y > climb.get_top_y() - 0.1,
			"%s fuehrt bis nach oben (y = %.2f, Oberkante %.2f)"
				% [climb.name, player.global_position.y, climb.get_top_y()])

func _spawn_level(path: String = LEVEL_PATH, keep_enemies: bool = false) -> Node:
	PlayerInput.reset()
	get_tree().paused = false
	var scene: PackedScene = load(path)
	var level := scene.instantiate()
	if not keep_enemies:
		# Mechanik-Tests sollen nicht von patrouillierenden Gegnern gestoert werden.
		var enemies := level.get_node_or_null("Gegner")
		if enemies != null:
			for enemy in enemies.get_children():
				enemies.remove_child(enemy)
				enemy.free()
	get_tree().root.add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return level

func _despawn(level: Node) -> void:
	PlayerInput.reset()
	level.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	Game.is_level_finished = false

func _wait(seconds: float) -> void:
	for i in int(round(seconds * PHYSICS_FPS)):
		await get_tree().physics_frame

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", description)
	else:
		print("  FEHL ", description)
		_failures.append(description)

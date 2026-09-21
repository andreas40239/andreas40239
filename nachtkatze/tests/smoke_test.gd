extends Node
## Kopflose Funktionspruefung fuer Meilenstein 1 und 2.
##
## Start:  godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn
## Beendet sich mit Exit-Code 0 (alles gruen) oder 1 (mindestens ein Fehler).

const LEVEL_PATH := "res://scenes/levels/level_greybox.tscn"
const PHYSICS_FPS := 60.0

var _failures: Array[String] = []
var _checks := 0

func _ready() -> void:
	# Erst einen Frame abwarten: waehrend _ready baut der Baum noch auf und
	# add_child() auf die Wurzel schlaegt fehl.
	await get_tree().process_frame
	await _run_all()
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
	await _test_damage_and_invulnerability()
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

	# Jede Kletterzone im Level muss tatsaechlich nach oben fuehren.
	for child in level.get_node("Kletterzonen").get_children():
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
	var level := await _spawn_level()
	var player: Player = level.get_node("Player")
	var hazard: Hazard = level.get_node("Gefahren/GefahrStrasse")
	var before := player.health
	player.global_position = hazard.global_position
	await _wait(0.1)
	_check(player.health == before - 1,
		"Treffer kostet genau 1 LP (%d -> %d)" % [before, player.health])
	_check(player.is_invulnerable, "Nach dem Treffer unverwundbar")
	_check(absf(player.velocity.x) > 0.5 and player.velocity.y > 0.0,
		"Rueckstoss weg vom Gegner wirkt")

	# Waehrend der Unverwundbarkeit darf kein zweiter Treffer zaehlen.
	var during := player.health
	player.global_position = hazard.global_position
	await _wait(0.3)
	_check(player.health == during, "Kein zweiter Treffer waehrend der Unverwundbarkeit")

	# Nach 1 s laeuft die Unverwundbarkeit ab.
	await _wait(1.0)
	_check(not player.is_invulnerable, "Unverwundbarkeit endet nach 1 s")
	_check(player.visual.visible, "Figur ist nach dem Blinken wieder sichtbar")
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

func _spawn_level() -> Node:
	PlayerInput.reset()
	get_tree().paused = false
	var scene: PackedScene = load(LEVEL_PATH)
	var level := scene.instantiate()
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

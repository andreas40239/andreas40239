extends Node
## Kopflose Pruefung der Level 1-10 gegen die Levelprogression (GDD Abschnitt 5 und 6).
##
## Start:  godot --headless --path . --fixed-fps 60 res://tests/level_test.tscn
## Beendet sich mit Exit-Code 0 (alles gruen) oder 1 (mindestens ein Fehler).
##
## Die Spielbarkeit (Ziel erreichbar, Fassadenroute an den Hunden vorbei,
## Sprungweiten) prueft schon tools/level_erzeugen.py beim Erzeugen. Hier wird
## nachgemessen, was nur im laufenden Spiel sichtbar ist.

const PHYSICS_FPS := 60.0
const WATCHDOG_SECONDS := 900

const T := LevelData.TimeOfDay
## GDD Abschnitt 6: Tageszeit, Stockwerke, kleine/grosse Hunde, Katzen, Autos, Futter.
const TABLE := [
	[T.TAG, 2, 1, 0, 0, 0, "viel"],
	[T.TAG, 2, 2, 0, 0, 0, "viel"],
	[T.TAG, 3, 1, 1, 1, 0, "mittel"],
	[T.DAEMMERUNG, 3, 1, 1, 1, 1, "mittel"],
	[T.DAEMMERUNG, 3, 1, 1, 2, 1, "mittel"],
	[T.DAEMMERUNG, 4, 1, 1, 2, 2, "mittel"],
	[T.NACHT, 4, 1, 1, 2, 2, "wenig"],
	[T.NACHT, 4, 2, 1, 2, 2, "wenig"],
	[T.NACHT, 5, 2, 1, 3, 3, "wenig"],
	[T.NACHT, 5, 2, 1, 3, 3, "wenig"],
]
const DENSITY := {"viel": 1.5, "mittel": 1.0, "wenig": 0.6}
## GDD Abschnitt 13: nur wenige echte Lichtquellen je Level.
const MAX_LIGHTS := 6

var _failures: Array[String] = []
var _checks := 0
var _finished := false
var _last_check := "(noch keine)"
var _food_counts := {}

func _ready() -> void:
	await get_tree().process_frame
	_start_watchdog()
	var saved_progress := SaveGame.completed_levels.duplicate()
	for number in range(1, TABLE.size() + 1):
		print("\n== Level %d ==" % number)
		await _test_level(number)
	_check_food_progression()
	SaveGame.completed_levels = saved_progress
	SaveGame.save_game()
	_finished = true
	print("\n--- Ergebnis: %d Pruefungen, %d Fehler ---" % [_checks, _failures.size()])
	for failure in _failures:
		print("FEHLER: ", failure)
	get_tree().quit(1 if _failures.size() > 0 else 0)

func _start_watchdog() -> void:
	var watchdog := func() -> void:
		await get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout
		if not _finished:
			print("\n--- ABBRUCH: Testlauf haengt (letzte Pruefung: %s) ---" % _last_check)
			get_tree().quit(2)
	watchdog.call()

func _test_level(number: int) -> void:
	var row: Array = TABLE[number - 1]
	var path := "res://scenes/levels/level_%02d.tscn" % number
	_check(Game.catalog.index_of_scene(path) == number, "L%d steht im Katalog an Stelle %d" % [number, number])

	# Aufbau mit Gegnern
	var level := await _spawn(path, true)
	var data: LevelData = level.level_data
	_check(data != null and data.scene_path == path, "L%d hat passende LevelData" % number)
	_check(data.time_of_day == row[0], "L%d Tageszeit laut GDD" % number)
	var small := 0
	var big := 0
	var cats := 0
	var cars := 0
	for enemy in level.get_node("Gegner").get_children():
		if enemy is Dog:
			if enemy.dog_size == Dog.DogSize.KLEIN:
				small += 1
			else:
				big += 1
		elif enemy is TerritoryCat:
			cats += 1
		elif enemy is Car:
			cars += 1
	_check(small == row[2] and big == row[3],
		"L%d Hunde: %d klein, %d gross (GDD %d/%d)" % [number, small, big, row[2], row[3]])
	_check(cats == row[4], "L%d Revierkatzen: %d (GDD %d)" % [number, cats, row[4]])
	_check(cars == row[5], "L%d fahrende Autos: %d (GDD %d)" % [number, cars, row[5]])
	_check(data.small_dogs == small and data.big_dogs == big and data.territory_cats == cats
			and data.cars == cars, "L%d LevelData stimmt mit der Szene ueberein" % number)
	_check(is_equal_approx(data.food_density, DENSITY[row[6]]),
		"L%d Futterdichte %s (%.2f)" % [number, row[6], data.food_density])
	_food_counts[number] = level.get_node("Futter").get_child_count()

	var bowl: FoodBowl = level.get_node("Futternapf")
	_check(is_equal_approx(bowl.global_position.y, row[1] * 3.0),
		"L%d Ziel auf %d Stockwerken Hoehe (y = %.1f)" % [number, row[1], bowl.global_position.y])
	var lights := level.get_node("Lichter").get_children()
	_check(level.get_node_or_null("Lichter/Ziellicht") != null, "L%d Zielbalkon ist beleuchtet" % number)
	_check(lights.size() <= MAX_LIGHTS, "L%d hoechstens %d Lichtquellen (%d)" % [number, MAX_LIGHTS, lights.size()])
	if data.time_of_day != T.TAG:
		_check(lights.size() >= 3, "L%d Laternen leuchten abends (%d Lichter)" % [number, lights.size()])
	var night := data.time_of_day == T.NACHT and number >= 7
	_check((level.get_node_or_null("Nachtsicht") != null) == night,
		"L%d Sicht %s" % [number, "eingeschraenkt" if night else "frei"])
	if number >= 5 and number != 6:
		_check(level.get_node("Leitungen").get_child_count() >= 1, "L%d hat Leitungen zum Balancieren" % number)
	if number >= 2:
		var gaps := 0
		for part in level.get_node("Welt").get_children():
			if part is AssetPiece and part.kind == AssetKit.Kind.ZAUN_MIT_LUECKE:
				gaps += 1
		if number == 2:
			_check(gaps >= 2, "L2 fuehrt Zaunluecken ein (%d)" % gaps)
	await _despawn(level)

	# Mechanik ohne Gegner
	level = await _spawn(path, false)
	var player: Player = level.get_node("Player")
	await _wait(0.5)
	_check(player.is_on_floor() and player.global_position.y < 1.0, "L%d Start auf der Strasse" % number)
	await _check_climb_zones(level, player, number)
	player.global_position = bowl_position(level) + Vector3(0.0, 0.4, 0.0)
	await _wait(0.3)
	_check(Game.is_level_finished and player.state == Player.State.VICTORY,
		"L%d Futternapf beendet das Level" % number)
	_check(SaveGame.is_completed(number), "L%d wird als geschafft gespeichert" % number)
	await _despawn(level)

func bowl_position(level: Node) -> Vector3:
	return (level.get_node("Futternapf") as Node3D).global_position

## Futter als Risikosteuerung: frueh viel, spaeter weniger (GDD Abschnitt 6).
func _check_food_progression() -> void:
	var early: float = (_food_counts[1] + _food_counts[2]) / 2.0
	var late: float = (_food_counts[7] + _food_counts[8] + _food_counts[9] + _food_counts[10]) / 4.0
	_check(early > late, "Frueh mehr Futter als spaeter (%.1f / %.1f)" % [early, late])

## Jede Kletterzone fuehrt bis nach oben (Mast: bis auf die Leitung).
func _check_climb_zones(level: Node, player: Player, number: int) -> void:
	var failed: Array[String] = []
	for zone in level.get_node("Kletterzonen").get_children():
		var climb := zone as ClimbZone
		var bottom: float = climb.global_position.y - climb.height * 0.5
		player.global_position = Vector3(climb.global_position.x, bottom + 0.4, 0.0)
		player.velocity = Vector3.ZERO
		await _wait(0.2)
		PlayerInput.set_touch_move(Vector2(0.0, 1.0))
		await _wait(climb.height / 2.0 + 1.2)
		PlayerInput.set_touch_move(Vector2.ZERO)
		await _wait(0.5)
		var top_reached := player.global_position.y > climb.get_top_y() - 0.1
		var on_wire := player.state == Player.State.BALANCE
		if not (top_reached or on_wire):
			failed.append("%s (y %.1f / %.1f)" % [climb.name, player.global_position.y, climb.get_top_y()])
	_check(failed.is_empty(), "L%d alle %d Kletterzonen fuehren nach oben %s"
		% [number, level.get_node("Kletterzonen").get_child_count(), str(failed)])

func _spawn(path: String, keep_enemies: bool) -> Node:
	PlayerInput.reset()
	get_tree().paused = false
	var level: Node = (load(path) as PackedScene).instantiate()
	if not keep_enemies:
		for enemy in level.get_node("Gegner").get_children():
			level.get_node("Gegner").remove_child(enemy)
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
	_last_check = description
	if condition:
		print("  ok   ", description)
	else:
		print("  FEHL ", description)
		_failures.append(description)

class_name LevelData
extends Resource
## Komplette Leveldefinition (GDD 9.1). Pfad und Bauplätze in Referenzkoordinaten 1920x1080.

@export var id: StringName
@export var number: int = 1
@export var display_name: String = ""
@export var world_name: String = "Sonnental"
@export var starting_currency: int = 300
@export var chaos_limit: int = 10
@export var path_points: PackedVector2Array
@export var build_spots: PackedVector2Array
@export var waves: Array[WaveData] = []
@export var available_station_ids: Array[StringName] = []
## Neue Monster, die vor Welle 1 auf einer Info-Karte vorgestellt werden.
@export var new_monster_ids: Array[StringName] = []
@export var tutorial_steps: Array[TutorialStep] = []
## Maximales Chaos für 3 / 2 / 1 Sterne.
@export var star_thresholds: Vector3i = Vector3i(0, 3, 9)
## Pause zwischen zwei Wellen (Sekunden).
@export var wave_break: float = 7.0
## Früher-Starten-Knopf zwischen den Wellen (ab Level 4).
@export var early_start: bool = false
@export var decor_seed: int = 1


func stars_for_chaos(chaos: int) -> int:
	if chaos >= chaos_limit:
		return 0
	if chaos <= star_thresholds.x:
		return 3
	if chaos <= star_thresholds.y:
		return 2
	if chaos <= star_thresholds.z:
		return 1
	return 0


func total_monsters() -> int:
	var n := 0
	for w in waves:
		n += w.monster_count()
	return n

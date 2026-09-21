extends Resource
class_name LevelData
## Datengetriebene Levelparameter (GDD Abschnitt 6 und 13).
## Balancing soll ohne Codeaenderung moeglich sein: je Level eine .tres-Datei.

enum TimeOfDay { TAG, DAEMMERUNG, NACHT }

@export var display_name: String = "Level"
## Szene dieses Levels - der Katalog findet es darueber wieder.
@export_file("*.tscn") var scene_path: String = ""
@export var time_of_day: TimeOfDay = TimeOfDay.TAG

@export_group("Leben")
## Maximale Lebenspunkte (GDD: 3 Pfoten).
@export_range(1, 9) var max_health: int = 3
## Startwert der Lebenspunkte.
@export_range(1, 9) var start_health: int = 3
## Tutorial-Modus: Lebenspunkte fallen nie unter 1, Scheitern unmoeglich (GDD Abschnitt 7).
@export var no_fail: bool = false

@export_group("Balancing")
## Reine Datenwerte fuer spaetere Meilensteine (Gegner, Autos, Futterdichte).
@export_range(0, 10) var small_dogs: int = 0
@export_range(0, 10) var big_dogs: int = 0
@export_range(0, 10) var territory_cats: int = 0
@export_range(0, 10) var cars: int = 0
@export_range(0.0, 3.0, 0.05) var food_density: float = 1.0

class_name MonsterData
extends Resource
## Statische Werte eines Monstertyps (GDD 3.2). Laufzeitwerte liegen in Monster.gd.

@export var id: StringName
@export var display_name: String = ""
@export var need_type: Needs.Type = Needs.Type.HUNGRY
## Startwert des Bedürfnisses. need_value läuft von max_need bis 0 (= FREUND).
@export var max_need: float = 100.0
## Grundgeschwindigkeit in px/s (Referenzauflösung 1920x1080).
@export var base_speed: float = 50.0
## Chaos-Punkte, wenn das Monster das Dorf noch wild erreicht.
@export var chaos_value: int = 1
## Sonnenpunkte, wenn das Monster als Freund ankommt.
@export var reward: int = 20
@export var body_color: Color = Color.WHITE
@export var size_scale: float = 1.0
## Effekt-Tag -> Resistenz (0.3 = 30 % weniger Wirkung, -0.3 = 30 % mehr Wirkung).
## Spezieller Tag &"slow" wirkt auf Verlangsamungen.
@export var effect_resistances: Dictionary = {}
## Tempo-Faktor als Freund auf dem Weg ins Dorf (Elektro: 3x).
@export var friend_speed_mult: float = 1.6
## Freund fliegt direkt (Luftlinie) ins Dorf (Flügel).
@export var friend_flies: bool = false
@export_multiline var description: String = ""

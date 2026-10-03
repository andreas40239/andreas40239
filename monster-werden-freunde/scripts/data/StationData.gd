class_name StationData
extends Resource
## Werte einer Hilfsstation (GDD Kap. 4 und 8.4).
## Stationen kennen keine Monsterklassen: sie erzeugen nur HelpEffects.

enum TargetStrategy { FIRST, MOST_NEED, MATCHING_FIRST, FASTEST }

@export var id: StringName
@export var display_name: String = ""
## Kurzer Name für die Stationskarte.
@export var short_name: String = ""
@export var supported_needs: Array[int] = []
## Needs.Type -> Wirkung pro Treffer (bzw. pro Sekunde bei Aura-Stationen).
@export var need_strengths: Dictionary = {}
## Wirkung auf Monster mit unpassendem Bedürfnis (Anteil der kleinsten Stärke). Keine Schäden!
@export var mismatch_factor: float = 0.2
@export var cost: int = 100
@export var upgrade_cost: int = 100
## Reichweite in px.
@export var help_range: float = 120.0
## Takt in Sekunden (nur Nicht-Aura).
@export var cooldown: float = 1.0
@export var is_aura: bool = false
@export var effect_tag: StringName
@export var slow_amount: float = 0.0
@export var slow_duration: float = 0.0
@export var target_strategy: TargetStrategy = TargetStrategy.MATCHING_FIRST
@export var color: Color = Color.WHITE
## Sichtbares Hilfs-Objekt: &"bubble", &"cookie", &"wind" (keine Waffen).
@export var projectile: StringName
@export_multiline var description: String = ""


func helps_need(need: int) -> bool:
	return supported_needs.has(need)

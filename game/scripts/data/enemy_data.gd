extends Resource
class_name EnemyData

## Data-driven definition for one animal species. New species can be added
## as a new .tres resource without touching enemy.gd.

enum Category { PREY, RIVAL, PREDATOR }
enum Shape { BLOB, DIAMOND, TRIANGLE, OVAL, OVIRAPTOR, HELICOPTER }

@export var species_id: String = ""
@export var display_name: String = ""
@export var category: Category = Category.PREY
@export var shape: Shape = Shape.BLOB
@export var color: Color = Color.WHITE
@export var accent_color: Color = Color.WHITE
@export var base_scale: float = 1.0
@export var move_speed: float = 80.0
@export var wander_radius: float = 120.0
@export var detection_radius: float = 160.0
@export var attack_range: float = 40.0
@export var satiety_value: float = 10.0
## Only used when category == RIVAL: the player can eat this animal once
## its own growth_level is higher than rival_level.
@export var rival_level: int = 1
## Only used when category == PREDATOR: once the player has spikes
## (growth_level >= GameManager.SPIKES_LEVEL) and has outgrown this value,
## this predator gets fended off instead of catching the player.
@export var threat_level: int = 1

## Combat: species with has_health require a sustained fight (the player
## deals GameManager.get_bite_dps() per second) before they can be eaten.
@export var has_health: bool = false
@export var max_health: float = 0.0
## Damage dealt to the player per attack tick, both while still too
## dangerous to fight (see edible_level) and, if > 0, during the fight
## itself once the player is capable of winning it.
@export var damage_per_tick: float = 0.0
## Minimum player growth_level to be able to defeat & eat this species at
## all (0 = not applicable, e.g. plain PREY/RIVAL rules apply instead).
@export var edible_level: int = 0
## Can never be defeated, fended off, or eaten - always dangerous on
## contact regardless of player level/spikes (e.g. the Oviraptor).
@export var unbeatable: bool = false

## Ranged predators (e.g. the helicopter) keep their distance and damage
## the player periodically instead of via melee contact.
@export var ranged: bool = false
@export var preferred_range: float = 0.0
@export var shoot_interval: float = 1.5

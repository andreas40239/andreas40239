extends Resource
class_name EnemyData

## Data-driven definition for one animal species. New species can be added
## as a new .tres resource without touching enemy.gd.

enum Category { PREY, RIVAL, PREDATOR }
enum Shape { BLOB, DIAMOND, TRIANGLE, OVAL }

@export var species_id: String = ""
@export var display_name: String = ""
@export var category: Category = Category.PREY
@export var shape: Shape = Shape.BLOB
@export var color: Color = Color.WHITE
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

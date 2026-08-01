extends Node2D
class_name EnemySpawner

## Spawns enemies dynamically within the current map bounds (see
## GameManager.get_map_half_extent), instead of hand-placing a fixed set
## per zone. This scales naturally as the map grows over 15 levels, and
## the per-species weight is how "mehr Ameisen" (more ants) is expressed.

const ANT_DATA := preload("res://resources/enemies/ant.tres")
const BIG_ANT_DATA := preload("res://resources/enemies/big_ant.tres")
const RIVAL_DATA := preload("res://resources/enemies/rival_lizard.tres")
const BIRD_DATA := preload("res://resources/enemies/bird.tres")
const CRAB_DATA := preload("res://resources/enemies/crab.tres")
const RED_ANT_DATA := preload("res://resources/enemies/red_ant.tres")
const BLACK_CRAB_DATA := preload("res://resources/enemies/black_crab.tres")
const OVIRAPTOR_DATA := preload("res://resources/enemies/oviraptor.tres")
const HELICOPTER_DATA := preload("res://resources/enemies/helicopter.tres")

const SPECIES_POOL := [
	{"data": ANT_DATA, "min_level": 1, "weight": 6.0},
	{"data": BIG_ANT_DATA, "min_level": 4, "weight": 2.5},
	{"data": RIVAL_DATA, "min_level": 1, "weight": 1.5},
	{"data": BIRD_DATA, "min_level": 2, "weight": 2.0},
	{"data": CRAB_DATA, "min_level": 3, "weight": 1.5},
	{"data": RED_ANT_DATA, "min_level": 11, "weight": 2.0},
	{"data": BLACK_CRAB_DATA, "min_level": 14, "weight": 1.2},
	{"data": OVIRAPTOR_DATA, "min_level": 17, "weight": 1.0},
	{"data": HELICOPTER_DATA, "min_level": 21, "weight": 0.8},
]

@export var enemy_scene: PackedScene
@export var max_active: int = 34
@export var spawn_interval: float = 1.4
@export var safe_radius: float = 260.0
@export var initial_burst: int = 14

var _timer: float = 0.0

func _ready() -> void:
	for i in initial_burst:
		_spawn_one()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		if get_child_count() < max_active:
			_spawn_one()

func _spawn_one() -> void:
	var candidates: Array = []
	var total_weight := 0.0
	for entry in SPECIES_POOL:
		if GameManager.growth_level >= entry["min_level"]:
			candidates.append(entry)
			total_weight += entry["weight"]
	if candidates.is_empty():
		return
	var roll := randf() * total_weight
	var chosen: EnemyData = candidates[0]["data"]
	var acc := 0.0
	for entry in candidates:
		acc += entry["weight"]
		if roll <= acc:
			chosen = entry["data"]
			break
	var enemy: CharacterBody2D = enemy_scene.instantiate()
	enemy.set("data", chosen)
	enemy.position = _random_position()
	add_child(enemy)

func _random_position() -> Vector2:
	var half: Vector2 = GameManager.get_map_half_extent()
	var pos := Vector2.ZERO
	for i in 12:
		pos = Vector2(
			randf_range(-half.x + 60.0, half.x - 60.0),
			randf_range(-half.y + 60.0, half.y - 60.0)
		)
		if pos.length() >= safe_radius:
			return pos
	return pos

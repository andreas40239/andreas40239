extends Node2D

## Orchestrates map growth: unlocks the next zone's barrier, reveals its
## enemies, and widens the camera limit whenever the player levels up.

const ZONE_CAMERA_RIGHT := {
	1: 900,
	2: 1700,
	3: 2500,
}

@onready var camera: Camera2D = $Player/Camera2D
@onready var barrier_1: StaticBody2D = $World/Barrier1
@onready var barrier_2: StaticBody2D = $World/Barrier2
@onready var zone_2_enemies: Node2D = $World/Zone2Enemies
@onready var zone_3_enemies: Node2D = $World/Zone3Enemies

func _ready() -> void:
	SaveManager.load_game()
	_apply_zone_state(GameManager.growth_level)
	GameManager.leveled_up.connect(_on_leveled_up)

func _on_leveled_up(new_level: int) -> void:
	_apply_zone_state(new_level)

func _apply_zone_state(level: int) -> void:
	camera.limit_right = ZONE_CAMERA_RIGHT.get(level, ZONE_CAMERA_RIGHT[3])

	if level >= 2:
		_open_barrier(barrier_1)
		zone_2_enemies.visible = true
		zone_2_enemies.process_mode = Node.PROCESS_MODE_INHERIT

	if level >= 3:
		_open_barrier(barrier_2)
		zone_3_enemies.visible = true
		zone_3_enemies.process_mode = Node.PROCESS_MODE_INHERIT

func _open_barrier(barrier: StaticBody2D) -> void:
	barrier.visible = false
	var shape: CollisionShape2D = barrier.get_node("CollisionShape2D")
	shape.set_deferred("disabled", true)

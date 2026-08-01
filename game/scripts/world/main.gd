extends Node2D

## Orchestrates map growth: on every level-up the playable rectangle
## (and camera limits) expand symmetrically in all four directions
## around the den, per GameManager.get_map_half_extent().

const WALL_THICKNESS := 20.0

@onready var camera: Camera2D = $Player/Camera2D
@onready var top_wall: StaticBody2D = $World/Boundary/TopWall
@onready var bottom_wall: StaticBody2D = $World/Boundary/BottomWall
@onready var left_wall: StaticBody2D = $World/Boundary/LeftWall
@onready var right_wall: StaticBody2D = $World/Boundary/RightWall

func _ready() -> void:
	SaveManager.load_game()
	_apply_map_size()
	GameManager.leveled_up.connect(_on_leveled_up)

func _on_leveled_up(_new_level: int) -> void:
	_apply_map_size()

func _apply_map_size() -> void:
	var half: Vector2 = GameManager.get_map_half_extent()
	camera.limit_left = int(-half.x)
	camera.limit_right = int(half.x)
	camera.limit_top = int(-half.y)
	camera.limit_bottom = int(half.y)
	_position_wall(top_wall, Vector2(0, -half.y), Vector2(half.x * 2.0 + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	_position_wall(bottom_wall, Vector2(0, half.y), Vector2(half.x * 2.0 + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	_position_wall(left_wall, Vector2(-half.x, 0), Vector2(WALL_THICKNESS, half.y * 2.0 + WALL_THICKNESS * 2.0))
	_position_wall(right_wall, Vector2(half.x, 0), Vector2(WALL_THICKNESS, half.y * 2.0 + WALL_THICKNESS * 2.0))

func _position_wall(wall: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	wall.position = pos
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision: CollisionShape2D = wall.get_node("CollisionShape2D")
	collision.shape = shape

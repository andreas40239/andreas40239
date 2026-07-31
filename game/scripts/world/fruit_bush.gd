extends Area2D

## Fruit powerup: instant satiety plus a temporary speed boost, per the
## design doc's "Fruechte in Straeuchern" powerup. Respawns after a cooldown.

@export var satiety_amount: float = 25.0
@export var boost_multiplier: float = 1.6
@export var boost_duration: float = 5.0
@export var respawn_time: float = 12.0

var available: bool = true

@onready var visual: Node2D = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not available or not body.is_in_group("player"):
		return
	body.apply_fruit_boost(satiety_amount, boost_multiplier, boost_duration)
	_consume()

func _consume() -> void:
	available = false
	visual.visible = false
	collision.disabled = true
	await get_tree().create_timer(respawn_time).timeout
	available = true
	visual.visible = true
	collision.disabled = false

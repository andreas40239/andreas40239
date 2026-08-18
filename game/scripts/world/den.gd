extends Area2D

## The lizard's burrow. It's the respawn point, a safe zone (no damage
## while inside), and recharges health over time. Leveling up no longer
## requires visiting it - see GameManager.level_up_ready / choose_upgrade,
## triggered automatically once satiety reaches its threshold.

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	body.set_den_position(global_position)
	body.set_in_den(true)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		body.set_in_den(false)

extends Area2D

## The lizard's burrow. Entering it with enough satiety triggers a
## level-up (per the design doc: satiety threshold reached AND return
## to the den). It also remembers itself as the respawn point.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	body.set_den_position(global_position)
	if GameManager.can_level_up():
		GameManager.level_up()

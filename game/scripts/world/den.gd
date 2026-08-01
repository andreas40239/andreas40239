extends Area2D

## The lizard's burrow. Entering it with enough satiety triggers a
## level-up (per the design doc: satiety threshold reached AND return
## to the den). It also remembers itself as the respawn point, and the
## player is safe from all attackers while inside.

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	body.set_den_position(global_position)
	body.set_in_den(true)
	if GameManager.can_level_up():
		GameManager.level_up()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		body.set_in_den(false)

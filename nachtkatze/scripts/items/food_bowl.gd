extends Area3D
class_name FoodBowl
## Levelziel: Futternapf auf dem beleuchteten Balkon (GDD Abschnitt 5).

signal reached()

func _ready() -> void:
	add_to_group("goal")
	collision_layer = 16   # Aufsammelbar
	collision_mask = 2     # Spieler
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or Game.is_level_finished:
		return
	player.win()
	reached.emit()
	Game.complete_level()

extends Area3D
class_name FoodBowl
## Levelziel: Futternapf auf dem beleuchteten Balkon (GDD Abschnitt 5).

signal reached()

func _ready() -> void:
	add_to_group("goal")
	collision_layer = 16   # Aufsammelbar
	collision_mask = 2     # Spieler
	monitoring = true
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null:
		mesh.mesh = AssetKit.get_mesh(AssetKit.Kind.FUTTERNAPF)
		mesh.material_override = AssetKit.get_character_material()
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or Game.is_level_finished:
		return
	player.win(global_position.x)
	reached.emit()
	Game.complete_level()

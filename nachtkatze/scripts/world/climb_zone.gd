@tool
extends Area3D
class_name ClimbZone
## Kletterbares Element (Regenrinne, Markise, Balkongitter, Strommast).
## GDD Abschnitt 8: technisch ueber eigene Area3D-Zonen, nicht ueber Geometrie.
## Die helle Markierung steht fuer den spaeteren warmen Lichtakzent.

@export var height := 3.0:
	set(value):
		height = value
		_apply()
@export var width := 0.6:
	set(value):
		width = value
		_apply()
## Auf welcher Seite die Katze oben herauskommt: 1 = rechts, -1 = links.
@export_range(-1, 1, 2) var exit_direction := 1:
	set(value):
		exit_direction = value
		_apply()
## Wie weit die Katze beim Hochziehen auf die Flaeche gesetzt wird.
@export var exit_offset := Vector3(0.7, 0.45, 0.0):
	set(value):
		exit_offset = value
		_apply()

func _ready() -> void:
	add_to_group("climbable")
	collision_layer = 4    # Kletterzone
	collision_mask = 0
	monitoring = false
	monitorable = true
	_apply()

func get_top_y() -> float:
	return global_position.y + height * 0.5

## Zielpunkt, auf den sich die Katze oben hochzieht.
func get_exit_point() -> Vector3:
	return Vector3(
		global_position.x + exit_offset.x * signf(float(exit_direction)),
		get_top_y() + exit_offset.y,
		0.0)

func _apply() -> void:
	if not is_node_ready():
		return
	var collision := get_node_or_null("Collision") as CollisionShape3D
	var mesh_instance := get_node_or_null("Mesh") as MeshInstance3D
	if collision == null or mesh_instance == null:
		return
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 1.0)
	collision.shape = shape
	# Schmaler Lichtakzent neben dem Bauteil - das Rohr selbst kommt aus dem
	# Asset-Kit (GDD Abschnitt 8: kletterbare Elemente einheitlich markiert).
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(width * 0.22, height, 0.1)
	mesh_instance.mesh = box_mesh
	mesh_instance.position = Vector3(0, 0, 0.16)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.86, 0.55)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.72, 0.32)
	material.emission_energy_multiplier = 0.45
	mesh_instance.set_surface_override_material(0, material)

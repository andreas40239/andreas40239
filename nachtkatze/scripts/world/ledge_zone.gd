@tool
extends Area3D
class_name LedgeZone
## Greifbare Kante. Die Katze haelt sich automatisch fest, sobald sie im Fallen
## hineingeraet (GDD Abschnitt 2: "Automatisches Festhalten an greifbaren Kanten").
##
## Die Zone wird direkt an die Oberkante einer Plattform gesetzt; "Richtung"
## bestimmt, auf welcher Seite die Katze haengt.

@export_range(-1, 1, 2) var facing := 1:
	set(value):
		facing = value
		_apply()
@export var size := Vector3(0.7, 0.7, 1.0):
	set(value):
		size = value
		_apply()
## Wie weit unterhalb der Kante die Katze haengt.
@export var hang_drop := 0.45
## Zielpunkt beim Hochziehen, relativ zur Kante.
@export var exit_offset := Vector3(0.6, 0.35, 0.0)

func _ready() -> void:
	add_to_group("ledge")
	collision_layer = 8    # Kantenzone
	collision_mask = 0
	monitoring = false
	monitorable = true
	_apply()

## Haengeposition: aussen vor der Kante, leicht darunter.
func get_hang_point() -> Vector3:
	return Vector3(
		global_position.x + 0.35 * signf(float(facing)),
		global_position.y - hang_drop,
		0.0)

func get_exit_point() -> Vector3:
	return Vector3(
		global_position.x - exit_offset.x * signf(float(facing)),
		global_position.y + exit_offset.y,
		0.0)

func _apply() -> void:
	if not is_node_ready():
		return
	var collision := get_node_or_null("Collision") as CollisionShape3D
	var mesh_instance := get_node_or_null("Mesh") as MeshInstance3D
	if collision == null or mesh_instance == null:
		return
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(size.x, 0.12, 0.3)
	mesh_instance.mesh = box_mesh
	mesh_instance.position = Vector3(0.0, size.y * 0.5, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.92, 0.70)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.85, 0.5)
	material.emission_energy_multiplier = 0.5
	mesh_instance.set_surface_override_material(0, material)

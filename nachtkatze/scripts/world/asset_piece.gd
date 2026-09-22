@tool
extends StaticBody3D
class_name AssetPiece
## Ein Bauteil aus dem Asset-Kit (GDD Abschnitt 8).
##
## Mesh und Kollision entstehen prozedural aus AssetKit; im Level setzt man
## nur Art und Position. Gleiche Bauteile teilen sich Mesh und Material.

@export var kind: AssetKit.Kind = AssetKit.Kind.GESCHOSS_SEGMENT:
	set(value):
		kind = value
		_apply()

## Aus: reine Zier, die Katze laeuft hindurch.
@export var solid: bool = true:
	set(value):
		solid = value
		_apply()

## Zufaellige Drehung um die Hochachse - gegen den Stempeleffekt bei Pflanzen.
@export_range(0.0, 360.0) var yaw_degrees: float = 0.0:
	set(value):
		yaw_degrees = value
		_apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	if not is_node_ready():
		return
	var mesh_instance := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_instance == null:
		return
	mesh_instance.mesh = AssetKit.get_mesh(kind)
	mesh_instance.material_override = AssetKit.get_material()
	mesh_instance.rotation.y = deg_to_rad(yaw_degrees)
	_rebuild_collision()

func _rebuild_collision() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.queue_free()
	var boxes := AssetKit.get_collision_boxes(kind) if solid else ([] as Array[AABB])
	collision_layer = 1 if boxes.size() > 0 else 0
	collision_mask = 0
	for box in boxes:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = box.size
		shape.shape = box_shape
		shape.position = box.position + box.size * 0.5
		add_child(shape)
		# Kollision dreht sich mit dem Bauteil.
		shape.position = shape.position.rotated(Vector3.UP, deg_to_rad(yaw_degrees))
		shape.rotation.y = deg_to_rad(yaw_degrees)

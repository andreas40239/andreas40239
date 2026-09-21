@tool
extends Area3D
class_name Hazard
## Platzhalter-Gefahr fuer Meilenstein 2.
##
## Sie dient nur dazu, Treffer, Unverwundbarkeit und Rueckstoss testbar zu
## machen. Die echten Gegner mit Zustandsautomaten und Warnsignalen
## (Hunde, Revierkatzen, Autos) folgen in Meilenstein 3.

@export var damage := 1
## Strecke, die die Gefahr hin und her faehrt (0 = statisch).
@export var patrol_distance := 0.0
@export var patrol_speed := 1.5
@export var size := Vector3(0.9, 0.9, 0.9):
	set(value):
		size = value
		_apply()

var _start_position := Vector3.ZERO
var _time := 0.0

func _ready() -> void:
	add_to_group("hazard")
	collision_layer = 32   # Gefahr
	collision_mask = 2     # Spieler
	monitoring = true
	_start_position = position
	_apply()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if patrol_distance > 0.0:
		_time += delta
		var phase := sin(_time * patrol_speed / maxf(patrol_distance, 0.001))
		position.x = _start_position.x + phase * patrol_distance
	# Treffer auch bei Dauerkontakt, sobald die Unverwundbarkeit ablaeuft.
	for body in get_overlapping_bodies():
		var player := body as Player
		if player != null:
			player.take_damage(damage, global_position)

func _apply() -> void:
	if not is_node_ready():
		return
	var collision := get_node_or_null("Collision") as CollisionShape3D
	var mesh_instance := get_node_or_null("Mesh") as MeshInstance3D
	if collision == null or mesh_instance == null:
		return
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.25, 0.25)
	material.roughness = 0.9
	mesh_instance.set_surface_override_material(0, material)
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape

class_name Checkpoint
extends Area3D
## A cosy leaf circle. Walking through it sets the hedgehog's respawn point.

## Show a "Checkpoint!" message the first time. Off for the starting circle.
@export var announce := true

var _activated := false
var _leaves: StandardMaterial3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	var shape := CylinderShape3D.new()
	shape.radius = 0.9
	shape.height = 1.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.5
	add_child(collision)
	body_entered.connect(_on_body_entered)
	for i in 10:
		var angle := TAU * i / 10.0
		MeshUtil.add(self, MeshUtil.box(Vector3(0.22, 0.01, 0.12)), Color.WHITE,
				Vector3(cos(angle) * 0.75, 0.01, sin(angle) * 0.75), Vector3.ONE, Vector3(0, -angle, 0))
	_leaves = MeshUtil.merge(self).mesh.surface_get_material(0)
	_leaves.albedo_color = Color(0.55, 0.45, 0.3)


func _on_body_entered(body: Node3D) -> void:
	if not body is Hedgehog:
		return
	body.respawn_point = global_position + Vector3.UP * 0.1
	if not _activated:
		_activated = true
		_leaves.albedo_color = Color(0.95, 0.6, 0.15)
		if announce:
			Game.show_toast("Checkpoint! A cosy leaf circle.")
			Sound.play("chime_checkpoint", -8.0)

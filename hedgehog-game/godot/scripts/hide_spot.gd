class_name HideSpot
extends Area3D
## A bush (or any covered place) where the hedgehog is hidden from animals.
## The bush turns see-through while the hedgehog is inside, so kids can
## still see their hedgehog.

@export var size := 1.0
@export var show_bush := true

var _materials: Array[StandardMaterial3D] = []
var _bush: Node3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	var shape := SphereShape3D.new()
	shape.radius = 0.75 * size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if show_bush:
		_build_bush()


func _on_body_entered(body: Node3D) -> void:
	if body is Hedgehog:
		body.enter_hide()
		Sound.play_at("bush", global_position, -2.0, 0.15, 20.0)
		_set_see_through(true)
		_rustle()


func _on_body_exited(body: Node3D) -> void:
	if body is Hedgehog:
		body.exit_hide()
		Sound.play_at("bush", global_position, -8.0, 0.15, 20.0)
		_set_see_through(false)
		_rustle()


func _set_see_through(on: bool) -> void:
	for mat in _materials:
		mat.albedo_color.a = 0.45 if on else 1.0


func _rustle() -> void:
	if _bush == null:
		return
	var tween := create_tween()
	tween.tween_property(_bush, "scale", Vector3(1.08, 0.95, 1.08), 0.08)
	tween.tween_property(_bush, "scale", Vector3.ONE, 0.2)


func _build_bush() -> void:
	_bush = Node3D.new()
	add_child(_bush)
	var greens := [Color(0.2, 0.45, 0.2), Color(0.25, 0.52, 0.22), Color(0.18, 0.4, 0.18)]
	var blobs := [
		Vector3(0, 0.45, 0), Vector3(0.4, 0.35, 0.1), Vector3(-0.35, 0.35, 0.15),
		Vector3(0.1, 0.35, -0.4), Vector3(-0.1, 0.65, -0.1),
	]
	for i in blobs.size():
		var blob := MeshUtil.add(_bush, MeshUtil.sphere(0.5 * size), greens[i % greens.size()], blobs[i] * size)
		var mat: StandardMaterial3D = blob.mesh.material
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		_materials.append(mat)

class_name HideSpot
extends Area3D
## A bush (or any covered place) where the hedgehog is hidden from animals.
## The bush turns see-through while the hedgehog is inside, so kids can
## still see their hedgehog. A compost heap also hides the hedgehog's smell
## from dogs.

@export var size := 1.0
@export var show_bush := true
@export_enum("bush", "compost") var look: String = "bush"
## Dogs can't smell a hedgehog hiding here (compost heaps, hedgehog houses).
@export var masks_scent := false

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
		body.enter_hide(masks_scent)
		if masks_scent:
			Game.unlock_fact("compost")
		Sound.play_at("bush", global_position, -2.0, 0.15, 20.0)
		_set_see_through(true)
		_rustle()


func _on_body_exited(body: Node3D) -> void:
	if body is Hedgehog:
		body.exit_hide(masks_scent)
		Sound.play_at("bush", global_position, -8.0, 0.15, 20.0)
		_set_see_through(false)
		_rustle()


func _set_see_through(on: bool) -> void:
	for mat in _materials:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS if on else BaseMaterial3D.TRANSPARENCY_DISABLED
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
	if look == "compost":
		_build_compost()
		return
	var greens := [Color(0.2, 0.45, 0.2), Color(0.25, 0.52, 0.22), Color(0.18, 0.4, 0.18)]
	var blobs := [
		Vector3(0, 0.45, 0), Vector3(0.4, 0.35, 0.1), Vector3(-0.35, 0.35, 0.15),
		Vector3(0.1, 0.35, -0.4), Vector3(-0.1, 0.65, -0.1),
	]
	for i in blobs.size():
		MeshUtil.add(_bush, MeshUtil.sphere(0.5 * size), greens[i % greens.size()], blobs[i] * size)
	_materials.append(MeshUtil.merge(_bush).mesh.surface_get_material(0))


func _build_compost() -> void:
	var browns := [Color(0.36, 0.25, 0.15), Color(0.42, 0.3, 0.18), Color(0.3, 0.22, 0.12)]
	MeshUtil.add(_bush, MeshUtil.sphere(0.8 * size), browns[0], Vector3(0, 0.15, 0), Vector3(1.1, 0.6, 1.0))
	MeshUtil.add(_bush, MeshUtil.sphere(0.5 * size), browns[1], Vector3(0.35, 0.35, 0.2) * size, Vector3(1.0, 0.7, 1.0))
	MeshUtil.add(_bush, MeshUtil.sphere(0.45 * size), browns[2], Vector3(-0.3, 0.4, -0.15) * size, Vector3(1.0, 0.8, 1.0))
	# Peelings and grass cuttings on top.
	var bits := [Color(0.9, 0.55, 0.15), Color(0.45, 0.65, 0.25), Color(0.85, 0.8, 0.4)]
	for i in 9:
		var angle := TAU * i / 9.0
		MeshUtil.add(_bush, MeshUtil.box(Vector3(0.14, 0.03, 0.08)), bits[i % bits.size()],
				Vector3(cos(angle) * 0.4, 0.55 + (i % 3) * 0.06, sin(angle) * 0.4) * size, Vector3.ONE, Vector3(0.3, angle, 0))
	_materials.append(MeshUtil.merge(_bush).mesh.surface_get_material(0))

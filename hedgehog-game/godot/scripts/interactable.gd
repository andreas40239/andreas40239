class_name Interactable
extends Area3D
## Base class for things the hedgehog can use with the Interact button.
## Subclasses override get_prompt() and interact().

@export var radius := 0.7


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Text shown after "[E]". An empty string means "nothing to do here right now".
func get_prompt(_player: Hedgehog) -> String:
	return ""


func interact(_player: Hedgehog) -> void:
	pass


func _on_body_entered(body: Node3D) -> void:
	if body is Hedgehog:
		body.add_interactable(self)


func _on_body_exited(body: Node3D) -> void:
	if body is Hedgehog:
		body.remove_interactable(self)

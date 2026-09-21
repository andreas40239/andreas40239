@tool
extends Area3D
class_name TutorialHint
## Ausloeser fuer einen Tutorial-Hinweis (GDD Abschnitt 7).
## Betritt die Katze den Bereich, zeigt das HUD das passende Symbol.

@export var hint: HintOverlay.Hint = HintOverlay.Hint.LAUFEN
@export var size := Vector3(3.0, 3.0, 2.0):
	set(value):
		size = value
		_apply()

func _ready() -> void:
	add_to_group("tutorial_hint")
	collision_layer = 16   # wie Aufsammelbares: reagiert auf den Spielerkoerper
	collision_mask = 2
	monitoring = true
	_apply()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.show_hint(hint)

func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.hide_hint(hint)

func _apply() -> void:
	if not is_node_ready():
		return
	var collision := get_node_or_null("Collision") as CollisionShape3D
	if collision == null:
		return
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape

@tool
extends Area3D
class_name Collectible
## Futter (GDD Abschnitt 3): Fischgraete gibt +1 LP, ganzer Fisch fuellt auf.
## Lebenspunkte koennen das Maximum nicht ueberschreiten.

enum Kind { FISCHGRAETE, GANZER_FISCH }

signal collected(kind: Kind)

@export var kind: Kind = Kind.FISCHGRAETE:
	set(value):
		kind = value
		_apply()
## Schwebe- und Drehbewegung, damit Futter im Graubox-Level auffaellt.
@export var bob_height := 0.12
@export var spin_speed := 1.6

var _time := 0.0
var _base_position := Vector3.ZERO

func _ready() -> void:
	add_to_group("collectible")
	collision_layer = 16   # Aufsammelbar
	collision_mask = 2     # Spieler
	monitoring = true
	_base_position = position
	_apply()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	var mesh_instance := get_node_or_null("Mesh") as Node3D
	if mesh_instance == null:
		return
	mesh_instance.rotate_y(spin_speed * delta)
	mesh_instance.position.y = sin(_time * 2.0) * bob_height

func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	if kind == Kind.GANZER_FISCH:
		player.heal_full()
	else:
		player.heal(1)
	player.play_eat()
	Sfx.play(&"knuspern", 2.0 if kind == Kind.GANZER_FISCH else 0.0)
	collected.emit(kind)
	set_deferred("monitoring", false)
	queue_free()

func _apply() -> void:
	if not is_node_ready():
		return
	var collision := get_node_or_null("Collision") as CollisionShape3D
	var mesh_instance := get_node_or_null("Mesh") as MeshInstance3D
	if collision == null or mesh_instance == null:
		return
	var is_big := kind == Kind.GANZER_FISCH
	mesh_instance.mesh = AssetKit.get_mesh(
		AssetKit.Kind.GANZER_FISCH if is_big else AssetKit.Kind.FISCHGRAETE)
	mesh_instance.material_override = AssetKit.get_character_material()
	# Etwas vergroessert, damit Futter auch aus der Ferne auffaellt.
	mesh_instance.scale = Vector3.ONE * (1.25 if is_big else 1.35)
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	collision.shape = shape

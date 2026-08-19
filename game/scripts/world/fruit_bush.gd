extends Area2D

## Fruit powerup: instant satiety plus a temporary speed boost, per the
## design doc's "Fruechte in Straeuchern" powerup. Respawns after a cooldown.

@export var satiety_amount: float = 25.0
@export var boost_multiplier: float = 1.6
@export var boost_duration: float = 5.0
@export var respawn_time: float = 12.0

var available: bool = true

@onready var visual: Node2D = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_visual()

## Rounded leaf clusters + a few scattered berries, in place of the old
## flat green/red rectangles.
func _build_visual() -> void:
	for child in visual.get_children():
		child.queue_free()
	var leaf := Color(0.18, 0.45, 0.2)
	var leaf_light := leaf.lightened(0.2)
	for spot in [Vector2(-14, -4), Vector2(14, -4), Vector2(0, -14), Vector2(0, 6), Vector2(-8, 10), Vector2(8, 10)]:
		_leaf_blob(spot, 15.0, leaf)
	_leaf_blob(Vector2(0, -2), 12.0, leaf_light)
	for berry in [Vector2(-9, -6), Vector2(8, -2), Vector2(-2, 8), Vector2(6, 10), Vector2(-10, 3)]:
		var fruit := Polygon2D.new()
		fruit.polygon = _oval_points(4.2, 4.2)
		fruit.color = Color(0.85, 0.15, 0.2)
		fruit.position = berry
		fruit.z_index = 1
		visual.add_child(fruit)
		var glint := Polygon2D.new()
		glint.polygon = _oval_points(1.2, 1.2)
		glint.color = Color(1, 1, 1, 0.7)
		glint.position = berry + Vector2(-1.2, -1.2)
		glint.z_index = 2
		visual.add_child(glint)

func _leaf_blob(pos: Vector2, radius: float, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = _oval_points(radius, radius * 0.85)
	poly.color = color
	poly.position = pos
	visual.add_child(poly)

func _oval_points(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _on_body_entered(body: Node) -> void:
	if not available or not body.is_in_group("player"):
		return
	body.apply_fruit_boost(satiety_amount, boost_multiplier, boost_duration)
	_consume()

func _consume() -> void:
	available = false
	visual.visible = false
	collision.disabled = true
	await get_tree().create_timer(respawn_time).timeout
	available = true
	visual.visible = true
	collision.disabled = false

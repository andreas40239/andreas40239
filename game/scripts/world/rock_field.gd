extends Node2D

## A handful of rock clusters scattered across the map that block
## movement, giving the player (and every animal) something besides the
## river to route around. Fixed, deterministic positions clear of the den
## and the river's path.

const ROCK_POSITIONS := [
	Vector2(-680.0, -420.0), Vector2(950.0, 260.0), Vector2(-1200.0, 700.0),
	Vector2(300.0, -950.0), Vector2(-1500.0, -1300.0), Vector2(1450.0, -700.0),
	Vector2(-300.0, 1450.0), Vector2(1750.0, 1150.0), Vector2(-1950.0, 200.0),
	Vector2(150.0, 1950.0), Vector2(1150.0, -1750.0), Vector2(-850.0, -1850.0),
]

const CLUSTER_RADIUS := 46.0

func _ready() -> void:
	for pos in ROCK_POSITIONS:
		_build_cluster(pos)

func get_positions() -> Array:
	return ROCK_POSITIONS

func _build_cluster(pos: Vector2) -> void:
	var cluster := Node2D.new()
	cluster.position = pos
	cluster.z_index = -1
	add_child(cluster)

	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CircleShape2D.new()
	shape.radius = CLUSTER_RADIUS
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	cluster.add_child(body)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(pos.x) * 13.0 + abs(pos.y) * 7.0)
	var rock_color := Color(0.5, 0.48, 0.46)
	for i in rng.randi_range(3, 5):
		var offset := Vector2(rng.randf_range(-28.0, 28.0), rng.randf_range(-28.0, 28.0))
		var r := rng.randf_range(14.0, 26.0)
		var sides := 7
		var pts := PackedVector2Array()
		for s in sides:
			var a := TAU * s / sides
			var jitter := rng.randf_range(0.75, 1.15)
			pts.append(Vector2(cos(a), sin(a)) * r * jitter)
		var poly := Polygon2D.new()
		poly.polygon = pts
		poly.color = rock_color.darkened(rng.randf_range(0.0, 0.2))
		poly.position = offset
		cluster.add_child(poly)
		var highlight := Polygon2D.new()
		highlight.polygon = pts
		highlight.color = Color(1.0, 1.0, 1.0, 0.12)
		highlight.position = offset + Vector2(-3.0, -3.0)
		highlight.scale = Vector2.ONE * 0.6
		cluster.add_child(highlight)

extends Area2D

## The lizard's burrow. It's the respawn point, a safe zone (no damage
## while inside), and recharges health over time. Leveling up no longer
## requires visiting it - see GameManager.level_up_ready / choose_upgrade,
## triggered automatically once satiety reaches its threshold.

@onready var visual: Node2D = $Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visual()

## Earthen mound with a dark entrance hole and a scatter of pebbles, in
## place of the old flat brown rectangle - built procedurally like the
## critters, in the same vector-primitive style.
func _build_visual() -> void:
	var soil := Color(0.36, 0.24, 0.14)
	_oval(Vector2(0, 8), 54, 28, soil.darkened(0.35), -2)  # ground shadow
	_oval(Vector2.ZERO, 52, 33, soil, -1)  # mound base
	_oval(Vector2(0, -7), 50, 24, soil.lightened(0.12), -1)  # sunlit top
	for spot in [Vector2(-30, -12), Vector2(24, -16), Vector2(-14, 12), Vector2(32, 8), Vector2(2, -22)]:
		_oval(spot, 5.0, 3.5, soil.darkened(0.2), 0)  # tufts of dirt/rock
	_oval(Vector2(0, 5), 21, 13, Color(0.07, 0.05, 0.04), 1)  # entrance hole
	_oval(Vector2(0, -1), 17, 8, Color(0.02, 0.02, 0.02, 0.6), 1)  # hole depth shading

func _oval(pos: Vector2, rx: float, ry: float, color: Color, z: int) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = color
	poly.position = pos
	poly.z_index = z
	visual.add_child(poly)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	body.set_den_position(global_position)
	body.set_in_den(true)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		body.set_in_den(false)

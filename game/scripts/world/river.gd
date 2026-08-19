extends Node2D

## A winding river crossing the map that the player (and every animal)
## must walk around - a chain of rotated rectangle StaticBody2D segments
## on the same collision layer as the boundary walls, with matching
## water/shore visuals. Laid out once across the max possible map extent
## (see GroundDetail) so it doesn't shift as the map grows. Its waypoints
## are exposed via get_points() so the minimap can draw the same river.

const RIVER_X := 620.0
const WIDTH := 110.0
const SHORE_MARGIN := 20.0
const SEGMENT_STEP := 300.0
const WAVE_AMPLITUDE := 90.0
const WAVE_PERIOD := 480.0

var _points: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	add_to_group("river")
	var half: Vector2 = GameManager.get_max_map_half_extent()
	_points = _build_points(half.y)
	_build_visual_and_collision()

func get_points() -> PackedVector2Array:
	return _points

func _build_points(max_y: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var y := -max_y - SEGMENT_STEP
	while y <= max_y + SEGMENT_STEP:
		var x: float = RIVER_X + sin(y / WAVE_PERIOD) * WAVE_AMPLITUDE
		pts.append(Vector2(x, y))
		y += SEGMENT_STEP
	return pts

func _build_visual_and_collision() -> void:
	var water := Color(0.25, 0.5, 0.75, 0.92)
	var shore := Color(0.76, 0.68, 0.48, 0.9)
	for i in _points.size() - 1:
		var a: Vector2 = _points[i]
		var b: Vector2 = _points[i + 1]
		var mid := (a + b) * 0.5
		var seg_len := a.distance_to(b) + 4.0
		var angle := (b - a).angle()

		_add_band(mid, angle, seg_len, WIDTH + SHORE_MARGIN * 2.0, shore, -6)
		_add_band(mid, angle, seg_len, WIDTH, water, -5)

		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = mid
		body.rotation = angle
		var shape := RectangleShape2D.new()
		shape.size = Vector2(seg_len, WIDTH)
		var col := CollisionShape2D.new()
		col.shape = shape
		body.add_child(col)
		add_child(body)

func _add_band(mid: Vector2, angle: float, length: float, width: float, color: Color, z: int) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-length * 0.5, -width * 0.5), Vector2(length * 0.5, -width * 0.5),
		Vector2(length * 0.5, width * 0.5), Vector2(-length * 0.5, width * 0.5),
	])
	poly.color = color
	poly.position = mid
	poly.rotation = angle
	poly.z_index = z
	add_child(poly)

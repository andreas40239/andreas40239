extends Control

## Small always-on-screen overview in a corner: the current map bounds,
## the den, the river, and the player's position/heading. The map can grow
## far larger than one screen, so on-screen content alone isn't always
## enough to tell which way is home.

const MARGIN := 6.0

var _player: Node2D = null
var _river: Node2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player = get_tree().get_first_node_in_group("player")
	_river = get_tree().get_first_node_in_group("river")

func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _river == null:
		_river = get_tree().get_first_node_in_group("river")
	queue_redraw()

func _draw() -> void:
	var half: Vector2 = GameManager.get_map_half_extent()
	if half.x <= 0.0 or half.y <= 0.0:
		return
	var s: Vector2 = size
	var scale_factor: float = min((s.x - MARGIN * 2.0) / (half.x * 2.0), (s.y - MARGIN * 2.0) / (half.y * 2.0))
	var center := s * 0.5

	draw_rect(Rect2(Vector2.ZERO, s), Color(0.08, 0.09, 0.07, 0.78), true)

	var top_left := center - half * scale_factor
	draw_rect(Rect2(top_left, half * 2.0 * scale_factor), Color(0.6, 0.52, 0.34, 0.9), false, 1.5)

	if is_instance_valid(_river):
		var pts: PackedVector2Array = _river.get_points()
		if pts.size() > 1:
			var mapped := PackedVector2Array()
			for p in pts:
				mapped.append(center + p * scale_factor)
			draw_polyline(mapped, Color(0.3, 0.6, 0.85, 0.95), 2.0)

	draw_circle(center, 3.5, Color(0.45, 0.3, 0.15))  # den

	if is_instance_valid(_player):
		var p_pos: Vector2 = center + _player.global_position * scale_factor
		var dir: Vector2 = _player.get("last_move_direction")
		if dir == null or dir.length() < 0.01:
			dir = Vector2.DOWN
		draw_line(p_pos, p_pos + dir.normalized() * 8.0, Color(0.9, 0.95, 0.6), 2.0)
		draw_circle(p_pos, 3.0, Color(0.35, 0.85, 0.35))

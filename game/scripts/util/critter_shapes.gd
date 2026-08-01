extends RefCounted
class_name CritterShapes

## Builds small multi-part vector critters (a few Polygon2D/Line2D pieces)
## into a given Node2D container, instead of a single flat primitive shape.
## Shared by the player lizard and the rival-lizard enemy.

static func clear(container: Node2D) -> void:
	for child in container.get_children():
		child.queue_free()

static func _poly(parent: Node2D, points: PackedVector2Array, color: Color, offset: Vector2 = Vector2.ZERO, z: int = 0) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = offset
	p.z_index = z
	parent.add_child(p)
	return p

static func _line(parent: Node2D, points: PackedVector2Array, color: Color, width: float) -> Line2D:
	var l := Line2D.new()
	l.points = points
	l.default_color = color
	l.width = width
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(l)
	return l

static func _ellipse(radius: float, squash: float = 1.0, sides: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a := TAU * i / sides
		pts.append(Vector2(cos(a) * radius, sin(a) * radius * squash))
	return pts

static func build_lizard(parent: Node2D, body_color: Color) -> void:
	clear(parent)
	var dark := body_color.darkened(0.15)
	# tail
	_poly(parent, PackedVector2Array([Vector2(-6, 8), Vector2(6, 8), Vector2(0, 27)]), body_color, Vector2.ZERO, -1)
	# legs
	for side in [-1.0, 1.0]:
		_poly(parent, PackedVector2Array([Vector2(0, -3), Vector2(side * 13, -6), Vector2(side * 9, 3)]), dark, Vector2(side * 5, -3), -1)
		_poly(parent, PackedVector2Array([Vector2(0, -3), Vector2(side * 13, 0), Vector2(side * 9, 6)]), dark, Vector2(side * 5, 7), -1)
	# body
	_poly(parent, _ellipse(13, 0.78), body_color)
	# head
	var head_pos := Vector2(0, -17)
	_poly(parent, _ellipse(8, 0.9), body_color, head_pos, 1)
	# eyes
	for side in [-1.0, 1.0]:
		_poly(parent, _ellipse(2.2), Color.WHITE, head_pos + Vector2(side * 3.5, -1.5), 2)
		_poly(parent, _ellipse(1.0), Color(0.08, 0.08, 0.08), head_pos + Vector2(side * 3.5, -1.5), 3)

static func build_ant(parent: Node2D, body_color: Color) -> void:
	clear(parent)
	var leg_color := body_color.darkened(0.2)
	for i in 3:
		var ly := -6.0 + i * 6.0
		for side in [-1.0, 1.0]:
			_line(parent, PackedVector2Array([Vector2(side * 3, ly), Vector2(side * 16, ly - 4.0 + i * 3.0)]), leg_color, 1.6)
	for side in [-1.0, 1.0]:
		_line(parent, PackedVector2Array([Vector2(side * 1.5, -16), Vector2(side * 7, -24)]), leg_color, 1.4)
	_poly(parent, _ellipse(6.5), body_color, Vector2(0, 10))
	_poly(parent, _ellipse(5.5), body_color, Vector2(0, 0))
	_poly(parent, _ellipse(4.5), body_color, Vector2(0, -11))

static func build_bird(parent: Node2D, body_color: Color) -> void:
	clear(parent)
	for side in [-1.0, 1.0]:
		_poly(parent, PackedVector2Array([Vector2(0, -2), Vector2(side * 30, -14), Vector2(side * 34, -2), Vector2(side * 10, 6)]), body_color.darkened(0.1), Vector2.ZERO, -1)
	_poly(parent, PackedVector2Array([Vector2(-5, 10), Vector2(5, 10), Vector2(0, 20)]), body_color, Vector2.ZERO, -1)
	_poly(parent, _ellipse(11, 0.62), body_color)
	_poly(parent, PackedVector2Array([Vector2(-3, -14), Vector2(3, -14), Vector2(0, -21)]), Color(0.95, 0.55, 0.15), Vector2.ZERO, 1)
	_poly(parent, _ellipse(1.3), Color(0.1, 0.1, 0.1), Vector2(3, -12), 2)

static func build_crab(parent: Node2D, body_color: Color) -> void:
	clear(parent)
	var leg_color := body_color.darkened(0.25)
	for i in 3:
		var ly := -4.0 + i * 5.0
		for side in [-1.0, 1.0]:
			_line(parent, PackedVector2Array([Vector2(side * 8, ly), Vector2(side * 20, ly + 6.0)]), leg_color, 1.8)
	_poly(parent, _ellipse(13, 0.72), body_color)
	for side in [-1.0, 1.0]:
		_line(parent, PackedVector2Array([Vector2(side * 9, -9), Vector2(side * 20, -16)]), leg_color, 2.2)
		_poly(parent, _ellipse(5.5, 0.7), body_color.lightened(0.15), Vector2(side * 22, -17))
		_line(parent, PackedVector2Array([Vector2(side * 3, -8), Vector2(side * 4, -16)]), leg_color, 1.4)
		_poly(parent, _ellipse(1.6), Color(0.05, 0.05, 0.05), Vector2(side * 4, -16))

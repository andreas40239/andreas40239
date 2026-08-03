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

static func _add_spikes(parent: Node2D, color: Color, y_start: float, y_end: float, count: int) -> void:
	for i in count:
		var t := float(i) / float(max(count - 1, 1))
		var y: float = lerp(y_start, y_end, t)
		_poly(parent, PackedVector2Array([Vector2(-3.5, 3), Vector2(3.5, 3), Vector2(0, -7)]), color, Vector2(0, y), 2)

static func build_lizard(parent: Node2D, body_color: Color, has_spikes: bool = false) -> void:
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
	if has_spikes:
		_add_spikes(parent, dark, -14.0, 14.0, 5)

static func build_trex(parent: Node2D, body_color: Color) -> void:
	clear(parent)
	var dark := body_color.darkened(0.15)
	# tail (thicker, longer than the small lizard's)
	_poly(parent, PackedVector2Array([Vector2(-8, 12), Vector2(8, 12), Vector2(0, 38)]), body_color, Vector2.ZERO, -1)
	# legs
	for side in [-1.0, 1.0]:
		_poly(parent, PackedVector2Array([Vector2(0, -4), Vector2(side * 16, -8), Vector2(side * 12, 6)]), dark, Vector2(side * 6, 4), -1)
		_poly(parent, PackedVector2Array([Vector2(0, -4), Vector2(side * 16, 2), Vector2(side * 12, 10)]), dark, Vector2(side * 6, 14), -1)
	# tiny arms
	for side in [-1.0, 1.0]:
		_line(parent, PackedVector2Array([Vector2(side * 8, -14), Vector2(side * 14, -10)]), dark, 2.2)
	# body
	_poly(parent, _ellipse(16, 0.75), body_color)
	# head with snout
	var head_pos := Vector2(0, -24)
	_poly(parent, _ellipse(11, 0.85), body_color, head_pos, 1)
	_poly(parent, PackedVector2Array([Vector2(-5, -6), Vector2(5, -6), Vector2(0, -16)]), body_color, head_pos, 1)
	# eyes
	for side in [-1.0, 1.0]:
		_poly(parent, _ellipse(2.4), Color.WHITE, head_pos + Vector2(side * 5, -2), 2)
		_poly(parent, _ellipse(1.1), Color(0.05, 0.05, 0.05), head_pos + Vector2(side * 5, -2), 3)
	# dorsal spikes
	_add_spikes(parent, dark, -20.0, 20.0, 6)

static func build_godzilla(parent: Node2D, body_color: Color) -> void:
	clear(parent)
	var dark := body_color.darkened(0.18)
	# thick tail
	_poly(parent, PackedVector2Array([Vector2(-10, 14), Vector2(10, 14), Vector2(0, 46)]), body_color, Vector2.ZERO, -1)
	# bulky legs
	for side in [-1.0, 1.0]:
		_poly(parent, PackedVector2Array([Vector2(0, -5), Vector2(side * 19, -9), Vector2(side * 14, 7)]), dark, Vector2(side * 7, 5), -1)
		_poly(parent, PackedVector2Array([Vector2(0, -5), Vector2(side * 19, 3), Vector2(side * 14, 12)]), dark, Vector2(side * 7, 16), -1)
	# small arms
	for side in [-1.0, 1.0]:
		_line(parent, PackedVector2Array([Vector2(side * 9, -16), Vector2(side * 16, -11)]), dark, 2.6)
	# body
	_poly(parent, _ellipse(19, 0.75), body_color)
	# head with snout (bigger than the T-Rex's)
	var head_pos := Vector2(0, -31)
	_poly(parent, _ellipse(16, 0.88), body_color, head_pos, 1)
	_poly(parent, PackedVector2Array([Vector2(-8, -7), Vector2(8, -7), Vector2(0, -23)]), body_color, head_pos, 1)
	# eyes
	for side in [-1.0, 1.0]:
		_poly(parent, _ellipse(3.2), Color.WHITE, head_pos + Vector2(side * 7, -2), 2)
		_poly(parent, _ellipse(1.5), Color(0.05, 0.05, 0.05), head_pos + Vector2(side * 7, -2), 3)
	# dramatic dorsal plates - denser and covering more of the back/head
	_add_spikes(parent, dark, -34.0, 34.0, 12)

static func build_oviraptor(parent: Node2D, body_color: Color, head_color: Color) -> void:
	clear(parent)
	var dark := body_color.darkened(0.15)
	# tail
	_poly(parent, PackedVector2Array([Vector2(-5, 10), Vector2(5, 10), Vector2(0, 26)]), body_color, Vector2.ZERO, -1)
	# legs
	for side in [-1.0, 1.0]:
		_poly(parent, PackedVector2Array([Vector2(0, -3), Vector2(side * 12, -5), Vector2(side * 9, 4)]), dark, Vector2(side * 5, -2), -1)
		_poly(parent, PackedVector2Array([Vector2(0, -3), Vector2(side * 12, 1), Vector2(side * 9, 7)]), dark, Vector2(side * 5, 7), -1)
	# small arms
	for side in [-1.0, 1.0]:
		_line(parent, PackedVector2Array([Vector2(side * 6, -12), Vector2(side * 11, -8)]), dark, 1.8)
	# body
	_poly(parent, _ellipse(11, 0.7), body_color)
	# head (distinct color) with a small crest
	var head_pos := Vector2(0, -19)
	_poly(parent, _ellipse(7, 0.85), head_color, head_pos, 1)
	_poly(parent, PackedVector2Array([Vector2(-3, -6), Vector2(3, -6), Vector2(0, -13)]), head_color.darkened(0.2), head_pos, 1)
	# eyes
	for side in [-1.0, 1.0]:
		_poly(parent, _ellipse(1.6), Color(0.05, 0.05, 0.05), head_pos + Vector2(side * 3, -1), 2)

static func build_helicopter(parent: Node2D, body_color: Color) -> void:
	clear(parent)
	var dark := body_color.darkened(0.2)
	_poly(parent, PackedVector2Array([Vector2(-3, 18), Vector2(3, 18), Vector2(3, 22), Vector2(-3, 22)]), dark, Vector2.ZERO, -1)  # tail boom
	_line(parent, PackedVector2Array([Vector2(-7, 20), Vector2(7, 20)]), Color(0.15, 0.15, 0.15), 1.4)  # tail rotor
	_poly(parent, _ellipse(13, 0.6), body_color)  # body
	_poly(parent, _ellipse(6, 0.8), Color(0.65, 0.85, 0.95, 0.85), Vector2(0, -3), 1)  # cockpit
	_line(parent, PackedVector2Array([Vector2(-26, 0), Vector2(26, 0)]), Color(0.1, 0.1, 0.1), 2.2)  # main rotor
	_line(parent, PackedVector2Array([Vector2(0, -26), Vector2(0, 26)]), Color(0.1, 0.1, 0.1), 2.2)  # main rotor (cross)

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

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

## Brief starburst of fading lines at a world position, to make an attack
## landing readable even when the two shapes involved barely move.
static func spawn_impact_spark(world: Node, global_pos: Vector2, color: Color = Color(1.0, 0.95, 0.75, 0.95)) -> void:
	if world == null or not is_instance_valid(world):
		return
	var spark := Node2D.new()
	spark.global_position = global_pos
	spark.z_index = 6
	world.add_child(spark)
	var ray_count := 6
	for i in ray_count:
		var a: float = TAU * i / ray_count + randf_range(-0.25, 0.25)
		var ray_len: float = randf_range(7.0, 15.0)
		var line := Line2D.new()
		line.width = 2.2
		line.default_color = color
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.points = PackedVector2Array([Vector2.ZERO, Vector2(cos(a), sin(a)) * ray_len])
		spark.add_child(line)
	var tw := spark.create_tween()
	tw.tween_property(spark, "modulate:a", 0.0, 0.22)
	tw.tween_callback(spark.queue_free)

static func build_lizard(parent: Node2D, body_color: Color, has_spikes: bool = false) -> void:
	clear(parent)
	var dark := body_color.darkened(0.15)
	var belly := body_color.lightened(0.35)
	# tail
	_poly(parent, PackedVector2Array([Vector2(-6, 8), Vector2(6, 8), Vector2(0, 27)]), body_color, Vector2.ZERO, -1)
	_line(parent, PackedVector2Array([Vector2(0, 9), Vector2(0, 24)]), dark, 1.2)
	# legs, with small toe claws at the tips
	for side in [-1.0, 1.0]:
		_poly(parent, PackedVector2Array([Vector2(0, -3), Vector2(side * 13, -6), Vector2(side * 9, 3)]), dark, Vector2(side * 5, -3), -1)
		_poly(parent, PackedVector2Array([Vector2(0, -3), Vector2(side * 13, 0), Vector2(side * 9, 6)]), dark, Vector2(side * 5, 7), -1)
		for toe in [-1.0, 0.0, 1.0]:
			_poly(parent, PackedVector2Array([Vector2(-1, 0), Vector2(1, 0), Vector2(toe * 0.6, 2.6)]), dark.darkened(0.2), Vector2(side * 17, 6 + toe), -1)
	# body + lighter belly patch
	_poly(parent, _ellipse(13, 0.78), body_color)
	_poly(parent, _ellipse(8, 0.55), belly, Vector2(0, 4), 0)
	# head
	var head_pos := Vector2(0, -17)
	_poly(parent, _ellipse(8, 0.9), body_color, head_pos, 1)
	# nostrils + mouth line for a bit of facial detail
	for side in [-1.0, 1.0]:
		_poly(parent, _ellipse(0.6), dark.darkened(0.3), head_pos + Vector2(side * 2.0, -6.5), 3)
	_line(parent, PackedVector2Array([head_pos + Vector2(-4, 2), head_pos + Vector2(4, 2)]), dark.darkened(0.1), 0.8)
	# eyes
	for side in [-1.0, 1.0]:
		_poly(parent, _ellipse(2.2), Color.WHITE, head_pos + Vector2(side * 3.5, -1.5), 2)
		_poly(parent, _ellipse(1.0), Color(0.08, 0.08, 0.08), head_pos + Vector2(side * 3.5, -1.5), 3)
	if has_spikes:
		_add_spikes(parent, dark, -14.0, 14.0, 5)

static func build_trex(parent: Node2D, body_color: Color) -> void:
	clear(parent)
	var dark := body_color.darkened(0.15)
	var belly := body_color.lightened(0.3)
	# tail (thicker, longer than the small lizard's), with banding
	_poly(parent, PackedVector2Array([Vector2(-8, 12), Vector2(8, 12), Vector2(0, 38)]), body_color, Vector2.ZERO, -1)
	for t in [18.0, 26.0]:
		_line(parent, PackedVector2Array([Vector2(-6 * (1.0 - t / 38.0), t), Vector2(6 * (1.0 - t / 38.0), t)]), dark, 1.0)
	# legs, clawed toes
	for side in [-1.0, 1.0]:
		_poly(parent, PackedVector2Array([Vector2(0, -4), Vector2(side * 16, -8), Vector2(side * 12, 6)]), dark, Vector2(side * 6, 4), -1)
		_poly(parent, PackedVector2Array([Vector2(0, -4), Vector2(side * 16, 2), Vector2(side * 12, 10)]), dark, Vector2(side * 6, 14), -1)
		for toe in [-1.0, 0.0, 1.0]:
			_poly(parent, PackedVector2Array([Vector2(-1.3, 0), Vector2(1.3, 0), Vector2(toe * 0.8, 3.4)]), dark.darkened(0.25), Vector2(side * 19, 15 + toe), -1)
	# tiny arms with claws
	for side in [-1.0, 1.0]:
		_line(parent, PackedVector2Array([Vector2(side * 8, -14), Vector2(side * 14, -10)]), dark, 2.2)
		_poly(parent, PackedVector2Array([Vector2(-0.8, 0), Vector2(0.8, 0), Vector2(0, 2.2)]), dark.darkened(0.3), Vector2(side * 14, -10), -1)
	# body + lighter belly patch
	_poly(parent, _ellipse(16, 0.75), body_color)
	_poly(parent, _ellipse(9, 0.5), belly, Vector2(0, 5), 0)
	# head with snout
	var head_pos := Vector2(0, -24)
	_poly(parent, _ellipse(11, 0.85), body_color, head_pos, 1)
	_poly(parent, PackedVector2Array([Vector2(-5, -6), Vector2(5, -6), Vector2(0, -16)]), body_color, head_pos, 1)
	# jagged teeth along the jawline
	for side in [-1.0, 1.0]:
		for i in 2:
			var tx: float = side * (2.0 + i * 2.2)
			_poly(parent, PackedVector2Array([Vector2(-0.7, 0), Vector2(0.7, 0), Vector2(0, 1.8)]), Color(0.95, 0.95, 0.9), head_pos + Vector2(tx, -1), 3)
	# eyes
	for side in [-1.0, 1.0]:
		_poly(parent, _ellipse(2.4), Color.WHITE, head_pos + Vector2(side * 5, -2), 2)
		_poly(parent, _ellipse(1.1), Color(0.05, 0.05, 0.05), head_pos + Vector2(side * 5, -2), 3)
	# dorsal spikes
	_add_spikes(parent, dark, -20.0, 20.0, 6)

static func build_godzilla(parent: Node2D, body_color: Color) -> void:
	clear(parent)
	var dark := body_color.darkened(0.18)
	var belly := body_color.lightened(0.4)
	# thick tail with plate stubs
	_poly(parent, PackedVector2Array([Vector2(-10, 14), Vector2(10, 14), Vector2(0, 46)]), body_color, Vector2.ZERO, -1)
	for t in [22.0, 32.0, 40.0]:
		var w: float = 8.0 * (1.0 - t / 46.0)
		_poly(parent, PackedVector2Array([Vector2(-2.5, 3), Vector2(2.5, 3), Vector2(0, -5)]), dark, Vector2(0, t - w), 0)
	# bulky legs with clawed toes
	for side in [-1.0, 1.0]:
		_poly(parent, PackedVector2Array([Vector2(0, -5), Vector2(side * 19, -9), Vector2(side * 14, 7)]), dark, Vector2(side * 7, 5), -1)
		_poly(parent, PackedVector2Array([Vector2(0, -5), Vector2(side * 19, 3), Vector2(side * 14, 12)]), dark, Vector2(side * 7, 16), -1)
		for toe in [-1.0, 0.0, 1.0]:
			_poly(parent, PackedVector2Array([Vector2(-1.6, 0), Vector2(1.6, 0), Vector2(toe, 4.0)]), dark.darkened(0.3), Vector2(side * 22, 18 + toe), -1)
	# small arms with claws
	for side in [-1.0, 1.0]:
		_line(parent, PackedVector2Array([Vector2(side * 9, -16), Vector2(side * 16, -11)]), dark, 2.6)
		_poly(parent, PackedVector2Array([Vector2(-1.0, 0), Vector2(1.0, 0), Vector2(0, 2.6)]), dark.darkened(0.3), Vector2(side * 16, -11), -1)
	# body + lighter belly plating
	_poly(parent, _ellipse(19, 0.75), body_color)
	_poly(parent, _ellipse(11, 0.5), belly, Vector2(0, 6), 0)
	# head with snout (bigger than the T-Rex's)
	var head_pos := Vector2(0, -31)
	_poly(parent, _ellipse(16, 0.88), body_color, head_pos, 1)
	_poly(parent, PackedVector2Array([Vector2(-8, -7), Vector2(8, -7), Vector2(0, -23)]), body_color, head_pos, 1)
	# fangs
	for side in [-1.0, 1.0]:
		for i in 2:
			var tx: float = side * (3.0 + i * 3.0)
			_poly(parent, PackedVector2Array([Vector2(-1.0, 0), Vector2(1.0, 0), Vector2(0, 2.6)]), Color(0.95, 0.95, 0.9), head_pos + Vector2(tx, -1), 3)
	# eyes with a faint glow ring for a menacing look
	for side in [-1.0, 1.0]:
		_poly(parent, _ellipse(4.4), Color(1.0, 0.35, 0.15, 0.35), head_pos + Vector2(side * 7, -2), 1)
		_poly(parent, _ellipse(3.2), Color.WHITE, head_pos + Vector2(side * 7, -2), 2)
		_poly(parent, _ellipse(1.5), Color(0.05, 0.05, 0.05), head_pos + Vector2(side * 7, -2), 3)
	# dramatic dorsal plates - denser and covering more of the back/head
	_add_spikes(parent, dark, -34.0, 34.0, 12)

static func build_oviraptor(parent: Node2D, body_color: Color, head_color: Color) -> void:
	clear(parent)
	var dark := body_color.darkened(0.15)
	# tail with a feathered tuft at the tip
	_poly(parent, PackedVector2Array([Vector2(-5, 10), Vector2(5, 10), Vector2(0, 26)]), body_color, Vector2.ZERO, -1)
	for side in [-1.0, 1.0]:
		_line(parent, PackedVector2Array([Vector2(0, 24), Vector2(side * 6, 32)]), dark, 1.3)
	# legs with clawed toes
	for side in [-1.0, 1.0]:
		_poly(parent, PackedVector2Array([Vector2(0, -3), Vector2(side * 12, -5), Vector2(side * 9, 4)]), dark, Vector2(side * 5, -2), -1)
		_poly(parent, PackedVector2Array([Vector2(0, -3), Vector2(side * 12, 1), Vector2(side * 9, 7)]), dark, Vector2(side * 5, 7), -1)
		for toe in [-1.0, 0.0, 1.0]:
			_poly(parent, PackedVector2Array([Vector2(-1.0, 0), Vector2(1.0, 0), Vector2(toe * 0.6, 2.8)]), dark.darkened(0.25), Vector2(side * 14, 11 + toe), -1)
	# small arms with claws
	for side in [-1.0, 1.0]:
		_line(parent, PackedVector2Array([Vector2(side * 6, -12), Vector2(side * 11, -8)]), dark, 1.8)
		_poly(parent, PackedVector2Array([Vector2(-0.7, 0), Vector2(0.7, 0), Vector2(0, 2.0)]), dark.darkened(0.3), Vector2(side * 11, -8), -1)
	# body with a few quill/feather streaks along the back
	_poly(parent, _ellipse(11, 0.7), body_color)
	for i in 3:
		_line(parent, PackedVector2Array([Vector2(-2 + i * 2, 6), Vector2(-2 + i * 2, -2)]), dark, 0.9)
	# head (distinct color) with a small crest
	var head_pos := Vector2(0, -19)
	_poly(parent, _ellipse(7, 0.85), head_color, head_pos, 1)
	_poly(parent, PackedVector2Array([Vector2(-3, -6), Vector2(3, -6), Vector2(0, -13)]), head_color.darkened(0.2), head_pos, 1)
	# small beak hook + eyes
	_poly(parent, PackedVector2Array([Vector2(-1.5, 3), Vector2(1.5, 3), Vector2(0, 6)]), head_color.darkened(0.35), head_pos, 2)
	for side in [-1.0, 1.0]:
		_poly(parent, _ellipse(1.6), Color(0.05, 0.05, 0.05), head_pos + Vector2(side * 3, -1), 2)

static func build_helicopter(parent: Node2D, body_color: Color) -> void:
	clear(parent)
	var dark := body_color.darkened(0.2)
	_line(parent, PackedVector2Array([Vector2(0, 16), Vector2(0, 22)]), dark, 3.0)  # tail boom
	_poly(parent, PackedVector2Array([Vector2(-3, 18), Vector2(3, 18), Vector2(3, 22), Vector2(-3, 22)]), dark, Vector2.ZERO, -1)  # tail fin
	_line(parent, PackedVector2Array([Vector2(-7, 20), Vector2(7, 20)]), Color(0.15, 0.15, 0.15), 1.4)  # tail rotor
	# landing skids
	for side in [-1.0, 1.0]:
		_line(parent, PackedVector2Array([Vector2(side * 6, 6), Vector2(side * 6, 13)]), dark, 1.2)
		_line(parent, PackedVector2Array([Vector2(side * 2, 13), Vector2(side * 10, 13)]), dark, 1.4)
	_poly(parent, _ellipse(13, 0.6), body_color)  # body
	# hazard stripe along the body
	_line(parent, PackedVector2Array([Vector2(-11, 4), Vector2(11, 4)]), Color(0.95, 0.75, 0.1, 0.8), 1.6)
	_poly(parent, _ellipse(6, 0.8), Color(0.65, 0.85, 0.95, 0.85), Vector2(0, -3), 1)  # cockpit
	_line(parent, PackedVector2Array([Vector2(0, -8), Vector2(0, 2)]), Color(0.25, 0.3, 0.35, 0.6), 1.0)  # windscreen divider
	_line(parent, PackedVector2Array([Vector2(-26, 0), Vector2(26, 0)]), Color(0.1, 0.1, 0.1), 2.2)  # main rotor
	_line(parent, PackedVector2Array([Vector2(0, -26), Vector2(0, 26)]), Color(0.1, 0.1, 0.1), 2.2)  # main rotor (cross)
	_poly(parent, _ellipse(2.2), Color(0.1, 0.1, 0.1), Vector2.ZERO, 2)  # rotor hub

static func build_ant(parent: Node2D, body_color: Color) -> void:
	clear(parent)
	var leg_color := body_color.darkened(0.2)
	var sheen := body_color.lightened(0.3)
	for i in 3:
		var ly := -6.0 + i * 6.0
		for side in [-1.0, 1.0]:
			_line(parent, PackedVector2Array([Vector2(side * 3, ly), Vector2(side * 16, ly - 4.0 + i * 3.0)]), leg_color, 1.6)
	for side in [-1.0, 1.0]:
		_line(parent, PackedVector2Array([Vector2(side * 1.5, -16), Vector2(side * 7, -24)]), leg_color, 1.4)
	# waist joints connecting the three body segments
	_line(parent, PackedVector2Array([Vector2(0, 4), Vector2(0, 6)]), leg_color, 2.0)
	_line(parent, PackedVector2Array([Vector2(0, -5), Vector2(0, -4)]), leg_color, 1.6)
	_poly(parent, _ellipse(6.5), body_color, Vector2(0, 10))
	_poly(parent, _ellipse(5.5), body_color, Vector2(0, 0))
	_poly(parent, _ellipse(4.5), body_color, Vector2(0, -11))
	# glossy highlight on the abdomen + a pair of mandibles
	_poly(parent, _ellipse(2.4, 0.7), sheen, Vector2(-1.5, 8), 0)
	for side in [-1.0, 1.0]:
		_poly(parent, PackedVector2Array([Vector2(0, 0), Vector2(side * 2.5, 1.5), Vector2(0, 2.5)]), leg_color.darkened(0.2), Vector2(0, -15), 1)

static func build_bird(parent: Node2D, body_color: Color) -> void:
	clear(parent)
	var wingtip := body_color.darkened(0.3)
	for side in [-1.0, 1.0]:
		_poly(parent, PackedVector2Array([Vector2(0, -2), Vector2(side * 30, -14), Vector2(side * 34, -2), Vector2(side * 10, 6)]), body_color.darkened(0.1), Vector2.ZERO, -1)
		# darker wingtip feathers
		_poly(parent, PackedVector2Array([Vector2(side * 26, -12), Vector2(side * 34, -2), Vector2(side * 24, 0)]), wingtip, Vector2.ZERO, -1)
		_line(parent, PackedVector2Array([Vector2(side * 8, -6), Vector2(side * 28, -10)]), body_color.darkened(0.2), 0.8)
	# fanned tail feathers
	_poly(parent, PackedVector2Array([Vector2(-5, 10), Vector2(5, 10), Vector2(0, 20)]), body_color, Vector2.ZERO, -1)
	for side in [-1.0, 1.0]:
		_line(parent, PackedVector2Array([Vector2(0, 16), Vector2(side * 4, 21)]), body_color.darkened(0.15), 1.0)
	_poly(parent, _ellipse(11, 0.62), body_color)
	# small webbed feet
	for side in [-1.0, 1.0]:
		_line(parent, PackedVector2Array([Vector2(side * 2, 6), Vector2(side * 4, 10)]), Color(0.9, 0.55, 0.15), 1.0)
	_poly(parent, PackedVector2Array([Vector2(-3, -14), Vector2(3, -14), Vector2(0, -21)]), Color(0.95, 0.55, 0.15), Vector2.ZERO, 1)
	_poly(parent, _ellipse(1.3), Color(0.1, 0.1, 0.1), Vector2(3, -12), 2)
	_poly(parent, _ellipse(0.4), Color(1, 1, 1, 0.8), Vector2(3.4, -12.4), 3)  # eye glint

static func build_crab(parent: Node2D, body_color: Color) -> void:
	clear(parent)
	var leg_color := body_color.darkened(0.25)
	var shell_light := body_color.lightened(0.2)
	for i in 3:
		var ly := -4.0 + i * 5.0
		for side in [-1.0, 1.0]:
			_line(parent, PackedVector2Array([Vector2(side * 8, ly), Vector2(side * 20, ly + 6.0)]), leg_color, 1.8)
			# leg-tip point for a bit more silhouette detail
			_line(parent, PackedVector2Array([Vector2(side * 20, ly + 6.0), Vector2(side * 23, ly + 9.0)]), leg_color.darkened(0.15), 1.2)
	_poly(parent, _ellipse(13, 0.72), body_color)
	# mottled shell texture + a highlight streak
	for spot in [Vector2(-5, -2), Vector2(4, 3), Vector2(-2, 5), Vector2(6, -3)]:
		_poly(parent, _ellipse(1.6, 0.8), shell_light, spot, 0)
	_line(parent, PackedVector2Array([Vector2(-8, -5), Vector2(8, -5)]), shell_light, 1.0)
	for side in [-1.0, 1.0]:
		_line(parent, PackedVector2Array([Vector2(side * 9, -9), Vector2(side * 20, -16)]), leg_color, 2.2)
		_poly(parent, _ellipse(5.5, 0.7), body_color.lightened(0.15), Vector2(side * 22, -17))
		# pincer tip detail
		_line(parent, PackedVector2Array([Vector2(side * 25, -19), Vector2(side * 29, -15)]), leg_color.darkened(0.2), 1.6)
		_line(parent, PackedVector2Array([Vector2(side * 25, -15), Vector2(side * 29, -19)]), leg_color.darkened(0.2), 1.6)
		_line(parent, PackedVector2Array([Vector2(side * 3, -8), Vector2(side * 4, -16)]), leg_color, 1.4)
		_poly(parent, _ellipse(1.6), Color(0.05, 0.05, 0.05), Vector2(side * 4, -16))
		_poly(parent, _ellipse(0.5), Color(1, 1, 1, 0.8), Vector2(side * 4 + 0.4, -16.4), 3)  # eye glint

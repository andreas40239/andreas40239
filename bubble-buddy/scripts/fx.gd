class_name BBFx
extends Node2D
## Particle bursts and floating praise text.
##
## Every positive interaction gets a sensory reward (GDD pillar "Rewarding"), so
## this node is deliberately generous with sparkles and stingy with anything
## that could read as punishment.

const DOT_SCALE := 0.7


func _make_burst(pos: Vector2, count: int, color: Color, spread: float, speed: float, scale_min: float, scale_max: float, gravity: Vector2, lifetime: float) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.position = pos
	p.amount = maxi(count, 1)
	p.one_shot = true
	p.explosiveness = 0.85
	p.lifetime = lifetime
	p.texture = BBDraw.dot_texture()
	p.local_coords = false

	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = spread
	m.initial_velocity_min = speed * 0.4
	m.initial_velocity_max = speed
	m.gravity = Vector3(gravity.x, gravity.y, 0)
	m.scale_min = scale_min
	m.scale_max = scale_max
	m.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, color.a))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	m.angular_velocity_min = -180.0
	m.angular_velocity_max = 180.0
	p.process_material = m

	add_child(p)
	p.finished.connect(p.queue_free)
	p.emitting = true
	return p


func sparkle(pos: Vector2, color := Color(1.0, 0.95, 0.72), count := 10) -> void:
	_make_burst(pos, count, color, 180.0, 220.0, 0.35, 0.85, Vector2(0, -40), 0.6)


func confetti(pos: Vector2, count := 24) -> void:
	for i in 4:
		var c := BBDraw.rainbow_color(randf())
		_make_burst(pos, maxi(count / 4, 2), c, 180.0, 330.0, 0.5, 1.2, Vector2(0, 240), 1.2)


func bubbles(pos: Vector2, count := 8, color := Color(0.85, 0.97, 1.0, 0.8)) -> void:
	_make_burst(pos, count, color, 55.0, 160.0, 0.4, 1.0, Vector2(0, -260), 1.1)


func dust(pos: Vector2, color := Color(0.95, 0.88, 0.7, 0.75), count := 16) -> void:
	_make_burst(pos, count, color, 120.0, 190.0, 0.8, 1.9, Vector2(0, -30), 0.9)


func pop_ring(pos: Vector2, color := Color(1, 1, 1, 0.9), radius := 90.0) -> void:
	var ring := BBRing.new()
	ring.position = pos
	ring.max_radius = radius
	ring.color = color
	add_child(ring)


func praise(pos: Vector2, text: String, color := Color(1, 1, 1)) -> void:
	var label := BBFloatText.new()
	label.position = pos
	label.text = text
	label.color = color
	add_child(label)

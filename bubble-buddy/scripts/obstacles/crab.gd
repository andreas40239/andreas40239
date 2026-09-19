class_name BBCrab
extends BBEntity
## Grumpy Crab: scuttles sideways across a gap, wears a tiny pirate hat, and is
## never hurt. A Big Bubble tumbles him aside with a surprised "bloop!".

const SPEED := 150.0

var dir := 1.0
var span := 220.0
var _home_x := 0.0
var _slow := 0.0
var _surprise := 0.0
var _claw := 0.0


func _ready() -> void:
	kind = Kind.OBSTACLE
	radius = 56.0
	_home_x = position.x
	dir = 1.0 if randf() < 0.5 else -1.0


func update_entity(delta: float) -> void:
	_slow = maxf(_slow - delta, 0.0)
	_surprise = maxf(_surprise - delta, 0.0)
	_claw += delta * (3.0 if _slow <= 0.0 else 1.1)
	if pushed:
		return
	var speed := SPEED * (0.35 if _slow > 0.0 else 1.0)
	position.x += dir * speed * delta
	if absf(position.x - _home_x) > span * 0.5:
		position.x = _home_x + signf(position.x - _home_x) * span * 0.5
		dir *= -1.0


func on_small_bubble(game) -> bool:
	# Small bubbles don't move him, they just make him dawdle.
	_slow = 1.6
	game.fx.pop_ring(position, Color(0.9, 0.98, 1.0, 0.6), 70.0)
	Sound.play_varied("small_bubble", 0.1, -6.0)
	return true


func on_big_bubble(game, dir_x: float) -> bool:
	if pushed:
		return false
	push_aside(dir_x)
	_surprise = 1.2
	game.fx.bubbles(position, 10)
	game.fx.praise(position + Vector2(0, -70), "Bloop!", Color(1, 0.95, 0.7))
	Sound.play_varied("push_crab", 0.08)
	return true


func on_touch(game, _player) -> void:
	game.bump_player(position)


func _draw() -> void:
	var sway := sin(age * 6.0) * 0.08
	var body := Color(0.92, 0.33, 0.28)
	if _slow > 0.0:
		body = body.lerp(Color(0.72, 0.84, 0.95), 0.25)

	# Legs.
	for i in 3:
		for s in [-1.0, 1.0]:
			var base := Vector2(s * 26.0, 14.0 + i * 8.0)
			var knee := base + Vector2(s * 22.0, 10.0 + sin(_claw * 2.0 + i) * 6.0)
			var foot := knee + Vector2(s * 16.0, 18.0)
			draw_polyline(PackedVector2Array([base, knee, foot]), body.darkened(0.2), 8.0, true)

	# Claws, one of them shaking in mock anger after a push.
	var shake := sin(age * 22.0) * 0.5 if _surprise > 0.0 else sin(_claw) * 0.2
	for s in [-1.0, 1.0]:
		var shoulder := Vector2(s * 40.0, -6.0)
		var elbow := shoulder + Vector2(s * 26.0, -18.0 - (shake * 16.0 if s > 0.0 else 0.0))
		draw_line(shoulder, elbow, body.darkened(0.15), 11.0, true)
		BBDraw.ellipse(self, elbow, 18.0, 14.0, body, s * 0.4 + shake * 0.2, 16)
		draw_line(elbow + Vector2(s * 6, -10), elbow + Vector2(s * 20, -16), body.darkened(0.25), 6.0, true)

	# Shell.
	BBDraw.ellipse(self, Vector2.ZERO, 46.0, 34.0, body, sway, 26)
	BBDraw.ellipse(self, Vector2(0, -8), 34.0, 18.0, body.lightened(0.18), sway, 22)

	# Tiny pirate hat.
	var hat := Vector2(0, -34.0)
	draw_colored_polygon(PackedVector2Array([
		hat + Vector2(-30, 4), hat + Vector2(30, 4), hat + Vector2(16, -18), hat + Vector2(-16, -18),
	]), Color(0.18, 0.22, 0.3))
	BBDraw.ellipse(self, hat + Vector2(0, 4), 33.0, 8.0, Color(0.18, 0.22, 0.3), 0.0, 18)
	BBDraw.star(self, hat + Vector2(0, -6), 4, 8.0, 3.0, Color(0.98, 0.92, 0.7), 0.4)

	# Face: eyes on stalks plus the grumpy brow that marks every hazard.
	for s in [-1.0, 1.0]:
		var stalk := Vector2(s * 15.0, -22.0)
		draw_line(Vector2(s * 12.0, -10.0), stalk, body.darkened(0.2), 6.0, true)
		if _surprise > 0.0:
			BBDraw.ellipse(self, stalk, 12.0, 12.0, Color.WHITE, 0.0, 14)
			BBDraw.ellipse(self, stalk, 5.0, 5.0, Color(0.13, 0.2, 0.27), 0.0, 12)
		else:
			BBDraw.eye(self, stalk, 11.0, Vector2(dir * 0.6, 0.2))
		BBDraw.brow(self, stalk + Vector2(0, -13.0), 20.0, s * 0.45)
	if _surprise > 0.0:
		BBDraw.ellipse(self, Vector2(0, 6), 9.0, 11.0, Color(0.5, 0.18, 0.2), 0.0, 14)
	else:
		BBDraw.smile(self, Vector2(0, 14), 14.0, Color(0.5, 0.18, 0.2), 5.0, true)

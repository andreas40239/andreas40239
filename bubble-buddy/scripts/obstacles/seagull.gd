class_name BBSeagull
extends BBEntity
## Surface Shine zone. A seagull skims sideways just under the surface, dips its
## beak, and is startled off by a Big Bubble.

var dir := 1.0
var speed := 210.0
var _flap := 0.0


func _ready() -> void:
	kind = Kind.OBSTACLE
	radius = 52.0
	dir = 1.0 if position.x < 540.0 else -1.0
	scroll_factor = 0.85


func update_entity(delta: float) -> void:
	_flap += delta * 7.0
	if pushed:
		return
	position.x += dir * speed * delta
	position.y += sin(age * 2.2) * 26.0 * delta
	if position.x < -140.0 or position.x > 1220.0:
		alive = false


func on_big_bubble(game, dir_x: float) -> bool:
	if pushed:
		return false
	push_aside(dir_x, 560.0)
	game.fx.bubbles(position, 8)
	game.fx.praise(position + Vector2(0, -70), "Squawk!", Color(1, 0.98, 0.82))
	Sound.play_varied("push_crab", 0.15)
	return true


func on_touch(game, _player) -> void:
	game.bump_player(position)


func _draw() -> void:
	var white := Color(0.98, 0.98, 1.0)
	var grey := Color(0.72, 0.78, 0.86)
	var flap := sin(_flap) * 0.6
	# Wings.
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -6),
			Vector2(s * 70.0, -30.0 - flap * 34.0),
			Vector2(s * 30.0, 12.0),
		]), grey)
	BBDraw.ellipse(self, Vector2.ZERO, 44.0, 28.0, white, dir * 0.1, 26)
	BBDraw.ellipse(self, Vector2(dir * 34.0, -16.0), 20.0, 19.0, white, 0.0, 20)
	# Beak.
	draw_colored_polygon(PackedVector2Array([
		Vector2(dir * 50.0, -14.0), Vector2(dir * 78.0, -8.0), Vector2(dir * 50.0, -2.0),
	]), Color(0.98, 0.72, 0.25))
	BBDraw.eye(self, Vector2(dir * 40.0, -22.0), 8.0, Vector2(dir * 0.5, 0.1))
	BBDraw.brow(self, Vector2(dir * 40.0, -34.0), 16.0, -dir * 0.5)
	# Tail.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-dir * 40.0, 0), Vector2(-dir * 66.0, -14.0), Vector2(-dir * 66.0, 14.0),
	]), grey)

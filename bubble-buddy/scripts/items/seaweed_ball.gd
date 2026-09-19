class_name BBSeaweedBall
extends BBEntity
## A baby sea creature tangled in a seaweed ball. A Big Bubble frees them; they
## then follow Finley for a while before waving goodbye.
##
## Touching the ball does nothing at all - this is a puzzle, not a hazard.

var species := "turtle"
var golden := false     # today's Golden Friend
var _freed := false


func _ready() -> void:
	kind = Kind.OBSTACLE
	radius = 66.0


func on_big_bubble(game, _dir: float) -> bool:
	if _freed:
		return false
	_freed = true
	alive = false
	game.free_friend(self)
	return true


func on_touch(_game, _player) -> void:
	pass


func on_rainbow(game) -> void:
	# Rainbow Rush frees friends rather than confetti-ing them.
	if not _freed:
		_freed = true
		alive = false
		game.free_friend(self)


func _draw() -> void:
	# The ball stays green so it always reads as tangled seaweed; a Golden
	# Friend is marked by gilded strands and a halo, not by a different shape.
	var col := Color(0.24, 0.58, 0.34)
	var strand_col := col.darkened(0.15)
	if golden:
		strand_col = Color(0.95, 0.80, 0.30)
		draw_circle(Vector2.ZERO, 96.0, Color(1.0, 0.88, 0.45, 0.18))
	BBDraw.blob(self, Vector2.ZERO, 62.0, col, age * 1.2, 5, 0.08, 36)
	for i in 7:
		var a := age * 0.6 + TAU * float(i) / 7.0
		var pts := PackedVector2Array()
		for j in 9:
			var k := float(j) / 8.0
			var ang := a + k * PI
			pts.append(Vector2(cos(ang) * 58.0, sin(ang) * 58.0 * (1.0 - k * 0.25)))
		draw_polyline(pts, strand_col, 9.0, true)

	# The trapped friend peeks out, looking hopeful rather than distressed.
	var peek := Vector2(0, 4)
	BBDraw.ellipse(self, peek, 26.0, 22.0, _species_color(), 0.0, 22)
	BBDraw.eye(self, peek + Vector2(-9, -4), 7.5, Vector2(0, 0.25))
	BBDraw.eye(self, peek + Vector2(9, -4), 7.5, Vector2(0, 0.25))
	BBDraw.smile(self, peek + Vector2(0, 7), 9.0, Color(0.3, 0.25, 0.2), 3.5)

	# "Pop me" cue: a bubble outline hint that pulses.
	var pulse := 0.5 + sin(age * 3.0) * 0.5
	draw_arc(Vector2.ZERO, 78.0 + pulse * 8.0, 0.0, TAU, 32, Color(0.85, 0.97, 1.0, 0.25 + pulse * 0.3), 5.0, true)
	if golden:
		for i in 4:
			var a := age * 1.6 + TAU * float(i) / 4.0
			BBDraw.sparkle(self, Vector2(cos(a), sin(a)) * 86.0, 15.0, Color(1, 0.95, 0.6, 0.9), a)


func _species_color() -> Color:
	match species:
		"turtle": return Color(0.45, 0.78, 0.48)
		"seahorse": return Color(0.98, 0.72, 0.42)
		"octopus": return Color(0.82, 0.52, 0.86)
		_: return Color(0.55, 0.78, 0.94)

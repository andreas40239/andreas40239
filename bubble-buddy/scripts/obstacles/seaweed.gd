class_name BBSeaweed
extends BBEntity
## Tangled Seaweed: static and swaying. Swim around it, or pop it with a Big
## Bubble to reveal what is hidden inside.

var height := 320.0
var strands := 3
var hidden_reward := "pearls"   # "pearls" | "starfish"
var _tangle := 0.0
var _phase := 0.0


func _ready() -> void:
	kind = Kind.OBSTACLE
	radius = 62.0
	_phase = randf() * TAU


func update_entity(delta: float) -> void:
	_tangle = maxf(_tangle - delta, 0.0)


func on_big_bubble(game, _dir: float) -> bool:
	game.pop_seaweed(self)
	return true


func on_touch(game, _player) -> void:
	# Not a hit: seaweed just slows Finley down for a moment, with a giggle.
	if _tangle > 0.0:
		return
	_tangle = 0.9
	game.tangle_player()


func _draw() -> void:
	var col := Color(0.20, 0.62, 0.36)
	var sway := sin(age * 1.4 + _phase) * 0.22

	# Each strand is a slim ribbon with broad leaves alternating down its
	# length, so the silhouette reads as leafy weed rather than a smooth stalk.
	for s in strands:
		var base_x := (float(s) - (strands - 1) * 0.5) * 42.0
		var shade := col.darkened(0.06 * s)
		var pts := PackedVector2Array()
		for i in 11:
			var k := float(i) / 10.0
			var x := base_x + sin(k * 3.0 + age * 1.6 + _phase + s) * 30.0 * k + sway * 44.0 * k
			pts.append(Vector2(x, -height * k))
		draw_polyline(pts, shade, 14.0, true)
		for i in range(1, 11):
			var side := 1.0 if (i + s) % 2 == 0 else -1.0
			var leaf_k := float(i) / 10.0
			var leaf_len: float = lerpf(34.0, 18.0, leaf_k)
			var angle := side * 0.75 + sway * 0.5
			BBDraw.ellipse(self, pts[i] + Vector2(cos(angle), sin(angle)) * leaf_len * 0.55,
				leaf_len, leaf_len * 0.36, shade.lightened(0.10 + 0.04 * i), angle, 14)

	# The tangle knot sits where the strands cross: the cue that something is
	# hidden inside and that a Big Bubble will open it.
	var knot := Vector2(sway * 30.0, -height * 0.52)
	BBDraw.blob(self, knot, 62.0, col.lightened(0.04), age * 1.4, 5, 0.12, 30)
	for i in 4:
		var a := age * 0.5 + TAU * float(i) / 4.0
		var loop := PackedVector2Array()
		for j in 10:
			var t := float(j) / 9.0
			var ang := a + t * PI
			loop.append(knot + Vector2(cos(ang) * 56.0, sin(ang) * 40.0))
		draw_polyline(loop, col.darkened(0.16), 9.0, true)
	BBDraw.ellipse(self, knot + Vector2(-10, -10), 20.0, 15.0, Color(0.95, 0.98, 0.85, 0.35), -0.4, 16)
	if SaveData.shape_cues:
		BBDraw.sparkle(self, knot, 16.0, Color(1, 1, 1, 0.5), age * 1.2)
	# A small grumpy face on the tangle keeps the visual language consistent.
	BBDraw.brow(self, knot + Vector2(-15, -14), 18.0, 0.4, Color(0.12, 0.3, 0.2, 0.7))
	BBDraw.brow(self, knot + Vector2(15, -14), 18.0, -0.4, Color(0.12, 0.3, 0.2, 0.7))

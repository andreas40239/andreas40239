class_name BBPufferfish
extends BBEntity
## Sleepy Pufferfish: inflates and deflates on a four second cycle. Puffed up he
## fills the lane; deflated, Finley swims straight past. Completely predictable,
## which is the point.

const CYCLE := 4.0

var _inflate := 0.0
var _phase := 0.0
var _puffed_last := false


func _ready() -> void:
	kind = Kind.OBSTACLE
	radius = 46.0
	_phase = randf() * CYCLE


func update_entity(_delta: float) -> void:
	var t := fposmod(age + _phase, CYCLE) / CYCLE
	# Inflate over the first half, hold, then sigh back down.
	_inflate = clampf(sin(t * PI) * 1.25, 0.0, 1.0)
	radius = lerpf(42.0, 92.0, _inflate)
	var puffed := _inflate > 0.55
	if puffed and not _puffed_last:
		Sound.play_varied("puff", 0.12, -10.0)
	_puffed_last = puffed


func on_big_bubble(game, dir_x: float) -> bool:
	if pushed:
		return false
	push_aside(dir_x, 480.0)
	game.fx.bubbles(position, 8)
	Sound.play_varied("push_crab", 0.1, -4.0)
	return true


func on_touch(game, _player) -> void:
	# Only a puffed-up puffer is in the way at all.
	if _inflate > 0.55:
		game.bump_player(position)


func _draw() -> void:
	var r: float = lerpf(40.0, 90.0, _inflate)
	var body := Color(0.98, 0.83, 0.45).lerp(Color(0.95, 0.66, 0.35), _inflate)

	# Tail and side fins.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 0.9, 0), Vector2(-r * 1.5, -r * 0.4), Vector2(-r * 1.5, r * 0.4),
	]), body.darkened(0.12))

	BBDraw.blob(self, Vector2.ZERO, r, body, age * 1.6, 3, 0.05 + _inflate * 0.03, 34)
	BBDraw.ellipse(self, Vector2(0, -r * 0.3), r * 0.66, r * 0.34, body.lightened(0.16), 0.0, 24)

	# Spikes grow with inflation: the shape itself signals "wait a moment".
	if _inflate > 0.12:
		var spikes := 14
		for i in spikes:
			var a := TAU * float(i) / float(spikes) + age * 0.3
			var base := Vector2(cos(a), sin(a)) * r * 0.96
			var tip := Vector2(cos(a), sin(a)) * (r + 10.0 + 22.0 * _inflate)
			var side := Vector2(-sin(a), cos(a)) * 7.0
			draw_colored_polygon(PackedVector2Array([base - side, base + side, tip]), body.darkened(0.22))

	# Sleepy face.
	var eye_y := -r * 0.16
	if _inflate > 0.55:
		BBDraw.eye(self, Vector2(-r * 0.3, eye_y), r * 0.15, Vector2(0, 0.2))
		BBDraw.eye(self, Vector2(r * 0.3, eye_y), r * 0.15, Vector2(0, 0.2))
		BBDraw.ellipse(self, Vector2(0, r * 0.35), r * 0.12, r * 0.14, Color(0.6, 0.32, 0.25), 0.0, 14)
	else:
		# Closed, snoozing eyes.
		for s in [-1.0, 1.0]:
			BBDraw.smile(self, Vector2(s * r * 0.3, eye_y), r * 0.16, Color(0.4, 0.3, 0.22), 5.0)
		BBDraw.smile(self, Vector2(0, r * 0.3), r * 0.18, Color(0.6, 0.32, 0.25), 5.0)
		# A little sleep bubble.
		var zz := fposmod(age, 2.0) / 2.0
		draw_circle(Vector2(r * 0.8, -r * 0.7 - zz * 40.0), 9.0 * (1.0 - zz * 0.4), Color(1, 1, 1, 0.5 * (1.0 - zz)))
	BBDraw.brow(self, Vector2(-r * 0.3, eye_y - r * 0.3), r * 0.3, 0.4, Color(0.45, 0.3, 0.2, 0.8))
	BBDraw.brow(self, Vector2(r * 0.3, eye_y - r * 0.3), r * 0.3, -0.4, Color(0.45, 0.3, 0.2, 0.8))

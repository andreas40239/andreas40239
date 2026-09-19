class_name BBPearl
extends BBEntity
## Shiny Pearl: the main currency. Gently drifts toward Finley when he is close,
## so young players are rewarded for being roughly in the right place.

const MAGNET_RANGE := 150.0

var value := 1
var dropped := false      # pearls shaken loose after a bump
var _shine := 0.0


func _ready() -> void:
	kind = Kind.COLLECTIBLE
	radius = 30.0
	_shine = randf() * TAU


func update_entity(delta: float) -> void:
	if dropped:
		# Dropped pearls hang in the water a moment so they can be re-collected.
		position += push_velocity * delta * 0.4


func magnet_toward(point: Vector2, delta: float) -> void:
	var d := point - position
	if d.length() < MAGNET_RANGE:
		position += d.normalized() * 320.0 * delta


func on_touch(game, _player) -> void:
	game.collect_pearl(self)


func _draw() -> void:
	var pulse := 1.0 + sin(age * 3.2 + _shine) * 0.06
	var r := 27.0 * pulse

	# Warm halo and a gold rim. Bubbles in this game are cool, hollow and
	# translucent, so a pearl has to be warm, solid and ringed to stay
	# instantly distinguishable from Finley's own bubble stream.
	draw_circle(Vector2.ZERO, r * 1.85, Color(1.0, 0.92, 0.72, 0.16))
	BBDraw.ellipse(self, Vector2(0, r * 0.18), r * 1.06, r * 1.06, Color(0.96, 0.74, 0.34, 0.55), 0.0, 22)
	BBDraw.ellipse(self, Vector2.ZERO, r, r, Color(1.0, 0.86, 0.45), 0.0, 24)
	BBDraw.ellipse(self, Vector2.ZERO, r * 0.86, r * 0.86, Color(1.0, 0.98, 0.94), 0.0, 24)

	# Iridescence: a peach lobe and a cool lobe, the way a real pearl shifts.
	BBDraw.ellipse(self, Vector2(r * 0.26, r * 0.28), r * 0.52, r * 0.36, Color(1.0, 0.82, 0.74, 0.75), -0.5, 16)
	BBDraw.ellipse(self, Vector2(-r * 0.3, r * 0.2), r * 0.4, r * 0.26, Color(0.80, 0.90, 1.0, 0.6), 0.5, 16)
	BBDraw.ellipse(self, Vector2(-r * 0.26, -r * 0.32), r * 0.40, r * 0.30, Color(1, 1, 1, 0.98), -0.5, 16)

	# Rhythmic shine: the universal "good thing" cue.
	var t := fposmod(age * 0.8 + _shine, 1.0)
	if t < 0.35:
		BBDraw.sparkle(self, Vector2(r * 0.62, -r * 0.7), 14.0 * (1.0 - t / 0.35), Color(1, 1, 1, 0.95), age)

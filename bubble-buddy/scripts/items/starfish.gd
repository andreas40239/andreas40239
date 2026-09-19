class_name BBStarfish
extends BBEntity
## Starfish Sticker: a cosmetic collectible hidden in nooks, worth a page in the
## Sticker Book.

var _phase := 0.0


func _ready() -> void:
	kind = Kind.COLLECTIBLE
	radius = 44.0
	_phase = randf() * TAU


func on_touch(game, _player) -> void:
	game.collect_starfish(self)


func _draw() -> void:
	var wob := sin(age * 2.0 + _phase) * 0.12
	var r := 42.0 + sin(age * 3.0 + _phase) * 2.0
	draw_circle(Vector2.ZERO, r * 1.5, Color(1, 0.95, 0.7, 0.16))
	# Five soft arms.
	var col := Color(1.0, 0.72, 0.30)
	for i in 5:
		var a := -PI * 0.5 + TAU * float(i) / 5.0 + wob
		var tip := Vector2(cos(a), sin(a)) * r
		BBDraw.ellipse(self, tip * 0.62, r * 0.42, r * 0.26, col, a, 16)
		BBDraw.ellipse(self, tip * 0.92, r * 0.2, r * 0.2, col, 0.0, 12)
	BBDraw.ellipse(self, Vector2.ZERO, r * 0.52, r * 0.52, col.lightened(0.12), 0.0, 20)
	# Little happy face, because everything friendly has one.
	BBDraw.eye(self, Vector2(-8, -4), 6.0, Vector2(0, 0.2))
	BBDraw.eye(self, Vector2(8, -4), 6.0, Vector2(0, 0.2))
	BBDraw.smile(self, Vector2(0, 6), 9.0, Color(0.7, 0.35, 0.15), 3.5)
	BBDraw.sparkle(self, Vector2(r * 0.6, -r * 0.7), 12.0, Color(1, 1, 1, 0.8), age * 1.5)

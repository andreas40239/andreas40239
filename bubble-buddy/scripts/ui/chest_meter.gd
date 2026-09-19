class_name BBChestMeter
extends Node2D
## Treasure Chest meter: 100 pearls fills it. Drawn rather than themed so the
## chest can bounce when it is nearly full.

var ratio := 0.0


func _draw() -> void:
	var w := 300.0
	var h := 34.0
	# Track.
	BBDraw.rounded_rect(self, Rect2(Vector2(56, -h * 0.5), Vector2(w, h)), h * 0.5, Color(0.08, 0.28, 0.36, 0.45))
	if ratio > 0.0:
		var fill := maxf(w * ratio, h)
		BBDraw.rounded_rect(self, Rect2(Vector2(56, -h * 0.5), Vector2(fill, h)), h * 0.5, Color(1.0, 0.82, 0.3))
		BBDraw.rounded_rect(self, Rect2(Vector2(62, -h * 0.5 + 5), Vector2(maxf(fill - 12, 4), h * 0.34)), h * 0.2, Color(1, 0.95, 0.72, 0.7))

	# Chest icon, bouncing gently as it nears full.
	var bounce: float = 0.0
	if ratio > 0.8:
		bounce = sin(Time.get_ticks_msec() * 0.008) * 4.0
	var c := Vector2(20, bounce)
	BBDraw.rounded_rect(self, Rect2(c + Vector2(-22, -6), Vector2(44, 28)), 6.0, Color(0.55, 0.36, 0.22))
	BBDraw.rounded_rect(self, Rect2(c + Vector2(-24, -20), Vector2(48, 18)), 9.0, Color(0.68, 0.45, 0.28))
	BBDraw.rounded_rect(self, Rect2(c + Vector2(-24, -6), Vector2(48, 7)), 3.0, Color(1.0, 0.82, 0.3))
	BBDraw.ellipse(self, c + Vector2(0, 2), 6.0, 6.0, Color(1.0, 0.82, 0.3), 0.0, 10)

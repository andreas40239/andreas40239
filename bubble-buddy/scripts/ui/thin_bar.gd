class_name BBThinBar
extends Node2D
## A slim timer bar for whichever power-up is active.

var ratio := 0.0
var color := Color.WHITE


func _draw() -> void:
	var w := 320.0
	var h := 18.0
	BBDraw.rounded_rect(self, Rect2(Vector2.ZERO, Vector2(w, h)), h * 0.5, Color(0.08, 0.28, 0.36, 0.45))
	if ratio > 0.0:
		BBDraw.rounded_rect(self, Rect2(Vector2.ZERO, Vector2(maxf(w * ratio, h), h)), h * 0.5, color)

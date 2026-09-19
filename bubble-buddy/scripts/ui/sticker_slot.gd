class_name BBStickerSlot
extends Control
## One sticker square: a coloured shape when found, a soft silhouette when not.
## Each zone uses a different shape family, so the book is readable without
## relying on colour.

var index := 0
var zone := 0
var found := false


func _ready() -> void:
	custom_minimum_size = Vector2(170, 170)


func _draw() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.38
	BBDraw.rounded_rect(self, Rect2(Vector2.ZERO, size), 28.0, Color(0.92, 0.95, 0.97, 0.85))
	if not found:
		# Unfound: a dashed outline plus a question dot, never a scolding lock.
		draw_arc(c, r, 0.0, TAU, 28, Color(0.68, 0.74, 0.79, 0.7), 5.0, true)
		BBDraw.ellipse(self, c, r * 0.18, r * 0.18, Color(0.68, 0.74, 0.79, 0.7), 0.0, 12)
		return

	var palette := [
		Color(0.98, 0.52, 0.45),
		Color(0.38, 0.74, 0.48),
		Color(0.40, 0.66, 0.90),
		Color(0.68, 0.50, 0.92),
		Color(1.0, 0.78, 0.30),
	]
	var col: Color = palette[posmod(zone, palette.size())]
	var variant := index % 5
	match posmod(zone, 5):
		0:
			BBDraw.star(self, c, 5, r, r * 0.46, col, float(variant) * 0.3)
		1:
			BBDraw.blob(self, c, r * 0.95, col, float(variant), 3 + variant, 0.1)
		2:
			BBDraw.ellipse(self, c, r, r * 0.72, col, float(variant) * 0.4, 24)
			BBDraw.ellipse(self, c, r * 0.5, r * 0.36, col.lightened(0.25), float(variant) * 0.4, 18)
		3:
			BBDraw.sparkle(self, c, r, col, float(variant) * 0.3)
		_:
			BBDraw.rounded_rect(self, Rect2(c - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), r * 0.42, col)
	BBDraw.ellipse(self, c - Vector2(r * 0.3, r * 0.35), r * 0.2, r * 0.14, Color(1, 1, 1, 0.75), -0.5, 12)

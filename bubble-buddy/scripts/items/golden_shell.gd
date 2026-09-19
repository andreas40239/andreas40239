class_name BBGoldenShell
extends BBEntity
## Golden Shell: a rare spawn that fills the Treasure Chest meter instantly.

func _ready() -> void:
	kind = Kind.COLLECTIBLE
	radius = 52.0


func on_touch(game, _player) -> void:
	game.collect_golden_shell(self)


func _draw() -> void:
	var gold := Color(1.0, 0.84, 0.32)
	var pulse := 1.0 + sin(age * 3.6) * 0.05
	draw_circle(Vector2.ZERO, 92.0 * pulse, Color(1, 0.9, 0.5, 0.18))
	draw_circle(Vector2.ZERO, 62.0 * pulse, Color(1, 0.92, 0.55, 0.18))
	# Scallop shell: a fan opening upward from a hinge at the bottom, with
	# scalloped ribs so it reads as a shell and not as a coin or a sun.
	var hinge := Vector2(0, 40)
	var pts := PackedVector2Array()
	pts.append(hinge)
	for i in 19:
		var k := float(i) / 18.0
		var a: float = lerpf(PI * 1.06, PI * 1.94, k)
		var r := 66.0 + sin(k * PI * 9.0) * 5.0     # scalloped outer edge
		pts.append(hinge + Vector2(cos(a) * r, sin(a) * r * 1.02))
	draw_colored_polygon(pts, gold)
	# Ribs fanning out from the hinge.
	for i in 7:
		var a: float = lerpf(PI * 1.1, PI * 1.9, float(i) / 6.0)
		draw_line(hinge + Vector2(cos(a), sin(a)) * 12.0,
			hinge + Vector2(cos(a), sin(a)) * 60.0, gold.darkened(0.2), 4.0, true)
	# Hinge ears.
	for s: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			hinge, hinge + Vector2(s * 34.0, -4.0), hinge + Vector2(s * 20.0, 12.0),
		]), gold.darkened(0.12))
	BBDraw.ellipse(self, hinge, 14.0, 9.0, gold.lightened(0.2), 0.0, 14)
	for i in 3:
		var a := age * 1.4 + TAU * float(i) / 3.0
		BBDraw.sparkle(self, Vector2(cos(a), sin(a)) * 64.0, 16.0, Color(1, 1, 1, 0.85), a)

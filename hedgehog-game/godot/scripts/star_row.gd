class_name StarRow
extends Control
## Draws 0-3 gold stars out of 3 (results screen, title screen).

@export var stars := 0
@export var star_size := 32.0
@export var spacing := 80.0


func _draw() -> void:
	for i in 3:
		var color := Color(1.0, 0.82, 0.2) if i < stars else Color(0.3, 0.3, 0.35)
		var center := Vector2(size.x / 2.0 + (i - 1) * spacing, size.y / 2.0)
		var points := PackedVector2Array()
		for k in 10:
			var r := star_size if k % 2 == 0 else star_size * 0.4
			var a := -PI / 2.0 + k * PI / 5.0
			points.append(center + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(points, color)

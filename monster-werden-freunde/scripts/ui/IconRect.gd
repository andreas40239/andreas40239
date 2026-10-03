class_name IconRect
extends Control
## Zeigt ein Vektor-Icon in einem Control an.

@export var icon: StringName = &"star":
	set(value):
		icon = value
		queue_redraw()
@export var tint: Color = Color.WHITE:
	set(value):
		tint = value
		queue_redraw()
var icon_scale := 1.0:
	set(value):
		icon_scale = value
		queue_redraw()


static func make(icon_name: StringName, size: float, color: Color = Color.WHITE) -> IconRect:
	var r := IconRect.new()
	r.icon = icon_name
	r.tint = color
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _draw() -> void:
	Icons.draw(self, icon, size * 0.5, minf(size.x, size.y) * icon_scale, tint)

class_name BBBubbleVisual
extends Sprite2D
## A shader-driven soft bubble. Used for the Bubble Shield and the Big Bubble so
## both read as the same friendly material.

var diameter := 200.0:
	set(value):
		diameter = value
		_refresh_scale()


func _init() -> void:
	texture = BBDraw.white_texture()
	centered = true
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/bubble.gdshader")
	mat.set_shader_parameter("seed", randf() * 10.0)
	material = mat
	_refresh_scale()


func _refresh_scale() -> void:
	if texture == null:
		return
	# The shader draws inside the quad, so the quad must cover the full circle.
	var base := float(texture.get_width())
	scale = Vector2.ONE * (diameter / base) * 1.06


func set_tint(color: Color) -> void:
	(material as ShaderMaterial).set_shader_parameter("tint", color)

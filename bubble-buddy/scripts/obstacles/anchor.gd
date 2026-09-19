class_name BBAnchor
extends BBEntity
## Falling Anchor: drops straight down a little faster than the current, then
## thumps into the sea floor with a puff of dust and is gone.

const FALL_SPEED := 210.0

var floor_y := 1800.0
var _landed := false
var _sway := 0.0


func _ready() -> void:
	kind = Kind.OBSTACLE
	radius = 58.0
	_sway = randf() * TAU


func update_entity(delta: float) -> void:
	if _landed:
		return
	position.y += FALL_SPEED * delta
	position.x += sin(age * 1.6 + _sway) * 18.0 * delta


func land(game) -> void:
	if _landed:
		return
	_landed = true
	alive = false
	game.fx.dust(Vector2(position.x, floor_y), Color(0.96, 0.9, 0.72, 0.8), 20)
	Sound.play_varied("puff", 0.1, -6.0)


func on_big_bubble(game, dir_x: float) -> bool:
	if pushed:
		return false
	push_aside(dir_x, 420.0)
	game.fx.bubbles(position, 8)
	Sound.play_varied("push_crab", 0.1, -6.0)
	return true


func on_touch(game, _player) -> void:
	game.bump_player(position)


func _draw() -> void:
	var metal := Color(0.55, 0.60, 0.68)
	var rust := Color(0.68, 0.45, 0.30)
	# Rope trailing upward keeps the anchor readable before it arrives.
	var pts := PackedVector2Array()
	for i in 7:
		var k := float(i) / 6.0
		pts.append(Vector2(sin(age * 2.0 + k * 3.0) * 12.0 * k, -60.0 - k * 150.0))
	draw_polyline(pts, Color(0.85, 0.76, 0.55, 0.75), 7.0, true)

	draw_line(Vector2(0, -58), Vector2(0, 40), metal, 14.0, true)
	draw_arc(Vector2(0, -66), 16.0, PI, TAU, 16, metal, 10.0, true)
	draw_line(Vector2(-34, -30), Vector2(34, -30), rust, 11.0, true)
	# Flukes.
	var arc := PackedVector2Array()
	for i in 17:
		var a: float = lerpf(PI * 0.15, PI * 0.85, float(i) / 16.0)
		arc.append(Vector2(cos(a) * -58.0, sin(a) * 42.0 + 22.0))
	draw_polyline(arc, metal, 16.0, true)
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(s * 56, 30), Vector2(s * 76, 6), Vector2(s * 40, 46),
		]), metal.darkened(0.1))
	BBDraw.ellipse(self, Vector2(0, 40), 14.0, 10.0, rust, 0.0, 14)
	if SaveData.shape_cues:
		# Downward chevron: "this one is coming at you".
		draw_polyline(PackedVector2Array([Vector2(-22, -92), Vector2(0, -74), Vector2(22, -92)]),
			Color(1, 0.95, 0.6, 0.8), 5.0, true)

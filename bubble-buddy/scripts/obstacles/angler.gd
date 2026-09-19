class_name BBAngler
extends BBEntity
## Deep Trench anglerfish. Nothing bites: only the cone of lamp light is a
## hazard, and it sweeps slowly and visibly so it is always easy to read.

const BEAM_LENGTH := 420.0

var side := 1.0
var _sweep := 0.0
var beam_on := true
var _cycle := 0.0


func _ready() -> void:
	kind = Kind.OBSTACLE
	radius = 70.0
	side = 1.0 if position.x < 540.0 else -1.0
	scroll_factor = 0.95


func update_entity(delta: float) -> void:
	_cycle += delta
	# The lamp dims for a beat every few seconds, giving a clear window.
	beam_on = fposmod(_cycle, 4.4) < 3.0
	_sweep = sin(age * 0.7) * 0.5


func lamp_origin() -> Vector2:
	return position + Vector2(side * 46.0, -54.0)


func beam_direction() -> Vector2:
	return Vector2(side, 0.0).rotated(_sweep * side)


## The light beam is the hazard, so the touch test is a cone test rather than a
## circle test. Handled by game.gd via this helper.
func beam_hits(point: Vector2) -> bool:
	if not beam_on:
		return false
	var to := point - lamp_origin()
	if to.length() > BEAM_LENGTH:
		return false
	return to.normalized().dot(beam_direction()) > 0.90


func on_big_bubble(game, dir_x: float) -> bool:
	if pushed:
		return false
	push_aside(dir_x, 380.0)
	beam_on = false
	game.fx.bubbles(position, 10)
	Sound.play_varied("pop", 0.1)
	return true


func on_touch(game, _player) -> void:
	game.bump_player(position)


func _draw() -> void:
	var body := Color(0.32, 0.28, 0.52)
	var glow := Color(0.75, 0.95, 0.72)

	if beam_on:
		# Soft, layered cone so the beam is obvious but never harsh.
		var o := lamp_origin()
		var d := beam_direction()
		for i in 3:
			var spread := 0.16 + i * 0.07
			var length := BEAM_LENGTH * (1.0 - i * 0.12)
			draw_colored_polygon(PackedVector2Array([
				o,
				o + d.rotated(spread) * length,
				o + d * length * 1.04,
				o + d.rotated(-spread) * length,
			]), Color(glow.r, glow.g, glow.b, 0.10))

	BBDraw.blob(self, Vector2.ZERO, 64.0, body, age * 1.3, 3, 0.06, 30)
	BBDraw.ellipse(self, Vector2(0, -16), 42.0, 22.0, body.lightened(0.16), 0.0, 22)
	# Tail.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-side * 58, 0), Vector2(-side * 96, -34), Vector2(-side * 96, 34),
	]), body.darkened(0.12))
	# Lamp on a stalk.
	var stalk_end := lamp_origin()
	draw_polyline(PackedVector2Array([Vector2(side * 10, -46), Vector2(side * 30, -76), stalk_end]),
		body.darkened(0.2), 9.0, true)
	var lamp_r := 20.0 if beam_on else 11.0
	draw_circle(stalk_end, lamp_r * 1.9, Color(glow.r, glow.g, glow.b, 0.22 if beam_on else 0.07))
	BBDraw.ellipse(self, stalk_end, lamp_r, lamp_r, Color(glow.r, glow.g, glow.b, 0.95 if beam_on else 0.4), 0.0, 16)
	# Face: big sleepy eye, soft round teeth that could not hurt a pea.
	BBDraw.eye(self, Vector2(side * 26.0, -10.0), 15.0, Vector2(side * 0.4, 0.1))
	BBDraw.brow(self, Vector2(side * 26.0, -30.0), 26.0, -side * 0.4)
	for i in 4:
		BBDraw.ellipse(self, Vector2(side * (46.0 - i * 13.0), 20.0 + i * 3.0), 6.0, 7.0, Color(1, 1, 1, 0.85), 0.0, 10)

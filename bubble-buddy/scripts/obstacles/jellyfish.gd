class_name BBJellyfish
extends BBEntity
## Drifting Jellyfish: floats in a sine wave, gives a harmless tiny zap, then
## looks thoroughly embarrassed about it.

var amplitude := 140.0
var frequency := 0.6
var _home_x := 0.0
var _embarrassed := 0.0


func _ready() -> void:
	kind = Kind.OBSTACLE
	radius = 54.0
	_home_x = position.x
	scroll_factor = 0.92


func update_entity(delta: float) -> void:
	_embarrassed = maxf(_embarrassed - delta, 0.0)
	if not pushed:
		position.x = _home_x + sin(age * TAU * frequency) * amplitude


func on_big_bubble(game, dir_x: float) -> bool:
	if pushed:
		return false
	push_aside(dir_x, 520.0)
	game.fx.bubbles(position, 8)
	Sound.play_varied("pop", 0.1)
	return true


func on_touch(game, _player) -> void:
	_embarrassed = 2.0
	game.zap_player(position)


func _draw() -> void:
	var pulse := 1.0 + sin(age * 2.6) * 0.1
	var body := Color(1.0, 0.62, 0.82, 0.62)
	if _embarrassed > 0.0:
		body = body.lerp(Color(1.0, 0.45, 0.55, 0.7), 0.5)

	# Tentacles.
	for i in 6:
		var base := Vector2((float(i) - 2.5) * 13.0, 22.0)
		var pts := PackedVector2Array()
		for j in 7:
			var k := float(j) / 6.0
			pts.append(base + Vector2(sin(age * 3.0 + i + k * 4.0) * 16.0 * k, 78.0 * k))
		draw_polyline(pts, Color(body.r, body.g, body.b, 0.42), 7.0, true)

	# Translucent bell: layered alpha instead of a shader keeps it cheap.
	BBDraw.ellipse(self, Vector2.ZERO, 54.0 * pulse, 44.0 * pulse, Color(body.r, body.g, body.b, 0.35), 0.0, 26)
	BBDraw.ellipse(self, Vector2(0, -4), 44.0 * pulse, 36.0 * pulse, Color(body.r, body.g, body.b, 0.5), 0.0, 24)
	BBDraw.ellipse(self, Vector2(-14, -14), 16.0, 11.0, Color(1, 1, 1, 0.55), -0.4, 14)

	if _embarrassed > 0.0:
		# Blushing cheeks and a sheepish little mouth.
		BBDraw.ellipse(self, Vector2(-26, 6), 10.0, 7.0, Color(1.0, 0.35, 0.45, 0.6), 0.0, 12)
		BBDraw.ellipse(self, Vector2(26, 6), 10.0, 7.0, Color(1.0, 0.35, 0.45, 0.6), 0.0, 12)
		BBDraw.eye(self, Vector2(-15, -4), 9.0, Vector2(0, 0.6), 0.55)
		BBDraw.eye(self, Vector2(15, -4), 9.0, Vector2(0, 0.6), 0.55)
		BBDraw.smile(self, Vector2(0, 12), 10.0, Color(0.6, 0.25, 0.35, 0.8), 4.0)
	else:
		BBDraw.eye(self, Vector2(-15, -4), 10.0, Vector2(0, 0.2))
		BBDraw.eye(self, Vector2(15, -4), 10.0, Vector2(0, 0.2))
		BBDraw.brow(self, Vector2(-15, -19), 18.0, 0.35, Color(0.7, 0.3, 0.45, 0.8))
		BBDraw.brow(self, Vector2(15, -19), 18.0, -0.35, Color(0.7, 0.3, 0.45, 0.8))
		BBDraw.smile(self, Vector2(0, 13), 11.0, Color(0.7, 0.3, 0.45, 0.8), 4.0, true)

	if SaveData.shape_cues:
		# Zig-zag cue: reads as "tingly" without relying on colour.
		var zig := PackedVector2Array()
		for i in 5:
			zig.append(Vector2(-22.0 + i * 11.0, -50.0 + (0.0 if i % 2 == 0 else 12.0)))
		draw_polyline(zig, Color(1, 1, 0.75, 0.75), 4.0, true)

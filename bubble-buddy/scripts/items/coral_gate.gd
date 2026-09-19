class_name BBCoralGate
extends BBEntity
## The Coral Gate: a glowing archway that saves progress, celebrates, and opens
## the next zone. The only "checkpoint" in a game with no failure states.

var zone := 0
var passed := false
var _glow := 0.0


func _ready() -> void:
	kind = Kind.GATE
	radius = 200.0
	z_index = 5


func update_entity(delta: float) -> void:
	_glow = minf(_glow + delta, 10.0)


func _draw() -> void:
	var z := Zones.get_zone(zone + 1)
	var col: Color = z["mid"]
	var glow: Color = z["near"]
	var pulse := 0.5 + sin(age * 2.2) * 0.5

	# Wide soft glow so the gate is visible long before it arrives.
	draw_circle(Vector2(0, 0), 320.0, Color(glow.r, glow.g, glow.b, 0.10 + pulse * 0.05))

	# Arch: two columns plus a curved top, drawn as fat polylines.
	var arch := PackedVector2Array()
	for i in 25:
		var a: float = lerpf(PI, TAU, float(i) / 24.0)
		arch.append(Vector2(cos(a) * 380.0, sin(a) * 240.0))
	draw_polyline(arch, col, 56.0, true)
	for s in [-1.0, 1.0]:
		draw_line(Vector2(s * 380.0, 0), Vector2(s * 380.0, 260.0), col, 56.0, true)
		# Coral knobs.
		for i in 4:
			BBDraw.ellipse(self, Vector2(s * 380.0, 40.0 + i * 62.0), 40.0, 30.0, col.lightened(0.1), 0.0, 16)

	# Glowing curtain the player swims through.
	for i in 5:
		var k := float(i) / 4.0
		draw_arc(Vector2.ZERO, 300.0 - i * 40.0, PI, TAU, 30,
			Color(glow.r, glow.g, glow.b, 0.22 * (1.0 - k) + pulse * 0.1), 14.0, true)

	# Sparkles along the arch.
	for i in 9:
		var a: float = lerpf(PI, TAU, float(i) / 8.0)
		var p := Vector2(cos(a) * 380.0, sin(a) * 240.0)
		var t := fposmod(age * 0.7 + float(i) * 0.12, 1.0)
		if t < 0.4:
			BBDraw.sparkle(self, p, 22.0 * (1.0 - t / 0.4), Color(1, 1, 1, 0.9), age + i)

	# Cheering little fish sitting on top of the arch.
	for i in 3:
		var x := (float(i) - 1.0) * 150.0
		var y := -250.0 + sin(age * 5.0 + i * 1.3) * 14.0
		var fish_col := Color(1.0, 0.72, 0.3).lerp(glow, 0.3)
		BBDraw.ellipse(self, Vector2(x, y), 30.0, 22.0, fish_col, 0.0, 18)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 26, y), Vector2(x - 46, y - 14), Vector2(x - 46, y + 14),
		]), fish_col)
		BBDraw.eye(self, Vector2(x + 12, y - 4), 6.0, Vector2(0, 0.2))
		BBDraw.smile(self, Vector2(x + 6, y + 6), 8.0, Color(0.5, 0.3, 0.2), 3.0)

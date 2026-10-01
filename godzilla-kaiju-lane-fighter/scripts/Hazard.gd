class_name Hazard
extends Node2D
## Telegraphed lane/column danger zone: flashes as a warning, then strikes.
## Used for tank laser sights, machine-gun strafes, boss lasers and beams.

var game
var lanes: Array = []
var x0 := 0.0
var x1 := 360.0
var warn := 1.0
var active := 0.5
var dmg := 10.0
var color := Color("ef4444")
var hits_air := false
var stun := 0.0
var thin := false     # laser-sight look during warning
var src_x = null
var t := 0.0
var done := false
var on_hit: Callable

func _ready() -> void:
	z_index = 40

func _process(delta: float) -> void:
	if game.frozen:
		return
	t += delta
	queue_redraw()
	if t >= warn and t < warn + active and not done and dmg > 0.0:
		var p: Player = game.player
		if p.state != "dead" and p.lane in lanes and p.position.x >= x0 - 10.0 and p.position.x <= x1 + 10.0 \
				and (hits_air or not p.airborne):
			done = true
			p.take_damage(dmg, {"stun": stun, "src_x": src_x, "unblockable": src_x == null})
			if on_hit.is_valid():
				on_hit.call()
	if t >= warn + active:
		queue_free()

func _draw() -> void:
	for l in lanes:
		var y: float = G.LANE_Y[l] - 62.0
		if t < warn:
			var a := 0.25 + 0.2 * sin(t * 25.0)
			if thin:
				draw_rect(Rect2(x0, y - 2, x1 - x0, 4), Color(color, a + 0.35))
			else:
				draw_rect(Rect2(x0, y - 30, x1 - x0, 60), Color(color, a * 0.6))
				draw_rect(Rect2(x0, y - 30, x1 - x0, 60), Color(color, a + 0.3), false, 2.0)
		else:
			draw_rect(Rect2(x0, y - 26, x1 - x0, 52), Color(color, 0.75))
			draw_rect(Rect2(x0, y - 10, x1 - x0, 20), Color(1, 1, 1, 0.9))

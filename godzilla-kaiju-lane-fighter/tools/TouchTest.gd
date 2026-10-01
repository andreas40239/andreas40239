extends Node
## Simulates real finger taps on each on-screen button and reports the result.
var game
var t := 0.0
var step := 0

func _ready() -> void:
	GameState.current_level = 1
	game = load("res://scenes/game.tscn").instantiate()
	get_tree().root.add_child.call_deferred(game)

func _touch(pos: Vector2, pressed: bool, idx := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = get_viewport().get_final_transform() * pos
	e.pressed = pressed
	get_viewport().push_input(e)

func _drag(pos: Vector2, rel: Vector2, idx := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = get_viewport().get_final_transform() * pos
	e.relative = rel
	get_viewport().push_input(e)

func _process(delta: float) -> void:
	t += delta
	if game.controls == null:
		return
	var c = game.controls
	var p = game.player
	if step == 0 and t > 0.9 and t < 1.0:
		# every point inside each DRAWN circle must map to that same button
		for zone in ["attack", "jump", "special"]:
			var node: Control = c.get_node("btn_" + zone)
			var r: Rect2 = node.get_global_rect()
			var ok := 0
			var total := 0
			for ring in [0.0, 0.4, 0.8]:
				for k in 12:
					var a: float = k * TAU / 12.0
					var pt: Vector2 = r.get_center() + Vector2(cos(a), sin(a)) * r.size.x * 0.5 * ring
					total += 1
					if c._zone_at(pt) == zone:
						ok += 1
			print("TOUCH: drawn %s circle -> %d/%d points hit %s" % [zone, ok, total, zone])
		step = -1
	if step == -1 and t > 1.0:
		step = 0
	if step == 0 and t > 1.0:
		print("TOUCH: viewport=%s jmp=%s atk=%s spc=%s" % [get_viewport().get_visible_rect().size, c.jmp_c, c.atk_c, c.spc_c])
		_touch(c.jmp_c, true); step = 1
	elif step == 1 and t > 1.08:
		_touch(c.jmp_c + Vector2(3, 2), false); step = 2
	elif step == 2 and t > 1.2:
		print("TOUCH: after jump tap airborne=%s state=%s" % [p.airborne, p.state]); step = 3
	elif step == 3 and t > 2.5:
		_touch(c.atk_c, true); step = 4
	elif step == 4 and t > 2.58:
		_touch(c.atk_c, false); step = 5
	elif step == 5 and t > 2.62:
		print("TOUCH: after attack tap state=%s" % p.state); step = 6
	elif step == 6 and t > 3.5:
		_touch(c.spc_c, true); step = 7
	elif step == 7 and t > 3.58:
		_touch(c.spc_c, false); step = 8
	elif step == 8 and t > 3.62:
		print("TOUCH: after special tap cd=%.1f" % p.special_cd); step = 9
	elif step == 9 and t > 4.5:
		_touch(c.jmp_c, true); step = 10
	elif step == 10 and t > 4.55:
		_drag(c.jmp_c + Vector2(0, -30), Vector2(0, -30)); step = 11
	elif step == 11 and t > 4.6:
		_touch(c.jmp_c + Vector2(0, -30), false); step = 12
	elif step == 12 and t > 4.7:
		print("TOUCH: after jump swipe-up airborne=%s" % p.airborne)
		get_tree().quit()

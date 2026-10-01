class_name Training
extends Control
## Level 0: step-by-step practice of every move. An animated finger shows the
## gesture right on the real button; the step completes when Godzilla does it.

var game
var step := -1
var progress := 0.0
var anim_t := 0.0
var waiting := false
var walk_from := 0.0
var text_label: Label
var count_label: Label
var hand_tex: Texture2D

const YELLOW := Color("facc15")

## zone: dpad / attack / jump / special. kind: tap, tap3, hold, swipe, dpad_lr, dpad_ud
const STEPS := [
	{"text": "HOLD LEFT OR RIGHT\nTO WALK", "zone": "dpad", "kind": "dpad_lr", "need": "walk"},
	{"text": "TAP UP OR DOWN\nTO CHANGE LANE", "zone": "dpad", "kind": "dpad_ud", "need": "lane", "count": 2},
	{"text": "TAP RED\n= TAIL WHIP", "zone": "attack", "kind": "tap", "need": "whip", "spawn": "raptor"},
	{"text": "TAP RED 3 TIMES FAST\n= SUPER COMBO", "zone": "attack", "kind": "tap3", "need": "combo"},
	{"text": "SWIPE SIDEWAYS ON RED\n= DASH ATTACK", "zone": "attack", "kind": "swipe", "dir": Vector2.RIGHT, "need": "dash"},
	{"text": "SWIPE UP ON RED\n= HIT FLYING ENEMIES", "zone": "attack", "kind": "swipe", "dir": Vector2.UP, "need": "antiair", "spawn": "ptera"},
	{"text": "SWIPE DOWN ON RED\n= GROUND STOMP", "zone": "attack", "kind": "swipe", "dir": Vector2.DOWN, "need": "pound"},
	{"text": "HOLD RED, THEN LET GO\n= ATOMIC BREATH", "zone": "attack", "kind": "hold", "need": "breath"},
	{"text": "TAP BLUE\n= JUMP", "zone": "jump", "kind": "tap", "need": "jump"},
	{"text": "SWIPE UP ON BLUE\n= BIG LEAP", "zone": "jump", "kind": "swipe", "dir": Vector2.UP, "need": "leap"},
	{"text": "SWIPE DOWN ON BLUE\n= DIVE SLAM", "zone": "jump", "kind": "swipe", "dir": Vector2.DOWN, "need": "dive"},
	{"text": "TAP PURPLE\n= NUCLEAR BLAST", "zone": "special", "kind": "tap", "need": "pulse"},
	{"text": "WALK INTO THE DIZZY RAPTOR\nTO GRAB IT. TAP RED TO THROW!", "zone": "dpad", "kind": "dpad_lr", "need": "throw", "spawn": "dizzy"},
	{"text": "TAP RED TO WHIP\nTHE MISSILE BACK!", "zone": "attack", "kind": "tap", "need": "swat", "spawn": "missile"},
]

func setup(p_game) -> void:
	game = p_game
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_tex = load("res://assets/sprites/ui/icon_hand.png")
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.55)
	panel.position = Vector2(0, 62)
	panel.size = Vector2(800, 64)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	count_label = Ui.label("", 7, Color(0.7, 0.75, 0.8))
	count_label.anchor_right = 1.0
	count_label.position = Vector2(0, 66)
	add_child(count_label)
	text_label = Ui.label("", 10, YELLOW)
	text_label.anchor_right = 1.0
	text_label.position = Vector2(0, 82)
	text_label.add_theme_constant_override("line_spacing", 6)
	add_child(text_label)
	var skip := Ui.button("SKIP >", func(): _finish(), 8, Color("6b7280"))
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -84
	skip.offset_right = -6
	skip.offset_top = 26
	add_child(skip)
	game.player.did.connect(_on_did)
	_next()

func _next() -> void:
	step += 1
	progress = 0.0
	anim_t = 0.0
	waiting = false
	if step >= STEPS.size():
		_finish()
		return
	var s: Dictionary = STEPS[step]
	text_label.text = s["text"]
	count_label.text = "PRACTICE %d / %d" % [step + 1, STEPS.size()]
	var p: Player = game.player
	p.meter = p.max_meter
	p.special_cd = 0.0
	walk_from = p.position.x
	if s.has("spawn"):
		_spawn(s["spawn"])

func _finish() -> void:
	if game.frozen:
		return
	waiting = true
	text_label.text = ""
	count_label.text = ""
	game._victory()

func _spawn(kind: String) -> void:
	var p: Player = game.player
	match kind:
		"raptor":
			if _live_enemies() < 2:
				game.spawn_enemy("raptor", false)
		"ptera":
			if _live_enemies() < 3:
				game.spawn_enemy("ptera", false)
		"dizzy":
			for e in game.enemies:
				if is_instance_valid(e) and e is Enemy and e.dizzy_forever:
					return
			if p.lane != G.LANE_GROUND:
				p.force_lane(G.LANE_GROUND)
			var e: Enemy = game.spawn_enemy("raptor", false)
			var side := 1.0 if p.position.x < 180.0 else -1.0
			e.position.x = clampf(p.position.x + 120.0 * side, 60.0, 300.0)
			e.dizzy_forever = true
			e._goto("stunned")
		"missile":
			for c in game.fx_root.get_children():
				if c is Projectile and not c.friendly:
					return
			var from_right := p.position.x < 180.0
			game.spawn_projectile("missile", p.lane, 380.0 if from_right else -20.0,
				Vector2(-90.0 if from_right else 90.0, 0), 0.0)

func _live_enemies() -> int:
	var n := 0
	for e in game.enemies:
		if is_instance_valid(e) and e.state != "dead":
			n += 1
	return n

func _on_did(action: String) -> void:
	if waiting or step < 0 or step >= STEPS.size():
		return
	var s: Dictionary = STEPS[step]
	if action == s["need"]:
		progress += 1.0
		if progress >= float(s.get("count", 1)):
			_success()

func _success() -> void:
	waiting = true
	AudioManager.play_sfx("ep_gain")
	game.hud.flash_message(["GREAT!", "AWESOME!", "SUPER!", "YES!", "PERFECT!"][step % 5], 0.9)
	text_label.text = ""
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree() and not game.frozen:
		_next()

func _process(delta: float) -> void:
	anim_t += delta
	queue_redraw()
	if waiting or step < 0 or step >= STEPS.size() or game.frozen:
		return
	var s: Dictionary = STEPS[step]
	if s["need"] == "walk" and absf(game.player.position.x - walk_from) > 140.0:
		_success()
	# keep practice targets around
	if s.has("spawn") and int(anim_t * 2.0) != int((anim_t - delta) * 2.0):
		_spawn(s["spawn"])

# ---------------- finger hint drawing ----------------
func _draw() -> void:
	if waiting or step < 0 or step >= STEPS.size():
		return
	var s: Dictionary = STEPS[step]
	var c = game.controls
	var center: Vector2 = c.button_center(s["zone"])
	var r: float = 70.0 if s["zone"] == "dpad" else c.RADIUS[s["zone"]]
	# pulsing yellow ring around the button to press
	draw_arc(center, r + 8.0 + 3.0 * sin(anim_t * 6.0), 0.0, TAU, 40, YELLOW, 3.0)
	var finger := center
	match s["kind"]:
		"tap":
			var ph := fmod(anim_t, 1.0)
			if ph < 0.3:
				draw_arc(center, 10.0 + ph * 60.0, 0.0, TAU, 24, Color(1, 1, 1, 1.0 - ph / 0.3), 3.0)
			finger = center + Vector2(0, 4.0 if ph < 0.3 else 0.0)
		"tap3":
			var ph := fmod(anim_t, 1.4)
			for k in 3:
				var tk := ph - k * 0.22
				if tk >= 0.0 and tk < 0.2:
					draw_arc(center, 10.0 + tk * 90.0, 0.0, TAU, 24, Color(1, 1, 1, 1.0 - tk / 0.2), 3.0)
			finger = center + Vector2(0, 4.0 if ph < 0.66 and fmod(ph, 0.22) < 0.1 else 0.0)
		"hold":
			var ph := fmod(anim_t, 1.8)
			var fill := clampf(ph / 1.2, 0.0, 1.0)
			draw_arc(center, r + 2.0, -PI / 2.0, -PI / 2.0 + TAU * fill, 40, Color(1, 1, 1), 5.0)
			if ph > 1.2:
				_arrow(center + Vector2(-20, -r - 14), center + Vector2(-140, -r - 14), Color("5eead4"))
		"swipe":
			var dir: Vector2 = s["dir"]
			var ph := fmod(anim_t, 1.1)
			var k := clampf(ph / 0.6, 0.0, 1.0)
			_arrow(center, center + dir * 60.0, YELLOW)
			if dir.x != 0.0:
				_arrow(center, center - dir * 60.0, Color(YELLOW, 0.5))
			finger = center + dir * 50.0 * k
		"dpad_lr":
			var ph := sin(anim_t * 3.0)
			_arrow(center, center + Vector2(64, 0), YELLOW)
			_arrow(center, center + Vector2(-64, 0), YELLOW)
			finger = center + Vector2(42.0 * signf(ph), 0)
		"dpad_ud":
			var up := fmod(anim_t, 1.6) < 0.8
			_arrow(center, center + Vector2(0, -64), YELLOW)
			_arrow(center, center + Vector2(0, 64), YELLOW)
			finger = center + Vector2(0, -42 if up else 42)
	# the finger: fingertip sits on the touch point
	draw_texture_rect(hand_tex, Rect2(finger - Vector2(18, 2), Vector2(40, 40)), false)

func _arrow(a: Vector2, b: Vector2, col: Color) -> void:
	draw_line(a, b, col, 4.0)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([b + d * 6.0, b - d * 10.0 + n * 9.0, b - d * 10.0 - n * 9.0]), col)

# Startup screen: four tanks roll onto the hills, the title bounces in and the
# tanks take turns firing firework shells until someone taps to play.
class_name StartupScreen
extends Control

signal done

const TAP_GUARD := 0.4       # ignore touches this soon after the screen opens
const TITLE := "TINY TANK WARS"

var _t := 0.0
var _left := false
var _next_shot := 1.9
var _shooter := 0
var _shells: Array = []      # {pos, vel, col}
var _confetti: Array = []    # {pos, vel, col, life, spin}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed)
	if tapped and _t > TAP_GUARD and not _left:
		_left = true
		A.click()
		done.emit()

func _hill(x: float) -> float:
	return size.y * 0.8 - sin(x / size.x * TAU * 1.3 + 0.6) * size.y * 0.05 \
			- sin(x / size.x * TAU * 3.1) * size.y * 0.02

# Where each tank ends up, and which way it faces (1 = right).
func _tank_home(i: int) -> Vector2:
	var fx: float = [0.12, 0.28, 0.72, 0.88][i]
	return Vector2(size.x * fx, 0.0)

func _tank_pos(i: int) -> Vector2:
	var home := _tank_home(i)
	var from_x := -120.0 if i < 2 else size.x + 120.0
	var start := 0.15 + float(i % 2) * 0.25
	var k := clampf((_t - start) / 1.1, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 3.0)
	var x := lerpf(from_x, home.x, k)
	var roll: float = absf(sin(_t * 16.0)) * 3.0 if k < 1.0 else sin(_t * 2.4 + float(i)) * 1.5
	return Vector2(x, _hill(x) - 30.0 - roll)  # tracks sit 32 px below the centre at 1.7x

func _process(delta: float) -> void:
	_t += delta
	if _t >= _next_shot:
		_fire(_shooter)
		_shooter = (_shooter + 3) % 4   # 0, 3, 2, 1, ... alternate sides
		_next_shot = _t + 1.6
	for sh in _shells:
		sh["vel"].y += 520.0 * delta
		sh["pos"] += sh["vel"] * delta
		if sh["vel"].y > -40.0:
			_burst(sh["pos"], sh["col"])
			sh["dead"] = true
	_shells = _shells.filter(func(sh): return not sh.get("dead", false))
	for c in _confetti:
		c["vel"].y += 260.0 * delta
		c["vel"] *= 0.985
		c["pos"] += c["vel"] * delta
		c["life"] -= delta
	_confetti = _confetti.filter(func(c): return c["life"] > 0.0)
	queue_redraw()

func _fire(i: int) -> void:
	var p := _tank_pos(i)
	var dirx := 1.0 if i < 2 else -1.0
	var target_x := size.x * randf_range(0.3, 0.7)
	var vx := (target_x - p.x) / 1.0
	_shells.append({"pos": p + Vector2(dirx * 42.0, -54.0),
			"vel": Vector2(vx, -randf_range(520.0, 600.0)), "col": UIKit.PLAYER_COLORS[i]})
	A.play("fire", randf_range(1.15, 1.35))

func _burst(pos: Vector2, col: Color) -> void:
	A.play("hit_splash", randf_range(1.3, 1.6))
	for k in range(36):
		var a := randf() * TAU
		var sp := randf_range(90.0, 300.0)
		var cc: Color = col if k % 3 else UIKit.PLAYER_COLORS[randi() % 4]
		_confetti.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * sp, "col": cc.lightened(0.15),
				"life": randf_range(0.9, 1.6), "spin": randf() * TAU})

func _draw() -> void:
	var w := size.x
	var h := size.y
	# Sky.
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0.40, 0.70, 0.98), Color(0.40, 0.70, 0.98),
			Color(0.80, 0.94, 1.0), Color(0.80, 0.94, 1.0)]))
	# Sun with slowly turning rays.
	var sun := Vector2(w * 0.88, h * 0.16)
	for k in range(12):
		var a := _t * 0.3 + TAU * float(k) / 12.0
		draw_line(sun + Vector2(cos(a), sin(a)) * 52.0, sun + Vector2(cos(a), sin(a)) * 74.0,
				Color(1.0, 0.9, 0.45, 0.8), 6.0)
	draw_circle(sun, 42.0, Color(1.0, 0.88, 0.4))
	# Drifting clouds.
	for k in range(3):
		var cx := fposmod(float(k) * w * 0.4 + _t * (18.0 + float(k) * 8.0), w + 300.0) - 150.0
		var cy := h * (0.1 + 0.09 * float(k))
		for o in [Vector2(-34, 6), Vector2.ZERO, Vector2(34, 6), Vector2(0, 14)]:
			draw_circle(Vector2(cx, cy) + o, 28.0, Color(1, 1, 1, 0.85))
	# Far and near hills.
	var far := PackedVector2Array([Vector2(0, h)])
	var near := PackedVector2Array([Vector2(0, h)])
	for i in range(41):
		var x := w * float(i) / 40.0
		far.append(Vector2(x, h * 0.66 - sin(float(i) * 0.55 + 1.0) * h * 0.07))
		near.append(Vector2(x, _hill(x)))
	far.append(Vector2(w, h))
	near.append(Vector2(w, h))
	draw_colored_polygon(far, Color(0.62, 0.8, 0.9))
	draw_colored_polygon(near, Color(0.45, 0.78, 0.4))
	# Tanks (the right-hand pair is mirrored to face inward).
	for i in range(4):
		var p := _tank_pos(i)
		if i < 2:
			UIKit.draw_mini_tank(self, p, 1.7, UIKit.PLAYER_COLORS[i], false, i)
		else:
			draw_set_transform(p, 0.0, Vector2(-1, 1))
			UIKit.draw_mini_tank(self, Vector2.ZERO, 1.7, UIKit.PLAYER_COLORS[i], false, i)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Shells and confetti.
	for sh in _shells:
		draw_circle(sh["pos"], 9.0, Color(0.25, 0.28, 0.36))
		draw_circle(sh["pos"] + Vector2(-3, -3), 3.0, Color(1, 1, 1, 0.6))
	for c in _confetti:
		var a: float = clampf(c["life"], 0.0, 1.0)
		var col: Color = c["col"]
		col.a = a
		var d := Vector2(cos(c["spin"] + _t * 8.0), sin(c["spin"] + _t * 8.0)) * 5.0
		draw_line(c["pos"] - d, c["pos"] + d, col, 5.0)
	_draw_title(w, h)
	# "Tap to play!" pill, pulsing once the intro has settled.
	if _t > 2.0:
		var f := ThemeDB.fallback_font
		var txt := "Tap to play!"
		var fs := 46
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var sc := 1.0 + 0.06 * sin(_t * 4.0)
		var fade := clampf((_t - 2.0) * 2.0, 0.0, 1.0)
		var c := Vector2(w * 0.5, h * 0.56)
		draw_set_transform(c, 0.0, Vector2(sc, sc))
		var box := Rect2(-tw * 0.5 - 34.0, -44.0, tw + 68.0, 80.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(UIKit.COL_GOOD, fade)
		sb.set_corner_radius_all(40)
		sb.border_color = Color(1, 1, 1, 0.9 * fade)
		sb.set_border_width_all(4)
		draw_style_box(sb, box)
		draw_string(f, Vector2(-tw * 0.5, 14.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(1, 1, 1, fade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var foot := "No ads  ·  No internet  ·  Just fun"
		var fw := f.get_string_size(foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, Vector2(w * 0.5 - fw * 0.5, h - 26.0), foot, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 22, Color(1, 1, 1, 0.85 * fade))

# Title letters drop in one after another, each in a player colour, then bob.
func _draw_title(w: float, h: float) -> void:
	var f := ThemeDB.fallback_font
	var fs := 104
	var total := f.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := w * 0.5 - total * 0.5
	var base_y := h * 0.34
	var ci := 0
	for i in range(TITLE.length()):
		var ch := TITLE[i]
		var cw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if ch != " ":
			var start := 0.7 + float(i) * 0.05
			var k := clampf((_t - start) / 0.5, 0.0, 1.0)
			# Back-out ease: overshoots slightly, then settles.
			var e := 1.0 + 2.7 * pow(k - 1.0, 3.0) + 1.7 * pow(k - 1.0, 2.0)
			var y := lerpf(-120.0, base_y, e) + sin(_t * 3.0 + float(i) * 0.5) * 4.0 * k
			var col: Color = UIKit.PLAYER_COLORS[ci % 4].lightened(0.1)
			draw_string_outline(f, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 18,
					Color(0.14, 0.22, 0.38))
			draw_string(f, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			ci += 1
		x += cw

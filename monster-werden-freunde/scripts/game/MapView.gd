class_name MapView
extends Node2D
## Statischer Hintergrund: Wiese, Deko (Bäume, Büsche, Blumen), Pfad und Dorf.

var path_points: PackedVector2Array
var spots: PackedVector2Array
var village_pos := Vector2.ZERO
var village: VillageView
var _decor: Array[Dictionary] = []
var _patches: Array[Dictionary] = []
var theme: StringName = &"meadow"
var _colors: Dictionary = {}


func setup(smooth_path: PackedVector2Array, spot_positions: PackedVector2Array, decor_seed: int,
		level_theme: StringName = &"meadow") -> void:
	theme = level_theme
	_colors = SceneryArt.colors(theme)
	if theme != &"meadow":
		var top := TopScenery.new()
		top.theme = theme
		add_child(top)
	path_points = smooth_path
	spots = spot_positions
	village_pos = path_points[path_points.size() - 1]
	_build_path_lines()
	village = VillageView.new()
	village.theme = theme
	village.position = village_pos
	add_child(village)
	_generate_decor(decor_seed)
	queue_redraw()


func _build_path_lines() -> void:
	var specs := [[118.0, _colors["path_border"]], [100.0, _colors["path"]], [44.0, _colors["path_mid"]]]
	for spec in specs:
		var line := Line2D.new()
		line.points = path_points
		line.width = spec[0]
		line.default_color = spec[1]
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		add_child(line)


func _distance_to_path(p: Vector2) -> float:
	var best := INF
	for i in range(0, path_points.size() - 1, 2):
		var j := mini(i + 2, path_points.size() - 1)
		var q := Geometry2D.get_closest_point_to_segment(p, path_points[i], path_points[j])
		best = minf(best, p.distance_to(q))
	return best


func _generate_decor(decor_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = decor_seed
	for i in 70:
		_patches.append({"p": Vector2(rng.randf_range(-900, 2800), rng.randf_range(-500, 1600)),
			"rx": rng.randf_range(60, 180), "ry": rng.randf_range(30, 80),
			"c": _colors["patch_a"] if rng.randf() < 0.5 else _colors["patch_b"]})
	var tries := 0
	while _decor.size() < 95 and tries < 900:
		tries += 1
		var p := Vector2(rng.randf_range(-900, 2800), rng.randf_range(-450, 1550))
		var roll := rng.randf()
		var kind := "flowers"
		var size := rng.randf_range(0.8, 1.25)
		var clearance := 70.0
		if roll < 0.28:
			kind = "tree"
			clearance = 120.0
		elif roll < 0.5:
			kind = "bush"
			clearance = 95.0
		elif roll < 0.58:
			kind = "rock"
			clearance = 80.0
		# Am Strand und im Schnee gibt es oben Meer bzw. Berge
		if theme != &"meadow" and p.y < 190.0:
			continue
		if _distance_to_path(p) < clearance:
			continue
		var near_spot := false
		for s in spots:
			if s.distance_to(p) < clearance + 30.0:
				near_spot = true
				break
		if near_spot or p.distance_to(village_pos + Vector2(110, 0)) < 300.0:
			continue
		# keine hohen Bäume unter der Leiste oben
		if kind == "tree" and p.y < 200.0 and p.x > -50.0 and p.x < 1970.0:
			continue
		_decor.append({"k": kind, "p": p, "s": size, "h": rng.randf(), "c": Color.from_hsv(rng.randf(), 0.55, 1.0)})
	_decor.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.p.y < b.p.y)


func _draw() -> void:
	draw_rect(Rect2(-2000, -1400, 6000, 4000), _colors.get("ground", Color("8fd16a")))
	for p in _patches:
		Icons.ellipse(self, p.p, p.rx, p.ry, p.c)
	for d in _decor:
		if theme == &"beach":
			match d.k:
				"tree": SceneryArt.palm(self, d.p, d.s, 0.0)
				"bush": SceneryArt.umbrella(self, d.p, d.s * 0.9, d.c)
				"rock": SceneryArt.sandcastle(self, d.p, d.s)
				_:
					SceneryArt.shell(self, d.p, d.s, d.c.lightened(0.3))
					SceneryArt.starfish(self, d.p + Vector2(26, 12), d.s * 0.8)
			continue
		if theme == &"snow":
			match d.k:
				"tree": SceneryArt.pine(self, d.p, d.s)
				"bush": SceneryArt.snow_pile(self, d.p, d.s)
				"rock": SceneryArt.snowy_rock(self, d.p, d.s)
				_: SceneryArt.ice_flowers(self, d.p, d.s)
			continue
		match d.k:
			"tree": _tree(d.p, d.s, d.h)
			"bush": _bush(d.p, d.s)
			"rock": _rock(d.p, d.s)
			_: _flowers(d.p, d.s, d.c)


func _tree(p: Vector2, s: float, h: float) -> void:
	Icons.ellipse(self, p + Vector2(0, 4), 46 * s, 14 * s, Color(0, 0, 0, 0.15))
	draw_rect(Rect2(p + Vector2(-9, -50) * s, Vector2(18, 52) * s), Color("8d5f3a"))
	var green: Color = Color("4fa64a") if h < 0.6 else Color("3f9a52")
	draw_circle(p + Vector2(-26, -66) * s, 34 * s, green.darkened(0.15))
	draw_circle(p + Vector2(26, -66) * s, 34 * s, green.darkened(0.15))
	draw_circle(p + Vector2(0, -92) * s, 40 * s, green)
	draw_circle(p + Vector2(-16, -70) * s, 30 * s, green)
	draw_circle(p + Vector2(18, -72) * s, 28 * s, green)
	draw_circle(p + Vector2(-12, -104) * s, 14 * s, green.lightened(0.25))
	if h > 0.75:
		for q in [Vector2(-20, -80), Vector2(14, -98), Vector2(22, -64)]:
			draw_circle(p + q * s, 6 * s, Color("ff6b6b"))


func _bush(p: Vector2, s: float) -> void:
	Icons.ellipse(self, p + Vector2(0, 4), 40 * s, 10 * s, Color(0, 0, 0, 0.13))
	var g := Color("5cb85a")
	draw_circle(p + Vector2(-20, -16) * s, 22 * s, g.darkened(0.1))
	draw_circle(p + Vector2(20, -16) * s, 22 * s, g.darkened(0.1))
	draw_circle(p + Vector2(0, -26) * s, 26 * s, g)
	draw_circle(p + Vector2(-8, -34) * s, 9 * s, g.lightened(0.25))


func _rock(p: Vector2, s: float) -> void:
	Icons.ellipse(self, p, 30 * s, 18 * s, Color("a9a9b3"))
	Icons.ellipse(self, p + Vector2(-6, -6) * s, 16 * s, 8 * s, Color("c8c8d0"))


func _flowers(p: Vector2, s: float, col: Color) -> void:
	for off in [Vector2(-14, 0), Vector2(12, -8), Vector2(2, 10)]:
		var c: Vector2 = p + off * s
		draw_line(c, c + Vector2(0, 12) * s, Color("3f8f3f"), 2.0)
		for i in 5:
			var a := TAU * i / 5.0
			draw_circle(c + Vector2(cos(a), sin(a)) * 5.0 * s, 4.0 * s, col)
		draw_circle(c, 3.0 * s, Color("ffd23f"))



class TopScenery extends Node2D:
	## Meer (Strand) bzw. Bergkette (Schnee) am oberen Bildrand.
	var theme: StringName = &"beach"
	var _t := 0.0

	func _process(delta: float) -> void:
		if theme == &"beach":
			_t += delta
			queue_redraw()

	func _draw() -> void:
		if theme == &"beach":
			SceneryArt.sea(self, -1500, 3500, 135, _t)
		else:
			SceneryArt.mountains(self, -1500, 3500, 150)

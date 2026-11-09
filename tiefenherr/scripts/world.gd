class_name World
extends Node3D
## Kachelkarte: Daten, Pfadfindung und Darstellung (MultiMesh, prozedurale Texturen, Licht).

const T = Defs.T
const R = Defs.R

var W := Defs.W
var H := Defs.H
var type := PackedInt32Array()
var own := PackedInt32Array()
var room := PackedInt32Array()
var dig_hp := PackedFloat32Array()
var marked := {}
var store := {}
var room_count := {R.TREASURY: 0, R.LAIR: 0, R.FARM: 0, R.TRAINING: 0}
var claimed_count := 0
var astar := AStarGrid2D.new()
var astar_h := AStarGrid2D.new()
var heart_tile := Vector2i(10, 10)
var gate_tile := Vector2i(46, 46)
var portals: Array = []
var dirty := true

var _mm := {}
var _deco := {}
var _torch := {}
var _flicker: Array = []
var _mark_mat: StandardMaterial3D
var _preview: MeshInstance3D
var _preview_mat: StandardMaterial3D
var _heart_node: Node3D
var _heart_orb: MeshInstance3D
var _heart_light: OmniLight3D
var _heart_flash := 0.0
var _time := 0.0
var _burst_mats := {}
var _burst_mesh: BoxMesh
var _spin_nodes: Array = []
var _deco_mats := {}


# ---------------------------------------------------------------- Hilfsfunktionen
func idx(t: Vector2i) -> int:
	return t.y * W + t.x

func to_t(i: int) -> Vector2i:
	return Vector2i(i % W, i / W)

func inb(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < W and t.y < H

func get_type(t: Vector2i) -> int:
	return type[idx(t)] if inb(t) else T.BEDROCK

func get_own(t: Vector2i) -> int:
	return own[idx(t)] if inb(t) else 0

func get_room(t: Vector2i) -> int:
	return room[idx(t)] if inb(t) else R.NONE

func is_walkable(t: Vector2i) -> bool:
	return inb(t) and type[idx(t)] == T.FLOOR

func is_own_floor(t: Vector2i) -> bool:
	return inb(t) and type[idx(t)] == T.FLOOR and own[idx(t)] == 1

func is_tall(t: Vector2i) -> bool:
	if not inb(t):
		return false
	var ty := type[idx(t)]
	return ty == T.ROCK or ty == T.GOLD or ty == T.GEM or ty == T.WALL or ty == T.BEDROCK

func is_player_diggable(t: Vector2i) -> bool:
	if not inb(t):
		return false
	var ty := type[idx(t)]
	return ty == T.ROCK or ty == T.GOLD or ty == T.GEM or (ty == T.WALL and own[idx(t)] == 1)

func hero_diggable(t: Vector2i) -> bool:
	if not inb(t):
		return false
	var ty := type[idx(t)]
	return ty == T.ROCK or ty == T.GOLD or ty == T.WALL

func tile_center(t: Vector2i) -> Vector3:
	return Vector3((t.x + 0.5) * Defs.TILE, 0.0, (t.y + 0.5) * Defs.TILE)

func pos_to_tile(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / Defs.TILE), floori(p.z / Defs.TILE))

func neighbors4(t: Vector2i) -> Array:
	return [t + Vector2i(1, 0), t + Vector2i(-1, 0), t + Vector2i(0, 1), t + Vector2i(0, -1)]

func _h(x: int, y: int, s: int = 0) -> int:
	var v := (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
	return absi(v)


# ---------------------------------------------------------------- Generierung
func generate(seed_val: int) -> void:
	var n := W * H
	type.resize(n)
	own.resize(n)
	room.resize(n)
	dig_hp.resize(n)
	var gold_n := FastNoiseLite.new()
	gold_n.seed = seed_val
	gold_n.frequency = 0.11
	var cave_n := FastNoiseLite.new()
	cave_n.seed = seed_val + 77
	cave_n.frequency = 0.075
	for y in H:
		for x in W:
			var i := y * W + x
			own[i] = 0
			room[i] = R.NONE
			var c := cave_n.get_noise_2d(x, y)
			if x < 1 or y < 1 or x >= W - 1 or y >= H - 1:
				type[i] = T.BEDROCK
			elif gold_n.get_noise_2d(x, y) > 0.45:
				type[i] = T.GOLD
			elif c > 0.52:
				type[i] = T.FLOOR
			elif c < -0.64:
				type[i] = T.BEDROCK
			else:
				type[i] = T.ROCK
	# Startbereich
	heart_tile = Vector2i(10, 10)
	_fill(Rect2i(4, 4, 13, 13), T.ROCK, 0)
	_fill(Rect2i(7, 7, 7, 7), T.FLOOR, 1)
	_fill(Rect2i(9, 9, 3, 3), T.HEART, 1)
	_fill(Rect2i(15, 8, 2, 3), T.GOLD, 0)
	_fill(Rect2i(8, 15, 3, 2), T.GOLD, 0)
	# Portale
	portals.clear()
	for pc in [Vector2i(24, 12), Vector2i(29, 31)]:
		_fill(Rect2i(pc.x - 3, pc.y - 3, 7, 7), T.ROCK, 0)
		_fill(Rect2i(pc.x - 2, pc.y - 2, 5, 5), T.FLOOR, 0)
		_fill(Rect2i(pc.x - 1, pc.y - 1, 3, 3), T.PORTAL, 0)
		portals.append({"center": pc, "claimed": false, "node": null})
	# Edelsteinader
	_fill(Rect2i(7, 22, 6, 5), T.ROCK, 0)
	_fill(Rect2i(9, 24, 2, 1), T.GEM, 0)
	# Heldentor
	gate_tile = Vector2i(W - 10, H - 10)
	_fill(Rect2i(gate_tile.x - 4, gate_tile.y - 4, 9, 9), T.FLOOR, 0)
	_fill(Rect2i(gate_tile.x - 1, gate_tile.y - 1, 3, 3), T.GATE, 2)
	# Rand erzwingen
	for y in H:
		for x in W:
			if x < 1 or y < 1 or x >= W - 1 or y >= H - 1:
				type[y * W + x] = T.BEDROCK
	for i in n:
		dig_hp[i] = Defs.tile_hp(type[i])
	claimed_count = 0
	for i in n:
		if own[i] == 1 and type[i] == T.FLOOR:
			claimed_count += 1
	# Pfadfindung
	for a in [astar, astar_h]:
		a.region = Rect2i(0, 0, W, H)
		a.cell_size = Vector2(1, 1)
		a.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar_h.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_h.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_h.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	astar_h.update()
	for y in H:
		for x in W:
			_update_astar(Vector2i(x, y))


func _fill(r: Rect2i, ty: int, ow: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * W + x
			type[i] = ty
			own[i] = ow
			room[i] = R.NONE


func _update_astar(t: Vector2i) -> void:
	var ty := type[idx(t)]
	astar.set_point_solid(t, ty != T.FLOOR)
	var solid_h := ty == T.BEDROCK or ty == T.GEM or ty == T.PORTAL or ty == T.HEART or ty == T.GATE
	astar_h.set_point_solid(t, solid_h)
	if not solid_h:
		var w := 1.0
		if ty == T.ROCK:
			w = 4.0
		elif ty == T.GOLD:
			w = 6.0
		elif ty == T.WALL:
			w = 11.0
		astar_h.set_point_weight_scale(t, w)


func find_path(from: Vector2i, to: Vector2i, hero := false) -> Array:
	var a: AStarGrid2D = astar_h if hero else astar
	if not inb(from) or not inb(to):
		return []
	if a.is_point_solid(to):
		return []
	var restore := false
	if a.is_point_solid(from):
		a.set_point_solid(from, false)
		restore = true
	var p := a.get_id_path(from, to)
	if restore:
		a.set_point_solid(from, true)
	return Array(p)


# ---------------------------------------------------------------- Änderungen
func set_tile(t: Vector2i, ty: int, ow: int) -> void:
	var i := idx(t)
	var was_claimed := type[i] == T.FLOOR and own[i] == 1
	if room[i] != R.NONE and ty != T.FLOOR:
		set_room(t, R.NONE)
	type[i] = ty
	own[i] = ow
	dig_hp[i] = Defs.tile_hp(ty)
	if ty != T.FLOOR and ty != T.ROCK and ty != T.GOLD and ty != T.GEM and ty != T.WALL:
		marked.erase(i)
	if ty == T.FLOOR:
		marked.erase(i)
	var now_claimed := ty == T.FLOOR and ow == 1
	if was_claimed != now_claimed:
		claimed_count += 1 if now_claimed else -1
	_update_astar(t)
	dirty = true
	_refresh_area(t)


func set_room(t: Vector2i, r: int) -> void:
	var i := idx(t)
	var old := room[i]
	if old == r:
		return
	if old != R.NONE:
		room_count[old] -= 1
	if r != R.NONE:
		room_count[r] += 1
	room[i] = r
	if old == R.TREASURY:
		store.erase(i)
	dirty = true
	_refresh_area(t)


func dig_hit(t: Vector2i, power: float) -> Dictionary:
	var i := idx(t)
	var ty := type[i]
	var gold := 0
	if ty == T.GOLD:
		gold = int(25.0 * power)
	elif ty == T.GEM:
		return {"gold": int(20.0 * power), "done": false}
	dig_hp[i] -= power
	if dig_hp[i] <= 0.0:
		set_tile(t, T.FLOOR, 0)
		return {"gold": gold, "done": true}
	return {"gold": gold, "done": false}


func hero_dig(t: Vector2i, amount: float) -> bool:
	var i := idx(t)
	dig_hp[i] -= amount
	if dig_hp[i] <= 0.0:
		set_tile(t, T.FLOOR, 0)
		return true
	return false


func toggle_marks(r: Rect2i, mark: bool) -> int:
	var c := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var t := Vector2i(x, y)
			if not is_player_diggable(t):
				continue
			var i := idx(t)
			if mark and not marked.has(i):
				marked[i] = true
				c += 1
			elif not mark and marked.has(i):
				marked.erase(i)
				c += 1
	if c > 0:
		dirty = true
	return c


func room_tiles(r: int) -> Array:
	var out := []
	for i in room.size():
		if room[i] == r and type[i] == T.FLOOR:
			out.append(to_t(i))
	return out


func heart_ring() -> Array:
	var out := []
	for y in range(-2, 3):
		for x in range(-2, 3):
			if absi(x) == 2 or absi(y) == 2:
				var t := heart_tile + Vector2i(x, y)
				if is_walkable(t):
					out.append(t)
	return out


func free_tile_near(c: Vector2i, maxr: int) -> Vector2i:
	for r in range(1, maxr + 1):
		var ring := []
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) == r and is_walkable(c + Vector2i(x, y)):
					ring.append(c + Vector2i(x, y))
		if not ring.is_empty():
			return ring.pick_random()
	return Vector2i(-1, -1)


func spread_tiles(c: Vector2i, n: int) -> Array:
	var out := []
	var seen := {c: true}
	var q := [c]
	while not q.is_empty() and out.size() < n:
		var t: Vector2i = q.pop_front()
		if is_walkable(t):
			out.append(t)
			for nb in neighbors4(t):
				if not seen.has(nb):
					seen[nb] = true
					q.append(nb)
	while out.size() < n and not out.is_empty():
		out.append(out[out.size() % maxi(1, out.size())])
	return out


# ---------------------------------------------------------------- Darstellung
func build_visuals() -> void:
	_burst_mesh = BoxMesh.new()
	_burst_mesh.size = Vector3(0.12, 0.12, 0.12)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(Defs.TILE, Defs.WALL_H, Defs.TILE)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(Defs.TILE, Defs.TILE)

	var rock := _tri_mat(_noise_tex(11, 0.012, [Color(0.17, 0.13, 0.11), Color(0.36, 0.29, 0.24), Color(0.48, 0.41, 0.35)]), _normal_tex(11, 0.012), 0.95)
	var gold := _tri_mat(_noise_tex(23, 0.03, [Color(0.22, 0.17, 0.12), Color(0.33, 0.26, 0.2), Color(0.33, 0.26, 0.2), Color(1.0, 0.78, 0.2)], [0.0, 0.5, 0.66, 0.74]), _normal_tex(23, 0.03), 0.5)
	gold.metallic = 0.35
	gold.emission_enabled = true
	gold.emission_texture = _noise_tex(23, 0.03, [Color.BLACK, Color.BLACK, Color(1.0, 0.7, 0.15)], [0.0, 0.68, 0.8])
	gold.emission_energy_multiplier = 1.4
	var gem := _tri_mat(_noise_tex(31, 0.04, [Color(0.05, 0.25, 0.35), Color(0.2, 0.9, 1.0)]), _normal_tex(31, 0.05), 0.15)
	gem.emission_enabled = true
	gem.emission = Color(0.2, 0.8, 1.0)
	gem.emission_energy_multiplier = 1.1
	gem.metallic = 0.4
	var bed := _tri_mat(_noise_tex(41, 0.02, [Color(0.04, 0.035, 0.04), Color(0.13, 0.11, 0.12)]), _normal_tex(41, 0.02), 1.0)
	var brick := StandardMaterial3D.new()
	var bt := _brick_textures()
	brick.albedo_texture = bt[0]
	brick.normal_enabled = true
	brick.normal_texture = bt[1]
	brick.normal_scale = 1.2
	brick.roughness = 0.85
	brick.uv1_triplanar = true
	brick.uv1_world_triplanar = true
	brick.uv1_scale = Vector3(0.5, 0.5, 0.5)

	var f_raw := _tri_mat(_noise_tex(51, 0.03, [Color(0.16, 0.12, 0.09), Color(0.3, 0.23, 0.17)]), _normal_tex(51, 0.03), 1.0)
	var f_claim := _tile_mat("claim", Color(0.33, 0.28, 0.27), Color(0.75, 0.08, 0.06))
	var f_treas := _tile_mat("treasury", Color(0.4, 0.33, 0.2), Color(1.0, 0.75, 0.2))
	var f_lair := _tile_mat("lair", Color(0.36, 0.27, 0.16), Color(0.55, 0.3, 0.15))
	var f_farm := _tile_mat("farm", Color(0.18, 0.24, 0.14), Color(0.25, 0.9, 0.7))
	var f_train := _tile_mat("training", Color(0.4, 0.27, 0.16), Color(0.85, 0.3, 0.2))

	_make_mm("rock", wall_mesh, rock, true)
	_make_mm("gold", wall_mesh, gold, true)
	_make_mm("gem", wall_mesh, gem, true)
	_make_mm("bedrock", wall_mesh, bed, true)
	_make_mm("wall", wall_mesh, brick, true)
	_make_mm("floor0", floor_mesh, f_raw, false)
	_make_mm("floor1", floor_mesh, f_claim, false)
	_make_mm("room%d" % R.TREASURY, floor_mesh, f_treas, false)
	_make_mm("room%d" % R.LAIR, floor_mesh, f_lair, false)
	_make_mm("room%d" % R.FARM, floor_mesh, f_farm, false)
	_make_mm("room%d" % R.TRAINING, floor_mesh, f_train, false)

	_mark_mat = StandardMaterial3D.new()
	_mark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.28)
	var mark_mesh := BoxMesh.new()
	mark_mesh.size = Vector3(Defs.TILE * 1.03, Defs.WALL_H + 0.06, Defs.TILE * 1.03)
	_make_mm("mark", mark_mesh, _mark_mat, false)

	_preview_mat = StandardMaterial3D.new()
	_preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_mat.no_depth_test = false
	_preview_mat.albedo_color = Color(1, 1, 1, 0.2)
	_preview = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3.ONE
	_preview.mesh = pm
	_preview.material_override = _preview_mat
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.visible = false
	add_child(_preview)

	_build_heart()
	for p in portals:
		p["node"] = _build_portal(tile_center(p["center"]), Color(0.65, 0.3, 1.0), false)
	_build_portal(tile_center(gate_tile), Color(0.75, 0.9, 1.0), true)
	for y in H:
		for x in W:
			_refresh_deco(Vector2i(x, y))
	_rebuild()


func _make_mm(key: String, mesh: Mesh, mat: Material, shadows: bool) -> void:
	var mmi := MultiMeshInstance3D.new()
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.mesh = mesh
	mmi.multimesh = m
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_mm[key] = mmi


func _noise_tex(s: int, freq: float, cols: Array, offs: Array = []) -> NoiseTexture2D:
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.seed = s
	fn.frequency = freq
	fn.fractal_octaves = 5
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nt.noise = fn
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	var g := Gradient.new()
	var o := PackedFloat32Array()
	var c := PackedColorArray()
	for k in cols.size():
		o.append(offs[k] if offs.size() == cols.size() else float(k) / maxf(1.0, cols.size() - 1))
		c.append(cols[k])
	g.offsets = o
	g.colors = c
	nt.color_ramp = g
	return nt


func _normal_tex(s: int, freq: float) -> NoiseTexture2D:
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.seed = s
	fn.frequency = freq * 1.6
	fn.fractal_octaves = 5
	nt.noise = fn
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 10.0
	return nt


func _tri_mat(alb: Texture2D, nrm: Texture2D, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = alb
	m.normal_enabled = true
	m.normal_texture = nrm
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.22, 0.22, 0.22)
	return m


func _brick_textures() -> Array:
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var bump := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var fn := FastNoiseLite.new()
	fn.frequency = 0.09
	for y in sz:
		var row := y / 32
		var off := 32 if row % 2 == 1 else 0
		for x in sz:
			var bx := (x + off) / 64
			var lx := (x + off) % 64
			var ly := y % 32
			var mortar := lx < 3 or ly < 3
			var n := fn.get_noise_2d(x, y) * 0.5 + 0.5
			var hv := float(_h(bx, row, 3) % 100) / 100.0
			var c: Color
			var hgt := 0.0
			if mortar:
				c = Color(0.1, 0.08, 0.08).lerp(Color(0.18, 0.15, 0.14), n)
				hgt = 0.1
			else:
				c = Color(0.32, 0.17, 0.15).lerp(Color(0.46, 0.33, 0.3), hv)
				c = c.darkened(0.25 * (1.0 - n))
				hgt = 0.7 + n * 0.3
			img.set_pixel(x, y, c)
			bump.set_pixel(x, y, Color(hgt, hgt, hgt))
	img.generate_mipmaps()
	bump.bump_map_to_normal_map(6.0)
	bump.generate_mipmaps()
	return [ImageTexture.create_from_image(img), ImageTexture.create_from_image(bump)]


func _tile_mat(kind: String, base: Color, accent: Color) -> StandardMaterial3D:
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var emi := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var fn := FastNoiseLite.new()
	fn.frequency = 0.06
	fn.seed = kind.hash()
	for y in sz:
		for x in sz:
			var n := fn.get_noise_2d(x, y) * 0.5 + 0.5
			var c := base.darkened(0.3 * (1.0 - n))
			var e := Color.BLACK
			var cx := x - 64
			var cy := y - 64
			var d := sqrt(float(cx * cx + cy * cy))
			match kind:
				"claim":
					var gx := x % 64
					var gy := y % 64
					if gx < 2 or gy < 2 or gx > 61 or gy > 61:
						c = c.darkened(0.6)
					var dm := absi(cx) + absi(cy)
					if dm > 14 and dm < 21:
						c = accent.darkened(0.25)
						e = accent * 0.3
					if x < 3 or y < 3 or x > sz - 4 or y > sz - 4:
						c = c.darkened(0.5)
				"treasury":
					if d > 30 and d < 36:
						c = accent.darkened(0.15)
						e = accent * 0.25
					if absi(cx) < 3 and absi(cy) < 18:
						c = accent
					if x < 4 or y < 4 or x > sz - 5 or y > sz - 5:
						c = accent.darkened(0.4)
				"lair":
					var straw := sin(float(x) * 0.6 + n * 9.0) * 0.5 + 0.5
					c = base.lerp(Color(0.62, 0.48, 0.25), straw * 0.55).darkened(0.2 * (1.0 - n))
				"farm":
					var moss := fn.get_noise_2d(x * 3, y * 3) * 0.5 + 0.5
					if moss > 0.62:
						c = Color(0.18, 0.4, 0.2).darkened(0.2 * (1.0 - n))
					if moss > 0.78:
						e = accent * 0.25
				"training":
					var plank := y % 32
					c = base.lerp(Color(0.52, 0.36, 0.2), (sin(float(x) * 0.15 + n * 6.0) * 0.5 + 0.5) * 0.5)
					if plank < 2:
						c = c.darkened(0.6)
					if (x + (y / 32) * 40) % 128 < 2:
						c = c.darkened(0.6)
			if kind != "claim" and (x < 2 or y < 2 or x > sz - 3 or y > sz - 3):
				c = c.darkened(0.45)
			img.set_pixel(x, y, c)
			emi.set_pixel(x, y, e)
	img.generate_mipmaps()
	emi.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.emission_enabled = true
	m.emission_texture = ImageTexture.create_from_image(emi)
	m.emission_energy_multiplier = 1.0
	m.roughness = 0.8
	m.normal_enabled = true
	m.normal_texture = _normal_tex(kind.hash(), 0.04)
	m.normal_scale = 0.5
	return m


func _rebuild() -> void:
	dirty = false
	var buckets := {}
	for k in _mm.keys():
		buckets[k] = []
	for y in H:
		for x in W:
			var i := y * W + x
			var ty := type[i]
			var c := Vector3((x + 0.5) * Defs.TILE, 0.0, (y + 0.5) * Defs.TILE)
			if ty == T.FLOOR or ty == T.HEART or ty == T.PORTAL or ty == T.GATE:
				var key := "floor0"
				if ty == T.FLOOR and room[i] != R.NONE:
					key = "room%d" % room[i]
				elif own[i] == 1:
					key = "floor1"
				buckets[key].append(Transform3D(Basis(), c))
			else:
				var hv := float(_h(x, y) % 1000) / 1000.0
				var sy := 1.0
				var key2 := "rock"
				match ty:
					T.ROCK:
						sy = 0.96 + hv * 0.14
					T.GOLD:
						key2 = "gold"
						sy = 0.98 + hv * 0.1
					T.GEM:
						key2 = "gem"
						sy = 1.05
					T.BEDROCK:
						key2 = "bedrock"
						sy = 1.08 + hv * 0.2
					T.WALL:
						key2 = "wall"
				var b := Basis.from_scale(Vector3(1.0, sy, 1.0))
				buckets[key2].append(Transform3D(b, c + Vector3(0, Defs.WALL_H * sy * 0.5, 0)))
			if marked.has(i):
				buckets["mark"].append(Transform3D(Basis(), c + Vector3(0, Defs.WALL_H * 0.5, 0)))
	for k in buckets.keys():
		var mm: MultiMesh = _mm[k].multimesh
		var arr: Array = buckets[k]
		mm.instance_count = arr.size()
		for j in arr.size():
			mm.set_instance_transform(j, arr[j])


func _process(delta: float) -> void:
	_time += delta
	if dirty:
		_rebuild()
	_mark_mat.albedo_color.a = 0.2 + 0.12 * sin(_time * 4.0)
	for f in _flicker:
		var l: OmniLight3D = f[0]
		if is_instance_valid(l):
			var ph: float = f[2]
			l.light_energy = f[1] * (0.82 + 0.1 * sin(_time * 11.0 + ph) + 0.08 * sin(_time * 23.7 + ph * 3.1))
	for s in _spin_nodes:
		if is_instance_valid(s[0]):
			s[0].rotate_y(delta * s[1])
	if _heart_orb:
		_heart_flash = maxf(0.0, _heart_flash - delta * 2.0)
		var beat := pow(maxf(0.0, sin(_time * 2.6)), 8.0)
		_heart_orb.scale = Vector3.ONE * (1.0 + beat * 0.12 + _heart_flash * 0.2)
		_heart_light.light_energy = 4.0 + beat * 3.0 + _heart_flash * 8.0


func set_preview(r: Rect2i, col: Color, tall: bool) -> void:
	if r.size == Vector2i.ZERO:
		_preview.visible = false
		return
	_preview.visible = true
	var h := Defs.WALL_H + 0.12 if tall else 0.14
	_preview.scale = Vector3(r.size.x * Defs.TILE + 0.04, h, r.size.y * Defs.TILE + 0.04)
	_preview.position = Vector3((r.position.x + r.size.x * 0.5) * Defs.TILE, h * 0.5, (r.position.y + r.size.y * 0.5) * Defs.TILE)
	_preview_mat.albedo_color = Color(col.r, col.g, col.b, 0.2 if tall else 0.16)


func heart_hit() -> void:
	_heart_flash = 1.0


# ---------------------------------------------------------------- Dekoration
func _refresh_area(t: Vector2i) -> void:
	_refresh_deco(t)
	for nb in neighbors4(t):
		if inb(nb):
			_refresh_deco(nb)


func refresh_tile(t: Vector2i) -> void:
	_refresh_deco(t)


func _dmat(key: String, c: Color, emit := 0.0, metal := 0.0, rough := 0.7) -> StandardMaterial3D:
	if _deco_mats.has(key):
		return _deco_mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_deco_mats[key] = m
	return m


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _refresh_deco(t: Vector2i) -> void:
	var i := idx(t)
	if _deco.has(i):
		_deco[i].queue_free()
		_deco.erase(i)
	if _torch.has(i):
		var tn: Node3D = _torch[i]
		for f in _flicker.duplicate():
			if f[3] == tn:
				_flicker.erase(f)
		tn.queue_free()
		_torch.erase(i)
	var ty := type[i]
	var c := tile_center(t)
	var hv := _h(t.x, t.y, 9)
	if ty == T.FLOOR and room[i] != R.NONE:
		var n := Node3D.new()
		n.position = c
		add_child(n)
		_deco[i] = n
		match room[i]:
			R.TREASURY:
				var g: int = store.get(i, 0)
				if g > 0:
					var f := clampf(float(g) / Defs.TREASURY_CAP, 0.15, 1.0)
					var cm := CylinderMesh.new()
					cm.top_radius = 0.08
					cm.bottom_radius = 0.75
					cm.height = 0.9
					cm.radial_segments = 10
					_add_mesh(n, cm, _dmat("goldpile", Color(1.0, 0.76, 0.2), 0.6, 0.9, 0.3), Vector3(0, 0.45 * f, 0), Vector3(0, hv * 0.01, 0), Vector3(f, f, f))
					var coin := CylinderMesh.new()
					coin.top_radius = 0.12
					coin.bottom_radius = 0.12
					coin.height = 0.03
					for k in 3:
						var a := float(hv % 360 + k * 120) * PI / 180.0
						_add_mesh(n, coin, _dmat("goldpile", Color(1.0, 0.76, 0.2), 0.6, 0.9, 0.3), Vector3(cos(a) * 0.75, 0.02, sin(a) * 0.75))
			R.LAIR:
				var tm := TorusMesh.new()
				tm.inner_radius = 0.35
				tm.outer_radius = 0.7
				_add_mesh(n, tm, _dmat("straw", Color(0.55, 0.42, 0.22), 0.0, 0.0, 1.0), Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
				var dm := CylinderMesh.new()
				dm.top_radius = 0.45
				dm.bottom_radius = 0.45
				dm.height = 0.04
				_add_mesh(n, dm, _dmat("fur", Color(0.22, 0.16, 0.12), 0.0, 0.0, 1.0), Vector3(0, 0.04, 0))
			R.FARM:
				for k in 3:
					var ox := float((hv >> (k * 3)) % 7) / 7.0 - 0.5
					var oz := float((hv >> (k * 3 + 9)) % 7) / 7.0 - 0.5
					var s := 0.6 + float((hv >> k) % 5) / 8.0
					var stem := CylinderMesh.new()
					stem.top_radius = 0.06
					stem.bottom_radius = 0.09
					stem.height = 0.5
					var p := Vector3(ox * 1.2, 0, oz * 1.2)
					_add_mesh(n, stem, _dmat("stem", Color(0.85, 0.85, 0.75), 0.2), p + Vector3(0, 0.25 * s, 0), Vector3.ZERO, Vector3.ONE * s)
					var cap := SphereMesh.new()
					cap.radius = 0.3
					cap.height = 0.3
					cap.is_hemisphere = true
					_add_mesh(n, cap, _dmat("cap", Color(0.1, 0.75, 0.6), 0.9), p + Vector3(0, 0.5 * s, 0), Vector3.ZERO, Vector3.ONE * s)
			R.TRAINING:
				if (t.x + t.y) % 2 == 0:
					var post := CylinderMesh.new()
					post.top_radius = 0.07
					post.bottom_radius = 0.09
					post.height = 1.4
					_add_mesh(n, post, _dmat("wood", Color(0.4, 0.26, 0.14), 0.0, 0.0, 0.9), Vector3(0, 0.7, 0))
					var bar := BoxMesh.new()
					bar.size = Vector3(0.9, 0.08, 0.08)
					_add_mesh(n, bar, _dmat("wood", Color(0.4, 0.26, 0.14), 0.0, 0.0, 0.9), Vector3(0, 1.05, 0))
					var body := CapsuleMesh.new()
					body.radius = 0.2
					body.height = 0.7
					_add_mesh(n, body, _dmat("sack", Color(0.6, 0.5, 0.3), 0.0, 0.0, 1.0), Vector3(0, 0.95, 0))
					var head := SphereMesh.new()
					head.radius = 0.15
					head.height = 0.3
					_add_mesh(n, head, _dmat("sack", Color(0.6, 0.5, 0.3), 0.0, 0.0, 1.0), Vector3(0, 1.45, 0))
				else:
					var rack := BoxMesh.new()
					rack.size = Vector3(0.6, 0.06, 0.6)
					_add_mesh(n, rack, _dmat("wood", Color(0.4, 0.26, 0.14), 0.0, 0.0, 0.9), Vector3(0, 0.03, 0))
	elif ty == T.WALL and own[i] == 1 and hv % 3 == 0:
		for nb in neighbors4(t):
			if is_own_floor(nb):
				_add_torch(i, c, tile_center(nb))
				break


func _add_torch(i: int, wall_c: Vector3, floor_c: Vector3) -> void:
	var dir := (floor_c - wall_c).normalized()
	var n := Node3D.new()
	n.position = wall_c + dir * (Defs.TILE * 0.5 + 0.08) + Vector3(0, 1.6, 0)
	add_child(n)
	_torch[i] = n
	var holder := BoxMesh.new()
	holder.size = Vector3(0.1, 0.35, 0.1)
	_add_mesh(n, holder, _dmat("iron", Color(0.15, 0.13, 0.12), 0.0, 0.8, 0.5), Vector3.ZERO, Vector3(dir.z * 0.4, 0, -dir.x * 0.4))
	var flame := SphereMesh.new()
	flame.radius = 0.11
	flame.height = 0.3
	_add_mesh(n, flame, _dmat("flame", Color(1.0, 0.55, 0.15), 6.0), Vector3(0, 0.25, 0) + dir * 0.06)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.omni_range = 7.5
	l.omni_attenuation = 1.4
	l.light_energy = 1.6
	l.position = Vector3(0, 0.3, 0) + dir * 0.4
	l.shadow_enabled = false
	n.add_child(l)
	_flicker.append([l, 1.6, float(i % 97), n])


func _build_heart() -> void:
	var n := Node3D.new()
	n.position = tile_center(heart_tile)
	add_child(n)
	_heart_node = n
	var base := CylinderMesh.new()
	base.top_radius = 2.3
	base.bottom_radius = 2.8
	base.height = 0.5
	_add_mesh(n, base, _dmat("hbase", Color(0.2, 0.15, 0.15), 0.0, 0.2, 0.8), Vector3(0, 0.25, 0))
	for k in 4:
		var a := k * PI * 0.5 + PI * 0.25
		var pil := CylinderMesh.new()
		pil.top_radius = 0.12
		pil.bottom_radius = 0.3
		pil.height = 3.4
		_add_mesh(n, pil, _dmat("hpil", Color(0.25, 0.12, 0.12), 0.0, 0.3, 0.6), Vector3(cos(a) * 2.2, 1.7, sin(a) * 2.2), Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25))
		var tip := SphereMesh.new()
		tip.radius = 0.14
		tip.height = 0.28
		_add_mesh(n, tip, _dmat("htip", Color(1.0, 0.2, 0.1), 5.0), Vector3(cos(a) * 1.8, 3.4, sin(a) * 1.8))
	var orb := SphereMesh.new()
	orb.radius = 1.0
	orb.height = 2.0
	var om := StandardMaterial3D.new()
	om.albedo_color = Color(0.6, 0.02, 0.03)
	om.emission_enabled = true
	om.emission = Color(1.0, 0.1, 0.08)
	om.emission_energy_multiplier = 3.0
	om.roughness = 0.2
	om.metallic = 0.3
	om.rim_enabled = true
	om.rim = 0.8
	_heart_orb = _add_mesh(n, orb, om, Vector3(0, 2.2, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = 1.35
	ring.outer_radius = 1.48
	var r1 := _add_mesh(n, ring, _dmat("hring", Color(1.0, 0.65, 0.3), 2.0, 0.9, 0.2), Vector3(0, 2.2, 0), Vector3(0.5, 0, 0))
	var ring_p := Node3D.new()
	ring_p.position = Vector3(0, 2.2, 0)
	n.add_child(ring_p)
	r1.reparent(ring_p)
	r1.position = Vector3.ZERO
	_spin_nodes.append([ring_p, 0.8])
	_heart_light = OmniLight3D.new()
	_heart_light.light_color = Color(1.0, 0.25, 0.15)
	_heart_light.omni_range = 18.0
	_heart_light.light_energy = 4.0
	_heart_light.shadow_enabled = true
	_heart_light.position = Vector3(0, 3.6, 0)
	n.add_child(_heart_light)
	var pt := CPUParticles3D.new()
	pt.amount = 40
	pt.lifetime = 2.6
	pt.mesh = _burst_mesh
	pt.material_override = _dmat("ember", Color(1.0, 0.4, 0.1), 6.0)
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pt.emission_sphere_radius = 1.3
	pt.direction = Vector3.UP
	pt.spread = 25.0
	pt.gravity = Vector3(0, 0.6, 0)
	pt.initial_velocity_min = 0.4
	pt.initial_velocity_max = 1.2
	pt.scale_amount_min = 0.3
	pt.scale_amount_max = 0.8
	pt.position = Vector3(0, 2.2, 0)
	n.add_child(pt)


func _build_portal(c: Vector3, col: Color, is_gate: bool) -> Node3D:
	var n := Node3D.new()
	n.position = c
	add_child(n)
	var stone := _dmat("pstone" + str(is_gate), Color(0.32, 0.3, 0.34) if is_gate else Color(0.22, 0.18, 0.24), 0.0, 0.1, 0.8)
	for k in 4:
		var a := k * PI * 0.5 + PI * 0.25
		var ob := PrismMesh.new()
		ob.size = Vector3(0.7, 3.2, 0.7)
		_add_mesh(n, ob, stone, Vector3(cos(a) * 2.5, 1.6, sin(a) * 2.5))
		var gem := SphereMesh.new()
		gem.radius = 0.16
		gem.height = 0.32
		_add_mesh(n, gem, _dmat("pgem" + col.to_html(), col, 4.0), Vector3(cos(a) * 2.5, 3.3, sin(a) * 2.5))
	var disc := CylinderMesh.new()
	disc.top_radius = 2.2
	disc.bottom_radius = 2.2
	disc.height = 0.06
	var dm := StandardMaterial3D.new()
	var nt := _noise_tex(5 if is_gate else 9, 0.02, [Color.BLACK, col * 0.5, col], [0.0, 0.55, 1.0])
	dm.albedo_texture = nt
	dm.emission_enabled = true
	dm.emission_texture = nt
	dm.emission_energy_multiplier = 2.5 if is_gate else 0.6
	var dmi := _add_mesh(n, disc, dm, Vector3(0, 0.05, 0))
	_spin_nodes.append([dmi, 0.7 if is_gate else -0.9])
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = 11.0
	l.light_energy = 3.0 if is_gate else 0.8
	l.position = Vector3(0, 2.2, 0)
	n.add_child(l)
	n.set_meta("light", l)
	n.set_meta("disc_mat", dm)
	var pt := CPUParticles3D.new()
	pt.amount = 30
	pt.lifetime = 2.0
	pt.mesh = _burst_mesh
	pt.material_override = _dmat("pp" + col.to_html(), col, 5.0)
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	pt.emission_ring_axis = Vector3.UP
	pt.emission_ring_radius = 2.0
	pt.emission_ring_inner_radius = 0.5
	pt.emission_ring_height = 0.1
	pt.direction = Vector3.UP
	pt.spread = 10.0
	pt.gravity = Vector3.ZERO
	pt.initial_velocity_min = 0.8
	pt.initial_velocity_max = 1.6
	pt.scale_amount_min = 0.3
	pt.scale_amount_max = 0.6
	pt.emitting = is_gate
	n.add_child(pt)
	n.set_meta("particles", pt)
	return n


func activate_portal(p: Dictionary) -> void:
	var n: Node3D = p["node"]
	p["claimed"] = true
	var l: OmniLight3D = n.get_meta("light")
	l.light_energy = 3.5
	var dm: StandardMaterial3D = n.get_meta("disc_mat")
	dm.emission_energy_multiplier = 2.6
	n.get_meta("particles").emitting = true
	var pi := pos_to_tile(n.position)
	for y in range(-1, 2):
		for x in range(-1, 2):
			own[idx(pi + Vector2i(x, y))] = 1
	dirty = true


# ---------------------------------------------------------------- Effekte
func burst(pos: Vector3, col: Color, amount := 14, speed := 3.0, life := 0.7) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.mesh = _burst_mesh
	var key := col.to_html()
	if not _burst_mats.has(key):
		_burst_mats[key] = _dmat("b" + key, col, 3.0)
	p.material_override = _burst_mats[key]
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.4, false).timeout.connect(p.queue_free)


func lightning(pos: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_position = pos
	var mat := _dmat("bolt", Color(0.7, 0.85, 1.0), 12.0)
	var p := Vector3(0, 0, 0)
	var segs := 9
	for k in segs:
		var nxt := Vector3(randf_range(-0.7, 0.7), float(k + 1) * 2.2, randf_range(-0.7, 0.7))
		var mid := (p + nxt) * 0.5
		var seg_len := p.distance_to(nxt)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, seg_len, 0.12)
		var mi := _add_mesh(n, bm, mat, mid)
		var up := (nxt - p).normalized()
		var axis := Vector3.UP.cross(up)
		if axis.length() > 0.001:
			mi.basis = Basis(axis.normalized(), Vector3.UP.angle_to(up))
		p = nxt
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.75, 1.0)
	l.light_energy = 14.0
	l.omni_range = 16.0
	l.position = Vector3(0, 2, 0)
	n.add_child(l)
	burst(pos + Vector3(0, 0.3, 0), Color(0.7, 0.85, 1.0), 40, 7.0, 0.8)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.45)
	tw.tween_callback(n.queue_free)

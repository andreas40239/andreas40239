class_name ApartmentBuilder
extends RefCounted
## Baut aus dem Grundriss (ApartmentGen) die 3D-Szene: Böden, Wände, Fenster, Tür,
## Möbel, Lichter, Kollision und Versteck-Knoten. Alles aus Quadern, pro Raum zu
## wenigen Meshes zusammengefasst.

const T := 0.16          # Wandstärke
const TALL := 2.5        # hintere Außenwände
const LOW := 0.85        # alle anderen Wände (Schnittansicht)

var apt: ApartmentGen
var root: Node3D
var spots: Array[HidingSpot] = []
var windows: Array[Dictionary] = []   # zu apt.openings parallele Infos: {glass, pos, opening, door}
var lights: Array[Dictionary] = []    # {light: OmniLight3D, base: float, mode: String}
var _batches := {}                    # room id -> MeshBatch
var _mats := {}
var _body: StaticBody3D
var _rng := RandomNumberGenerator.new()


func build(p_apt: ApartmentGen) -> Node3D:
	apt = p_apt
	_rng.seed = apt.seed_used + 1234
	root = Node3D.new()
	root.name = "Apartment"
	_body = StaticBody3D.new()
	_body.name = "WorldBody"
	_body.collision_layer = Cfg.LAYER_WORLD
	_body.collision_mask = 0
	root.add_child(_body)
	_build_ground()
	_build_floors()
	_build_walls()
	_build_wall_collision()
	for f in apt.furniture:
		_build_furniture(f)
	_build_room_lights()
	for id in _batches:
		var mi: MeshInstance3D = _batches[id].build("Room%d" % id)
		root.add_child(mi)
	return root


# ------------------------------------------------------------------ Materialien

func mat(key: String, color: Color, tex := "", rough := 0.9) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic_specular = 0.25
	if tex != "":
		var path := "res://assets/textures/%s.png" % tex
		if ResourceLoader.exists(path):
			m.albedo_texture = load(path)
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats[key] = m
	return m


func emissive(key: String, color: Color, energy := 1.5) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


func glass_mat() -> StandardMaterial3D:
	if _mats.has("glass"):
		return _mats["glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.65, 0.9, 0.3)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.emission_enabled = true
	m.emission = Color(0.2, 0.3, 0.55)
	m.emission_energy_multiplier = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["glass"] = m
	return m


func _floor_mat(type: int) -> StandardMaterial3D:
	match type:
		ApartmentGen.RoomType.BATH: return mat("fl_bath", Color(0.95, 0.98, 1.0), "floor_bath", 0.5)
		ApartmentGen.RoomType.KITCHEN: return mat("fl_kitchen", Color(1, 1, 1), "floor_kitchen", 0.6)
		ApartmentGen.RoomType.HALL: return mat("fl_hall", Color(1, 1, 1), "floor_hall", 0.6)
		ApartmentGen.RoomType.CLASSROOM: return mat("fl_class", Color(0.72, 0.86, 0.74), "floor_hall", 0.6)
		ApartmentGen.RoomType.STORAGE: return mat("fl_store", Color(0.6, 0.6, 0.64), "floor_hall", 0.7)
		_: return mat("fl_wood", Color(1, 1, 1), "floor_wood", 0.8)


func _wall_mat(type: int) -> StandardMaterial3D:
	match type:
		ApartmentGen.RoomType.BATH: return mat("w_bath", Color(0.62, 0.8, 0.84), "wall_plaster")
		ApartmentGen.RoomType.KITCHEN: return mat("w_kitchen", Color(0.92, 0.82, 0.55), "wall_plaster")
		ApartmentGen.RoomType.BEDROOM: return mat("w_bed", Color(0.8, 0.66, 0.66), "wall_plaster")
		ApartmentGen.RoomType.LIVING: return mat("w_living", Color(0.66, 0.76, 0.64), "wall_plaster")
		ApartmentGen.RoomType.OFFICE: return mat("w_office", Color(0.66, 0.7, 0.82), "wall_plaster")
		ApartmentGen.RoomType.DINING: return mat("w_dining", Color(0.78, 0.86, 0.95), "wall_plaster")
		ApartmentGen.RoomType.CLASSROOM: return mat("w_class", Color(0.92, 0.86, 0.6), "wall_plaster")
		ApartmentGen.RoomType.STORAGE: return mat("w_store", Color(0.62, 0.62, 0.64), "wall_plaster")
		_: return mat("w_hall", Color(0.88, 0.84, 0.74), "wall_plaster")


func _batch(room_id: int) -> MeshBatch:
	if not _batches.has(room_id):
		_batches[room_id] = MeshBatch.new()
	return _batches[room_id]


# ------------------------------------------------------------------ Boden & Wände

func _build_ground() -> void:
	var b := _batch(-1)
	b.add_box(mat("ground", Color(0.035, 0.04, 0.05)), Vector3(apt.w * 0.5, -0.2, apt.h * 0.5), Vector3(90, 0.2, 90))
	# Gehweg rund ums Haus
	b.add_box(mat("pavement", Color(0.09, 0.09, 0.1)), Vector3(apt.w * 0.5, -0.09, apt.h * 0.5),
		Vector3(apt.w + 3.0, 0.06, apt.h + 3.0))


func _build_floors() -> void:
	for r in apt.rooms:
		var rc: Rect2i = r.rect
		_batch(r.id).add_box(_floor_mat(r.type),
			Vector3(rc.position.x + rc.size.x * 0.5, -0.05, rc.position.y + rc.size.y * 0.5),
			Vector3(rc.size.x, 0.1, rc.size.y))


func _build_walls() -> void:
	var cap := mat("wall_cap", Color(0.06, 0.06, 0.08))
	for y in range(0, apt.h + 1):
		for x in apt.w:
			var e := apt.get_h(x, y)
			if e == ApartmentGen.Edge.NONE:
				continue
			var rid := apt.room_at(x, y) if y < apt.h else apt.room_at(x, y - 1)
			_wall_piece(e, rid, Vector3(x + 0.5, 0, y), true, y == 0, Vector2i(x, y))
	for y in apt.h:
		for x in range(0, apt.w + 1):
			var e := apt.get_v(x, y)
			if e == ApartmentGen.Edge.NONE:
				continue
			var rid := apt.room_at(x, y) if x < apt.w else apt.room_at(x - 1, y)
			_wall_piece(e, rid, Vector3(x, 0, y + 0.5), false, x == 0, Vector2i(x, y))
	# Eckpfosten der hinteren Wände sauber schließen
	_batch(0).add_box(cap, Vector3(0, TALL + 0.015, 0), Vector3(T + 0.02, 0.03, T + 0.02))


func _wall_piece(e: int, rid: int, c: Vector3, horizontal: bool, is_tall: bool, ec: Vector2i) -> void:
	var b := _batch(rid)
	var wm := _wall_mat(apt.rooms[rid].type)
	var cap := mat("wall_cap", Color(0.06, 0.06, 0.08))
	var hgt := TALL if is_tall else LOW
	var yaw := 0.0 if horizontal else PI * 0.5
	var full := Vector3(1.0 + T, hgt, T)
	match e:
		ApartmentGen.Edge.WALL:
			b.add_box(wm, c + Vector3(0, hgt * 0.5, 0), full, yaw)
			b.add_box(cap, c + Vector3(0, hgt + 0.015, 0), Vector3(1.0 + T, 0.03, T + 0.02), yaw)
		ApartmentGen.Edge.DOOR:
			b.add_box(mat("threshold", Color(0.25, 0.17, 0.1)), c + Vector3(0, 0.006, 0), Vector3(1.0 - T, 0.012, T), yaw)
		ApartmentGen.Edge.WINDOW:
			var sill := 0.9 if is_tall else 0.45
			var top := 2.0 if is_tall else LOW + 0.25
			b.add_box(wm, c + Vector3(0, sill * 0.5, 0), Vector3(1.0 + T, sill, T), yaw)
			if is_tall:
				b.add_box(wm, c + Vector3(0, (top + hgt) * 0.5, 0), Vector3(1.0 + T, hgt - top, T), yaw)
				b.add_box(cap, c + Vector3(0, hgt + 0.015, 0), Vector3(1.0 + T, 0.03, T + 0.02), yaw)
			var fm := mat("frame", Color(0.9, 0.9, 0.86))
			var basis := Basis(Vector3.UP, yaw)
			var mid := (sill + top) * 0.5
			var wh := top - sill
			for sx in [-0.47, 0.47]:
				b.add_box(fm, c + basis * Vector3(sx, mid, 0), Vector3(0.06, wh, T + 0.04), yaw)
			b.add_box(fm, c + Vector3(0, sill + 0.03, 0), Vector3(1.0, 0.06, T + 0.08), yaw)
			b.add_box(fm, c + Vector3(0, top - 0.03, 0), Vector3(1.0, 0.06, T + 0.04), yaw)
			# Glasscheibe als eigener Knoten (wird beim Einbruch zerstört)
			var glass := MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(0.9, wh - 0.1, 0.03)
			glass.mesh = gm
			glass.material_override = glass_mat()
			glass.position = c + Vector3(0, mid, 0)
			glass.rotation.y = yaw
			root.add_child(glass)
			var cross := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(0.04, wh - 0.1, 0.05)
			cross.mesh = cm
			cross.material_override = fm
			glass.add_child(cross)
			windows.append({"glass": glass, "pos": c + Vector3(0, mid, 0), "sill": sill,
				"opening": _find_opening("window", horizontal, ec), "door": null})
		ApartmentGen.Edge.ENTRANCE:
			b.add_box(wm, c + Vector3(0, (2.1 + hgt) * 0.5, 0), Vector3(1.0 + T, hgt - 2.1, T), yaw)
			b.add_box(cap, c + Vector3(0, hgt + 0.015, 0), Vector3(1.0 + T, 0.03, T + 0.02), yaw)
			var fm := mat("doorframe", Color(0.2, 0.14, 0.1))
			var basis := Basis(Vector3.UP, yaw)
			for sx in [-0.47, 0.47]:
				b.add_box(fm, c + basis * Vector3(sx, 1.05, 0), Vector3(0.06, 2.1, T + 0.04), yaw)
			# Türblatt mit Scharnier
			var hinge := Node3D.new()
			hinge.position = c + basis * Vector3(0.44, 0, 0)
			hinge.rotation.y = yaw
			root.add_child(hinge)
			var leaf := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.88, 2.05, 0.07)
			leaf.mesh = lm
			leaf.material_override = mat("door", Color(0.16, 0.3, 0.24), "wood_furniture")
			leaf.position = Vector3(-0.44, 1.03, 0)
			hinge.add_child(leaf)
			var knob := MeshInstance3D.new()
			var km := BoxMesh.new()
			km.size = Vector3(0.08, 0.08, 0.16)
			knob.mesh = km
			knob.material_override = mat("brass", Color(0.8, 0.65, 0.25), "", 0.3)
			knob.position = Vector3(-0.76, 1.0, 0)
			hinge.add_child(knob)
			windows.append({"glass": null, "pos": c + Vector3(0, 1.0, 0), "sill": 0.0,
				"opening": _find_opening("entrance", horizontal, ec), "door": hinge})


func _find_opening(kind: String, horizontal: bool, ec: Vector2i) -> Dictionary:
	for o in apt.openings:
		if o.kind == kind and o.horizontal == horizontal and o.x == ec.x and o.y == ec.y:
			return o
	return {}


func _build_wall_collision() -> void:
	# durchgehende Wandstücke zu langen Boxen zusammenfassen
	for y in range(0, apt.h + 1):
		var x := 0
		while x < apt.w:
			if _solid(apt.get_h(x, y)):
				var x1 := x
				while x1 < apt.w and _solid(apt.get_h(x1, y)):
					x1 += 1
				_add_col(Vector3((x + x1) * 0.5, 1.25, y), Vector3(x1 - x + T, 2.5, T))
				x = x1
			else:
				x += 1
	for x in range(0, apt.w + 1):
		var y := 0
		while y < apt.h:
			if _solid(apt.get_v(x, y)):
				var y1 := y
				while y1 < apt.h and _solid(apt.get_v(x, y1)):
					y1 += 1
				_add_col(Vector3(x, 1.25, (y + y1) * 0.5), Vector3(T, 2.5, y1 - y + T))
				y = y1
			else:
				y += 1


func _solid(e: int) -> bool:
	return e == ApartmentGen.Edge.WALL or e == ApartmentGen.Edge.WINDOW or e == ApartmentGen.Edge.ENTRANCE


func _add_col(c: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = c
	_body.add_child(cs)


# ------------------------------------------------------------------ Lichter

func _add_light(pos: Vector3, color: Color, energy: float, rng_m: float, mode := "none") -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	root.add_child(l)
	lights.append({"light": l, "base": energy, "mode": mode})
	return l


func _build_room_lights() -> void:
	for r in apt.rooms:
		var rc: Rect2i = r.rect
		var c := Vector3(rc.position.x + rc.size.x * 0.5, 2.3, rc.position.y + rc.size.y * 0.5)
		var rad := maxf(rc.size.x, rc.size.y) * 0.75 + 1.5
		match r.type:
			ApartmentGen.RoomType.BATH:
				_add_light(c, Color(0.7, 0.95, 1.0), 0.6, rad, "fluoro")
			ApartmentGen.RoomType.KITCHEN:
				_add_light(c, Color(1.0, 0.95, 0.75), 1.2, rad, "fluoro")
			ApartmentGen.RoomType.BEDROOM:
				_add_light(c, Color(1.0, 0.7, 0.5), 0.75, rad)
			ApartmentGen.RoomType.LIVING:
				_add_light(c, Color(1.0, 0.8, 0.55), 0.8, rad)
			ApartmentGen.RoomType.OFFICE:
				_add_light(c, Color(0.75, 0.8, 1.0), 0.7, rad)
			ApartmentGen.RoomType.DINING:
				_add_light(c, Color(1.0, 0.85, 0.6), 1.0, rad)
			ApartmentGen.RoomType.CLASSROOM:
				_add_light(c, Color(0.9, 0.97, 1.0), 1.0, rad, "fluoro")
			ApartmentGen.RoomType.STORAGE:
				_add_light(c, Color(1.0, 0.8, 0.5), 0.55, rad, "flicker")
			ApartmentGen.RoomType.HALL:
				# Lampen entlang der langen Achse, etwa alle 9 m
				var horiz := rc.size.x >= rc.size.y
				var n := maxi(1, roundi(maxf(rc.size.x, rc.size.y) / 9.0))
				for i in n:
					var t := (i + 0.5) / n
					var lp := Vector3(rc.position.x + rc.size.x * (t if horiz else 0.5), 2.3,
						rc.position.y + rc.size.y * (0.5 if horiz else t))
					_add_light(lp, Color(1.0, 0.75, 0.45), 0.9, 7.5, "flicker" if i % 2 == 1 else "none")


# ------------------------------------------------------------------ Möbel

func _build_furniture(f: Dictionary) -> void:
	var rc: Rect2i = f.rect
	var c := Vector3(rc.position.x + rc.size.x * 0.5, 0, rc.position.y + rc.size.y * 0.5)
	var yaw: float = [0.0, -PI * 0.5, PI, PI * 0.5][f.dir]
	var b := _batch(f.room)
	var def: Dictionary = ApartmentGen.FURN[f.kind]
	var L: float = def.l
	var D: float = def.d
	var wood := mat("wood", Color(0.75, 0.6, 0.45), "wood_furniture")
	var wood_dark := mat("wood_dark", Color(0.42, 0.3, 0.22), "wood_furniture")
	var white := mat("white", Color(0.92, 0.93, 0.95), "", 0.4)
	var metal := mat("metal", Color(0.6, 0.63, 0.68), "", 0.35)
	var black := mat("black", Color(0.07, 0.07, 0.09), "", 0.5)
	var lb := func(m: Material, lc: Vector3, size: Vector3) -> void:
		b.add_box(m, c + Basis(Vector3.UP, yaw) * lc, size, yaw)
	var spot: HidingSpot = null
	if f.hide > 0:
		spot = HidingSpot.new()
		spot.kind = f.kind
		spot.capacity = f.hide
		spot.yaw = yaw
		spot.rect = rc
		spot.position = c
		for a in f.access:
			spot.access.append(Nav.center(a))
		root.add_child(spot)
		spots.append(spot)
	var col_h := 1.0
	match f.kind:
		"bed":
			for sx in [-0.82, 0.82]:
				for sz in [-0.88, 0.88]:
					lb.call(wood_dark, Vector3(sx, 0.2, sz), Vector3(0.1, 0.4, 0.1))
			lb.call(wood_dark, Vector3(0, 0.47, 0), Vector3(1.8, 0.14, 1.9))
			lb.call(white, Vector3(0, 0.63, 0.02), Vector3(1.7, 0.18, 1.8))
			lb.call(mat("blanket", Color(1, 1, 1), "fabric_bed"), Vector3(0, 0.74, 0.32), Vector3(1.74, 0.06, 1.2))
			# Decke hängt vorn und seitlich herunter
			lb.call(mat("blanket", Color(1, 1, 1), "fabric_bed"), Vector3(0, 0.56, 0.93), Vector3(1.74, 0.4, 0.04))
			for sx in [-0.45, 0.45]:
				lb.call(white, Vector3(sx, 0.77, -0.62), Vector3(0.62, 0.1, 0.36))
			lb.call(wood_dark, Vector3(0, 0.65, -0.95), Vector3(1.84, 1.1, 0.08))
			_add_eyes(spot, Vector3(0.0, 0.2, 0.96))
			col_h = 0.8
		"wardrobe", "cabinet":
			var ww := L - 0.14
			var hh := 1.85
			lb.call(wood, Vector3(0, hh * 0.5, -0.12), Vector3(ww, hh, 0.66))
			lb.call(wood_dark, Vector3(0, hh + 0.03, -0.12), Vector3(ww + 0.06, 0.06, 0.7))
			lb.call(wood_dark, Vector3(0, 0.04, -0.1), Vector3(ww + 0.02, 0.08, 0.7))
			# Türen als eigene Knoten (wackeln beim Verstecken)
			var n_doors := 2 if f.kind == "wardrobe" else 1
			var dw := (ww - 0.06) / n_doors
			for i in n_doors:
				var side := -1.0 if i == 0 else 1.0
				var hinge := Node3D.new()
				var hx := side * (ww * 0.5 - 0.03) if n_doors == 2 else -(ww * 0.5 - 0.03)
				hinge.position = Vector3(hx, 0.95, 0.225)
				spot.add_child(hinge)
				var leaf := MeshInstance3D.new()
				var lm := BoxMesh.new()
				lm.size = Vector3(dw - 0.03, 1.66, 0.04)
				leaf.mesh = lm
				leaf.material_override = wood_dark
				leaf.position = Vector3((-side if n_doors == 2 else 1.0) * dw * 0.5, 0, 0)
				hinge.add_child(leaf)
				var knob := MeshInstance3D.new()
				var km := BoxMesh.new()
				km.size = Vector3(0.04, 0.16, 0.05)
				knob.mesh = km
				knob.material_override = mat("brass", Color(0.8, 0.65, 0.25), "", 0.3)
				knob.position = Vector3((-side if n_doors == 2 else 1.0) * (dw - 0.1), 0, 0.04)
				hinge.add_child(knob)
				spot.doors.append(hinge)
			spot.rotation.y = yaw
			_add_eyes(spot, Vector3(0.0, 1.45, 0.25), false)
			col_h = 2.0
		"table":
			for sx in [-0.78, 0.78]:
				for sz in [-0.36, 0.36]:
					lb.call(wood_dark, Vector3(sx, 0.38, sz), Vector3(0.08, 0.76, 0.08))
			lb.call(wood, Vector3(0, 0.79, 0), Vector3(1.76, 0.06, 0.9))
			# lange Tischdecke (blau-weiß) – darunter kann man sich verstecken
			var school := apt.theme == "school"
			# lange Tischdecke (in der Schule: Pultverkleidung) – darunter kann man sich verstecken
			var cloth := mat("desk_side", Color(0.45, 0.5, 0.42)) if school else mat("cloth", Color(0.93, 0.9, 0.8))
			if not school:
				lb.call(mat("cloth_red", Color(0.7, 0.14, 0.12)), Vector3(0, 0.845, 0), Vector3(1.82, 0.012, 0.36))
				lb.call(mat("cloth_red", Color(0.7, 0.14, 0.12)), Vector3(0, 0.42, 0.482), Vector3(1.8, 0.1, 0.012))
				lb.call(cloth, Vector3(0, 0.83, 0), Vector3(1.8, 0.02, 0.94))
			lb.call(cloth, Vector3(0, 0.6, 0.47), Vector3(1.8, 0.46, 0.02))
			lb.call(cloth, Vector3(0, 0.6, -0.47), Vector3(1.8, 0.46, 0.02))
			lb.call(cloth, Vector3(0.9, 0.6, 0), Vector3(0.02, 0.46, 0.94))
			lb.call(cloth, Vector3(-0.9, 0.6, 0), Vector3(0.02, 0.46, 0.94))
			if school:
				# Hefte und Bücher
				lb.call(white, Vector3(-0.45, 0.835, 0.05), Vector3(0.3, 0.02, 0.4))
				lb.call(mat("book2", Color(0.2, 0.35, 0.7)), Vector3(0.4, 0.845, -0.05), Vector3(0.26, 0.05, 0.36))
			else:
				# Deko: Teller und Flasche
				lb.call(white, Vector3(-0.4, 0.86, 0.05), Vector3(0.26, 0.02, 0.26))
				lb.call(mat("bottle", Color(0.15, 0.4, 0.2), "", 0.2), Vector3(0.35, 0.97, -0.1), Vector3(0.08, 0.26, 0.08))
			_add_eyes(spot, Vector3(0.0, 0.22, 0.49))
			col_h = 0.9
		"nightstand":
			lb.call(wood, Vector3(0, 0.25, -0.15), Vector3(0.55, 0.5, 0.5))
			lb.call(wood_dark, Vector3(0, 0.52, -0.15), Vector3(0.6, 0.04, 0.55))
			lb.call(metal, Vector3(0, 0.66, -0.15), Vector3(0.05, 0.24, 0.05))
			lb.call(emissive("lampshade", Color(1.0, 0.75, 0.45), 2.0), Vector3(0, 0.86, -0.15), Vector3(0.24, 0.2, 0.24))
			_add_light(c + Basis(Vector3.UP, yaw) * Vector3(0, 1.1, -0.15), Color(1.0, 0.65, 0.35), 1.3, 4.5, "flicker")
			col_h = 0.6
		"counter":
			var top := mat("marble", Color(0.85, 0.85, 0.82), "floor_hall", 0.3)
			lb.call(mat("kitchen_front", Color(0.3, 0.45, 0.55)), Vector3(0, 0.43, -0.17), Vector3(L - 0.04, 0.86, 0.62))
			lb.call(top, Vector3(0, 0.89, -0.16), Vector3(L, 0.06, 0.68))
			# Herd
			lb.call(black, Vector3(-L * 0.5 + 0.5, 0.925, -0.16), Vector3(0.6, 0.02, 0.52))
			for sx in [-0.14, 0.14]:
				for sz in [-0.12, 0.12]:
					lb.call(metal, Vector3(-L * 0.5 + 0.5 + sx, 0.94, -0.16 + sz), Vector3(0.16, 0.015, 0.16))
			lb.call(black, Vector3(-L * 0.5 + 0.5, 0.5, 0.145), Vector3(0.56, 0.5, 0.02))
			# Spüle
			lb.call(metal, Vector3(L * 0.5 - 0.6, 0.925, -0.16), Vector3(0.6, 0.02, 0.44))
			lb.call(metal, Vector3(L * 0.5 - 0.6, 1.02, -0.4), Vector3(0.04, 0.2, 0.04))
			lb.call(metal, Vector3(L * 0.5 - 0.6, 1.11, -0.32), Vector3(0.04, 0.03, 0.2))
			# Topf
			lb.call(mat("pot_red", Color(0.7, 0.15, 0.12), "", 0.4), Vector3(-L * 0.5 + 0.36, 1.02, -0.28), Vector3(0.2, 0.14, 0.2))
			col_h = 1.0
		"fridge":
			lb.call(white, Vector3(0, 0.92, -0.12), Vector3(0.74, 1.84, 0.68))
			lb.call(black, Vector3(0, 1.22, 0.225), Vector3(0.7, 0.012, 0.012))
			lb.call(metal, Vector3(-0.28, 1.45, 0.24), Vector3(0.04, 0.3, 0.04))
			lb.call(metal, Vector3(-0.28, 0.85, 0.24), Vector3(0.04, 0.5, 0.04))
			col_h = 2.0
		"shower":
			lb.call(white, Vector3(0, 0.05, 0), Vector3(0.94, 0.1, 0.94))
			lb.call(mat("drain", Color(0.3, 0.32, 0.35)), Vector3(0, 0.105, 0), Vector3(0.12, 0.01, 0.12))
			# Duschstange + Brausekopf an der Rückwand
			lb.call(metal, Vector3(0, 1.05, -0.4), Vector3(0.04, 1.9, 0.04))
			lb.call(metal, Vector3(0, 1.98, -0.25), Vector3(0.04, 0.04, 0.3))
			lb.call(metal, Vector3(0, 1.93, -0.12), Vector3(0.2, 0.05, 0.2))
			# Glaswände zur Raumseite
			_glass_panel(c + Basis(Vector3.UP, yaw) * Vector3(0, 0.95, 0.46), Vector3(0.94, 1.7, 0.03), yaw)
			_glass_panel(c + Basis(Vector3.UP, yaw) * Vector3(0.46, 0.95, 0), Vector3(0.03, 1.7, 0.94), yaw)
			_glass_panel(c + Basis(Vector3.UP, yaw) * Vector3(-0.46, 0.95, 0), Vector3(0.03, 1.7, 0.94), yaw)
			col_h = 2.0
		"toilet":
			lb.call(white, Vector3(0, 0.22, 0.02), Vector3(0.4, 0.44, 0.52))
			lb.call(white, Vector3(0, 0.46, 0.02), Vector3(0.44, 0.04, 0.56))
			lb.call(white, Vector3(0, 0.6, -0.36), Vector3(0.46, 0.75, 0.2))
			lb.call(metal, Vector3(0, 1.0, -0.36), Vector3(0.1, 0.03, 0.08))
			col_h = 0.8
		"sink":
			lb.call(white, Vector3(0, 0.4, -0.3), Vector3(0.22, 0.8, 0.22))
			lb.call(white, Vector3(0, 0.84, -0.22), Vector3(0.62, 0.14, 0.48))
			lb.call(mat("water", Color(0.5, 0.7, 0.8), "", 0.1), Vector3(0, 0.915, -0.2), Vector3(0.46, 0.01, 0.32))
			lb.call(metal, Vector3(0, 0.98, -0.4), Vector3(0.04, 0.16, 0.04))
			# Spiegel mit Licht
			lb.call(emissive("mirror", Color(0.6, 0.8, 0.9), 0.9), Vector3(0, 1.0 if not _back_is_tall(f) else 1.55, -0.47), Vector3(0.6, 0.25 if not _back_is_tall(f) else 0.7, 0.03))
			_add_light(c + Basis(Vector3.UP, yaw) * Vector3(0, 1.4, 0.0), Color(0.6, 0.9, 1.0), 0.45, 3.5, "fluoro")
			col_h = 1.0
		"sofa":
			var fab := mat("sofa", Color(0.5, 0.22, 0.2))
			lb.call(fab, Vector3(0, 0.22, 0.02), Vector3(1.84, 0.44, 0.84))
			lb.call(fab, Vector3(0, 0.6, -0.36), Vector3(1.84, 0.5, 0.2))
			for sx in [-0.84, 0.84]:
				lb.call(fab, Vector3(sx, 0.4, 0.02), Vector3(0.18, 0.64, 0.84))
			lb.call(mat("cushion", Color(0.9, 0.75, 0.4)), Vector3(-0.45, 0.52, -0.18), Vector3(0.4, 0.3, 0.14))
			col_h = 0.9
		"tv":
			lb.call(wood_dark, Vector3(0, 0.22, -0.2), Vector3(1.6, 0.44, 0.46))
			lb.call(black, Vector3(0, 0.5, -0.2), Vector3(0.3, 0.12, 0.16))
			lb.call(black, Vector3(0, 0.93, -0.2), Vector3(1.24, 0.74, 0.06))
			var scr := emissive("tv_screen", Color(0.45, 0.6, 1.0), 1.6)
			lb.call(scr, Vector3(0, 0.93, -0.165), Vector3(1.14, 0.64, 0.01))
			_add_light(c + Basis(Vector3.UP, yaw) * Vector3(0, 1.0, 0.5), Color(0.45, 0.6, 1.0), 1.4, 5.0, "tv")
			col_h = 1.2
		"bookshelf":
			lb.call(wood_dark, Vector3(0, 0.9, -0.3), Vector3(1.84, 1.8, 0.06))
			for sx in [-0.9, 0.9]:
				lb.call(wood_dark, Vector3(sx, 0.9, -0.14), Vector3(0.06, 1.8, 0.38))
			for i in 5:
				var sy := 0.04 + i * 0.44
				lb.call(wood_dark, Vector3(0, sy, -0.14), Vector3(1.8, 0.05, 0.36))
				if i < 4:
					var bx := -0.82
					while bx < 0.75:
						var bw := _rng.randf_range(0.06, 0.14)
						var bh := _rng.randf_range(0.24, 0.36)
						if _rng.randf() < 0.85:
							var hue := _rng.randf()
							lb.call(mat("book%d" % int(hue * 8), Color.from_hsv(int(hue * 8) / 8.0, 0.55, 0.6)),
								Vector3(bx + bw * 0.5, sy + 0.025 + bh * 0.5, -0.12), Vector3(bw - 0.01, bh, 0.24))
						bx += bw
			col_h = 2.0
		"plant":
			lb.call(mat("terracotta", Color(0.7, 0.36, 0.22)), Vector3(0, 0.18, 0), Vector3(0.36, 0.36, 0.36))
			var leaf := mat("leaf", Color(0.2, 0.5, 0.25))
			lb.call(leaf, Vector3(0, 0.62, 0), Vector3(0.12, 0.6, 0.12))
			for i in 6:
				var a := i * TAU / 6.0 + _rng.randf() * 0.5
				var rr := _rng.randf_range(0.14, 0.26)
				lb.call(leaf, Vector3(cos(a) * rr, _rng.randf_range(0.6, 1.1), sin(a) * rr), Vector3(0.26, 0.1, 0.26))
			lb.call(leaf, Vector3(0, 1.1, 0), Vector3(0.3, 0.26, 0.3))
			col_h = 1.0
		"rug":
			var horiz: bool = f.dir == 0
			b.add_box(mat("rug", Color(1, 1, 1), "floor_carpet"), c + Vector3(0, 0.012, 0),
				Vector3(rc.size.x - 0.3, 0.024, rc.size.y - 0.3))
			if horiz:
				pass
		"board":
			# Schultafel an der Wand (hoch an der hinteren Außenwand, sonst niedrig)
			var high := _back_is_tall(f)
			var by := 1.45 if high else 0.5
			var bh := 1.0 if high else 0.5
			lb.call(mat("board_frame", Color(0.55, 0.4, 0.25)), Vector3(0, by, -0.4), Vector3(L - 0.3, bh + 0.08, 0.04))
			lb.call(mat("board", Color(0.1, 0.3, 0.2), "", 0.9), Vector3(0, by, -0.375), Vector3(L - 0.4, bh, 0.02))
			lb.call(mat("chalk", Color(0.9, 0.9, 0.85)), Vector3(-0.5, by + bh * 0.2, -0.362), Vector3(0.9, 0.03, 0.01))
			lb.call(mat("chalk", Color(0.9, 0.9, 0.85)), Vector3(-0.3, by - bh * 0.05, -0.362), Vector3(1.3, 0.03, 0.01))
			lb.call(mat("board_frame", Color(0.55, 0.4, 0.25)), Vector3(0, by - bh * 0.5 - 0.05, -0.34), Vector3(L - 0.4, 0.03, 0.1))
	if def.block:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(rc.size.x - 0.14, col_h, rc.size.y - 0.14)
		cs.shape = sh
		cs.position = c + Vector3(0, col_h * 0.5, 0)
		_body.add_child(cs)


func _back_is_tall(f: Dictionary) -> bool:
	var rc: Rect2i = f.rect
	return (f.dir == 0 and rc.position.y == 0) or (f.dir == 3 and rc.position.x == 0)


func _glass_panel(pos: Vector3, size: Vector3, yaw: float) -> void:
	var g := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = size
	g.mesh = gm
	g.material_override = glass_mat()
	g.position = pos
	g.rotation.y = yaw
	root.add_child(g)


func _add_eyes(spot: HidingSpot, local: Vector3, rotate_with_yaw := true) -> void:
	var eyes := Node3D.new()
	# Schrank-Spots sind selbst gedreht, Bett/Tisch nicht
	eyes.position = (Basis(Vector3.UP, spot.yaw) * local) if rotate_with_yaw else local
	if rotate_with_yaw:
		eyes.rotation.y = spot.yaw
	var em := emissive("hide_eyes", Color(1.0, 1.0, 0.85), 3.0)
	for sx in [-0.07, 0.07]:
		var e := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.07, 0.05, 0.02)
		e.mesh = m
		e.material_override = em
		e.position = Vector3(sx, 0, 0)
		eyes.add_child(e)
	eyes.visible = false
	spot.add_child(eyes)
	spot.eyes = eyes

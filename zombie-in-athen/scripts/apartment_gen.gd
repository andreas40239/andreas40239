class_name ApartmentGen
extends RefCounted
## Erzeugt den Grundriss einer Wohnung als Datenmodell (ohne 3D):
## Raster aus 1x1-m-Zellen, dünne Wände auf den Zellkanten, Türen, Fenster, Möbel.
##
## Ansicht: Die Kamera schaut von Süd-Ost nach Nord-West. Nord (y=0) und West (x=0)
## sind also die "hinteren" Wände (volle Höhe), Süd/Ost die vorderen (niedrig).

enum Edge { NONE, WALL, DOOR, WINDOW, ENTRANCE }
enum RoomType { HALL, BEDROOM, BATH, KITCHEN, LIVING, OFFICE, DINING, CLASSROOM, STORAGE }

const ROOM_NAMES := {
	RoomType.HALL: "Flur", RoomType.BEDROOM: "Schlafzimmer", RoomType.BATH: "Bad",
	RoomType.KITCHEN: "Küche", RoomType.LIVING: "Wohnzimmer", RoomType.OFFICE: "Gästezimmer",
	RoomType.DINING: "Gastraum", RoomType.CLASSROOM: "Klassenzimmer", RoomType.STORAGE: "Abstellraum",
}

# Möbel: l = Länge entlang der Wand, d = Tiefe, hide = Versteck-Kapazität,
# tall = blockiert Sichtlinie, block = blockiert Bewegung
const FURN := {
	"bed":       {"l": 2, "d": 2, "hide": 2, "tall": false, "block": true},
	"wardrobe":  {"l": 2, "d": 1, "hide": 1, "tall": true,  "block": true},
	"cabinet":   {"l": 1, "d": 1, "hide": 1, "tall": true,  "block": true},
	"table":     {"l": 2, "d": 1, "hide": 1, "tall": false, "block": true},
	"nightstand":{"l": 1, "d": 1, "hide": 0, "tall": false, "block": true},
	"counter":   {"l": 3, "d": 1, "hide": 0, "tall": false, "block": true},
	"fridge":    {"l": 1, "d": 1, "hide": 0, "tall": true,  "block": true},
	"shower":    {"l": 1, "d": 1, "hide": 0, "tall": false, "block": true},
	"toilet":    {"l": 1, "d": 1, "hide": 0, "tall": false, "block": true},
	"sink":      {"l": 1, "d": 1, "hide": 0, "tall": false, "block": true},
	"sofa":      {"l": 2, "d": 1, "hide": 0, "tall": false, "block": true},
	"tv":        {"l": 2, "d": 1, "hide": 0, "tall": false, "block": true},
	"bookshelf": {"l": 2, "d": 1, "hide": 0, "tall": true,  "block": true},
	"plant":     {"l": 1, "d": 1, "hide": 0, "tall": false, "block": true},
	"rug":       {"l": 3, "d": 2, "hide": 0, "tall": false, "block": false},
	"board":     {"l": 3, "d": 1, "hide": 0, "tall": false, "block": false},   # Tafel an der Wand
}

var w := 22
var h := 16
var theme := "home"                    # home | taverna | school
var rooms: Array[Dictionary] = []      # {id, type, rect: Rect2i, name}
var cell_room := PackedInt32Array()    # Raum-ID je Zelle
var hedge := PackedByteArray()         # (h+1)*w   Kante zwischen (x,y-1) und (x,y)
var vedge := PackedByteArray()         # h*(w+1)   Kante zwischen (x-1,y) und (x,y)
var blocked := PackedByteArray()       # Zelle durch Möbel blockiert
var tall := PackedByteArray()          # Zelle blockiert die Sichtlinie
var reserved := PackedByteArray()      # Zelle muss frei bleiben (vor Türen/Fenstern)
var furniture: Array[Dictionary] = []  # {kind, rect: Rect2i, dir, room, hide, access: Array[Vector2i]}
var openings: Array[Dictionary] = []   # {kind, horizontal, x, y, inside: Vector2i, out: Vector2i}
var seed_used := 0
var rng := RandomNumberGenerator.new()


func generate(p_seed: int, cfg: Dictionary) -> bool:
	for attempt in 80:
		seed_used = p_seed
		rng.seed = hash(str(p_seed) + ":" + str(attempt))
		if _try_generate(cfg):
			return true
	push_error("ApartmentGen: kein gültiger Grundriss gefunden")
	return false


# ------------------------------------------------------------------ Zugriff

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h

func room_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return -1
	return cell_room[y * w + x]

func is_blocked(x: int, y: int) -> bool:
	return not in_bounds(x, y) or blocked[y * w + x] != 0

func is_tall(x: int, y: int) -> bool:
	return not in_bounds(x, y) or tall[y * w + x] != 0

func get_h(x: int, y: int) -> int:
	return hedge[y * w + x]

func get_v(x: int, y: int) -> int:
	return vedge[y * (w + 1) + x]

func _set_h(x: int, y: int, e: int) -> void:
	hedge[y * w + x] = e

func _set_v(x: int, y: int, e: int) -> void:
	vedge[y * (w + 1) + x] = e

## Kante zwischen zwei orthogonal benachbarten Zellen.
func edge_between(ax: int, ay: int, bx: int, by: int) -> int:
	if ax == bx:
		return get_h(ax, maxi(ay, by))
	return get_v(maxi(ax, bx), ay)

func passable(ax: int, ay: int, bx: int, by: int) -> bool:
	if not in_bounds(ax, ay) or not in_bounds(bx, by):
		return false
	var e := edge_between(ax, ay, bx, by)
	return e == Edge.NONE or e == Edge.DOOR

func free_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in h:
		for x in w:
			if blocked[y * w + x] == 0:
				out.append(Vector2i(x, y))
	return out


# ------------------------------------------------------------------ Erzeugung

func _try_generate(cfg: Dictionary) -> bool:
	w = int(cfg.get("width", 22))
	h = int(cfg.get("height", 16))
	theme = String(cfg.get("theme", "home"))
	var layout := String(cfg.get("layout", "single"))
	rooms.clear()
	furniture.clear()
	openings.clear()
	cell_room.resize(w * h)
	cell_room.fill(-1)
	blocked.resize(w * h)
	blocked.fill(0)
	tall.resize(w * h)
	tall.fill(0)
	reserved.resize(w * h)
	reserved.fill(0)
	hedge.resize((h + 1) * w)
	hedge.fill(Edge.NONE)
	vedge.resize(h * (w + 1))
	vedge.fill(Edge.NONE)

	# --- Flure und Zimmerstreifen
	# "single": ein Flur quer durch die Mitte, Zimmer darüber und darunter.
	# "double": zwei Flure, an beiden Enden verbunden (Rundweg), dazwischen ein dritter Streifen.
	var strips: Array[Dictionary] = []    # {x, y, width, depth, rows: Flur-Kanten (H-Zeilen)}
	var hall_y := 0
	if layout == "double":
		var base := (h - 4) / 3
		var d1 := base + (1 if (h - 4) % 3 > 0 else 0)
		var d3 := base + (1 if (h - 4) % 3 > 1 else 0)
		var d2 := h - 4 - d1 - d3
		var ya := d1
		var yb := d1 + 2 + d2
		hall_y = ya
		_add_room(RoomType.HALL, Rect2i(0, ya, w, 2))
		_add_room(RoomType.HALL, Rect2i(0, yb, w, 2))
		_add_room(RoomType.HALL, Rect2i(0, ya + 2, 2, d2))
		_add_room(RoomType.HALL, Rect2i(w - 2, ya + 2, 2, d2))
		strips.append({"x": 0, "y": 0, "width": w, "depth": d1, "rows": [ya]})
		strips.append({"x": 2, "y": ya + 2, "width": w - 4, "depth": d2, "rows": [ya + 2, yb]})
		strips.append({"x": 0, "y": yb + 2, "width": w, "depth": d3, "rows": [yb + 2]})
	else:
		var cy := h / 2 - 1 + rng.randi_range(-1, 0)
		hall_y = cy
		_add_room(RoomType.HALL, Rect2i(0, cy, w, 2))
		strips.append({"x": 0, "y": 0, "width": w, "depth": cy, "rows": [cy]})
		strips.append({"x": 0, "y": cy + 2, "width": w, "depth": h - cy - 2, "rows": [cy + 2]})

	# --- Anzahl Zimmer je Streifen
	var counts: Array = cfg.get("rooms", [])
	if counts.size() != strips.size():
		var n_rooms := 3 + clampi(int(cfg.get("extra_rooms", 2)), 0, 3)
		var n_top := n_rooms / 2 + (n_rooms % 2 if rng.randf() < 0.5 else 0)
		n_top = clampi(n_top, 1, n_rooms - 1)
		counts = [n_top, n_rooms - n_top]
	var rects: Array[Rect2i] = []
	var rows_of: Array = []
	for si in strips.size():
		var st: Dictionary = strips[si]
		var widths := _split(st.width, int(counts[si]), 4)
		if widths.is_empty():
			return false
		var x0: int = st.x
		for rw in widths:
			rects.append(Rect2i(x0, st.y, rw, st.depth))
			rows_of.append(st.rows)
			x0 += rw
	var types := _assign_types(rects)
	var first_room := rooms.size()
	for i in rects.size():
		_add_room(types[i], rects[i])

	# --- Wände auf allen Raumgrenzen (Flurstücke gehen offen ineinander über)
	for y in range(0, h + 1):
		for x in w:
			if not _same_space(room_at(x, y - 1), room_at(x, y)):
				_set_h(x, y, Edge.WALL)
	for y in h:
		for x in range(0, w + 1):
			if not _same_space(room_at(x - 1, y), room_at(x, y)):
				_set_v(x, y, Edge.WALL)

	# --- Türen zum Flur (Zimmer zwischen zwei Fluren bekommen meist zwei)
	for i in rects.size():
		var rc: Rect2i = rects[i]
		var rows: Array = rows_of[i]
		for ri in rows.size():
			if ri > 0 and rng.randf() > 0.75:
				continue
			var ey: int = rows[ri]
			var dx := rng.randi_range(rc.position.x + 1, rc.end.x - 2)
			_set_h(dx, ey, Edge.DOOR)
			_reserve(dx, ey - 1)
			_reserve(dx, ey)
	# --- Verbindungstüren zwischen Nachbarzimmern (Rundwege zum Flüchten)
	var links := 0
	for pass_i in 2:
		for i in range(first_room, rooms.size() - 1):
			var a: Rect2i = rooms[i].rect
			var b: Rect2i = rooms[i + 1].rect
			if a.position.y != b.position.y or a.end.x != b.position.x:
				continue
			if _has_door_v(b.position.x, a):
				continue
			if rng.randf() < (0.55 if pass_i == 0 else 1.0) and (pass_i == 0 or links == 0):
				var dy := rng.randi_range(a.position.y + 1, a.end.y - 2)
				_set_v(b.position.x, dy, Edge.DOOR)
				_reserve(b.position.x - 1, dy)
				_reserve(b.position.x, dy)
				links += 1

	# --- Eingangstür am West-Ende des (oberen) Flurs (hintere Wand, gut sichtbar)
	var ey := hall_y + rng.randi_range(0, 1)
	_set_v(0, ey, Edge.ENTRANCE)
	_reserve(0, ey)
	openings.append({"kind": "entrance", "horizontal": false, "x": 0, "y": ey,
		"inside": Vector2i(0, ey), "out": Vector2i(-1, 0)})

	# --- Fenster in den Außenwänden
	for r in rooms:
		var rc: Rect2i = r.rect
		if r.type == RoomType.HALL:
			# Fenster am Ost-Ende der Querflure
			if rc.size.x == w:
				var wy := rc.position.y + rng.randi_range(0, 1)
				_add_window(false, w, wy, Vector2i(w - 1, wy), Vector2i(1, 0))
			continue
		var max_win := 1 if r.type == RoomType.BATH else 2
		var count := 0
		if rc.position.y == 0:
			for wx in _pick_spaced(rc.position.x + 1, rc.end.x - 2, max_win):
				_add_window(true, wx, 0, Vector2i(wx, 0), Vector2i(0, -1))
				count += 1
		if rc.end.y == h:
			for wx in _pick_spaced(rc.position.x + 1, rc.end.x - 2, max_win):
				_add_window(true, wx, h, Vector2i(wx, h - 1), Vector2i(0, 1))
				count += 1
		if rc.position.x == 0 and count < 3:
			for wy in _pick_spaced(rc.position.y + 1, rc.end.y - 2, 1):
				_add_window(false, 0, wy, Vector2i(0, wy), Vector2i(-1, 0))
		if rc.end.x == w and count < 3:
			for wy in _pick_spaced(rc.position.y + 1, rc.end.y - 2, 1):
				_add_window(false, w, wy, Vector2i(w - 1, wy), Vector2i(1, 0))

	# --- Möbel
	for r in rooms:
		_furnish(r)

	# --- Prüfen: alles erreichbar, genug Verstecke
	if not _all_reachable():
		return false
	var hide_cap := 0
	for f in furniture:
		if f.hide > 0:
			f["access"] = _access_cells(f.rect)
			if f.access.is_empty():
				return false
			hide_cap += f.hide
	var kinds := {}
	for f in furniture:
		kinds[f.kind] = true
	var has_type := {}
	for r in rooms:
		has_type[r.type] = true
	if theme == "home":
		# Pflicht: Schlafzimmer, Bad mit Dusche, Küche
		if not (has_type.has(RoomType.BEDROOM) and has_type.has(RoomType.BATH) and has_type.has(RoomType.KITCHEN)):
			return false
		if not (kinds.has("bed") and kinds.has("shower")):
			return false
	if not (kinds.has("table") and (kinds.has("wardrobe") or kinds.has("cabinet"))):
		return false
	return hide_cap >= 6 + (rects.size() - 5)


func _same_space(a: int, b: int) -> bool:
	if a == b:
		return true
	return a >= 0 and b >= 0 and rooms[a].type == RoomType.HALL and rooms[b].type == RoomType.HALL


## Raumtypen je nach Ort: die kleinsten und größten Räume bekommen feste Rollen,
## der Rest wird gemischt verteilt.
func _assign_types(rects: Array[Rect2i]) -> Dictionary:
	var small: Array = [RoomType.BATH]
	var large: Array = [RoomType.LIVING]
	var first: Array = [RoomType.BEDROOM, RoomType.KITCHEN]
	var filler: Array = [RoomType.OFFICE, RoomType.BEDROOM, RoomType.BATH, RoomType.STORAGE, RoomType.LIVING, RoomType.BEDROOM, RoomType.OFFICE]
	match theme:
		"taverna":
			small = [RoomType.BATH, RoomType.STORAGE]
			large = [RoomType.DINING, RoomType.DINING]
			first = [RoomType.KITCHEN, RoomType.OFFICE, RoomType.BEDROOM]
			filler = [RoomType.STORAGE, RoomType.BATH, RoomType.OFFICE]
		"school":
			small = [RoomType.BATH, RoomType.BATH, RoomType.STORAGE]
			large = [RoomType.DINING]
			first = [RoomType.KITCHEN, RoomType.OFFICE]
			filler = [RoomType.CLASSROOM]
	var order: Array = range(rects.size())
	order.sort_custom(func(a, b): return rects[a].get_area() < rects[b].get_area())
	var types := {}
	var budget: int = rects.size() - first.size()
	while budget > 0 and (not small.is_empty() or not large.is_empty()):
		if not small.is_empty():
			types[order.pop_front()] = small.pop_front()
			budget -= 1
		if budget > 0 and not large.is_empty():
			types[order.pop_back()] = large.pop_front()
			budget -= 1
	var pool: Array = []
	var fi := 0
	while pool.size() < order.size():
		if pool.size() < first.size():
			pool.append(first[pool.size()])
		else:
			pool.append(filler[fi % filler.size()])
			fi += 1
	_shuffle(pool)
	for i in order.size():
		types[order[i]] = pool[i]
	return types


func _add_room(type: int, rect: Rect2i) -> void:
	var id := rooms.size()
	var nm: String = ROOM_NAMES[type]
	for r in rooms:
		if r.type == type:
			nm += " 2"
	rooms.append({"id": id, "type": type, "rect": rect, "name": nm})
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cell_room[y * w + x] = id


func _split(total: int, n: int, minw: int) -> Array[int]:
	var out: Array[int] = []
	if n * minw > total:
		return out
	for i in n:
		out.append(minw)
	var extra := total - n * minw
	while extra > 0:
		out[rng.randi_range(0, n - 1)] += 1
		extra -= 1
	return out


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _reserve(x: int, y: int) -> void:
	if in_bounds(x, y):
		reserved[y * w + x] = 1


func _has_door_v(x: int, rc: Rect2i) -> bool:
	for y in range(rc.position.y, rc.end.y):
		if get_v(x, y) == Edge.DOOR:
			return true
	return false


func _pick_spaced(lo: int, hi: int, n: int) -> Array[int]:
	var out: Array[int] = []
	if hi < lo:
		return out
	var cands: Array = range(lo, hi + 1)
	_shuffle(cands)
	for c in cands:
		var ok := true
		for o in out:
			if absi(o - c) < 3:
				ok = false
		if ok:
			out.append(c)
		if out.size() >= n:
			break
	return out


func _add_window(horizontal: bool, x: int, y: int, inside: Vector2i, out_dir: Vector2i) -> void:
	if reserved[inside.y * w + inside.x] != 0:
		return   # nicht direkt neben einer Tür
	if horizontal:
		_set_h(x, y, Edge.WINDOW)
	else:
		_set_v(x, y, Edge.WINDOW)
	_reserve(inside.x, inside.y)
	openings.append({"kind": "window", "horizontal": horizontal, "x": x, "y": y,
		"inside": inside, "out": out_dir})


# ------------------------------------------------------------------ Möblierung

func _furnish(r: Dictionary) -> void:
	var rc: Rect2i = r.rect
	var area: int = rc.get_area()
	match r.type:
		RoomType.BEDROOM:
			_place(r, "bed")
			_place(r, "wardrobe")
			_place(r, "nightstand")
			if area >= 30:
				_place(r, "cabinet")
			_place(r, "plant")
			_place(r, "rug", true)
		RoomType.BATH:
			if theme == "home":
				_place(r, "shower", false, true)
			_place(r, "toilet")
			_place(r, "sink")
			_place(r, "cabinet")
			if theme != "home":
				_place(r, "toilet")
				_place(r, "sink")
			if area >= 28:
				_place(r, "plant")
		RoomType.KITCHEN:
			_place(r, "counter")
			_place(r, "fridge")
			_place(r, "table", true)
			if theme != "home":
				_place(r, "counter")
			if area >= 30:
				_place(r, "cabinet")
			_place(r, "plant")
		RoomType.LIVING:
			_place(r, "sofa")
			_place(r, "tv")
			_place(r, "table", true)
			_place(r, "bookshelf")
			_place(r, "wardrobe")
			_place(r, "plant")
			_place(r, "rug", true)
		RoomType.OFFICE:
			if theme == "home":
				_place(r, "bed")
			else:
				_place(r, "sofa")
			_place(r, "table")
			_place(r, "bookshelf")
			_place(r, "cabinet")
			_place(r, "plant")
		RoomType.DINING:
			# Gastraum / Mensa: Theke und viele Tische
			_place(r, "counter")
			_place(r, "fridge")
			_place_grid(r, "table", 3, 3, 1)
			_place(r, "cabinet")
			_place(r, "plant")
			_place(r, "plant")
		RoomType.CLASSROOM:
			_place(r, "board", false, false, 0)
			_place_grid(r, "table", 3, 2, 2)
			_place(r, "cabinet")
			_place(r, "bookshelf")
			_place(r, "plant")
		RoomType.STORAGE:
			_place(r, "cabinet")
			_place(r, "cabinet")
			_place(r, "bookshelf")
			_place(r, "fridge")
			_place(r, "table")
		RoomType.HALL:
			var length := maxi(rc.size.x, rc.size.y)
			var n_cab := 1 + (1 if length >= 20 else 0)
			if theme == "school":
				n_cab = maxi(2, length / 5)    # Spinde
			elif length < 10:
				n_cab = 1 if rng.randf() < 0.5 else 0
			for i in n_cab:
				_place(r, "cabinet")
			_place(r, "plant")


## Möbel in Reihen aufstellen (Tische im Gastraum / Klassenzimmer).
func _place_grid(r: Dictionary, kind: String, step_x: int, step_y: int, top_margin: int) -> int:
	var def: Dictionary = FURN[kind]
	var rc: Rect2i = r.rect
	var n := 0
	var y := rc.position.y + top_margin
	while y + def.d <= rc.end.y - 1:
		var x := rc.position.x + 1
		while x + def.l <= rc.end.x - 1:
			if _try_put(r, kind, Rect2i(x, y, def.l, def.d), 0, true):
				n += 1
			x += step_x
		y += step_y
	return n


## dir: Richtung, in die das Möbel "schaut" (0 = +z/Süd, 1 = -x/West, 2 = -z/Nord, 3 = +x/Ost);
## die Rückseite steht an der gegenüberliegenden Wand.
func _place(r: Dictionary, kind: String, center := false, corner := false, only_dir := -1) -> bool:
	var def: Dictionary = FURN[kind]
	var rc: Rect2i = r.rect
	var cands: Array = []
	if center:
		for horiz in [true, false]:
			var fw: int = def.l if horiz else def.d
			var fh: int = def.d if horiz else def.l
			for y in range(rc.position.y + 1, rc.end.y - fh):
				for x in range(rc.position.x + 1, rc.end.x - fw):
					cands.append({"rect": Rect2i(x, y, fw, fh), "dir": 0 if horiz else 3})
	else:
		var l: int = def.l
		var d: int = def.d
		# hohe Möbel nur an die hinteren Wände (Nord/West), damit sie nichts verdecken
		var dirs: Array = [0, 3] if def.tall else [0, 1, 2, 3]
		if only_dir >= 0:
			dirs = [only_dir]
		for dir in dirs:
			match dir:
				0:  # an Nordwand
					for x in range(rc.position.x, rc.end.x - l + 1):
						cands.append({"rect": Rect2i(x, rc.position.y, l, d), "dir": 0})
				2:  # an Südwand
					for x in range(rc.position.x, rc.end.x - l + 1):
						cands.append({"rect": Rect2i(x, rc.end.y - d, l, d), "dir": 2})
				3:  # an Westwand
					for y in range(rc.position.y, rc.end.y - l + 1):
						cands.append({"rect": Rect2i(rc.position.x, y, d, l), "dir": 3})
				1:  # an Ostwand
					for y in range(rc.position.y, rc.end.y - l + 1):
						cands.append({"rect": Rect2i(rc.end.x - d, y, d, l), "dir": 1})
	_shuffle(cands)
	if corner:
		cands = cands.filter(func(c):
			var p: Vector2i = c.rect.position
			return (p.x == rc.position.x or p.x == rc.end.x - 1) and (p.y == rc.position.y or p.y == rc.end.y - 1))
	for c in cands:
		if _try_put(r, kind, c.rect, c.dir, center):
			return true
	return false


func _try_put(r: Dictionary, kind: String, fr: Rect2i, dir: int, center: bool) -> bool:
	var def: Dictionary = FURN[kind]
	if not _rect_free(fr, def.block):
		return false
	if not def.block:
		if kind == "board":
			# Tafel hängt an der Wand: keine Tür/kein Fenster dahinter, Platz davor frei halten
			if not _backs_solid(fr, dir):
				return false
			for y in range(fr.position.y, fr.end.y):
				for x in range(fr.position.x, fr.end.x):
					if reserved[y * w + x] != 0:
						return false
			for y in range(fr.position.y, fr.end.y):
				for x in range(fr.position.x, fr.end.x):
					_reserve(x, y)
		furniture.append({"kind": kind, "rect": fr, "dir": dir, "room": r.id, "hide": 0})
		return true
	# Die Wand hinter dem Möbel darf weder Tür noch Fenster sein
	if not center and not _backs_solid(fr, dir):
		return false
	_mark(fr, 1, def.tall)
	if _all_reachable() and not _access_cells(fr).is_empty():
		furniture.append({"kind": kind, "rect": fr, "dir": dir, "room": r.id, "hide": def.hide})
		return true
	_mark(fr, 0, def.tall)
	return false


func _rect_free(fr: Rect2i, blocking: bool) -> bool:
	for y in range(fr.position.y, fr.end.y):
		for x in range(fr.position.x, fr.end.x):
			if blocked[y * w + x] != 0:
				return false
			if blocking and reserved[y * w + x] != 0:
				return false
	if not blocking:
		for f in furniture:
			if f.kind == "rug" and (f.rect as Rect2i).intersects(fr):
				return false
	return true


func _backs_solid(fr: Rect2i, dir: int) -> bool:
	for y in range(fr.position.y, fr.end.y):
		for x in range(fr.position.x, fr.end.x):
			var e := Edge.WALL
			match dir:
				0: e = get_h(x, fr.position.y) if y == fr.position.y else Edge.WALL
				2: e = get_h(x, fr.end.y) if y == fr.end.y - 1 else Edge.WALL
				3: e = get_v(fr.position.x, y) if x == fr.position.x else Edge.WALL
				1: e = get_v(fr.end.x, y) if x == fr.end.x - 1 else Edge.WALL
			if e != Edge.WALL:
				return false
	return true


func _mark(fr: Rect2i, v: int, is_tall: bool) -> void:
	for y in range(fr.position.y, fr.end.y):
		for x in range(fr.position.x, fr.end.x):
			blocked[y * w + x] = v
			if is_tall:
				tall[y * w + x] = v


func _access_cells(fr: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(fr.position.y, fr.end.y):
		for x in range(fr.position.x, fr.end.x):
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(x, y) + d
				if fr.has_point(n) or not in_bounds(n.x, n.y):
					continue
				if blocked[n.y * w + n.x] != 0:
					continue
				if edge_between(x, y, n.x, n.y) != Edge.NONE:
					continue
				if not out.has(n):
					out.append(n)
	return out


func _all_reachable() -> bool:
	var start := -1
	var total := 0
	for i in w * h:
		if blocked[i] == 0:
			total += 1
			if start < 0 and rooms[cell_room[i]].type == RoomType.HALL:
				start = i
	if start < 0:
		return false
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	var stack: Array[int] = [start]
	seen[start] = 1
	var count := 0
	while not stack.is_empty():
		var i: int = stack.pop_back()
		count += 1
		var x := i % w
		var y := i / w
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if not in_bounds(nx, ny):
				continue
			var ni := ny * w + nx
			if seen[ni] != 0 or blocked[ni] != 0:
				continue
			if not passable(x, y, nx, ny):
				continue
			seen[ni] = 1
			stack.append(ni)
	return count == total

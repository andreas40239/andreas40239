extends Node2D
## Spielleiter: Karte, Kollision, Bosse, Checkpoints, Kamera, Ablauf.
## Welches Level gespielt wird, steht in Engine-Metadaten "level" (vom Startbildschirm gesetzt).

const Levels := preload("res://scripts/levels.gd")
const WorldStatic := preload("res://scripts/world_static.gd")
const WorldDynamic := preload("res://scripts/world_dynamic.gd")
const Player := preload("res://scripts/player.gd")
const Bat := preload("res://scripts/enemy_bat.gd")
const Slime := preload("res://scripts/enemy_slime.gd")
const BabySpider := preload("res://scripts/enemy_spider.gd")
const Knight := preload("res://scripts/boss_knight.gd")
const Octopus := preload("res://scripts/boss_octopus.gd")
const Golem := preload("res://scripts/boss_golem.gd")
const Spider := preload("res://scripts/boss_spider.gd")
const Dragon := preload("res://scripts/dragon.gd")
const Pickup := preload("res://scripts/pickup.gd")
const Projectile := preload("res://scripts/projectile.gd")
const Effects := preload("res://scripts/effects.gd")
const Hud := preload("res://scripts/hud.gd")
const AudioMgr := preload("res://scripts/audio.gd")
const Progress := preload("res://scripts/progress.gd")

const START_SCENE := "res://scenes/start.tscn"
const TILE := 32
const MAX_DT := 1.0 / 30.0

# --- Drehende Labyrinth-Scheiben (Level 1) --------------------------------
const RING_HALF_THICK := 4.0
const RING_GAP := 46.0  # Breite der Lücke in Pixeln

# --- Feuerfeld: alle Flammen gehen gemeinsam an und aus -------------------
const FIRE_CYCLE := 5.0  # Sekunden pro Durchgang
const FIRE_ON := 1.0     # so lange brennt es
const FIRE_WARN := 0.8   # so lange flackert vorher die Warnung

enum { BOSS_IDLE, BOSS_FIGHT, BOSS_DONE }
const BOSS_ENTRY := ["", "a", "b", "c"]
const BOSS_EXIT := ["", "A", "B", "G"]

var level: Dictionary
var level_num := 1
var map_w := 0
var map_h := 0
var tiles: Array = []

var world_static: Node2D
var world_dynamic: Node2D
var entities: Node2D
var effects: Node2D
var camera: Camera2D
var hud: Node
var audio: Node

var player: Node2D
var dragon: Node2D = null
var enemies: Array = []
var projectiles: Array = []
var pickups: Array = []

var time := 0.0
var has_rings := false
var ring_center := Vector2.ZERO
var ring_radii: Array = []
var ring_speed: Array = []
var ring_angles: Array = []
var fire: Dictionary = {}

var boss_count := 0
var boss_info: Array = [{}]
var boss_state: Array = [0]
var boss_nodes: Array = [null]
var boss_spawn: Array = [Vector2.ZERO]

var crystals := 0
var keys := 0
var portal_pos := Vector2.ZERO
var checkpoint := Vector2.ZERO
var deaths := 0
var play_time := 0.0
var state := "play"  # play, dead, won
var dead_timer := 0.0
var shake := 0.0
var fire_last_step := -1
var portal_msg_cd := 0.0
var door_msg_cd := 0.0
var dragon_roar_cd := 3.0
var seen_dragon := false
var seen_hints := {}

# Steuerung (wird vom HUD bzw. der Tastatur gesetzt)
var touch_dir := Vector2.ZERO
var action_queued := false


func _ready() -> void:
	randomize()
	level_num = int(Engine.get_meta("level", 1))
	level = Levels.get_level(level_num)
	_load_map()
	_setup_level()

	world_static = WorldStatic.new()
	world_static.game = self
	add_child(world_static)
	world_dynamic = WorldDynamic.new()
	world_dynamic.game = self
	add_child(world_dynamic)
	entities = Node2D.new()
	add_child(entities)
	effects = Effects.new()
	add_child(effects)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map_w * TILE
	camera.limit_bottom = map_h * TILE
	add_child(camera)

	audio = AudioMgr.new()
	add_child(audio)
	hud = Hud.new()
	hud.game = self
	add_child(hud)

	_spawn_from_map()
	player.weapon = level["start_weapon"]
	player.position = checkpoint
	camera.position = player.position
	camera.make_current()
	audio.play_music("dungeon")
	hud.show_message("Level %d: %s" % [level_num, level["name"]], level["intro"])


func _setup_level() -> void:
	var r = level["rings"]
	has_rings = r != null
	if has_rings:
		ring_center = r["center"]
		ring_radii = r["radii"]
		ring_speed = r["speed"]
		ring_angles = []
		for i in ring_radii.size():
			ring_angles.append(1.7 * i)
	if level["fire"] != null:
		fire = level["fire"]
	var bs: Array = level["bosses"]
	boss_count = bs.size()
	for b in bs:
		boss_info.append(b)
		boss_state.append(BOSS_IDLE)
		boss_nodes.append(null)
		boss_spawn.append(Vector2.ZERO)


# ---------------------------------------------------------------- Karte
func _load_map() -> void:
	var rows: Array = level["map"]
	map_h = rows.size()
	map_w = String(rows[0]).length()
	tiles.clear()
	for y in map_h:
		var row: Array = []
		var s: String = rows[y]
		for x in map_w:
			row.append(s[x])
		tiles.append(row)


func tile_at(tx: int, ty: int) -> String:
	if tx < 0 or ty < 0 or tx >= map_w or ty >= map_h:
		return "#"
	return tiles[ty][tx]


func set_tile(tx: int, ty: int, ch: String) -> void:
	tiles[ty][tx] = ch
	world_static.queue_redraw_all()


func tile_center(tx: int, ty: int) -> Vector2:
	return Vector2((tx + 0.5) * TILE, (ty + 0.5) * TILE)


func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func _boss_for_gate(ch: String, gates: Array) -> int:
	var i := gates.find(ch)
	return i if i > 0 and i <= boss_count else -1


## Ist die Kachel für Läufer blockiert? (fliegend: Wasser ist frei)
func is_solid(tx: int, ty: int, flying := false) -> bool:
	var ch := tile_at(tx, ty)
	match ch:
		"#", "C", "P", "t", "L":
			return true
		"~":
			return not flying
		"a", "b", "c":
			var i := _boss_for_gate(ch, BOSS_ENTRY)
			return i > 0 and boss_state[i] == BOSS_FIGHT
		"A", "B", "G":
			var i := _boss_for_gate(ch, BOSS_EXIT)
			return i > 0 and boss_state[i] != BOSS_DONE
	return false


func _spawn_from_map() -> void:
	var boss_chars := {}
	for i in range(1, boss_count + 1):
		boss_chars[boss_info[i]["char"]] = i
	for y in map_h:
		for x in map_w:
			var ch: String = tiles[y][x]
			var p := tile_center(x, y)
			var keep_floor := true
			match ch:
				"S":
					checkpoint = p
				"f":
					_add_pickup("fire", p)
				"i":
					_add_pickup("ice", p)
				"h":
					_add_pickup("heart", p)
				"p":
					_add_pickup("potion", p)
				"k":
					_add_pickup("key", p)
				"v":
					_add_enemy(Bat.new(), p)
				"s":
					_add_enemy(Slime.new(), p)
				"D":
					pass
				"E":
					portal_pos = p
					keep_floor = false
				_:
					if boss_chars.has(ch):
						boss_spawn[boss_chars[ch]] = p
						if boss_info[boss_chars[ch]]["kind"] == "octopus":
							tiles[y][x] = "~"
							keep_floor = false
					else:
						keep_floor = false
			if keep_floor:
				tiles[y][x] = "."
	if has_rings:
		checkpoint = ring_center
	player = Player.new()
	player.game = self
	entities.add_child(player)
	if level["dragon"] != null:
		dragon = Dragon.new()
		dragon.game = self
		dragon.center = level["dragon"]["center"]
		dragon.amp = level["dragon"]["amp"]
		entities.add_child(dragon)
	for i in range(1, boss_count + 1):
		_spawn_boss(i)


func _add_pickup(kind: String, p: Vector2) -> Node2D:
	var pk := Pickup.new()
	pk.kind = kind
	pk.position = p
	pk.game = self
	entities.add_child(pk)
	pickups.append(pk)
	return pk


func _add_enemy(e: Node2D, p: Vector2) -> void:
	e.game = self
	e.position = p
	entities.add_child(e)
	enemies.append(e)


func spawn_baby_spider(p: Vector2) -> void:
	_add_enemy(BabySpider.new(), p)


func _spawn_boss(i: int) -> void:
	if boss_nodes[i] != null and is_instance_valid(boss_nodes[i]):
		enemies.erase(boss_nodes[i])
		boss_nodes[i].queue_free()
	var b: Node2D
	match boss_info[i]["kind"]:
		"knight": b = Knight.new()
		"octopus": b = Octopus.new()
		"golem": b = Golem.new()
		"icegolem":
			b = Golem.new()
			b.ice_variant = true
		"spider": b = Spider.new()
	b.game = self
	b.position = boss_spawn[i]
	b.boss_id = i
	entities.add_child(b)
	enemies.append(b)
	boss_nodes[i] = b


func spawn_projectile(p: Vector2, vel: Vector2, kind: String, hostile := true) -> void:
	var pr := Projectile.new()
	pr.game = self
	pr.position = p
	pr.velocity = vel
	pr.kind = kind
	pr.hostile = hostile
	entities.add_child(pr)
	projectiles.append(pr)


# ---------------------------------------------------------- Kollision
## Bewegt einen Kreis mit Kachel-Kollision; gibt die neue Position zurück.
func move_circle(pos: Vector2, delta: Vector2, r: float, flying := false) -> Vector2:
	var steps := int(ceil(delta.length() / (r * 0.8))) + 1
	var d := delta / steps
	for _i in steps:
		pos.x += d.x
		pos = resolve_tiles(pos, r, flying)
		pos.y += d.y
		pos = resolve_tiles(pos, r, flying)
	return pos


func resolve_tiles(pos: Vector2, r: float, flying := false) -> Vector2:
	var x0 := floori((pos.x - r) / TILE)
	var x1 := floori((pos.x + r) / TILE)
	var y0 := floori((pos.y - r) / TILE)
	var y1 := floori((pos.y + r) / TILE)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if not is_solid(tx, ty, flying):
				continue
			var rx := float(tx * TILE)
			var ry := float(ty * TILE)
			var closest := Vector2(clampf(pos.x, rx, rx + TILE), clampf(pos.y, ry, ry + TILE))
			var diff := pos - closest
			var dist := diff.length()
			if dist < r:
				if dist > 0.001:
					pos = closest + diff / dist * r
				else:
					# Mittelpunkt steckt in der Kachel: kürzesten Weg hinaus
					var c := Vector2(rx + TILE * 0.5, ry + TILE * 0.5)
					var o := pos - c
					if absf(o.x) > absf(o.y):
						pos.x = c.x + signf(o.x) * (TILE * 0.5 + r)
					else:
						pos.y = c.y + signf(o.y) * (TILE * 0.5 + r)
	return pos


func touches_solid(pos: Vector2, r: float, flying := false) -> bool:
	return resolve_tiles(pos, r, flying).distance_squared_to(pos) > 0.01


## Kollision mit den drehenden Ringen der Startzone.
func resolve_rings(pos: Vector2, r: float) -> Vector2:
	if not has_rings:
		return pos
	var to := pos - ring_center
	if to.length() > ring_radii[-1] + 30.0:
		return pos
	for i in ring_radii.size():
		var rad: float = ring_radii[i]
		var gap_half := (RING_GAP * 0.5) / rad
		var d := (pos - ring_center).length()
		if absf(d - rad) >= RING_HALF_THICK + r + 2.0:
			continue
		var ang := (pos - ring_center).angle()
		var diff := wrapf(ang - ring_angles[i], -PI, PI)
		if absf(diff) > gap_half:
			# Auf der Mauer: radial auf die nächste Seite schieben
			var dir := (pos - ring_center).normalized()
			if d < rad:
				pos = ring_center + dir * minf(d, rad - RING_HALF_THICK - r)
			else:
				pos = ring_center + dir * maxf(d, rad + RING_HALF_THICK + r)
		else:
			# In der Lücke: an den Mauerenden abprallen
			for sgn in [-1.0, 1.0]:
				var e: Vector2 = ring_center + Vector2.from_angle(ring_angles[i] + sgn * gap_half) * rad
				var off := pos - e
				var od := off.length()
				if od < RING_HALF_THICK + r and od > 0.001:
					pos = e + off / od * (RING_HALF_THICK + r)
	return pos


## 0 = aus, 1 = Warnung (glühend), 2 = brennt
func fire_burning_at(tx: int, ty: int) -> int:
	if tile_at(tx, ty) != "F" or fire.is_empty():
		return 0
	var ph := fposmod(time, FIRE_CYCLE)
	if ph < FIRE_ON:
		return 2
	if ph > FIRE_CYCLE - FIRE_WARN:
		return 1
	return 0


func is_ice(p: Vector2) -> bool:
	var t := world_to_tile(p)
	return tile_at(t.x, t.y) == "I"


# ------------------------------------------------------------ Ablauf
func _process(delta: float) -> void:
	var dt := minf(delta, MAX_DT)
	time += dt
	for i in ring_angles.size():
		ring_angles[i] = wrapf(ring_angles[i] + ring_speed[i] * dt, -PI, PI)

	if state == "play":
		play_time += dt
		_update_play(dt)
	elif state == "dead":
		dead_timer -= dt
		_update_world_only(dt)
		if dead_timer <= 0.0:
			_respawn()
	else:
		_update_world_only(dt)

	# Kamera + Bildschirmwackeln
	camera.position = player.position
	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 18.0)
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	else:
		camera.offset = Vector2.ZERO


func _update_world_only(dt: float) -> void:
	if dragon:
		dragon.update(dt)
	for pk in pickups:
		pk.update(dt)


func _update_play(dt: float) -> void:
	# Eingabe
	var dir := touch_dir
	var kb := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	if kb != Vector2.ZERO:
		dir = kb.normalized()
	player.input_dir = dir
	if action_queued:
		action_queued = false
		player.try_attack()

	player.update(dt)
	if dragon:
		dragon.update(dt)
	for e in enemies.duplicate():
		if is_instance_valid(e):
			e.update(dt)
	for pr in projectiles.duplicate():
		if is_instance_valid(pr):
			pr.update(dt)
	for pk in pickups.duplicate():
		if is_instance_valid(pk):
			pk.update(dt)

	_check_contacts()
	_check_bosses()
	_check_fire_field()
	_check_doors(dt)
	_check_zones(dt)


func _check_contacts() -> void:
	if player.dead:
		return
	for e in enemies:
		if not is_instance_valid(e) or not e.is_dangerous():
			continue
		if e.touches(player.position, player.radius):
			player.hurt(e.contact_damage(), (player.position - e.position).normalized())
	if dragon and dragon.touches(player.position, player.radius):
		player.hurt(1, dragon.push_dir(player.position))
	for pk in pickups.duplicate():
		if pk.position.distance_to(player.position) < player.radius + 14.0:
			_collect(pk)


func _collect(pk: Node2D) -> void:
	pickups.erase(pk)
	match pk.kind:
		"fire":
			player.weapon = maxi(player.weapon, 1)
			audio.sfx("powerup")
			hud.show_message("FEUERSCHWERT!", "Schlage gegen rissige Wände, um sie zu zerstören.")
			checkpoint = pk.position
		"ice":
			player.weapon = 2
			audio.sfx("powerup")
			hud.show_message("EISSCHWERT!", "Friert Gegner ein - und behält die Kraft des Feuers.")
			checkpoint = pk.position
		"heart":
			player.max_hp += 2
			player.hp = player.max_hp
			audio.sfx("powerup")
			hud.show_message("HERZ-KRISTALL!", "Mehr Leben - und alle Herzen aufgefüllt.")
			checkpoint = pk.position
		"potion":
			player.hp = mini(player.max_hp, player.hp + 2)
			audio.sfx("pickup")
			hud.show_message("Heiltrank", "+2 Herzen")
		"key":
			keys += 1
			audio.sfx("key")
			hud.show_message("SCHLÜSSEL!", "Damit öffnest du eine verschlossene Tür.")
			checkpoint = pk.position
		"crystal":
			crystals += 1
			audio.sfx("crystal")
			hud.show_message("KRISTALL %d/%d" % [crystals, boss_count], "Bringe alle Kristalle zum Portal.")
	effects.burst(pk.position, Color(1, 0.95, 0.6), 18, 120.0)
	pk.queue_free()


func _check_bosses() -> void:
	var pt := world_to_tile(player.position)
	for i in range(1, boss_count + 1):
		if boss_state[i] == BOSS_IDLE and Rect2i(boss_info[i]["trigger"]).has_point(pt):
			_start_boss(i)


func _start_boss(i: int) -> void:
	boss_state[i] = BOSS_FIGHT
	audio.sfx("gate")
	audio.play_music("boss")
	shake = 6.0
	boss_nodes[i].start_fight()
	hud.show_message(boss_info[i]["name"], "")


func boss_defeated(i: int) -> void:
	boss_state[i] = BOSS_DONE
	var b: Node2D = boss_nodes[i]
	enemies.erase(b)
	effects.burst(b.position, Color(1, 0.7, 0.3), 60, 260.0)
	shake = 12.0
	audio.sfx("boss_defeat")
	audio.sfx("gate")
	audio.play_music("dungeon")
	var drop: Vector2 = boss_info[i].get("drop", b.position)
	_add_pickup("crystal", drop)
	checkpoint = drop
	hud.show_message(boss_info[i]["name"] + " besiegt!", "Ein Kristall ist erschienen. Das Tor ist offen.")
	b.queue_free()
	boss_nodes[i] = null
	for pr in projectiles.duplicate():
		pr.queue_free()
	projectiles.clear()
	# kleine Spinnen verschwinden mit ihrer Mutter
	for e in enemies.duplicate():
		if e.has_meta("brood"):
			enemies.erase(e)
			effects.burst(e.position, Color(0.6, 0.5, 0.7), 8, 80.0)
			e.queue_free()


func _check_fire_field() -> void:
	if fire.is_empty():
		return
	var step := floori(time / FIRE_CYCLE)
	var p := player.position
	var pt := world_to_tile(p)
	if step != fire_last_step:
		fire_last_step = step
		if Rect2i(fire["area"]).has_point(pt):
			audio.sfx("fire", -6.0)
	if player.dead or player.invuln > 0.0:
		return
	if fire_burning_at(pt.x, pt.y) == 2:
		# Kinderfreundlich: ein Herz Schaden, kleiner Schubs zurück, kein Neustart
		player.hurt(1, Vector2.LEFT)
		effects.burst(p, Color(1, 0.5, 0.1), 20, 150.0)


func _check_doors(dt: float) -> void:
	door_msg_cd -= dt
	if player.dead:
		return
	var p := player.position
	var pt := world_to_tile(p)
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var tx := pt.x + ox
			var ty := pt.y + oy
			if tile_at(tx, ty) != "L":
				continue
			var rect := Rect2(tx * TILE, ty * TILE, TILE, TILE)
			var closest := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
			if closest.distance_to(p) > player.radius + 3.0:
				continue
			if keys > 0:
				keys -= 1
				_open_door(tx, ty)
				audio.sfx("gate")
				hud.show_message("Die Tür ist offen!", "")
				return
			elif door_msg_cd <= 0.0:
				door_msg_cd = 3.0
				audio.sfx("denied")
				hud.show_message("Verschlossen!", "Du brauchst einen Schlüssel.")


func _open_door(tx: int, ty: int) -> void:
	# ganze zusammenhängende Tür öffnen
	var todo := [Vector2i(tx, ty)]
	while not todo.is_empty():
		var t: Vector2i = todo.pop_back()
		if tile_at(t.x, t.y) != "L":
			continue
		tiles[t.y][t.x] = "."
		effects.burst(tile_center(t.x, t.y), Color(0.9, 0.8, 0.4), 14, 120.0)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			todo.append(t + d)
	world_static.queue_redraw_all()


func _check_zones(dt: float) -> void:
	var p := player.position
	var pt := world_to_tile(p)
	portal_msg_cd -= dt
	for i in level["hints"].size():
		var h: Dictionary = level["hints"][i]
		if not seen_hints.has(i) and Rect2i(h["rect"]).has_point(pt):
			seen_hints[i] = true
			if h["title"] != "":
				hud.show_message(h["title"], h["sub"])
			if h.has("checkpoint"):
				checkpoint = h["checkpoint"]
	# Drachenhalle
	if dragon and Rect2i(level["dragon"]["hall"]).has_point(pt):
		dragon_roar_cd -= dt
		if not seen_dragon:
			seen_dragon = true
			checkpoint = level["dragon"]["entry"]
			audio.sfx("dragon")
			shake = 8.0
			hud.show_message("Der Endlos-Drache!", "Er kreist ewig. Finde die Lücke - das Eisschwert lähmt ihn.")
			dragon_roar_cd = 7.0
		elif dragon_roar_cd <= 0.0:
			dragon_roar_cd = randf_range(6.0, 10.0)
			audio.sfx("dragon", -4.0)
	# Portal
	if p.distance_to(portal_pos) < 26.0:
		if crystals >= boss_count:
			_win()
		elif portal_msg_cd <= 0.0:
			portal_msg_cd = 2.5
			audio.sfx("denied")
			hud.show_message("Das Portal ist versiegelt", "Es fehlen noch %d Kristalle." % (boss_count - crystals))


func dragon_hall_has(pt: Vector2i) -> bool:
	return dragon != null and Rect2i(level["dragon"]["hall"]).has_point(pt)


func _win() -> void:
	state = "won"
	Progress.mark_done(level_num)
	audio.play_music("victory")
	effects.burst(player.position, Color(0.6, 0.9, 1.0), 80, 300.0)
	hud.show_victory()


func has_next_level() -> bool:
	return level_num < Levels.COUNT


func player_died() -> void:
	state = "dead"
	dead_timer = 2.0
	deaths += 1
	audio.sfx("death")
	effects.burst(player.position, Color(0.9, 0.2, 0.2), 40, 200.0)


func _respawn() -> void:
	# laufende Bosskämpfe zurücksetzen
	for i in range(1, boss_count + 1):
		if boss_state[i] == BOSS_FIGHT:
			boss_state[i] = BOSS_IDLE
			_spawn_boss(i)
	for e in enemies.duplicate():
		if e.has_meta("brood"):
			enemies.erase(e)
			e.queue_free()
	for pr in projectiles.duplicate():
		pr.queue_free()
	projectiles.clear()
	player.revive(checkpoint)
	camera.position = checkpoint
	camera.reset_smoothing()
	audio.play_music("dungeon")
	state = "play"
	hud.show_message("Weiter geht's!", "")


func next_level() -> void:
	Engine.set_meta("level", level_num + 1)
	get_tree().reload_current_scene()


func to_menu() -> void:
	get_tree().change_scene_to_file(START_SCENE)


## Schwerthieb des Spielers: trifft Gegner, Projektile und rissige Wände.
func player_attack(origin: Vector2, facing: Vector2, weapon: int) -> void:
	var reach := 40.0
	var dmg := 1 if weapon == 0 else 2
	var hit_any := false
	for e in enemies.duplicate():
		if not is_instance_valid(e) or not e.is_hittable():
			continue
		var to: Vector2 = e.position - origin
		var d := to.length()
		if d > reach + e.radius:
			continue
		if d > e.radius + 6.0 and absf(facing.angle_to(to)) > deg_to_rad(75):
			continue
		hit_any = true
		e.take_hit(dmg, to.normalized() if d > 0.1 else facing, weapon)
	# Drache (nur einfrieren mit Eis)
	if dragon and dragon.hit_test(origin + facing * 24.0, 30.0):
		hit_any = true
		if weapon >= 2:
			dragon.freeze(2.8)
			audio.sfx("freeze")
			effects.burst(origin + facing * 24.0, Color(0.6, 0.9, 1.0), 16, 140.0)
		else:
			audio.sfx("clank")
	# Projektile zerschlagen
	for pr in projectiles.duplicate():
		if is_instance_valid(pr) and pr.hostile and pr.position.distance_to(origin + facing * 22.0) < 30.0 + pr.radius:
			effects.burst(pr.position, pr.color(), 8, 90.0)
			pr.kill()
	# Rissige Wände
	if weapon >= 1:
		var probes := [facing * 30.0, facing.rotated(0.5) * 28.0, facing.rotated(-0.5) * 28.0]
		var broken := {}
		for o in probes:
			var t := world_to_tile(origin + o)
			if tile_at(t.x, t.y) == "C" and not broken.has(t):
				broken[t] = true
		for t in broken:
			set_tile(t.x, t.y, ".")
			effects.burst(tile_center(t.x, t.y), Color(0.55, 0.45, 0.35), 26, 180.0)
			effects.burst(tile_center(t.x, t.y), Color(1.0, 0.5, 0.1), 12, 120.0)
			audio.sfx("wall_break")
			shake = 7.0
			hit_any = true
	elif not hit_any:
		var t := world_to_tile(origin + facing * 30.0)
		if tile_at(t.x, t.y) == "C":
			audio.sfx("clank", -6.0)
			if hud.message_time <= 0.0:
				hud.show_message("Die Wand hat Risse...", "Mit einer stärkeren Klinge könnte sie brechen.")
	if hit_any:
		shake = maxf(shake, 2.5)


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)

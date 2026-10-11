extends SceneTree
## Automatischer Durchlauf aller Spielabschnitte (headless).
## Aufruf: godot --headless --script res://tools/autotest.gd

var main: Node
var frame := 0
var phase := 0
var phase_t := 0.0
var log_lines: Array = []
var ok := true
var done := {}
var shots := false
var rocks := false
var fire_hits := 0
var last_x := 0


func once(k: String) -> bool:
	if done.has(k):
		return false
	done[k] = true
	return true


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func check(name: String, cond: bool) -> void:
	print(("OK   " if cond else "FAIL ") + name)
	if not cond:
		ok = false


func tp(tx: float, ty: float) -> void:
	main.player.position = Vector2((tx + 0.5) * 32, (ty + 0.5) * 32)


func kill_boss(i: int) -> void:
	var b = main.boss_nodes[i]
	var guard := 0
	while is_instance_valid(b) and main.boss_state[i] != main.BOSS_DONE and guard < 50:
		b.hit_cd = 0.0
		if b.has_method("start_fight") and i == 2:
			b.mode = "up"
		b.take_hit(2, Vector2.RIGHT, 2)
		guard += 1


func _process(dt: float) -> bool:
	frame += 1
	phase_t += dt
	match phase:
		0:
			if frame == 3:
				main.start_game()
				main.touch_dir = Vector2.RIGHT
			if phase_t > 3.0:
				var d: float = main.player.position.distance_to(main.RING_CENTER)
				check("Ringe halten den Helden (Abstand %.1f)" % d, d > 15.0 and d < main.RING_RADII[3])
				_next()
		1:
			# Einfacher Bot: laeuft zur Luecke des naechsten Rings, dann zum Ausgang
			var p: Vector2 = main.player.position
			var C: Vector2 = main.RING_CENTER
			var d: float = p.distance_to(C)
			var target: Vector2 = main.tile_center(14, 16) + Vector2(16, 0)
			for i in main.RING_RADII.size():
				var r: float = main.RING_RADII[i]
				if d < r:
					target = C + Vector2.from_angle(main.ring_angles[i]) * (r + 20.0)
					break
			if d > main.RING_RADII[3] + 8.0 and p.y < 13 * 32 and absf(p.x - target.x) > 8.0:
				target = Vector2(target.x, p.y + 20.0)
			main.touch_dir = (target - p).normalized()
			if main.world_to_tile(p).y >= 15:
				check("Bot entkommt den Scheiben in %.1f s" % phase_t, true)
				main.touch_dir = Vector2.ZERO
				_next()
			elif phase_t > 90.0:
				check("Bot entkommt den Scheiben (steckt bei %s)" % main.world_to_tile(p), false)
				_next()
		2:
			tp(4, 21)
			_next()
		3:
			if phase_t > 0.2:
				check("Feuerschwert eingesammelt", main.player.weapon == 1)
				tp(14.5, 18)
				main.player.facing = Vector2.DOWN
				main.player.cooldown = 0
				main.player.try_attack()
				check("Rissige Wand zerstoert", main.tile_at(14, 19) == "." and main.tile_at(15, 19) == ".")
				_next()
		4:
			tp(14.5, 24)
			if phase_t > 0.1:
				check("Ritterkampf gestartet", main.boss_state[1] == main.BOSS_FIGHT)
				check("Tor a geschlossen", main.is_solid(14, 20))
				_next()
		5:
			main.player.invuln = 5.0
			main.player.hp = main.player.max_hp
			if phase_t > 6.0:
				check("Ritter lebt nach 6 s Kampf", is_instance_valid(main.boss_nodes[1]))
				var k = main.boss_nodes[1]
				var hp0: int = k.hp
				main.player.position = k.position + Vector2(-28, 0)
				main.player.facing = Vector2.RIGHT
				main.player.cooldown = 0
				k.hit_cd = 0
				main.player.try_attack()
				check("Schwert trifft den Ritter (%d -> %d)" % [hp0, k.hp], k.hp < hp0)
				kill_boss(1)
				check("Ritter besiegt", main.boss_state[1] == main.BOSS_DONE)
				check("Ausgang A offen", not main.is_solid(10, 30))
				_next()
		6:
			if phase_t > 0.2 and main.pickups.size() > 0:
				main.player.position = main.pickups[main.pickups.size() - 1].position
			if phase_t > 0.5:
				check("Kristall 1", main.crystals == 1)
				# Tod testen: Respawn am Checkpoint
				main.player.invuln = 0
				main.player.hurt(99, Vector2.UP)
				check("Spieler tot", main.state == "dead")
				_next()
		7:
			if phase_t > 2.5:
				check("Respawn", main.state == "play" and main.player.hp == main.player.max_hp)
				# Feuerfeld: brennende Kachel suchen
				var found := false
				for x in range(6, 18):
					if main.fire_burning_at(x, 36) == 2:
						tp(x, 36)
						found = true
						break
				check("Brennende Duese gefunden", found)
				main.player.invuln = 0
				_next()
		8:
			if phase_t > 0.1:
				check("Feuer wirft zurueck", main.world_to_tile(main.player.position) == Vector2i(4, 36))
				phase = 80
				phase_t = 0.0
		80:
			# Bot ueberquert das Feuerfeld im Rhythmus (Reihe 36)
			main.player.hp = main.player.max_hp
			var p: Vector2 = main.player.position
			var best_x := -1
			var cur: int = main.world_to_tile(p).x
			for x in range(17, 5, -1):
				var f: float = fposmod(main.time / main.FIRE_STEP - (x - 6), 4.0)
				if f >= 2.05 and f < 3.2 and x >= cur and (cur >= 6 or x == 6):
					best_x = x
			var tx: float = 4.5 if best_x < 0 else best_x + 0.5
			if best_x < 0 and cur >= 6:
				tx = p.x / 32.0
			if cur >= 17:
				tx = 19.5
			if main.world_to_tile(p).x >= 18:
				check("Bot ueberquert Feuerfeld in %.1f s (Treffer: %d)" % [phase_t, fire_hits], fire_hits <= 1)
				main.touch_dir = Vector2.ZERO
				phase = 81
				phase_t = 0.0
			else:
				var want := Vector2(tx * 32, 36.5 * 32) - p
				main.touch_dir = want.normalized() if want.length() > 3.0 else Vector2.ZERO
				if main.world_to_tile(p) == Vector2i(4, 36) and last_x > 6:
					fire_hits += 1
				last_x = main.world_to_tile(p).x
				if phase_t > 40.0:
					check("Bot ueberquert Feuerfeld", false)
					phase = 81
		81:
			tp(23, 36)
			phase = 9
			phase_t = 0.0
		9:
			main.player.invuln = 5.0
			main.player.hp = main.player.max_hp
			if phase_t > 0.1 and once("krake"):
				check("Krakenkampf gestartet", main.boss_state[2] == main.BOSS_FIGHT)
			if main.projectiles.size() > 0 or main.audio.last_played.has("ink"):
				shots = true
			var o = main.boss_nodes[2]
			if o != null and o.mode == "up" and once("okrake"):
				var pool: Rect2 = o.POOL
				var pp: Vector2 = o.position
				# naechster Punkt am Ufer
				var cands := [Vector2(pool.position.x - 11, pp.y), Vector2(pool.end.x + 11, pp.y), Vector2(pp.x, pool.position.y - 11), Vector2(pp.x, pool.end.y + 11)]
				var best: Vector2 = cands[0]
				for c in cands:
					if c.distance_to(pp) < best.distance_to(pp):
						best = c
				main.player.position = best
				main.player.facing = (pp - best).normalized()
				main.player.cooldown = 0
				o.hit_cd = 0
				var hp1: int = o.hp
				main.player.try_attack()
				check("Schwert trifft die Krake vom Ufer (%d -> %d)" % [hp1, o.hp], o.hp < hp1)
			if phase_t > 10.0:
				check("Krake hat geschossen", shots)
				kill_boss(2)
				check("Krake besiegt", main.boss_state[2] == main.BOSS_DONE)
				_next()
		10:
			if phase_t > 0.2:
				tp(24, 36)
			if phase_t > 0.5:
				check("Kristall 2", main.crystals == 2)
				tp(42, 37)
				_next()
		11:
			if phase_t > 0.2:
				check("Herz-Kristall: 7 Herzen", main.player.max_hp == 7)
				tp(53.5, 34)
				_next()
		12:
			main.player.invuln = 5.0
			main.player.hp = main.player.max_hp
			if main.projectiles.size() > 0:
				rocks = true
			if phase_t > 0.2 and once("golem"):
				check("Golemkampf gestartet", main.boss_state[3] == main.BOSS_FIGHT)
				var g = main.boss_nodes[3]
				var hp0: int = g.hp
				g.take_hit(2, Vector2.RIGHT, 1)
				check("Golem immun gegen Feuer", g.hp == hp0)
			if phase_t > 8.0:
				check("Golem hat Felsen gestampft", rocks)
				main.player.weapon = 2
				kill_boss(3)
				check("Golem besiegt", main.boss_state[3] == main.BOSS_DONE)
				check("Ausgang G offen", not main.is_solid(60, 32))
				_next()
		13:
			if phase_t > 0.2 and main.pickups.size() > 0:
				main.player.position = main.pickups[main.pickups.size() - 1].position
			if phase_t > 0.5:
				check("Kristall 3", main.crystals == 3)
				tp(61.5, 11)
				_next()
		14:
			# Drachenhalle: 8 s ohne Schutz
			if phase_t > 8.0:
				print("  HP nach Drachenhalle: ", main.player.hp, " Status: ", main.state)
				main.player.invuln = 0
				main.player.dead = false
				main.state = "play"
				main.player.hp = 7
				main.dragon.freeze(5.0)
				check("Drache eingefroren -> harmlos", not main.dragon.touches(main.dragon.seg_pos[0], 10.0))
				tp(30, 6)
				_next()
		15:
			if phase_t > 0.3:
				check("Sieg", main.state == "won")
				_next()
		16:
			print("ERGEBNIS: ", "ALLES OK" if ok else "FEHLER")
			quit(0 if ok else 1)
	return false


func _next() -> void:
	phase += 1
	phase_t = 0.0

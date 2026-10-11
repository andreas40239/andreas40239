extends SceneTree
## Automatischer Durchlauf beider Level (headless).
## Aufruf: godot --headless --script res://tools/autotest.gd

var main: Node
var ok := true
var frame_dt := 0.0


func _initialize() -> void:
	_run()


func check(name: String, cond: bool) -> void:
	print(("OK   " if cond else "FAIL ") + name)
	if not cond:
		ok = false


func wait(sec: float) -> void:
	var end: float = main.time + sec
	while main.time < end:
		await process_frame


func frames(n: int) -> void:
	for i in n:
		await process_frame


func tp(tx: float, ty: float) -> void:
	main.player.position = Vector2((tx + 0.5) * 32, (ty + 0.5) * 32)


func protect() -> void:
	main.player.invuln = 5.0
	main.player.hp = main.player.max_hp


func load_level(n: int) -> void:
	if main:
		main.queue_free()
		await process_frame
	Engine.set_meta("level", n)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(3)


func kill_boss(i: int) -> void:
	var guard := 0
	while main.boss_state[i] != main.BOSS_DONE and guard < 50:
		var b = main.boss_nodes[i]
		b.hit_cd = 0.0
		if main.boss_info[i]["kind"] == "octopus":
			b.mode = "up"
		b.take_hit(2, Vector2.RIGHT, 2 if main.boss_info[i]["kind"] != "icegolem" else 1)
		guard += 1


func collect_last_pickup() -> void:
	await wait(0.2)
	main.player.position = main.pickups[main.pickups.size() - 1].position
	await wait(0.2)


func attack(facing: Vector2) -> void:
	main.player.facing = facing
	main.player.cooldown = 0
	main.player.try_attack()


func _run() -> void:
	await test_level1()
	await test_level2()
	print("ERGEBNIS: ", "ALLES OK" if ok else "FEHLER")
	quit(0 if ok else 1)


func test_level1() -> void:
	print("--- Level 1")
	await load_level(1)
	check("Startet direkt im Spiel", main.state == "play")
	check("Start mit Holzschwert", main.player.weapon == 0)
	# Bot: zur Lücke des nächsten Rings laufen, dann zum Ausgang
	var t0: float = main.time
	var escaped := false
	while main.time - t0 < 90.0:
		var p: Vector2 = main.player.position
		var C: Vector2 = main.ring_center
		var d: float = p.distance_to(C)
		var target: Vector2 = main.tile_center(14, 16) + Vector2(16, 0)
		for i in main.ring_radii.size():
			var r: float = main.ring_radii[i]
			if d < r:
				target = C + Vector2.from_angle(main.ring_angles[i]) * (r + 20.0)
				break
		if d > main.ring_radii[3] + 8.0 and p.y < 13 * 32 and absf(p.x - target.x) > 8.0:
			target = Vector2(target.x, p.y + 20.0)
		main.touch_dir = (target - p).normalized()
		if main.world_to_tile(p).y >= 15:
			escaped = true
			break
		await process_frame
	main.touch_dir = Vector2.ZERO
	check("Bot entkommt den Scheiben in %.1f s" % (main.time - t0), escaped)

	tp(4, 21)
	await wait(0.2)
	check("Feuerschwert eingesammelt", main.player.weapon == 1)
	tp(14.5, 18)
	attack(Vector2.DOWN)
	check("Rissige Wand zerstört", main.tile_at(14, 19) == "." and main.tile_at(15, 19) == ".")

	tp(14.5, 24)
	await wait(0.1)
	check("Ritterkampf gestartet", main.boss_state[1] == main.BOSS_FIGHT)
	check("Tor a geschlossen", main.is_solid(14, 20))
	var t1: float = main.time
	while main.time - t1 < 5.0:
		protect()
		await process_frame
	var k = main.boss_nodes[1]
	var hp0: int = k.hp
	main.player.position = k.position + Vector2(-28, 0)
	k.hit_cd = 0
	attack(Vector2.RIGHT)
	check("Schwert trifft den Ritter (%d -> %d)" % [hp0, k.hp], k.hp < hp0)
	kill_boss(1)
	check("Ritter besiegt, Ausgang offen", main.boss_state[1] == main.BOSS_DONE and not main.is_solid(10, 30))
	await collect_last_pickup()
	check("Kristall 1", main.crystals == 1)

	main.player.invuln = 0
	main.player.hurt(99, Vector2.UP)
	check("Spieler tot", main.state == "dead")
	await wait(2.3)
	check("Respawn mit vollen Herzen", main.state == "play" and main.player.hp == main.player.max_hp)

	# Feuerfeld: ein Kind läuft einfach geradeaus hinüber
	var worst := 0
	for attempt in 8:
		tp(4, 36)
		main.player.hp = main.player.max_hp
		main.player.invuln = 0
		await wait(randf_range(0.0, 3.4))
		var hp_before: int = main.player.hp
		main.touch_dir = Vector2.RIGHT
		var t2: float = main.time
		while main.world_to_tile(main.player.position).x < 18 and main.time - t2 < 15.0:
			await process_frame
		main.touch_dir = Vector2.ZERO
		worst = maxi(worst, hp_before - main.player.hp)
	check("Feuerfeld geradeaus: höchstens 1 Herz verloren (schlimmster Lauf: %d)" % worst, worst <= 1)
	# Wer wartet, bis die Flammen ausgehen, kommt ohne Schaden hinüber
	tp(4, 36)
	main.player.invuln = 0
	while main.fire_burning_at(8, 36) != 2:
		await process_frame
	while main.fire_burning_at(8, 36) == 2:
		await process_frame
	var hp_w: int = main.player.hp
	main.touch_dir = Vector2.RIGHT
	while main.world_to_tile(main.player.position).x < 18:
		await process_frame
	main.touch_dir = Vector2.ZERO
	check("Losgehen beim Erlöschen: kein Schaden", main.player.hp == hp_w)
	# Wer wartet, bis die Flammen vorbei sind, bleibt heil
	while main.fire_burning_at(8, 36) != 2:
		await process_frame
	tp(8, 36)
	var found := true
	main.player.invuln = 0
	var hp1: int = main.player.hp
	await wait(0.05)
	check("Brennende Düse kostet ein Herz", found and main.player.hp == hp1 - 1)

	tp(23, 36)
	await wait(0.1)
	check("Krakenkampf gestartet", main.boss_state[2] == main.BOSS_FIGHT)
	var shots := false
	var t3: float = main.time
	var tested := false
	while main.time - t3 < 10.0:
		protect()
		if main.audio.last_played.has("ink"):
			shots = true
		var o = main.boss_nodes[2]
		if not tested and o.mode == "up":
			tested = true
			var pool: Rect2 = o.POOL
			var pp: Vector2 = o.position
			var cands := [Vector2(pool.position.x - 11, pp.y), Vector2(pool.end.x + 11, pp.y), Vector2(pp.x, pool.position.y - 11), Vector2(pp.x, pool.end.y + 11)]
			var best: Vector2 = cands[0]
			for c in cands:
				if c.distance_to(pp) < best.distance_to(pp):
					best = c
			main.player.position = best
			o.hit_cd = 0
			var h: int = o.hp
			attack((pp - best).normalized())
			check("Schwert trifft die Krake vom Ufer (%d -> %d)" % [h, o.hp], o.hp < h)
		await process_frame
	check("Krake hat geschossen", shots)
	kill_boss(2)
	check("Krake besiegt", main.boss_state[2] == main.BOSS_DONE)
	await collect_last_pickup()
	check("Kristall 2", main.crystals == 2)
	tp(42, 37)
	await wait(0.2)
	check("Herz-Kristall: 7 Herzen", main.player.max_hp == 7)

	tp(53.5, 34)
	await wait(0.2)
	check("Golemkampf gestartet", main.boss_state[3] == main.BOSS_FIGHT)
	var g = main.boss_nodes[3]
	var gh: int = g.hp
	g.take_hit(2, Vector2.RIGHT, 1)
	check("Golem immun gegen Feuer", g.hp == gh)
	var t4: float = main.time
	var rocks := false
	while main.time - t4 < 8.0:
		protect()
		if main.projectiles.size() > 0:
			rocks = true
		await process_frame
	check("Golem hat Felsen gestampft", rocks)
	main.player.weapon = 2
	kill_boss(3)
	check("Golem besiegt, Ausgang offen", main.boss_state[3] == main.BOSS_DONE and not main.is_solid(60, 32))
	await collect_last_pickup()
	check("Kristall 3", main.crystals == 3)

	tp(61.5, 11)
	await wait(8.0)
	print("  HP nach 8 s Drachenhalle: ", main.player.hp, " Status: ", main.state)
	if main.state == "dead":
		await wait(2.5)
	main.player.hp = 7
	main.dragon.freeze(5.0)
	check("Drache eingefroren -> harmlos", not main.dragon.touches(main.dragon.seg_pos[0], 10.0))
	tp(30, 6)
	await wait(0.3)
	check("Sieg Level 1", main.state == "won")
	check("Weiteres Level vorhanden", main.has_next_level())


func test_level2() -> void:
	print("--- Level 2")
	await load_level(2)
	check("Level 2 geladen", main.level_num == 2 and main.state == "play")
	check("Start mit Feuerschwert", main.player.weapon == 1)
	check("Zwei Bosse", main.boss_count == 2)
	# Eis: Schwung bleibt nach dem Loslassen
	tp(19, 7)
	main.touch_dir = Vector2.RIGHT
	await wait(0.8)
	main.touch_dir = Vector2.ZERO
	var x0: float = main.player.position.x
	await wait(0.3)
	check("Auf dem Eis rutscht man weiter (%.0f px)" % (main.player.position.x - x0), main.player.position.x - x0 > 15.0)
	# Tür ohne Schlüssel
	tp(33, 6)
	main.touch_dir = Vector2.RIGHT
	await wait(0.4)
	main.touch_dir = Vector2.ZERO
	check("Tür ohne Schlüssel bleibt zu", main.tile_at(34, 6) == "L")
	tp(32, 11)
	await wait(0.2)
	check("Schlüssel 1", main.keys == 1)
	tp(33, 6.5)
	main.touch_dir = Vector2.RIGHT
	await wait(0.4)
	main.touch_dir = Vector2.ZERO
	check("Tür geöffnet", main.tile_at(34, 6) == "." and main.tile_at(34, 7) == "." and main.keys == 0)

	tp(44, 9)
	await wait(0.1)
	check("Spinnenkampf gestartet", main.boss_state[1] == main.BOSS_FIGHT)
	var webs := false
	var brood := false
	var t0: float = main.time
	while main.time - t0 < 12.0:
		protect()
		if main.audio.last_played.has("web"):
			webs = true
		for e in main.enemies:
			if e.has_meta("brood"):
				brood = true
		await process_frame
	check("Spinne schießt Netze", webs)
	check("Spinne ruft kleine Spinnen", brood)
	var sp = main.boss_nodes[1]
	main.player.position = sp.position + Vector2(-30, 0)
	sp.hit_cd = 0
	var h: int = sp.hp
	attack(Vector2.RIGHT)
	check("Schwert trifft die Spinne", sp.hp < h)
	kill_boss(1)
	var left := 0
	for e in main.enemies:
		if e.has_meta("brood"):
			left += 1
	check("Spinne besiegt, kleine Spinnen weg", main.boss_state[1] == main.BOSS_DONE and left == 0)
	await collect_last_pickup()
	check("Kristall 1", main.crystals == 1)
	# Netz verlangsamt nur
	main.player.invuln = 0
	var hp_w: int = main.player.hp
	main.spawn_projectile(main.player.position + Vector2(-40, 0), Vector2(200, 0), "web")
	await wait(0.4)
	check("Netz verlangsamt ohne Schaden", main.player.slow > 0.0 and main.player.hp == hp_w)

	tp(48, 31)
	await wait(0.2)
	check("Schlüssel 2", main.keys == 1)
	tp(22, 31.5)
	main.touch_dir = Vector2.LEFT
	await wait(0.4)
	main.touch_dir = Vector2.ZERO
	check("Zweite Tür geöffnet", main.tile_at(21, 31) == ".")
	tp(11, 30)
	await wait(0.1)
	check("Eisgolem-Kampf gestartet", main.boss_state[2] == main.BOSS_FIGHT)
	var g = main.boss_nodes[2]
	var gh: int = g.hp
	g.take_hit(2, Vector2.RIGHT, 0)
	check("Eisgolem immun gegen Holz", g.hp == gh)
	g.hit_cd = 0
	g.take_hit(2, Vector2.RIGHT, 1)
	check("Feuer schmilzt den Eisgolem", g.hp < gh)
	var t1: float = main.time
	while main.time - t1 < 6.0:
		protect()
		await process_frame
	kill_boss(2)
	check("Eisgolem besiegt, Ausgang offen", main.boss_state[2] == main.BOSS_DONE and not main.is_solid(8, 27))
	await collect_last_pickup()
	check("Kristall 2", main.crystals == 2)
	tp(9, 21)
	await wait(0.3)
	check("Sieg Level 2", main.state == "won")
	check("Kein weiteres Level", not main.has_next_level())

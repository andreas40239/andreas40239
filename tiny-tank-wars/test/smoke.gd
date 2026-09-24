# Headless smoke test: boots the real scene tree, drives a battle
# through AI turns and verifies core rules. Run with:
#   godot --headless -s res://test/smoke.gd
extends SceneTree

var frames_left := 40000
var battle
var phase := 0
var fails := 0
var audio            # the audio autoload instance this test creates
# Lambdas capture locals by value, so signal results must land on members.
var _landed := Vector2.ZERO
var _got := false
var setup_done := false

func _init() -> void:
	call_deferred("_setup")

func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + msg)
		print("FAIL: ", msg)
	else:
		print("ok: ", msg)

func _setup() -> void:
	# Autoloads are not auto-instanced with -s, create them manually.
	var g = load("res://src/game.gd").new()
	g.name = "G"
	root.add_child(g)
	var a = load("res://src/audio.gd").new()
	a.name = "A"
	root.add_child(a)
	audio = a
	var main = load("res://src/main.gd").new()
	main.name = "Main"
	root.add_child(main)
	await process_frame
	check(main.screen != null, "main menu built")
	main._show_mode_select()
	await process_frame
	main._show_level_select(1)
	await process_frame
	# Start an all-AI battle so it plays itself: humans=0 is not a real mode,
	# use humans=1 but drive the human turn manually.
	main._start_battle(1, 3)
	await process_frame
	battle = main.screen
	check(battle is Battle, "battle instantiated")
	check(battle.tanks.size() == 4, "4 tanks spawned")
	check(battle.terrain.spawn_points.size() == 4, "4 spawn platforms")
	# Spawn distance rule (GDD 13.1).
	var sp: Array = battle.terrain.spawn_points
	for i in range(4):
		for j in range(i + 1, 4):
			check(absf(sp[i].x - sp[j].x) >= 200.0, "spawns %d/%d >= 200 px apart" % [i, j])
	check(battle.wind == 0.0, "no wind at level 3")
	# Sim sanity: a 45deg shot lands to the right.
	var t0 = battle.tanks[0]
	var res = Sim.trace(Vector2(300, 300), 45.0, 60.0, 0.0, battle.terrain, [], null)
	check(res["impact"].x > 300.0, "45deg shot travels right")
	var res2 = Sim.trace(Vector2(300, 300), 135.0, 60.0, 0.0, battle.terrain, [], null)
	check(res2["impact"].x < 300.0, "135deg shot travels left")
	# AI produces sane shots for every tier and personality.
	battle.tanks[1].drama = false
	for tier in range(4):
		for pers in range(4):
			battle.tanks[1].ai_tier = tier
			battle.tanks[1].personality = pers
			var shot = AI.choose_shot(battle.tanks[1], battle.tanks, battle.terrain, 10.0)
			check(shot["angle"] >= 0.0 and shot["angle"] <= 180.0, "tier %d pers %d angle in range" % [tier, pers])
			check(shot["power"] >= 0.0 and shot["power"] <= 100.0, "tier %d pers %d power in range" % [tier, pers])
	# Damage falloff resolution.
	var victim = battle.tanks[1]
	var hp0: float = victim.hp
	battle._resolve_explosion(victim.center(), victim, battle.tanks[0])
	check(victim.hp == hp0 - 25.0, "direct hit deals 25 (got %f)" % (hp0 - victim.hp))
	check(battle.tanks[0].damage_dealt == 25.0, "shooter credited damage")
	# Shield blocks direct hit.
	var v2 = battle.tanks[2]
	v2.shield_active = true
	battle._resolve_explosion(v2.center(), v2, battle.tanks[0])
	check(v2.hp == 100.0, "iron cover blocked direct hit")
	check(v2.shield_cracked, "shield cracked after block")
	# --- Music tracks -------------------------------------------------
	check(audio.MUSIC_TRACKS.size() == 3, "three music tracks available")
	var first_track: String = audio.track_name()
	var second: String = audio.next_track()
	check(second != first_track, "next_track switches song (%s -> %s)" % [first_track, second])
	audio.next_track()
	check(audio.next_track() == first_track, "track list cycles back around")

	# --- Prediction matches the real shell ------------------------------
	# The Arc Toggle promises an exact path; verify a live projectile lands
	# where the trace said it would.
	var shooter = battle.tanks[0]
	shooter.angle = 55.0
	shooter.power = 70.0
	var pred = Sim.trace(shooter.barrel_tip(), 55.0, 70.0, 0.0,
			battle.terrain, battle.tanks, shooter)
	var proj = Projectile.new()
	battle.add_child(proj)
	proj.launch(shooter.barrel_tip(), 55.0, 70.0, 0.0, battle.terrain, battle.tanks, shooter)
	proj.impact.connect(func(pos, _tk, _lost): _landed = pos; _got = true)
	var pguard := 0
	while not _got and pguard < 2000:
		await physics_frame
		pguard += 1
	check(_got, "test projectile resolved")
	if _got:
		var err: float = _landed.distance_to(pred["impact"])
		check(err < 1.0, "live shell lands where predicted (%.2f px off)" % err)

	# --- Drama robot: seven near misses, then it closes in ---------------
	var ace = battle.tanks[1]
	ace.drama = true
	ace.ai_memory.clear()
	check(ace.display_name == "Ace", "drama robot is named Ace (got %s)" % ace.display_name)
	var ace_victim = battle.tanks[0]
	ace_victim.hp = 100.0
	var radius := 40.0      # robots carry no upgrades
	var base_dmg := 25.0
	var early_hits := 0
	var late_damage := 0.0
	var dists := []
	for shot_i in range(12):
		ace.shots_taken = shot_i
		var ashot = AI.choose_shot(ace, battle.tanks, battle.terrain, 0.0)
		var ares = Sim.trace(ace.barrel_tip_for(ashot["angle"]), ashot["angle"], ashot["power"],
				0.0, battle.terrain, battle.tanks, ace)
		var d: float = 0.0 if ares["tank"] == ace_victim else ares["impact"].distance_to(ace_victim.center())
		dists.append(d)
		var dmg: float = 0.0 if d >= radius else floorf(base_dmg * (1.0 - d / radius))
		if shot_i < 7:
			if dmg > 0.0:
				early_hits += 1
			check(dmg == 0.0, "drama shot %d does no damage (%.0f px away)" % [shot_i + 1, d])
		else:
			late_damage += dmg
	check(early_hits == 0, "all seven opening shots missed")
	check(late_damage >= 30.0, "shots 8-12 do real damage (%d total)" % int(late_damage))
	var early_avg := 0.0
	for i in range(7):
		early_avg += dists[i]
	early_avg /= 7.0
	var late_avg := 0.0
	for i in range(7, 12):
		late_avg += dists[i]
	late_avg /= 5.0
	check(late_avg < early_avg, "hits close in over time (%.0f px -> %.0f px)" % [early_avg, late_avg])

	# --- Each robot duels its own human ---------------------------------
	main._start_battle(2, 4)
	await process_frame
	var b2 = main.screen
	check(b2.humans == 2, "two-player battle started")
	var seats := []
	for t in b2.tanks:
		if not t.is_human:
			seats.append(t.target_seat)
			var tgt = AI.pick_target(t, b2.tanks)
			check(tgt != null and tgt.is_human, "robot %s targets a human" % t.display_name)
			check(tgt.seat == t.target_seat, "robot %s duels its assigned player" % t.display_name)
	check(seats.size() == 2, "two robots in a 2-player game")
	check(seats[0] != seats[1], "the robots take different players (%s)" % str(seats))
	# When a robot's human is knocked out it must still find someone.
	b2.tanks[0].alive = false
	for t in b2.tanks:
		if not t.is_human:
			check(AI.pick_target(t, b2.tanks) != null, "robot retargets after a player is out")
	b2.tanks[0].alive = true
	battle = b2

	# Now drive the actual turn loop: make everyone AI so it self-plays.
	for t in battle.tanks:
		t.is_human = false
		t.ai_tier = 3
	battle.humans = 0
	setup_done = true
	phase = 1

func _process(_delta: float) -> bool:
	frames_left -= 1
	if phase == 1 and battle != null and is_instance_valid(battle):
		if battle.state == battle.S.ENDED:
			print("battle ended cleanly after self-play")
			phase = 2
			_finish()
			return true
		if frames_left <= 0:
			# Not necessarily an error (AI may be slow to kill), but check state sanity.
			check(battle.state != battle.S.SETUP, "battle progressed past setup")
			check(battle.turn_count > 2, "multiple turns were taken (got %d)" % battle.turn_count)
			phase = 2
			_finish()
			return true
	elif frames_left <= 0:
		_finish()
		return true
	return false

func _finish() -> void:
	check(setup_done, "all setup checks ran to completion")
	print("SMOKE RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

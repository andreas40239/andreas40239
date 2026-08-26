# Headless smoke test: boots the real scene tree, drives a battle
# through AI turns and verifies core rules. Run with:
#   godot --headless -s res://test/smoke.gd
extends SceneTree

var frames_left := 3000
var battle
var phase := 0
var fails := 0

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
	# Now drive the actual turn loop: make everyone AI so it self-plays.
	for t in battle.tanks:
		t.is_human = false
		t.ai_tier = 3
	battle.humans = 0
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
	print("SMOKE RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

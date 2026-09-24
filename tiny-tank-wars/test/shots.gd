# Visual verification: boots the real game, walks the screens and saves PNGs.
#   xvfb-run godot --rendering-driver opengl3 -s res://test/shots.gd
extends SceneTree

var main
var battle
var g
var shot_dir := "/tmp/ttw_shots"

func _init() -> void:
	call_deferred("_run")

func snap(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [shot_dir, name])
	print("saved ", name)

func waitf(n: int) -> void:
	for i in range(n):
		await process_frame

func wait_aim() -> void:
	var guard := 0
	while battle.state != battle.S.AIM and guard < 900:
		await process_frame
		guard += 1

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	root.size = Vector2i(1280, 720)
	g = root.get_node("G")  # the real autoload; script mode already created it
	var a = root.get_node("A")
	g.unlocked_level = 12  # show a level-select grid and wind
	g.settings["full_path"] = false
	g.settings["map"] = 0
	main = load("res://src/main.gd").new()
	main.name = "Main"
	root.add_child(main)
	# Startup screen: title settled and a firework in the air.
	await waitf(150)
	snap("00_startup")
	main._show_menu()
	await waitf(8)
	snap("01_menu")
	main._show_mode_select()
	await waitf(5)
	snap("02_mode_select")
	g.settings["map"] = 2
	main._show_level_select(2)
	await waitf(5)
	snap("03_level_select")
	# Each map, zoomed right out during the first human turn.
	var names := ["hills", "snowy", "canyon", "towers"]
	for m in range(4):
		g.settings["map"] = m
		main._start_battle(1, 3)
		await waitf(4)
		battle = main.screen
		await wait_aim()
		battle.cam.fly_to(Vector2(1200, 450), BattleCam.MIN_ZOOM, 0.01)
		await waitf(12)
		snap("04_map_%s" % names[m])
	# Aim with the short hint, then with the full flight path on.
	g.settings["map"] = 1
	main._start_battle(1, 12)
	await waitf(4)
	battle = main.screen
	await wait_aim()
	await waitf(50)
	snap("05_aim_short")
	g.settings["full_path"] = true
	battle._update_preview()
	battle.cam.fly_to(battle.current_tank().position + Vector2(300, -120), 0.7, 0.01)
	await waitf(12)
	snap("06_aim_full_path")
	# Fire goes straight away.
	battle.aim_started_ms -= 1000
	battle._try_fire()
	await waitf(30)
	snap("07_flight")
	var guard := 0
	while battle.pending_shots > 0 and guard < 900:
		await process_frame
		guard += 1
	await waitf(20)
	snap("08_after_impact")
	# Pause panel.
	if battle.state != battle.S.ENDED:
		battle._show_pause_panel()
		await waitf(8)
		snap("09_pause")
		paused = false
		for c in battle.overlay_holder.get_children():
			c.queue_free()
	# Level end (force a victory) and the upgrade shop.
	if battle.state != battle.S.ENDED:
		for i in range(1, 4):
			battle.tanks[i].alive = false
		battle.tanks[0].damage_dealt = 180.0
		battle._end_level()
		await waitf(8)
		snap("10_level_end")
		for c in battle.overlay_holder.get_children():
			c.queue_free()
		g.seat(0)["points"] = 7
		battle._show_shop(0, 6)
		await waitf(8)
		snap("11_shop")
	quit(0)

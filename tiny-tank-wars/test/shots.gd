# Visual verification: boots the real game, walks the screens and saves PNGs.
#   xvfb-run godot --rendering-driver opengl3 -s res://test/shots.gd
extends SceneTree

var main
var battle
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

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	root.size = Vector2i(1280, 720)
	var g = load("res://src/game.gd").new()
	g.name = "G"
	root.add_child(g)
	var a = load("res://src/audio.gd").new()
	a.name = "A"
	root.add_child(a)
	g.unlocked_level = 12  # show a level-select grid and wind
	main = load("res://src/main.gd").new()
	main.name = "Main"
	root.add_child(main)
	await waitf(8)
	snap("01_menu")
	main._show_mode_select()
	await waitf(5)
	snap("02_mode_select")
	main._show_level_select(2)
	await waitf(5)
	snap("03_level_select")
	# Battle at level 12: wind active.
	main._start_battle(1, 12)
	await waitf(10)
	battle = main.screen
	# Let the intro banner play, then reach the aim state.
	await waitf(100)
	snap("04_battle_start")
	# Force the human aim state if not there yet.
	var guard := 0
	while battle.state != battle.S.AIM and guard < 600:
		await process_frame
		guard += 1
	await waitf(10)
	snap("05_aim")
	# Confirm state with exact arc shown.
	if battle.state == battle.S.AIM:
		battle._hold_to_confirm()
		battle._arc_visible = true
		battle.arc_btn.text = "Hide Path"
		battle._compute_arc()
		await waitf(8)
		snap("06_confirm_arc")
		# Fire!
		battle._do_fire()
		await waitf(30)
		snap("07_flight")
		# Wait for the resolution.
		guard = 0
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

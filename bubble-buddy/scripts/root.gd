extends Node
## Application shell: owns the screen stack and the end-of-run bookkeeping.

var _current: Node = null
var _game: BBGame = null


func _ready() -> void:
	# Portrait, 60fps, and a window that behaves on desktop as well as tablets.
	Engine.max_fps = 60
	get_window().min_size = Vector2i(360, 640)
	get_viewport().size_changed.connect(_fit_current)
	_show_menu()

	# A tiny smoke mode used by the build pipeline: runs the game headless for a
	# few seconds and prints a summary, so a broken build fails loudly in CI.
	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke":
			_run_smoke_test()
		elif arg == "--shots":
			_run_shots()
		elif arg == "--audio-check":
			_run_audio_check()
		elif arg == "--icons":
			_generate_icons()


func _swap(screen: Node) -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = screen
	add_child(screen)
	_fit_current()


## A Control whose parent is a plain Node does not inherit a rect, so full-screen
## screens are sized explicitly here and re-sized whenever the window changes.
func _fit_current() -> void:
	if _current == null or not is_instance_valid(_current):
		return
	if _current is Control:
		var v := get_viewport().get_visible_rect().size
		(_current as Control).position = Vector2.ZERO
		(_current as Control).size = v
		if _current.has_method("relayout"):
			_current.call("relayout", v)


func _show_menu() -> void:
	_game = null
	var menu := BBMainMenu.new()
	menu.play_requested.connect(_start_game)
	menu.stickers_requested.connect(_show_stickers)
	menu.dashboard_requested.connect(_show_dashboard)
	_swap(menu)
	Sound.set_zone_music(0)
	Sound.start_music()


func _start_game() -> void:
	var game := BBGame.new()
	game.exit_requested.connect(_on_run_finished)
	_game = game
	_swap(game)


func _show_stickers() -> void:
	var book := BBStickerBook.new()
	book.back_requested.connect(_show_menu)
	_swap(book)


func _show_dashboard() -> void:
	var dash := BBParentDashboard.new()
	dash.back_requested.connect(_show_menu)
	_swap(dash)


func _on_run_finished(summary: Dictionary) -> void:
	SaveData.record_run(
		summary["pearls"],
		summary["gates"],
		summary["seconds"],
		summary["quit_after_hit"],
		summary["zone"])
	_show_summary(summary)


## A calm end-of-swim card. No score pressure, no "try again" nagging.
func _show_summary(summary: Dictionary) -> void:
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.46, 0.83, 0.90)
	screen.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)

	var panel := BBUi.panel(BBUi.CREAM, 72)
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	panel.add_child(col)
	col.add_child(BBUi.label("What a lovely swim!", BBUi.FONT_TITLE, BBUi.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(BBUi.label("Pearls: %d" % summary["pearls"], BBUi.FONT_BIG, BBUi.TEAL, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(BBUi.label("Friends freed: %d" % summary["friends"], BBUi.FONT_BODY, BBUi.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(BBUi.label("Coral Gates: %d" % summary["gates"], BBUi.FONT_BODY, BBUi.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(BBUi.label("Stickers found: %d of %d" % [SaveData.sticker_count(), SaveData.TOTAL_STICKERS],
		BBUi.FONT_BODY, BBUi.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(BBUi.spacer(16))

	var again := BBUi.button("Swim again", BBUi.TEAL)
	again.pressed.connect(_start_game)
	col.add_child(again)

	var menu := BBUi.button("Home", BBUi.SUN)
	menu.add_theme_color_override("font_color", BBUi.INK)
	menu.pressed.connect(_show_menu)
	col.add_child(menu)

	_swap(screen)
	Sound.play("chest")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		SaveData.save_game()


# ---------------------------------------------------------------------------
# Smoke test (build pipeline only)
# ---------------------------------------------------------------------------

func _run_smoke_test() -> void:
	print("[smoke] starting Bubble Buddy smoke test")
	_start_game()
	await get_tree().process_frame
	var game := _game
	var elapsed := 0.0
	var frames := 0
	# Simulate roughly three minutes of play at 60fps, steering back and forth
	# and firing the Big Bubble, so every spawn pattern and interaction runs.
	while elapsed < 180.0:
		var dt := 1.0 / 60.0
		var b := game.player_bounds()
		game.player.target = Vector2(
			b.position.x + b.size.x * (0.5 + 0.45 * sin(elapsed * 1.7)),
			b.position.y + b.size.y * (0.5 + 0.35 * sin(elapsed * 0.9)))
		if fposmod(elapsed, 3.2) < dt:
			game.player.start_charge()
		if fposmod(elapsed + 0.4, 3.2) < dt:
			game.player.release_charge()
		game._process(dt)
		elapsed += dt
		frames += 1
		if frames % 60 == 0:
			await get_tree().process_frame
	print("[smoke] simulated %.1fs: pearls=%d gates=%d zone=%d friends=%d stickers=%d hits=%d" % [
		elapsed, game.pearls_run, game.gates_run, game.zone, game.friends_freed,
		SaveData.sticker_count(), SaveData.hits_taken])
	if game.gates_run < 1:
		print("[smoke] FAIL: no Coral Gate was reached")
		quit(1)
	elif game.pearls_run < 50:
		print("[smoke] FAIL: pearl flow too thin (%d)" % game.pearls_run)
		quit(1)
	else:
		print("[smoke] OK")
		quit(0)


func quit(code: int) -> void:
	get_tree().quit(code)


## Development helper: walks the app and saves screenshots of each screen.
func _run_shots() -> void:
	var dir := "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	print("[shots] writing to ", ProjectSettings.globalize_path(dir))

	await _settle(1.4)
	await _shot(dir, "01_menu")

	_start_game()
	await _settle(0.2)
	var game := _game
	await _simulate(game, 6.0)
	await _shot(dir, "02_game_early")

	await _simulate(game, 14.0)
	await _shot(dir, "03_game_mid")

	# Force each power-up so its look can be checked.
	game.player.shield = true
	await _simulate(game, 0.6)
	await _shot(dir, "04_shield")

	game.player.rainbow = 4.0
	game.player.charging = true
	game.player.charge = 0.8
	await _simulate(game, 1.2)
	await _shot(dir, "05_rainbow")
	game.player.charging = false
	game.player.rainbow = 0.0

	# Bring on a Coral Gate.
	game._pearls_since_gate = BBGame.GATE_PEARLS
	await _simulate(game, 3.4)
	await _shot(dir, "06_gate")
	await _simulate(game, 2.6)
	await _shot(dir, "07_after_gate")

	# A bump, to check the dizzy wobble.
	game.bump_player(game.player.position + Vector2(60, 0))
	await _simulate(game, 0.4)
	await _shot(dir, "08_dizzy")

	_show_stickers()
	await _settle(0.8)
	await _shot(dir, "09_stickers")

	_show_dashboard()
	await _settle(0.8)
	await _shot(dir, "10_dashboard")

	print("[shots] done")
	get_tree().quit(0)


func _settle(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


## Advances the game deterministically while still letting frames render.
func _simulate(game: BBGame, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		var b := game.player_bounds()
		game.player.target = Vector2(
			b.position.x + b.size.x * (0.5 + 0.42 * sin(elapsed * 1.5 + game.run_time)),
			b.position.y + b.size.y * 0.55)
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, name])
	print("[shots] saved ", name)


## Development helper: confirms the synthesised audio is actually audible,
## since a build machine usually has no sound device to listen with.
func _run_audio_check() -> void:
	var names := ["pearl", "small_bubble", "big_bubble", "push_crab", "zap", "rescue",
		"gate", "rainbow", "shield", "current", "dizzy", "pop", "button", "giggle",
		"sticker", "puff", "chest"]
	var failures := 0
	for n in names:
		var peak := Sound.debug_peak(n)
		var seconds := Sound.debug_seconds(n)
		print("[audio] %-13s peak=%.3f  %.2fs" % [n, peak, seconds])
		if peak < 0.05:
			failures += 1
			print("[audio] FAIL: ", n, " is silent")
	# Wait for the music worker thread to finish rendering its loops.
	var waited := 0.0
	while not Sound.debug_music_ready() and waited < 30.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	for track in ["music_bright", "music_mellow", "music_percussion"]:
		var peak := Sound.debug_peak(track)
		var seconds := Sound.debug_seconds(track)
		print("[audio] %-13s peak=%.3f  %.2fs" % [track, peak, seconds])
		if peak < 0.05:
			failures += 1
			print("[audio] FAIL: ", track, " is silent")
	if failures > 0:
		print("[audio] %d silent stream(s)" % failures)
		get_tree().quit(1)
	else:
		print("[audio] OK")
		get_tree().quit(0)


## Build helper: renders the Android launcher icons from icon.svg so the icon
## set never drifts out of sync with the source art.
func _generate_icons() -> void:
	var tex: Texture2D = load("res://icon.svg")
	var source := tex.get_image()
	source.convert(Image.FORMAT_RGBA8)

	var legacy := source.duplicate() as Image
	legacy.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	legacy.save_png("res://icons/icon_192.png")

	# Adaptive foreground: Android masks the outer third, so the artwork is
	# scaled down and centred inside a transparent 432px canvas.
	var inner := source.duplicate() as Image
	inner.resize(280, 280, Image.INTERPOLATE_LANCZOS)
	var fg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	fg.fill(Color(0, 0, 0, 0))
	fg.blit_rect(inner, Rect2i(0, 0, 280, 280), Vector2i(76, 76))
	fg.save_png("res://icons/adaptive_foreground_432.png")

	# Adaptive background: the same sea gradient as the icon itself.
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	for y in 432:
		var k := float(y) / 431.0
		var col := Color(0.55, 0.91, 0.94).lerp(Color(0.16, 0.65, 0.77), k)
		for x in 432:
			bg.set_pixel(x, y, col)
	bg.save_png("res://icons/adaptive_background_432.png")

	print("[icons] wrote icons/icon_192.png, adaptive foreground and background")
	get_tree().quit(0)

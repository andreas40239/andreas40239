extends SceneTree
## Erstellt Screenshots (braucht Grafik, z. B. xvfb-run).
## Aufruf: godot --script res://tools/screenshots.gd -- <ausgabeordner>

var out := "/tmp"
var node: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run()


func shot(name: String, n := 40) -> void:
	for i in n:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func open(scene: String, level := 1) -> void:
	if node:
		node.queue_free()
		await process_frame
	Engine.set_meta("level", level)
	node = load(scene).instantiate()
	root.add_child(node)
	for i in 5:
		await process_frame


func place(tx: float, ty: float) -> void:
	node.player.position = Vector2((tx + 0.5) * 32, (ty + 0.5) * 32)
	node.camera.position = node.player.position
	node.camera.reset_smoothing()
	node.player.invuln = 99
	node.hud.message_time = 0.0


func _run() -> void:
	await open("res://scenes/start.tscn")
	await shot("00_startbildschirm")
	await open("res://scenes/main.tscn", 1)
	await shot("01_level1_start")
	place(9, 36)
	while node.fire_burning_at(8, 36) != 1:
		await process_frame
	await shot("02_feuerfeld_warnung")
	while node.fire_burning_at(8, 36) != 2:
		await process_frame
	await shot("03_feuerfeld_brennt", 3)
	await open("res://scenes/main.tscn", 2)
	await shot("10_level2_start")
	place(24, 6)
	await shot("11_eishalle")
	place(44, 9)
	await shot("12_spinne")
	for i in 150:
		node.player.invuln = 99
		await process_frame
	await shot("13_spinne_kampf")
	node.keys = 1
	place(23, 31.5)
	await shot("14_tuer")
	place(11, 30)
	for i in 120:
		node.player.invuln = 99
		await process_frame
	await shot("15_eisgolem")
	node.crystals = 2
	node.boss_state[1] = node.BOSS_DONE
	node.boss_state[2] = node.BOSS_DONE
	place(9, 21)
	for i in 200:
		await process_frame
	await shot("16_sieg")
	quit()

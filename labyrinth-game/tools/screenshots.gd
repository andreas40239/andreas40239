extends SceneTree
## Erstellt Screenshots verschiedener Orte (braucht Grafik, z. B. xvfb-run).
## Aufruf: godot --script res://tools/screenshots.gd -- <ausgabeordner>

var main: Node
var frame := 0
var shots := [
	["title", Vector2(15, 8.5), "title"],
	["start", Vector2(15, 8.5), "play"],
	["firesword", Vector2(5, 20), "play"],
	["knight", Vector2(14.5, 24), "play"],
	["firefield", Vector2(9, 36), "play"],
	["octopus", Vector2(23, 36), "play"],
	["heart", Vector2(41, 36), "play"],
	["icesword", Vector2(50, 22), "play"],
	["golem", Vector2(53, 35), "play"],
	["dragon", Vector2(46, 9), "play"],
	["portal", Vector2(32, 6), "play"],
]
var idx := 0
var wait := 0
var out := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 5:
		return false
	if idx >= shots.size():
		quit()
		return false
	var s: Array = shots[idx]
	if wait == 0:
		main.state = s[2]
		main.player.invuln = 0
		main.player.hp = 4
		main.player.weapon = 1 if idx < 7 else 2
		main.player.position = Vector2((s[1].x + 0.5) * 32, (s[1].y + 0.5) * 32)
		main.camera.position = main.player.position
		main.camera.reset_smoothing()
		if s[0] == "knight" or s[0] == "octopus" or s[0] == "golem":
			main.player.invuln = 99
	wait += 1
	if s[0] == "knight" and wait == 50:
		main.action_queued = true
	if wait == 60:
		var img := root.get_texture().get_image()
		img.save_png("%s/%02d_%s.png" % [out, idx, s[0]])
		idx += 1
		wait = 0
	return false

extends SceneTree
## Hilfswerkzeug für Screenshots (nicht Teil des Spiels).
## godot --path . --resolution 1920x1080 -s tests/screenshot.gd -- <screen> <out.png> [level] [sekunden] [aktionen]
## screen: title | level_select | game
## aktionen (kommagetrennt): build:<spot>:<station>, start, select:<spot>, station:<index>, upgrade:range

var _args: PackedStringArray
var _main: Node
var _frames := 0
var _game = null
var _sim_time := 0.0
var _target_time := 0.0
var _done := false


func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	_main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(_main)


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		var screen := StringName(_args[0])
		var level := int(_args[2]) if _args.size() > 2 else 1
		if screen != &"title":
			root.get_node("GameState").goto_screen(screen, {"level": level})
	if _frames == 12 and _args[0] == "game":
		_game = _find_game()
		_target_time = float(_args[3]) if _args.size() > 3 else 0.0
		if _args.size() > 4:
			_run_actions(_args[4])
	if _frames > 12 and _game and _sim_time < _target_time:
		_sim_time += delta
		return false
	if _frames > 40 and not _done:
		_done = true
		var img := root.get_texture().get_image()
		img.save_png(_args[1])
		print("Screenshot gespeichert: ", _args[1], " ", img.get_size())
		return true
	return false


func _find_game():
	for c in _main.get_children():
		if c.has_method("build_station"):
			return c
	return null


func _run_actions(spec: String) -> void:
	for a in spec.split(","):
		var parts := a.split(":")
		match parts[0]:
			"build":
				root.get_node("GameState").earn(1000)
				_game.build_station(_game.build_manager.spots[int(parts[1])], StringName(parts[2]))
			"start":
				_game.hud._close_modal()
				_game._intro_open = false
				_game.start_next_wave()
			"select":
				_game.select_spot(_game.build_manager.spots[int(parts[1])])
			"station":
				_game._select_station(_game.build_manager.stations[int(parts[1])])
			"upgrade":
				_game._on_upgrade_pressed(StringName(parts[1]))
			"nointro":
				_game.hud._close_modal()
				_game._intro_open = false
				_game._start_tutorial()
			"win":
				_game.hud._close_modal()
				_game._intro_open = false
				root.get_node("GameState").chaos = 2
				_game.friends_count = 16
				_game.end_level(true)
			"fast":
				_game.toggle_speed()

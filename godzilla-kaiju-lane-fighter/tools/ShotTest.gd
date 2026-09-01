extends Node
## Screenshot a UI scene: godot tools/shot_scene.tscn -- <scene_name>

var t := 0.0
var scene_name := "main_menu"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		scene_name = arg
	GameState.current_level = 2
	var packed: PackedScene = load("res://scenes/%s.tscn" % scene_name)
	get_tree().root.add_child.call_deferred(packed.instantiate())

func _process(delta: float) -> void:
	t += delta
	if t > 1.5:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/ui_%s.png" % [OS.get_environment("SCREENSHOT_DIR"), scene_name])
		print("shot saved")
		get_tree().quit(0)

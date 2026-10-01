extends Node
## Screenshot a UI scene: godot tools/shot_scene.tscn -- <scene_name>

var t := 0.0
var scene_name := "main_menu"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		scene_name = arg
	GameState.current_level = int(OS.get_environment("LEVEL")) if OS.has_environment("LEVEL") else 2
	var packed: PackedScene = load("res://scenes/%s.tscn" % scene_name)
	get_tree().root.add_child.call_deferred(packed.instantiate())

func _process(delta: float) -> void:
	t += delta
	var at := float(OS.get_environment("SHOT_T")) if OS.has_environment("SHOT_T") else 1.5
	if t > at:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/ui_%s_%s.png" % [OS.get_environment("SCREENSHOT_DIR"), scene_name, str(at)])
		print("shot saved")
		get_tree().quit(0)

extends Node
## Plays the real level as the current scene, hibernates, and taps the
## results screen through the normal input pipeline. The level must restart.
## Run: godot --headless --fixed-fps 60 res://tests/results_test.tscn


func _ready() -> void:
	# A driver that survives the scene change.
	var driver := Node.new()
	driver.set_script(load("res://tests/results_test_driver.gd"))
	get_tree().root.add_child.call_deferred(driver)
	Game.best_stars = [0, 0, 0]
	get_tree().change_scene_to_file.call_deferred("res://scenes/garden_1.tscn")

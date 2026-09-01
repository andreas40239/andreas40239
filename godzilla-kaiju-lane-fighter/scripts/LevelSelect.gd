extends Control
## Level select (3 MVP levels).

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	var bg := ColorRect.new()
	bg.color = Color("0d1117")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	var box := VBoxContainer.new()
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	box.add_child(Ui.label("SELECT HUNTING GROUND", 11, Color("2dd4bf")))
	box.add_child(Ui.label(" ", 6))
	for lv in [1, 2, 3]:
		var d: Dictionary = G.LEVELS[lv]
		var unlocked: bool = lv <= GameState.unlocked_level
		var done: bool = GameState.completed.get(lv, false)
		var text: String = "%d. %s%s" % [lv, d["name"], "  *" if done else ""]
		var wrap := CenterContainer.new()
		if unlocked:
			var b := Ui.button(text, func():
				GameState.current_level = lv
				get_tree().change_scene_to_file("res://scenes/story_card.tscn"), 9)
			wrap.add_child(b)
		else:
			var b := Ui.button("%d. ? ? ? LOCKED" % lv, func(): pass, 9, Color(0.35, 0.38, 0.42))
			b.disabled = true
			wrap.add_child(b)
		box.add_child(wrap)
	box.add_child(Ui.label(" ", 6))
	var w2 := CenterContainer.new()
	w2.add_child(Ui.button("EVOLVE  (EP: %d)" % GameState.ep, func(): get_tree().change_scene_to_file("res://scenes/upgrade_screen.tscn"), 9, Color("a855f7")))
	box.add_child(w2)
	var w3 := CenterContainer.new()
	w3.add_child(Ui.button("BACK", func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), 8, Color("6b7280")))
	box.add_child(w3)
	AudioManager.play_music("menu")

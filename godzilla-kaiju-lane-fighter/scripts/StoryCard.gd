extends Control
## Static story text card between levels (GDD 12.2). Tap to begin.

var can_continue := false

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	var bg := ColorRect.new()
	bg.color = Color("0d1117")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	var d: Dictionary = G.LEVELS[GameState.current_level]
	var box := VBoxContainer.new()
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	add_child(box)
	box.add_child(Ui.label("LEVEL %d" % GameState.current_level, 9, Color("6b7280")))
	box.add_child(Ui.label(d["name"], 13, Color("2dd4bf")))
	var story := Ui.label(d["story"], 7, Color(0.8, 0.84, 0.88))
	story.add_theme_constant_override("line_spacing", 6)
	box.add_child(story)
	var tap := Ui.label("- TAP TO RISE -", 8, Color("fbbf24"))
	tap.modulate.a = 0.0
	box.add_child(tap)
	var tw := create_tween().set_loops()
	tw.tween_property(tap, "modulate:a", 1.0, 0.6)
	tw.tween_property(tap, "modulate:a", 0.2, 0.6)
	AudioManager.stop_music()
	await get_tree().create_timer(0.6).timeout
	can_continue = true

func _input(event: InputEvent) -> void:
	if not can_continue:
		return
	var go := false
	if event is InputEventScreenTouch and event.pressed:
		go = true
	elif event is InputEventKey and event.pressed:
		go = true
	elif event is InputEventMouseButton and event.pressed:
		go = true
	if go:
		can_continue = false
		get_tree().change_scene_to_file("res://scenes/game.tscn")

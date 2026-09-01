extends Control
## Tier 1 evolution upgrades (GDD 8.2, MVP scope). 1 EP each.

var ep_label: Label

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	var bg := ColorRect.new()
	bg.color = Color("0d1117")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	_rebuild()
	AudioManager.play_music("menu")

func _rebuild() -> void:
	for c in get_children():
		if c is VBoxContainer:
			c.queue_free()
	var box := VBoxContainer.new()
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(Ui.label("EVOLUTION CHAMBER", 12, Color("a855f7")))
	ep_label = Ui.label("EVOLUTION POINTS: %d" % GameState.ep, 9, Color("fbbf24"))
	box.add_child(ep_label)
	box.add_child(Ui.label("earn EP by conquering levels", 6, Color(0.6, 0.65, 0.7)))
	box.add_child(Ui.label(" ", 4))
	for id in GameState.UPGRADES:
		var u: Dictionary = GameState.UPGRADES[id]
		var owned: bool = GameState.has_upg(id)
		var pan := Ui.panel()
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		pan.add_child(inner)
		var title := Ui.label("%s  [%s]" % [u["name"], u["tree"]], 8, u["color"])
		inner.add_child(title)
		inner.add_child(Ui.label(u["desc"], 6, Color(0.75, 0.8, 0.85)))
		if owned:
			inner.add_child(Ui.label("< EVOLVED >", 7, Color("22c55e")))
		else:
			var wrapb := CenterContainer.new()
			var buy := Ui.button("EVOLVE - 1 EP", func():
				if GameState.buy_upgrade(id):
					AudioManager.play_sfx("ep_gain")
					_rebuild()
				else:
					AudioManager.play_sfx("gz_hurt", -12.0), 7, u["color"])
			buy.disabled = GameState.ep <= 0
			wrapb.add_child(buy)
			inner.add_child(wrapb)
		var wrap := CenterContainer.new()
		wrap.add_child(pan)
		box.add_child(wrap)
	box.add_child(Ui.label(" ", 4))
	var w3 := CenterContainer.new()
	w3.add_child(Ui.button("BACK", func(): get_tree().change_scene_to_file("res://scenes/level_select.tscn"), 8, Color("6b7280")))
	box.add_child(w3)

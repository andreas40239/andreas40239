class_name WorldSelect
extends Control
## Weltauswahl: Sonnental, Strand und Meer, Schnee und Berge.
## Eine Welt kann man erst bereisen, wenn die vorherige geschafft ist.

const WORLD_COLORS: Array[Color] = [Color("3f9a3a"), Color("e08a1e"), Color("3a7fc4")]
const WORLD_MONSTERS: Array = [[&"knurri", &"troepfli"], [&"elektro", &"fluegel"], [&"bibber", &"flocki"]]


func _ready() -> void:
	theme = UiTheme.get_theme()
	var bg := SceneryBackground.new()
	bg.show_village = false
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = tr("Wähle eine Welt")
	title.label_settings = UiTheme.label_settings(72, Color.WHITE, 18, UiTheme.INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HUD._anchor(title, 0.5, 0.0, 0, 30)
	add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	HUD._anchor(row, 0.5, 0.56, 0, 0)
	add_child(row)
	for w in DataRegistry.world_count():
		var card := WorldCard.make(w + 1)
		var world_number := w + 1
		card.pressed.connect(func() -> void:
			if SaveManager.is_world_unlocked(world_number):
				GameState.goto_screen(&"level_select", {"world": world_number}))
		row.add_child(card)

	var back := IconButton.make(&"back", UiTheme.BLUE)
	HUD._anchor(back, 0.0, 0.0, 28, 28)
	back.pressed.connect(go_back)
	add_child(back)


func go_back() -> void:
	GameState.goto_screen(&"title")


class WorldCard extends Button:
	var world := 1
	var unlocked := true
	var completed := false
	var _t := 0.0
	var _picture: WorldPicture

	static func make(w: int) -> WorldCard:
		var c := WorldCard.new()
		c.world = w
		c.unlocked = SaveManager.is_world_unlocked(w)
		c.completed = SaveManager.is_world_completed(w)
		c.custom_minimum_size = Vector2(520, 640)
		c.focus_mode = Control.FOCUS_NONE
		c.disabled = not c.unlocked
		UiTheme.style_button(c, Color("fffaf0") if c.unlocked else Color("dfe3ea"), UiTheme.INK, 40)
		c._picture = WorldPicture.new()
		c._picture.world = w
		c._picture.happy = c.completed
		c._picture.position = Vector2(24, 24)
		c._picture.size = Vector2(472, 400)
		c._picture.clip_contents = true
		c._picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(c._picture)
		c.button_down.connect(func() -> void: AudioManager.play(&"tap"))
		return c

	func _process(delta: float) -> void:
		_t += delta
		var next := unlocked and not completed
		var s: float = 1.0 + (0.025 * sin(_t * 3.0) if next else 0.0)
		pivot_offset = size * 0.5
		scale = Vector2(s, s)
		queue_redraw()

	func _draw() -> void:
		var f := UiTheme.get_bold()
		var col: Color = WorldSelect.WORLD_COLORS[world - 1] if unlocked else Color("8a93a8")
		draw_string(f, Vector2(0, 480), tr("Welt %d") % world, HORIZONTAL_ALIGNMENT_CENTER, size.x, 36, UiTheme.INK.lightened(0.2))
		draw_string(f, Vector2(0, 536), tr(DataRegistry.world_name(world)), HORIZONTAL_ALIGNMENT_CENTER, size.x, 46, col)
		if unlocked:
			var txt := "%d/%d" % [SaveManager.world_stars(world), DataRegistry.world_levels(world).size() * 3]
			var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
			Icons.star(self, Vector2(size.x * 0.5 - w * 0.5 - 26, 584), 46, Color("ffd23f"), false)
			draw_string(f, Vector2(size.x * 0.5 - w * 0.5 + 4, 598), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, UiTheme.INK)
			if completed:
				Icons.check(self, Vector2(size.x - 70, 70), 60, UiTheme.GREEN)
		else:
			draw_rect(Rect2(Vector2(24, 24), Vector2(472, 400)), Color(1, 1, 1, 0.55))
			Icons.lock(self, Vector2(size.x * 0.5, 220), 130)
			draw_string(f, Vector2(0, 596), tr("Schaffe zuerst Welt %d") % (world - 1), HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, UiTheme.INK.lightened(0.3))


class WorldPicture extends Control:
	## Kleine Landschaft der Welt mit zwei typischen Monstern.
	var world := 1
	var happy := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var theme_id := DataRegistry.world_theme(world)
		var cols := SceneryArt.colors(theme_id)
		draw_rect(Rect2(0, 0, w, h), Color("9ad8f5"))
		draw_circle(Vector2(w * 0.82, h * 0.16), 34, Color("ffd84d"))
		match theme_id:
			&"beach":
				draw_rect(Rect2(0, h * 0.42, w, h), cols["ground"])
				SceneryArt.sea(self, 0, w, h * 0.42, _t)
				SceneryArt.palm(self, Vector2(w * 0.12, h * 0.8), 0.9, _t)
				SceneryArt.umbrella(self, Vector2(w * 0.86, h * 0.92), 0.8, Color("ff6b6b"))
			&"snow":
				SceneryArt.mountains(self, -80, w + 80, h * 0.55)
				draw_rect(Rect2(0, h * 0.55, w, h), cols["ground"])
				SceneryArt.pine(self, Vector2(w * 0.1, h * 0.86), 0.8)
				SceneryArt.pine(self, Vector2(w * 0.9, h * 0.82), 0.7)
				for i in 14:
					var p := Vector2(fmod(i * 97.0, w), fmod(i * 53.0 + _t * 30.0, h))
					draw_circle(p, 3, Color(1, 1, 1, 0.9))
			_:
				Icons.ellipse(self, Vector2(w * 0.3, h * 0.72), w * 0.6, h * 0.3, Color("8fd16a"))
				Icons.ellipse(self, Vector2(w * 0.8, h * 0.75), w * 0.5, h * 0.3, Color("7cc35c"))
				draw_rect(Rect2(0, h * 0.8, w, h), Color("6bbf59"))
				draw_rect(Rect2(w * 0.08, h * 0.5, 14, 60), Color("8d5f3a"))
				draw_circle(Vector2(w * 0.08 + 7, h * 0.48), 34, Color("4fa64a"))
		var kinds: Array = WorldSelect.WORLD_MONSTERS[world - 1]
		for i in kinds.size():
			var d := DataRegistry.monster(kinds[i])
			draw_set_transform(Vector2(w * (0.35 + i * 0.3), h * 0.94), 0.0, Vector2(1.7, 1.7))
			MonsterArt.draw_monster(self, d.id, d.body_color, 34.0 * d.size_scale, 1.0 if happy else 0.15, _t + i, 1.0 if i == 0 else -1.0, true)
			if happy:
				Icons.heart(self, Vector2(0, -88), 22, Color("ff5a87"))
		draw_set_transform(Vector2.ZERO)

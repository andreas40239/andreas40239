extends Control
## Title screen: pick a garden. Each garden unlocks when the one before it
## has been finished; the best star rating is shown on its card.

const CARD_COLORS := [Color(0.35, 0.55, 0.3), Color(0.55, 0.42, 0.25), Color(0.2, 0.25, 0.45)]
const CARD_TEXT := [
	"Learn the ropes, dodge the cat and find a cosy spot under the shed.",
	"Biscuit the dog can smell you! Hide in compost heaps and use the ball.",
	"After dark an owl is hunting. Watch for its shadow and stay hidden!",
]

var cards: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	Sound.start_music()
	_build()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.32, 0.5, 0.3)
	background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(background)
	var sky := ColorRect.new()
	sky.color = Color(0.55, 0.72, 0.88)
	sky.set_anchors_preset(PRESET_TOP_WIDE)
	sky.custom_minimum_size = Vector2(0, 250)
	add_child(sky)

	var column := VBoxContainer.new()
	column.set_anchors_preset(PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 20)
	column.add_child(header)
	var icon := TextureRect.new()
	icon.texture = load("res://icon.svg")
	icon.custom_minimum_size = Vector2(110, 110)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var titles := VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(titles)
	titles.add_child(_label("Hedgehog Highways", 56))
	titles.add_child(_label("Help the little hedgehog get ready for winter", 22))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	column.add_child(row)
	for i in Game.LEVELS.size():
		row.add_child(_card(i))
	if cards.size() > 0:
		cards[_suggested_level()].grab_focus()


## The first unfinished garden that is unlocked (or the last one).
func _suggested_level() -> int:
	for i in Game.LEVELS.size():
		if Game.is_unlocked(i) and Game.best_stars[i] == 0:
			return i
	return 0


func _card(index: int) -> Button:
	var unlocked := Game.is_unlocked(index)
	var card := Button.new()
	card.custom_minimum_size = Vector2(300, 290)
	card.disabled = not unlocked
	var color: Color = CARD_COLORS[index] if unlocked else Color(0.35, 0.35, 0.38)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color.lightened(0.12) if state == "hover" or state == "focus" else color
		style.set_corner_radius_all(18)
		style.set_border_width_all(4 if state == "focus" else 0)
		style.border_color = Color(1.0, 0.85, 0.3)
		card.add_theme_stylebox_override(state, style)
	card.pressed.connect(Game.go_to_level.bind(index))
	cards.append(card)

	var box := VBoxContainer.new()
	box.set_anchors_preset(PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	box.offset_top = 14
	box.offset_bottom = -14
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(_label("Garden %d" % (index + 1), 20, MOUSE_FILTER_IGNORE))
	box.add_child(_label(Game.LEVELS[index]["title"], 28, MOUSE_FILTER_IGNORE))
	var stars := StarRow.new()
	stars.stars = Game.best_stars[index]
	stars.star_size = 22.0
	stars.spacing = 54.0
	stars.custom_minimum_size = Vector2(0, 54)
	stars.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(stars)
	var text: String = CARD_TEXT[index] if unlocked else "Finish garden %d to unlock this garden." % index
	var about := _label(text, 18, MOUSE_FILTER_IGNORE)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(about)
	return card


func _label(text: String, font_size: int, filter := MOUSE_FILTER_STOP) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = filter
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("outline_size", 6)
	return label

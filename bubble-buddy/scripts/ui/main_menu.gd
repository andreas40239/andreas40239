class_name BBMainMenu
extends Control
## Title screen. Three destinations only: play, stickers, and a grown-ups door
## that needs a deliberate two second hold.

signal play_requested
signal stickers_requested
signal dashboard_requested

const HOLD_TIME := 2.0

var _hold := 0.0
var _holding := false
var _hold_ring: BBHoldRing
var _bg: BBBackground
var _fish: BBTitleFish
var _title_box: VBoxContainer
var _buttons: VBoxContainer
var _privacy: Label


func _ready() -> void:
	_bg = BBBackground.new()
	_bg.scroll_speed = 40.0
	add_child(_bg)

	_fish = BBTitleFish.new()
	add_child(_fish)

	_title_box = VBoxContainer.new()
	_title_box.add_theme_constant_override("separation", 16)
	add_child(_title_box)

	var title := BBUi.label("Bubble Buddy", BBUi.FONT_TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_outline_color", Color(0.06, 0.32, 0.44, 0.85))
	_title_box.add_child(title)

	var sub := BBUi.label("A gentle ocean adventure", BBUi.FONT_BODY, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_constant_override("outline_size", 12)
	sub.add_theme_color_override("font_outline_color", Color(0.06, 0.32, 0.44, 0.7))
	_title_box.add_child(sub)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 36)
	add_child(_buttons)

	var play := BBUi.button("Play", BBUi.TEAL, Vector2(520, 180))
	play.add_theme_font_size_override("font_size", 84)
	play.pressed.connect(func(): play_requested.emit())
	_buttons.add_child(play)

	var stickers := BBUi.button("Sticker Book", BBUi.SUN, Vector2(520, 150))
	stickers.add_theme_color_override("font_color", BBUi.INK)
	stickers.pressed.connect(func(): stickers_requested.emit())
	_buttons.add_child(stickers)

	# Grown-ups door: hold to open, so small hands do not wander in.
	var grown := Button.new()
	grown.text = "Hold for grown-ups"
	grown.custom_minimum_size = Vector2(520, 130)
	grown.focus_mode = Control.FOCUS_NONE
	grown.add_theme_font_size_override("font_size", BBUi.FONT_SMALL)
	grown.add_theme_color_override("font_color", BBUi.INK)
	for state in ["normal", "hover", "pressed"]:
		grown.add_theme_stylebox_override(state, BBUi.rounded_style(Color(1, 1, 1, 0.78), 60))
	grown.button_down.connect(func():
		_holding = true
		_hold = 0.0)
	grown.button_up.connect(func():
		_holding = false
		_hold = 0.0)
	_buttons.add_child(grown)

	_hold_ring = BBHoldRing.new()
	add_child(_hold_ring)

	_privacy = BBUi.label("No ads. No purchases. No internet. Nothing is collected.",
		BBUi.FONT_SMALL, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_privacy.add_theme_constant_override("outline_size", 10)
	_privacy.add_theme_color_override("font_outline_color", Color(0.06, 0.32, 0.44, 0.75))
	add_child(_privacy)

	relayout(size if size.x > 1.0 else Vector2(1080, 1920))


func relayout(v: Vector2) -> void:
	_bg.view_size = v
	_fish.position = Vector2(v.x * 0.5, v.y * 0.32)

	var title_width: float = minf(v.x - 80.0, 1000.0)
	_title_box.size = Vector2(title_width, 0)
	_title_box.position = Vector2((v.x - title_width) * 0.5, v.y * 0.09)

	var button_width := 520.0
	_buttons.size = Vector2(button_width, 0)
	_buttons.position = Vector2((v.x - button_width) * 0.5, v.y * 0.56)

	_hold_ring.position = Vector2(v.x * 0.5, v.y * 0.885)

	var privacy_width: float = minf(v.x - 60.0, 1000.0)
	_privacy.size = Vector2(privacy_width, 0)
	_privacy.custom_minimum_size = Vector2(privacy_width, 0)
	_privacy.position = Vector2((v.x - privacy_width) * 0.5, v.y - 100.0)


func _process(delta: float) -> void:
	if _holding:
		_hold += delta
		if _hold >= HOLD_TIME:
			_holding = false
			_hold = 0.0
			Sound.play("sticker")
			dashboard_requested.emit()
	_hold_ring.ratio = _hold / HOLD_TIME
	_hold_ring.queue_redraw()

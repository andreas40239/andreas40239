class_name BBHud
extends CanvasLayer
## Minimal in-game HUD: pearl count, treasure chest meter, the Big Bubble button
## and the occasional celebration banner. Nothing here nags, counts down, or
## warns.

signal bubble_pressed
signal bubble_released
signal pause_requested

var view := Vector2(1080, 1920)

var pearls := 0
var chest_ratio := 0.0
var zone_name := ""

var _pearl_label: Label
var _chest: BBChestMeter
var _banner: Control
var _banner_label: Label
var _banner_sub: Label
var _banner_t := 0.0
var _bubble_button: BBBubbleButton
var _power_label: Label
var _power_bar: BBThinBar
var _friend_label: Label
var _rhyme: Control
var _gear: Button
var _power_holder: Control
var _banner_panel: PanelContainer


func _ready() -> void:
	layer = 10
	_build_counter()
	_build_chest()
	_build_buttons()
	_build_banner()
	_build_power_readout()
	layout(view)


## Re-anchors the HUD to the real screen size (called on start and on rotation
## or window resize).
func layout(v: Vector2) -> void:
	view = v
	if _gear != null:
		_gear.position = Vector2(v.x - 160.0, 46.0)
	if _bubble_button != null:
		_bubble_button.position = Vector2(v.x - 210.0, v.y - 250.0)
	if _power_holder != null:
		_power_holder.position = Vector2(46.0, v.y - 190.0)
	if _banner_panel != null:
		var width: float = minf(v.x - 180.0, 900.0)
		_banner_panel.custom_minimum_size = Vector2(width, 0)
		_banner_panel.size = Vector2(width, 0)
		_banner_panel.position = Vector2((v.x - width) * 0.5, 0.0)
		_banner.position = Vector2(0, v.y * 0.17)


func _build_counter() -> void:
	var holder := Control.new()
	holder.position = Vector2(40, 40)
	add_child(holder)

	var bubble := BBPearlIcon.new()
	bubble.position = Vector2(60, 60)
	holder.add_child(bubble)

	_pearl_label = BBUi.label("0", 68, BBUi.INK)
	_pearl_label.position = Vector2(112, 22)
	_pearl_label.add_theme_color_override("font_color", Color.WHITE)
	_pearl_label.add_theme_constant_override("outline_size", 12)
	_pearl_label.add_theme_color_override("font_outline_color", Color(0.1, 0.28, 0.38, 0.8))
	holder.add_child(_pearl_label)


func _build_chest() -> void:
	_chest = BBChestMeter.new()
	_chest.position = Vector2(60, 168)
	add_child(_chest)


func _build_buttons() -> void:
	_gear = BBUi.icon_button("II", BBUi.CREAM, 120.0)
	_gear.pressed.connect(func(): pause_requested.emit())
	add_child(_gear)

	_bubble_button = BBBubbleButton.new()
	_bubble_button.pressed_down.connect(func(): bubble_pressed.emit())
	_bubble_button.released.connect(func(): bubble_released.emit())
	add_child(_bubble_button)


func _build_banner() -> void:
	_banner = Control.new()
	_banner.visible = false
	add_child(_banner)

	_banner_panel = BBUi.panel(Color(1, 1, 1, 0.92), 60)
	_banner.add_child(_banner_panel)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_panel.add_child(col)

	_banner_label = BBUi.label("", BBUi.FONT_BIG, BBUi.INK, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_banner_label)
	_banner_sub = BBUi.label("", BBUi.FONT_BODY, BBUi.TEAL, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_banner_sub)


func _build_power_readout() -> void:
	var holder := Control.new()
	add_child(holder)
	_power_holder = holder

	_power_label = BBUi.label("", BBUi.FONT_SMALL, Color.WHITE)
	_power_label.add_theme_constant_override("outline_size", 10)
	_power_label.add_theme_color_override("font_outline_color", Color(0.1, 0.28, 0.38, 0.8))
	holder.add_child(_power_label)

	_power_bar = BBThinBar.new()
	_power_bar.position = Vector2(0, 54)
	holder.add_child(_power_bar)

	_friend_label = BBUi.label("", BBUi.FONT_SMALL, Color.WHITE)
	_friend_label.position = Vector2(0, 96)
	_friend_label.add_theme_constant_override("outline_size", 10)
	_friend_label.add_theme_color_override("font_outline_color", Color(0.1, 0.28, 0.38, 0.8))
	holder.add_child(_friend_label)


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			_banner.visible = false


func set_pearls(count: int, chest: float) -> void:
	pearls = count
	_pearl_label.text = str(count)
	chest_ratio = chest
	_chest.ratio = chest
	_chest.queue_redraw()


func set_charge(charge: float, cooldown_ratio: float) -> void:
	_bubble_button.charge = charge
	_bubble_button.ready_ratio = cooldown_ratio
	_bubble_button.queue_redraw()


func set_power(text: String, ratio: float, color: Color) -> void:
	_power_label.text = text
	_power_bar.ratio = ratio
	_power_bar.color = color
	_power_bar.visible = ratio > 0.0
	_power_bar.queue_redraw()


func set_friends(count: int) -> void:
	if count <= 0:
		_friend_label.text = ""
	elif count == 1:
		_friend_label.text = "1 friend is following you!"
	else:
		_friend_label.text = "%d friends are following you!" % count


func banner(title: String, subtitle := "", duration := 2.6) -> void:
	_banner_label.text = title
	_banner_sub.text = subtitle
	_banner.visible = true
	_banner_t = duration


## The daily Golden Friend's rhyme, shown as a card that fades on its own.
func show_rhyme(species_name: String, rhyme: String) -> void:
	if _rhyme != null and is_instance_valid(_rhyme):
		_rhyme.queue_free()
	var holder := Control.new()
	add_child(holder)
	_rhyme = holder

	var width: float = minf(view.x - 160.0, 920.0)
	var panel := BBUi.panel(Color(1, 0.98, 0.9, 0.96), 64)
	panel.position = Vector2((view.x - width) * 0.5, view.y * 0.32)
	panel.custom_minimum_size = Vector2(width, 0)
	holder.add_child(panel)

	var col := VBoxContainer.new()
	panel.add_child(col)
	col.add_child(BBUi.label("Today's Golden Friend", BBUi.FONT_SMALL, BBUi.CORAL, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(BBUi.label(species_name, BBUi.FONT_BIG, BBUi.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(BBUi.label(rhyme, BBUi.FONT_BODY, BBUi.INK, HORIZONTAL_ALIGNMENT_CENTER, true))

	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 0), 0.8)
	tween.tween_callback(holder.queue_free)

class_name BBStickerBook
extends Control
## The collection screen: stickers, friends rescued, pearls and zone badges.
## Purely celebratory - nothing here is locked behind a purchase.

signal back_requested

const COLUMNS := 5


var _bg: ColorRect
var _scroll: ScrollContainer
var _col: VBoxContainer
var _back: Button


func _ready() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.46, 0.83, 0.90)
	add_child(_bg)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	_scroll.add_child(col)
	_col = col

	col.add_child(BBUi.label("Sticker Book", BBUi.FONT_TITLE, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_stats_card())

	for zone in Zones.count():
		col.add_child(_zone_page(zone))

	col.add_child(_friends_card())
	col.add_child(BBUi.spacer(40))

	_back = BBUi.button("Back", BBUi.CORAL, Vector2(420, 140))
	_back.pressed.connect(func(): back_requested.emit())
	add_child(_back)

	relayout(size if size.x > 1.0 else Vector2(1080, 1920))


func relayout(v: Vector2) -> void:
	_bg.size = v
	_scroll.position = Vector2(40, 40)
	_scroll.size = Vector2(v.x - 80.0, v.y - 250.0)
	_col.custom_minimum_size = Vector2(v.x - 120.0, 0)
	_back.position = Vector2((v.x - 420.0) * 0.5, v.y - 180.0)


func _stats_card() -> Control:
	var panel := BBUi.panel(BBUi.CREAM)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(BBUi.label("%d of %d stickers found" % [SaveData.sticker_count(), SaveData.TOTAL_STICKERS],
		BBUi.FONT_BIG, BBUi.INK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(BBUi.label("Pearls collected: %d" % SaveData.pearls_lifetime, BBUi.FONT_BODY, BBUi.TEAL))
	col.add_child(BBUi.label("Best swim: %d pearls" % SaveData.pearls_best_run, BBUi.FONT_BODY, BBUi.TEAL))
	col.add_child(BBUi.label("Coral Gates passed: %d" % SaveData.gates_lifetime, BBUi.FONT_BODY, BBUi.TEAL))
	col.add_child(BBUi.label("Golden Shells: %d" % SaveData.golden_shells, BBUi.FONT_BODY, BBUi.TEAL))
	return panel


func _zone_page(zone: int) -> Control:
	var panel := BBUi.panel(Color(1, 1, 1, 0.9))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	var title := BBUi.label(Zones.zone_name(zone), BBUi.FONT_BIG, BBUi.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if SaveData.zone_badges.has(zone):
		header.add_child(BBUi.label("Badge earned", BBUi.FONT_SMALL, BBUi.LEAF))

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	col.add_child(grid)

	for i in SaveData.STICKERS_PER_ZONE:
		var index := zone * SaveData.STICKERS_PER_ZONE + i
		var slot := BBStickerSlot.new()
		slot.index = index
		slot.found = SaveData.has_sticker(index)
		slot.zone = zone
		grid.add_child(slot)
	return panel


func _friends_card() -> Control:
	var panel := BBUi.panel(BBUi.CREAM)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(BBUi.label("Friends rescued", BBUi.FONT_BIG, BBUi.INK))
	for species in Zones.FRIEND_SPECIES:
		var row := HBoxContainer.new()
		var name_label := BBUi.label(Zones.FRIEND_NAMES[species], BBUi.FONT_BODY, BBUi.INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(BBUi.label(str(SaveData.friend_count(species)), BBUi.FONT_BODY, BBUi.CORAL))
		col.add_child(row)
	col.add_child(BBUi.label("Today's Golden Friend: %s%s" % [
		Zones.FRIEND_NAMES.get(SaveData.daily_species, "?"),
		" (found!)" if SaveData.daily_claimed else ""],
		BBUi.FONT_SMALL, BBUi.TEAL))
	return panel

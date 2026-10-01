extends Control
## Splash screen: Godzilla rises from the dark, roars, title slams in.
## Tap to skip. Goes to the main menu.

var gz_holder: Control
var fins: TextureRect
var title: Label
var sub: Label
var flash: ColorRect
var t := 0.0
var leaving := false
var roared := false

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	var bg := ColorRect.new()
	bg.color = Color("0d1117")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	var sky := TextureRect.new()
	sky.texture = load("res://assets/sprites/backgrounds/volcano_sky.png")
	sky.anchor_right = 1.0
	sky.anchor_bottom = 1.0
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.modulate = Color(1, 1, 1, 0)
	add_child(sky)
	create_tween().tween_property(sky, "modulate:a", 1.0, 1.2)
	# Godzilla (body + fins behind it), huge, starts below the screen
	gz_holder = Control.new()
	gz_holder.anchor_left = 0.5
	gz_holder.anchor_right = 0.5
	gz_holder.anchor_top = 1.0
	gz_holder.anchor_bottom = 1.0
	gz_holder.offset_left = -165
	gz_holder.offset_right = 165
	gz_holder.offset_top = 40
	gz_holder.offset_bottom = 340
	add_child(gz_holder)
	fins = _frame_rect("godzilla_fins", 0)
	fins.modulate = Color("5eead4")
	gz_holder.add_child(fins)
	gz_holder.add_child(_frame_rect("godzilla", 0))
	title = Ui.label("GODZILLA", 30, Color("2dd4bf"))
	title.anchor_right = 1.0
	title.position.y = 120
	title.modulate.a = 0.0
	add_child(title)
	sub = Ui.label("KAIJU LANE FIGHTER", 12, Color("fbbf24"))
	sub.anchor_right = 1.0
	sub.position.y = 172
	sub.modulate.a = 0.0
	add_child(sub)
	var hint := Ui.label("TAP TO START", 8, Color(0.75, 0.8, 0.85))
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_right = 1.0
	hint.offset_top = -36
	hint.modulate.a = 0.0
	add_child(hint)
	var tw2 := create_tween()
	tw2.tween_interval(2.4)
	tw2.tween_property(hint, "modulate:a", 1.0, 0.4)
	flash = ColorRect.new()
	flash.color = Color(0.8, 1.0, 0.98, 0.0)
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	AudioManager.stop_music()
	AudioManager.play_sfx("stomp", -4.0)
	# rise up from the bottom of the screen
	var rise := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_property(gz_holder, "offset_top", -290.0, 1.3)
	rise.parallel().tween_property(gz_holder, "offset_bottom", -20.0, 1.3)

func _frame_rect(tex: String, frame: int) -> TextureRect:
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/sprites/characters/%s.png" % tex)
	at.region = Rect2(frame * 64, 0, 64, 48)
	var r := TextureRect.new()
	r.texture = at
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r

func _process(delta: float) -> void:
	t += delta
	if t > 1.35 and not roared:
		roared = true
		# ROAR: mouth opens, fins blaze, screen shakes + flashes
		for c in gz_holder.get_children():
			(c.texture as AtlasTexture).region = Rect2(11 * 64, 0, 64, 48)
		AudioManager.play_sfx("gz_roar")
		AudioManager.play_sfx("pulse", -6.0)
		flash.color.a = 0.7
		create_tween().tween_property(flash, "color:a", 0.0, 0.5)
		var pop := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		title.scale = Vector2(1.8, 1.8)
		title.pivot_offset = Vector2(get_viewport_rect().size.x * 0.5, 20)
		pop.tween_property(title, "modulate:a", 1.0, 0.15)
		pop.parallel().tween_property(title, "scale", Vector2.ONE, 0.35)
		pop.tween_property(sub, "modulate:a", 1.0, 0.3)
	if roared and t < 2.2:
		var k := (2.2 - t) * 8.0
		position = Vector2(randf_range(-k, k), randf_range(-k, k))
		fins.modulate = Color(1, 1, 1).lerp(Color("5eead4"), clampf((t - 1.35) / 0.8, 0.0, 1.0))
	else:
		position = Vector2.ZERO
		fins.modulate = Color("5eead4").lerp(Color(1, 1, 1), 0.25 + 0.25 * sin(t * 4.0))
	if t > 5.5:
		_leave()

func _input(event: InputEvent) -> void:
	if t < 0.4:
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventKey and event.pressed):
		_leave()

func _leave() -> void:
	if leaving:
		return
	leaving = true
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(0, 0, 0), 0.35)
	tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))

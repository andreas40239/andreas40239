extends Node3D
## Level controller for each garden: the winter clock, the sniff-mode look,
## night lighting, and the hibernation ending with its star rating.

## Position in Game.LEVELS.
@export var level_index := 0
@export var level_title := "Garden 1: The Cottage Garden"
## Shown at the start of the level (gardens without a tutorial).
@export_multiline var intro_text := ""
## Night gardens: dark sky, moonlight, a little lantern glow around the hedgehog.
@export var night := false
## Length of the level's autumn, in seconds.
@export var level_duration := 360.0
@export var good_nest_material := 6
@export var good_dexterity := 60.0
## The neighbours' dog barks from behind these spots now and then.
@export var dog_spots: Array[Vector3] = [Vector3(19, 0, 4), Vector3(-19, 0, -6), Vector3(4, 0, 19), Vector3(-6, 0, -19)]
## When the winter clock passes this point, the wind starts picking up.
@export var wind_rise_start := 0.75

var elapsed := 0.0
var finished := false
var stars := 0

var _winter_announced := false
var _sniff_amount := 0.0
var _dog_timer := 10.0
var _wind_warned := false
var _sun_color := Color.WHITE
var _sun_energy := 1.0

@onready var player: Hedgehog = $Player
@onready var hud = $HUD
@onready var camera_rig = $CameraRig
@onready var sun: DirectionalLight3D = $Sun
@onready var environment: Environment = $WorldEnvironment.environment
@onready var snow: CPUParticles3D = $Snow
@onready var tutorial = $Tutorial


func _ready() -> void:
	# The garden's static scenery becomes one mesh: far fewer draw calls.
	MeshUtil.merge($Scenery)
	_warm_up_shaders()
	_sun_color = sun.light_color
	_sun_energy = sun.light_energy
	hud.bind(player)
	hud.play_again_pressed.connect(func() -> void: get_tree().reload_current_scene())
	hud.next_garden_pressed.connect(func() -> void: Game.go_to_level(level_index + 1))
	hud.all_gardens_pressed.connect(Game.go_to_title)
	for spot in get_tree().get_nodes_in_group("hibernation_spots"):
		spot.hibernate_requested.connect(_on_hibernate_requested)
	environment.adjustment_enabled = true
	# The tutorial is only needed the first time.
	if tutorial.active and Game.best_stars[level_index] > 0:
		tutorial.skip()
	if night:
		_add_lantern()
		Game.unlock_fact("night")
	else:
		get_tree().create_timer(1.5).timeout.connect(Game.unlock_fact.bind("start"))
	if tutorial.active:
		Game.show_toast("Find food, stay safe and build a cosy nest before winter!")
	else:
		hud.show_title(level_title, intro_text if intro_text != "" else "Find food, stay safe and build a cosy nest before winter!")
	Sound.start_level_audio(night)
	_apply_audio(0.0)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart") and not hud.is_showing_results():
		get_tree().reload_current_scene()
		return

	if not finished and not tutorial.active:  # Autumn waits for the tutorial.
		elapsed += delta
		var progress := clampf(elapsed / level_duration, 0.0, 1.0)
		player.winter_progress = progress
		hud.set_season(progress)
		_apply_season(progress)
		if progress > 0.5:
			Game.unlock_fact("winter")
		if progress >= 1.0 and not _winter_announced:
			_start_winter()
		_apply_audio(progress)
		if progress >= wind_rise_start and not _wind_warned:
			_wind_warned = true
			Game.show_toast("Brrr... the wind is picking up. Winter is nearly here!")

	if not finished:
		_dog_timer -= delta
		if _dog_timer <= 0.0:
			_dog_timer = randf_range(18.0, 40.0)
			Sound.play_at("bark", dog_spots.pick_random(), -4.0, 0.08, 60.0)

	_sniff_amount = move_toward(_sniff_amount, 1.0 if player.is_sniffing else 0.0, delta * 4.0)
	environment.adjustment_saturation = lerpf(1.0, 0.3, _sniff_amount)
	camera_rig.sniff_amount = _sniff_amount


## Phones compile each kind of material the first time it is drawn, which
## causes a hitch mid-game (first sniff, first time the cat notices you, the
## first snow...). So we draw one of each, hidden behind the fade-in, at the
## start of the level.
func _warm_up_shaders() -> void:
	var camera: Camera3D = camera_rig.get_node("SpringArm3D/Camera3D")
	var warm := Node3D.new()
	camera.add_child(warm)
	warm.position = Vector3(0, 0, -1.5)
	var scent := Scent.new()
	warm.add_child(scent)
	scent.set_revealed(true)
	var label := Label3D.new()
	# Same font settings as the animals' labels, with every glyph they use.
	label.text = "?!. meh zzz WOOF ouch yay"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 96
	label.outline_size = 12
	label.pixel_size = 0.0005
	warm.add_child(label)
	var see_through := MeshUtil.add(warm, MeshUtil.sphere(0.1), Color.GREEN)
	(see_through.mesh.material as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	var merged_parts := Node3D.new()
	warm.add_child(merged_parts)
	MeshUtil.add(merged_parts, MeshUtil.sphere(0.1), Color.BROWN)
	MeshUtil.merge(merged_parts)
	var flakes: CPUParticles3D = snow.duplicate()
	flakes.position = Vector3.ZERO
	flakes.emission_box_extents = Vector3(0.2, 0.2, 0.2)
	warm.add_child(flakes)
	flakes.preprocess = 1.0
	flakes.emitting = true
	for i in 4:
		await get_tree().process_frame
	warm.queue_free()


## Rates the nest. Returns [description, achieved] pairs; one star each.
func rate_hibernation(spot: HibernationSpot) -> Array:
	return [
		["Slept in a safe, sheltered spot", spot.secure],
		["Cosy nest (%d+ pieces of nest material)" % good_nest_material, spot.nest_amount >= good_nest_material],
		["Healthy and nimble (all hearts, dexterity %d+)" % int(good_dexterity),
				player.health == player.max_health and player.dexterity >= good_dexterity],
	]


func _on_hibernate_requested(spot: HibernationSpot) -> void:
	if finished:
		return
	finished = true
	var criteria := rate_hibernation(spot)
	stars = 0
	for entry in criteria:
		if entry[1]:
			stars += 1
	Game.complete_level(level_index, stars)
	player.start_sleep(spot.global_position)
	camera_rig.start_orbit()
	snow.emitting = true
	var tween := create_tween()
	tween.tween_property(sun, "light_energy", 0.35, 4.0)
	# The wind settles down for a peaceful sleep.
	create_tween().tween_method(Sound.set_wind, 0.6, 0.15, 5.0)
	Sound.set_insects(0.0)
	hud.play_hibernation(stars, criteria, player.stats, Game.has_level(level_index + 1))


func _start_winter() -> void:
	_winter_announced = true
	for spot in get_tree().get_nodes_in_group("hibernation_spots"):
		spot.winter_override = true
	snow.emitting = true
	Game.show_toast("Winter is here! Sniff for a blue scent and curl up in a safe spot.")


## Wind grows slowly through autumn and picks up strongly near the end;
## the crickets fall silent as it gets colder.
func _apply_audio(progress: float) -> void:
	var wind := lerpf(0.1, 0.3, progress / wind_rise_start)
	if progress > wind_rise_start:
		wind = lerpf(0.3, 1.0, (progress - wind_rise_start) / (1.0 - wind_rise_start))
	Sound.set_wind(wind)
	Sound.set_insects(1.0 - progress * 1.3)


func _apply_season(progress: float) -> void:
	sun.light_color = _sun_color.lerp(Color(0.75, 0.82, 1.0), progress * 0.8)
	sun.light_energy = _sun_energy * lerpf(1.0, 0.65, progress)


## A soft warm glow around the hedgehog, so kids can see it at night.
func _add_lantern() -> void:
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.6)
	glow.light_energy = 1.4
	glow.omni_range = 5.0
	glow.position = Vector3(0, 1.2, 0)
	glow.shadow_enabled = false
	player.add_child(glow)

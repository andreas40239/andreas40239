extends Node3D
## Prototype level controller: the winter clock, the sniff-mode look, and
## the hibernation ending with its star rating.

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
	hud.bind(player)
	for spot in get_tree().get_nodes_in_group("hibernation_spots"):
		spot.hibernate_requested.connect(_on_hibernate_requested)
	environment.adjustment_enabled = true
	get_tree().create_timer(1.5).timeout.connect(Game.unlock_fact.bind("start"))
	Game.show_toast("Find food, stay safe and build a cosy nest before winter!")
	Sound.start_level_audio()
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
	label.text = "?!."
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 12
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
	player.start_sleep(spot.global_position)
	camera_rig.start_orbit()
	snow.emitting = true
	var tween := create_tween()
	tween.tween_property(sun, "light_energy", 0.35, 4.0)
	# The wind settles down for a peaceful sleep.
	create_tween().tween_method(Sound.set_wind, 0.6, 0.15, 5.0)
	Sound.set_insects(0.0)
	hud.play_hibernation(stars, criteria, player.stats)


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
	sun.light_color = Color(1.0, 0.9, 0.75).lerp(Color(0.75, 0.82, 1.0), progress)
	sun.light_energy = lerpf(1.2, 0.75, progress)

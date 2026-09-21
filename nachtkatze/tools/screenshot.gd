extends Node
## Entwicklerwerkzeug: macht Bilder vom Graubox-Level, damit sich der
## Levelaufbau ohne Editor pruefen laesst.
##
## Start: xvfb-run godot --rendering-driver opengl3 --path . \
##          --resolution 1280x720 res://tools/screenshot.tscn
## Die Bilder landen in user:// (siehe Ausgabe).

const LEVEL_PATH := "res://scenes/levels/level_greybox.tscn"
const TUTORIAL_PATH := "res://scenes/levels/level_00_tutorial.tscn"

## Aufnahmen fuer das Tutorial-Level (Aufruf mit "-- tutorial").
const TUTORIAL_SHOTS := [
	{"name": "tut_00_spielansicht", "position": Vector3.ZERO, "fov": 0.0},
	{"name": "tut_01_start", "position": Vector3(6.0, 3.0, 15.0), "fov": 55.0},
	{"name": "tut_02_balkon", "position": Vector3(13.0, 4.0, 16.0), "fov": 55.0},
	{"name": "tut_03_hund", "position": Vector3(20.0, 4.0, 16.0), "fov": 55.0},
	{"name": "tut_04_dach", "position": Vector3(29.0, 6.5, 17.0), "fov": 58.0},
	{"name": "tut_05_ziel", "position": Vector3(36.0, 6.0, 15.0), "fov": 55.0},
]

## "spielansicht" nutzt die echte Verfolgerkamera an der Startposition,
## alle anderen Eintraege sind feste Uebersichtsstandorte.
const SHOTS := [
	{"name": "00_spielansicht", "position": Vector3.ZERO, "fov": 0.0},
	{"name": "01_strasse", "position": Vector3(7.0, 3.0, 16.0), "fov": 55.0},
	{"name": "02_fassade", "position": Vector3(22.0, 5.0, 18.0), "fov": 55.0},
	{"name": "03_daecher", "position": Vector3(34.0, 6.0, 18.0), "fov": 55.0},
	{"name": "04_ziel", "position": Vector3(52.0, 6.5, 20.0), "fov": 60.0},
	{"name": "05_uebersicht", "position": Vector3(28.0, 7.0, 46.0), "fov": 70.0},
]

func _ready() -> void:
	await get_tree().process_frame
	var tutorial := OS.get_cmdline_user_args().has("tutorial")
	var shots: Array = TUTORIAL_SHOTS if tutorial else SHOTS
	var level: Node = load(TUTORIAL_PATH if tutorial else LEVEL_PATH).instantiate()
	get_tree().root.add_child(level)
	await get_tree().physics_frame

	var camera: Camera3D = level.get_node("Camera3D")
	camera.set_physics_process(false)
	var player: Node3D = level.get_node("Player")
	player.set_physics_process(false)

	for shot in shots:
		if shot["fov"] <= 0.0:
			# Echte Spielansicht: Kamera und Katze bleiben, wie sie das Level setzt.
			camera.set_physics_process(true)
			player.set_physics_process(true)
			for i in 30:
				await get_tree().physics_frame
			for i in 4:
				await RenderingServer.frame_post_draw
			var view := get_viewport().get_texture().get_image()
			view.save_png("user://%s.png" % shot["name"])
			print("Bild gespeichert: ",
				ProjectSettings.globalize_path("user://%s.png" % shot["name"]))
			camera.set_physics_process(false)
			player.set_physics_process(false)
			continue
		camera.global_position = shot["position"]
		camera.rotation = Vector3.ZERO
		camera.fov = shot["fov"]
		# Katze im Bild halten, damit der Massstab sichtbar bleibt.
		player.global_position = Vector3(shot["position"].x, player.global_position.y, 0.0)
		for i in 4:
			await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "user://%s.png" % shot["name"]
		image.save_png(path)
		print("Bild gespeichert: ", ProjectSettings.globalize_path(path))

	get_tree().quit()

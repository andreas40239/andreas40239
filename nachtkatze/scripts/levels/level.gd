extends Node3D
class_name Level
## Wurzelknoten eines Levels. Liest die Levelparameter aus einer LevelData-
## Ressource (GDD Abschnitt 13) und stellt Beleuchtung sowie Lebenspunkte ein.

@export var level_data: LevelData

@onready var player: Player = $Player
@onready var hud: HUD = $HUD

func _ready() -> void:
	PlayerInput.reset()
	var data := level_data if level_data != null else LevelData.new()
	player.max_health = data.max_health
	player.no_fail = data.no_fail
	player.health = clampi(data.start_health, 1, data.max_health)
	player.health_changed.emit(player.health, player.max_health)
	hud.bind_player(player)
	_apply_time_of_day(data.time_of_day)
	Game.register_level(self, data)

## Beleuchtungs-Voreinstellungen je Tageszeit (GDD Abschnitt 9).
## Bewusst schlicht - der Grafikstil folgt in Meilenstein 5.
func _apply_time_of_day(time_of_day: LevelData.TimeOfDay) -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	var light_color := Color(1.0, 0.96, 0.88)
	var light_energy := 1.0
	var sky_color := Color(0.42, 0.62, 0.85)
	var ambient_energy := 0.35
	# Glow nur bei Laternen- und Fensterlicht (GDD Abschnitt 9).
	var use_glow := false

	match time_of_day:
		LevelData.TimeOfDay.DAEMMERUNG:
			light_color = Color(1.0, 0.62, 0.38)
			light_energy = 0.7
			sky_color = Color(0.38, 0.26, 0.38)
			ambient_energy = 0.3
			use_glow = true
		LevelData.TimeOfDay.NACHT:
			light_color = Color(0.55, 0.62, 0.9)
			light_energy = 0.25
			sky_color = Color(0.07, 0.09, 0.16)
			ambient_energy = 0.2
			use_glow = true

	if sun != null:
		sun.light_color = light_color
		sun.light_energy = light_energy
	if world_environment != null and world_environment.environment != null:
		var env := world_environment.environment
		env.background_color = sky_color
		env.ambient_light_color = sky_color.lerp(light_color, 0.4)
		env.ambient_light_energy = ambient_energy
		env.glow_enabled = use_glow

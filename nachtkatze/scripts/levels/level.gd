extends Node3D
class_name Level
## Wurzelknoten eines Levels. Liest die Levelparameter aus einer LevelData-
## Ressource (GDD Abschnitt 13) und stellt Beleuchtung sowie Lebenspunkte ein.

@export var level_data: LevelData

@onready var player: Player = $Player
@onready var hud: HUD = $HUD

var night_view: NightView = null

func _ready() -> void:
	PlayerInput.reset()
	var data := level_data if level_data != null else LevelData.new()
	player.max_health = data.max_health
	player.no_fail = data.no_fail
	player.health = clampi(data.start_health, 1, data.max_health)
	player.health_changed.emit(player.health, player.max_health)
	hud.bind_player(player)
	_apply_time_of_day(data.time_of_day)
	if data.view_radius > 0.0:
		night_view = NightView.new()
		night_view.name = "Nachtsicht"
		night_view.setup(player, data.view_radius, data.view_darkness)
		add_child(night_view)
	Game.register_level(self, data)

## Beleuchtungs-Voreinstellungen je Tageszeit (GDD Abschnitt 9).
func _apply_time_of_day(time_of_day: LevelData.TimeOfDay) -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	var light_color := Color(1.0, 0.96, 0.88)
	var light_energy := 1.0
	var sky_color := Color(0.42, 0.62, 0.85)
	var ambient_energy := 0.35
	# Fenster, Laternen und Leuchtband leuchten erst abends richtig.
	var emission := 1.0
	# Glow nur bei Laternen- und Fensterlicht (GDD Abschnitt 9).
	var use_glow := false

	match time_of_day:
		LevelData.TimeOfDay.DAEMMERUNG:
			# Orange-Violett, tiefe Sonne, erste Laternen an.
			light_color = Color(1.0, 0.66, 0.44)
			light_energy = 0.8
			sky_color = Color(0.46, 0.30, 0.44)
			ambient_energy = 0.42
			emission = 1.7
			use_glow = true
		LevelData.TimeOfDay.NACHT:
			# Dunkles Blaugrau mit leichter Lichtverschmutzung, kuehles Mondlicht.
			light_color = Color(0.58, 0.66, 0.95)
			light_energy = 0.42
			sky_color = Color(0.10, 0.12, 0.21)
			ambient_energy = 0.4
			emission = 2.4
			use_glow = true

	if sun != null:
		sun.light_color = light_color
		sun.light_energy = light_energy
		# Der Ersatzpfad des Toon-Shaders kennt die Szenenlichter nicht.
		AssetKit.set_sun(-sun.global_transform.basis.z, light_color, light_energy * 0.85)
	AssetKit.set_emission(emission)
	if world_environment != null and world_environment.environment != null:
		var env := world_environment.environment
		env.background_color = sky_color
		env.ambient_light_color = sky_color.lerp(light_color, 0.4)
		env.ambient_light_energy = ambient_energy
		env.glow_enabled = use_glow

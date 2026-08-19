extends CanvasLayer

@onready var health_bar: ProgressBar = $Control/HealthBar
@onready var satiety_bar: ProgressBar = $Control/SatietyBar
@onready var level_label: Label = $Control/LevelLabel
@onready var message_label: Label = $Control/MessageLabel
@onready var restart_button: Button = $Control/RestartButton

func _ready() -> void:
	GameManager.satiety_changed.connect(_on_satiety_changed)
	GameManager.leveled_up.connect(_on_leveled_up)
	GameManager.player_caught.connect(_on_player_caught)
	restart_button.pressed.connect(_on_restart_pressed)
	_on_satiety_changed(GameManager.satiety, GameManager.get_satiety_threshold())
	_update_level_label()
	restart_button.visible = GameManager.run_complete

	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_health_changed)
		_on_health_changed(player.health, player.max_health)

func _on_health_changed(value: float, max_value: float) -> void:
	health_bar.max_value = max(max_value, 1.0)
	health_bar.value = value

func _on_satiety_changed(value: float, max_value: float) -> void:
	if max_value <= 0.0:
		satiety_bar.max_value = 1.0
		satiety_bar.value = 1.0
	else:
		satiety_bar.max_value = max_value
		satiety_bar.value = value

func _on_leveled_up(_new_level: int) -> void:
	_update_level_label()
	restart_button.visible = GameManager.run_complete
	# The level-up popup (fireworks + upgrade choice) already announces
	# this dramatically; only the final-level message is still worth a
	# separate HUD toast.
	if GameManager.run_complete:
		_show_message("Vertical Slice geschafft! Hoechstes Level erreicht.")

func _on_player_caught() -> void:
	_show_message("Erwischt! Zurueck zum Bau.")

func _on_restart_pressed() -> void:
	restart_button.visible = false
	GameManager.restart_game()
	get_tree().reload_current_scene()

func _update_level_label() -> void:
	level_label.text = "Level %d" % GameManager.growth_level

func _show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true
	await get_tree().create_timer(2.5).timeout
	message_label.visible = false

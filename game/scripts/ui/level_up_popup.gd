extends CanvasLayer

## Shown the instant satiety hits its threshold (GameManager.level_up_ready)
## instead of leveling up requiring a trip back to the den. Pauses the
## game, bursts a little fireworks show, and lets the player pick which
## power to upgrade - the choice itself is what applies the level-up.

@onready var defense_button: Button = $Panel/VBox/Buttons/DefenseOption/DefenseButton
@onready var attack_button: Button = $Panel/VBox/Buttons/AttackOption/AttackButton
@onready var fireworks: Node2D = $Fireworks

func _ready() -> void:
	visible = false
	defense_button.pressed.connect(func(): _choose("defense"))
	attack_button.pressed.connect(func(): _choose("attack"))
	GameManager.level_up_ready.connect(_on_level_up_ready)

func _on_level_up_ready() -> void:
	visible = true
	get_tree().paused = true
	_launch_fireworks()

func _choose(upgrade: String) -> void:
	if not visible:
		return
	GameManager.choose_upgrade(upgrade)
	visible = false
	get_tree().paused = false

func _launch_fireworks() -> void:
	for burst in fireworks.get_children():
		if burst is CPUParticles2D:
			burst.restart()

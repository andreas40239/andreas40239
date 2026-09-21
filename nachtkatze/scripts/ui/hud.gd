extends CanvasLayer
class_name HUD
## HUD und Menues im Level (GDD Abschnitt 12):
## Lebenspunkte oben links, Pause oben rechts, Joystick und Sprungtaste unten,
## dazu Pausen-, Sieg- und Game-Over-Anzeige sowie die Tutorial-Symbole.
## Start- und Hauptmenue stehen in scenes/ui/.

@onready var paw_container: HBoxContainer = %Paws
@onready var pause_button: TouchButton = %PauseButton
@onready var jump_button: TouchButton = %JumpButton
@onready var joystick: VirtualJoystick = %Joystick
@onready var touch_controls: Control = %TouchControls
@onready var pause_panel: Control = %PausePanel
@onready var win_panel: Control = %WinPanel
@onready var game_over_panel: Control = %GameOverPanel
@onready var hint_overlay: HintOverlay = %HintOverlay

var _player: Player = null
var _paws: Array[PawIcon] = []

func _ready() -> void:
	add_to_group("hud")
	pause_button.pressed.connect(_toggle_pause)
	jump_button.pressed.connect(PlayerInput.press_jump)
	jump_button.released.connect(PlayerInput.release_jump)

	%ResumeButton.pressed.connect(_toggle_pause)
	%RestartButton.pressed.connect(_restart)
	%RetryButton.pressed.connect(_restart)
	%NextButton.pressed.connect(_continue)
	%MenuButton.pressed.connect(Game.open_menu)
	%WinMenuButton.pressed.connect(Game.open_menu)

	pause_panel.visible = false
	win_panel.visible = false
	game_over_panel.visible = false

	Game.level_completed.connect(_on_level_completed)
	Game.level_failed.connect(_on_level_failed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not Game.is_level_finished:
		_toggle_pause()
		get_viewport().set_input_as_handled()

## Wird vom Level aufgerufen, sobald die Spielerkatze bereit ist.
func bind_player(player: Player) -> void:
	_player = player
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health)

func _on_health_changed(current: int, maximum: int) -> void:
	if _paws.size() != maximum:
		_rebuild_paws(maximum)
	for i in _paws.size():
		_paws[i].filled = i < current

func _rebuild_paws(count: int) -> void:
	for paw in _paws:
		paw.queue_free()
	_paws.clear()
	for i in count:
		var paw := PawIcon.new()
		paw_container.add_child(paw)
		_paws.append(paw)

# --- Tutorial-Hinweise (GDD Abschnitt 7) ------------------------------------

func show_hint(kind: HintOverlay.Hint) -> void:
	hint_overlay.show_hint(kind)

func hide_hint(kind: HintOverlay.Hint = HintOverlay.Hint.KEIN) -> void:
	hint_overlay.hide_hint(kind)

# --- Pause ------------------------------------------------------------------

func _toggle_pause() -> void:
	if Game.is_level_finished:
		return
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_panel.visible = paused
	touch_controls.visible = not paused
	PlayerInput.reset()

func _restart() -> void:
	Game.restart_level()

func _continue() -> void:
	if Game.has_next_level():
		Game.load_next_level()
	else:
		Game.restart_level()

# --- Levelende --------------------------------------------------------------

func _on_level_completed(_data: LevelData) -> void:
	hint_overlay.hide_hint()
	touch_controls.visible = false
	pause_panel.visible = false
	win_panel.visible = true
	%NextButton.text = "Weiter" if Game.has_next_level() else "Nochmal spielen"
	await get_tree().create_timer(1.2, true, false, true).timeout
	# Der Spieler kann in der Zwischenzeit schon weitergetippt haben.
	if not is_inside_tree():
		return
	get_tree().paused = true

func _on_level_failed(_data: LevelData) -> void:
	hint_overlay.hide_hint()
	touch_controls.visible = false
	pause_panel.visible = false
	game_over_panel.visible = true
	# GDD Abschnitt 3: kurzer Hinweis, danach Neustart des Levels von vorne.
	await get_tree().create_timer(Game.AUTO_RESTART_DELAY, true, false, true).timeout
	if not is_inside_tree():
		return
	if game_over_panel.visible:
		_restart()

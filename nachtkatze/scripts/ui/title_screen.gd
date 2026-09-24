extends Node3D
## Startbild (GDD Abschnitt 12): Daemmerungsszene mit der Katze als Silhouette
## auf dem Dach, dahinter der angestrahlte Kirchturm. Antippen fuehrt ins
## Hauptmenue.

@onready var _hint: Control = %TippHinweis

var _time := 0.0

func _ready() -> void:
	# Im Menue nur Musik, das Ambient gehoert zu den Levels.
	Sfx.stop_ambient()
	PlayerInput.reset()

func _process(delta: float) -> void:
	# Der Hinweis pulsiert, damit klar ist, dass es weitergeht.
	_time += delta
	if _hint != null:
		_hint.modulate.a = 0.45 + sin(_time * 3.0) * 0.35

func _unhandled_input(event: InputEvent) -> void:
	var tapped := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or event.is_action_pressed("ui_accept")
	if tapped:
		get_viewport().set_input_as_handled()
		Game.open_menu()

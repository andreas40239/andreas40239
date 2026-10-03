extends Node
## App-Start und Navigation (ScreenRouter): Titel -> Levelauswahl -> Spiel.

const SCREENS := {
	&"title": "res://scenes/meta/TitleScreen.tscn",
	&"level_select": "res://scenes/meta/LevelSelect.tscn",
	&"game": "res://scenes/game/Game.tscn",
}

var _current: Node
var _fade_layer: CanvasLayer
var _fade: ColorRect


func _ready() -> void:
	get_tree().root.theme = UiTheme.get_theme()
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.theme = UiTheme.get_theme()
	_fade.color = Color("8fd16a")
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade)
	GameState.screen_requested.connect(_on_screen_requested)
	AudioManager.play_music()
	_show(&"title", {})


func _on_screen_requested(screen: StringName, params: Dictionary) -> void:
	_show.call_deferred(screen, params)


func _show(screen: StringName, params: Dictionary) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if params.has("level"):
		GameState.current_level = clampi(int(params["level"]), 1, DataRegistry.level_count())
	if _current:
		_current.queue_free()
		remove_child(_current)
	_current = load(SCREENS[screen]).instantiate()
	add_child(_current)
	move_child(_fade_layer, -1)
	_fade.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.35)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _current and _current.has_method("go_back"):
			_current.go_back()
		else:
			get_tree().quit()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		# App im Hintergrund: Spiel anhalten (Android).
		if _current is Game and not get_tree().paused:
			(_current as Game).toggle_pause()

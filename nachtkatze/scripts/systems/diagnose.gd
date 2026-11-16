extends CanvasLayer
## Autoload "Diagnose": kleine Statuszeile fuer Testversionen auf dem Geraet.
##
## Zeigt Version, Bildzaehler, Bilder je Sekunde, aktuelle Szene, die letzte
## erkannte Eingabe und die juengsten Fehlermeldungen aus der Logdatei. Damit
## laesst sich ohne Kabel und Entwicklerwerkzeug sagen, ob das Spiel haengt,
## ob Beruehrungen ankommen und ob das Geraet Fehler meldet.
##
## Sichtbar nur in Debug-Versionen auf Android (oder mit "-- diagnose" am
## Rechner); in einer Release-Version entfernt sie sich selbst.

const LOG_PATH := "user://logs/godot.log"
const MAX_ERRORS := 4

var last_input := "noch keine"
var input_count := 0

var _label: Label = null
var _frames := 0
var _log_timer := 0.0
var _errors: Array[String] = []

func _ready() -> void:
	var wanted := (OS.is_debug_build() and OS.has_feature("android")) \
		or OS.get_cmdline_user_args().has("diagnose")
	if not wanted:
		queue_free()
		return
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_label.offset_top = 4
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)

func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		input_count += 1
		last_input = "Touch %s" % ("gedrueckt" if touch.pressed else "losgelassen")
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		input_count += 1
		last_input = "Mausklick"
	elif event is InputEventKey and (event as InputEventKey).pressed:
		input_count += 1
		last_input = "Taste"

func _process(delta: float) -> void:
	if _label == null:
		return
	_frames += 1
	_log_timer -= delta
	if _log_timer <= 0.0:
		_log_timer = 1.0
		_read_errors()
	var scene := get_tree().current_scene
	var lines := PackedStringArray()
	lines.append("v%s  |  Bild %d  |  %d B/s  |  Szene: %s  |  Eingabe: %s (%d)" % [
		ProjectSettings.get_setting("application/config/version", "?"), _frames,
		int(Engine.get_frames_per_second()), scene.name if scene != null else "keine",
		last_input, input_count])
	lines.append_array(PackedStringArray(_errors))
	_label.text = "\n".join(lines)

## Juengste Fehlerzeilen aus der Logdatei (Projekteinstellung file_logging).
func _read_errors() -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.READ)
	if file == null:
		return
	# Nur das Ende lesen - die Datei kann lang werden.
	var length := file.get_length()
	file.seek(maxi(length - 6000, 0))
	var text := file.get_buffer(mini(length, 6000)).get_string_from_utf8()
	_errors.clear()
	for line in text.split("\n"):
		if line.contains("ERROR") and not line.contains("resources still in use"):
			_errors.append(line.strip_edges().left(150))
	while _errors.size() > MAX_ERRORS:
		_errors.pop_front()

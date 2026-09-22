extends Node
## Autoload "Musik": spielt die Hintergrundmusik (GDD Abschnitt 11).
##
## Drei selbst erzeugte Stuecke, im Menue umschaltbar. Sie laufen als Schleife
## durch, ein Levelwechsel unterbricht sie nicht. Gespielt wird auf dem Bus
## "Music", den der Musikschalter in den Einstellungen stummt.

## Reihenfolge wie im GDD: Tag heiter, Daemmerung ruhiger, Nacht zurueckhaltend.
const TRACKS := [
	{"name": "Gassenlied", "zeit": "Tag", "pfad": "res://assets/musik/gassenlied.wav"},
	{"name": "Abendwind", "zeit": "Dämmerung", "pfad": "res://assets/musik/abendwind.wav"},
	{"name": "Nachtstreifen", "zeit": "Nacht", "pfad": "res://assets/musik/nachtstreifen.wav"},
]

const FADE_TIME := 0.6

signal track_changed(index: int)

var current_track: int = 0

var _player: AudioStreamPlayer = null
var _fade_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	play_track(SaveGame.music_track, false)

func track_count() -> int:
	return TRACKS.size()

func track_name(index: int) -> String:
	var track: Dictionary = TRACKS[clampi(index, 0, TRACKS.size() - 1)]
	return "%s (%s)" % [track["name"], track["zeit"]]

## Spielt ein Stueck; mit Ueberblendung, wenn schon Musik laeuft.
func play_track(index: int, fade: bool = true) -> void:
	index = clampi(index, 0, TRACKS.size() - 1)
	current_track = index
	var stream: AudioStream = load(TRACKS[index]["pfad"])
	if stream == null:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if fade and _player.playing:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_player, "volume_db", -40.0, FADE_TIME * 0.5)
		_fade_tween.tween_callback(_start.bind(stream))
		_fade_tween.tween_property(_player, "volume_db", 0.0, FADE_TIME)
	else:
		_player.volume_db = 0.0
		_start(stream)
	track_changed.emit(index)

## Naechstes Stueck - so schaltet das Menue durch.
func next_track() -> void:
	var next := (current_track + 1) % TRACKS.size()
	SaveGame.set_music_track(next)
	play_track(next)

func _start(stream: AudioStream) -> void:
	_player.stream = stream
	_player.play()

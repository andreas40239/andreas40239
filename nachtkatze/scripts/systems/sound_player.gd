extends Node
## Autoload "Sfx": Soundeffekte und Ambient je Tageszeit (GDD Abschnitt 11).
##
## Effekte laufen auf dem Bus "SFX", das Ambient auf dem Bus "Ambient", der in
## "SFX" muendet - der Sound-Schalter im Menue stummt damit beides.
## Geraeusche der Katze und der Oberflaeche sind nicht raeumlich, Gegner und
## Autos klingen von ihrer Position aus (leiser, wenn sie weiter weg sind).
##
## Die Klaenge erzeugt tools/sfx_erzeugen.py. Wer sie durch Aufnahmen ersetzen
## will, legt Dateien mit gleichem Namen ab.

signal sound_played(sound_name: StringName)

const SFX_DIR := "res://assets/sfx/"
const AMBIENT_DIR := "res://assets/ambient/"

## Name -> Varianten (Dateien ohne Endung). Varianten wechseln zufaellig.
const SOUNDS := {
	&"pfote": ["pfote_1", "pfote_2", "pfote_3"],
	&"kratzen": ["kratzen_1", "kratzen_2"],
	&"landung": ["landung"],
	&"knuspern": ["knuspern"],
	&"miau": ["miau"],
	&"schnurren": ["schnurren"],
	&"klaeffen": ["klaeffen"],
	&"knurren": ["knurren"],
	&"bellen": ["bellen"],
	&"fauchen": ["fauchen"],
	&"kampf": ["kampf"],
	&"motor": ["motor"],
	&"hupe": ["hupe"],
	&"klick": ["klick"],
	&"geschafft": ["geschafft"],
	&"game_over": ["game_over"],
}

## Grundlautstaerke je Geraeusch in dB - hier wird abgemischt.
const VOLUMES := {
	&"pfote": -14.0, &"kratzen": -12.0, &"landung": -8.0, &"knuspern": -4.0,
	&"miau": -3.0, &"schnurren": -2.0, &"klaeffen": -3.0, &"knurren": -1.0,
	&"bellen": -3.0, &"fauchen": -5.0, &"kampf": -3.0, &"motor": -6.0,
	&"hupe": -6.0, &"klick": -8.0, &"geschafft": 0.0, &"game_over": 0.0,
}

## Leichte Tonhoehenstreuung, damit Wiederholungen nicht mechanisch klingen.
const PITCH_SPREAD := {&"pfote": 0.08, &"kratzen": 0.1, &"landung": 0.06, &"knuspern": 0.06,
	&"miau": 0.05, &"bellen": 0.05, &"klaeffen": 0.04}

const AMBIENT := {
	LevelData.TimeOfDay.TAG: "tag",
	LevelData.TimeOfDay.DAEMMERUNG: "daemmerung",
	LevelData.TimeOfDay.NACHT: "nacht",
}
const AMBIENT_VOLUME := -4.0

const POOL_SIZE := 8
const POOL_3D_SIZE := 8
## Raeumliche Geraeusche: bis zu dieser Entfernung zur Kamera hoerbar.
const MAX_DISTANCE := 38.0
const UNIT_SIZE := 9.0

var ambient_name: String = ""

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _next := 0
var _next_3d := 0
var _ambient_player: AudioStreamPlayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound_name in SOUNDS:
		var variants: Array[AudioStream] = []
		for file in SOUNDS[sound_name]:
			var stream := load(SFX_DIR + file + ".wav") as AudioStream
			if stream != null:
				variants.append(stream)
		_streams[sound_name] = variants
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)
	for i in POOL_3D_SIZE:
		_pool_3d.append(_make_player_3d())
		add_child(_pool_3d[i])
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Ambient"
	_ambient_player.volume_db = AMBIENT_VOLUME
	add_child(_ambient_player)

	Game.level_started.connect(_on_level_started)
	Game.level_completed.connect(func(_data): play(&"geschafft"))
	Game.level_failed.connect(func(_data): play(&"game_over"))
	# Jede Menue-Schaltflaeche klickt, ohne dass jede Szene das selbst verdrahtet.
	get_tree().node_added.connect(_on_node_added)

# --- Effekte ----------------------------------------------------------------

func has_sound(sound_name: StringName) -> bool:
	return _streams.has(sound_name) and not (_streams[sound_name] as Array).is_empty()

## Spielt ein Geraeusch ohne Raumposition (Katze, Oberflaeche).
func play(sound_name: StringName, volume_offset: float = 0.0, pitch: float = 1.0) -> void:
	var stream := _pick(sound_name)
	if stream == null:
		return
	var player := _free_player()
	player.stream = stream
	player.volume_db = VOLUMES.get(sound_name, 0.0) + volume_offset
	player.pitch_scale = _pitch(sound_name, pitch)
	player.play()
	sound_played.emit(sound_name)

## Spielt ein Geraeusch an einer Stelle der Welt (Gegner).
func play_at(sound_name: StringName, world_position: Vector3, volume_offset: float = 0.0,
		pitch: float = 1.0) -> void:
	var stream := _pick(sound_name)
	if stream == null:
		return
	var player := _free_player_3d()
	player.stream = stream
	player.global_position = world_position
	player.volume_db = VOLUMES.get(sound_name, 0.0) + volume_offset
	player.pitch_scale = _pitch(sound_name, pitch)
	player.play()
	sound_played.emit(sound_name)

## Eigener, dauerhafter Spieler fuer Schleifen, die mit einem Objekt wandern
## (Motor des fahrenden Autos). Der Aufrufer haengt ihn an sein Objekt.
func make_loop_player(sound_name: StringName) -> AudioStreamPlayer3D:
	var player := _make_player_3d()
	player.stream = _pick(sound_name)
	player.volume_db = VOLUMES.get(sound_name, 0.0)
	return player

func _make_player_3d() -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = "SFX"
	player.unit_size = UNIT_SIZE
	player.max_distance = MAX_DISTANCE
	player.max_db = 2.0
	player.attenuation_filter_cutoff_hz = 20500.0   # keine Dumpfheit in der Ferne
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	return player

func _pick(sound_name: StringName) -> AudioStream:
	if not has_sound(sound_name):
		push_warning("Unbekanntes Geraeusch: %s" % sound_name)
		return null
	var variants: Array = _streams[sound_name]
	return variants[randi() % variants.size()]

func _pitch(sound_name: StringName, pitch: float) -> float:
	var spread: float = PITCH_SPREAD.get(sound_name, 0.0)
	return pitch * (1.0 + randf_range(-spread, spread))

func _free_player() -> AudioStreamPlayer:
	for player in _pool:
		if not player.playing:
			return player
	_next = (_next + 1) % _pool.size()
	return _pool[_next]

func _free_player_3d() -> AudioStreamPlayer3D:
	for player in _pool_3d:
		if not player.playing:
			return player
	_next_3d = (_next_3d + 1) % _pool_3d.size()
	return _pool_3d[_next_3d]

# --- Ambient ----------------------------------------------------------------

## Hintergrundgeraeusche je Tageszeit. Laeuft dieselbe Schleife schon (Neustart
## des Levels), spielt sie ohne Unterbruch weiter.
func play_ambient(time_of_day: LevelData.TimeOfDay) -> void:
	var file: String = AMBIENT.get(time_of_day, "tag")
	if file == ambient_name and _ambient_player.playing:
		return
	var stream := load(AMBIENT_DIR + file + ".wav") as AudioStream
	if stream == null:
		return
	ambient_name = file
	_ambient_player.stream = stream
	_ambient_player.play()

func stop_ambient() -> void:
	ambient_name = ""
	_ambient_player.stop()

func is_ambient_playing() -> bool:
	return _ambient_player.playing

func _on_level_started(data: LevelData) -> void:
	play_ambient(data.time_of_day if data != null else LevelData.TimeOfDay.TAG)

# --- Oberflaeche ------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	play(&"klick")

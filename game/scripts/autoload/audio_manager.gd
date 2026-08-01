extends Node

## Background music + ocean ambience (looping) and short SFX for eating,
## getting caught, and leveling up. Connects to GameManager signals
## directly so gameplay code doesn't need to know audio exists.

const MUSIC_PATH := "res://assets/audio/music_loop.wav"
const OCEAN_PATH := "res://assets/audio/ocean_loop.wav"
const EAT_PATH := "res://assets/audio/eat.wav"
const CAUGHT_PATH := "res://assets/audio/caught.wav"
const LEVEL_UP_PATH := "res://assets/audio/level_up.wav"

const MUSIC_VOLUME_DB := -8.0
const OCEAN_VOLUME_DB := -14.0

var _music_player: AudioStreamPlayer
var _ocean_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player := 0

var _eat_stream: AudioStream
var _caught_stream: AudioStream
var _level_up_stream: AudioStream

func _ready() -> void:
	_music_player = _make_looping_player(MUSIC_PATH, MUSIC_VOLUME_DB)
	_ocean_player = _make_looping_player(OCEAN_PATH, OCEAN_VOLUME_DB)
	_music_player.play()
	_ocean_player.play()

	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)

	_eat_stream = load(EAT_PATH)
	_caught_stream = load(CAUGHT_PATH)
	_level_up_stream = load(LEVEL_UP_PATH)

	GameManager.leveled_up.connect(_on_leveled_up)
	GameManager.player_caught.connect(_on_player_caught)

func _make_looping_player(path: String, volume_db: float) -> AudioStreamPlayer:
	var stream: AudioStreamWAV = load(path)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player

func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := _sfx_players[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
	player.stream = stream
	player.play()

func play_eat() -> void:
	_play_sfx(_eat_stream)

func _on_leveled_up(_new_level: int) -> void:
	_play_sfx(_level_up_stream)

func _on_player_caught() -> void:
	_play_sfx(_caught_stream)

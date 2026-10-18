class_name GameAudio
extends Node
## Musik-Playlist (3 Songs, wechseln automatisch), Motor- und Reifengeraeusche,
## Soundeffekte.
##
## Eigene Musik: einfach res://music/song1.mp3, song2.mp3, song3.mp3 ablegen.
## MP3 wird vor OGG bevorzugt.

const SONG_EXT := ["mp3", "ogg", "wav"]
const ENGINE_FILES := ["res://sounds/engine_kart.wav", "res://sounds/engine_racer.wav", "res://sounds/engine_truck.wav"]
# Tonhoehe: [Leerlauf, Zuwachs bei Drehzahl 1.0]
const ENGINE_PITCH := [[0.75, 2.1], [0.55, 1.65], [0.6, 1.45]]

var music := AudioStreamPlayer.new()
var engine := AudioStreamPlayer.new()
var squeal := AudioStreamPlayer.new()
var music_on := true
var songs: Array[AudioStream] = []
var song_index := 0

var _engine_streams: Array[AudioStream] = []
var _engine_type := 0
var _sfx := {}
var _pool: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in [1, 2, 3]:
		for ext in SONG_EXT:
			var p := "res://music/song%d.%s" % [i, ext]
			if ResourceLoader.exists(p):
				songs.append(load(p))
				break
	music.volume_db = -7.0
	music.finished.connect(_next_song)
	add_child(music)
	for f in ENGINE_FILES:
		_engine_streams.append(load(f))
	engine.volume_db = -80.0
	add_child(engine)
	squeal.stream = load("res://sounds/squeal.wav")
	squeal.volume_db = -80.0
	add_child(squeal)
	for n in ["fanfare", "boost", "thud", "click", "error", "landing"]:
		_sfx[n] = load("res://sounds/%s.wav" % n)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	if songs.size() > 0:
		music.stream = songs[0]
		music.play()


func _next_song() -> void:
	if songs.is_empty():
		return
	song_index = (song_index + 1) % songs.size()
	music.stream = songs[song_index]
	if music_on:
		music.play()


func toggle_music() -> bool:
	music_on = not music_on
	if music_on:
		music.play()
	else:
		music.stop()
	return music_on


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _sfx.has(name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _sfx[name]
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


func start_engine(type: int) -> void:
	_engine_type = type
	engine.stream = _engine_streams[type]
	engine.volume_db = -14.0
	engine.pitch_scale = ENGINE_PITCH[type][0]
	engine.play()
	squeal.volume_db = -80.0
	squeal.play()


func stop_engine() -> void:
	engine.stop()
	squeal.stop()


func update_engine(rpm: float, throttle: float, slip: float) -> void:
	if not engine.playing:
		return
	var pr: Array = ENGINE_PITCH[_engine_type]
	engine.pitch_scale = clampf(pr[0] + pr[1] * rpm, 0.3, 4.0)
	engine.volume_db = linear_to_db(0.3 + 0.35 * throttle + 0.25 * rpm) - 5.0
	var sv := clampf((slip - 0.08) * 1.4, 0.0, 1.0)
	squeal.volume_db = linear_to_db(maxf(sv * 0.9, 0.0001)) - 3.0
	squeal.pitch_scale = 0.9 + sv * 0.2

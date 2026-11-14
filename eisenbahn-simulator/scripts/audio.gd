class_name GameAudio
extends Node
## Musik und Geräusche. Musik wird weich überblendet; Geräusche laufen über einen
## kleinen Pool von Playern, Dauergeräusche (Rollen, Glocke) über eigene Player.

const MUSIC := {
	"menu": "res://assets/audio/music/menu.ogg",
	"build": "res://assets/audio/music/build.ogg",
	"drive": "res://assets/audio/music/drive.ogg",
}
const SFX := {
	"chuff": ["res://assets/audio/sfx/chuff1.wav", "res://assets/audio/sfx/chuff2.wav", "res://assets/audio/sfx/chuff3.wav", "res://assets/audio/sfx/chuff4.wav"],
	"whistle": ["res://assets/audio/sfx/whistle.ogg", "res://assets/audio/sfx/whistle2.ogg"],
	"hiss": ["res://assets/audio/sfx/hiss.ogg"],
	"brake": ["res://assets/audio/sfx/brake.ogg"],
	"bump": ["res://assets/audio/sfx/bump.wav"],
	"crash": ["res://assets/audio/sfx/crash.wav"],
	"place": ["res://assets/audio/sfx/place.wav"],
	"place_big": ["res://assets/audio/sfx/place_big.wav"],
	"erase": ["res://assets/audio/sfx/erase.wav"],
	"error": ["res://assets/audio/sfx/error.wav"],
	"click": ["res://assets/audio/sfx/click.wav"],
	"switch": ["res://assets/audio/sfx/switch.wav"],
	"success": ["res://assets/audio/sfx/success.ogg"],
	"star": ["res://assets/audio/sfx/star.wav"],
}
const LOOPS := {
	"roll": "res://assets/audio/sfx/roll_loop.ogg",
	"bell": "res://assets/audio/sfx/bell_loop.ogg",
}

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _cur_music := ""
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _streams: Dictionary = {}
var _loops: Dictionary = {}
var _loop_target: Dictionary = {}
var _music_duck := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
	_music_a = _player("Music")
	_music_b = _player("Music")
	for i in 10:
		_pool.append(_player("SFX"))
	for key in SFX:
		var arr: Array = []
		for path in SFX[key]:
			if ResourceLoader.exists(path):
				arr.append(load(path))
		_streams[key] = arr
	for key in LOOPS:
		var p := _player("SFX")
		if ResourceLoader.exists(LOOPS[key]):
			var st: AudioStream = load(LOOPS[key])
			if st is AudioStreamOggVorbis:
				(st as AudioStreamOggVorbis).loop = true
			p.stream = st
		p.volume_db = -60.0
		_loops[key] = p
		_loop_target[key] = {"vol": 0.0, "pitch": 1.0}
	apply_settings()


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not Save.music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not Save.sfx_on)


func music(track: String) -> void:
	if track == _cur_music:
		return
	_cur_music = track
	var path: String = MUSIC.get(track, "")
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	var has_new := path != "" and ResourceLoader.exists(path)
	if not old.playing and not has_new:
		return
	var tw := create_tween().set_parallel(true)
	if old.playing:
		tw.tween_property(old, "volume_db", -50.0, 1.2)
		tw.tween_callback(old.stop).set_delay(1.25)
	if has_new:
		var st: AudioStream = load(path)
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		_music_a.stream = st
		_music_a.volume_db = -40.0
		_music_a.play()
		tw.tween_property(_music_a, "volume_db", -9.0, 1.4)


func play(key: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var arr: Array = _streams.get(key, [])
	if arr.is_empty():
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = arr[randi() % arr.size()]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Dauergeräusch: vol 0…1 (0 = aus), pitch = Tonhöhe.
func loop(key: String, vol: float, pitch: float = 1.0) -> void:
	if _loop_target.has(key):
		_loop_target[key] = {"vol": clampf(vol, 0.0, 1.0), "pitch": pitch}


func stop_loops() -> void:
	for key in _loop_target:
		_loop_target[key] = {"vol": 0.0, "pitch": 1.0}


func _process(dt: float) -> void:
	for key in _loops:
		var p: AudioStreamPlayer = _loops[key]
		if p.stream == null:
			continue
		var tgt: Dictionary = _loop_target[key]
		var cur := db_to_linear(p.volume_db) if p.playing else 0.0
		var nv := move_toward(cur, tgt["vol"], dt * 2.5)
		if nv > 0.003:
			if not p.playing:
				p.play()
			p.volume_db = linear_to_db(nv)
			p.pitch_scale = lerpf(p.pitch_scale, tgt["pitch"], clampf(dt * 6.0, 0.0, 1.0))
		elif p.playing:
			p.stop()

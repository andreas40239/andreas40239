extends Node
## Autoload "Sfx": Soundeffekte (positional + UI), Herzschlag und Musik mit Überblendung.

const DIR := "res://assets/audio/"
const POOL_3D := 14
const POOL_UI := 6

var _streams := {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool_ui: Array[AudioStreamPlayer] = []
var _i3 := 0
var _iu := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _heart: AudioStreamPlayer
var chase_level := 0.0      # 0..1 Zielwert: wie stark die Verfolgungsmusik zu hören ist
var heart_level := 0.0      # 0..1 Zielwert Herzschlag
var _chase := 0.0
var _heartv := 0.0
var _music_started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 4.0
		p.max_distance = 30.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.7
		add_child(p)
		_pool3d.append(p)
	for i in POOL_UI:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool_ui.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	_heart = AudioStreamPlayer.new()
	for p in [_music_a, _music_b, _heart]:
		p.volume_db = -60.0
		add_child(p)


func stream(sname: String) -> AudioStream:
	if _streams.has(sname):
		return _streams[sname]
	var s: AudioStream = null
	for ext in [".wav", ".ogg"]:
		var path: String = DIR + sname + ext
		if ResourceLoader.exists(path):
			s = load(path)
			break
	_streams[sname] = s
	return s


## Positionaler Effekt in der Spielwelt.
func play_at(sname: String, pos: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	if not GameState.sfx_on:
		return
	var s := stream(sname)
	if s == null:
		return
	var p := _pool3d[_i3]
	_i3 = (_i3 + 1) % POOL_3D
	p.stream = s
	p.global_position = pos + Vector3(0, 1.0, 0)
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.93, 1.07)
	p.play()


## Nicht-positionaler Effekt (UI, Ansagen).
func play(sname: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not GameState.sfx_on:
		return
	var s := stream(sname)
	if s == null:
		return
	var p := _pool_ui[_iu]
	_iu = (_iu + 1) % POOL_UI
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func start_music() -> void:
	if _music_started:
		return
	var a := stream("music_ambient")
	var b := stream("music_chase")
	if a is AudioStreamOggVorbis:
		a.loop = true
	if b is AudioStreamOggVorbis:
		b.loop = true
	var hb := stream("heartbeat")
	if hb is AudioStreamWAV:
		hb.loop_mode = AudioStreamWAV.LOOP_FORWARD
		hb.loop_begin = 0
		hb.loop_end = int(hb.get_length() * hb.mix_rate)
	_music_a.stream = a
	_music_b.stream = b
	_heart.stream = hb
	if a != null:
		_music_a.play()
	if b != null:
		_music_b.play()
	if hb != null:
		_heart.play()
	_music_started = true


func reset_levels() -> void:
	chase_level = 0.0
	heart_level = 0.0


func _process(delta: float) -> void:
	if not _music_started:
		return
	_chase = move_toward(_chase, chase_level, delta * 0.7)
	_heartv = move_toward(_heartv, heart_level, delta * 1.5)
	var on := GameState.music_on
	_music_a.volume_db = linear_to_db(maxf(0.0001, (0.55 - 0.3 * _chase) if on else 0.0))
	_music_b.volume_db = linear_to_db(maxf(0.0001, (0.6 * _chase) if on else 0.0))
	_heart.volume_db = linear_to_db(maxf(0.0001, (0.9 * _heartv) if GameState.sfx_on else 0.0))
	_heart.pitch_scale = 1.0 + 0.35 * _heartv

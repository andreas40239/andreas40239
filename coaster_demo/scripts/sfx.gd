class_name Sfx
extends Node
## Soundeffekte: kurze Einzel-Sounds (Bauen, UI) und Fahrgeräusche als Schleifen,
## deren Lautstärke/Tonhöhe vom Tempo abhängen. Die WAVs liegen in res://sounds/.

const ONESHOTS := ["place", "undo", "error", "click", "closed", "save", "load", "bell", "brake",
	"splash", "boost"]
const SETTINGS_PATH := "user://settings.cfg"

var muted := false

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _roll: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _chain: AudioStreamPlayer


func _ready() -> void:
	for n in ONESHOTS:
		_streams[n] = load("res://sounds/%s.wav" % n)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_roll = _loop_player("roll_loop")
	_wind = _loop_player("wind_loop")
	_chain = _loop_player("chain_loop")
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		muted = cfg.get_value("audio", "muted", false)
	_apply_mute()


func _loop_player(n: String) -> AudioStreamPlayer:
	var s: AudioStreamWAV = (load("res://sounds/%s.wav" % n) as AudioStreamWAV).duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = -80.0
	add_child(p)
	return p


## Spielt einen kurzen Sound; `pitch_jitter` variiert die Tonhöhe leicht.
func play(n: String, volume_db := 0.0, pitch := 1.0, pitch_jitter := 0.06) -> void:
	if muted or not _streams.has(n):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[n]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()


func set_muted(m: bool) -> void:
	muted = m
	_apply_mute()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "muted", muted)
	cfg.save(SETTINGS_PATH)


func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)


func start_ride() -> void:
	for p in [_roll, _wind, _chain]:
		p.volume_db = -80.0
		p.play()


func stop_ride() -> void:
	for p in [_roll, _wind, _chain]:
		p.stop()


## Pro Frame während der Fahrt: Tempo in m/s, ob der Kettenlift zieht.
func update_ride(speed: float, on_chain: bool, delta: float) -> void:
	var k := 1.0 - exp(-8.0 * delta)
	var s := clampf(speed / 20.0, 0.0, 1.0)   # 0..1 bei 0..72 km/h
	_fade(_roll, linear_to_db(0.25 + 0.75 * s) if speed > 0.3 else -80.0, k)
	_roll.pitch_scale = 0.6 + 0.9 * s
	_fade(_wind, linear_to_db(maxf(s * s, 0.001)) - 4.0, k)
	_wind.pitch_scale = 0.8 + 0.5 * s
	_fade(_chain, -3.0 if on_chain else -80.0, k)
	_chain.pitch_scale = clampf(speed / 3.0, 0.6, 1.6)


func _fade(p: AudioStreamPlayer, target_db: float, k: float) -> void:
	p.volume_db = lerpf(p.volume_db, target_db, k)

extends Node
## Pooled SFX playback + looping music (GDD 10 / Appendix C).

const POOL_SIZE := 10
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_name := ""
var _cache := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -6.0
	add_child(_music)

func _load(path: String, looped := false) -> AudioStream:
	var key := path + ("#l" if looped else "")
	if _cache.has(key):
		return _cache[key]
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	if looped and stream is AudioStreamWAV:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2  # 16-bit mono frames
	_cache[key] = stream
	return stream

func play_sfx(sfx_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var stream := _load("res://assets/audio/sfx/%s.wav" % sfx_name)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
	# all busy: steal the first player
	_pool[0].stream = stream
	_pool[0].volume_db = volume_db
	_pool[0].pitch_scale = pitch
	_pool[0].play()

func play_music(music_name: String, looped := true) -> void:
	if _music_name == music_name and _music.playing:
		return
	var stream := _load("res://assets/audio/music/%s.wav" % music_name, looped)
	if stream == null:
		return
	_music_name = music_name
	_music.stream = stream
	_music.play()

func stop_music() -> void:
	_music_name = ""
	_music.stop()

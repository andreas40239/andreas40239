extends Node
## Musik und Soundeffekte mit getrennten Lautstärkereglern (Busse "Music" und "SFX").

const SFX := {
	&"tap": preload("res://audio/sfx/tap.wav"),
	&"build": preload("res://audio/sfx/build.wav"),
	&"bubble": preload("res://audio/sfx/bubble.wav"),
	&"cookie": preload("res://audio/sfx/cookie.wav"),
	&"wind": preload("res://audio/sfx/wind.wav"),
	&"friend": preload("res://audio/sfx/friend.wav"),
	&"arrive": preload("res://audio/sfx/arrive.wav"),
	&"chaos": preload("res://audio/sfx/chaos.wav"),
	&"upgrade": preload("res://audio/sfx/upgrade.wav"),
	&"sell": preload("res://audio/sfx/sell.wav"),
	&"star": preload("res://audio/sfx/star.wav"),
	&"wave": preload("res://audio/sfx/wave.wav"),
	&"win": preload("res://audio/sfx/win.wav"),
	&"lose": preload("res://audio/sfx/lose.wav"),
	&"deny": preload("res://audio/sfx/deny.wav"),
	&"need_info": preload("res://audio/sfx/need_info.wav"),
}
const MUSIC := preload("res://audio/music/sonnental.wav")
const POOL_SIZE := 10

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _last_played: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = MUSIC
	_music.volume_db = -4.0
	_music.finished.connect(_music.play)
	add_child(_music)
	set_music_volume(float(SaveManager.get_setting("music", 0.7)))
	set_sfx_volume(float(SaveManager.get_setting("sfx", 0.9)))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func play_music() -> void:
	if not _music.playing:
		_music.play()


## Spielt einen Effekt. Gleiche Effekte werden gedrosselt, damit es nicht zu laut wird.
func play(sfx_name: StringName, pitch_variation: float = 0.06, volume_db: float = 0.0) -> void:
	if not SFX.has(sfx_name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sfx_name, -1000)) < 60:
		return
	_last_played[sfx_name] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = SFX[sfx_name]
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.volume_db = volume_db
	p.play()


func set_music_volume(linear: float) -> void:
	_set_bus_volume("Music", linear)


func set_sfx_volume(linear: float) -> void:
	_set_bus_volume("SFX", linear)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))

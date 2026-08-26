# Sound and music manager (autoload "A").
extends Node

var streams := {}
var sfx_players: Array = []
var music_player: AudioStreamPlayer

const SFX_POOL := 10

func _ready() -> void:
	for n in ["click", "fire", "whiz", "explosion", "hit_direct", "hit_splash",
			"shield", "wind", "victory", "defeat", "music"]:
		streams[n] = load("res://assets/audio/%s.wav" % n)
	for i in range(SFX_POOL):
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	var m: AudioStreamWAV = streams["music"]
	m.loop_mode = AudioStreamWAV.LOOP_FORWARD
	m.loop_begin = 0
	m.loop_end = m.data.size() / 2  # 16-bit mono
	music_player.stream = m
	play_music()

func _vol_db(kind: String) -> float:
	if G.settings["muted"]:
		return -80.0
	var v: float = G.settings.get(kind, 1.0)
	if v <= 0.01:
		return -80.0
	return linear_to_db(v)

func play(name: String, pitch := 1.0, kind := "sfx") -> void:
	if not streams.has(name):
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = streams[name]
			p.pitch_scale = pitch
			p.volume_db = _vol_db(kind)
			p.play()
			return
	# All busy: steal the first player.
	var p0: AudioStreamPlayer = sfx_players[0]
	p0.stream = streams[name]
	p0.pitch_scale = pitch
	p0.volume_db = _vol_db(kind)
	p0.play()

func click() -> void:
	play("click", randf_range(0.95, 1.1), "ui")

func play_music() -> void:
	music_player.volume_db = _vol_db("music")
	if not music_player.playing:
		music_player.play()

func refresh_music_volume() -> void:
	music_player.volume_db = _vol_db("music")

func haptic(ms := 30) -> void:
	if G.settings["haptics"]:
		Input.vibrate_handheld(ms)

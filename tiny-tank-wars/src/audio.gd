# Sound and music manager (autoload "A").
extends Node

# Music tracks the player can switch between in the menu / pause screen.
const MUSIC_TRACKS := ["music", "music2", "music3"]
const MUSIC_NAMES := ["Sunny Hills", "Bouncy Blocks", "Cloud Picnic"]

var streams := {}
var sfx_players: Array = []
var music_player: AudioStreamPlayer

const SFX_POOL := 10

func _ready() -> void:
	for n in ["click", "fire", "whiz", "explosion", "hit_direct", "hit_splash",
			"shield", "wind", "victory", "defeat"]:
		streams[n] = load("res://assets/audio/%s.wav" % n)
	for n in MUSIC_TRACKS:
		var m: AudioStreamWAV = load("res://assets/audio/%s.wav" % n)
		m.loop_mode = AudioStreamWAV.LOOP_FORWARD
		m.loop_begin = 0
		m.loop_end = m.data.size() / 2  # 16-bit mono
		streams[n] = m
	for i in range(SFX_POOL):
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
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

# --- Music track selection -------------------------------------------

func track_index() -> int:
	return clampi(int(G.settings.get("music_track", 0)), 0, MUSIC_TRACKS.size() - 1)

func track_name() -> String:
	return MUSIC_NAMES[track_index()]

func play_music() -> void:
	var want: AudioStream = streams[MUSIC_TRACKS[track_index()]]
	if music_player.stream != want:
		music_player.stream = want
		music_player.play()
	music_player.volume_db = _vol_db("music")
	if not music_player.playing:
		music_player.play()

# Switch to the next song and start it right away.
func next_track() -> String:
	G.settings["music_track"] = (track_index() + 1) % MUSIC_TRACKS.size()
	music_player.stream = streams[MUSIC_TRACKS[track_index()]]
	music_player.volume_db = _vol_db("music")
	music_player.play()
	G.save_game()
	return track_name()

func refresh_music_volume() -> void:
	music_player.volume_db = _vol_db("music")
	if not G.settings["muted"] and G.settings.get("music", 0.8) > 0.01 and not music_player.playing:
		play_music()

func haptic(ms := 30) -> void:
	if G.settings["haptics"]:
		Input.vibrate_handheld(ms)

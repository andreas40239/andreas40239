extends Node
## Musik (mit Ueberblendung) und Soundeffekte.

const MUSIC := {
	"dungeon": preload("res://audio/music_dungeon.ogg"),
	"boss": preload("res://audio/music_boss.ogg"),
	"victory": preload("res://audio/music_victory.ogg"),
}
const MUSIC_DB := {"dungeon": -7.0, "boss": -6.0, "victory": -4.0}
const SFX := {
	"swing": preload("res://audio/swing.wav"),
	"swing_fire": preload("res://audio/swing_fire.wav"),
	"swing_ice": preload("res://audio/swing_ice.wav"),
	"hit": preload("res://audio/hit.wav"),
	"clank": preload("res://audio/clank.wav"),
	"wall_break": preload("res://audio/wall_break.wav"),
	"pickup": preload("res://audio/pickup.wav"),
	"powerup": preload("res://audio/powerup.wav"),
	"hurt": preload("res://audio/hurt.wav"),
	"death": preload("res://audio/death.wav"),
	"bat": preload("res://audio/bat.wav"),
	"slime": preload("res://audio/slime.wav"),
	"monster_die": preload("res://audio/monster_die.wav"),
	"knight": preload("res://audio/knight.wav"),
	"octopus": preload("res://audio/octopus.wav"),
	"ink": preload("res://audio/ink.wav"),
	"golem": preload("res://audio/golem.wav"),
	"slam": preload("res://audio/slam.wav"),
	"dragon": preload("res://audio/dragon.wav"),
	"fire": preload("res://audio/fire.wav"),
	"freeze": preload("res://audio/freeze.wav"),
	"gate": preload("res://audio/gate.wav"),
	"boss_defeat": preload("res://audio/boss_defeat.wav"),
	"crystal": preload("res://audio/crystal.wav"),
	"denied": preload("res://audio/denied.wav"),
}
const POOL_SIZE := 12

var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var current := ""
var pool: Array = []
var next_idx := 0
var last_played := {}


func _ready() -> void:
	for k in MUSIC:
		if k != "victory":
			MUSIC[k].loop = true
	music_a = AudioStreamPlayer.new()
	music_b = AudioStreamPlayer.new()
	add_child(music_a)
	add_child(music_b)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)


func play_music(name: String) -> void:
	if name == current:
		return
	current = name
	# alter Spieler blendet aus, neuer blendet ein
	var old := music_a
	music_a = music_b
	music_b = old
	music_a.stream = MUSIC[name]
	music_a.volume_db = -40.0
	music_a.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(music_a, "volume_db", MUSIC_DB[name], 0.8)
	if music_b.playing:
		tw.tween_property(music_b, "volume_db", -60.0, 0.8)
		tw.chain().tween_callback(music_b.stop)


func sfx(name: String, db := 0.0) -> void:
	if not SFX.has(name):
		return
	var now := Time.get_ticks_msec()
	if last_played.get(name, -1000) > now - 60:
		return
	last_played[name] = now
	var p: AudioStreamPlayer = pool[next_idx]
	next_idx = (next_idx + 1) % POOL_SIZE
	p.stream = SFX[name]
	p.volume_db = db - 2.0
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()

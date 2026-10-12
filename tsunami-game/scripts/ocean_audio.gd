extends Node
## Prozedural erzeugter Sound: Meeresrauschen, Tsunami-Grollen und Motorbrummen
## der Baumaschinen. Kommt ohne Audiodateien aus (AudioStreamGenerator).

const RATE := 22050.0

## 0..1 – zusätzliches Grollen während eines Tsunamis
var intensity := 0.0
## 0..1 – Lautstärke der Baumaschinen-Motoren
var machine_level := 0.0

var _burst := 0.0
var _clock := 0.0
var _lp1 := 0.0
var _lp2 := 0.0
var _rumble := 0.0
var _motor_phase := 0.0
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.2
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -4.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


## Kurzer lauter Aufprall (Welle schlägt gegen die Mauer).
func impact(strength: float) -> void:
	_burst = maxf(_burst, clampf(strength, 0.0, 1.0))


func _process(delta: float) -> void:
	_burst = maxf(0.0, _burst - delta * 0.35)
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	var step := 1.0 / RATE
	for i in frames:
		_clock += step
		# Langsame Dünung: Wellen rollen heran und brechen
		var swell := 0.5 + 0.35 * sin(_clock * TAU * 0.11) + 0.15 * sin(_clock * TAU * 0.047 + 1.3)
		var white := randf() * 2.0 - 1.0
		var cutoff := clampf(0.03 + 0.12 * swell + 0.15 * intensity + 0.25 * _burst, 0.01, 0.9)
		_lp1 += (white - _lp1) * cutoff
		_lp2 += (_lp1 - _lp2) * cutoff
		var ocean := _lp2 * (0.7 + 1.6 * swell * swell) * 3.0

		# Tiefes Grollen des Tsunamis
		_rumble += (white - _rumble) * 0.004
		var roar := _rumble * 18.0 * (intensity + _burst)

		# Dieselmotor: Sägezahn mit Lastschwankung
		var motor := 0.0
		if machine_level > 0.001:
			_motor_phase += (34.0 + 6.0 * sin(_clock * 2.7)) * step
			var saw := fmod(_motor_phase, 1.0) * 2.0 - 1.0
			var chug := 0.65 + 0.35 * sin(_clock * TAU * 11.0)
			motor = (saw * 0.6 + white * 0.15) * 0.10 * machine_level * chug

		var s := clampf(ocean * (1.0 + intensity + 2.0 * _burst) + roar + motor, -1.0, 1.0)
		_playback.push_frame(Vector2(s, s))

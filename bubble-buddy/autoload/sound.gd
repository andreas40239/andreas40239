extends Node
## Procedural audio for Bubble Buddy.
##
## Every sound effect and the music loops are synthesised into AudioStreamWAV at
## startup, so the project ships with no binary audio assets and stays fully
## self-contained and offline. Music is built on a worker thread so the title
## screen never hitches while it renders.

const MIX_RATE := 22050
const SFX_VOICES := 14

# 96 BPM, four bars of 4/4 => a 10 second seamless loop.
const BPM := 96.0
const BEAT := 60.0 / BPM
const LOOP_BEATS := 16

var _sfx: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0

var _music_base: AudioStreamPlayer
var _music_perc: AudioStreamPlayer
var _music_thread: Thread
var _music_tracks: Array[AudioStreamWAV] = []
var _perc_stream: AudioStreamWAV
var _music_ready := false
var _wanted_zone := -1
var _music_playing := false
var _perc_target_db := -60.0
var _perc_db := -60.0


func _ready() -> void:
	_build_sfx()
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)

	_music_base = AudioStreamPlayer.new()
	_music_base.bus = "Master"
	add_child(_music_base)
	_music_perc = AudioStreamPlayer.new()
	_music_perc.bus = "Master"
	_music_perc.volume_db = -60.0
	add_child(_music_perc)

	_music_thread = Thread.new()
	_music_thread.start(_build_music_async)


func _exit_tree() -> void:
	if _music_thread != null and _music_thread.is_started():
		_music_thread.wait_to_finish()


func _process(delta: float) -> void:
	# Smoothly fade the percussion layer in and out (Rainbow Rush).
	if absf(_perc_db - _perc_target_db) > 0.5:
		_perc_db = lerpf(_perc_db, _perc_target_db, clampf(delta * 6.0, 0.0, 1.0))
		_music_perc.volume_db = _perc_db if SaveData.music_enabled else -60.0


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not SaveData.sfx_enabled:
		return
	var stream: AudioStreamWAV = _sfx.get(name)
	if stream == null:
		return
	var p := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.4, 2.4)
	p.volume_db = volume_db
	p.play()


func play_varied(name: String, spread := 0.06, volume_db := 0.0) -> void:
	play(name, 1.0 + randf_range(-spread, spread), volume_db)


## Zones share two rendered loops; the pitch offset gives each its own colour
## without paying for five separate renders on the device.
func set_zone_music(zone: int) -> void:
	_wanted_zone = zone
	if not _music_ready:
		return
	var track_index := 0 if zone % 5 in [0, 4] else 1
	var stream := _music_tracks[track_index]
	var pitch: float = [1.0, 0.94, 0.9, 0.86, 1.06][posmod(zone, 5)]
	if _music_base.stream != stream:
		_music_base.stream = stream
		if _music_playing:
			_music_base.play()
	_music_base.pitch_scale = pitch
	_music_perc.pitch_scale = pitch


func start_music() -> void:
	_music_playing = true
	if not _music_ready or not SaveData.music_enabled:
		return
	_music_base.volume_db = -6.0
	if not _music_base.playing:
		_music_base.play()
	if not _music_perc.playing:
		_music_perc.play()


func stop_music() -> void:
	_music_playing = false
	_music_base.stop()
	_music_perc.stop()


func set_percussion(active: bool) -> void:
	_perc_target_db = -9.0 if active else -60.0


func refresh_settings() -> void:
	if SaveData.music_enabled:
		if _music_playing:
			start_music()
	else:
		_music_base.stop()
		_music_perc.stop()


# ---------------------------------------------------------------------------
# Stream helpers
# ---------------------------------------------------------------------------

func _make_stream(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var count := samples.size()
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var v := clampf(samples[i], -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = MIX_RATE
	st.stereo = false
	st.data = bytes
	if loop:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = count
	return st


func _buffer(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * MIX_RATE))
	buf.fill(0.0)
	return buf


## Soft-clip so layered voices stay warm instead of crackling.
func _soften(buf: PackedFloat32Array) -> PackedFloat32Array:
	for i in buf.size():
		var v := buf[i]
		buf[i] = tanh(v * 1.15) * 0.92
	return buf


## A plucked voice: fundamental plus a couple of harmonics under an exponential
## decay. `bright` leans it towards ukulele, low values towards marimba.
func _pluck(buf: PackedFloat32Array, at: float, freq: float, dur: float, amp: float, bright := 0.5) -> void:
	var start := int(at * MIX_RATE)
	var length := int(dur * MIX_RATE)
	var n := buf.size()
	var attack := int(0.004 * MIX_RATE)
	for i in length:
		var idx := start + i
		if idx < 0 or idx >= n:
			continue
		var t := float(i) / MIX_RATE
		var env: float = exp(-t * (3.2 + bright * 3.0))
		if i < attack:
			env *= float(i) / float(attack)
		var w := sin(TAU * freq * t)
		w += sin(TAU * freq * 2.0 * t) * (0.18 + bright * 0.30)
		w += sin(TAU * freq * 3.0 * t) * bright * 0.16
		w += sin(TAU * freq * 1.003 * t) * bright * 0.25   # gentle chorus detune
		buf[idx] += w * env * amp * 0.34


## A slow, soft pad for the underwater bed.
func _pad(buf: PackedFloat32Array, at: float, freq: float, dur: float, amp: float) -> void:
	var start := int(at * MIX_RATE)
	var length := int(dur * MIX_RATE)
	var n := buf.size()
	for i in length:
		var idx := start + i
		if idx < 0 or idx >= n:
			continue
		var t := float(i) / MIX_RATE
		var env := clampf(t / 0.55, 0.0, 1.0) * clampf((dur - t) / 0.7, 0.0, 1.0)
		var vib := sin(TAU * 4.5 * t) * 0.004
		var w := sin(TAU * freq * (1.0 + vib) * t) * 0.6
		w += sin(TAU * freq * 0.5 * t) * 0.3
		w += sin(TAU * freq * 2.01 * t) * 0.12
		buf[idx] += w * env * amp * 0.22


func _noise(buf: PackedFloat32Array, at: float, dur: float, amp: float, decay := 18.0, tone := 0.0) -> void:
	var start := int(at * MIX_RATE)
	var length := int(dur * MIX_RATE)
	var n := buf.size()
	var last := 0.0
	for i in length:
		var idx := start + i
		if idx < 0 or idx >= n:
			continue
		var t := float(i) / MIX_RATE
		var raw := randf_range(-1.0, 1.0)
		# One-pole low-pass keeps hiss friendly rather than harsh.
		last = lerpf(last, raw, clampf(0.08 + tone, 0.02, 1.0))
		buf[idx] += last * exp(-t * decay) * amp


## A pitch glide, used for bloops, whooshes and Finley's giggles.
func _glide(buf: PackedFloat32Array, at: float, f0: float, f1: float, dur: float, amp: float, wobble := 0.0) -> void:
	var start := int(at * MIX_RATE)
	var length := int(dur * MIX_RATE)
	var n := buf.size()
	var phase := 0.0
	for i in length:
		var idx := start + i
		if idx < 0 or idx >= n:
			continue
		var t := float(i) / MIX_RATE
		var k := t / dur
		var f: float = lerpf(f0, f1, k * k)
		if wobble > 0.0:
			f *= 1.0 + sin(TAU * 11.0 * t) * wobble
		phase += TAU * f / MIX_RATE
		var env := sin(PI * clampf(k, 0.0, 1.0))
		buf[idx] += sin(phase) * env * amp * 0.5


func _note(semitones: float, octave := 0.0) -> float:
	# Middle C as the anchor of the whole soundtrack.
	return 261.63 * pow(2.0, (semitones + octave * 12.0) / 12.0)


# ---------------------------------------------------------------------------
# Sound effects
# ---------------------------------------------------------------------------

func _build_sfx() -> void:
	_sfx["pearl"] = _sfx_pearl()
	_sfx["small_bubble"] = _sfx_small_bubble()
	_sfx["big_bubble"] = _sfx_big_bubble()
	_sfx["push_crab"] = _sfx_push_crab()
	_sfx["zap"] = _sfx_zap()
	_sfx["rescue"] = _sfx_rescue()
	_sfx["gate"] = _sfx_gate()
	_sfx["rainbow"] = _sfx_rainbow()
	_sfx["shield"] = _sfx_shield()
	_sfx["current"] = _sfx_current()
	_sfx["dizzy"] = _sfx_dizzy()
	_sfx["pop"] = _sfx_pop()
	_sfx["button"] = _sfx_button()
	_sfx["giggle"] = _sfx_giggle()
	_sfx["sticker"] = _sfx_sticker()
	_sfx["puff"] = _sfx_puff()
	_sfx["chest"] = _sfx_chest()


func _sfx_pearl() -> AudioStreamWAV:
	var b := _buffer(0.42)
	_pluck(b, 0.0, _note(12), 0.4, 0.85, 0.7)
	_pluck(b, 0.0, _note(19), 0.3, 0.35, 0.8)
	_glide(b, 0.0, 1500.0, 2100.0, 0.09, 0.22)
	return _make_stream(_soften(b))


func _sfx_small_bubble() -> AudioStreamWAV:
	var b := _buffer(0.2)
	_glide(b, 0.0, 420.0, 760.0, 0.14, 0.32)
	_noise(b, 0.0, 0.08, 0.06, 40.0, 0.4)
	return _make_stream(_soften(b))


func _sfx_big_bubble() -> AudioStreamWAV:
	var b := _buffer(0.7)
	# "Bloop" then a soft outward "whoosh".
	_glide(b, 0.0, 700.0, 240.0, 0.22, 0.6)
	_glide(b, 0.05, 180.0, 520.0, 0.3, 0.35)
	_noise(b, 0.12, 0.45, 0.3, 6.0, 0.25)
	return _make_stream(_soften(b))


func _sfx_push_crab() -> AudioStreamWAV:
	var b := _buffer(0.8)
	# Three clacky claw taps...
	for i in 3:
		var t := 0.02 + i * 0.09
		_noise(b, t, 0.08, 0.5, 60.0, 0.9)
		_pluck(b, t, _note(26 - i * 2), 0.07, 0.3, 1.0)
	# ...and a surprised little crab squeak.
	_glide(b, 0.32, 520.0, 980.0, 0.22, 0.32, 0.03)
	return _make_stream(_soften(b))


func _sfx_zap() -> AudioStreamWAV:
	var b := _buffer(0.75)
	var start := 0
	var length := int(0.16 * MIX_RATE)
	for i in length:
		var t := float(i) / MIX_RATE
		var f := 190.0 + sin(TAU * 40.0 * t) * 60.0
		var v: float = signf(sin(TAU * f * t)) * 0.16 * exp(-t * 9.0)
		b[start + i] += v
	# Finley finds it funny rather than frightening.
	_glide(b, 0.2, 620.0, 900.0, 0.12, 0.28, 0.05)
	_glide(b, 0.34, 700.0, 1020.0, 0.1, 0.24, 0.05)
	_glide(b, 0.46, 780.0, 1120.0, 0.1, 0.2, 0.05)
	return _make_stream(_soften(b))


func _sfx_rescue() -> AudioStreamWAV:
	var b := _buffer(0.95)
	var notes := [0, 4, 7]
	for i in notes.size():
		_pluck(b, i * 0.11, _note(notes[i] + 12), 0.5, 0.75, 0.55)
		_pluck(b, i * 0.11, _note(notes[i] + 24), 0.35, 0.28, 0.7)
	_pad(b, 0.0, _note(0), 0.9, 0.5)
	return _make_stream(_soften(b))


func _sfx_gate() -> AudioStreamWAV:
	var b := _buffer(2.0)
	# Harp glissando up a pentatonic scale.
	var scale := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 28]
	for i in scale.size():
		_pluck(b, i * 0.055, _note(scale[i] + 12), 0.9, 0.5, 0.85)
	# A crowd of cheering fish: bright noise swell plus happy chirps.
	_noise(b, 0.55, 1.1, 0.16, 2.2, 0.55)
	for i in 7:
		_glide(b, 0.6 + i * 0.07, randf_range(700.0, 900.0), randf_range(1100.0, 1500.0), 0.18, 0.12, 0.04)
	_pad(b, 0.5, _note(0), 1.4, 0.6)
	_pad(b, 0.5, _note(7), 1.4, 0.4)
	return _make_stream(_soften(b))


func _sfx_rainbow() -> AudioStreamWAV:
	var b := _buffer(1.4)
	var chord := [0, 4, 7, 12]
	for i in chord.size():
		_pluck(b, 0.0, _note(chord[i] + 12), 1.2, 0.5, 0.8)
	for i in 6:
		_pluck(b, 0.12 + i * 0.08, _note([12, 16, 19, 24, 19, 16][i]), 0.4, 0.4, 0.9)
	_noise(b, 0.0, 0.5, 0.1, 6.0, 0.6)
	return _make_stream(_soften(b))


func _sfx_shield() -> AudioStreamWAV:
	var b := _buffer(0.8)
	_glide(b, 0.0, 300.0, 900.0, 0.5, 0.3)
	for i in 4:
		_pluck(b, i * 0.07, _note(12 + i * 5), 0.5, 0.3, 0.9)
	return _make_stream(_soften(b))


func _sfx_current() -> AudioStreamWAV:
	var b := _buffer(1.0)
	_noise(b, 0.0, 0.9, 0.24, 2.4, 0.18)
	_glide(b, 0.0, 240.0, 820.0, 0.7, 0.25)
	return _make_stream(_soften(b))


func _sfx_dizzy() -> AudioStreamWAV:
	var b := _buffer(0.9)
	_glide(b, 0.0, 780.0, 340.0, 0.8, 0.3, 0.09)
	_pluck(b, 0.0, _note(7), 0.4, 0.25, 0.4)
	return _make_stream(_soften(b))


func _sfx_pop() -> AudioStreamWAV:
	var b := _buffer(0.3)
	_glide(b, 0.0, 900.0, 320.0, 0.12, 0.45)
	_noise(b, 0.0, 0.12, 0.18, 30.0, 0.5)
	return _make_stream(_soften(b))


func _sfx_button() -> AudioStreamWAV:
	var b := _buffer(0.28)
	_pluck(b, 0.0, _note(16), 0.26, 0.5, 0.6)
	_glide(b, 0.0, 520.0, 780.0, 0.07, 0.18)
	return _make_stream(_soften(b))


func _sfx_giggle() -> AudioStreamWAV:
	var b := _buffer(0.7)
	for i in 4:
		_glide(b, i * 0.12, 640.0 + i * 60.0, 940.0 + i * 70.0, 0.11, 0.24, 0.06)
	return _make_stream(_soften(b))


func _sfx_sticker() -> AudioStreamWAV:
	var b := _buffer(1.1)
	var notes := [0, 4, 7, 12, 16]
	for i in notes.size():
		_pluck(b, i * 0.08, _note(notes[i] + 12), 0.7, 0.6, 0.75)
	_noise(b, 0.0, 0.3, 0.08, 9.0, 0.6)
	return _make_stream(_soften(b))


func _sfx_puff() -> AudioStreamWAV:
	var b := _buffer(0.45)
	_noise(b, 0.0, 0.3, 0.3, 9.0, 0.3)
	_glide(b, 0.0, 200.0, 420.0, 0.22, 0.3)
	return _make_stream(_soften(b))


func _sfx_chest() -> AudioStreamWAV:
	var b := _buffer(1.6)
	var scale := [0, 4, 7, 12, 16, 19, 24]
	for i in scale.size():
		_pluck(b, i * 0.07, _note(scale[i] + 12), 0.8, 0.55, 0.8)
	_pad(b, 0.1, _note(0), 1.3, 0.55)
	_pad(b, 0.1, _note(4), 1.3, 0.35)
	return _make_stream(_soften(b))


# ---------------------------------------------------------------------------
# Music (worker thread)
# ---------------------------------------------------------------------------

func _build_music_async() -> void:
	var bright := _music_loop(true)
	var mellow := _music_loop(false)
	var perc := _percussion_loop()
	call_deferred("_music_finished", bright, mellow, perc)


func _music_finished(bright: AudioStreamWAV, mellow: AudioStreamWAV, perc: AudioStreamWAV) -> void:
	_music_tracks = [bright, mellow]
	_perc_stream = perc
	_music_perc.stream = _perc_stream
	_music_ready = true
	if _music_thread.is_started():
		_music_thread.wait_to_finish()
	set_zone_music(maxi(_wanted_zone, 0))
	if _music_playing:
		start_music()


## Four gentle bars: ukulele chords on the downbeats, a marimba melody on the
## eighths and a slow pad underneath. Pentatonic throughout, so no note in the
## loop can clash with any sound effect layered over it.
func _music_loop(bright: bool) -> AudioStreamWAV:
	var total := LOOP_BEATS * BEAT
	var b := _buffer(total)
	var chords := [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]] if bright \
		else [[9, 12, 16], [5, 9, 12], [0, 4, 7], [4, 7, 11]]
	var melody := [0, 4, 7, 9, 7, 4, 9, 12, 7, 4, 0, 4, 7, 9, 12, 7] if bright \
		else [9, 12, 9, 7, 4, 7, 9, 5, 4, 0, 4, 7, 9, 7, 4, 2]

	for bar in 4:
		var bar_t := bar * 4.0 * BEAT
		var chord: Array = chords[bar]
		# Ukulele strum on beats 1 and 3 (a soft, slightly spread arpeggio).
		for strum in [0.0, 2.0 * BEAT]:
			for i in chord.size():
				_pluck(b, bar_t + strum + i * 0.018, _note(chord[i]), 1.1, 0.42, 0.9)
		# A quieter offbeat strum keeps the groove moving without hurrying it.
		for i in chord.size():
			_pluck(b, bar_t + 3.0 * BEAT + i * 0.016, _note(chord[i] + 12), 0.6, 0.16, 0.85)
		# Pad root, one per bar.
		_pad(b, bar_t, _note(chord[0] - 12), 4.0 * BEAT + 0.4, 0.55)
		_pad(b, bar_t, _note(chord[1] - 12), 4.0 * BEAT + 0.4, 0.3)

	# Marimba melody on eighth notes, resting on some of them so it breathes.
	for step in LOOP_BEATS:
		if step % 4 == 3:
			continue
		var t := step * BEAT
		_pluck(b, t, _note(melody[step] + 12), 0.9, 0.34, 0.35)
		if step % 4 == 0:
			_pluck(b, t + BEAT * 0.5, _note(melody[step] + 19), 0.5, 0.14, 0.4)

	return _make_stream(_soften(b), true)


## Light shaker and a soft heartbeat kick. Kept on its own stream so Rainbow
## Rush can fade it in as an extra layer over whichever zone track is playing.
func _percussion_loop() -> AudioStreamWAV:
	var total := LOOP_BEATS * BEAT
	var b := _buffer(total)
	for step in LOOP_BEATS * 2:
		var t := step * BEAT * 0.5
		var accent := 0.22 if step % 4 == 0 else 0.12
		_noise(b, t, 0.1, accent, 55.0, 0.85)
	for step in LOOP_BEATS:
		if step % 4 == 0 or step % 8 == 6:
			_glide(b, step * BEAT, 120.0, 58.0, 0.16, 0.5)
	return _make_stream(_soften(b), true)


# ---------------------------------------------------------------------------
# Build-time introspection (used by the audio check, harmless at runtime)
# ---------------------------------------------------------------------------

func _debug_stream(name: String) -> AudioStreamWAV:
	match name:
		"music_bright":
			return _music_tracks[0] if _music_tracks.size() > 0 else null
		"music_mellow":
			return _music_tracks[1] if _music_tracks.size() > 1 else null
		"music_percussion":
			return _perc_stream
		_:
			return _sfx.get(name)


func debug_peak(name: String) -> float:
	var stream := _debug_stream(name)
	if stream == null:
		return 0.0
	var bytes := stream.data
	var peak := 0.0
	var count := bytes.size() / 2
	for i in count:
		var v: float = absf(float(bytes.decode_s16(i * 2)) / 32768.0)
		if v > peak:
			peak = v
	return peak


func debug_seconds(name: String) -> float:
	var stream := _debug_stream(name)
	if stream == null:
		return 0.0
	return float(stream.data.size() / 2) / float(MIX_RATE)


func debug_music_ready() -> bool:
	return _music_ready

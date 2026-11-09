extends Node
## Prozedural synthetisierte Soundeffekte und Musik (keine externen Audiodateien nötig).
## Ambient-Musik + Kampf-Trommeln werden im Hintergrund-Thread erzeugt und dynamisch überblendet.

const RATE := 22050
const LOOP := 24.0

var streams := {}
var _p2d: Array = []
var _p3d: Array = []
var _rr2 := 0
var _rr3 := 0
var music: AudioStreamPlayer
var battle: AudioStreamPlayer
var battle_level := 0.0
var battle_target := 0.0
var _thread: Thread
var _recent := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_build_sfx()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_p2d.append(p)
	for i in 28:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 18.0
		p3.max_distance = 160.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p3)
		_p3d.append(p3)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.volume_db = -3.0
	add_child(music)
	battle = AudioStreamPlayer.new()
	battle.bus = "Music"
	battle.volume_db = -80.0
	add_child(battle)
	_thread = Thread.new()
	_thread.start(_gen_music_thread)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func _process(delta: float) -> void:
	battle_level = move_toward(battle_level, battle_target, delta * 0.25)
	if battle.playing:
		battle.volume_db = linear_to_db(maxf(battle_level, 0.0001)) - 2.0
	for k in _recent.keys():
		_recent[k] -= delta
		if _recent[k] <= 0.0:
			_recent.erase(k)


func _setup_buses() -> void:
	for nm in ["Music", "SFX"]:
		if AudioServer.get_bus_index(nm) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nm)
			AudioServer.set_bus_send(i, "Master")
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.65
		rv.damping = 0.55
		rv.wet = 0.16
		rv.dry = 0.95
		rv.spread = 0.8
		AudioServer.add_bus_effect(sfx, rv)
	if AudioServer.get_bus_effect_count(0) == 0:
		var cp := AudioEffectCompressor.new()
		cp.threshold = -10.0
		cp.ratio = 4.0
		AudioServer.add_bus_effect(0, cp)


func set_volume(bus: String, lin: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lin, 0.0001)))
		AudioServer.set_bus_mute(i, lin <= 0.001)


# ---------------------------------------------------------------- Abspielen
func play(nm: String, vol_db := 0.0, pitch_var := 0.05) -> void:
	if not streams.has(nm):
		return
	var p: AudioStreamPlayer = _p2d[_rr2]
	_rr2 = (_rr2 + 1) % _p2d.size()
	p.stream = streams[nm]
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	p.play()


func play_at(nm: String, pos: Vector3, vol_db := 0.0) -> void:
	if not streams.has(nm):
		return
	var c: float = _recent.get(nm, 0.0)
	if c > 0.12:
		return
	_recent[nm] = c + 0.05
	var p: AudioStreamPlayer3D = null
	for k in _p3d.size():
		var cand: AudioStreamPlayer3D = _p3d[(_rr3 + k) % _p3d.size()]
		if not cand.playing:
			p = cand
			_rr3 = (_rr3 + k + 1) % _p3d.size()
			break
	if p == null:
		p = _p3d[_rr3]
		_rr3 = (_rr3 + 1) % _p3d.size()
	p.stream = streams[nm]
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + _rng.randf_range(-0.08, 0.08)
	p.global_position = pos
	p.play()


# ---------------------------------------------------------------- Synthese-Helfer
func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


func _wav(b: PackedFloat32Array, peak := 0.9, stereo := false, loop := false) -> AudioStreamWAV:
	var mx := 0.0001
	for v in b:
		mx = maxf(mx, absf(v))
	var g := peak / mx
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, clampi(int(b[i] * g * 32767.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = stereo
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = b.size() / (2 if stereo else 1)
	return w


func _build_sfx() -> void:
	var r := _rng
	r.seed = 1234
	# Spitzhacke auf Stein
	var b := _buf(0.32)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := r.randf_range(-1, 1)
		lp += 0.45 * (n - lp)
		b[i] = (n - lp) * exp(-t * 55.0) * 0.7 + sin(TAU * 1870.0 * t) * exp(-t * 20.0) * 0.3 + sin(TAU * 2950.0 * t) * exp(-t * 28.0) * 0.18 + sin(TAU * 130.0 * t) * exp(-t * 35.0) * 0.5
	streams["dig"] = _wav(b, 0.8)
	# Münzen
	b = _buf(0.5)
	for hit in [[0.0, 2600.0], [0.06, 3250.0], [0.13, 2900.0], [0.21, 3500.0]]:
		var st := int(hit[0] * RATE)
		for i in range(st, b.size()):
			var t := float(i - st) / RATE
			b[i] += (sin(TAU * hit[1] * t) + 0.5 * sin(TAU * hit[1] * 1.51 * t)) * exp(-t * 16.0) * 0.4
	streams["gold"] = _wav(b, 0.7)
	# Boden beanspruchen: magisches Schimmern
	b = _buf(0.7)
	for i in b.size():
		var t := float(i) / RATE
		var f := 520.0 + 700.0 * t
		var env := sin(PI * t / 0.7)
		b[i] = (sin(TAU * f * t) + 0.5 * sin(TAU * f * 1.5 * t)) * env * (0.6 + 0.4 * sin(TAU * 18.0 * t)) * 0.4
	streams["claim"] = _wav(b, 0.55)
	# Bauen / Befestigen
	b = _buf(0.45)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += 0.08 * (r.randf_range(-1, 1) - lp)
		var f := 110.0 - 50.0 * minf(1.0, t * 6.0)
		b[i] = sin(TAU * f * t) * exp(-t * 9.0) * 0.8 + lp * exp(-t * 12.0) * 2.0
	streams["build"] = _wav(b, 0.85)
	# Treffer
	b = _buf(0.22)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += 0.25 * (r.randf_range(-1, 1) - lp)
		b[i] = lp * exp(-t * 30.0) * 1.5 + sin(TAU * (170.0 - 300.0 * t) * t) * exp(-t * 18.0) * 0.8
	streams["hit"] = _wav(b, 0.85)
	# Schwung
	b = _buf(0.28)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		var a := 0.05 + 0.4 * sin(PI * t / 0.28)
		lp += a * (r.randf_range(-1, 1) - lp)
		b[i] = lp * sin(PI * t / 0.28)
	streams["swing"] = _wav(b, 0.6)
	# Blitz
	b = _buf(1.2)
	lp = 0.0
	var gate := 1.0
	for i in b.size():
		var t := float(i) / RATE
		if i % 180 == 0:
			gate = r.randf_range(0.2, 1.0)
		lp += 0.3 * (r.randf_range(-1, 1) - lp)
		b[i] = r.randf_range(-1, 1) * gate * exp(-t * 5.0) * 0.7 + sin(TAU * (60.0 - 20.0 * t) * t) * exp(-t * 2.5) * 0.9 + lp * exp(-t * 3.0)
	streams["zap"] = _wav(b, 0.95)
	# Heilung
	b = _buf(1.3)
	for k in 4:
		var f2: float = [523.25, 659.25, 783.99, 1046.5][k]
		var st2 := int(k * 0.09 * RATE)
		for i in range(st2, b.size()):
			var t := float(i - st2) / RATE
			b[i] += sin(TAU * f2 * t) * minf(1.0, t * 30.0) * exp(-t * 2.2) * 0.3
	streams["heal"] = _wav(b, 0.6)
	# Beschwören / Portal
	b = _buf(1.3)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f3 := 900.0 * exp(-t * 1.6) + 120.0
		lp += 0.1 * (r.randf_range(-1, 1) - lp)
		var env2 := minf(1.0, t * 8.0) * exp(-t * 2.2)
		b[i] = (sin(TAU * f3 * t + sin(TAU * 6.0 * t) * 2.0) * 0.5 + lp * 2.0) * env2
	streams["spawn"] = _wav(b, 0.7)
	# Stufenaufstieg
	b = _buf(0.9)
	for k in 5:
		var f4: float = [392.0, 493.88, 587.33, 783.99, 987.77][k]
		var st3 := int(k * 0.08 * RATE)
		for i in range(st3, b.size()):
			var t := float(i - st3) / RATE
			b[i] += (sin(TAU * f4 * t) + 0.3 * sin(TAU * f4 * 2.0 * t)) * exp(-t * 4.0) * 0.25
	streams["levelup"] = _wav(b, 0.6)
	# Alarmhorn
	b = _buf(2.2)
	for i in b.size():
		var t := float(i) / RATE
		var f5 := 98.0 if t < 1.0 else 130.8
		var env3 := minf(1.0, t * 6.0) * minf(1.0, (2.2 - t) * 3.0)
		var ph := TAU * f5 * t + sin(TAU * 5.0 * t) * 0.3
		var v := 0.0
		for h in range(1, 8):
			v += sin(ph * h) / float(h)
		b[i] = v * env3 * 0.4
	streams["alarm"] = _wav(b, 0.8)
	# Tod
	b = _buf(0.8)
	lp = 0.0
	var ph2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f6 := 220.0 * exp(-t * 2.2) + 40.0
		ph2 += TAU * f6 / RATE
		lp += 0.2 * (r.randf_range(-1, 1) - lp)
		var saw := fmod(ph2 / TAU, 1.0) * 2.0 - 1.0
		b[i] = (saw * 0.5 + lp) * exp(-t * 3.5)
	streams["death"] = _wav(b, 0.75)
	# Klick (UI)
	b = _buf(0.06)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 1300.0 * t) * exp(-t * 90.0)
	streams["ui"] = _wav(b, 0.5)
	# Fehler
	b = _buf(0.25)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (1.0 if sin(TAU * 110.0 * t) > 0 else -1.0) * 0.3 * exp(-t * 6.0)
	streams["error"] = _wav(b, 0.45)
	# Essen
	b = _buf(0.5)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += 0.15 * (r.randf_range(-1, 1) - lp)
		var e := exp(-fmod(t, 0.16) * 30.0)
		b[i] = lp * e * 2.0
	streams["eat"] = _wav(b, 0.6)
	# Herzschlag
	b = _buf(0.8)
	for st4 in [0.0, 0.28]:
		var s4 := int(st4 * RATE)
		for i in range(s4, b.size()):
			var t := float(i - s4) / RATE
			b[i] += sin(TAU * (60.0 - 20.0 * t) * t) * minf(1.0, t * 60.0) * exp(-t * 12.0)
	streams["heart"] = _wav(b, 0.95)
	# Feuer / Magiegeschoss
	b = _buf(0.4)
	lp = 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += 0.12 * (r.randf_range(-1, 1) - lp)
		b[i] = lp * sin(PI * t / 0.4) * 3.0
	streams["fire"] = _wav(b, 0.6)
	# Bogen
	b = _buf(0.3)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * (330.0 - 200.0 * t) * t) * exp(-t * 14.0) + r.randf_range(-1, 1) * exp(-t * 80.0) * 0.5
	streams["bow"] = _wav(b, 0.55)
	# Befehl bestätigt
	b = _buf(0.22)
	for i in b.size():
		var t := float(i) / RATE
		var f7 := 660.0 if t < 0.09 else 880.0
		b[i] = sin(TAU * f7 * t) * exp(-fmod(t, 0.09) * 25.0) * 0.5
	streams["order"] = _wav(b, 0.45)
	# Sieg / Niederlage
	streams["victory"] = _wav(_chord([293.66, 369.99, 440.0, 587.33], 3.0, true), 0.8)
	streams["defeat"] = _wav(_chord([146.83, 174.61, 220.0, 207.65], 3.5, false), 0.8)


func _chord(freqs: Array, dur: float, bright: bool) -> PackedFloat32Array:
	var b := _buf(dur)
	for k in freqs.size():
		var f: float = freqs[k]
		var st := int(k * (0.12 if bright else 0.3) * RATE)
		for i in range(st, b.size()):
			var t := float(i - st) / RATE
			var v := sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.0 * t) + (0.25 * sin(TAU * f * 3.0 * t) if bright else 0.0)
			b[i] += v * minf(1.0, t * 10.0) * exp(-t * (1.0 if bright else 0.7)) * 0.25
	return b


# ---------------------------------------------------------------- Musik (Thread)
func _gen_music_thread() -> void:
	var m := _gen_music()
	var d := _gen_drums()
	call_deferred("_music_ready", m, d)


func _music_ready(m: AudioStreamWAV, d: AudioStreamWAV) -> void:
	if _thread.is_started():
		_thread.wait_to_finish()
	music.stream = m
	battle.stream = d
	music.play()
	battle.play()


static func _hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


func _gen_music() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var n := int(LOOP * RATE)
	var tbl := PackedFloat32Array()
	tbl.resize(4096)
	var sine := PackedFloat32Array()
	sine.resize(4096)
	for i in 4096:
		var ph := TAU * i / 4096.0
		tbl[i] = sin(ph) + 0.5 * sin(2.0 * ph + 0.3) + 0.28 * sin(3.0 * ph + 0.7) + 0.14 * sin(4.0 * ph) + 0.07 * sin(5.0 * ph)
		sine[i] = sin(ph)
	# d-Moll: i - VI - iv - V
	var chords := [[50.0, 53.0, 57.0, 62.0], [46.0, 50.0, 53.0, 58.0], [43.0, 50.0, 55.0, 58.0], [45.0, 49.0, 52.0, 57.0]]
	var roots := [38.0, 34.0, 31.0, 33.0]
	var cf := []
	var rf := PackedFloat32Array()
	for k in 4:
		var arr := PackedFloat32Array()
		for nt in chords[k]:
			arr.append(_hz(nt) * 4096.0)
			arr.append(_hz(nt) * 1.003 * 4096.0)
		cf.append(arr)
		rf.append(_hz(roots[k]) * 4096.0)
	var bells := [[1.0, 74.0], [2.6, 77.0], [4.2, 76.0], [7.0, 74.0], [8.6, 70.0], [10.0, 69.0], [13.0, 67.0], [14.6, 70.0], [16.2, 74.0], [19.0, 73.0], [20.6, 76.0], [22.2, 69.0]]
	var bf := []
	for bl in bells:
		bf.append([bl[0], _hz(bl[1])])
	var cl := LOOP / 4.0
	var dry := PackedFloat32Array()
	dry.resize(n)
	var lp := 0.0
	var wind := 0.0
	for i in n:
		var t := float(i) / RATE
		var p := t / cl
		var k := int(p) % 4
		var f := p - floorf(p)
		var blend := smoothstep(0.0, 0.4, f)
		var kp := (k + 3) % 4
		var tp := t + (LOOP if k == 0 else 0.0)
		var cur := 0.0
		var a: PackedFloat32Array = cf[k]
		for j in a.size():
			cur += tbl[int(t * a[j]) & 4095]
		var prv := 0.0
		var b2: PackedFloat32Array = cf[kp]
		for j in b2.size():
			prv += tbl[int(tp * b2[j]) & 4095]
		var pad := (cur * blend + prv * (1.0 - blend)) * 0.07
		var swell := 0.7 + 0.3 * sin(TAU * t / cl - PI * 0.5)
		var cut := 0.06 + 0.06 * (0.5 + 0.5 * sin(TAU * t / LOOP))
		lp += cut * (pad * swell - lp)
		var bass := (sine[int(t * rf[k]) & 4095] * blend + sine[int(tp * rf[kp]) & 4095] * (1.0 - blend)) * 0.22
		var bell := 0.0
		for e in bf:
			var dt: float = t - e[0]
			if dt < 0.0:
				dt += LOOP
			if dt < 3.5:
				var fq: float = e[1]
				bell += (sin(TAU * fq * dt) + 0.35 * sin(TAU * fq * 2.76 * dt) + 0.15 * sin(TAU * fq * 5.4 * dt)) * exp(-dt * 1.5) * minf(1.0, dt * 200.0) * 0.09
		wind += 0.015 * (rng.randf_range(-1, 1) - wind)
		dry[i] = lp + bass + bell + wind * 0.5 * (0.6 + 0.4 * sin(TAU * t * 2.0 / LOOP))
	return _stereo_delay(dry, n, true)


func _stereo_delay(dry: PackedFloat32Array, n: int, wide: bool) -> AudioStreamWAV:
	var dl := int(0.37 * RATE)
	var dr := int(0.53 * RATE)
	var bl := PackedFloat32Array()
	bl.resize(dl)
	var br := PackedFloat32Array()
	br.resize(dr)
	var il := 0
	var ir := 0
	var out := PackedFloat32Array()
	out.resize(n * 2)
	var fb := 0.42 if wide else 0.25
	for pass_i in 2:
		for i in n:
			var x := dry[i]
			var yl := bl[il]
			var yr := br[ir]
			bl[il] = x * 0.7 + yr * fb
			br[ir] = x * 0.5 + yl * fb
			il = (il + 1) % dl
			ir = (ir + 1) % dr
			if pass_i == 1:
				out[i * 2] = x + yl * 0.55
				out[i * 2 + 1] = x + yr * 0.55
	return _wav(out, 0.85, true, true)


func _gen_drums() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := int(LOOP * RATE)
	var dry := PackedFloat32Array()
	dry.resize(n)
	var eighth := 0.3
	var steps := int(LOOP / eighth)
	var roots := [38.0, 34.0, 31.0, 33.0]
	for s in steps:
		var st := int(s * eighth * RATE)
		var pos := s % 8
		var big := pos == 0 or pos == 4
		var tom := pos == 3 or pos == 6 or pos == 7
		if big or tom:
			var hl := int((0.7 if big else 0.3) * RATE)
			var lp := 0.0
			for i in hl:
				var t := float(i) / RATE
				var f := (95.0 if big else 165.0) * (1.0 - 0.45 * minf(1.0, t * 5.0))
				lp += 0.2 * (rng.randf_range(-1, 1) - lp)
				var v := sin(TAU * f * t) * exp(-t * (6.0 if big else 12.0)) * (1.0 if big else 0.55)
				v += lp * exp(-t * 40.0) * (1.2 if big else 0.6)
				dry[(st + i) % n] += v
		# treibender Bass
		var chord_i := int(float(s) * eighth / (LOOP / 4.0)) % 4
		var bf := _hz(roots[chord_i] + 12.0)
		var bl := int(0.22 * RATE)
		var ph := 0.0
		for i in bl:
			var t := float(i) / RATE
			ph += bf / RATE
			var saw := fmod(ph, 1.0) * 2.0 - 1.0
			dry[(st + i) % n] += saw * exp(-t * 14.0) * 0.18 * (1.0 if pos % 2 == 0 else 0.6)
	return _stereo_delay(dry, n, false)

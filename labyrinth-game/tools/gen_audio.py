#!/usr/bin/env python3
"""Erzeugt alle Musikstuecke und Soundeffekte des Spiels prozedural.

Benoetigt: numpy, ffmpeg (fuer OGG). Aufruf aus dem Projektordner:
    python3 tools/gen_audio.py
Schreibt nach audio/.
"""
import os
import subprocess
import wave

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio')
rng = np.random.default_rng(1234)


# ------------------------------------------------------------------ Helfer
def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def t_axis(dur, sr):
    return np.arange(int(dur * sr)) / sr


def env_adsr(n, sr, a=0.01, d=0.1, s=0.7, r=0.2, hold=None):
    """ADSR-Huellkurve der Laenge n (hold = Zeit bis zum Release)."""
    t = np.arange(n) / sr
    if hold is None:
        hold = max(n / sr - r, a)
    e = np.where(t < a, t / max(a, 1e-6),
                 np.where(t < a + d, 1 - (1 - s) * (t - a) / max(d, 1e-6), s))
    rel = np.clip(1 - (t - hold) / max(r, 1e-6), 0, 1)
    return e * np.where(t > hold, rel, 1)


def phase(f, n, sr):
    f = np.broadcast_to(np.asarray(f, dtype=float), (n,))
    return np.cumsum(f) / sr


def osc(kind, f, n, sr):
    ph = phase(f, n, sr)
    if kind == 'sine':
        return np.sin(2 * np.pi * ph)
    if kind == 'saw':
        return 2 * (ph % 1.0) - 1
    if kind == 'square':
        return np.where((ph % 1.0) < 0.5, 1.0, -1.0)
    if kind == 'pulse':
        return np.where((ph % 1.0) < 0.25, 1.0, -1.0)
    if kind == 'tri':
        return 4 * np.abs((ph % 1.0) - 0.5) - 1
    raise ValueError(kind)


def noise(n):
    return rng.uniform(-1, 1, n)


def fft_filter(x, sr, lo=None, hi=None, order=2):
    """Weicher Hoch-/Tiefpass im Frequenzbereich (zirkular -> loop-sicher)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    H = np.ones_like(f)
    if hi is not None:
        H *= 1 / np.sqrt(1 + (f / hi) ** (2 * order))
    if lo is not None:
        H *= 1 / np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
    return np.fft.irfft(X * H, len(x))


def lp_var(x, fc, sr):
    """Zeitvariabler One-Pole-Tiefpass (fuer kurze Effekte)."""
    fc = np.broadcast_to(np.asarray(fc, dtype=float), x.shape)
    a = 1 - np.exp(-2 * np.pi * fc / sr)
    y = np.empty_like(x)
    s = 0.0
    for i in range(len(x)):
        s += a[i] * (x[i] - s)
        y[i] = s
    return y


def bp_var(x, fc, q, sr):
    """Zeitvariabler State-Variable-Bandpass."""
    fc = np.broadcast_to(np.asarray(fc, dtype=float), x.shape)
    y = np.empty_like(x)
    low = band = 0.0
    damp = 1.0 / q
    for i in range(len(x)):
        f = 2 * np.sin(np.pi * min(fc[i], sr / 6) / sr)
        high = x[i] - low - damp * band
        band += f * high
        low += f * band
        y[i] = band
    return y


def reverb_circular(x, sr, seconds=2.5, wet=0.35, lo=200, hi=5000, seed=7):
    """Faltungshall mit Rausch-Impulsantwort, zirkular (nahtlose Loops)."""
    r = np.random.default_rng(seed)
    n = int(seconds * sr)
    t = np.arange(n) / sr
    ir = r.standard_normal(n) * np.exp(-6.9 * t / seconds)
    ir = fft_filter(ir, sr, lo=lo, hi=hi)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    L = len(x)
    if n > L:
        ir = ir[:L]
    irp = np.zeros(L)
    irp[:len(ir)] = ir
    wet_sig = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(irp), L)
    return x * (1 - wet) + wet_sig * wet * 1.5


def reverb_tail(x, sr, seconds=0.8, wet=0.25):
    pad = np.concatenate([x, np.zeros(int(seconds * sr))])
    return reverb_circular(pad, sr, seconds=seconds, wet=wet)


def normalize(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def soft_clip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


def fade(x, sr, fin=0.005, fout=0.03):
    n_in, n_out = int(fin * sr), int(fout * sr)
    x = x.copy()
    if n_in:
        x[:n_in] *= np.linspace(0, 1, n_in)
    if n_out:
        x[-n_out:] *= np.linspace(1, 0, n_out)
    return x


def write_wav(name, x, sr):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype('<i2').tobytes()
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data)
    return path


def write_ogg(name, x, sr):
    tmp = write_wav('_tmp.wav', x, sr)
    path = os.path.join(OUT, name)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp,
                    '-c:a', 'libvorbis', '-q:a', '4', path], check=True)
    os.remove(tmp)


def mix_at(buf, sig, start, gain=1.0):
    """Addiert sig ab Sample start in buf (zirkular, fuer Loops)."""
    n = len(buf)
    idx = (np.arange(len(sig)) + start) % n
    np.add.at(buf, idx, sig * gain)


# ------------------------------------------------------------- Instrumente
def inst_pad(midis, dur, sr):
    n = int(dur * sr)
    x = np.zeros(n)
    for m in midis:
        for det in (-0.08, 0.0, 0.08):
            x += osc('saw', mtof(m + det), n, sr)
    x = fft_filter(x, sr, hi=900, order=2)
    return x * env_adsr(n, sr, a=1.2, d=0.5, s=0.8, r=1.2) / (len(midis) * 3)


def inst_bell(m, dur, sr):
    n = int(dur * sr)
    t = np.arange(n) / sr
    fc = mtof(m)
    idx = 3.0 * np.exp(-t * 3)
    x = np.sin(2 * np.pi * fc * t + idx * np.sin(2 * np.pi * fc * 1.4 * t))
    x += 0.3 * np.sin(2 * np.pi * fc * 2.01 * t) * np.exp(-t * 4)
    return x * np.exp(-t * 2.2) * env_adsr(n, sr, a=0.003, d=0.05, s=1, r=0.2)


def inst_bass(m, dur, sr, kind='sine', cutoff=None):
    n = int(dur * sr)
    x = osc(kind, mtof(m), n, sr)
    if kind != 'sine':
        x = x * 0.6 + 0.6 * osc('sine', mtof(m), n, sr)
    e = env_adsr(n, sr, a=0.01, d=0.15, s=0.7, r=min(0.1, dur / 3))
    x = x * e
    if cutoff:
        x = fft_filter(x, sr, hi=cutoff, order=2)
    return x


def inst_kick(sr, dur=0.45, f0=150, f1=42):
    n = int(dur * sr)
    t = np.arange(n) / sr
    f = f1 + (f0 - f1) * np.exp(-t * 30)
    x = np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-t * 7)
    x += noise(n) * np.exp(-t * 200) * 0.3
    return x


def inst_tom(sr, m=38, dur=0.6):
    n = int(dur * sr)
    t = np.arange(n) / sr
    f = mtof(m) * (1 + 0.6 * np.exp(-t * 20))
    return np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-t * 6)


def inst_snare(sr, dur=0.25):
    n = int(dur * sr)
    t = np.arange(n) / sr
    x = fft_filter(noise(n), sr, lo=1200, hi=8000) * np.exp(-t * 18)
    x += np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25) * 0.6
    return x


def inst_hat(sr, dur=0.06, open_=False):
    n = int((0.25 if open_ else dur) * sr)
    t = np.arange(n) / sr
    return fft_filter(noise(n), sr, lo=7000, order=3) * np.exp(-t * (12 if open_ else 70))


def inst_lead(m, dur, sr):
    n = int(dur * sr)
    t = np.arange(n) / sr
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 4 - 0.4, 0, 1)
    f = mtof(m) * vib
    x = 0.5 * osc('square', f, n, sr) + 0.5 * osc('saw', f * 1.003, n, sr)
    x = fft_filter(x, sr, hi=2600, order=2)
    return x * env_adsr(n, sr, a=0.01, d=0.1, s=0.75, r=min(0.08, dur / 3))


def inst_power(root, dur, sr):
    n = int(dur * sr)
    x = np.zeros(n)
    for iv in (0, 7, 12):
        for det in (-0.05, 0.05):
            x += osc('saw', mtof(root + iv + det), n, sr)
    x = soft_clip(x * 0.6, 2.5)
    x = fft_filter(x, sr, hi=1800, order=2)
    return x * env_adsr(n, sr, a=0.005, d=0.1, s=0.6, r=min(0.06, dur / 3))


def drip(sr):
    n = int(0.15 * sr)
    t = np.arange(n) / sr
    f = 900 + 1800 * t / 0.15
    return np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-t * 35)


# ------------------------------------------------------------------- Musik
def music_dungeon():
    sr = 44100
    bpm = 72
    beat = 60 / bpm
    bars = 16
    L = int(bars * 4 * beat * sr)
    buf = np.zeros(L)
    # Akkorde (je 2 Takte): Dm, Bb, C, A  (harmonisch Moll)
    prog = [([50, 53, 57], 38), ([46, 50, 53], 34), ([48, 52, 55], 36), ([45, 49, 52], 33)]
    for rep in range(2):
        for i, (chord, root) in enumerate(prog):
            bar = rep * 8 + i * 2
            st = int(bar * 4 * beat * sr)
            mix_at(buf, inst_pad(chord, 8 * beat + 0.6, sr), st, 0.55)
            # Basston: tiefe Orgel + Puls
            for b in range(8):
                mix_at(buf, inst_bass(root, beat * 0.95, sr), st + int(b * beat * sr),
                       0.32 if b % 4 == 0 else 0.18)
    # Herzschlag-Tom
    for bar in range(bars):
        st = int(bar * 4 * beat * sr)
        mix_at(buf, inst_tom(sr, 36), st, 0.35)
        mix_at(buf, inst_tom(sr, 36), st + int(0.45 * beat * sr), 0.22)
        if bar % 2 == 1:
            mix_at(buf, inst_tom(sr, 43, 0.4), st + int(3 * beat * sr), 0.15)
    # Glocken-Melodie (D-Moll), (Takt, Schlag, Midi, Dauer in Schlaegen)
    mel = [
        (0, 0, 74, 2), (0, 2, 72, 1), (0, 3, 69, 1), (1, 0, 70, 3),
        (2, 0, 69, 2), (2, 2, 65, 2), (3, 0, 67, 4),
        (4, 0, 72, 2), (4, 2, 70, 1), (4, 3, 67, 1), (5, 0, 69, 3), (5, 3, 65, 1),
        (6, 0, 64, 2), (6, 2, 61, 2), (7, 0, 62, 4),
        (8, 0, 77, 1.5), (8, 1.5, 76, 0.5), (8, 2, 74, 2), (9, 0, 70, 4),
        (10, 0, 72, 1), (10, 1, 74, 1), (10, 2, 76, 2), (11, 0, 72, 4),
        (12, 0, 73, 2), (12, 2, 76, 2), (13, 0, 74, 2), (13, 2, 69, 2),
        (14, 0, 70, 1), (14, 1, 69, 1), (14, 2, 67, 1), (14, 3, 64, 1), (15, 0, 62, 4),
    ]
    for bar, bt, m, d in mel:
        st = int((bar * 4 + bt) * beat * sr)
        note = inst_bell(m, d * beat + 1.5, sr)
        mix_at(buf, note, st, 0.22)
        mix_at(buf, note, st + int(0.75 * beat * sr), 0.08)   # Echo
    # Wassertropfen
    for k in range(14):
        st = int(rng.uniform(0, L))
        mix_at(buf, drip(sr), st, rng.uniform(0.04, 0.09))
    buf = reverb_circular(buf, sr, seconds=3.5, wet=0.45, hi=4000)
    write_ogg('music_dungeon.ogg', normalize(soft_clip(normalize(buf), 1.2), 0.8), sr)


def music_boss():
    sr = 44100
    bpm = 150
    beat = 60 / bpm
    bars = 16
    L = int(bars * 4 * beat * sr)
    buf = np.zeros(L)
    e8 = beat / 2
    # Em, Em, C, C, D, D, B, B  (E harmonisch Moll)
    roots = [40, 40, 36, 36, 38, 38, 35, 35] * 2
    for bar in range(bars):
        st = int(bar * 4 * beat * sr)
        r = roots[bar]
        # Bass-Achtel mit Oktavspruengen
        for k in range(8):
            m = r + (12 if k in (3, 6) else 0)
            mix_at(buf, inst_bass(m, e8 * 0.9, sr, 'saw', cutoff=700), st + int(k * e8 * sr), 0.42)
        # Power-Chord-Stoesse
        for k, ln in ((0, 3), (3, 3), (6, 2)):
            mix_at(buf, inst_power(r + 12, ln * e8 * 0.9, sr), st + int(k * e8 * sr), 0.30)
        # Schlagzeug
        for b in range(4):
            mix_at(buf, inst_kick(sr), st + int(b * beat * sr), 0.85)
            if b in (1, 3):
                mix_at(buf, inst_snare(sr), st + int(b * beat * sr), 0.5)
        if bar % 4 == 3:
            for k in range(4):
                mix_at(buf, inst_snare(sr, 0.15), st + int((3 * beat + k * beat / 4) * sr), 0.25 + 0.06 * k)
        for k in range(8):
            mix_at(buf, inst_hat(sr, open_=(k == 7)), st + int(k * e8 * sr), 0.14 if k % 2 else 0.2)
    # Lead (zweite Haelfte), E harmonisch Moll
    lead = [
        (8, 0, 76, 1.5), (8, 1.5, 79, 0.5), (8, 2, 78, 1), (8, 3, 76, 1), (9, 0, 75, 2), (9, 2, 71, 2),
        (10, 0, 72, 1.5), (10, 1.5, 76, 0.5), (10, 2, 79, 1), (10, 3, 81, 1), (11, 0, 79, 3), (11, 3, 76, 1),
        (12, 0, 74, 1), (12, 1, 78, 1), (12, 2, 81, 1), (12, 3, 83, 1), (13, 0, 84, 2), (13, 2, 83, 2),
        (14, 0, 87, 1), (14, 1, 86, 1), (14, 2, 83, 1), (14, 3, 78, 1), (15, 0, 75, 2), (15, 2, 71, 2),
    ]
    for bar, bt, m, d in lead:
        st = int((bar * 4 + bt) * beat * sr)
        mix_at(buf, inst_lead(m, d * beat * 0.95, sr), st, 0.17)
    # Gegenstimme erste Haelfte (tiefer, Glocke)
    for bar in range(0, 8):
        st = int(bar * 4 * beat * sr)
        r = roots[bar] + 24
        for k, iv in enumerate((0, 7, 12, 7)):
            mix_at(buf, inst_bell(r + iv, beat * 1.2, sr), st + int(k * beat * sr), 0.07)
    buf = reverb_circular(buf, sr, seconds=1.2, wet=0.18, hi=6000)
    write_ogg('music_boss.ogg', normalize(soft_clip(normalize(buf), 1.6), 0.85), sr)


def music_victory():
    sr = 44100
    beat = 60 / 120
    notes = [(0, 67, 0.5), (0.5, 72, 0.5), (1, 76, 0.5), (1.5, 79, 1.0), (2.5, 76, 0.5), (3, 79, 2.5)]
    L = int(6.5 * sr)
    buf = np.zeros(L)
    for bt, m, d in notes:
        st = int(bt * beat * sr)
        mix_at(buf, inst_lead(m, d * beat, sr), st, 0.3)
        mix_at(buf, inst_bell(m + 12, d * beat + 1, sr), st, 0.15)
    mix_at(buf, inst_pad([60, 64, 67, 72], 3.5, sr), int(3 * beat * sr), 0.8)
    mix_at(buf, inst_kick(sr), int(3 * beat * sr), 0.6)
    buf = reverb_circular(buf, sr, seconds=2, wet=0.3)
    write_ogg('music_victory.ogg', fade(normalize(buf, 0.8), sr, fout=0.5), sr)


# -------------------------------------------------------------- Effekte
SR = 22050


def whoosh(dur=0.22, f0=600, f1=2800, q=2.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    fc = f0 + (f1 - f0) * (t / dur)
    x = bp_var(noise(n), fc, q, SR)
    return x * np.sin(np.pi * t / dur) ** 1.5


def sfx_all():
    out = {}
    # Holzschwert-Schwung
    out['swing'] = normalize(whoosh(), 0.7)
    # Feuerschwert: Fauchen + Knistern
    n = int(0.35 * SR); t = np.arange(n) / SR
    crack = (rng.random(n) < 0.01) * rng.uniform(-1, 1, n)
    roar = lp_var(noise(n), 900, SR) * np.sin(np.pi * t / 0.35)
    out['swing_fire'] = normalize(np.pad(whoosh(0.25, 400, 2000), (0, n - int(0.25 * SR))) + roar * 1.5 + crack * 0.8, 0.8)
    # Eisschwert: Schwung + Kristall-Klingeln
    n = int(0.5 * SR); t = np.arange(n) / SR
    chime = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in ((2637, 9), (3951, 12), (5274, 16), (3322, 10)))
    out['swing_ice'] = normalize(np.pad(whoosh(0.22, 900, 4000), (0, n - int(0.22 * SR))) + chime * 0.25, 0.75)
    # Treffer
    n = int(0.18 * SR); t = np.arange(n) / SR
    out['hit'] = normalize(np.sin(2 * np.pi * (180 * np.exp(-t * 10)) * t) * np.exp(-t * 25)
                           + lp_var(noise(n), 3000, SR) * np.exp(-t * 40), 0.85)
    # Metallisches "Kling" (kein Schaden)
    n = int(0.6 * SR); t = np.arange(n) / SR
    out['clank'] = normalize(sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d)
                                 for f, d in ((820, 6), (1373, 8), (2150, 11), (2960, 14), (4100, 20))), 0.6)
    # Wand bricht
    n = int(0.9 * SR); t = np.arange(n) / SR
    rumble = lp_var(noise(n), 300, SR) * np.exp(-t * 4) * 3
    debris = np.zeros(n)
    for _ in range(25):
        p = int(rng.uniform(0.02, 0.7) * SR)
        m = int(0.03 * SR)
        debris[p:p + m] += fft_filter(noise(m), SR, lo=800, hi=4000) * np.exp(-np.arange(m) / SR * 120) * rng.uniform(0.3, 1)
    out['wall_break'] = normalize(rumble + debris + inst_kick(SR, 0.9, 120, 35)[:n] * 0.8, 0.9)
    # Aufheben
    seq = [72, 76, 79, 84]
    parts = [osc('square', mtof(m), int(0.07 * SR), SR) * 0.5 for m in seq]
    out['pickup'] = fade(np.concatenate(parts) * 0.6, SR)
    # Power-Up
    seq = [60, 64, 67, 72, 76, 79, 84, 88]
    parts = []
    for i, m in enumerate(seq):
        nn = int(0.06 * SR)
        parts.append((osc('square', mtof(m), nn, SR) * 0.4 + osc('sine', mtof(m + 12), nn, SR) * 0.4))
    x = np.concatenate(parts + [inst_bell(96, 0.8, SR) * 0.8])
    out['powerup'] = normalize(reverb_tail(x, SR, 0.6, 0.3), 0.8)
    # Schaden genommen
    n = int(0.3 * SR); t = np.arange(n) / SR
    out['hurt'] = fade(osc('square', 520 * np.exp(-t * 5), n, SR) * np.exp(-t * 6) * 0.5, SR)
    # Tod
    n = int(1.2 * SR); t = np.arange(n) / SR
    out['death'] = fade(lp_var(osc('saw', 330 * np.exp(-t * 1.3) * (1 + 0.03 * np.sin(2 * np.pi * 8 * t)), n, SR), 1500, SR)
                        * np.exp(-t * 1.5) * 0.8, SR, fout=0.2)
    # Fledermaus
    n = int(0.35 * SR)
    x = np.zeros(n)
    for k in range(3):
        m = int(0.04 * SR); tt = np.arange(m) / SR
        chirp = np.sin(2 * np.pi * np.cumsum(5200 - 30000 * tt) / SR) * np.sin(np.pi * tt / 0.04)
        p = int(k * 0.11 * SR)
        x[p:p + m] += chirp
    out['bat'] = normalize(x, 0.55)
    # Schleim
    n = int(0.4 * SR); t = np.arange(n) / SR
    f = 140 + 120 * np.sin(2 * np.pi * 9 * t) * np.exp(-t * 4)
    x = osc('sine', f, n, SR) * np.exp(-t * 6) + lp_var(noise(n), 700, SR) * np.exp(-t * 10) * 2
    out['slime'] = normalize(x, 0.6)
    # Monster stirbt (Plopp)
    n = int(0.3 * SR); t = np.arange(n) / SR
    out['monster_die'] = normalize(osc('sine', 600 * np.exp(-t * 8) + 80, n, SR) * np.exp(-t * 12)
                                   + lp_var(noise(n), 2000, SR) * np.exp(-t * 20), 0.7)

    def growl(dur, base, cut, vib=6.0, rough=0.5):
        n = int(dur * SR); t = np.arange(n) / SR
        f = base * (1 + 0.25 * np.sin(np.pi * t / dur)) * (1 + 0.04 * np.sin(2 * np.pi * vib * t))
        am = 0.7 + 0.3 * np.sin(2 * np.pi * 23 * t + 3 * np.sin(2 * np.pi * 3 * t))
        x = (osc('saw', f, n, SR) + osc('saw', f * 1.49, n, SR) * 0.4) * am
        x += lp_var(noise(n), cut * 1.5, SR) * rough * 3
        x = lp_var(soft_clip(x, 2), cut, SR)
        return fade(x * env_adsr(n, SR, a=0.08, d=0.2, s=0.8, r=dur * 0.4), SR)

    # Schattenritter: metallisches Bruellen
    x = growl(1.0, 95, 1400)
    n = len(x); t = np.arange(n) / SR
    x += sum(np.sin(2 * np.pi * f * t) * np.exp(-t * 5) for f in (1210, 1830)) * 0.1
    out['knight'] = normalize(reverb_tail(x, SR, 0.6, 0.25), 0.85)
    # Krake: Blubbern + Stoehnen
    n = int(1.3 * SR); t = np.arange(n) / SR
    x = growl(1.3, 65, 600, vib=3, rough=0.2) * 0.8
    for _ in range(30):
        m = int(rng.uniform(0.03, 0.07) * SR); tt = np.arange(m) / SR
        f0 = rng.uniform(300, 900)
        b = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 4 * tt / tt[-1])) / SR) * np.sin(np.pi * tt / tt[-1])
        p = int(rng.uniform(0, 1.2) * SR)
        x[p:p + m] += b[:len(x[p:p + m])] * 0.35
    out['octopus'] = normalize(x, 0.85)
    # Tinte / Wasser-Schuss
    n = int(0.25 * SR); t = np.arange(n) / SR
    out['ink'] = normalize(osc('sine', 200 + 900 * np.exp(-t * 25), n, SR) * np.exp(-t * 14)
                           + lp_var(noise(n), 1200, SR) * np.exp(-t * 18) * 1.5, 0.6)
    # Golem: tiefes Grollen
    x = growl(1.4, 48, 450, vib=2, rough=0.9)
    out['golem'] = normalize(reverb_tail(x, SR, 0.8, 0.3), 0.9)
    # Stampfer / Schockwelle
    n = int(1.0 * SR); t = np.arange(n) / SR
    x = inst_kick(SR, 1.0, 90, 30) * 1.2 + lp_var(noise(n), 250, SR) * np.exp(-t * 3) * 4
    out['slam'] = normalize(soft_clip(x, 1.5), 0.95)
    # Drache: lautes Bruellen
    x = growl(1.6, 130, 2200, vib=7, rough=0.8)
    n = len(x); t = np.arange(n) / SR
    x += bp_var(noise(n), 1500 - 800 * t / 1.6, 3, SR) * np.sin(np.pi * t / 1.6) * 1.2
    out['dragon'] = normalize(reverb_tail(x, SR, 1.0, 0.3), 0.9)
    # Feuerduese
    n = int(0.6 * SR); t = np.arange(n) / SR
    x = lp_var(noise(n), 600 + 1500 * np.sin(np.pi * t / 0.6), SR) * np.sin(np.pi * t / 0.6) ** 0.5
    x += (rng.random(n) < 0.006) * rng.uniform(-0.6, 0.6, n)
    out['fire'] = normalize(x, 0.6)
    # Einfrieren
    n = int(0.7 * SR); t = np.arange(n) / SR
    x = np.zeros(n)
    for _ in range(40):
        p = int(rng.uniform(0, 0.5) * SR); m = int(0.015 * SR)
        x[p:p + m] += np.sin(2 * np.pi * rng.uniform(3000, 7000) * np.arange(m) / SR) * np.exp(-np.arange(m) / SR * 200)
    x += sum(np.sin(2 * np.pi * f * t) * np.exp(-t * 4) for f in (1760, 2637)) * 0.3
    out['freeze'] = normalize(x, 0.6)
    # Steintor
    n = int(0.8 * SR); t = np.arange(n) / SR
    grind = lp_var(noise(n) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 14 * t))), 500, SR)
    out['gate'] = normalize(fade(grind * env_adsr(n, SR, 0.05, 0.1, 0.9, 0.2) * 3, SR)
                            + inst_kick(SR, 0.8, 70, 35)[:n] * np.clip((t - 0.65) * 50, 0, 1), 0.8)
    # Boss besiegt: Explosion + aufsteigender Akkord
    n = int(2.2 * SR); t = np.arange(n) / SR
    x = lp_var(noise(n), 800 * np.exp(-t * 1.5) + 100, SR) * np.exp(-t * 2.5) * 4
    x += inst_kick(SR, 2.2, 100, 30) * 0.8
    for i, m in enumerate((60, 64, 67, 72)):
        st = int((0.5 + i * 0.12) * SR)
        b = inst_bell(m + 12, 1.5, SR)
        x[st:st + len(b)] += b[:n - st] * 0.4
    out['boss_defeat'] = normalize(reverb_tail(x, SR, 1.0, 0.3), 0.9)
    # Kristall/Schluessel
    x = np.concatenate([inst_bell(m, 0.12, SR) for m in (84, 88, 91)] + [inst_bell(96, 1.0, SR)])
    out['crystal'] = normalize(reverb_tail(x, SR, 0.8, 0.35), 0.75)
    # Portal gesperrt
    n = int(0.4 * SR); t = np.arange(n) / SR
    out['denied'] = fade(osc('square', np.where(t < 0.2, 220, 165), n, SR) * 0.35 * np.exp(-t * 3), SR)

    for k, v in out.items():
        write_wav(k + '.wav', fade(np.asarray(v, dtype=float), SR, 0.002, 0.02), SR)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    sfx_all()
    music_dungeon()
    music_boss()
    music_victory()
    print('fertig:', sorted(os.listdir(OUT)))

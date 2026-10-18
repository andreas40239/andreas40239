#!/usr/bin/env python3
"""Offline-Synthesizer fuer die Demo-Musik und die Soundeffekte.

Erzeugt:
  music/song1.ogg  - Techno (128 BPM, harte Drums, Acid-Bass, Acid-Pads)
  music/song2.ogg  - Speedrock / Rock'n'Roll (200 BPM)
  music/song3.ogg  - Reggae (One Drop, 80 BPM)
  sounds/*.wav     - Motor-Loops, Reifenquietschen, Fanfare, Boost, Aufprall ...

Aufruf:  python3 tools/gen_audio.py   (im Ordner racetrack/)
Benoetigt numpy, scipy und ffmpeg (fuer OGG).
"""
import os
import subprocess
import sys
import wave

import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rng = np.random.default_rng(1234)


# ----------------------------------------------------------------------------
# Grundbausteine
# ----------------------------------------------------------------------------
def secs(n):
    return np.arange(n) / SR


def midi_hz(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=float) - 69.0) / 12.0)


def _polyblep(ph, dt):
    out = np.zeros_like(ph)
    m = ph < dt
    x = ph[m] / dt[m]
    out[m] = x + x - x * x - 1.0
    m = ph > 1.0 - dt
    x = (ph[m] - 1.0) / dt[m]
    out[m] = x * x + x + x + 1.0
    return out


def phase_of(freq, n, ph0=0.0):
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    dt = f / SR
    return (ph0 + np.cumsum(dt)) % 1.0, dt


def saw(freq, n, ph0=0.0):
    ph, dt = phase_of(freq, n, ph0)
    return 2.0 * ph - 1.0 - _polyblep(ph, dt)


def square(freq, n, pw=0.5, ph0=0.0):
    ph, dt = phase_of(freq, n, ph0)
    a = 2.0 * ph - 1.0 - _polyblep(ph, dt)
    ph2 = (ph + pw) % 1.0
    b = 2.0 * ph2 - 1.0 - _polyblep(ph2, dt)
    return 0.5 * (a - b)


def sine(freq, n, ph0=0.0):
    ph, _ = phase_of(freq, n, ph0)
    return np.sin(2 * np.pi * ph)


def noise(n):
    return rng.uniform(-1.0, 1.0, n)


def butter(x, fc, kind="low", order=2):
    if kind == "band":
        b, a = signal.butter(order, [fc[0] / (SR / 2), fc[1] / (SR / 2)], btype="band")
    else:
        b, a = signal.butter(order, fc / (SR / 2), btype=kind)
    return signal.lfilter(b, a, x)


def svf(x, cutoff, res=0.5, mode="lp"):
    """Zeitvariables State-Variable-Filter (TPT). cutoff in Hz (Array/Skalar), res 0..0.98"""
    n = len(x)
    c = np.clip(np.broadcast_to(np.asarray(cutoff, dtype=float), (n,)), 20.0, SR * 0.45)
    g = np.tan(np.pi * c / SR)
    k = 2.0 - 2.0 * min(res, 0.985)
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    xs = x.tolist()
    a1l, a2l, a3l = a1.tolist(), a2.tolist(), a3.tolist()
    out = [0.0] * n
    ic1 = ic2 = 0.0
    if mode == "lp":
        for i in range(n):
            v3 = xs[i] - ic2
            v1 = a1l[i] * ic1 + a2l[i] * v3
            v2 = ic2 + a2l[i] * ic1 + a3l[i] * v3
            ic1 = 2.0 * v1 - ic1
            ic2 = 2.0 * v2 - ic2
            out[i] = v2
    else:  # band
        for i in range(n):
            v3 = xs[i] - ic2
            v1 = a1l[i] * ic1 + a2l[i] * v3
            v2 = ic2 + a2l[i] * ic1 + a3l[i] * v3
            ic1 = 2.0 * v1 - ic1
            ic2 = 2.0 * v2 - ic2
            out[i] = v1
    return np.array(out)


def env_ad(n, attack, decay, curve=1.0):
    t = secs(n)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-4))
    return a * d ** curve


def env_adsr(n, a, d, s, r, gate):
    """gate = Dauer in Sekunden bis Release"""
    t = secs(n)
    e = np.where(t < a, t / max(a, 1e-4),
                 np.where(t < a + d, 1.0 - (1.0 - s) * (t - a) / max(d, 1e-4), s))
    rel = t > gate
    if np.any(rel):
        lvl = e[min(int(gate * SR), n - 1)]
        e = np.where(rel, lvl * np.exp(-(t - gate) / max(r, 1e-4)), e)
    return e


class Mix:
    def __init__(self, seconds):
        self.n = int(seconds * SR)
        self.buf = np.zeros((self.n, 2))
        self.sends = {}

    def add(self, x, start, gain=1.0, pan=0.0, send=None, send_gain=0.3):
        i0 = int(round(start * SR))
        if i0 >= self.n:
            return
        x = np.asarray(x)
        if x.ndim == 1:
            l = x * gain * np.sqrt(0.5 * (1 - pan))
            r = x * gain * np.sqrt(0.5 * (1 + pan))
            st = np.stack([l, r], axis=1)
        else:
            st = x * gain
        m = min(len(st), self.n - i0)
        self.buf[i0:i0 + m] += st[:m]
        if send:
            if send not in self.sends:
                self.sends[send] = np.zeros((self.n, 2))
            self.sends[send][i0:i0 + m] += st[:m] * send_gain

    def apply_reverb(self, name, seconds=1.8, wet=1.0, hp=200.0):
        if name not in self.sends:
            return
        nir = int(seconds * SR)
        t = secs(nir)
        out = np.zeros_like(self.buf)
        for ch in range(2):
            ir = noise(nir) * np.exp(-t * 6.9 / seconds)
            ir = butter(ir, 6000, "low")
            ir /= np.sqrt(np.sum(ir ** 2))
            y = signal.fftconvolve(self.sends[name][:, ch], ir)[: self.n]
            out[:, ch] = butter(y, hp, "high")
        self.buf += out * wet

    def apply_delay(self, name, delay, feedback=0.45, repeats=6, wet=1.0):
        if name not in self.sends:
            return
        d = int(delay * SR)
        src = self.sends[name]
        g = 1.0
        for k in range(1, repeats + 1):
            g *= feedback
            sh = d * k
            if sh >= self.n:
                break
            seg = src[: self.n - sh].copy()
            # Ping-Pong
            if k % 2:
                seg = seg[:, ::-1]
            seg[:, 0] = butter(seg[:, 0], 3500, "low")
            seg[:, 1] = butter(seg[:, 1], 3500, "low")
            self.buf[sh:] += seg * g * wet

    def master(self, fade_in=0.02, fade_out=1.2, drive=1.3):
        x = self.buf
        x = x - np.mean(x, axis=0)
        peak = np.max(np.abs(x)) + 1e-9
        x = x / peak * drive
        x = np.tanh(x) / np.tanh(drive)
        fi = int(fade_in * SR)
        fo = int(fade_out * SR)
        x[:fi] *= np.linspace(0, 1, fi)[:, None]
        x[-fo:] *= np.linspace(1, 0, fo)[:, None] ** 1.5
        x *= 0.95 / (np.max(np.abs(x)) + 1e-9)
        return x


def write_wav(path, data):
    data = np.asarray(data)
    if data.ndim == 1:
        data = data[:, None]
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(pcm.shape[1])
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def write_ogg(path, data):
    tmp = path + ".tmp.wav"
    write_wav(tmp, data)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis",
                    "-q:a", "5", path], check=True)
    os.remove(tmp)


# ----------------------------------------------------------------------------
# Drums
# ----------------------------------------------------------------------------
def kick(hard=False, length=0.45, f_hi=160.0, f_lo=46.0):
    n = int(length * SR)
    t = secs(n)
    f = f_lo + (f_hi - f_lo) * np.exp(-t / 0.035)
    body = sine(f, n) * np.exp(-t / (0.32 if hard else 0.22))
    click = butter(noise(n), 2500, "high") * np.exp(-t / 0.004) * 0.5
    x = body + click
    if hard:
        x = np.tanh(x * 3.0) * 0.9
    return x


def snare(tone=190.0, length=0.35, snap=0.12):
    n = int(length * SR)
    t = secs(n)
    body = sine(tone * (1 + 0.4 * np.exp(-t / 0.01)), n) * np.exp(-t / 0.05) * 0.6
    nz = butter(noise(n), (1500, 9000), "band") * np.exp(-t / snap)
    return np.tanh((body + nz * 1.1) * 1.4)


def clap(length=0.4):
    n = int(length * SR)
    t = secs(n)
    nz = butter(noise(n), (900, 3200), "band", order=2)
    e = np.zeros(n)
    for k, off in enumerate((0.0, 0.011, 0.022, 0.031)):
        tt = np.maximum(t - off, 0)
        e += (t >= off) * np.exp(-tt / (0.006 if k < 3 else 0.13))
    return np.tanh(nz * e * 3.0)


def hat(open_=False, length=None):
    length = length or (0.5 if open_ else 0.07)
    n = int(length * SR)
    t = secs(n)
    metal = sum(square(f, n) for f in (3150.0, 4170.0, 5410.0, 6880.0)) * 0.25
    x = butter(noise(n) * 0.7 + metal * 0.5, 7000, "high")
    return x * np.exp(-t / (0.16 if open_ else 0.022))


def crash(length=2.2):
    n = int(length * SR)
    t = secs(n)
    metal = sum(square(f, n) for f in (2210.0, 3375.0, 4520.0, 5990.0, 7530.0)) * 0.15
    x = butter(noise(n) + metal, 3500, "high")
    return x * np.exp(-t / 0.7) * (1 - np.exp(-t / 0.002))


def ride(length=0.9):
    n = int(length * SR)
    t = secs(n)
    bell = sine(3250.0, n) * 0.25 + sine(5150.0, n) * 0.12
    x = butter(noise(n), 6000, "high") * 0.5 + bell
    return x * np.exp(-t / 0.35)


def rimshot(length=0.12):
    n = int(length * SR)
    t = secs(n)
    x = sine(820.0, n) * np.exp(-t / 0.012) + butter(noise(n), (1800, 6000), "band") * np.exp(-t / 0.018)
    return np.tanh(x * 2.0)


def tom(freq=110.0, length=0.5):
    n = int(length * SR)
    t = secs(n)
    f = freq * (1 + 0.6 * np.exp(-t / 0.03))
    return sine(f, n) * np.exp(-t / 0.18) + butter(noise(n), 3000, "low") * np.exp(-t / 0.02) * 0.3


# ----------------------------------------------------------------------------
# Song 1: Techno
# ----------------------------------------------------------------------------
def song_techno():
    bpm = 128.0
    beat = 60.0 / bpm
    bar = beat * 4
    st = beat / 4
    bars = 32
    mx = Mix(bars * bar + 0.01)
    K = kick(hard=True, length=0.5)
    CL = clap()
    CH = hat()
    OH = hat(True)
    CR = crash()

    def is_break(b):
        return 16 <= b < 20

    for b in range(bars):
        t0 = b * bar
        for q in range(4):
            tq = t0 + q * beat
            if not is_break(b):
                mx.add(K, tq, 0.95)
            if b >= 8 and not is_break(b) and q in (1, 3):
                mx.add(CL, tq, 0.55, 0.05, send="rev", send_gain=0.35)
            if b >= 4 and not (16 <= b < 19):
                mx.add(OH, tq + beat / 2, 0.22, 0.25)
        if b >= 2 and not (16 <= b < 18):
            for s in range(16):
                acc = 0.16 if s % 4 == 2 else 0.08
                mx.add(CH, t0 + s * st, acc, -0.3 + 0.6 * ((s * 7) % 5) / 4)
        if b in (8, 20, 24, 28):
            mx.add(CR, t0, 0.35, 0.0, send="rev", send_gain=0.2)
    # Snare-Roll zum Drop
    SN = snare(220, 0.25, 0.08)
    for i in range(32):
        tt = 19 * bar + i * (bar / 32)
        mx.add(SN, tt, 0.12 + 0.5 * i / 32, 0.0, send="rev", send_gain=0.2)
    # Riser
    nr = int(2 * bar * SR)
    tr = secs(nr)
    riser = svf(noise(nr), 300 + 7000 * (tr / tr[-1]) ** 2, 0.7, "band") * (tr / tr[-1]) ** 2
    mx.add(riser, 18 * bar, 0.25, 0.0, send="rev", send_gain=0.4)

    # Acid-Bass (303-artig): ein durchgehender Oszillator mit Slides
    notes = [33, 33, 45, 33, 36, 33, 43, 0, 33, 45, 33, 40, 31, 33, 45, 36]
    accent = [1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0]
    slide = [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0]
    alt = [33, 33, 45, 33, 38, 33, 45, 0, 33, 46, 33, 41, 31, 33, 43, 38]
    total = mx.n
    freq = np.zeros(total)
    gate = np.zeros(total)
    fenv = np.zeros(total)
    n_steps = int(bars * 16)
    sn = int(st * SR)
    prev_f = midi_hz(33)
    for s in range(n_steps):
        b = s // 16
        if b < 4 or (16 <= b < 18):
            continue
        i = s % 16
        pat = alt if (b // 2) % 4 == 3 else notes
        m = pat[i]
        i0 = int(s * st * SR)
        i1 = min(i0 + sn, total)
        if m == 0:
            continue
        f = midi_hz(m)
        seg = i1 - i0
        if slide[i]:
            freq[i0:i1] = np.geomspace(prev_f, f, seg)
        else:
            freq[i0:i1] = f
        prev_f = f
        gl = seg if slide[(i + 1) % 16] else int(seg * 0.62)
        gate[i0:i0 + gl] = 1.0
        tt = secs(seg)
        fenv[i0:i1] = np.exp(-tt / (0.09 if accent[i] else 0.05)) * (1.6 if accent[i] else 0.8)
    freq[freq == 0] = midi_hz(33)
    tt = secs(total)
    lfo = 0.5 - 0.5 * np.cos(2 * np.pi * tt / (8 * bar))
    base_cut = 180 + 900 * lfo + 600 * np.clip((tt - 20 * bar) / (12 * bar), 0, 1)
    osc = saw(freq, total) * 0.7 + square(freq, total, 0.5) * 0.3
    g_sm = butter(gate, 300, "low")
    cut = base_cut + 2800 * fenv * (0.4 + lfo)
    acid = svf(osc * g_sm, cut, 0.9) * 2.2
    acid = np.tanh(acid * 1.8)
    acid = butter(acid, 40, "high")
    mx.add(acid, 0, 0.42, 0.0, send="dly", send_gain=0.18)

    # Sub-Bass unter dem Kick (Offbeat)
    SUB = sine(midi_hz(33), int(beat * 0.45 * SR)) * env_ad(int(beat * 0.45 * SR), 0.005, 0.12)
    for b in range(bars):
        if b < 8 or is_break(b):
            continue
        for q in range(4):
            mx.add(SUB, b * bar + q * beat + beat / 2, 0.35)

    # Acid-Pads: Akkorde mit schmatzendem Resonanzfilter
    chords = [[57, 60, 64, 67], [53, 57, 60, 64], [50, 57, 60, 65], [52, 55, 59, 64]]
    pad = np.zeros((total, 2))
    for b in range(8, bars):
        ch = chords[(b // 2) % 4]
        i0 = int(b * bar * SR)
        seg = int(bar * SR)
        for c in range(2):
            v = np.zeros(seg)
            for m in ch:
                for det in (-0.09, 0.0, 0.11):
                    v += saw(midi_hz(m + det + (0.03 if c else -0.03)), seg, rng.random())
            pad[i0:i0 + seg, c] += v / 8.0
    # Gate-Rhythmus in 16teln (Trance-Gate-Artig) + Filter-Squelch
    gpat = np.array([1, 0.3, 0.8, 0.3, 1, 0.3, 0.6, 1, 0.3, 0.8, 1, 0.3, 0.7, 0.3, 1, 0.5])
    steps = (tt / st).astype(int) % 16
    stp = (tt / st) % 1.0
    gate_env = gpat[steps] * np.exp(-stp * 2.2)
    sq_lfo = 0.5 - 0.5 * np.cos(2 * np.pi * tt / (4 * bar))
    pcut = 350 + 2600 * sq_lfo * (0.5 + 0.5 * gate_env)
    in_break = (tt >= 16 * bar) & (tt < 20 * bar)
    pcut = np.where(in_break, 300 + 4000 * ((tt - 16 * bar) / (4 * bar)) ** 2, pcut)
    gate_env = np.where(in_break, 1.0, gate_env)
    for c in range(2):
        pad[:, c] = svf(pad[:, c], pcut, 0.82) * butter(gate_env, 60, "low")
    pad *= np.clip((tt - 8 * bar) / (2 * bar), 0, 1)[:, None]
    mx.add(pad, 0, 0.5, send="rev", send_gain=0.35)

    mx.apply_delay("dly", beat * 0.75, 0.4, 5, 0.8)
    mx.apply_reverb("rev", 2.2, 0.7)
    return mx.master(drive=1.6)


# ----------------------------------------------------------------------------
# Song 2: Speedrock
# ----------------------------------------------------------------------------
def guitar_chord(root, dur, muted=False, n_extra=0.0, seed=0, fifth=True):
    n = int((dur + (0.05 if muted else 0.25)) * SR)
    ns = [root, root + 7, root + 12] if fifth else [root]
    x = np.zeros(n)
    for m in ns:
        for det in (-0.07, 0.06):
            x += saw(midi_hz(m + det), n, rng.random())
    x /= len(ns) * 2
    x = butter(x, 90, "high")
    x = np.tanh(x * 9.0)
    if muted:
        e = env_ad(n, 0.002, 0.07)
        x = butter(x * e, 1400, "low", 2)
        x = x * 1.6
    else:
        e = env_adsr(n, 0.003, 0.15, 0.75, 0.12, dur)
        x = butter(x * e, 4200, "low", 2)
    return x


def lead_note(m, dur, bend=0.0):
    n = int((dur + 0.1) * SR)
    t = secs(n)
    vib = 0.25 * np.clip((t - 0.12) / 0.15, 0, 1) * np.sin(2 * np.pi * 6.0 * t)
    bd = bend * np.clip(t / 0.08, 0, 1)
    f = midi_hz(m + vib + bd)
    x = saw(f, n) * 0.6 + square(f * 2.0, n, 0.3) * 0.2
    x = np.tanh(butter(x, 200, "high") * 7.0)
    x = butter(x, 3800, "low", 2)
    return x * env_adsr(n, 0.005, 0.1, 0.85, 0.06, dur)


def bass_note(m, dur, drive=2.5):
    n = int((dur + 0.03) * SR)
    f = midi_hz(m)
    x = saw(f, n) * 0.6 + sine(f, n) * 0.6
    x = np.tanh(butter(x, 1200, "low") * drive)
    return x * env_adsr(n, 0.003, 0.05, 0.8, 0.02, dur * 0.9)


def song_rock():
    bpm = 200.0
    beat = 60.0 / bpm
    bar = beat * 4
    e8 = beat / 2
    bars = 50
    mx = Mix(bars * bar + 2.0)
    K = kick(length=0.3, f_hi=140, f_lo=55)
    S = snare(200, 0.3, 0.1)
    H = hat(length=0.06)
    R = ride()
    C = crash()
    T1, T2, T3 = tom(180), tom(130), tom(95)
    E, G, A, B, D = 40, 43, 45, 47, 38  # Grundtoene (E2 ...)

    # Gitarre: Spuren links/rechts (gedoppelt)
    def gtr(root, t, dur, muted=False, gain=0.5):
        mx.add(guitar_chord(root, dur, muted), t, gain, -0.65)
        mx.add(guitar_chord(root, dur, muted), t + 0.008, gain, 0.65)

    def bass(m, t, dur):
        mx.add(bass_note(m - 12, dur), t, 0.55, 0.0)

    # Verse-Riff (2 Takte, Achtel): (Grundton, gedaempft?)
    riff = [(E, 1), (E, 1), (E, 1), (E, 1), (E, 1), (E, 1), (G, 0), (A, 0),
            (E, 1), (E, 1), (E, 1), (E, 1), (D, 0), (D, 1), (B - 12, 0), (B - 12, 0)]
    chorus = [(A, 4), (E, 4), (A, 4), (E, 4), (G, 2), (D, 2), (B - 12, 4), (A, 4), (E, 4), (A, 4), (B - 12, 4)]

    def section_verse(b0, nbars):
        for b in range(nbars):
            for i in range(8):
                root, muted = riff[(b % 2) * 8 + i]
                t = (b0 + b) * bar + i * e8
                gtr(root, t, e8 * (0.9 if muted else 0.95), bool(muted), 0.42 if muted else 0.5)
                bass(root, t, e8 * 0.9)
            # Drums: Kick 1, 2&, 3 ; Snare 2, 4 ; Hats Achtel
            t0 = (b0 + b) * bar
            for i in range(8):
                mx.add(H, t0 + i * e8, 0.18 if i % 2 else 0.26, 0.3)
            for k in (0, 3, 4):
                mx.add(K, t0 + k * e8, 0.9)
            for s_ in (2, 6):
                mx.add(S, t0 + s_ * e8, 0.75, -0.05, send="rev", send_gain=0.25)
            if b == 0:
                mx.add(C, t0, 0.4, -0.4, send="rev", send_gain=0.15)

    def section_chorus(b0, nbars):
        tpos = b0 * bar
        seq = []
        acc = 0
        idx = 0
        while acc < nbars * 8:
            root, l8 = chorus[idx % len(chorus)]
            seq.append((root, acc, l8))
            acc += l8
            idx += 1
        for root, s8, l8 in seq:
            if s8 >= nbars * 8:
                break
            for j in range(l8):
                t = tpos + (s8 + j) * e8
                gtr(root, t, e8 * 0.97, False, 0.36 if j else 0.5)
                bass(root, t, e8 * 0.9)
        for b in range(nbars):
            t0 = (b0 + b) * bar
            # Oom-Pah Punk-Beat
            for i in range(8):
                if i % 2 == 0:
                    mx.add(K, t0 + i * e8, 0.9)
                else:
                    mx.add(S, t0 + i * e8, 0.62, -0.05, send="rev", send_gain=0.2)
                mx.add(R, t0 + i * e8, 0.13, 0.4)
            if b % 2 == 0:
                mx.add(C, t0, 0.45, 0.4 if b % 4 else -0.4, send="rev", send_gain=0.15)

    def fill(b):
        t0 = b * bar + 4 * e8
        for i, (tm, g) in enumerate([(S, 0.6), (S, 0.7), (T1, 0.8), (T1, 0.8), (T2, 0.85), (T2, 0.85),
                                     (T3, 0.9), (T3, 0.95)]):
            mx.add(tm, t0 + i * (e8 / 2), g, -0.3 + 0.6 * i / 7)

    def section_solo(b0, nbars):
        section_verse(b0, nbars)
        # Pentatonik-Melodie (E-Moll)
        line = [(64, 2), (67, 1), (69, 1), (71, 2, 2), (69, 1), (67, 1),
                (64, 2), (62, 1), (64, 5), (0, 4),
                (71, 1), (74, 1), (76, 2), (74, 1), (76, 1), (79, 2, 1), (76, 2), (74, 2), (71, 4),
                (69, 1), (71, 1), (69, 1), (67, 1), (64, 4), (67, 2), (69, 2, 2), (71, 4), (0, 4),
                (76, 1), (79, 1), (81, 1), (79, 1), (76, 1), (74, 1), (71, 1), (69, 1), (67, 1), (69, 1),
                (71, 2), (64, 8)]
        t = b0 * bar
        tend = (b0 + nbars) * bar
        for item in line:
            m, l8 = item[0], item[1]
            bend = item[2] if len(item) > 2 else 0
            if t >= tend:
                break
            if m:
                mx.add(lead_note(m - (2 if bend else 0), l8 * e8 * 0.95, bend), t, 0.33, 0.1,
                       send="rev", send_gain=0.4)
            t += l8 * e8

    # Intro: Fill + grosser Akkord
    for i in range(8):
        mx.add(S, i * e8, 0.25 + 0.08 * i, 0.0)
    fill(0)
    gtr(E, bar, bar * 2 - 0.05, False, 0.55)
    bass(E, bar, bar * 1.8)
    mx.add(C, bar, 0.55, 0.0, send="rev", send_gain=0.3)
    mx.add(K, bar, 1.0)
    fill(2)
    b = 3
    section_verse(b, 8); fill(b + 7); b += 8          # 3-10
    section_chorus(b, 8); fill(b + 7); b += 8         # 11-18
    section_solo(b, 8); fill(b + 7); b += 8           # 19-26
    section_verse(b, 8); fill(b + 7); b += 8          # 27-34
    section_chorus(b, 8); fill(b + 7); b += 8         # 35-42
    # 43-48: Stops / Hits
    hits = [E, E, G, G, A, A, B - 12, B - 12, E, E, G, G, A, B - 12, E, E]
    for i, root in enumerate(hits * 1):
        t = b * bar + i * (bar * 6 / len(hits))
        gtr(root, t, bar * 6 / len(hits) * 0.9, False, 0.5)
        bass(root, t, bar * 6 / len(hits) * 0.8)
        mx.add(K, t, 1.0)
        mx.add(C if i % 4 == 0 else S, t, 0.5 if i % 4 == 0 else 0.6, 0.0, send="rev", send_gain=0.2)
    b += 6
    fill(b - 1)
    # Schlussakkord
    gtr(E, b * bar, 2.6, False, 0.6)
    bass(E, b * bar, 2.4)
    mx.add(C, b * bar, 0.7, 0.0, send="rev", send_gain=0.3)
    mx.add(K, b * bar, 1.0)
    mx.apply_reverb("rev", 1.4, 0.6)
    out = mx.master(drive=1.5, fade_out=0.8)
    return out[: int(60.0 * SR)] if len(out) > 60 * SR else out


# ----------------------------------------------------------------------------
# Song 3: Reggae
# ----------------------------------------------------------------------------
def skank_chord(notes, dur=0.16):
    n = int((dur + 0.05) * SR)
    x = np.zeros(n)
    for m in notes:
        x += saw(midi_hz(m), n, rng.random()) + square(midi_hz(m) * 1.002, n, 0.4) * 0.4
    x = butter(x / len(notes), (700, 4500), "band", 1)
    return x * env_ad(n, 0.002, 0.05)


def organ_chord(notes, dur):
    n = int((dur + 0.03) * SR)
    x = np.zeros(n)
    for m in notes:
        f = midi_hz(m)
        x += sine(f, n) + 0.5 * sine(2 * f, n) + 0.3 * sine(3 * f, n) + 0.15 * sine(4 * f, n)
    return x / len(notes) * env_adsr(n, 0.004, 0.03, 0.8, 0.02, dur)


def reggae_bass(m, dur):
    n = int((dur + 0.05) * SR)
    f = midi_hz(m)
    x = sine(f, n) + 0.25 * sine(2 * f, n) + 0.08 * saw(f, n)
    x = np.tanh(x * 1.3)
    return butter(x, 700, "low") * env_adsr(n, 0.008, 0.1, 0.85, 0.04, dur)


def melodica(m, dur):
    n = int((dur + 0.08) * SR)
    t = secs(n)
    vib = 0.18 * np.clip((t - 0.15) / 0.2, 0, 1) * np.sin(2 * np.pi * 5.2 * t)
    f = midi_hz(m + vib)
    x = square(f, n, 0.32) * 0.7 + saw(f, n) * 0.3
    x = butter(x, 2600, "low") + butter(noise(n), (1500, 4000), "band") * 0.04
    return x * env_adsr(n, 0.04, 0.1, 0.8, 0.07, dur)


def song_reggae():
    bpm = 80.0
    beat = 60.0 / bpm
    bar = beat * 4
    e8 = beat / 2
    bars = 20
    mx = Mix(bars * bar + 0.01)
    K = kick(length=0.4, f_hi=120, f_lo=50)
    RS = rimshot()
    SN = snare(230, 0.3, 0.09)
    H = hat(length=0.05)
    OH = hat(True, 0.35)
    swing = e8 * 0.12

    Am, D, Dm, Em, F, G, C = ([57, 60, 64], [57, 62, 66], [57, 62, 65], [55, 59, 64],
                              [57, 60, 65], [55, 59, 62], [55, 60, 64])
    roots = {"Am": 45, "D": 38, "Dm": 38, "Em": 40, "F": 41, "G": 43, "C": 36}
    chords = {"Am": Am, "D": D, "Dm": Dm, "Em": Em, "F": F, "G": G, "C": C}
    prog = (["Am", "Am"] + ["Am", "D", "Am", "D", "Am", "D", "F", "G"] +
            ["Dm", "Am", "Dm", "Am", "F", "G", "Am", "Em"] + ["Am", "Am"])

    bass_pat = [(0.0, 0, 1.2), (1.5, 0, 0.4), (2.0, 7, 0.45), (2.5, 10, 0.4), (3.0, 12, 0.45), (3.5, 7, 0.45)]
    bass_pat2 = [(0.0, 0, 0.9), (1.0, 3, 0.45), (1.5, 5, 0.4), (2.5, 7, 0.9), (3.5, 5, 0.4)]

    for b, name in enumerate(prog):
        t0 = b * bar
        ch = chords[name]
        r = roots[name]
        # Skank auf 2 und 4 (mit Dub-Echo)
        for q in (1, 3):
            mx.add(skank_chord([m + 12 for m in ch]), t0 + q * beat, 0.42, 0.35, send="dly", send_gain=0.35)
        # Orgel-"Bubble" auf den Offbeats
        if 2 <= b < 18:
            for i in range(8):
                if i % 2 == 1:
                    mx.add(organ_chord(ch, e8 * 0.45), t0 + i * e8 + swing, 0.16, -0.4)
        # Bass
        if b >= 1:
            pat = bass_pat if b % 2 == 0 else bass_pat2
            for (bt, off, ln) in pat:
                mx.add(reggae_bass(r + off - 12 if r > 40 else r + off, ln * beat), t0 + bt * beat, 0.75, 0.0)
        # One-Drop Drums
        for i in range(8):
            tt = t0 + i * e8 + (swing if i % 2 else 0)
            if b >= 1:
                mx.add(H, tt, 0.16 if i % 2 else 0.11, 0.35)
        if b >= 1:
            mx.add(K, t0 + 2 * beat, 0.85)
            mx.add(RS, t0 + 2 * beat, 0.5, -0.1, send="rev", send_gain=0.25)
            if b % 4 == 3:
                mx.add(OH, t0 + 3.5 * beat, 0.18, 0.35)
        # Fills am Abschnittsende
        if b in (1, 9, 17):
            for i in range(6):
                mx.add(SN, t0 + 3 * beat + i * (beat / 6), 0.25 + 0.06 * i, -0.2 + 0.08 * i,
                       send="rev", send_gain=0.3)

    # Melodica-Melodie (Teil B und Schluss)
    mel = [(69, 1.0), (72, 0.5), (74, 1.5), (72, 0.5), (69, 0.5), (67, 1.0), (69, 3.0),
           (0, 1.0), (74, 0.5), (76, 0.5), (77, 1.0), (76, 1.0), (74, 1.0), (72, 0.5), (74, 3.5),
           (0, 1.0), (72, 0.5), (74, 0.5), (76, 1.5), (74, 0.5), (72, 1.0), (69, 1.0), (67, 2.0), (69, 2.5),
           (0, 1.5), (76, 0.5), (79, 0.5), (76, 1.0), (74, 1.0), (72, 1.0), (71, 2.0), (69, 4.0)]
    t = 10 * bar
    for m, ln in mel:
        if m:
            mx.add(melodica(m, ln * beat * 0.92), t, 0.3, -0.15, send="dly", send_gain=0.25)
        t += ln * beat
    # Intro-Melodie leiser
    t = 2 * bar + 2 * beat
    for m, ln in mel[:7]:
        if m:
            mx.add(melodica(m - 12, ln * beat * 0.92), t, 0.22, 0.2, send="dly", send_gain=0.3)
        t += ln * beat

    mx.apply_delay("dly", beat * 0.75, 0.5, 6, 0.9)
    mx.apply_reverb("rev", 1.6, 0.6)
    return mx.master(drive=1.4)


# ----------------------------------------------------------------------------
# Soundeffekte
# ----------------------------------------------------------------------------
def loop_xfade(x, fade=0.05):
    """Macht einen Puffer nahtlos loopbar (Ende in den Anfang ueberblenden)."""
    nf = int(fade * SR)
    out = x[:-nf].copy()
    w = np.linspace(0, 1, nf)
    out[:nf] = x[:nf] * w + x[-nf:] * (1 - w)
    return out


def engine_kart():
    n = SR + int(0.05 * SR)
    t = secs(n)
    f0 = 55.0
    ph = (t * f0) % 1.0
    pulse = np.exp(-ph / 0.08) * np.sin(2 * np.pi * ph * 5)  # Einzylinder-"Knall" pro Takt
    buzz = saw(f0 * 2, n) * 0.35 + square(f0, n, 0.2) * 0.3
    nz = butter(noise(n), (300, 3000), "band") * (np.exp(-ph / 0.15)) * 0.6
    x = pulse * 0.9 + buzz + nz
    x = np.tanh(butter(x, 3200, "low") * 2.0)
    return loop_xfade(x) * 0.8


def engine_racer():
    n = SR + int(0.05 * SR)
    t = secs(n)
    f0 = 110.0
    x = np.zeros(n)
    for h, a in [(1, 1.0), (2, 0.6), (3, 0.45), (4, 0.35), (5, 0.3), (6, 0.18), (8, 0.12), (10, 0.08)]:
        x += a * np.sin(2 * np.pi * f0 * h * t + rng.random() * 6.28)
    x += saw(f0 * 0.5, n) * 0.4 + saw(f0 * 1.005, n) * 0.3
    x = np.tanh(x * 1.5)
    x += butter(noise(n), (1500, 5000), "band") * 0.15
    x = butter(x, 6000, "low")
    return loop_xfade(x) * 0.7


def engine_truck():
    n = SR + int(0.05 * SR)
    t = secs(n)
    f0 = 32.0
    ph_cycle = t * f0
    idx = ph_cycle.astype(int) % 8
    amps = np.array([1.0, 0.62, 0.9, 0.55, 1.0, 0.7, 0.82, 0.6])
    ph = ph_cycle % 1.0
    pulse = np.exp(-ph / 0.18) * amps[idx]
    x = butter(pulse - pulse.mean(), 900, "low") * 3.0
    x += saw(f0, n) * 0.45 + sine(f0 * 0.5, n) * 0.5
    x += butter(noise(n), 400, "low") * 0.5 * pulse
    x = np.tanh(x * 1.8)
    x = butter(x, 1400, "low")
    return loop_xfade(x) * 0.85


def squeal():
    n = SR + int(0.05 * SR)
    t = secs(n)
    fm = 1 + 0.02 * np.sin(2 * np.pi * 7 * t) + 0.01 * np.sin(2 * np.pi * 13 * t)
    x = sine(1150 * fm, n) * 0.6 + sine(1720 * fm, n) * 0.3 + sine(2300 * fm, n) * 0.15
    x += butter(noise(n), (900, 2600), "band") * 0.5
    am = 0.75 + 0.25 * np.sin(2 * np.pi * 11 * t)
    return loop_xfade(np.tanh(x * am * 1.5)) * 0.7


def fanfare():
    mx = Mix(4.2)
    tri = 0.13

    def brass(m, dur):
        n = int((dur + 0.25) * SR)
        t = secs(n)
        vib = 0.12 * np.clip((t - 0.15) / 0.2, 0, 1) * np.sin(2 * np.pi * 5.5 * t)
        f = midi_hz(m + vib)
        x = saw(f, n) * 0.7 + saw(f * 1.003, n) * 0.4
        e = env_adsr(n, 0.02, 0.1, 0.8, 0.12, dur)
        cut = 600 + 3500 * env_ad(n, 0.04, 0.4) + 1200 * e
        return np.tanh(svf(x, cut, 0.3) * e * 1.6)

    seq = [(67, 0, tri * 0.9), (67, tri, tri * 0.9), (67, 2 * tri, tri * 0.9), (72, 3 * tri, 0.45),
           (67, 3 * tri + 0.5, 0.18), (72, 3 * tri + 0.7, 0.18), (76, 3 * tri + 0.9, 0.18), (79, 3 * tri + 1.1, 1.6)]
    for m, t0, d in seq:
        mx.add(brass(m, d), t0, 0.5, -0.2, send="rev", send_gain=0.4)
        mx.add(brass(m - (5 if m > 67 else 12), d), t0 + 0.005, 0.32, 0.25, send="rev", send_gain=0.4)
    # Schlussakkord
    for m in (60, 64, 67, 72):
        mx.add(brass(m, 1.6), 3 * tri + 1.1, 0.25, (m - 66) / 10, send="rev", send_gain=0.4)
    SN = snare(240, 0.2, 0.06)
    for i in range(14):
        mx.add(SN, 3 * tri + 1.1 + i * 0.07, 0.12 + 0.02 * i, 0.0)
    mx.add(crash(2.5), 3 * tri + 1.1, 0.4, 0.0, send="rev", send_gain=0.3)
    mx.add(kick(True), 3 * tri + 1.1, 0.6)
    mx.add(pop(), 0.0, 0.6)
    mx.apply_reverb("rev", 1.8, 0.7)
    return mx.master(fade_out=0.6, drive=1.2)


def pop():
    n = int(0.12 * SR)
    t = secs(n)
    return butter(noise(n), (600, 5000), "band") * np.exp(-t / 0.02) * 2.0


def boost():
    n = int(1.0 * SR)
    t = secs(n)
    cut = 300 * (14 ** (t / t[-1]))
    x = svf(noise(n), cut, 0.75, "band") * 2.0
    x += saw(110 * (1 + 2 * t), n) * 0.25
    e = np.clip(t / 0.05, 0, 1) * np.exp(-np.maximum(t - 0.55, 0) / 0.15)
    return np.tanh(x * e * 1.5) * 0.8


def thud():
    n = int(0.4 * SR)
    t = secs(n)
    x = sine(70 * (1 + np.exp(-t / 0.02)), n) * np.exp(-t / 0.12)
    x += butter(noise(n), 1500, "low") * np.exp(-t / 0.04) * 0.8
    x += butter(noise(n), (2000, 6000), "band") * np.exp(-t / 0.015) * 0.3
    return np.tanh(x * 1.8) * 0.9


def place_click():
    n = int(0.12 * SR)
    t = secs(n)
    x = sine(900, n) * np.exp(-t / 0.015) + sine(1800, n) * np.exp(-t / 0.008) * 0.4
    x += butter(noise(n), 3000, "high") * np.exp(-t / 0.004) * 0.4
    return x * 0.8


def error_buzz():
    n = int(0.35 * SR)
    t = secs(n)
    x = square(110, n, 0.5) * 0.5 + square(116, n, 0.5) * 0.5
    g = ((t < 0.13) | ((t > 0.18) & (t < 0.31))).astype(float)
    return butter(x * butter(g, 200, "low"), 1800, "low") * 0.6


def landing():
    n = int(0.3 * SR)
    t = secs(n)
    x = sine(55 * (1 + 0.5 * np.exp(-t / 0.03)), n) * np.exp(-t / 0.09)
    x += butter(noise(n), 800, "low") * np.exp(-t / 0.05) * 0.7
    return np.tanh(x * 1.5) * 0.8


def main():
    music = os.path.join(ROOT, "music")
    sounds = os.path.join(ROOT, "sounds")
    os.makedirs(music, exist_ok=True)
    os.makedirs(sounds, exist_ok=True)
    only = sys.argv[1:]

    def want(name):
        return not only or name in only

    sfx = {
        "engine_kart": engine_kart, "engine_racer": engine_racer, "engine_truck": engine_truck,
        "squeal": squeal, "fanfare": fanfare, "boost": boost, "thud": thud, "click": place_click,
        "error": error_buzz, "landing": landing,
    }
    for name, fn in sfx.items():
        if want(name):
            x = fn()
            if x.ndim == 1:
                x = x / (np.max(np.abs(x)) + 1e-9) * 0.9
            write_wav(os.path.join(sounds, name + ".wav"), x)
            print("sound", name, len(x) / SR, "s")
    for name, fn in (("song1", song_techno), ("song2", song_rock), ("song3", song_reggae)):
        if want(name):
            x = fn()
            write_ogg(os.path.join(music, name + ".ogg"), x)
            print("music", name, round(len(x) / SR, 2), "s")


if __name__ == "__main__":
    main()

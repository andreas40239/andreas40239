#!/usr/bin/env python3
"""Procedural audio generator for "Zombie in Athen".

Every sound effect and both music loops are synthesised from scratch with
numpy/scipy (oscillators, filtered noise, modal resonators, Karplus-Strong
strings, formant filters, convolution reverb).  No samples, no downloads, so
all output is licence-free.

Usage (from the project root):
    python3 tools/gen_audio.py              # generate everything + verify
    python3 tools/gen_audio.py win lose     # only regenerate some assets
    python3 tools/gen_audio.py --verify     # only verify existing files

Output goes to assets/audio/.  The script is deterministic (fixed seed).
Requirements: numpy, scipy, ffmpeg/ffprobe (for the OGG Vorbis music).
"""
import json
import os
import struct
import subprocess
import sys
import tempfile
import wave
import zlib

import numpy as np
from scipy import signal

SR = 44100
SEED = 40239
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT_DIR = os.path.join(ROOT, "assets", "audio")
FFMPEG = "ffmpeg"
FFPROBE = "ffprobe"

# ----------------------------------------------------------------------------
# basic helpers
# ----------------------------------------------------------------------------


def rng_for(name):
    """Independent deterministic RNG per asset (so assets do not affect each other)."""
    return np.random.default_rng([SEED, zlib.crc32(name.encode())])


def n_of(t):
    return int(round(t * SR))


def tvec(n):
    return np.arange(n) / SR


def db(x):
    return 10.0 ** (x / 20.0)


def white(rng, n):
    return rng.standard_normal(n)


def colored(rng, n, slope=1.0):
    """Noise with a 1/f^slope power spectrum (1 = pink, 2 = brown)."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = f[1]
    spec *= (f / 100.0) ** (-slope / 2.0)
    x = np.fft.irfft(spec, n)
    return x / (np.std(x) + 1e-12)


def lp(x, fc, order=2):
    sos = signal.butter(order, min(fc, SR * 0.45), "low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def hp(x, fc, order=2):
    sos = signal.butter(order, fc, "high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, min(hi, SR * 0.45)], "band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp1(x, fc):
    a = np.exp(-2.0 * np.pi * fc / SR)
    return signal.lfilter([1.0 - a], [1.0, -a], x)


def reson(x, f, q):
    """Two-pole resonator with unity gain at f."""
    b, a = signal.iirpeak(f, q, fs=SR)
    return signal.lfilter(b, a, x)


def peq(x, f, q, gain_db):
    """RBJ peaking EQ."""
    A = 10.0 ** (gain_db / 40.0)
    w = 2.0 * np.pi * f / SR
    al = np.sin(w) / (2.0 * q)
    b = np.array([1 + al * A, -2 * np.cos(w), 1 - al * A])
    a = np.array([1 + al / A, -2 * np.cos(w), 1 - al / A])
    return signal.lfilter(b / a[0], a / a[0], x)


def svf(x, fc, q=0.707, mode="lp"):
    """Time-varying state variable filter (TPT form). fc/q may be arrays."""
    n = len(x)
    fc = np.clip(np.broadcast_to(np.asarray(fc, dtype=float), (n,)), 15.0, 0.45 * SR)
    k = 1.0 / np.broadcast_to(np.asarray(q, dtype=float), (n,))
    g = np.tan(np.pi * fc / SR)
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    xs = np.asarray(x, dtype=float).tolist()
    A1, A2, A3 = a1.tolist(), a2.tolist(), a3.tolist()
    v1s = [0.0] * n
    v2s = [0.0] * n
    ic1 = ic2 = 0.0
    for i in range(n):
        v3 = xs[i] - ic2
        v1 = A1[i] * ic1 + A2[i] * v3
        v2 = ic2 + A2[i] * ic1 + A3[i] * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        v1s[i] = v1
        v2s[i] = v2
    v1 = np.array(v1s)
    v2 = np.array(v2s)
    if mode == "lp":
        return v2
    if mode == "bp":
        return k * v1
    if mode == "hp":
        return x - k * v1 - v2
    raise ValueError(mode)


def decay(n, t60):
    return np.exp(-6.9078 * tvec(n) / t60)


def ar_env(n, attack, t60):
    """Smooth attack followed by exponential decay."""
    t = tvec(n)
    if attack > 0:
        a = np.sin(np.clip(t / attack, 0.0, 1.0) * np.pi / 2.0) ** 2
    else:
        a = 1.0
    return a * np.exp(-6.9078 * np.maximum(t - attack, 0.0) / t60)


def env_pts(n, pts):
    """Piecewise-linear envelope through (time_s, value) points."""
    return np.interp(tvec(n), [p[0] for p in pts], [p[1] for p in pts])


def env_log(n, pts):
    """Piecewise-exponential (log-linear) curve, for frequencies."""
    return np.exp(np.interp(tvec(n), [p[0] for p in pts], [np.log(p[1]) for p in pts]))


def bell(n, peak=0.5, power=1.0):
    """Swell envelope 0 -> 1 -> 0 with its maximum at fraction `peak`."""
    u = np.linspace(0.0, 1.0, n)
    w = np.where(u < peak, u / peak, (1.0 - u) / (1.0 - peak))
    return np.sin(w * np.pi / 2.0) ** (2.0 * power)


def fade(x, fi=0.001, fo=0.012):
    x = np.array(x, dtype=float)
    a = max(1, n_of(fi))
    b = max(1, n_of(fo))
    a = min(a, len(x) // 2)
    b = min(b, len(x) // 2)
    x[:a] *= np.sin(np.linspace(0, np.pi / 2, a, endpoint=False)) ** 2
    x[-b:] *= np.cos(np.linspace(0, np.pi / 2, b, endpoint=False) + np.pi / 2 / b) ** 2
    x[-1] = 0.0
    return x


def normalize(x, peak_db=-1.0):
    m = np.max(np.abs(x))
    return x * (db(peak_db) / m) if m > 0 else x


def place(buf, x, t, g=1.0):
    """Mix x into buf at time t (seconds); clipped at the buffer end."""
    i = n_of(t)
    if i >= buf.shape[-1] or i < 0:
        return
    j = min(buf.shape[-1], i + x.shape[-1])
    buf[..., i:j] += g * x[..., : j - i]


def place_circ(buf, x, t, g=1.0):
    """Mix x into the loop buffer at time t with wrap-around (seamless loops)."""
    L = buf.shape[-1]
    i = n_of(t) % L
    n = x.shape[-1]
    pos = 0
    while pos < n:
        m = min(n - pos, L - i)
        buf[..., i : i + m] += g * x[..., pos : pos + m]
        pos += m
        i = 0


def pan(x, p):
    """Equal-power pan of a mono signal, p in [-1 (left), 1 (right)]."""
    a = (p + 1.0) * np.pi / 4.0
    return np.stack([np.cos(a) * x, np.sin(a) * x])


def sweep(n, f0, f1, tau):
    """Sine whose frequency glides exponentially from f0 to f1 (time constant tau)."""
    f = f1 + (f0 - f1) * np.exp(-tvec(n) / tau)
    return np.sin(2.0 * np.pi * np.cumsum(f) / SR)


def tone(f):
    """Sine from a per-sample frequency array."""
    return np.sin(2.0 * np.pi * np.cumsum(f) / SR)


def modal(n, freqs, t60s, amps):
    """Sum of exponentially damped sines (struck resonant modes)."""
    freqs = np.atleast_1d(np.asarray(freqs, dtype=float))
    t60s = np.broadcast_to(np.asarray(t60s, dtype=float), freqs.shape)
    amps = np.broadcast_to(np.asarray(amps, dtype=float), freqs.shape)
    t = tvec(n)[None, :]
    y = amps[:, None] * np.exp(-6.9078 * t / t60s[:, None]) * np.sin(2 * np.pi * freqs[:, None] * t)
    return y.sum(axis=0)


def blip(f0, f1, dur):
    """Short gliding sine with a Hann envelope (bubble / droplet)."""
    n = max(8, n_of(dur))
    f = np.geomspace(f0, f1, n)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.hanning(n)


def pulse_train(n, rate, rng, jitter=0.1, amp_jit=0.2):
    """Irregular impulse train (stick-slip creaks, vocal fry). rate: Hz array."""
    rate = np.broadcast_to(np.asarray(rate, dtype=float), (n,))
    out = np.zeros(n)
    pos = float(rng.uniform(0, SR / rate[0]))
    while pos < n - 2:
        i = int(pos)
        fr = pos - i
        a = 1.0 + amp_jit * rng.standard_normal()
        out[i] += a * (1.0 - fr)
        out[i + 1] += a * fr
        pos += SR / rate[i] * max(0.3, 1.0 + jitter * rng.standard_normal())
    return out


def crackles(rng, n, count, t0, t1, lo=(900, 2500), hi=(3500, 8000), dec=(0.003, 0.012), power=1.5, amp_fall=1.0):
    """Cluster of short band-limited noise snaps (splintering, crunching)."""
    out = np.zeros(n)
    m = n_of(0.04)
    for _ in range(count):
        u = rng.random() ** power
        t = t0 + (t1 - t0) * u
        b = bp(white(rng, m), rng.uniform(*lo), rng.uniform(*hi)) * decay(m, rng.uniform(*dec))
        place(out, b, t, rng.uniform(0.3, 1.0) * (1.0 - amp_fall * 0.7 * u))
    return out


def saw_blep(f):
    """Band-limited (polyBLEP) sawtooth from a per-sample frequency array."""
    dt = f / SR
    tot = np.cumsum(dt)
    ph = tot - np.floor(tot)
    y = 2.0 * ph - 1.0
    m = ph < dt
    x = ph[m] / dt[m]
    y[m] -= x + x - x * x - 1.0
    m = ph > 1.0 - dt
    x = (ph[m] - 1.0) / dt[m]
    y[m] -= x * x + x + x + 1.0
    return y


# ----------------------------------------------------------------------------
# reverb (convolution with exponentially decaying, frequency-shaped noise)
# ----------------------------------------------------------------------------

_IR_CACHE = {}


def room_ir(t60, bright=5000.0, seed=1):
    key = (round(t60, 4), round(bright), seed)
    if key not in _IR_CACHE:
        r = np.random.default_rng([SEED, 777, seed])
        n = n_of(t60 * 1.25)
        nz = r.standard_normal(n)
        lo = lp(nz, bright, 2) * decay(n, t60)
        hi = hp(nz, bright, 2) * decay(n, t60 * 0.4)  # highs die faster
        ir = hp(lo + hi, 140.0, 2)
        k = n_of(0.004)
        ir[:k] *= np.linspace(0.0, 1.0, k)
        # a few discrete early reflections
        for _ in range(6):
            i = int(r.uniform(0.004, 0.045) * SR)
            if i < n:
                ir[i] += r.choice([-1.0, 1.0]) * r.uniform(2.0, 5.0) * np.std(ir[: n_of(0.05)])
        ir *= np.cos(np.linspace(0, np.pi / 2, n)) ** 0.5
        _IR_CACHE[key] = ir / np.sqrt(np.sum(ir ** 2))
    return _IR_CACHE[key]


def reverb(x, t60=0.4, mix=0.15, bright=5000.0, seed=1, predelay=0.004):
    """Mono reverb; returns dry + wet including the tail."""
    ir = room_ir(t60, bright, seed)
    wet = signal.fftconvolve(x, ir)
    pd = n_of(predelay)
    out = np.zeros(len(wet) + pd)
    out[: len(x)] += x
    out[pd:] += mix * wet
    return out


def circ_reverb(x2, t60, bright, seed, predelay=0.02, cross=0.3):
    """Stereo reverb applied as circular convolution so a loop stays seamless."""
    L = x2.shape[1]
    pd = n_of(predelay)
    out = np.zeros_like(x2)
    for c in range(2):
        ir = room_ir(t60, bright, seed + 10 * c)
        h = np.zeros(L)
        idx = (np.arange(len(ir)) + pd) % L
        np.add.at(h, idx, ir)
        src = (1.0 - cross) * x2[c] + cross * x2[1 - c]
        out[c] = np.fft.irfft(np.fft.rfft(src) * np.fft.rfft(h), L)
    return out


# ----------------------------------------------------------------------------
# Karplus-Strong bouzouki
# ----------------------------------------------------------------------------

NOTE_IDX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6,
            "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def N(name):
    """Note name ('F#4') -> frequency in Hz."""
    if not isinstance(name, str):
        return float(name)
    midi = 12 * (int(name[-1]) + 1) + NOTE_IDX[name[:-1]]
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def ks_string(exc, freq, t60, bright=0.9):
    """Karplus-Strong string as one IIR filter:
    y[n] = x[n] + g * LP(frac_delay(y[n-N])), fractional delay for exact tuning."""
    P = SR / freq
    s = bright                      # weight of the undelayed tap of the loop low-pass
    d = P - (1.0 - s)               # delay left for the delay line (+ linear interpolation)
    Nd = int(np.floor(d))
    fr = d - Nd
    g = 10.0 ** (-3.0 / (t60 * freq))
    c = g * np.convolve([s, 1.0 - s], [1.0 - fr, fr])
    a = np.zeros(Nd + 3)
    a[0] = 1.0
    a[Nd : Nd + 3] -= c
    return signal.lfilter([1.0], a, exc)


def pluck(freq, n, rng, amp=1.0, bright=0.9, octave=False, detune=6.0, t60=None):
    """One pick stroke on a double course (two slightly detuned strings)."""
    out = np.zeros(n)
    if t60 is None:
        t60 = float(np.clip(2.6 * (220.0 / freq) ** 0.45, 0.7, 4.0))
    courses = [(-detune / 2.0, 1.0, 1.0, 0.0),
               (detune / 2.0, 2.0 if octave else 1.0, 0.8, rng.uniform(0.002, 0.005))]
    for cents, mult, gain, dly in courses:
        fj = freq * mult * 2.0 ** (cents / 1200.0)
        P = SR / fj
        m = int(P) + 1
        burst = rng.uniform(-1.0, 1.0, m)
        burst = lp1(burst, 1800.0 + 7000.0 * min(1.0, amp))   # softer strokes are darker
        burst -= burst.mean()
        burst /= np.max(np.abs(burst)) + 1e-9
        exc = np.zeros(n)
        d = n_of(dly)
        if d + m >= n:
            continue
        exc[d : d + m] = burst
        pp = max(1, int(round(0.13 * P)))                     # pick position comb (near bridge)
        e2 = exc.copy()
        e2[pp:] -= 0.8 * exc[:-pp]
        out += gain * ks_string(e2, fj, t60 / (1.5 if mult > 1 else 1.0), bright)
    # pick noise
    k = min(n, n_of(0.004))
    out[:k] += 0.25 * hp(white(rng, k), 2500.0) * np.linspace(1, 0, k) ** 2
    return amp * out


SWELLS = {
    None: lambda u: 1.0,
    "hairpin": lambda u: 0.5 + 0.5 * np.sin(np.pi * u) ** 0.8,
    "cresc": lambda u: 0.45 + 0.55 * u,
    "dim": lambda u: 1.0 - 0.65 * u,
}


def bouz_note(freq, dur, rng, vel=1.0, trem=0.0, swell=None, ring=0.12, bright=0.9,
              octave=False, strokes=None, jit=0.06, t60=None):
    """Bouzouki note. trem > 0 gives tremolo picking at that rate (Hz): every new
    stroke damps the string and re-excites it, like a real plectrum.
    ring: release time constant after `dur` (None = let the string ring out)."""
    freq = N(freq)
    if strokes is None:
        if trem > 0:
            k = max(1, int(round(dur * trem)))
            strokes = np.arange(k) / trem
            strokes[1:] += rng.uniform(-jit, jit, k - 1) / trem
        else:
            strokes = np.array([0.0])
    strokes = np.asarray(strokes, dtype=float)
    tail = 2.5 if ring is None else 5.0 * ring
    total = n_of(dur + tail)
    out = np.zeros(total)
    damp = n_of(0.010)
    for si, ts in enumerate(strokes):
        last = si == len(strokes) - 1
        u = ts / max(dur, 1e-6)
        amp = vel * (1.0 if si % 2 == 0 else 0.8) * (1.0 + 0.07 * rng.standard_normal()) * SWELLS[swell](u)
        i0 = n_of(ts)
        if last:
            y = pluck(freq, total - i0, rng, amp, bright, octave, t60=t60)
            if ring is not None:
                r0 = max(0, n_of(dur - ts))
                y[r0:] *= np.exp(-tvec(len(y) - r0) / ring)
        else:
            seg = n_of(strokes[si + 1] - ts) + damp
            y = pluck(freq, seg, rng, amp, bright, octave, t60=t60)
            y[-damp:] *= np.cos(np.linspace(0, np.pi / 2, damp)) ** 2
        out[i0 : i0 + len(y)] += y[: total - i0]
    return out


def bouz_body(x):
    """Body/soundboard colouring of the bouzouki bus."""
    x = hp(x, 110.0, 2)
    x = peq(x, 290.0, 1.4, 3.0)
    x = peq(x, 820.0, 1.2, 2.0)
    x = peq(x, 2900.0, 1.1, 4.5)
    return lp(x, 9500.0, 1)


def bouz_line(notes, rng, tail=3.0):
    """notes: list of (time, pitch, dur, vel, kwargs). Returns a mono line."""
    end = max(t + d for t, _, d, _, _ in notes) + tail
    buf = np.zeros(n_of(end))
    for t, pitch, dur, vel, kw in notes:
        place(buf, bouz_note(pitch, dur, rng, vel=vel, **kw), t)
    return bouz_body(buf)


# ----------------------------------------------------------------------------
# creature / human voice (source-filter synthesis)
# ----------------------------------------------------------------------------

VOWELS = {
    "a": (730, 1090, 2440, 3400), "o": (570, 840, 2410, 3300), "u": (300, 870, 2240, 3200),
    "e": (530, 1840, 2480, 3500), "i": (270, 2290, 3010, 3600), "uh": (640, 1190, 2390, 3300),
    "ae": (660, 1720, 2410, 3400), "r": (490, 1350, 1690, 3200),
}


def vowel_path(n, pts, scale=1.0):
    """Formant trajectories through [(time, vowel), ...]; scale < 1 = bigger throat."""
    t = tvec(n)
    tp = [p[0] for p in pts]
    sc = np.broadcast_to(np.asarray(scale, dtype=float), (n,))
    return [sc * np.exp(np.interp(t, tp, [np.log(VOWELS[p[1]][k]) for p in pts])) for k in range(4)]


def formant_bank(src, F, bws=(90, 110, 170, 250), gains=(1.0, 0.7, 0.4, 0.22)):
    out = np.zeros(len(src))
    for f, bw, g in zip(F, bws, gains):
        out += g * svf(src, f, q=f / bw, mode="bp")
    return out


def glottal(f0, rng, jitter=0.02, shimmer=0.1, sub=0.0, tilt=1200.0):
    """Glottal source: band-limited saw with pitch jitter, per-cycle shimmer and
    period doubling (`sub`) for rough, sub-harmonic growls."""
    n = len(f0)
    j = lp1(white(rng, n), 30.0)
    j /= np.std(j) + 1e-12
    f = f0 * (1.0 + np.broadcast_to(jitter, (n,)) * j)
    dt = f / SR
    tot = np.cumsum(dt)
    cyc = np.floor(tot).astype(int)
    ph = tot - cyc
    y = 2.0 * ph - 1.0
    m = ph < dt
    x = ph[m] / dt[m]
    y[m] -= x + x - x * x - 1.0
    m = ph > 1.0 - dt
    x = (ph[m] - 1.0) / dt[m]
    y[m] -= x * x + x + x + 1.0
    ncyc = int(cyc[-1]) + 1
    first = np.minimum(np.searchsorted(cyc, np.arange(ncyc)), n - 1)
    sh = np.broadcast_to(shimmer, (n,))[first]
    sb = np.broadcast_to(sub, (n,))[first]
    amps = 1.0 + sh * rng.standard_normal(ncyc)
    amps[1::2] *= 1.0 - sb[1::2]
    y = y * amps[cyc]
    return lp1(y, tilt), ph


def fry(n, rate, rng, jitter=0.2, fc=2600.0):
    """Vocal fry: slow irregular glottal pulses."""
    return lp1(pulse_train(n, rate, rng, jitter=jitter, amp_jit=0.3), fc) * 8.0


def monster_post(x, drive=2.5, chest_db=6.0, top=5500.0):
    x = hp(x, 70.0, 2)
    x = peq(x, 170.0, 1.0, chest_db)
    x = x / (np.max(np.abs(x)) + 1e-9)
    x = np.tanh(drive * x)
    return lp(x, top, 2)


# ----------------------------------------------------------------------------
# sound effects
# ----------------------------------------------------------------------------


def sfx_step_run(idx):
    r = rng_for(f"step_run_{idx}")
    dur = [0.19, 0.21, 0.18, 0.23][idx - 1]
    n = n_of(dur)
    v = r.uniform
    click = bp(white(r, n), 1800 * v(0.85, 1.2), 6500, 2) * decay(n, 0.012 * v(0.8, 1.3))
    knock = sweep(n, 430 * v(0.9, 1.1), 185 * v(0.9, 1.1), 0.010) * decay(n, 0.06)
    tok = modal(n, np.array([540, 815, 1290, 1830]) * v(0.9, 1.1) * r.uniform(0.96, 1.04, 4),
                [0.05, 0.04, 0.03, 0.02], [1, 0.8, 0.5, 0.3])
    fm = np.array([172, 287, 431, 655, 968]) * v(0.92, 1.08) * r.uniform(0.96, 1.04, 5)
    floor = modal(n, fm, [0.14, 0.11, 0.08, 0.06, 0.04], [1, 0.7, 0.5, 0.35, 0.2])
    thump = sweep(n, 115 * v(0.9, 1.1), 58, 0.03) * decay(n, 0.12)
    scuff = bp(white(r, n), 700, 3200) * ar_env(n, 0.004, 0.06 * v(0.8, 1.3))
    x = 1.5 * click + 1.1 * knock + 0.7 * tok + 0.6 * floor + 0.45 * thump + 0.35 * scuff
    out = x.copy()
    place(out, lp(x, 3000), v(0.026, 0.04), 0.4 * v(0.7, 1.2))      # toe lands after heel
    out = np.tanh(1.4 * out / np.max(np.abs(out)))
    return reverb(out, 0.22, 0.10, 4000, seed=2), dur


def sfx_step_sneak(idx):
    r = rng_for(f"step_sneak_{idx}")
    dur = [0.17, 0.19][idx - 1]
    n = n_of(dur)
    v = r.uniform
    pad = bp(white(r, n), 240, 1300 * v(0.85, 1.2), 1) * ar_env(n, 0.012, 0.085 * v(0.9, 1.2))
    thump = sweep(n, 170 * v(0.9, 1.1), 95, 0.03) * ar_env(n, 0.006, 0.07)
    tick = bp(white(r, n), 1800, 4200) * ar_env(n, 0.002, 0.012)
    cloth = bp(white(r, n), 2500, 6500) * ar_env(n, 0.03, 0.05) * lp1(np.abs(white(r, n)), 60)
    x = pad / np.max(np.abs(pad)) + 0.3 * thump + 0.06 * tick / np.max(np.abs(tick)) + 0.2 * cloth / np.max(np.abs(cloth))
    return x, dur


def sfx_zombie_step(idx):
    r = rng_for(f"zombie_step_{idx}")
    dur = [0.50, 0.56, 0.45][idx - 1]
    drag = [0.30, 0.35, 0.26][idx - 1]
    n = n_of(dur)
    v = r.uniform
    nd = n_of(drag)
    # dragging scrape: gritty band noise with stick-slip roughness
    rough = lp1(white(r, nd), 45.0 * v(0.8, 1.3))
    rough = np.maximum(rough / (np.std(rough) + 1e-9), -0.4) + 0.5
    fc = env_log(nd, [(0, 500 * v(0.8, 1.2)), (drag * 0.6, 1500 * v(0.8, 1.2)), (drag, 800)])
    scrape = svf(white(r, nd), fc, 1.1, "bp") * rough * bell(nd, 0.65, 0.8)
    grit = crackles(r, nd, 22, 0.02, drag, lo=(1500, 3000), hi=(4500, 8000), dec=(0.002, 0.006), power=0.8, amp_fall=0.0)
    rumble = lp(white(r, nd), 190) * bell(nd, 0.6)
    x = np.zeros(n)
    place(x, 1.0 * scrape / np.max(np.abs(scrape)) + 0.3 * grit + 0.3 * rumble / np.max(np.abs(rumble)), 0.0)
    # dull thud of the dead foot landing
    nt = n - n_of(drag - 0.03)
    thud = 0.6 * np.tanh(2.0 * sweep(nt, 150 * v(0.9, 1.1), 62, 0.03) * decay(nt, 0.18))
    thud += 1.6 * lp(white(r, nt), 600) * decay(nt, 0.07)
    thud += 0.6 * modal(nt, np.array([148, 236, 371, 590]) * v(0.93, 1.07), [0.12, 0.09, 0.06, 0.04], [1, 0.8, 0.5, 0.3])
    place(x, thud, drag - 0.03, 0.7)
    return reverb(x, 0.25, 0.10, 3500, seed=2), dur


def sfx_glass_break():
    r = rng_for("glass_break")
    dur = 1.5
    n = n_of(dur)
    x = np.zeros(n)
    # impact
    x += 1.2 * hp(white(r, n), 1800) * decay(n, 0.045)
    x += 0.9 * bp(white(r, n), 350, 1100) * decay(n, 0.035)
    x += 0.7 * sweep(n, 190, 85, 0.02) * decay(n, 0.08)
    # shatter: dense cluster of inharmonic ringing partials
    k = 70
    fr = np.exp(r.uniform(np.log(1800), np.log(15000), k))
    x += 0.16 * modal(n, fr, r.uniform(0.03, 0.28, k), r.uniform(0.3, 1.0, k) * (3000.0 / fr) ** 0.3)
    # bright fizz of tiny fragments
    x += 0.5 * hp(white(r, n), 5000) * ar_env(n, 0.002, 0.35) * (0.4 + lp1(np.abs(white(r, n)), 90))

    def tink(f0, t60, m):
        ratios = np.array([1.0, r.uniform(1.3, 1.7), r.uniform(2.1, 2.9), r.uniform(3.2, 4.4)])
        f = f0 * ratios
        keep = f < 19000
        y = modal(m, f[keep], (t60 * np.array([1, 0.7, 0.5, 0.35]))[keep], np.array([1, 0.6, 0.4, 0.25])[keep])
        kk = n_of(0.0015)
        y[:kk] += 0.5 * white(r, kk) * np.linspace(1, 0, kk)
        return y

    m = n_of(0.3)
    # falling shards, denser at first
    for _ in range(60):
        u = r.random() ** 1.7
        t = 0.04 + 1.28 * u
        x_amp = r.uniform(0.3, 1.0) * np.exp(-1.7 * u)
        place(x, tink(r.uniform(2800, 9500), r.uniform(0.02, 0.11), m), t, x_amp)
    # bigger pieces hitting the floor and bouncing
    for t0, a0 in ((0.33, 1.1), (0.58, 0.85), (0.86, 0.55)):
        for b in range(5):
            t = t0 + r.uniform(-0.03, 0.03) + 0.045 * b * r.uniform(0.6, 1.4)
            place(x, tink(r.uniform(2200, 6000), r.uniform(0.04, 0.14), m), t, a0 * 0.75 ** b * r.uniform(0.6, 1.0))
    for t, a in ((1.12, 0.22), (1.21, 0.3), (1.27, 0.14), (1.36, 0.16)):      # last stragglers
        place(x, tink(r.uniform(3500, 8000), r.uniform(0.04, 0.09), m), t, a)
    return reverb(x, 0.5, 0.12, 7000, seed=3), dur


def wood_hit(r, m, f0, bright=1.0):
    y = modal(m, f0 * np.array([1.0, 2.76, 5.40]) * r.uniform(0.97, 1.03, 3),
              np.array([0.11, 0.07, 0.04]) * r.uniform(0.7, 1.3), [1.0, 0.5 * bright, 0.25 * bright])
    y += 0.6 * bp(white(r, m), f0, f0 * 6) * decay(m, 0.02)
    return y


def sfx_door_break():
    r = rng_for("door_break")
    dur = 1.2
    n = n_of(dur)
    x = np.zeros(n)
    boom = np.tanh(2.5 * sweep(n, 98, 43, 0.05) * decay(n, 0.3))
    crack = hp(white(r, n), 500) * decay(n, 0.03) + 0.8 * bp(white(r, n), 900, 4500) * decay(n, 0.1)
    panel = modal(n, np.array([118, 187, 263, 395, 540, 760]) * r.uniform(0.97, 1.03, 6),
                  [0.28, 0.24, 0.2, 0.15, 0.11, 0.08], [1, 0.9, 0.7, 0.5, 0.35, 0.25])
    splinter = crackles(r, n, 20, 0.004, 0.26, lo=(700, 1800), hi=(3000, 7500), dec=(0.004, 0.02), power=1.3)
    x += 0.55 * boom + 1.1 * crack + 0.75 * panel + 1.0 * splinter
    # second crack as the door gives way
    place(x, bp(white(r, n_of(0.2)), 600, 5000) * decay(n_of(0.2), 0.05), 0.085, 0.7)
    place(x, np.tanh(2 * sweep(n_of(0.3), 170, 75, 0.03) * decay(n_of(0.3), 0.2)), 0.085, 0.4)
    # debris: planks and splinters falling
    m = n_of(0.25)
    for t, a in ((0.2, 0.7), (0.27, 1.0), (0.36, 0.8), (0.42, 0.5), (0.47, 0.9), (0.58, 0.6), (0.64, 0.4), (0.7, 0.65), (0.83, 0.45), (0.93, 0.3)):
        place(x, wood_hit(r, m, r.uniform(240, 900)), t + r.uniform(-0.015, 0.015), a)
    x += 0.5 * crackles(r, n, 34, 0.2, 1.05, lo=(900, 2500), hi=(3500, 8000), dec=(0.003, 0.01), power=1.0)
    wash = lp(white(r, n), 2400) * ar_env(n, 0.01, 0.55) * (0.5 + lp1(np.abs(white(r, n)), 40))
    x += 0.25 * wash / np.max(np.abs(wash)) * 1.6
    return reverb(x, 0.6, 0.2, 4500, seed=4), dur


def sfx_door_bang():
    r = rng_for("door_bang")
    dur = 0.5
    n = n_of(dur)
    thud = np.tanh(2.2 * sweep(n, 165, 68, 0.035) * decay(n, 0.24))
    panel = modal(n, [118, 172, 246, 335, 470, 640, 880], [0.32, 0.27, 0.21, 0.15, 0.11, 0.08, 0.05],
                  [1, 0.95, 0.85, 0.65, 0.45, 0.3, 0.18])
    fist = lp(white(r, n), 1300) * decay(n, 0.03) + 0.6 * bp(white(r, n), 300, 900) * decay(n, 0.06)
    x = 0.55 * thud + 0.9 * panel + 1.6 * fist
    for t, a in ((0.027, 0.10), (0.049, 0.07), (0.083, 0.045), (0.125, 0.03)):   # latch / frame rattle
        m = n_of(0.03)
        place(x, bp(white(r, m), 2200, 6000) * decay(m, 0.005), t, a * 4)
    return reverb(x, 0.45, 0.16, 3200, seed=4), dur


def sfx_zombie_groan(idx):
    r = rng_for(f"zombie_groan_{idx}")
    if idx == 1:      # ---- long low moan "uuuooaaah"
        dur = 1.8
        n = n_of(dur)
        t = tvec(n)
        f0 = env_log(n, [(0, 60), (0.3, 80), (1.0, 73), (1.5, 62), (1.8, 46)])
        f0 = f0 * (1 + 0.02 * np.sin(2 * np.pi * 4.3 * t))
        sub = env_pts(n, [(0, 0.5), (0.3, 0.15), (1.2, 0.2), (1.8, 0.7)])
        src, ph = glottal(f0, r, jitter=0.03, shimmer=0.12, sub=sub, tilt=900)
        breath = hp(white(r, n), 900) * (0.6 + 0.4 * np.sin(2 * np.pi * ph)) * 0.10
        F = vowel_path(n, [(0, "u"), (0.5, "o"), (1.1, "a"), (1.8, "uh")], 0.8)
        y = formant_bank(src + breath, F)
        y += 0.35 * formant_bank(fry(n, env_log(n, [(0, 30), (1.8, 22)]), r), F) * env_pts(n, [(0, 0.5), (0.3, 0), (1.3, 0), (1.8, 1)])
        y *= env_pts(n, [(0, 0), (0.22, 1), (1.1, 0.9), (1.8, 0)])
        y = monster_post(y, 2.2, 7.0, 4200) * env_pts(n, [(0, 0), (0.12, 1), (1.3, 1), (1.8, 0)])
        return reverb(y, 0.35, 0.10, 3500, seed=5), dur
    if idx == 2:      # ---- rasping growl "rrraaargh"
        dur = 1.4
        n = n_of(dur)
        f0 = env_log(n, [(0, 84), (0.15, 112), (0.9, 98), (1.4, 68)])
        src, ph = glottal(f0, r, jitter=0.06, shimmer=0.3, sub=0.65, tilt=1500)
        wander = lp1(white(r, n), 6.0)
        fr = np.clip(31.0 * (1 + 0.15 * wander / np.std(wander)), 22, 44)
        am = 0.35 + 0.65 * np.abs(np.sin(np.pi * np.cumsum(fr) / SR)) ** 0.6
        rasp = bp(white(r, n), 1500, 5200) * am ** 2 * 0.35
        F = vowel_path(n, [(0, "r"), (0.2, "a"), (0.8, "ae"), (1.4, "o")], 0.82)
        y = formant_bank(src * am + rasp, F, gains=(1.0, 0.8, 0.5, 0.3))
        y *= env_pts(n, [(0, 0), (0.06, 1), (0.9, 0.85), (1.4, 0)])
        y = monster_post(y, 4.5, 5.0, 5200) * env_pts(n, [(0, 0), (0.04, 1), (1.0, 1), (1.4, 0)]) ** 1.5
        return reverb(y, 0.35, 0.10, 4000, seed=5), dur
    if idx == 3:      # ---- wet gurgle
        dur = 1.6
        n = n_of(dur)
        t = tvec(n)
        rate = env_log(n, [(0, 27), (0.5, 46), (1.1, 33), (1.6, 20)])
        pulses = fry(n, rate, r, jitter=0.25)
        f0 = env_log(n, [(0, 55), (0.6, 68), (1.6, 48)])
        voiced, _ = glottal(f0, r, jitter=0.05, shimmer=0.3, sub=0.5, tilt=700)
        wob = lp1(white(r, n), 8.0)
        wob = 1 + 0.28 * wob / (np.std(wob) + 1e-9) * 0.6 + 0.18 * np.sin(2 * np.pi * 9.0 * t)
        F = vowel_path(n, [(0, "o"), (0.7, "u"), (1.2, "o"), (1.6, "u")], 0.8)
        F[0] = F[0] * wob
        F[1] = F[1] * (2 - wob)
        bub_env = lp1((r.random(n) < 14.0 / SR).astype(float) * SR / 14.0, 18.0)
        wet = bp(white(r, n), 350, 1700) * bub_env * 0.25
        y = formant_bank(pulses + 0.35 * voiced + wet, F)
        y = y / np.max(np.abs(y))
        for _ in range(16):                                   # throat bubbles
            f = r.uniform(240, 620)
            place(y, blip(f, f * r.uniform(1.5, 2.1), r.uniform(0.025, 0.055)), r.uniform(0.08, 1.45), r.uniform(0.1, 0.3))
        y *= env_pts(n, [(0, 0), (0.1, 1), (1.1, 0.9), (1.6, 0)])
        y = monster_post(y, 2.6, 6.0, 3800) * env_pts(n, [(0, 0), (0.06, 1), (1.2, 1), (1.6, 0)])
        return reverb(y, 0.35, 0.10, 3500, seed=5), dur
    # ---- idx 4: wheezing hiss (rattling inhale, long breathy exhale)
    dur = 1.7
    n = n_of(dur)
    t = tvec(n)
    nz = white(r, n)
    env_in = env_pts(n, [(0, 0), (0.12, 0.5), (0.45, 0.9), (0.55, 0), (dur, 0)])
    env_ex = env_pts(n, [(0, 0), (0.62, 0), (0.7, 1), (1.2, 0.7), (1.7, 0)])
    F = vowel_path(n, [(0, "e"), (0.5, "i"), (0.62, "uh"), (1.0, "a"), (1.7, "uh")], 0.9)
    flut_f = 24.0 + 6 * np.sin(2 * np.pi * 1.3 * t)
    flutter = 0.5 + 0.5 * np.abs(np.sin(np.pi * np.cumsum(flut_f) / SR)) ** 0.5
    src = hp(nz, 400) * (env_in * (0.6 + 0.4 * flutter) + env_ex * flutter)
    y = formant_bank(src, F, bws=(180, 220, 300, 400), gains=(0.8, 1.0, 0.8, 0.5))
    y = y / np.max(np.abs(y))
    wf = env_log(n, [(0, 1500), (0.5, 2300), (0.62, 1900), (1.7, 1250)]) * (1 + 0.03 * np.sin(2 * np.pi * 6.5 * t))
    whistle = svf(nz, wf, 28.0, "bp") * (env_in + env_ex)      # whistling windpipe
    y += 0.8 * whistle / np.max(np.abs(whistle))
    rattle = formant_bank(fry(n, env_log(n, [(0, 38), (1.7, 26)]), r, jitter=0.3), F) * (0.5 * env_in + env_ex)
    y += 0.45 * rattle / (np.max(np.abs(rattle)) + 1e-9)
    y += 0.5 * hp(nz, 4500) * env_ex * flutter * 0.2
    y = np.tanh(1.8 * hp(y, 150) / np.max(np.abs(y))) * env_pts(n, [(0, 0), (0.05, 1), (1.25, 1), (1.7, 0)])
    return reverb(y, 0.35, 0.10, 6000, seed=5), dur


def sfx_zombie_scream():
    r = rng_for("zombie_scream")
    dur = 1.2
    n = n_of(dur)
    t = tvec(n)
    f0 = env_log(n, [(0, 230), (0.07, 520), (0.3, 650), (0.7, 600), (1.0, 470), (1.2, 320)])
    f0 = f0 * (1 + 0.035 * np.sin(2 * np.pi * 11.0 * t + 2 * np.sin(2 * np.pi * 2.3 * t)))
    sub = env_pts(n, [(0, 0.7), (0.15, 0.35), (0.8, 0.5), (1.2, 0.8)])
    v1, _ = glottal(f0, r, jitter=0.04, shimmer=0.25, sub=sub, tilt=3200)
    v2, _ = glottal(f0 * 1.059, r, jitter=0.05, shimmer=0.3, sub=0.5, tilt=3200)    # dissonant second throat
    rf = 68.0 + 10 * np.sin(2 * np.pi * 3.1 * t)
    am = 0.45 + 0.55 * np.abs(np.sin(np.pi * np.cumsum(rf) / SR)) ** 0.7
    shriek = bp(white(r, n), 2400, 7800) * 0.45
    F = vowel_path(n, [(0, "a"), (0.25, "ae"), (0.6, "e"), (1.2, "a")], 1.12)
    y = formant_bank((v1 + 0.45 * v2 + shriek) * am, F, bws=(130, 160, 220, 300), gains=(0.8, 1.0, 1.0, 0.7))
    y *= env_pts(n, [(0, 0), (0.02, 1), (0.8, 0.95), (1.2, 0)])
    y = hp(y, 180)
    y = peq(y, 3000, 1.2, 5.0)
    y = np.tanh(5.0 * y / np.max(np.abs(y)))
    y = lp(y, 9000) * env_pts(n, [(0, 0), (0.012, 1), (0.85, 1), (1.2, 0)]) ** 1.5
    return reverb(y, 0.5, 0.15, 6000, seed=6), dur


def sfx_zombie_bite():
    r = rng_for("zombie_bite")
    dur = 0.5
    n = n_of(dur)
    x = np.zeros(n)
    # jaws snapping shut
    m = n_of(0.2)
    snap = np.tanh(2 * sweep(m, 210, 85, 0.02) * decay(m, 0.09)) + 0.8 * bp(white(r, m), 1500, 5500) * decay(m, 0.009)
    place(x, snap, 0.025, 1.0)
    # crunch
    x += 0.9 * crackles(r, n, 22, 0.035, 0.32, lo=(1000, 2600), hi=(4000, 9000), dec=(0.003, 0.012), power=1.2)
    place(x, wood_hit(r, n_of(0.1), 700.0, 0.6), 0.03, 0.35)       # bone-ish knock
    # wet tearing squelch
    fc = env_log(n, [(0, 600), (0.03, 700), (0.13, 1800), (0.27, 650), (0.42, 1250), (0.5, 500)])
    gurg = lp1((r.random(n) < 45.0 / SR).astype(float) * SR / 45.0, 30.0) + 0.3
    sq = svf(colored(r, n, 1.0), fc, 4.0, "bp") * gurg * env_pts(n, [(0, 0), (0.03, 0.4), (0.12, 1), (0.3, 0.7), (0.5, 0)])
    x += 1.6 * sq / np.max(np.abs(sq))
    for _ in range(7):
        f = r.uniform(350, 900)
        place(x, blip(f, f * r.uniform(1.4, 2.0), r.uniform(0.015, 0.04)), r.uniform(0.08, 0.42), r.uniform(0.15, 0.35))
    x += 0.6 * lp(white(r, n), 300) * ar_env(n, 0.03, 0.18)
    x = np.tanh(1.6 * x / np.max(np.abs(x)))
    return reverb(x, 0.2, 0.08, 5000, seed=7), dur


def sfx_human_hurt():
    r = rng_for("human_hurt")
    dur = 0.4
    n = n_of(dur)
    f0 = env_log(n, [(0, 290), (0.07, 400), (0.2, 345), (0.4, 205)])
    sub = env_pts(n, [(0, 0.35), (0.12, 0.1), (0.4, 0.3)])
    src, _ = glottal(f0, r, jitter=0.025, shimmer=0.12, sub=sub, tilt=2200)
    voiced_env = env_pts(n, [(0, 0), (0.02, 0.2), (0.05, 1), (0.2, 0.8), (0.36, 0)])
    breath_env = env_pts(n, [(0, 0.6), (0.04, 1.0), (0.1, 0.3), (0.25, 0.35), (0.4, 0.5)])
    breath = hp(white(r, n), 1000) * breath_env * 0.3
    F = vowel_path(n, [(0, "ae"), (0.12, "a"), (0.4, "uh")], 1.06)
    y = formant_bank(src * voiced_env + breath, F, gains=(1.0, 0.8, 0.45, 0.3))
    y *= env_pts(n, [(0, 0), (0.012, 1), (0.3, 1), (0.4, 0)])
    y = np.tanh(2.0 * hp(y, 120) / np.max(np.abs(y))) * env_pts(n, [(0, 0), (0.01, 1), (0.27, 1), (0.4, 0)])
    return reverb(y, 0.25, 0.08, 6000, seed=8), dur


def bell_tone(n, f, t60=0.4):
    return modal(n, f * np.array([1.0, 2.0, 3.01, 4.2, 5.43]), t60 * np.array([1.0, 0.7, 0.45, 0.3, 0.2]),
                 [1.0, 0.6, 0.35, 0.2, 0.1])


def sfx_pickup():
    r = rng_for("pickup")
    dur = 0.5
    n = n_of(dur)
    x = np.zeros(n)
    for i, (name, a) in enumerate((("A5", 0.8), ("D6", 0.9), ("F#6", 1.0))):
        t0 = 0.065 * i
        m = n - n_of(t0)
        y = bell_tone(m, N(name), 0.42) * (1 + 0.1 * np.sin(2 * np.pi * 9 * tvec(m)))
        k = n_of(0.002)
        y[:k] += 0.3 * hp(white(r, k), 4000) * np.linspace(1, 0, k)
        place(x, y, t0, a)
    place(x, modal(n, [N("A6") * 2, N("D6") * 4], [0.25, 0.2], [0.12, 0.08]), 0.13)   # sparkle on top
    return reverb(x, 0.4, 0.14, 8000, seed=9), dur


def sfx_upgrade_spawn():
    r = rng_for("upgrade_spawn")
    dur = 0.7
    n = n_of(dur)
    x = np.zeros(n)
    scale = [N(s) for s in ("D6", "E6", "F#6", "A6", "B6", "D7", "E7", "F#7", "A7")]
    for i in range(26):
        u = i / 25.0
        f = scale[int(np.clip(round(u * 8 + r.normal(0, 1.3)), 0, 8))] * r.choice([1.0, 1.0, 2.0])
        m = n_of(0.3)
        g = np.sin(2 * np.pi * f * tvec(m)) * ar_env(m, 0.006, r.uniform(0.1, 0.24))
        place(x, g, 0.02 + 0.5 * u + r.uniform(-0.02, 0.02), r.uniform(0.3, 1.0) * np.sin(np.pi * (0.1 + 0.8 * u)) ** 0.7)
    sw = svf(white(r, n), env_log(n, [(0, 1500), (0.55, 7000), (0.7, 8000)]), 3.0, "bp") * bell(n, 0.55)
    x = 1.6 * x / np.max(np.abs(x)) + 0.7 * sw / np.max(np.abs(sw))
    pad = (np.sin(2 * np.pi * N("D5") * tvec(n)) + 0.7 * np.sin(2 * np.pi * N("A5") * tvec(n))) * bell(n, 0.4)
    x += 0.22 * pad
    x = reverb(x, 0.6, 0.25, 9000, seed=9)
    return x, dur


def sfx_garlic():
    r = rng_for("garlic")
    dur = 0.8
    n = n_of(dur)
    t = tvec(n)
    # "pfffft" cloud
    puff = svf(white(r, n), env_log(n, [(0, 3800), (0.1, 1900), (0.6, 420), (0.8, 300)]), 0.9, "lp")
    puff *= ar_env(n, 0.012, 0.5)
    # flabby raspberry
    rate = env_log(n, [(0, 62), (0.18, 44), (0.5, 25), (0.8, 18)])
    rasp = lp1(pulse_train(n, rate, r, jitter=0.08, amp_jit=0.15), 900.0)
    rasp = reson(rasp, 185, 3.0) + 0.6 * reson(rasp, 430, 4.0) + 0.3 * reson(rasp, 900, 4.0)
    rasp *= env_pts(n, [(0, 0), (0.02, 1), (0.3, 0.8), (0.55, 0)])
    x = 0.9 * puff / np.max(np.abs(puff)) + 0.8 * rasp / np.max(np.abs(rasp))
    # stinky bubbles popping in the cloud
    for tb, f in ((0.22, 420), (0.33, 560), (0.41, 380), (0.5, 700), (0.57, 520), (0.64, 860), (0.7, 640)):
        f *= r.uniform(0.9, 1.1)
        place(x, blip(f, f * r.uniform(1.6, 2.2), r.uniform(0.045, 0.07)), tb + r.uniform(-0.01, 0.01), r.uniform(0.35, 0.6))
    # comic falling "whoo"
    x += 0.12 * tone(env_log(n, [(0, 950), (0.6, 300), (0.8, 260)]) * (1 + 0.03 * np.sin(2 * np.pi * 13 * t))) * bell(n, 0.25)
    x = np.tanh(1.5 * x / np.max(np.abs(x)))
    return reverb(x, 0.3, 0.08, 4000, seed=10), dur


def sfx_souvlaki():
    r = rng_for("souvlaki")
    dur = 0.9
    step = 0.062
    notes = []
    names = ["D4", "F#4", "A4", "D5", "F#5", "A5"]
    for i, nm in enumerate(names):
        notes.append((i * step, nm, step * 1.3, 0.7 + 0.05 * i, dict(ring=0.08)))
    t_end = len(names) * step
    notes.append((t_end, "D6", 0.34, 1.0, dict(trem=15.0, swell="dim", ring=0.16, jit=0.03)))
    notes.append((t_end, "D5", 0.34, 0.6, dict(ring=0.2)))
    notes.append((t_end + 0.006, "A5", 0.34, 0.5, dict(ring=0.2)))
    x = bouz_line(notes, r, tail=0.6)
    n = len(x)
    # speed sparkle rising with the run
    sp = svf(white(r, n), env_log(n, [(0, 2500), (0.4, 9000), (n / SR, 9000)]), 5.0, "bp") * ar_env(n, 0.35, 0.3)
    x = x / np.max(np.abs(x)) + 0.25 * sp / np.max(np.abs(sp))
    return reverb(x, 0.45, 0.14, 7000, seed=11), dur


def sfx_melon_throw():
    r = rng_for("melon_throw")
    dur = 0.4
    n = n_of(dur)
    t = tvec(n)
    fc = env_log(n, [(0, 320), (0.17, 1500), (0.4, 420)])
    env = bell(n, 0.45, 1.0)
    w = svf(white(r, n), fc, 2.4, "bp") * env
    air = hp(white(r, n), 3000) * env ** 2
    spin = 1 + 0.3 * np.sin(2 * np.pi * 34 * t + 4 * t * 34)       # tumbling melon
    low = svf(white(r, n), fc * 0.4, 1.5, "bp") * env
    x = (w / np.max(np.abs(w)) + 0.18 * air / np.max(np.abs(air)) + 0.5 * low / np.max(np.abs(low))) * spin
    return x, dur


def sfx_melon_splat():
    r = rng_for("melon_splat")
    dur = 0.8
    n = n_of(dur)
    x = np.zeros(n)
    thud = np.tanh(2.6 * sweep(n, 110, 46, 0.04) * decay(n, 0.28))
    rind = bp(white(r, n), 700, 3600) * decay(n, 0.03) + 0.7 * crackles(r, n, 10, 0.0, 0.07, dec=(0.003, 0.01))
    hollow = modal(n, [165, 248, 392], [0.12, 0.09, 0.06], [1, 0.6, 0.3])
    wet = svf(white(r, n), env_log(n, [(0, 5200), (0.08, 2300), (0.5, 520), (0.8, 400)]), 0.8, "lp")
    wet *= ar_env(n, 0.003, 0.55) * (0.6 + lp1(np.abs(white(r, n)), 35) * 1.2)
    sq = svf(colored(r, n, 1.0), env_log(n, [(0, 1500), (0.3, 380), (0.8, 300)]), 5.0, "bp") * ar_env(n, 0.02, 0.3)
    x += 0.5 * thud + 1.0 * rind + 0.6 * hollow + 1.5 * wet / np.max(np.abs(wet)) + 1.1 * sq / np.max(np.abs(sq))
    for _ in range(16):                         # juice drops and seeds raining down
        tb = 0.12 + 0.55 * r.random() ** 0.9
        f = r.uniform(900, 2600)
        d = blip(f, f * r.uniform(0.5, 0.75), r.uniform(0.008, 0.02))
        d += 0.8 * bp(white(r, len(d)), 1500, 6000) * np.hanning(len(d))
        place(x, d, tb, r.uniform(0.08, 0.2) * (1.1 - tb))
    x += 0.35 * crackles(r, n, 18, 0.1, 0.7, lo=(2000, 4000), hi=(6000, 10000), dec=(0.002, 0.005), power=0.9)
    # pulp sloshing and settling after the burst
    glug = lp1((r.random(n) < 30.0 / SR).astype(float), 22.0)
    slosh = bp(white(r, n), 300, 1700) * (glug / np.max(glug) + 0.25) * env_pts(n, [(0, 0), (0.1, 0.4), (0.22, 1), (0.5, 0.6), (0.8, 0)])
    x += 0.22 * slosh / np.max(np.abs(slosh))
    x = np.tanh(1.5 * x / np.max(np.abs(x)))
    return reverb(x, 0.3, 0.10, 4500, seed=12), dur


def creak(r, n, rate_pts, squeak=7.0):
    """Stick-slip hinge creak: irregular pulses ringing through wooden resonances."""
    rate = env_log(n, rate_pts)
    p = pulse_train(n, rate, r, jitter=0.12, amp_jit=0.3)
    p = lp1(p, 5000.0)
    y = np.zeros(n)
    for f, q, g in ((610, 9, 1.0), (1170, 12, 0.9), (1940, 14, 0.7), (2900, 15, 0.45)):
        y += g * reson(p, f * r.uniform(0.95, 1.05), q)
    sq = svf(p, rate * squeak, 9.0, "bp")                     # squeal that follows the hinge speed
    y = y / np.max(np.abs(y)) + 0.9 * sq / (np.max(np.abs(sq)) + 1e-9)
    return np.tanh(2.0 * y / np.max(np.abs(y)))


def sfx_hide_in():
    r = rng_for("hide_in")
    dur = 0.7
    n = n_of(dur)
    x = np.zeros(n)
    nc = n_of(0.5)
    c = creak(r, nc, [(0, 34), (0.15, 72), (0.3, 112), (0.42, 78), (0.5, 50)], squeak=8.0)
    c *= env_pts(nc, [(0, 0), (0.04, 0.7), (0.3, 1.0), (0.44, 0.5), (0.5, 0)])
    place(x, c, 0.0, 0.8)
    m = n - n_of(0.52)
    close = np.tanh(1.5 * sweep(m, 150, 72, 0.025) * decay(m, 0.11))
    close += 0.5 * modal(m, [212, 338, 525], [0.09, 0.07, 0.05], [1, 0.6, 0.35]) + 0.5 * lp(white(r, m), 900) * decay(m, 0.02)
    place(x, close, 0.52, 0.85)
    k = n_of(0.03)
    place(x, bp(white(r, k), 2000, 5500) * decay(k, 0.005), 0.545, 0.9)   # latch
    return reverb(x, 0.2, 0.08, 3500, seed=13), dur


def sfx_hide_out():
    r = rng_for("hide_out")
    dur = 0.5
    n = n_of(dur)
    x = np.zeros(n)
    nc = n_of(0.24)
    c = creak(r, nc, [(0, 55), (0.1, 105), (0.24, 170)], squeak=6.0)
    c *= env_pts(nc, [(0, 0), (0.02, 1.0), (0.16, 0.8), (0.24, 0)])
    place(x, c, 0.0, 0.8)
    rustle = bp(white(r, n), 2000, 8000) * lp1(np.abs(white(r, n)), 28.0) ** 1.5
    rustle *= env_pts(n, [(0, 0), (0.1, 0.3), (0.27, 1), (0.42, 0.3), (0.5, 0)])
    x += 0.6 * rustle / np.max(np.abs(rustle))
    m = n_of(0.15)
    place(x, modal(m, [255, 410, 660], [0.06, 0.05, 0.03], [1, 0.6, 0.3]) + 0.4 * lp(white(r, m), 1500) * decay(m, 0.012), 0.3, 0.55)
    return reverb(x, 0.2, 0.08, 4500, seed=13), dur


def sfx_heartbeat():
    """One lub-dub cycle, exactly 0.90 s; tails are wrapped so it loops seamlessly."""
    r = rng_for("heartbeat")
    dur = 0.90
    n = n_of(dur)
    assert n == 39690
    x = np.zeros(n)

    def beat(f_hi, f_lo, t60):
        m = n_of(0.5)
        e = ar_env(m, 0.008, t60)
        y = 0.8 * sweep(m, f_hi, f_lo, 0.03) * e
        y += 1.0 * sweep(m, f_hi * 2.1, f_lo * 2.0, 0.02) * ar_env(m, 0.005, t60 * 0.75)   # audible on small speakers
        y += 0.8 * sweep(m, f_hi * 3.6, f_lo * 3.1, 0.015) * ar_env(m, 0.004, t60 * 0.5)
        y += 0.6 * bp(white(r, m), 90, 380, 1) * e
        return y

    place_circ(x, beat(74, 42, 0.17), 0.02, 1.0)        # lub
    place_circ(x, beat(92, 52, 0.12), 0.30, 0.72)       # dub
    x = np.tanh(2.2 * x / np.max(np.abs(x)))
    x = lp(x, 700)
    return x, dur


def sfx_transform():
    r = rng_for("transform")
    dur = 2.0
    n = n_of(dur)
    t = tvec(n)
    mm = np.clip((t - 0.45) / 0.9, 0, 1)
    mm = mm * mm * (3 - 2 * mm)                                  # morph human -> zombie
    f0 = env_log(n, [(0, 400), (0.1, 520), (0.5, 505), (0.9, 340), (1.25, 175), (1.6, 104), (2.0, 64)])
    f0 = f0 * (1 + (0.02 + 0.03 * mm) * np.sin(2 * np.pi * (6 + 5 * mm) * t))
    src, _ = glottal(f0, r, jitter=0.015 + 0.05 * mm, shimmer=0.08 + 0.3 * mm, sub=0.1 + 0.6 * mm, tilt=2400)
    rf = 36.0 + 8 * np.sin(2 * np.pi * 1.7 * t)
    am = 1 - mm * 0.65 * (1 - np.abs(np.sin(np.pi * np.cumsum(rf) / SR)) ** 0.6)
    breath = hp(white(r, n), 1200) * (0.18 + 0.2 * mm)
    F = vowel_path(n, [(0, "a"), (0.6, "a"), (1.1, "o"), (1.6, "a"), (2.0, "u")], 1.08 - 0.3 * mm)
    y = formant_bank(src * am + breath * am, F, gains=(1.0, 0.8, 0.5, 0.3))
    y = y / np.max(np.abs(y))
    gur = formant_bank(fry(n, env_log(n, [(0, 40), (1.2, 40), (2.0, 24)]), r, jitter=0.25), F)
    y += 0.5 * gur / np.max(np.abs(gur)) * np.clip((t - 1.2) / 0.5, 0, 1)
    y *= env_pts(n, [(0, 0), (0.03, 1), (0.9, 0.9), (1.05, 0.7), (1.3, 1.0), (1.75, 0.9), (2.0, 0)])
    y = hp(y, 80)
    y = peq(y, 170, 1.0, 6.0)
    y = y / np.max(np.abs(y))
    y = (1 - mm) * 1.25 * np.tanh(3.0 * y) + mm * np.tanh(6.0 * y)
    y = lp(y, 7000) * env_pts(n, [(0, 0), (0.02, 1), (1.6, 1), (2.0, 0)]) ** 1.5
    for _ in range(8):                                           # wet throat pops near the end
        f = r.uniform(260, 600)
        place(y, blip(f, f * 1.8, r.uniform(0.03, 0.05)), r.uniform(1.35, 1.9), 0.18)
    return reverb(y, 0.45, 0.14, 5000, seed=14), dur


def sfx_tick():
    r = rng_for("tick")
    dur = 0.08
    n = n_of(dur)
    x = hp(white(r, n), 3000) * decay(n, 0.004)
    x += 0.9 * modal(n, [1850, 2930, 4480, 6100], [0.03, 0.025, 0.015, 0.01], [1, 0.7, 0.4, 0.25])
    x += 0.5 * modal(n, [640], [0.04], [1.0])
    return x, dur


def sfx_alarm():
    r = rng_for("alarm")
    dur = 2.0
    n = n_of(dur)
    t = tvec(n)
    x = np.zeros(n)
    # sub hit + impact
    x += 0.5 * np.tanh(3.0 * sweep(n, 110, N("D1"), 0.09) * decay(n, 1.5))
    x += 0.4 * np.tanh(2.0 * sweep(n, 260, N("D2"), 0.05) * decay(n, 0.9))
    x += 1.0 * lp(white(r, n), 2200) * decay(n, 0.14) + 0.7 * bp(white(r, n), 180, 1100) * decay(n, 0.5)
    # low brass/string cluster with the Hijaz semitone rub (D-Eb) and Bb
    cl = np.zeros(n)
    for nm, a in (("D2", 1.0), ("A2", 0.7), ("D3", 0.8), ("Eb3", 0.7), ("Bb3", 0.45), ("F#3", 0.3)):
        for det in (-6, 5):
            f = N(nm) * 2 ** (det / 1200.0) * (1 + 0.004 * np.sin(2 * np.pi * r.uniform(4.5, 6) * t + r.uniform(0, 6)))
            cl += a * saw_blep(f)
    fc = env_log(n, [(0, 180), (0.05, 3200), (0.5, 1300), (2.0, 240)])
    cl = svf(cl, fc, 1.3, "lp")
    cl *= env_pts(n, [(0, 0), (0.02, 1), (0.6, 0.55), (2.0, 0)]) * (1 - 0.18 * np.sin(2 * np.pi * 27 * t) ** 2)
    x += 1.5 * cl / np.max(np.abs(cl))
    # struck low piano-like string
    x += 0.5 * pluck(N("D2"), n, r, 1.0, bright=0.96, octave=True, t60=2.5) * 0.6
    # shrieking string cluster on top
    hi = np.zeros(n)
    for nm in ("D6", "Eb6", "E6", "A6"):
        hi += saw_blep(N(nm) * (1 + 0.006 * np.sin(2 * np.pi * r.uniform(5, 7) * t + r.uniform(0, 6))))
    hi = bp(hi, 1800, 6500) * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * t)) * env_pts(n, [(0, 0), (0.03, 1), (0.5, 0.5), (1.6, 0)])
    x += 0.16 * hi
    x = np.tanh(1.6 * x / np.max(np.abs(x)))
    return reverb(x, 1.4, 0.25, 4500, seed=15, predelay=0.012), dur


def sfx_listen():
    r = rng_for("listen")
    dur = 1.0
    n = n_of(dur)
    t = tvec(n)
    m = n_of(0.6)
    f = env_log(m, [(0, 345), (0.6, 300)])
    ping = (tone(f) + 0.5 * tone(f * 0.5) + 0.15 * tone(f * 2.01)) * ar_env(m, 0.03, 0.5)
    x = np.zeros(n)
    g = 1.0
    for k in range(4):                                   # sonar echoes, each one duller
        place(x, ping if k == 0 else lp(ping, 1400.0 / k), 0.05 + 0.19 * k, g)
        g *= 0.45
    wh = svf(colored(r, n, 1.0), env_log(n, [(0, 150), (0.45, 540), (1.0, 160)]), 3.0, "bp") * bell(n, 0.45)
    x += 0.9 * wh / np.max(np.abs(wh))
    x += 0.4 * np.sin(2 * np.pi * 73.4 * t) * bell(n, 0.4) * (1 + 0.3 * np.sin(2 * np.pi * 6 * t))
    return reverb(x, 0.8, 0.3, 3000, seed=16), dur


def sfx_win():
    r = rng_for("win")
    dur = 2.5
    s = 0.1                                                 # sixteenth
    L = []
    run = [("A4", 1), ("D5", 1), ("F#5", 1), ("A5", 2), ("G5", 1), ("F#5", 1), ("G5", 1), ("A5", 1)]
    third = {"G5": "B5", "F#5": "A5", "A5": "C#6"}
    t = 0.0
    for i, (nm, k) in enumerate(run):
        L.append((t, nm, k * s, 0.85, dict(ring=0.1)))
        if i >= 4:                                          # parallel thirds, bouzouki style
            L.append((t + 0.004, third[nm], k * s, 0.6, dict(ring=0.1)))
        t += k * s
    L.append((t, "D6", 1.0, 1.0, dict(trem=14.0, swell="hairpin", ring=0.35, jit=0.04)))
    L.append((t + 0.003, "F#6", 1.0, 0.75, dict(trem=14.0, swell="hairpin", ring=0.35, jit=0.04)))
    for i, nm in enumerate(("D3", "A3", "D4", "F#4", "A4")):   # final strummed chord
        L.append((t + 0.012 * i, nm, 1.2, 0.7, dict(ring=0.5, octave=i < 2)))
    L.append((0.0, "D3", 0.4, 0.8, dict(ring=0.25, octave=True)))
    L.append((0.4, "A3", 0.4, 0.7, dict(ring=0.25, octave=True)))
    x = bouz_line(L, r, tail=1.0)
    x = x / np.max(np.abs(x))
    k = n_of(0.25)
    place(x, hp(white(r, k), 6000) * ar_env(k, 0.002, 0.16) * (0.6 + 0.4 * np.sin(2 * np.pi * 45 * tvec(k))), t, 0.18)  # zill
    return reverb(x, 0.8, 0.18, 7000, seed=17), dur


def sfx_lose():
    r = rng_for("lose")
    dur = 2.5
    L = []
    seq = [("D5", 0.0, 0.27), ("C5", 0.27, 0.27), ("Bb4", 0.54, 0.3), ("A4", 0.84, 0.34),
           ("F#4", 1.18, 0.32), ("Eb4", 1.5, 0.38)]
    for nm, t, d in seq:
        L.append((t, nm, d, 0.8, dict(ring=0.18, bright=0.82)))
    L.append((1.88, "D4", 0.5, 0.75, dict(trem=9.0, swell="dim", ring=0.25, bright=0.8, jit=0.08)))
    L.append((0.0, "D3", 1.0, 0.8, dict(ring=0.5, octave=True, bright=0.85)))
    L.append((1.88, "D2", 0.6, 0.9, dict(ring=0.4, octave=True, bright=0.85)))
    x = bouz_line(L, r, tail=1.0)
    x = x / np.max(np.abs(x))
    n = len(x)
    t = tvec(n)
    pad = np.zeros(n)
    for nm, a in (("D2", 1.0), ("A2", 0.6), ("Eb3", 0.5), ("D3", 0.6)):
        for det in (-7, 6):
            pad += a * saw_blep(np.full(n, N(nm) * 2 ** (det / 1200.0)))
    pad = lp(pad, 700) * env_pts(n, [(0, 0), (0.6, 0.5), (1.9, 1.0), (2.5, 0), (n / SR, 0)])
    x += 0.4 * pad / np.max(np.abs(pad))
    m = n_of(0.6)
    place(x, np.tanh(2 * sweep(m, 150, N("D2"), 0.05) * decay(m, 0.5)) + 0.5 * lp(white(r, m), 600) * decay(m, 0.1), 1.88, 0.45)
    return reverb(x, 1.0, 0.22, 3500, seed=18), dur


def sfx_ui_click():
    r = rng_for("ui_click")
    dur = 0.06
    n = n_of(dur)
    x = sweep(n, 2300, 1500, 0.01) * decay(n, 0.028)
    x += 0.4 * bp(white(r, n), 3000, 9000) * decay(n, 0.003)
    x += 0.3 * modal(n, [3100], [0.012], [1.0])
    return x, dur


# name -> (generator, peak dBFS, fade-in s, fade-out s)
SFX = {}
for _i in range(1, 5):
    SFX[f"step_run_{_i}"] = (lambda i=_i: sfx_step_run(i), -1.0, 0.0004, 0.02)
for _i in range(1, 3):
    SFX[f"step_sneak_{_i}"] = (lambda i=_i: sfx_step_sneak(i), -8.0, 0.002, 0.03)
for _i in range(1, 4):
    SFX[f"zombie_step_{_i}"] = (lambda i=_i: sfx_zombie_step(i), -1.0, 0.005, 0.04)
for _i in range(1, 5):
    SFX[f"zombie_groan_{_i}"] = (lambda i=_i: sfx_zombie_groan(i), -1.0, 0.005, 0.08)
SFX.update({
    "glass_break": (sfx_glass_break, -1.0, 0.0003, 0.12),
    "door_break": (sfx_door_break, -1.0, 0.0004, 0.12),
    "door_bang": (sfx_door_bang, -1.0, 0.0005, 0.06),
    "zombie_scream": (sfx_zombie_scream, -1.0, 0.003, 0.08),
    "zombie_bite": (sfx_zombie_bite, -1.0, 0.002, 0.05),
    "human_hurt": (sfx_human_hurt, -1.0, 0.003, 0.04),
    "pickup": (sfx_pickup, -1.0, 0.001, 0.06),
    "upgrade_spawn": (sfx_upgrade_spawn, -5.0, 0.02, 0.1),
    "garlic": (sfx_garlic, -1.0, 0.003, 0.08),
    "souvlaki": (sfx_souvlaki, -1.0, 0.001, 0.1),
    "melon_throw": (sfx_melon_throw, -1.0, 0.01, 0.05),
    "melon_splat": (sfx_melon_splat, -1.0, 0.0005, 0.08),
    "hide_in": (sfx_hide_in, -5.0, 0.005, 0.04),
    "hide_out": (sfx_hide_out, -5.0, 0.004, 0.05),
    "heartbeat": (sfx_heartbeat, -1.0, 0.004, 0.02),
    "transform": (sfx_transform, -1.0, 0.004, 0.12),
    "tick": (sfx_tick, -6.0, 0.0003, 0.01),
    "alarm": (sfx_alarm, -1.0, 0.001, 0.3),
    "listen": (sfx_listen, -4.0, 0.03, 0.2),
    "win": (sfx_win, -1.0, 0.001, 0.3),
    "lose": (sfx_lose, -1.0, 0.001, 0.35),
    "ui_click": (sfx_ui_click, -6.0, 0.0003, 0.008),
})

# expected duration windows in seconds for verification
EXPECT = {
    "step_run": (0.15, 0.25), "step_sneak": (0.10, 0.25), "zombie_step": (0.40, 0.60),
    "glass_break": (1.40, 1.60), "door_break": (1.10, 1.30), "door_bang": (0.45, 0.55),
    "zombie_groan": (1.00, 2.00), "zombie_scream": (1.10, 1.30), "zombie_bite": (0.45, 0.55),
    "human_hurt": (0.35, 0.45), "pickup": (0.45, 0.55), "upgrade_spawn": (0.65, 0.75),
    "garlic": (0.75, 0.85), "souvlaki": (0.85, 0.95), "melon_throw": (0.35, 0.45),
    "melon_splat": (0.75, 0.85), "hide_in": (0.65, 0.75), "hide_out": (0.45, 0.55),
    "heartbeat": (0.90, 0.90), "transform": (1.90, 2.10), "tick": (0.07, 0.09),
    "alarm": (1.90, 2.10), "listen": (0.90, 1.10), "win": (2.40, 2.60), "lose": (2.40, 2.60),
    "ui_click": (0.05, 0.07), "music_ambient": (60.0, 75.0), "music_chase": (24.0, 32.0),
}


def expect_for(name):
    if name in EXPECT:
        return EXPECT[name]
    return EXPECT[name.rsplit("_", 1)[0]]


# assets that are meant to be looped: they get a standard RIFF 'smpl' loop chunk
# (whole file, forward), which Godot's WAV importer picks up with "Detect From WAV".
LOOPED_WAVS = {"heartbeat"}


def write_wav(path, x, loop=False):
    """16-bit PCM mono WAV. With loop=True a 'smpl' chunk marks the whole file as a forward loop."""
    pcm = np.round(np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(pcm)) + pcm
    if loop:
        n = len(pcm) // 2
        smpl = struct.pack("<9I", 0, 0, int(round(1e9 / SR)), 60, 0, 0, 0, 1, 0)      # header, 1 loop
        smpl += struct.pack("<6I", 0, 0, 0, n - 1, 0, 0)                               # id, forward, start, end (inclusive)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


def read_smpl_loop(path):
    """Return (start, end) of the first 'smpl' loop in a WAV file, or None."""
    with open(path, "rb") as f:
        data = f.read()
    pos = 12
    while pos + 8 <= len(data):
        cid, size = data[pos : pos + 4], struct.unpack("<I", data[pos + 4 : pos + 8])[0]
        if cid == b"smpl" and size >= 60:
            vals = struct.unpack("<15I", data[pos + 8 : pos + 68])
            return (vals[11], vals[12]) if vals[7] >= 1 else None
        pos += 8 + size + (size & 1)
    return None


def render_sfx(name):
    func, peak_db, fi, fo = SFX[name]
    x, dur = func()
    n = n_of(dur)
    x = np.asarray(x, dtype=float)
    if len(x) < n:
        x = np.concatenate([x, np.zeros(n - len(x))])
    x = x[:n]
    if not np.all(np.isfinite(x)):
        raise RuntimeError(f"{name}: non-finite samples")
    x = fade(x, fi, fo)
    x = normalize(x, peak_db)
    write_wav(os.path.join(OUT_DIR, name + ".wav"), x, loop=name in LOOPED_WAVS)
    return x


# ----------------------------------------------------------------------------
# music
# ----------------------------------------------------------------------------


def loop_freq(f, Ls):
    """Nearest frequency with a whole number of cycles in the loop."""
    return round(f * Ls) / Ls


def circ_noise(rng, L, lo, hi, order=3):
    """Band-limited noise that is periodic over L samples (filtered in the FFT domain)."""
    spec = np.fft.rfft(rng.standard_normal(L))
    f = np.fft.rfftfreq(L, 1.0 / SR)
    f[0] = 1e-6
    mag = 1.0 / np.sqrt(1.0 + (lo / f) ** (2 * order)) / np.sqrt(1.0 + (f / hi) ** (2 * order))
    x = np.fft.irfft(spec * mag, L)
    return x / (np.std(x) + 1e-12)


def circ_filter(x2, lo=None, hi=None, order=2):
    """Zero-phase circular high/low-pass on a loop buffer."""
    L = x2.shape[-1]
    f = np.fft.rfftfreq(L, 1.0 / SR)
    f[0] = 1e-6
    mag = np.ones_like(f)
    if lo:
        mag /= np.sqrt(1.0 + (lo / f) ** (2 * order))
    if hi:
        mag /= np.sqrt(1.0 + (f / hi) ** (2 * order))
    return np.fft.irfft(np.fft.rfft(x2, axis=-1) * mag, L, axis=-1)


def drone(L, rng, base, nh=10, rolloff=1.6, sub=0.5, fund=1.0):
    """Slowly breathing harmonic drone; every partial and LFO is periodic over the loop."""
    Ls = L / SR
    t = np.arange(L) / SR
    out = np.zeros((2, L))
    for h in range(1, nh + 1):
        for det in (-1, 1):
            f = loop_freq(base * h * 2 ** (det * rng.uniform(1.0, 4.0) / 1200.0), Ls)
            lfo = 0.6 + 0.4 * np.sin(2 * np.pi * rng.integers(1, 6) / Ls * t + rng.uniform(0, 2 * np.pi))
            s = lfo * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi)) / h ** rolloff * (fund if h == 1 else 1.0)
            p = rng.uniform(-0.8, 0.8) if h > 1 else 0.0
            out += pan(s, p)
    out += pan(sub * np.sin(2 * np.pi * loop_freq(base / 2, Ls) * t), 0.0)
    return out


def pad_note(freq, dur, rng, att=3.0, rel=4.0, nh=6, rolloff=1.8, det=7.0, fmax=5000.0):
    """Soft additive pad voice (3 detuned, panned layers), stereo."""
    freq = N(freq)
    n = n_of(dur + rel)
    t = tvec(n)
    env = np.ones(n)
    a = n_of(att)
    r = n_of(rel)
    env[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    env[-r:] *= np.cos(np.linspace(0, np.pi / 2, r)) ** 2
    out = np.zeros((2, n))
    for cents, p in ((-det, -0.75), (0.0, 0.0), (det, 0.75)):
        fv = freq * 2 ** (cents / 1200.0)
        vib = 1 + 0.0018 * np.sin(2 * np.pi * rng.uniform(4.0, 5.5) * t + rng.uniform(0, 6.28))
        ph = 2 * np.pi * fv * np.cumsum(vib) / SR
        for h in range(1, nh + 1):
            if fv * h > fmax:
                break
            amp = (0.7 + 0.3 * np.sin(2 * np.pi * rng.uniform(0.07, 0.3) * t + rng.uniform(0, 6.28))) / h ** rolloff
            out += pan(amp * np.sin(h * ph + rng.uniform(0, 6.28)), p)
    return out * env


def glass_tone(freq, dur, rng, att=2.0, rel=3.0):
    """Thin, slightly wavering 'wine glass' tone for eerie high textures."""
    n = n_of(dur + rel)
    t = tvec(n)
    vib = 1 + 0.003 * np.sin(2 * np.pi * rng.uniform(4.5, 6.0) * t) * np.clip(t / 2.0, 0, 1)
    ph = 2 * np.pi * freq * np.cumsum(vib) / SR
    y = np.sin(ph) + 0.12 * np.sin(2.76 * ph + 1.0) + 0.05 * np.sin(5.4 * ph)
    env = np.ones(n)
    a, r = n_of(att), n_of(rel)
    env[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    env[-r:] *= np.cos(np.linspace(0, np.pi / 2, r)) ** 2
    return y * env * (0.8 + 0.2 * np.sin(2 * np.pi * rng.uniform(0.3, 0.7) * t))


def deep_drum(rng, f=N("D2"), t60=1.6):
    """Distant, clearly musical low frame-drum hit (not confusable with door bangs)."""
    n = n_of(2.2)
    y = sweep(n, f * 1.7, f, 0.05) * ar_env(n, 0.004, t60)
    y += 0.4 * modal(n, [f * 1.59, f * 2.14, f * 2.65], [0.5, 0.35, 0.25], [1, 0.6, 0.4])
    y += 0.25 * lp(white(rng, n), 700) * decay(n, 0.06)
    return np.tanh(1.8 * y)


def soft_master(x2, pre_pct=99.9, drive=1.15, peak_db=-2.0):
    ref = np.percentile(np.abs(x2), pre_pct)
    y = np.tanh(drive * x2 / ref * 0.8)
    return y / np.max(np.abs(y)) * db(peak_db)


def music_ambient(debug=False):
    r = rng_for("music_ambient")
    Ls = 64.0
    L = n_of(Ls)
    t = np.arange(L) / SR
    buses = {}

    # --- drone on D (the tonic of D Hijaz) -------------------------------
    buses["drone"] = drone(L, r, N("D2"), nh=12, rolloff=1.25, sub=0.12, fund=0.55)

    # --- pad progression: D5 | Eb/D | Gm | Cm -> D ------------------------
    pad = np.zeros((2, L))
    prog = [
        (-2.0, 18.0, ["D3", "A3", "D4"], [1.0, 0.8, 0.6]),            # D (open fifth)
        (-2.0, 18.0, ["F#4"], [0.25]),
        (13.0, 8.0, ["Eb3", "Bb3", "Eb4", "G4"], [0.9, 0.7, 0.6, 0.4]),   # Eb over the D drone
        (20.5, 11.5, ["D3", "A3", "D4", "F#4"], [0.9, 0.7, 0.5, 0.25]),  # back to D
        (30.0, 16.5, ["G3", "Bb3", "D4", "G4"], [0.9, 0.7, 0.6, 0.4]),   # Gm
        (46.0, 8.5, ["C3", "G3", "Eb4", "C4"], [0.9, 0.7, 0.55, 0.5]),   # Cm
        (53.5, 8.5, ["D3", "A3", "F#4"], [0.9, 0.7, 0.3]),               # D (cadence, flows into the loop start)
    ]
    for t0, d, names, amps in prog:
        for nm, a in zip(names, amps):
            place_circ(pad, pad_note(nm, d, r, att=4.0, rel=4.0), t0, a)
    buses["pad"] = pad

    # --- bouzouki: sparse tremolo melody in D Hijaz -----------------------
    def tr(rate=12.5, swell="hairpin", ring=0.14):
        return dict(trem=rate * r.uniform(0.96, 1.04), swell=swell, ring=ring, bright=0.87)

    low = dict(ring=1.2, octave=True, bright=0.85)
    mel = [
        # phrase A (over D): A - Bb - A
        (3.0, "A4", 2.6, 0.62, tr(swell="cresc")), (5.6, "Bb4", 1.2, 0.72, tr(swell=None)),
        (6.8, "A4", 3.0, 0.7, tr(swell="dim", ring=0.5)),
        (12.6, "D3", 1.5, 0.55, low),
        (16.4, "Eb3", 1.5, 0.5, low),
        # phrase B (over Eb, resolving to D)
        (18.0, "G4", 1.4, 0.6, tr(swell="cresc")), (19.4, "Bb4", 1.6, 0.74, tr()),
        (21.0, "C5", 0.8, 0.7, tr(swell=None)), (21.8, "Bb4", 0.8, 0.68, tr(swell=None)),
        (22.6, "G4", 0.9, 0.64, tr(swell=None)), (23.5, "A4", 0.9, 0.66, tr(swell=None)),
        (24.4, "F#4", 3.4, 0.66, tr(swell="dim", ring=0.5)),
        (29.6, "D3", 1.5, 0.5, low),
        # phrase C (over Gm, climax)
        (34.0, "D5", 2.8, 0.74, tr(rate=13.5)), (36.8, "C5", 0.9, 0.7, tr(swell=None)),
        (37.7, "Bb4", 1.3, 0.72, tr(swell=None)), (39.0, "A4", 1.0, 0.68, tr(swell=None)),
        (40.0, "Bb4", 0.6, 0.66, tr(swell=None)), (40.6, "A4", 0.6, 0.64, tr(swell=None)),
        (41.2, "G4", 2.8, 0.64, tr(swell="dim", ring=0.5)),
        (45.6, "G3", 1.5, 0.5, low),
        # phrase D (over Cm, Hijaz cadence Eb -> D)
        (50.0, "C5", 1.2, 0.64, tr(swell=None)), (51.2, "Bb4", 0.6, 0.62, tr(swell=None)),
        (51.8, "G4", 0.6, 0.62, tr(swell=None)), (52.4, "Eb4", 3.2, 0.72, tr(ring=0.4)),
        (57.0, "D4", 3.8, 0.66, tr(rate=11.5, swell="dim", ring=0.7)),
        (57.0, "D3", 1.5, 0.5, dict(ring=1.4, octave=True, bright=0.85)),
        (61.6, "A4", 0.7, 0.32, dict(ring=0.9, bright=0.8)), (62.4, "D5", 0.7, 0.28, dict(ring=0.9, bright=0.8)),
    ]
    line = bouz_line(mel, r, tail=5.0)
    bz = np.zeros((2, L))
    place_circ(bz, pan(line, -0.2), 0.0)
    place_circ(bz, pan(line, 0.5), 0.31, 0.22)        # faint slap echo across the room
    buses["bouzouki"] = bz

    # reversed tremolo swells creeping into phrases C and D
    tex = np.zeros((2, L))
    for t_end, nm, p in ((34.0, "D5", 0.6), (50.0, "C5", -0.6), (3.0, "A4", 0.4)):
        sw = bouz_body(bouz_note(nm, 1.6, r, vel=0.7, trem=13.0, swell="dim", ring=0.5))
        sw = reverb(sw, 2.5, 0.9, 5000, seed=31)[: n_of(4.0)]
        sw = fade(sw[::-1].copy(), 1.5, 0.03)
        place_circ(tex, pan(sw, p), t_end - len(sw) / SR, 0.5)

    # eerie glass tones (semitone rubs)
    for t0, names, d, p, a in ((8.5, ("A5", "Bb5"), 3.0, -0.5, 1.0), (26.5, ("Eb6",), 3.5, 0.6, 0.8),
                               (43.5, ("D6", "Eb6"), 3.0, 0.3, 0.7), (47.5, ("C6",), 3.0, -0.6, 0.7),
                               (59.5, ("A5",), 2.5, 0.5, 0.7)):
        for i, nm in enumerate(names):
            place_circ(tex, pan(glass_tone(N(nm), d, r), p * (1 if i == 0 else -1)), t0 + 0.4 * i, 0.16 * a)

    # distant bowed-metal groans: very narrow noise bands
    for t0, f, p in ((14.5, 233.0, -0.7), (31.0, 392.0, 0.7), (48.5, 311.0, -0.4), (22.0, 622.0, 0.5)):
        n = n_of(6.0)
        g = reson(white(r, n), f, 70.0) + 0.5 * reson(white(r, n), f * 1.506, 90.0)
        g *= bell(n, 0.35, 1.0)
        place_circ(tex, pan(g / np.max(np.abs(g)), p), t0, 0.2)
    buses["texture"] = tex

    # wind (periodic noise bands with gusting LFOs)
    wind = np.zeros((2, L))
    for c in range(2):
        g1 = (0.5 + 0.5 * np.sin(2 * np.pi * 3 / Ls * t + 1.0 + c * 0.7)) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 / Ls * t + 2.0)) ** 2
        g2 = (0.5 + 0.5 * np.sin(2 * np.pi * 5 / Ls * t + 4.0 + c * 0.9)) ** 2
        wind[c] = circ_noise(r, L, 280, 650) * (0.25 + g1) + 0.5 * circ_noise(r, L, 900, 1700) * g2 \
            + 0.12 * circ_noise(r, L, 3000, 7000) * g1 * g2
    buses["wind"] = wind

    # distant low drum, far away in the building
    drum = np.zeros((2, L))
    for t0, a in ((1.0, 0.8), (15.9, 0.7), (16.55, 0.4), (32.0, 0.9), (47.9, 0.6), (48.5, 0.75), (56.95, 0.55)):
        place_circ(drum, pan(deep_drum(r), r.uniform(-0.3, 0.3)), t0, a)
    buses["drum"] = drum

    gains = {"drone": 0.17, "pad": 0.10, "bouzouki": 0.5, "texture": 0.6, "wind": 0.07, "drum": 0.34}
    sends = {"drone": 0.08, "pad": 0.35, "bouzouki": 0.55, "texture": 0.9, "wind": 0.2, "drum": 0.7}
    dry = np.zeros((2, L))
    send = np.zeros((2, L))
    for k, b in buses.items():
        if debug:
            print(f"    bus {k:9s} rms {20 * np.log10(np.std(b) * gains[k] + 1e-12):6.1f} dB")
        dry += gains[k] * b
        send += gains[k] * sends[k] * b
    mix = dry + 1.0 * circ_reverb(send, 3.4, 4200.0, seed=40, predelay=0.03)
    mix = circ_filter(mix, lo=28.0)
    return soft_master(mix, drive=1.1, peak_db=-2.5)


# percussion for the chase loop ------------------------------------------------

def _soft_on(y, ms=0.6):
    k = n_of(ms / 1000.0)
    y[:k] *= np.linspace(0.0, 1.0, k)
    return y


def perc_dum(rng, vel=1.0):
    n = n_of(0.4)
    y = sweep(n, 155, 66, 0.025) * decay(n, 0.3)
    y += 0.5 * modal(n, [108, 163, 221], [0.16, 0.11, 0.08], [1, 0.6, 0.4])
    y += 0.5 * lp(white(rng, n), 2500) * decay(n, 0.012)
    return _soft_on(np.tanh(2.2 * y)) * vel


def perc_tek(rng, vel=1.0, hi=1.0):
    n = n_of(0.14)
    f = np.array([820, 1340, 2210, 3150]) * hi * (1 + 0.02 * rng.standard_normal(4))
    y = modal(n, f, [0.06, 0.05, 0.035, 0.025], [1, 0.7, 0.5, 0.3])
    y += 0.8 * bp(white(rng, n), 2500, 9000) * decay(n, 0.02)
    return _soft_on(y, 0.3) * vel


def perc_shaker(rng, vel=1.0):
    n = n_of(0.07)
    return hp(white(rng, n), 5500) * ar_env(n, 0.004, 0.04) * vel


def perc_boom(rng):
    n = n_of(1.8)
    y = sweep(n, 95, 41, 0.06) * decay(n, 1.4) + 0.4 * lp(white(rng, n), 500) * decay(n, 0.2)
    y += 0.3 * bp(white(rng, n), 300, 2500) * decay(n, 0.5)
    return _soft_on(np.tanh(2.5 * y))


def bass_note(freq, dur, vel, rng):
    n = n_of(dur + 0.04)
    t = tvec(n)
    fa = np.full(n, freq)
    x = 0.5 * (saw_blep(fa * 1.004) + saw_blep(fa * 0.996))
    y = lp(x, 560) + 1.1 * vel * lp(x, 1800) * decay(n, 0.1) + 0.4 * np.sin(2 * np.pi * freq * t)
    env = ar_env(n, 0.004, 0.55)
    k = n_of(0.035)
    env[-k:] *= np.cos(np.linspace(0, np.pi / 2, k)) ** 2
    return np.tanh(2.2 * y * env) * vel


def music_chase(debug=False):
    r = rng_for("music_chase")
    E = 9702                     # samples per eighth note (0.22 s) -> 7/8 bar = 1.54 s
    e = E / SR
    BARS = 16
    L = E * 7 * BARS             # 24.64 s
    bar = 7 * e
    buses = {}

    roots = ["D", "D", "D", "D", "D", "D", "Eb", "D", "G", "G", "D", "D", "D", "D", "C", "Eb"]
    chords = {"D": ("D4", "A4", "D5"), "Eb": ("Eb4", "Bb4", "Eb5"), "G": ("G4", "Bb4", "D5"), "C": ("C4", "G4", "C5")}
    bass_oct = {"D": "D2", "Eb": "Eb2", "G": "G2", "C": "C2"}

    # --- percussion: 3+2+2 (dum . tek | dum tek | dum tek) -----------------
    drums = np.zeros((2, L))
    shak = np.zeros((2, L))
    for b in range(BARS):
        t0 = b * bar
        fill = b % 4 == 3
        for i in range(7):
            ti = t0 + i * e + r.normal(0, 0.0015)
            if i == 0:
                place_circ(drums, pan(perc_dum(r, 1.0), 0.0), ti)
            elif i in (3, 5):
                place_circ(drums, pan(perc_dum(r, 0.72), 0.0), ti)
            elif i == 1:
                place_circ(drums, pan(perc_tek(r, 0.3, 1.25), 0.25), ti)
            else:
                place_circ(drums, pan(perc_tek(r, 0.7 if i != 6 else 0.85), 0.2), ti)
            if fill and i >= 5:      # sixteenth roll into the next phrase
                place_circ(drums, pan(perc_tek(r, 0.5 + 0.1 * i, 1.1), 0.2), ti + e / 2)
            if b == BARS - 1 and i >= 3:
                place_circ(drums, pan(perc_tek(r, 0.35 + 0.08 * i, 1.2), -0.2), ti + e / 2)
            for h in range(2):       # sixteenth shaker
                place_circ(shak, pan(perc_shaker(r, (0.9 if i in (0, 3, 5) else 0.55) * (1.0 if h == 0 else 0.6)), -0.35),
                           t0 + (i + 0.5 * h) * e + r.normal(0, 0.002))
        if b % 4 == 0:
            place_circ(drums, pan(perc_boom(r), 0.0), t0, 0.9)
    buses["drums"] = drums
    buses["shaker"] = shak

    # --- driving bass pulse ------------------------------------------------
    bass = np.zeros(L)
    for b in range(BARS):
        f = N(bass_oct[roots[b]])
        for i in range(7):
            vel = 1.0 if i == 0 else (0.85 if i in (3, 5) else 0.55)
            ff = f * 2 if (i == 6 and b % 2 == 1) else f
            place_circ(bass, bass_note(ff, e * 0.85, vel, r), b * bar + i * e)
    buses["bass"] = pan(bass, 0.0)

    # --- lead bouzouki riff (D Hijaz, sixteenth picking, tremolo on long notes)
    riff = [
        [("D5", 1), ("Eb5", 1), ("F#5", 1), ("G5", 1), ("F#5", 1), ("Eb5", 1), ("D5", 1)],
        [("Eb5", 1), ("D5", 1), ("C5", 1), ("D5", 2), ("D5", 2)],
        [("D5", 1), ("Eb5", 1), ("F#5", 1), ("G5", 1), ("A5", 1), ("Bb5", 1), ("A5", 1)],
        [("G5", 1), ("F#5", 1), ("Eb5", 1), ("F#5", 2), ("D5", 2)],
        [("A5", 1), ("Bb5", 1), ("A5", 1), ("G5", 1), ("F#5", 1), ("G5", 1), ("A5", 1)],
        [("Bb5", 1), ("A5", 1), ("G5", 1), ("F#5", 2), ("Eb5", 1), ("D5", 1)],
        [("Eb5", 1), ("G5", 1), ("Bb5", 1), ("G5", 1), ("Eb5", 1), ("G5", 1), ("Bb5", 1)],
        [("A5", 1), ("G5", 1), ("F#5", 1), ("Eb5", 2), ("D5", 2)],
        [("D6", 1), ("C6", 1), ("Bb5", 1), ("D6", 1), ("C6", 1), ("Bb5", 1), ("A5", 1)],
        [("Bb5", 1), ("A5", 1), ("G5", 1), ("Bb5", 2), ("A5", 1), ("G5", 1)],
        [("F#5", 1), ("G5", 1), ("A5", 1), ("Bb5", 1), ("A5", 1), ("G5", 1), ("F#5", 1)],
        [("Eb5", 1), ("F#5", 1), ("Eb5", 1), ("D5", 2), ("D5", 2)],
        [("D6", 1), ("Eb6", 1), ("D6", 1), ("C6", 1), ("Bb5", 1), ("C6", 1), ("D6", 1)],
        [("Eb6", 1), ("D6", 1), ("C6", 1), ("Bb5", 1), ("A5", 1), ("G5", 1), ("F#5", 1)],
        [("G5", 1), ("Eb5", 1), ("G5", 1), ("C6", 1), ("Bb5", 1), ("G5", 1), ("Eb5", 1)],
        [("Eb5", 1), ("G5", 1), ("Bb5", 1), ("Eb6", 1), ("D6", 1), ("Bb5", 1), ("Eb5", 1)],
    ]
    lead = []
    low = []
    for b, notes in enumerate(riff):
        pos = 0
        for nm, k in notes:
            d = k * e
            if k == 1:
                strokes = np.array([0.0, e / 2 + r.normal(0, 0.003)])
            else:                                  # tremolo: sixteenth triplets (13.6 Hz)
                strokes = np.arange(3 * k) * e / 3 + np.concatenate([[0], r.normal(0, 0.003, 3 * k - 1)])
            accent = 1.0 if pos in (0, 3, 5) else 0.78
            tn = b * bar + pos * e
            lead.append((tn, nm, d * 0.97, 0.85 * accent, dict(strokes=strokes, ring=0.07, bright=0.92)))
            if b >= 8:                             # second bouzouki an octave lower joins in
                lo_nm = nm[:-1] + str(int(nm[-1]) - 1)
                low.append((tn + 0.004, lo_nm, d * 0.97, 0.7 * accent, dict(strokes=strokes, ring=0.07, bright=0.9)))
            pos += k
        assert pos == 7, (b, pos)
    bz = np.zeros((2, L))
    place_circ(bz, pan(bouz_line(lead, r, tail=1.5), -0.3), 0.0)
    place_circ(bz, pan(bouz_line(low, r, tail=1.5), 0.35), 0.0, 0.8)
    buses["lead"] = bz

    # --- off-beat chord chops (baglamas-like) -------------------------------
    chop = []
    for b in range(BARS):
        for i in (1, 2, 4, 6):
            for j, nm in enumerate(chords[roots[b]]):
                chop.append((b * bar + i * e + 0.007 * j, nm, e * 0.45, 0.6 if i != 6 else 0.75, dict(ring=0.035, bright=0.93)))
    ch = np.zeros((2, L))
    place_circ(ch, pan(bouz_line(chop, r, tail=1.0), 0.55), 0.0)
    buses["chop"] = ch

    # --- drone + tension strings --------------------------------------------
    buses["drone"] = drone(L, r, N("D2"), nh=10, rolloff=1.3, sub=0.1, fund=0.6)
    strings = np.zeros((2, L))
    trem_rate = 3.0 / e
    for b0, nb, names in ((4, 4, ("D5", "Eb5")), (8, 2, ("G5", "D6")), (10, 2, ("A5", "D6")),
                          (12, 2, ("D6", "Eb6", "A5")), (14, 2, ("Eb6", "G5", "C6"))):
        for i, nm in enumerate(names):
            y = pad_note(nm, nb * bar - 0.8, r, att=1.2, rel=0.8, nh=5, rolloff=1.2, det=9.0, fmax=7000.0)
            tt = tvec(y.shape[1])
            y *= 0.6 + 0.4 * np.abs(np.sin(np.pi * trem_rate * tt))      # bowed tremolo locked to the beat
            place_circ(strings, y, b0 * bar, 1.0 if i == 0 else 0.8)
    buses["strings"] = strings

    # --- risers into every phrase start --------------------------------------
    fx = np.zeros((2, L))
    for b in (0, 4, 8, 12):
        n = n_of(2 * bar if b == 0 else bar)
        rise = bp(white(r, n), 1500, 9000) * np.linspace(0, 1, n) ** 3
        rise = fade(rise, 0.01, 0.01)
        place_circ(fx, pan(rise, 0.0), b * bar - n / SR, 1.0 if b == 0 else 0.6)
    buses["fx"] = fx

    gains = {"drums": 0.55, "shaker": 0.30, "bass": 0.62, "lead": 0.42, "chop": 0.26, "drone": 0.10,
             "strings": 0.06, "fx": 0.2}
    sends = {"drums": 0.18, "shaker": 0.15, "bass": 0.03, "lead": 0.3, "chop": 0.3, "drone": 0.05,
             "strings": 0.5, "fx": 0.5}
    dry = np.zeros((2, L))
    send = np.zeros((2, L))
    for k, bus in buses.items():
        if debug:
            print(f"    bus {k:9s} rms {20 * np.log10(np.std(bus) * gains[k] + 1e-12):6.1f} dB")
        dry += gains[k] * bus
        send += gains[k] * sends[k] * bus
    mix = dry + 1.0 * circ_reverb(send, 1.5, 5000.0, seed=50, predelay=0.015)
    mix = circ_filter(mix, lo=30.0)
    return soft_master(mix, pre_pct=99.7, drive=1.5, peak_db=-3.0)


# name -> (generator, nominal Vorbis bitrate)
MUSIC = {"music_ambient": (music_ambient, "104k"), "music_chase": (music_chase, "96k")}


def write_ogg(path, x2, bitrate):
    """Encode a (2, L) float buffer as OGG Vorbis via ffmpeg (bit-exact flags for determinism)."""
    pcm = np.round(np.clip(x2.T, -1.0, 1.0) * 32767.0).astype("<i2")
    with tempfile.TemporaryDirectory() as td:
        tmp = os.path.join(td, "in.wav")
        with wave.open(tmp, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        cmd = [FFMPEG, "-y", "-v", "error", "-i", tmp, "-map_metadata", "-1", "-fflags", "+bitexact",
               "-flags:a", "+bitexact", "-c:a", "libvorbis", "-b:a", bitrate, "-ar", str(SR), "-ac", "2", path]
        subprocess.run(cmd, check=True)


def decode_ogg(path):
    raw = subprocess.run([FFMPEG, "-v", "error", "-i", path, "-f", "f32le", "-acodec", "pcm_f32le", "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).T.astype(float)


# ----------------------------------------------------------------------------
# verification
# ----------------------------------------------------------------------------


def loop_metrics(x, at=0):
    """Discontinuity measures for the loop wrap of x (channels, n) or (n,).
    at=0 examines the real loop point; other values examine an arbitrary inner
    position the same way (used as a reference for what 'normal' looks like)."""
    x = np.atleast_2d(x)
    if at:
        x = np.roll(x, -at, axis=1)
    d = np.abs(np.diff(x, axis=1))
    jump = float(np.max(np.abs(x[:, 0] - x[:, -1])))
    p999 = float(np.percentile(d, 99.9)) + 1e-9
    # click detector: high-passed energy right at the seam vs. the surrounding material
    w = min(8192, x.shape[1] // 2)
    seam = np.concatenate([x[:, -w:], x[:, :w]], axis=1)
    hf = signal.sosfiltfilt(signal.butter(4, 5000, "high", fs=SR, output="sos"), seam, axis=1)
    blk = 128
    e = (hf[:, : (2 * w // blk) * blk] ** 2).reshape(x.shape[0], -1, blk).mean(axis=2).mean(axis=0)
    mid = len(e) // 2
    seam_e = float(np.max(e[mid - 1 : mid + 1]))
    ref_e = float(np.percentile(e, 95)) + 1e-15
    # level continuity over 50 ms on both sides
    k = min(n_of(0.05), x.shape[1] // 4)
    r0 = np.sqrt(np.mean(x[:, :k] ** 2)) + 1e-9
    r1 = np.sqrt(np.mean(x[:, -k:] ** 2)) + 1e-9
    return {"jump": jump, "jump_vs_p999": jump / p999, "seam_hf_ratio": seam_e / ref_e,
            "level_step_db": float(abs(20 * np.log10(r0 / r1)))}


def loop_check(x):
    """Compare the loop point with three inner phrase boundaries (L/4, L/2, 3L/4).
    A musical downbeat at t=0 is fine as long as the wrap looks like the same
    downbeat elsewhere in the track. Returns (metrics, reference metrics, ok)."""
    x = np.atleast_2d(x)
    L = x.shape[1]
    lm = loop_metrics(x)
    refs = [loop_metrics(x, at=L * k // 4) for k in (1, 2, 3)]
    ref = {k: max(rm[k] for rm in refs) for k in lm}
    ok = (lm["jump_vs_p999"] <= max(1.0, 1.5 * ref["jump_vs_p999"])
          and lm["seam_hf_ratio"] <= max(4.0, 2.0 * ref["seam_hf_ratio"])
          and lm["level_step_db"] <= max(3.0, ref["level_step_db"] + 3.0))
    return lm, ref, ok


def verify(names=None, verbose=True):
    problems = []
    rows = []
    all_names = list(SFX) + list(MUSIC)
    for name in all_names:
        if names and name not in names:
            continue
        lo, hi = expect_for(name)
        is_music = name in MUSIC
        path = os.path.join(OUT_DIR, name + (".ogg" if is_music else ".wav"))

        def bad(msg):
            problems.append(f"{os.path.basename(path)}: {msg}")

        if not os.path.isfile(path) or os.path.getsize(path) == 0:
            bad("missing or empty")
            continue
        if not is_music:
            with wave.open(path, "rb") as w:
                ch, sw, fr, nf = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
                pcm = np.frombuffer(w.readframes(nf), dtype="<i2")
            if (ch, sw, fr) != (1, 2, SR):
                bad(f"format {ch}ch/{sw * 8}bit/{fr}Hz, expected 1ch/16bit/{SR}Hz")
            x = pcm.astype(float) / 32768.0
            dur = nf / SR
            target_peak = SFX[name][1]
            peak_db = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
            if abs(peak_db - target_peak) > 0.3:
                bad(f"peak {peak_db:.2f} dBFS, expected {target_peak}")
            if np.any(np.abs(pcm.astype(int)) >= 32767):
                bad("clipping (full-scale samples)")
            edge = max(abs(x[0]), abs(x[-1]))
            if edge > 0.004:
                bad(f"click risk: edge sample {edge:.4f}")
            if abs(np.mean(x)) > 0.01:
                bad(f"DC offset {np.mean(x):.4f}")
            if name == "heartbeat":
                if nf != 39690:
                    bad(f"{nf} frames, expected exactly 39690 (0.90 s)")
                lm = loop_metrics(x)
                if lm["jump"] > 0.002 or lm["seam_hf_ratio"] > 4.0:
                    bad(f"loop discontinuity {lm}")
                extra = f"  loop point: jump {lm['jump']:.5f}, seam HF ratio {lm['seam_hf_ratio']:.2f}"
            else:
                extra = ""
            want_loop = (0, nf - 1) if name in LOOPED_WAVS else None
            if read_smpl_loop(path) != want_loop:
                bad(f"smpl loop chunk {read_smpl_loop(path)}, expected {want_loop}")
        else:
            info = json.loads(subprocess.run(
                [FFPROBE, "-v", "error", "-show_entries", "stream=codec_name,sample_rate,channels:format=duration,bit_rate",
                 "-of", "json", path], check=True, capture_output=True).stdout)
            st = info["streams"][0]
            if st["codec_name"] != "vorbis" or int(st["sample_rate"]) != SR or int(st["channels"]) != 2:
                bad(f"format {st}")
            kbps = float(info["format"]["bit_rate"]) / 1000.0
            if not 90.0 <= kbps <= 118.0:
                bad(f"bitrate {kbps:.0f} kbps outside ~96-112")
            x = decode_ogg(path)
            dur = x.shape[1] / SR
            peak_db = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
            if peak_db > -0.3:
                bad(f"decoded peak {peak_db:.2f} dBFS (clipping risk)")
            lm, ref, ok = loop_check(x)
            if not ok:
                bad(f"loop discontinuity {lm} (inner reference {ref})")
            extra = (f"  {kbps:.0f} kbps\n{'':24s}loop point: jump {lm['jump']:.4f} = {lm['jump_vs_p999']:.2f}x p99.9 sample step "
                     f"(inner ref {ref['jump_vs_p999']:.2f}x), seam HF ratio {lm['seam_hf_ratio']:.2f} (ref {ref['seam_hf_ratio']:.2f}), "
                     f"level step {lm['level_step_db']:.1f} dB (ref {ref['level_step_db']:.1f})")
        if not np.all(np.isfinite(x)):
            bad("NaN/Inf samples")
        rms_db = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
        if rms_db < -45.0:
            bad(f"nearly silent (RMS {rms_db:.1f} dBFS)")
        if not (lo - 1e-6 <= dur <= hi + 1e-6):
            bad(f"duration {dur:.3f} s outside [{lo}, {hi}]")
        rows.append((os.path.basename(path), dur, peak_db, rms_db, extra))
    if verbose:
        for fn, dur, pk, rms, extra in rows:
            print(f"  {fn:22s} {dur:7.3f} s  peak {pk:6.2f} dBFS  rms {rms:6.1f} dBFS{extra}")
    return problems


# ----------------------------------------------------------------------------


def main(argv):
    os.makedirs(OUT_DIR, exist_ok=True)
    args = [a for a in argv if not a.startswith("--")]
    debug = "--debug" in argv
    if "--verify" not in argv:
        for name in SFX:
            if args and name not in args:
                continue
            render_sfx(name)
            print(f"wrote {name}.wav")
        for name, (func, bitrate) in MUSIC.items():
            if args and name not in args:
                continue
            x2 = func(debug)
            if not np.all(np.isfinite(x2)):
                raise RuntimeError(f"{name}: non-finite samples")
            lm = loop_metrics(x2)
            path = os.path.join(OUT_DIR, name + ".ogg")
            write_ogg(path, x2, bitrate)
            dec = decode_ogg(path)
            if dec.shape != x2.shape:
                raise RuntimeError(f"{name}: decoded length {dec.shape[1]} != source {x2.shape[1]}")
            corr = float(np.corrcoef(dec[0], x2[0])[0, 1])
            print(f"wrote {name}.ogg  (source loop jump {lm['jump']:.5f}, seam HF ratio {lm['seam_hf_ratio']:.2f}, "
                  f"codec/source correlation {corr:.4f})")
            if corr < 0.98:
                raise RuntimeError(f"{name}: decoded audio not aligned with source (corr {corr:.3f})")
    print("verifying ...")
    problems = verify(args or None)
    if problems:
        print("PROBLEMS:")
        for p in problems:
            print("  - " + p)
        return 1
    print("all files OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""Synthesises every sound effect, ambience loop and the music for the
Hedgehog Highways prototype. No samples are used, so there are no licensing
questions. Requires numpy and ffmpeg (with libvorbis).

Usage (from the project folder):
    python3 tools/generate_sounds.py            # writes sounds/*.ogg

Each sound is a small function below; tweak and re-run to change it.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sounds")
rng = np.random.default_rng(7)


# --- Building blocks -------------------------------------------------------------

def silence(seconds):
    return np.zeros(int(seconds * RATE))


def times(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def noise(seconds):
    return rng.standard_normal(int(seconds * RATE))


def band(x, low, high, soft=0.15):
    """Band-pass via FFT with soft (log-frequency) edges."""
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    f = np.maximum(freqs, 1.0)
    gain = np.ones_like(f)
    if low > 0:
        gain *= 1 / (1 + np.exp(-(np.log(f) - np.log(low)) / soft))
    if high < RATE / 2:
        gain *= 1 / (1 + np.exp((np.log(f) - np.log(high)) / soft))
    return np.fft.irfft(spectrum * gain, len(x))


def envelope(n, attack, release, curve=3.0):
    """Linear attack, exponential-ish release over the rest of the sound."""
    a = max(1, int(attack * RATE))
    env = np.ones(n)
    env[:a] = np.linspace(0, 1, a)
    r = max(1, int(release * RATE))
    r = min(r, n - a)
    if r > 0:
        env[n - r:] *= np.linspace(1, 0, r) ** curve
    return env


def decay(n, seconds):
    return np.exp(-np.arange(n) / RATE / seconds)


def place(target, sound, at_seconds, gain=1.0, wrap=False):
    """Mixes `sound` into `target` starting at `at_seconds`. With `wrap`, the
    part past the end continues at the start (for seamless loops)."""
    start = int(at_seconds * RATE)
    end = start + len(sound)
    if end <= len(target):
        target[start:end] += sound * gain
    elif wrap:
        cut = len(target) - start
        target[start:] += sound[:cut] * gain
        rest = sound[cut:]
        target[:len(rest)] += rest * gain
    else:
        target[start:] += sound[:len(target) - start] * gain
    return target


def tone(freq_curve, partials=((1, 1.0),)):
    """Additive tone following a per-sample frequency curve."""
    phase = 2 * np.pi * np.cumsum(freq_curve) / RATE
    out = np.zeros(len(freq_curve))
    for mult, amp in partials:
        out += amp * np.sin(phase * mult)
    return out


def glide(points, seconds):
    """Piecewise-linear curve through (time_fraction, value) points."""
    t = np.linspace(0, 1, int(seconds * RATE))
    xs, ys = zip(*points)
    return np.interp(t, xs, ys)


def stft_filter(x, centre_curve, width_octaves, hop=512, size=2048):
    """Time-varying band-pass: the pass band follows `centre_curve` (Hz per sample)."""
    window = np.hanning(size)
    out = np.zeros(len(x) + size)
    norm = np.zeros(len(x) + size)
    freqs = np.fft.rfftfreq(size, 1 / RATE)
    logf = np.log2(np.maximum(freqs, 1.0))
    padded = np.concatenate([x, np.zeros(size)])
    for start in range(0, len(x), hop):
        frame = padded[start:start + size] * window
        centre = centre_curve[min(start + size // 2, len(centre_curve) - 1)]
        gain = np.exp(-0.5 * ((logf - np.log2(centre)) / width_octaves) ** 2)
        out[start:start + size] += np.fft.irfft(np.fft.rfft(frame) * gain, size) * window
        norm[start:start + size] += window ** 2
    return (out / np.maximum(norm, 1e-6))[:len(x)]


def formant_voice(f0, formants, seconds, breath=0.015):
    """Harmonic voice (cat, dog) shaped by moving formants.
    formants: list of (time_fraction, [(freq, bandwidth_octaves, gain), ...])."""
    n = int(seconds * RATE)
    f0 = np.interp(np.arange(n), np.linspace(0, n - 1, len(f0)), f0)
    phase = 2 * np.pi * np.cumsum(f0) / RATE
    frac = np.linspace(0, 1, n)
    out = np.zeros(n)
    keys = [k for k, _ in formants]
    for h in range(1, 40):
        freq = f0 * h
        if np.min(freq) > RATE / 2.2:
            break
        amp = np.zeros(n)
        for slot in range(len(formants[0][1])):
            fc = np.interp(frac, keys, [f[slot][0] for _, f in formants])
            bw = np.interp(frac, keys, [f[slot][1] for _, f in formants])
            g = np.interp(frac, keys, [f[slot][2] for _, f in formants])
            amp += g * np.exp(-0.5 * (np.log2(np.maximum(freq, 1) / fc) / bw) ** 2)
        amp *= 1.0 / h ** 0.3
        amp[freq > RATE / 2.2] = 0
        out += amp * np.sin(phase * h)
    out += breath * band(noise(seconds), 1500, 6000) * np.max(np.abs(out))
    return out


def reverb(x, seconds=1.8, mix=0.25, brightness=4000):
    n = int(seconds * RATE)
    ir = band(noise(seconds), 200, brightness) * decay(n, seconds / 5)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = np.fft.irfft(np.fft.rfft(np.concatenate([x, np.zeros(n)])) * np.fft.rfft(np.concatenate([ir, np.zeros(len(x))])), len(x) + n)
    dry = np.concatenate([x, np.zeros(n)])
    return dry * (1 - mix) + wet * mix * 3


def make_loop(x, loop_seconds):
    """Folds everything after `loop_seconds` back onto the start."""
    n = int(loop_seconds * RATE)
    out = x[:n].copy()
    tail = x[n:]
    while len(tail):
        part = tail[:n]
        out[:len(part)] += part
        tail = tail[n:]
    return out


def crossfade_loop(x, fade_seconds):
    """Seamless loop for noise beds: blends the end into the start."""
    f = int(fade_seconds * RATE)
    body = x[:-f].copy()
    ramp = np.linspace(0, 1, f)
    body[:f] = body[:f] * np.sqrt(ramp) + x[-f:] * np.sqrt(1 - ramp)
    return body


def normalise(x, peak=0.9):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def note_freq(name):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + 12 * (octave + 1) - 69) / 12)


def save(name, x, peak=0.9, quality=4):
    os.makedirs(OUT_DIR, exist_ok=True)
    data = (normalise(x, peak) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = tmp.name
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    out = os.path.join(OUT_DIR, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", str(quality), out], check=True)
    os.remove(wav_path)
    print(f"  {name}.ogg  {len(x) / RATE:.2f}s")


# --- Hedgehog ---------------------------------------------------------------------

def snuffle(variant):
    out = silence(0.6)
    t = 0.02
    for i in range(4 + variant % 3):
        length = rng.uniform(0.035, 0.06)
        burst = band(noise(length), rng.uniform(900, 1300), rng.uniform(3000, 4200)) * envelope(int(length * RATE), 0.006, length * 0.8, 2)
        place(out, burst, t, rng.uniform(0.6, 1.0))
        t += rng.uniform(0.065, 0.11)
    return out


def squeak():
    f = glide([(0, 2000), (0.35, 2900), (1, 2300)], 0.2)
    f *= 1 + 0.03 * np.sin(2 * np.pi * 32 * times(0.2))
    return tone(f, ((1, 1.0), (2, 0.15))) * envelope(len(f), 0.015, 0.08)


def huff():
    puff = band(noise(0.28), 250, 1600) * envelope(int(0.28 * RATE), 0.01, 0.24, 2.5)
    thump = tone(glide([(0, 160), (1, 90)], 0.08)) * envelope(int(0.08 * RATE), 0.003, 0.07)
    return place(puff * 0.8, thump, 0.0, 0.6)


def step(variant):
    length = 0.03 + 0.008 * variant
    return band(noise(length), 1200 + 300 * variant, 6000) * decay(int(length * RATE), 0.006)


def crunch():
    out = silence(0.42)
    t = 0.0
    for _ in range(7):
        length = rng.uniform(0.006, 0.02)
        click = band(noise(length), 1800, 9000) * decay(int(length * RATE), length / 3)
        place(out, click, t, rng.uniform(0.5, 1.0))
        t += rng.uniform(0.025, 0.06)
    body = band(noise(0.42), 400, 2500) * decay(int(0.42 * RATE), 0.08) * 0.3
    return out + body


def munch():
    out = silence(0.55)
    for i, t in enumerate((0.0, 0.17, 0.34)):
        length = 0.1
        chew = band(noise(length), 250, 1800) * envelope(int(length * RATE), 0.02, 0.07, 2)
        place(out, chew, t, 1.0 - i * 0.2)
    return out


def slurp():
    n = 0.45
    centre = glide([(0, 500), (0.6, 1800), (1, 900)], n)
    s = stft_filter(noise(n), centre, 0.35) * envelope(int(n * RATE), 0.03, 0.15)
    bleh_f = glide([(0, 420), (1, 230)], 0.35) * (1 + 0.05 * np.sin(2 * np.pi * 9 * times(0.35)))
    bleh = tone(bleh_f, ((1, 1), (2, 0.5), (3, 0.3))) * envelope(len(bleh_f), 0.02, 0.2)
    out = silence(0.9)
    place(out, s, 0.0, 0.8)
    place(out, bleh, 0.45, 0.35)
    return out


def snore():
    loop = 3.2
    inhale_c = glide([(0, 300), (1, 900)], 1.2)
    inhale = stft_filter(noise(1.2), inhale_c, 0.4) * envelope(int(1.2 * RATE), 0.6, 0.3) * 0.7
    whistle_f = glide([(0, 1100), (1, 800)], 1.1)
    whistle = (tone(whistle_f) * 0.25 + band(noise(1.1), 400, 2000) * 0.4) * envelope(int(1.1 * RATE), 0.2, 0.7)
    out = silence(loop + 1)
    place(out, inhale, 0.1)
    place(out, whistle, 1.6)
    return make_loop(out, loop)


# --- Leaves, bushes, insects -----------------------------------------------------------

def rustle(variant, length=0.6, low=2000, high=10000):
    out = silence(length)
    for _ in range(int(60 * length)):
        g = rng.uniform(0.004, 0.02)
        grain = band(noise(g), low, high) * np.hanning(int(g * RATE))
        place(out, grain, rng.uniform(0, length - g), rng.uniform(0.2, 1.0))
    return out * envelope(len(out), 0.05, length * 0.5, 1.5)


def crawl():
    loop = 2.4
    out = silence(loop)
    t = 0.0
    while t < loop:
        for _ in range(rng.integers(4, 9)):  # a burst of tiny leg ticks
            g = rng.uniform(0.002, 0.004)
            tick = band(noise(g), 3000, 9000) * np.hanning(int(g * RATE))
            place(out, tick, t, rng.uniform(0.3, 1.0), wrap=True)
            t += rng.uniform(0.02, 0.05)
        t += rng.uniform(0.15, 0.4)
    return out


def crickets():
    loop = 8.0
    out = silence(loop)
    for pitch, period, offset in ((4400, 0.62, 0.0), (4900, 0.85, 0.31), (4100, 1.1, 0.55)):
        t = offset
        while t < loop:
            for pulse in range(3):
                n = int(0.018 * RATE)
                chirp = np.sin(2 * np.pi * pitch * np.arange(n) / RATE) * np.hanning(n)
                place(out, chirp, t + pulse * 0.032, 0.5, wrap=True)
            t += period * rng.uniform(0.9, 1.1)
    return out


# --- Cat --------------------------------------------------------------------------

def meow(length=0.75, low=1.0):
    f0 = glide([(0, 480 * low), (0.3, 720 * low), (0.75, 560 * low), (1, 380 * low)], length)
    f0 *= 1 + 0.01 * np.sin(2 * np.pi * 6 * times(length))
    formants = [
        (0.0, [(350, 0.4, 1.0), (2400, 0.3, 0.7)]),   # "mi"
        (0.35, [(850, 0.4, 1.0), (1400, 0.3, 0.8)]),  # "a"
        (1.0, [(400, 0.4, 1.0), (850, 0.3, 0.5)]),    # "ow"
    ]
    v = formant_voice(f0, formants, length)
    return v * envelope(len(v), 0.05, length * 0.35, 2)


def meh():
    length = 0.4
    f0 = glide([(0, 380), (1, 300)], length)
    formants = [(0.0, [(550, 0.4, 1.0), (1800, 0.3, 0.6)]), (1.0, [(500, 0.4, 1.0), (1600, 0.3, 0.5)])]
    v = formant_voice(f0, formants, length)
    return v * envelope(len(v), 0.03, 0.25, 2)


def hiss():
    length = 0.7
    return band(noise(length), 3000, 11000) * envelope(int(length * RATE), 0.02, 0.4, 2)


def purr():
    loop = 2.0
    t = times(loop)
    pulses = (0.5 + 0.5 * np.sin(2 * np.pi * 26 * t)) ** 3
    breath = 0.6 + 0.4 * np.sin(2 * np.pi * 0.5 * t) ** 2
    body = band(noise(loop), 60, 500)
    return body * pulses * breath + 0.3 * np.sin(2 * np.pi * 52 * t) * pulses * breath


def bell():
    out = silence(0.7)
    for i in range(3):
        f = rng.uniform(3300, 4300)
        n = int(0.5 * RATE)
        partials = ((1, 1.0), (2.76, 0.5), (5.4, 0.25), (8.93, 0.12))
        ding = sum(a * np.sin(2 * np.pi * f * m * np.arange(n) / RATE) * decay(n, 0.12 / m ** 0.5) for m, a in partials)
        place(out, ding, rng.uniform(0, 0.15), rng.uniform(0.5, 1.0))
    return out


# --- Dog (the neighbour's, behind the fence) -------------------------------------------------

def woof(pitch=1.0):
    length = 0.22
    f0 = glide([(0, 260 * pitch), (0.25, 420 * pitch), (1, 220 * pitch)], length)
    f0 *= 1 + 0.04 * rng.standard_normal(len(f0)).cumsum() / np.sqrt(len(f0))
    formants = [(0.0, [(500, 0.45, 1.0), (1000, 0.35, 0.7)]), (0.3, [(700, 0.45, 1.0), (1200, 0.35, 0.8)]), (1.0, [(450, 0.45, 1.0), (900, 0.35, 0.5)])]
    v = formant_voice(f0, formants, length, breath=0.08)
    return v * envelope(len(v), 0.01, 0.12, 2)


def bark(variant):
    count = 2 if variant == 1 else 3
    out = silence(0.3 * count + 0.6)
    t = 0.0
    for i in range(count):
        place(out, woof(rng.uniform(0.9, 1.1)), t, 1.0 - i * 0.1)
        t += rng.uniform(0.26, 0.34)
    out = band(out, 120, 2600)  # It's behind the fence, a bit muffled.
    return reverb(out, 0.8, 0.1)


# --- Wind --------------------------------------------------------------------------------------

def wind_loop():
    length = 14.0
    t = times(length + 2)
    centre = 380 + 160 * np.sin(2 * np.pi * t / 7.0) + 90 * np.sin(2 * np.pi * t / 3.1)
    bed = stft_filter(noise(length + 2), centre, 0.7)
    swell = 0.7 + 0.3 * np.sin(2 * np.pi * t / 5.3) * np.sin(2 * np.pi * t / 11.0)
    return crossfade_loop(bed * swell, 2.0)


def gust():
    length = 3.5
    centre = glide([(0, 300), (0.45, 1300), (1, 400)], length)
    g = stft_filter(noise(length), centre, 0.5)
    return g * envelope(len(g), 1.2, 1.8, 1.5)


# --- Chimes -----------------------------------------------------------------------------------------

def chime(notes, spacing=0.12, ring=0.6):
    out = silence(spacing * len(notes) + ring + 0.3)
    for i, name in enumerate(notes):
        f = note_freq(name)
        n = int(ring * RATE)
        d = tone(np.full(n, f), ((1, 1.0), (2, 0.2), (3, 0.05))) * decay(n, ring / 4) * envelope(n, 0.004, 0.05)
        place(out, d, i * spacing)
    return reverb(out, 1.0, 0.2)


def poof():
    length = 0.4
    return band(noise(length), 150, 1200) * envelope(int(length * RATE), 0.01, 0.35, 2)


# --- Music ----------------------------------------------------------------------------------------------

def music():
    """A slow, warm loop: soft pad chords, a gentle bass and a kalimba-like
    melody on the C major pentatonic scale. 72 BPM, 16 bars."""
    bpm = 72
    beat = 60 / bpm
    bars = 16
    length = bars * 4 * beat
    total = length + 4.0
    out = silence(total)

    progression = [
        ["C3", "G3", "E4", "B4"],   # Cmaj7
        ["A2", "E3", "C4", "G4"],   # Am7
        ["F2", "C3", "A3", "E4"],   # Fmaj7
        ["G2", "D3", "B3", "E4"],   # G6
    ]
    # Pad: two slightly detuned voices per note, slow swell.
    for bar in range(bars):
        chord = progression[(bar // 2) % len(progression)]
        if bar % 2:
            continue
        start = bar * 4 * beat
        dur = 8 * beat + 1.0
        n = int(dur * RATE)
        env = envelope(n, 1.6, 2.0, 1.5)
        for name in chord:
            f = note_freq(name)
            for detune in (0.998, 1.002):
                voice = tone(np.full(n, f * detune), ((1, 1.0), (2, 0.25), (3, 0.08)))
                place(out, voice * env, start, 0.07)
        # Bass on beats 1 and 3.
        root = note_freq(chord[0]) / 2 if note_freq(chord[0]) > 100 else note_freq(chord[0])
        for b in (0, 2, 4, 6):
            n = int(1.6 * RATE)
            bass = tone(np.full(n, root), ((1, 1.0), (2, 0.3))) * decay(n, 0.6) * envelope(n, 0.02, 0.3)
            place(out, bass, start + b * beat, 0.12)

    # Kalimba melody: a gentle random walk on the pentatonic scale, mostly on
    # the beat, with rests. Chord tones are favoured at the start of each bar.
    scale = ["C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6"]
    melody_rng = np.random.default_rng(3)
    index = 2
    for bar in range(bars):
        chord = progression[(bar // 2) % len(progression)]
        for step in range(8):  # eighth notes
            if melody_rng.random() < (0.55 if step % 2 else 0.25):
                continue  # rest
            if step == 0:
                targets = [i for i, s in enumerate(scale) if s[:-1] in [c[:-1] for c in chord]]
                if targets:
                    index = min(targets, key=lambda i: abs(i - index))
            else:
                index = int(np.clip(index + melody_rng.choice([-2, -1, -1, 1, 1, 2]), 0, len(scale) - 1))
            f = note_freq(scale[index])
            n = int(1.8 * RATE)
            pluck = tone(np.full(n, f), ((1, 1.0), (2.0, 0.18), (4.1, 0.06))) * decay(n, 0.45) * envelope(n, 0.003, 0.2)
            place(out, pluck, bar * 4 * beat + step * beat / 2, 0.16 * melody_rng.uniform(0.7, 1.0))

    out = reverb(out, 2.5, 0.35, 3500)
    return make_loop(out, length)


# --- Main --------------------------------------------------------------------------------------------

def main():
    print("Generating sounds into", os.path.normpath(OUT_DIR))
    for i in range(1, 4):
        save(f"snuffle_{i}", snuffle(i), 0.5)
        save(f"step_{i}", step(i), 0.4)
        save(f"rustle_{i}", rustle(i), 0.7)
    save("squeak", squeak(), 0.6)
    save("huff", huff(), 0.6)
    save("crunch", crunch(), 0.8)
    save("munch", munch(), 0.7)
    save("slurp", slurp(), 0.7)
    save("snore", snore(), 0.4)
    save("bush", rustle(0, 0.7, 700, 5000), 0.7)
    save("crawl", crawl(), 0.5)
    save("crickets", crickets(), 0.35)
    save("meow", meow(), 0.7)
    save("meow_sleepy", meow(1.0, 0.8), 0.5)
    save("meh", meh(), 0.6)
    save("hiss", hiss(), 0.6)
    save("purr", purr(), 0.5)
    save("bell", bell(), 0.5)
    save("bark_1", bark(1), 0.8)
    save("bark_2", bark(2), 0.8)
    save("wind", wind_loop(), 0.7)
    save("gust", gust(), 0.8)
    save("chime_checkpoint", chime(["C6", "E6", "G6"]), 0.5)
    save("chime_fact", chime(["G6", "D7"], 0.08, 0.5), 0.4)
    save("chime_step", chime(["E6", "A6"], 0.1, 0.5), 0.4)
    save("star", chime(["C6"], 0.1, 1.0), 0.5)
    save("poof", poof(), 0.6)
    save("music", music(), 0.8, quality=5)


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Generates the game's placeholder audio (SFX, music, ocean ambience) as
16-bit mono PCM WAV files, using only the Python standard library (no
numpy) so it can be re-run without extra dependencies. SFX are short
square/triangle-wave blips; the music is polyphonic (sustained pad chords
+ bass + lead layered together) using a softer sine/triangle blend and a
light echo, for a smoother, more modern sound than plain chiptune square
waves.

Usage: python3 tools/generate_audio.py
Writes into assets/audio/ next to this script's parent directory.
"""

import math
import random
import struct
import wave
import os

SR = 22050
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")


def midi_to_freq(m: float) -> float:
    return 440.0 * (2.0 ** ((m - 69.0) / 12.0))


def square(phase: float, duty: float = 0.5) -> float:
    return 1.0 if (phase % 1.0) < duty else -1.0


def triangle(phase: float, duty: float = 0.5) -> float:
    p = phase % 1.0
    return 4.0 * abs(p - 0.5) - 1.0


def sine(phase: float, duty: float = 0.5) -> float:
    return math.sin(2.0 * math.pi * phase)


def soft(phase: float, duty: float = 0.5) -> float:
    """Sine/triangle blend: warmer and less buzzy than a bare square wave,
    used for the modern-style pad/lead instead of chiptune-style square."""
    return 0.6 * math.sin(2.0 * math.pi * phase) + 0.4 * triangle(phase)


def env_pluck(t: float, dur: float, attack: float = 0.008, release: float = 0.05) -> float:
    if t < attack:
        return t / attack
    tail = dur - release
    if t > tail:
        return max(0.0, (dur - t) / release)
    return 1.0


class Buffer:
    def __init__(self, seconds: float):
        self.n = int(seconds * SR)
        self.data = [0.0] * self.n

    def add_note(self, start: float, dur: float, freq_fn, wave_fn, amp: float = 0.3, duty: float = 0.5,
                 attack: float = 0.008, release: float = 0.05):
        i0 = int(start * SR)
        n = int(dur * SR)
        for i in range(n):
            idx = i0 + i
            if idx < 0 or idx >= self.n:
                continue
            t = i / SR
            freq = freq_fn(t) if callable(freq_fn) else freq_fn
            self.data[idx] += wave_fn(t * freq, duty) * amp * env_pluck(t, dur, attack, release)

    def add_sweep(self, start: float, dur: float, freq_start: float, freq_end: float, wave_fn, amp: float = 0.3):
        i0 = int(start * SR)
        n = int(dur * SR)
        phase = 0.0
        prev_t = 0.0
        for i in range(n):
            idx = i0 + i
            t = i / SR
            freq = freq_start + (freq_end - freq_start) * (t / dur)
            phase += freq * (t - prev_t if i > 0 else 1.0 / SR)
            prev_t = t
            if 0 <= idx < self.n:
                self.data[idx] += wave_fn(phase) * amp * env_pluck(t, dur, attack=0.005, release=dur * 0.35)

    def add_noise(self, start: float, dur: float, amp: float = 0.3, lp: float = 0.15, lfo_hz: float = 0.0):
        i0 = int(start * SR)
        n = int(dur * SR)
        prev = 0.0
        for i in range(n):
            idx = i0 + i
            t = i / SR
            white = random.uniform(-1.0, 1.0)
            prev = prev * (1.0 - lp) + white * lp
            level = amp
            if lfo_hz > 0.0:
                level *= 0.55 + 0.45 * math.sin(2.0 * math.pi * lfo_hz * t)
            if 0 <= idx < self.n:
                self.data[idx] += prev * level

    def write(self, path: str, normalize_peak: float = 0.9):
        peak = max((abs(x) for x in self.data), default=1.0) or 1.0
        scale = (normalize_peak / peak) if peak > normalize_peak else 1.0
        samples = [max(-1.0, min(1.0, x * scale)) for x in self.data]
        ints = [int(x * 32767.0) for x in samples]
        with wave.open(path, "w") as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(SR)
            f.writeframes(struct.pack("<%dh" % len(ints), *ints))
        print("wrote", path, "(%.2fs)" % (len(ints) / SR))


def apply_reverb(buf: "Buffer", delay_s: float = 0.09, decay: float = 0.32, taps: int = 3):
    """Simple multi-tap echo (a cheap stand-in for a real reverb) to give
    the music some depth/space instead of a dry chiptune sound."""
    delay_samples = int(delay_s * SR)
    n = len(buf.data)
    out = list(buf.data)
    for tap in range(1, taps + 1):
        d = delay_samples * tap
        if d >= n:
            break
        g = decay ** tap
        for i in range(n - d):
            out[i + d] += buf.data[i] * g
    buf.data = out


def make_eat():
    buf = Buffer(0.22)
    buf.add_note(0.00, 0.07, midi_to_freq(79), square, amp=0.35)  # G5
    buf.add_note(0.06, 0.10, midi_to_freq(84), square, amp=0.35)  # C6
    buf.write(os.path.join(OUT_DIR, "eat.wav"))


def make_caught():
    buf = Buffer(0.5)
    buf.add_sweep(0.0, 0.42, 520.0, 110.0, lambda p: square(p, 0.5), amp=0.4)
    buf.add_noise(0.0, 0.12, amp=0.15, lp=0.4)
    buf.write(os.path.join(OUT_DIR, "caught.wav"))


def make_level_up():
    buf = Buffer(0.85)
    notes = [60, 64, 67, 72, 76]  # C-E-G-C-E ascending
    t = 0.0
    step = 0.09
    for i, m in enumerate(notes):
        buf.add_note(t, step * 1.4, midi_to_freq(m + 12), square, amp=0.32)
        buf.add_note(t, step * 1.4, midi_to_freq(m), triangle, amp=0.18)
        t += step
    buf.add_note(t, 0.35, midi_to_freq(84), square, amp=0.3)
    buf.write(os.path.join(OUT_DIR, "level_up.wav"))


# Richer 7th-chord voicings (root for the bass line one octave below the
# lowest pad tone) for a smoother, more "modern" harmony than plain triads.
CHORDS = [
    {"root": 48, "tones": [60, 64, 67, 71]},   # Cmaj7
    {"root": 45, "tones": [57, 60, 64, 67]},   # Am7
    {"root": 41, "tones": [53, 57, 60, 64]},   # Fmaj7
    {"root": 43, "tones": [55, 59, 62, 65]},   # G7
]


def make_music():
    # Polyphonic: a sustained pad (all chord tones at once, not arpeggiated)
    # plus a bassline plus a lead line, layered together - a real harmonic
    # bed instead of a single monophonic voice. Soft sine/triangle blend
    # instead of square waves for a smoother, less "8-bit" tone, with a
    # light echo/reverb for space. Section A stays calm (sparse lead over
    # slow-moving pad chords); Section B speeds up (busier running lead)
    # while the pad/bass keep the same steady harmonic bed.
    a_bars = 2
    b_bars = 2
    a_chord_len = 2.4
    b_chord_len = 1.2
    total = a_bars * len(CHORDS) * a_chord_len + b_bars * len(CHORDS) * b_chord_len
    buf = Buffer(total + 0.6)

    t = 0.0
    for _bar in range(a_bars):
        for chord in CHORDS:
            for tone in chord["tones"]:
                buf.add_note(t, a_chord_len * 0.97, midi_to_freq(tone), soft, amp=0.11, attack=0.15, release=0.35)
            buf.add_note(t, a_chord_len * 0.97, midi_to_freq(chord["root"]), sine, amp=0.24, attack=0.05, release=0.2)
            lead_notes = [chord["tones"][0] + 12, chord["tones"][2] + 12]
            half = a_chord_len / 2.0
            for i, m in enumerate(lead_notes):
                buf.add_note(t + i * half, half * 0.85, midi_to_freq(m), soft, amp=0.16, attack=0.02, release=0.12)
            t += a_chord_len

    for _bar in range(b_bars):
        for chord in CHORDS:
            for tone in chord["tones"]:
                buf.add_note(t, b_chord_len * 0.97, midi_to_freq(tone), soft, amp=0.10, attack=0.06, release=0.18)
            buf.add_note(t, b_chord_len * 0.97, midi_to_freq(chord["root"]), sine, amp=0.24, attack=0.02, release=0.12)
            run = [
                chord["tones"][0], chord["tones"][2], chord["tones"][3], chord["tones"][2] + 12,
                chord["tones"][1] + 12, chord["tones"][0] + 12,
            ]
            note_len = b_chord_len / len(run)
            for i, m in enumerate(run):
                buf.add_note(t + i * note_len, note_len * 0.8, midi_to_freq(m + 12), soft, amp=0.14, attack=0.005, release=0.05)
            t += b_chord_len

    apply_reverb(buf, delay_s=0.09, decay=0.32, taps=3)
    buf.write(os.path.join(OUT_DIR, "music_loop.wav"))


def make_ocean():
    dur = 24.0
    buf = Buffer(dur)
    buf.add_noise(0.0, dur, amp=0.5, lp=0.06, lfo_hz=0.11)
    buf.add_noise(0.0, dur, amp=0.18, lp=0.25, lfo_hz=0.17)
    buf.write(os.path.join(OUT_DIR, "ocean_loop.wav"), normalize_peak=0.55)


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    random.seed(1234)
    make_eat()
    make_caught()
    make_level_up()
    make_music()
    make_ocean()

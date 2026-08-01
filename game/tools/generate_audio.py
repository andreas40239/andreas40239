#!/usr/bin/env python3
"""Generates the game's placeholder audio (SFX, music, ocean ambience) as
16-bit mono PCM WAV files, using only the Python standard library (no
numpy) so it can be re-run without extra dependencies. Chiptune-style
square/triangle wave synthesis for the 8-bit Gameboy aesthetic requested
for the vertical slice.

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

    def add_note(self, start: float, dur: float, freq_fn, wave_fn, amp: float = 0.3, duty: float = 0.5):
        i0 = int(start * SR)
        n = int(dur * SR)
        for i in range(n):
            idx = i0 + i
            if idx < 0 or idx >= self.n:
                continue
            t = i / SR
            freq = freq_fn(t) if callable(freq_fn) else freq_fn
            self.data[idx] += wave_fn(t * freq, duty) * amp * env_pluck(t, dur)

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


CHORDS = [
    {"root": 48, "arp": [72, 76, 79, 76]},   # C
    {"root": 45, "arp": [69, 72, 76, 72]},   # Am
    {"root": 53, "arp": [65, 69, 72, 69]},   # F
    {"root": 55, "arp": [67, 71, 74, 71]},   # G
]


def make_music():
    # Section A: calm, 2s per chord, arpeggio in quarter notes.
    # Section B: faster, 1s per chord, arpeggio doubled up (eighth notes).
    a_bars = 2  # repeats of the 4-chord progression
    b_bars = 2
    a_chord_len = 2.0
    b_chord_len = 1.0
    total = a_bars * len(CHORDS) * a_chord_len + b_bars * len(CHORDS) * b_chord_len
    buf = Buffer(total + 0.4)

    t = 0.0
    for _bar in range(a_bars):
        for chord in CHORDS:
            note_len = a_chord_len / len(chord["arp"])
            for i, m in enumerate(chord["arp"]):
                buf.add_note(t + i * note_len, note_len * 0.92, midi_to_freq(m), square, amp=0.22, duty=0.5)
            buf.add_note(t, a_chord_len * 0.96, midi_to_freq(chord["root"]), triangle, amp=0.22)
            t += a_chord_len

    for _bar in range(b_bars):
        for chord in CHORDS:
            arp2 = chord["arp"] + chord["arp"]
            note_len = b_chord_len / len(arp2)
            for i, m in enumerate(arp2):
                buf.add_note(t + i * note_len, note_len * 0.85, midi_to_freq(m + 12), square, amp=0.24, duty=0.35)
            half = b_chord_len / 2.0
            buf.add_note(t, half * 0.9, midi_to_freq(chord["root"]), triangle, amp=0.24)
            buf.add_note(t + half, half * 0.9, midi_to_freq(chord["root"]), triangle, amp=0.24)
            t += b_chord_len

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

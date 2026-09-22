#!/usr/bin/env python3
"""Erzeugt die drei Hintergrundstuecke fuer Nachtkatze (GDD Abschnitt 11).

Alles synthetisiert, keine Samples: das Zupfinstrument entsteht mit dem
Karplus-Strong-Verfahren, Bass und Flaechen aus einfachen Schwingungen.
Jedes Stueck ist nahtlos schleifbar - Toene, die ueber das Ende hinausklingen,
werden an den Anfang zurueckgefaltet.

Aufruf:  python3 nachtkatze/tools/musik_erzeugen.py
Ergebnis: nachtkatze/assets/musik/*.wav
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "musik")

# Halbtonabstaende zum Grundton.
def note(base_hz, semitones):
    return base_hz * (2.0 ** (semitones / 12.0))


def add(buffer, start, samples, gain=1.0):
    """Mischt Samples ab start dazu; alles hinter dem Ende wandert nach vorn."""
    total = len(buffer)
    for i, value in enumerate(samples):
        buffer[(start + i) % total] += value * gain


def pluck(freq, duration, decay=0.996, brightness=0.5):
    """Karplus-Strong: gezupfte Saite."""
    length = max(2, int(RATE / freq))
    rng = random.Random(int(freq * 1000))
    ring = [rng.uniform(-1.0, 1.0) for _ in range(length)]
    # Anschlag weicher machen
    for _ in range(int((1.0 - brightness) * 6)):
        ring = [(ring[i] + ring[(i + 1) % length]) * 0.5 for i in range(length)]
    out = []
    index = 0
    for n in range(int(duration * RATE)):
        current = ring[index]
        nxt = ring[(index + 1) % length]
        value = (current + nxt) * 0.5 * decay
        ring[index] = value
        out.append(current)
        index = (index + 1) % length
    # Ausklang, damit nichts knackt
    fade = int(0.02 * RATE)
    for i in range(min(fade, len(out))):
        out[len(out) - 1 - i] *= i / fade
    return out


def soft_bass(freq, duration):
    """Weicher Basston mit langsamem Ein- und Ausschwingen."""
    out = []
    count = int(duration * RATE)
    for n in range(count):
        t = n / RATE
        envelope = min(1.0, t * 8.0) * math.exp(-t * 1.6)
        value = math.sin(TAU * freq * t) * 0.6 + math.sin(TAU * freq * 2 * t) * 0.12
        out.append(value * envelope)
    return out


def pad(freq, duration):
    """Leise Flaeche, die den Klang zusammenhaelt."""
    out = []
    count = int(duration * RATE)
    for n in range(count):
        t = n / RATE
        envelope = min(1.0, t * 1.2) * min(1.0, (duration - t) * 1.2)
        value = (math.sin(TAU * freq * t)
                 + math.sin(TAU * freq * 1.005 * t) * 0.7
                 + math.sin(TAU * freq * 0.5 * t) * 0.4)
        out.append(value * envelope * 0.2)
    return out


def shaker(duration, seed):
    """Kurzes Rauschen als leises Schlagwerk."""
    rng = random.Random(seed)
    out = []
    count = int(duration * RATE)
    for n in range(count):
        t = n / RATE
        envelope = math.exp(-t * 45.0)
        out.append(rng.uniform(-1.0, 1.0) * envelope * 0.25)
    return out


TAU = math.pi * 2.0


def smooth_loop(buffer, milliseconds=5.0):
    """Faehrt Anfang und Ende auf null, damit die Schleife nicht klickt.
    Fuenf Millisekunden sind kuerzer als jede hoerbare Luecke."""
    fade = int(RATE * milliseconds / 1000.0)
    total = len(buffer)
    for i in range(fade):
        weight = i / fade
        buffer[i] *= weight
        buffer[total - 1 - i] *= weight
    return buffer


def write_wave(name, buffer):
    smooth_loop(buffer)
    peak = max(abs(v) for v in buffer) or 1.0
    scale = 0.86 / peak
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        frames = bytearray()
        for value in buffer:
            sample = int(max(-1.0, min(1.0, value * scale)) * 32767)
            frames += struct.pack("<h", sample)
        handle.writeframes(bytes(frames))
    print("%-22s %5.1f s" % (name, len(buffer) / RATE))


def build(name, bpm, bars, root, scale, chords, seed, style):
    """Baut ein Stueck aus Akkordfolge, Arpeggio, Bass und Schlagwerk."""
    beat = 60.0 / bpm
    bar_length = beat * 4.0
    total = int(bar_length * bars * RATE)
    buffer = [0.0] * total
    rng = random.Random(seed)

    for bar in range(bars):
        chord = chords[bar % len(chords)]
        bar_start = int(bar * bar_length * RATE)

        # Bass auf der Eins, in ruhigen Stuecken auch auf der Drei
        add(buffer, bar_start, soft_bass(note(root, chord[0]) / 2.0, bar_length * 0.9), 0.5)
        if style != "nacht":
            add(buffer, bar_start + int(bar_length * 0.5 * RATE),
                soft_bass(note(root, chord[1]) / 2.0, bar_length * 0.45), 0.3)

        # Flaeche
        add(buffer, bar_start, pad(note(root, chord[0]), bar_length), 0.5)

        # Zupfmuster
        if style == "tag":
            pattern = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5]
            decay, gain = 0.9955, 0.5
        elif style == "daemmerung":
            pattern = [0.0, 1.0, 1.75, 2.5, 3.25]
            decay, gain = 0.9968, 0.42
        else:
            pattern = [0.0, 2.0, 3.0]
            decay, gain = 0.9975, 0.3
        for step_index, step in enumerate(pattern):
            degree = chord[(step_index + bar) % len(chord)]
            octave = 12 if (style == "tag" and step_index % 4 == 3) else 0
            frequency = note(root, degree + octave)
            add(buffer, bar_start + int(step * beat * RATE),
                pluck(frequency, bar_length * 0.9, decay, 0.6), gain)

        # Melodie in der zweiten Haelfte jeder Phrase
        if bar % 4 >= 2:
            for step in (1.5, 2.5, 3.25):
                degree = scale[rng.randrange(len(scale))] + 12
                add(buffer, bar_start + int(step * beat * RATE),
                    pluck(note(root, degree), beat * 1.4, decay, 0.75), gain * 0.8)

        # Leises Schlagwerk
        if style != "nacht":
            offsets = [0.5, 1.5, 2.5, 3.5] if style == "tag" else [1.5, 3.5]
            for step in offsets:
                add(buffer, bar_start + int(step * beat * RATE),
                    shaker(0.25, seed + bar * 7 + int(step * 10)), 0.5)

    write_wave(name, buffer)


def main():
    os.makedirs(OUT, exist_ok=True)
    # Tag: heiter, dur-nah, zuegig (GDD Abschnitt 11)
    build("gassenlied.wav", bpm=112, bars=16, root=note(220.0, 0),
          scale=[0, 2, 4, 5, 7, 9, 11],
          chords=[[0, 4, 7], [5, 9, 12], [7, 11, 14], [0, 4, 9]],
          seed=11, style="tag")
    # Daemmerung: ruhiger, griechisch gefaerbt (Phrygisch-Dur)
    build("abendwind.wav", bpm=88, bars=14, root=note(196.0, 0),
          scale=[0, 1, 4, 5, 7, 8, 10],
          chords=[[0, 4, 7], [1, 5, 8], [0, 3, 7], [8, 12, 15]],
          seed=23, style="daemmerung")
    # Nacht: zurueckhaltend, dunkel, sparsam
    build("nachtstreifen.wav", bpm=68, bars=12, root=note(174.61, 0),
          scale=[0, 2, 3, 5, 7, 8, 10],
          chords=[[0, 3, 7], [3, 7, 10], [5, 8, 12], [0, 3, 10]],
          seed=37, style="nacht")


if __name__ == "__main__":
    main()

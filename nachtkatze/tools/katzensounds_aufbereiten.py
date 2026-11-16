#!/usr/bin/env python3
"""Bereitet die frei lizenzierten Katzenaufnahmen fuer Nachtkatze auf.

Miauen, Schnurren und Fauchen sind echte Aufnahmen unter CC0 (gemeinfrei);
Quellen und Urheber stehen in assets/sfx/QUELLEN.md. Das Kampfgeraeusch ist
aus Fauchen und Miauen derselben Quellen gemischt.

Das Skript laedt nichts selbst herunter. Die Originale (Adressen siehe QUELLEN)
in einen Ordner legen und aufrufen:

    python3 nachtkatze/tools/katzensounds_aufbereiten.py <Ordner mit den Originalen>

Gebraucht wird ffmpeg zum Dekodieren. Ergebnis: assets/sfx/miau_1..3.wav,
schnurren.wav, fauchen.wav, kampf.wav (22050 Hz, mono, 16 Bit).
"""
import os
import struct
import subprocess
import sys
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")

# Dateinamen der Originale, wie sie die Quellen ausliefern.
MEW_FOOD = "cat_mewfood.wav"            # OpenGameArt, Kerzoven
SOFT_MEW = "cat_softmew.wav"            # OpenGameArt, Kerzoven
PURR = "cat_purractive_loop.wav"        # OpenGameArt, Kerzoven
MEOW = "Meow.ogg"                       # OpenGameArt, IgnasD
HISS = "Cat_hissing_-_Zabuhailo.wav"    # Wikimedia Commons, Zabuhailo
YOWL = "Maullido_de_gata_hembra_joven.ogg"   # Wikimedia Commons, George Miquilena


def decode(folder, name, rate=RATE):
    """Dekodiert eine Datei nach mono mit der gewuenschten Abtastrate."""
    path = os.path.join(folder, name)
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(rate), "-f", "s16le", "-"],
        check=True, capture_output=True).stdout
    return [v / 32768.0 for v in struct.unpack("<%dh" % (len(raw) // 2), raw)]


def cut(samples, start, end):
    return samples[int(start * RATE):int(end * RATE)]


def fade(samples, fade_in, fade_out):
    out = list(samples)
    n_in, n_out = int(fade_in * RATE), int(fade_out * RATE)
    for i in range(min(n_in, len(out))):
        out[i] *= i / n_in
    for i in range(min(n_out, len(out))):
        out[-1 - i] *= i / n_out
    return out


def normalize(samples, peak):
    top = max(abs(v) for v in samples) or 1.0
    return [v * peak / top for v in samples]


def mix(*layers):
    """Mischt (Samples, Startzeit, Pegel)-Schichten."""
    length = max(int(start * RATE) + len(samples) for samples, start, _gain in layers)
    out = [0.0] * length
    for samples, start, gain in layers:
        offset = int(start * RATE)
        for i, value in enumerate(samples):
            out[offset + i] += value * gain
    return out


def write(name, samples, peak=0.9):
    samples = normalize(samples, peak)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in samples))
    print("%-16s %5.2f s" % (name, len(samples) / RATE))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    folder = sys.argv[1]
    # Miauen bei Treffer: drei kurze Varianten
    write("miau_1.wav", fade(cut(decode(folder, MEW_FOOD), 0.48, 0.98), 0.01, 0.08), 0.9)
    write("miau_2.wav", fade(cut(decode(folder, MEOW), 0.0, 0.46), 0.005, 0.06), 0.9)
    write("miau_3.wav", fade(cut(decode(folder, SOFT_MEW), 0.36, 1.02), 0.01, 0.1), 0.9)
    # Schnurren im Ziel
    write("schnurren.wav", fade(cut(decode(folder, PURR), 0.15, 3.6), 0.2, 0.7), 0.85)
    # Fauchen als Warnung der Revierkatze
    hiss = decode(folder, HISS)
    write("fauchen.wav", fade(cut(hiss, 0.86, 2.02), 0.02, 0.18), 0.8)
    # Kampfgeraeusch: Fauchen und zwei hoeher abgespielte Schreie uebereinander.
    # (Schneller dekodiert = hoeher: 22050 Hz Daten aus einer als langsamer
    # angenommenen Quelle.)
    yowl = decode(folder, YOWL, int(RATE / 1.25))
    yowl_high = decode(folder, YOWL, int(RATE / 1.5))
    fight = mix(
        (fade(cut(hiss, 0.9, 1.6), 0.01, 0.1), 0.0, 0.8),
        (fade(cut(yowl, 0.05, 0.5), 0.01, 0.08), 0.04, 1.0),
        (fade(cut(yowl_high, 0.1, 0.42), 0.01, 0.08), 0.42, 0.8),
        (fade(cut(hiss, 1.5, 1.95), 0.01, 0.12), 0.5, 0.6))
    write("kampf.wav", fade(fight[:int(0.78 * RATE)], 0.005, 0.1), 0.9)


if __name__ == "__main__":
    main()

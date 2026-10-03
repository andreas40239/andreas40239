#!/usr/bin/env python3
"""Erzeugt alle Soundeffekte und die Musik-Schleife prozedural (keine externen Assets).

Aufruf:  python3 tools/gen_audio.py
Ergebnis: audio/sfx/*.wav und audio/music/sonnental.wav (22,05 kHz, mono, 16 bit)
Weiche, kindgerechte Klänge: Glocken, Blubbern, Pusten - keine aggressiven Trefferklänge.
"""
import os
import wave

import numpy as np

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "audio", "music")
rng = np.random.default_rng(7)


def write(path, sig, peak=0.85):
    sig = np.asarray(sig, dtype=np.float64)
    m = np.max(np.abs(sig))
    if m > 0:
        sig = sig / m * peak
    data = (np.clip(sig, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def tt(dur):
    return np.arange(int(SR * dur)) / SR


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def tone(freq, dur, decay=6.0, harmonics=((1, 1.0), (2, 0.3), (3, 0.1)), attack=0.005):
    t = tt(dur)
    sig = sum(a * np.sin(2 * np.pi * freq * h * t) for h, a in harmonics)
    env = np.minimum(1.0, t / attack) * np.exp(-decay * t)
    return sig * env


def bell(freq, dur, decay=4.0):
    return tone(freq, dur, decay, ((1, 1.0), (2.0, 0.35), (3.01, 0.15), (4.2, 0.06)), 0.003)


def mix(dur, items):
    buf = np.zeros(int(SR * dur))
    for start, sig in items:
        s = int(SR * start)
        e = min(len(buf), s + len(sig))
        buf[s:e] += sig[: e - s]
    return buf


def lowpass(sig, k):
    return np.convolve(sig, np.ones(k) / k, mode="same")


def sweep(f0, f1, dur, decay=20.0):
    t = tt(dur)
    f = f0 + (f1 - f0) * t / dur
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * np.minimum(1, t / 0.004) * np.exp(-decay * t)


def make_sfx():
    os.makedirs(SFX_DIR, exist_ok=True)
    s = {}
    s["tap"] = tone(880, 0.09, 35) + 0.4 * tone(1320, 0.09, 45)
    s["build"] = mix(0.7, [(0, bell(midi(72), 0.5)), (0.09, bell(midi(79), 0.5)), (0.18, bell(midi(84), 0.5))])
    s["bubble"] = mix(0.16, [(0, sweep(300, 1600, 0.08, 25)), (0.05, 0.6 * sweep(500, 2200, 0.08, 30))])
    noise = rng.uniform(-1, 1, int(SR * 0.08)) * np.exp(-40 * tt(0.08))
    munch = lowpass(noise, 6)
    s["cookie"] = mix(0.2, [(0, munch), (0.09, 0.8 * munch)])
    wn = rng.uniform(-1, 1, int(SR * 0.4))
    s["wind"] = lowpass(lowpass(wn, 25), 25) * np.sin(np.pi * tt(0.4) / 0.4) ** 2
    s["friend"] = mix(0.8, [(i * 0.07, bell(midi(n), 0.6, 5)) for i, n in enumerate([72, 76, 79, 84])])
    s["arrive"] = mix(0.6, [(0, bell(midi(79), 0.4, 6)), (0.1, bell(midi(84), 0.5, 5)), (0.1, 0.4 * bell(midi(88), 0.5, 5))])
    t = tt(0.45)
    f = 330 * (1 - 0.45 * t / 0.45) + 18 * np.sin(2 * np.pi * 11 * t)
    boing = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.2 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    s["chaos"] = boing * np.minimum(1, t / 0.01) * np.exp(-4.5 * t)
    s["upgrade"] = mix(0.7, [(i * 0.05, bell(midi(n), 0.45, 6)) for i, n in enumerate([72, 74, 76, 79, 84])])
    s["sell"] = mix(0.35, [(0, bell(2093, 0.2, 12)), (0.07, bell(2637, 0.25, 10))])
    s["star"] = mix(0.6, [(0, bell(1568, 0.5, 5)), (0.02, 0.3 * bell(2349, 0.5, 6))])
    horn = ((1, 1.0), (2, 0.5), (3, 0.3), (4, 0.15), (5, 0.08))
    s["wave"] = mix(0.7, [(0, tone(midi(67), 0.3, 5, horn, 0.03)), (0.18, tone(midi(72), 0.5, 4, horn, 0.03))])
    fan = [(0.0, 72), (0.13, 76), (0.26, 79)]
    items = [(st, bell(midi(n), 0.4, 5)) for st, n in fan]
    items += [(0.42, bell(midi(84), 1.2, 2.5)), (0.42, 0.5 * bell(midi(88), 1.2, 2.5)), (0.42, 0.4 * bell(midi(79), 1.2, 2.5))]
    s["win"] = mix(1.7, items)
    s["lose"] = mix(1.3, [(0, bell(midi(67), 0.5, 4)), (0.25, bell(midi(64), 0.5, 4)), (0.5, bell(midi(60), 0.8, 3))])
    s["deny"] = mix(0.25, [(0, tone(392, 0.1, 25)), (0.1, tone(330, 0.12, 25))])
    s["need_info"] = mix(0.3, [(0, bell(midi(81), 0.25, 9))])
    for name, sig in s.items():
        write(os.path.join(SFX_DIR, name + ".wav"), sig, 0.8 if name not in ("wind", "cookie") else 0.6)
    print("SFX:", ", ".join(sorted(s)))


def make_music():
    os.makedirs(MUSIC_DIR, exist_ok=True)
    bpm = 100
    beat = 60.0 / bpm
    bar = 4 * beat
    chords = {
        "C": [48, 60, 64, 67], "Am": [45, 57, 60, 64], "F": [41, 57, 60, 65],
        "G": [43, 55, 59, 62], "Em": [40, 55, 59, 64], "Dm": [38, 57, 60, 62],
    }
    phrase_a = ["C", "Am", "F", "G", "C", "Am", "Dm", "G"]
    phrase_b = ["F", "G", "Em", "Am", "F", "G", "C", "C"]
    song = phrase_a + phrase_a + phrase_b + phrase_a + phrase_b
    length = int(len(song) * bar * SR)
    buf = np.zeros(length)

    def add(start, sig, amp):
        s = int(start * SR) % length
        n = len(sig)
        end = s + n
        if end <= length:
            buf[s:end] += amp * sig
        else:
            k = length - s
            buf[s:] += amp * sig[:k]
            buf[: n - k] += amp * sig[k:]

    penta = [60, 62, 64, 67, 69, 72, 74, 76, 79]
    motif_rng = np.random.default_rng(42)
    motifs = {}
    for key in ("a1", "a2", "b1", "b2"):
        notes = []
        pos = 0.0
        while pos < 4 * 4:  # vier Takte in Vierteln
            dur = motif_rng.choice([0.5, 1.0, 1.0, 1.5, 2.0])
            dur = min(dur, 16 - pos)
            notes.append((pos, dur, int(motif_rng.integers(0, len(penta)))))
            pos += dur
        motifs[key] = notes

    for i, name in enumerate(song):
        t0 = i * bar
        ch = chords[name]
        root = ch[0]
        # Bass (gezupft)
        for b in (0, 2):
            add(t0 + b * beat, tone(midi(root), beat * 1.8, 3.5, ((1, 1), (2, 0.25))), 0.35)
        add(t0 + 3.5 * beat, tone(midi(root + 7), beat * 0.8, 6, ((1, 1), (2, 0.2))), 0.18)
        # Pad (weich)
        t = tt(bar + 0.3)
        pad_env = np.minimum(1, t / 0.4) * np.minimum(1, np.maximum(0, (bar + 0.3 - t) / 0.4))
        pad = sum(np.sin(2 * np.pi * midi(n) * t) + 0.3 * np.sin(4 * np.pi * midi(n) * t) for n in ch[1:])
        add(t0, pad * pad_env, 0.035)
        # Holzblock auf 2 und 4, Shaker auf Achteln
        for b in (1, 3):
            add(t0 + b * beat, bell(midi(84) * 0.75, 0.08, 45), 0.12)
        for e in range(8):
            sh = lowpass(rng.uniform(-1, 1, int(SR * 0.05)), 2) * np.exp(-60 * tt(0.05))
            add(t0 + e * beat / 2, sh - lowpass(sh, 8), 0.10 if e % 2 else 0.06)
        # Melodie: Motiv pro Vier-Takt-Block
        block = i % 4
        if block == 0:
            part = "a" if name in ("C",) or i < 16 or i >= 24 and i < 32 else "b"
            key = part + ("1" if (i // 4) % 2 == 0 else "2")
            for pos, dur, idx in motifs[key]:
                start = t0 + pos * beat
                cur_chord = chords[song[min(len(song) - 1, i + int(pos // 4))]]
                note = penta[idx]
                if pos % 2 == 0:  # betonte Zaehlzeiten: Akkordton bevorzugen
                    cands = [n for n in penta if n % 12 in [c % 12 for c in cur_chord]]
                    note = min(cands, key=lambda n: abs(n - note))
                add(start, bell(midi(note), dur * beat + 0.4, 3.0), 0.22)
                add(start, bell(midi(note + 12), dur * beat + 0.2, 5.0), 0.04)

    write(os.path.join(MUSIC_DIR, "sonnental.wav"), buf, 0.75)
    print("Musik: %.1f s" % (length / SR))


if __name__ == "__main__":
    make_sfx()
    make_music()

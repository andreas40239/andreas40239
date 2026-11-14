#!/usr/bin/env python3
"""Erzeugt die Spielmusik vollständig per Klangsynthese (keine Samples).

Drei nahtlos schleifende Stücke:
  menu.ogg   – freundliches Titelthema (C-Dur, 104 BPM)
  build.ogg  – ruhige Baumusik (G-Dur, 84 BPM)
  drive.ogg  – beschwingter "Train Beat" (D-Dur, 124 BPM)
dazu der kurze Erfolgs-Jingle sfx/success.ogg.

Aufruf:  python3 tools/gen_music.py        (benötigt numpy, scipy, ffmpeg)
"""
import os
import subprocess
import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(2024)

NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def freq(name):
    """'F#5' -> Hz"""
    n = NOTE[name[0]]
    i = 1
    if name[i] == "#":
        n += 1
        i += 1
    elif name[i] == "b":
        n -= 1
        i += 1
    octave = int(name[i:])
    return 440.0 * 2 ** ((n - 9) / 12 + (octave - 4))


CHORDS = {
    "C": ["C", "E", "G"], "F": ["F", "A", "C"], "G": ["G", "B", "D"], "Am": ["A", "C", "E"],
    "Dm": ["D", "F", "A"], "Em": ["E", "G", "B"], "D": ["D", "F#", "A"], "Bm": ["B", "D", "F#"],
    "A": ["A", "C#", "E"], "D7": ["D", "F#", "C"],
}


def chord_notes(ch, low_octave):
    """Akkordtöne aufsteigend ab der angegebenen Oktave."""
    out = []
    last = -1.0
    octv = low_octave
    for n in CHORDS[ch]:
        f = freq(f"{n}{octv}")
        while f <= last:
            octv += 1
            f = freq(f"{n}{octv}")
        out.append(f)
        last = f
    return out


# ------------------------------------------------------------------ Instrumente

def env_adsr(n, a, d, s, r, sr=SR):
    a_n, d_n, r_n = int(a * sr), int(d * sr), int(r * sr)
    e = np.full(n + r_n, s, dtype=np.float64)
    if a_n > 0:
        e[:a_n] = np.linspace(0, 1, a_n)
    if d_n > 0:
        seg = e[a_n:a_n + d_n]
        seg[:] = np.linspace(1, s, d_n)[:len(seg)]
    e[n:] = s * np.linspace(1, 0, r_n) ** 2
    return e


def pluck(f, dur, vel=1.0, bright=1.0):
    """Gezupfte Saite: Obertöne klingen umso schneller ab, je höher sie sind."""
    n = int((dur + 0.9) * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    pos = 0.23
    for k in range(1, 13):
        fk = f * k * (1 + 0.00025 * k * k)
        if fk > SR * 0.45:
            break
        amp = np.sin(np.pi * k * pos) / k ** (1.25 / bright)
        dec = (2.2 + 0.55 * k * k * (f / 300.0) ** 0.5) / max(0.6, dur * 0.9 + 0.5)
        out += amp * np.exp(-dec * t) * np.sin(2 * np.pi * fk * t + rng.uniform(0, 0.3))
    att = np.minimum(1.0, t / 0.004)
    rel = np.clip((dur + 0.9 - t) / 0.25, 0, 1)
    return out * att * rel * vel * 0.62


def glock(f, dur, vel=1.0):
    """Glockenspiel / Spieluhr."""
    n = int((dur + 1.6) * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, dec in ((1.0, 1.0, 3.2), (2.76, 0.42, 6.0), (5.4, 0.2, 11.0), (8.93, 0.07, 18.0)):
        if f * ratio < SR * 0.45:
            out += amp * np.exp(-dec * t) * np.sin(2 * np.pi * f * ratio * t)
    out *= np.minimum(1.0, t / 0.002)
    return out * vel * 0.46


def epiano(f, dur, vel=1.0):
    """Weiches E-Piano (FM-artig) für ruhige Melodien."""
    n = int((dur + 1.0) * SR)
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * f * 2.0 * t) * (1.6 * np.exp(-5.0 * t) + 0.25)
    out = np.sin(2 * np.pi * f * t + mod) * np.exp(-1.6 * t / max(0.5, dur))
    out += 0.3 * np.sin(2 * np.pi * f * 0.5 * t) * np.exp(-2.5 * t)
    att = np.minimum(1.0, t / 0.006)
    rel = np.clip((dur + 1.0 - t) / 0.3, 0, 1)
    return out * att * rel * vel * 0.42


def reed(f, dur, vel=1.0):
    """Akkordeon-/Mundharmonika-artige Stimme mit leichtem Vibrato (zwei Zungen)."""
    n = int(dur * SR)
    t = np.arange(n + int(0.12 * SR)) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.12) / 0.2, 0, 1)
    out = np.zeros(len(t))
    for det in (-0.004, 0.004):
        ph = 2 * np.pi * np.cumsum(f * (1 + det) * vib) / SR
        for k in range(1, 9):
            if f * k > SR * 0.4:
                break
            amp = (1.0 if k % 2 == 1 else 0.55) / k ** 1.15
            out += amp * np.sin(k * ph)
    e = env_adsr(n, 0.035, 0.08, 0.82, 0.12)[:len(t)]
    return out * e * vel * 0.2


def pad(f, dur, vel=1.0):
    """Warme Fläche aus leicht verstimmten Stimmen."""
    n = int(dur * SR)
    r = int(0.9 * SR)
    t = np.arange(n + r) / SR
    out = np.zeros(len(t))
    for det in (-0.006, 0.0, 0.007):
        for k in range(1, 6):
            amp = 1.0 / k ** 1.8
            out += amp * np.sin(2 * np.pi * f * (1 + det) * k * t + rng.uniform(0, 6.28))
    e = env_adsr(n, min(0.6, dur * 0.3), 0.3, 0.8, 0.9)[:len(t)]
    return out * e * vel * 0.058


def bass(f, dur, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n + int(0.08 * SR)) / SR
    out = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t) + 0.12 * np.sin(6 * np.pi * f * t)
    e = env_adsr(n, 0.008, 0.18, 0.6, 0.08)[:len(t)]
    return np.tanh(out * 1.3) * e * vel * 0.3


def kick(vel=1.0):
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    f = 46 + 95 * np.exp(-t * 32)
    out = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11)
    out += 0.25 * rng.standard_normal(n) * np.exp(-t * 180)
    return out * vel * 0.75


_bp = signal.butter(2, [1400, 7000], btype="band", fs=SR, output="sos")
_hp = signal.butter(2, 6500, btype="high", fs=SR, output="sos")


def brush(vel=1.0, length=0.11):
    """Besen auf der Snare – die Zutat für den "Train Beat"."""
    n = int(length * SR)
    t = np.arange(n) / SR
    x = signal.sosfilt(_bp, rng.standard_normal(n))
    return x * np.exp(-t * (26 / (length / 0.11))) * np.minimum(1, t / 0.002) * vel * 0.5


def shaker(vel=1.0):
    n = int(0.06 * SR)
    t = np.arange(n) / SR
    x = signal.sosfilt(_hp, rng.standard_normal(n))
    return x * np.exp(-t * 60) * vel * 0.3


def block(vel=1.0, f=880.0):
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.7 * t)) * np.exp(-t * 55) * vel * 0.3


# ------------------------------------------------------------------ Mischpult

class Mix:
    def __init__(self, bpm, bars, beats_per_bar=4):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.loop = int(round(bars * beats_per_bar * self.beat * SR))
        self.n = self.loop + int(4.0 * SR)
        self.dry = np.zeros((self.n, 2))
        self.wet = np.zeros((self.n, 2))

    def add(self, x, beat, pan=0.0, gain=1.0, send=0.25):
        i = int(round(beat * self.beat * SR))
        if i >= self.n:
            return
        x = x[:self.n - i]
        l = np.cos((pan + 1) * np.pi / 4) * gain
        r = np.sin((pan + 1) * np.pi / 4) * gain
        self.dry[i:i + len(x), 0] += x * l
        self.dry[i:i + len(x), 1] += x * r
        if send > 0:
            self.wet[i:i + len(x), 0] += x * l * send
            self.wet[i:i + len(x), 1] += x * r * send

    def render(self, reverb_time=1.7):
        # Hall: Faltung mit abklingendem Rauschen (links/rechts unterschiedlich)
        n_ir = int(reverb_time * SR)
        t = np.arange(n_ir) / SR
        out = self.dry.copy()
        lp = signal.butter(1, 5200, fs=SR, output="sos")
        for c in range(2):
            ir = rng.standard_normal(n_ir) * np.exp(-t * (6.9 / reverb_time))
            ir[:int(0.012 * SR)] *= 0.2
            ir = signal.sosfilt(lp, ir)
            ir /= np.sqrt(np.sum(ir ** 2))
            w = signal.fftconvolve(self.wet[:, c], ir)[:self.n]
            out[:, c] += w * 0.9
        # Nachklang hinter dem Schleifenende vorne wieder einblenden -> nahtlose Schleife
        tail = out[self.loop:]
        res = out[:self.loop].copy()
        res[:len(tail)] += tail
        # Summe: Rumpeln entfernen, Höhen leicht anheben (kleine Handy-Lautsprecher)
        hp = signal.butter(2, 45, btype="high", fs=SR, output="sos")
        shelf = signal.butter(1, 2800, btype="high", fs=SR, output="sos")
        for c in range(2):
            # periodisch filtern (Schleife dreimal aneinander, Mitte behalten) -> bleibt nahtlos
            y = np.concatenate([res[:, c]] * 3)
            y = signal.sosfilt(hp, y)
            y = y + 0.6 * signal.sosfilt(shelf, y)
            res[:, c] = y[self.loop:2 * self.loop]
        res = np.tanh(res * 1.15) / np.tanh(1.15)
        res *= 0.89 / np.max(np.abs(res))
        return res


def parse_melody(text):
    """'E5:1 G5:1 r:2 | ...' -> Liste (Takt, Schlag, Länge, Ton)."""
    notes = []
    for bar_i, bar in enumerate(text.strip().split("|")):
        pos = 0.0
        for tok in bar.split():
            name, ln = tok.split(":")
            ln = float(ln)
            if name != "r":
                notes.append((bar_i, pos, ln, name))
            pos += ln
        assert abs(pos - 4.0) < 1e-6, f"Takt {bar_i + 1} hat {pos} Schläge: {bar}"
    return notes


def save(name, audio, quality=5):
    path = os.path.join(ROOT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = (np.clip(audio, -1, 1) * 32767).astype("<i2").tobytes()
    ch = 1 if audio.ndim == 1 else audio.shape[1]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", str(ch), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(quality), path], input=pcm, check=True)
    print("wrote", name, f"{len(audio) / SR:.1f}s")


# ------------------------------------------------------------------ Stücke

def menu():
    A = "C C F C Am F G G"
    A2 = "C C F C Am F,G C C"
    B = "F F C C Dm G C G"
    chords = (A + " " + A2 + " " + B + " " + A2).split()
    m = Mix(104, len(chords))
    mel_a = "E5:1 G5:1 C6:1.5 G5:.5 | E5:1 G5:1 E5:2 | F5:1 A5:1 C6:1.5 A5:.5 | G5:3 r:1 |"
    mel = (mel_a + " A5:1 C6:1 E6:1.5 C6:.5 | A5:1 F5:1 A5:2 | G5:1 B5:1 D6:1 B5:1 | G5:2 D5:1 G5:1 |"
           + mel_a + " A5:1 C6:1 E6:1.5 C6:.5 | A5:1 F5:1 G5:1 B5:1 | C6:3 G5:1 | C6:2 r:2 |"
           " A5:1.5 G5:.5 F5:1 A5:1 | C6:2 A5:2 | G5:1.5 F5:.5 E5:1 G5:1 | C6:2 G5:2 |"
           " F5:1 A5:1 D6:1.5 A5:.5 | B5:1 G5:1 B5:1 D6:1 | C6:1 G5:1 E5:1 G5:1 | D5:1 G5:1 B5:1 D6:1 |"
           + mel_a + " A5:1 C6:1 E6:1.5 C6:.5 | A5:1 F5:1 G5:1 B5:1 | C6:3 G5:1 | C6:2 r:2")
    for bar, pos, ln, name in parse_melody(mel):
        b = bar * 4 + pos
        m.add(glock(freq(name), ln * m.beat, 0.9), b, 0.15, 1.0, 0.4)
        m.add(pluck(freq(name) / 2, ln * m.beat, 0.55, 1.2), b, -0.2, 1.0, 0.25)
    for bar, cell in enumerate(chords):
        parts = cell.split(",")
        for hi, ch in enumerate(parts):
            off = bar * 4 + hi * (4 / len(parts))
            span = 4 / len(parts)
            notes = chord_notes(ch, 3)
            root = freq(CHORDS[ch][0] + "2")
            for f in notes:
                m.add(pad(f, span * m.beat, 0.8), off, 0.0, 1.0, 0.5)
            # Bass: Grundton – Quinte
            m.add(bass(root, 0.9 * m.beat, 0.9), off, 0.0, 1.0, 0.05)
            if span >= 4:
                m.add(bass(root * 1.5, 0.9 * m.beat, 0.7), off + 2, 0.0, 1.0, 0.05)
                m.add(bass(root, 0.45 * m.beat, 0.6), off + 3.5, 0.0, 1.0, 0.05)
            # Zupfbegleitung in Achteln
            pat = [0, 2, 1, 2, 0, 2, 1, 2] if span >= 4 else [0, 2, 1, 2]
            hi_notes = chord_notes(ch, 4)
            for i, k in enumerate(pat):
                m.add(pluck(hi_notes[k], 0.5 * m.beat, 0.42 if i % 2 else 0.55), off + i * 0.5, 0.45 if i % 2 else -0.45, 1.0, 0.3)
        # leichte Perkussion
        for i in range(8):
            m.add(shaker(0.5 if i % 2 else 0.8), bar * 4 + i * 0.5, 0.3, 1.0, 0.1)
        m.add(kick(0.7), bar * 4, 0, 1.0, 0.02)
        m.add(kick(0.5), bar * 4 + 2, 0, 1.0, 0.02)
        m.add(block(0.6, 1320), bar * 4 + 1, -0.3, 1.0, 0.3)
        m.add(block(0.6, 990), bar * 4 + 3, -0.3, 1.0, 0.3)
    save("music/menu.ogg", m.render())


def build():
    A = "G Em C D G Em C D"
    A2 = "G Bm C D Em C D G"
    B = "C G Am D C G Am,D G"
    chords = (A + " " + A2 + " " + B).split()
    m = Mix(84, len(chords))
    mel = ("B4:1.5 D5:.5 G5:2 | F#5:1 E5:1 B4:2 | C5:1.5 E5:.5 G5:1 E5:1 | D5:3 r:1 |"
           " B4:1.5 D5:.5 G5:1 A5:1 | B5:2 G5:2 | E5:1 G5:1 E5:1 C5:1 | D5:2 A4:2 |"
           " B4:1.5 D5:.5 G5:2 | F#5:1 D5:1 B4:2 | E5:1 G5:1 C6:2 | A5:1.5 F#5:.5 D5:2 |"
           " G5:1 B5:1 E5:2 | E5:1.5 G5:.5 C5:2 | D5:1 F#5:1 A5:1 F#5:1 | G5:3 r:1 |"
           " E5:2 G5:2 | D5:2 B4:2 | C5:1 E5:1 A5:2 | F#5:2 D5:2 |"
           " E5:1 G5:1 C6:1 G5:1 | B5:2 D5:2 | C5:1 E5:1 D5:1 F#5:1 | G5:4")
    for bar, pos, ln, name in parse_melody(mel):
        m.add(epiano(freq(name), ln * m.beat, 0.9), bar * 4 + pos, 0.1, 1.0, 0.45)
    for bar, cell in enumerate(chords):
        parts = cell.split(",")
        for hi, ch in enumerate(parts):
            span = 4 / len(parts)
            off = bar * 4 + hi * span
            for f in chord_notes(ch, 3):
                m.add(pad(f, span * m.beat, 1.0), off, 0.0, 1.0, 0.6)
            root = freq(CHORDS[ch][0] + "2")
            m.add(bass(root, 1.6 * m.beat * span / 4, 0.8), off, 0.0, 1.0, 0.05)
            if span >= 4:
                m.add(bass(root * 1.5, 0.9 * m.beat, 0.55), off + 2.5, 0.0, 1.0, 0.05)
            # ruhiges Arpeggio
            notes = chord_notes(ch, 4) + [chord_notes(ch, 5)[0]]
            pat = [0, 1, 2, 3, 2, 1, 2, 1] if span >= 4 else [0, 1, 2, 3]
            for i, k in enumerate(pat):
                m.add(pluck(notes[k], 0.9 * m.beat, 0.5 if i % 4 else 0.62, 0.9), off + i * 0.5, 0.5 * np.sin(i * 1.3), 1.0, 0.35)
        if bar % 2 == 1:
            m.add(glock(chord_notes(cell.split(",")[0], 6)[0], 1.0, 0.35), bar * 4 + 3, -0.4, 1.0, 0.6)
        for i in range(4):
            m.add(shaker(0.35 if i % 2 == 0 else 0.5), bar * 4 + i + 0.5, 0.35, 1.0, 0.15)
    save("music/build.ogg", m.render(2.1))


def drive():
    A = "D D G D D Bm A A"
    A2 = "D D G D G A D D"
    B = "G G D D A A D A"
    chords = (A + " " + A2 + " " + B + " " + A2).split()
    m = Mix(124, len(chords))
    a4 = "F#5:.5 A5:.5 D6:1 A5:.5 F#5:.5 A5:1 | D6:1 B5:.5 A5:.5 F#5:2 | G5:.5 B5:.5 D6:1 B5:.5 G5:.5 B5:1 | A5:1.5 F#5:.5 D5:2 |"
    a2_end = " B5:1 D6:1 G5:1 B5:1 | C#6:1 E6:1 A5:1 C#6:1 | D6:1.5 A5:.5 F#5:1 A5:1 | D6:2 r:2 |"
    mel = (a4 + " F#5:.5 A5:.5 D6:1 E6:1 D6:1 | B5:1 D6:.5 B5:.5 F#5:2 | E5:.5 A5:.5 C#6:1 B5:.5 A5:.5 E5:1 | A5:3 r:1 |"
           + a4 + a2_end +
           " B5:1.5 A5:.5 G5:1 B5:1 | D6:2 B5:1 G5:1 | A5:1.5 G5:.5 F#5:1 A5:1 | D6:2 A5:2 |"
           " C#6:1 B5:.5 A5:.5 E5:1 A5:1 | C#6:1 E6:1 C#6:1 A5:1 | D6:1 A5:1 F#5:1 D5:1 | E5:1 A5:1 C#6:1 E6:1 |"
           + a4 + a2_end.rstrip(" |"))
    for bar, pos, ln, name in parse_melody(mel):
        b = bar * 4 + pos
        m.add(reed(freq(name), ln * m.beat * 0.92, 0.9), b, 0.12, 1.0, 0.3)
        if bar >= 16:
            m.add(glock(freq(name), ln * m.beat, 0.4), b, -0.3, 1.0, 0.4)
    for bar, ch in enumerate(chords):
        off = bar * 4
        root = freq(CHORDS[ch][0] + "2")
        fifth = root * 1.5 if root * 1.5 < 150 else root * 0.75
        # "Boom-Chicka": Wechselbass und Nachschlag-Akkorde
        m.add(bass(root, 0.8 * m.beat, 1.0), off, 0, 1.0, 0.04)
        m.add(bass(fifth, 0.8 * m.beat, 0.85), off + 2, 0, 1.0, 0.04)
        if bar % 4 == 3:
            m.add(bass(root * 1.125, 0.4 * m.beat, 0.7), off + 3, 0, 1.0, 0.04)
            m.add(bass(root * 1.25, 0.4 * m.beat, 0.7), off + 3.5, 0, 1.0, 0.04)
        notes = chord_notes(ch, 4)
        for beat in (1, 3):
            for j, f in enumerate(notes):
                m.add(pluck(f, 0.3 * m.beat, 0.5, 1.3), off + beat + j * 0.012, -0.5, 1.0, 0.2)
                m.add(pluck(f, 0.2 * m.beat, 0.3, 1.3), off + beat + 0.5 + j * 0.012, -0.5, 1.0, 0.2)
        for f in chord_notes(ch, 3):
            m.add(pad(f, 4 * m.beat, 0.55), off, 0.0, 1.0, 0.4)
        # Train Beat: Besen in Sechzehnteln, Akzente auf 2 und 4
        for i in range(16):
            acc = 1.0 if i in (4, 12) else (0.55 if i % 4 == 2 else (0.42 if i % 2 == 0 else 0.3))
            m.add(brush(acc, 0.13 if i in (4, 12) else 0.07), off + i * 0.25, 0.25, 1.0, 0.12)
        m.add(kick(0.9), off, 0, 1.0, 0.02)
        m.add(kick(0.75), off + 2, 0, 1.0, 0.02)
    save("music/drive.ogg", m.render(1.4))


def success():
    m = Mix(120, 2)
    seq = [("C5", 0.0), ("E5", 0.25), ("G5", 0.5), ("C6", 0.75), ("E6", 1.0)]
    for name, b in seq:
        m.add(glock(freq(name), 0.6, 1.0), b * 2, 0.0, 1.0, 0.5)
        m.add(pluck(freq(name) / 2, 0.5, 0.8, 1.3), b * 2, 0.0, 1.0, 0.3)
    for name in ("C4", "E4", "G4", "C5", "G5", "C6"):
        m.add(pluck(freq(name), 1.6, 0.6, 1.2), 2.6, 0.0, 1.0, 0.4)
        m.add(glock(freq(name) * 2, 1.4, 0.35), 2.6, 0.0, 1.0, 0.5)
    m.add(bass(freq("C2"), 0.9, 0.9), 2.6, 0, 1.0, 0.1)
    out = m.dry + 0  # ohne Schleifen-Faltung: einfacher Hall
    n_ir = int(1.2 * SR)
    t = np.arange(n_ir) / SR
    for c in range(2):
        ir = rng.standard_normal(n_ir) * np.exp(-t * 6)
        ir /= np.sqrt(np.sum(ir ** 2))
        out[:, c] += signal.fftconvolve(m.wet[:, c], ir)[:m.n] * 0.8
    out = out[:int(3.4 * SR)]
    out *= np.linspace(1, 0, len(out))[:, None] ** 0.5
    out *= 0.9 / np.max(np.abs(out))
    save("sfx/success.ogg", out, 5)


if __name__ == "__main__":
    success()
    menu()
    build()
    drive()

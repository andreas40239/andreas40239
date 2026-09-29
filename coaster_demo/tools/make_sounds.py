#!/usr/bin/env python3
"""Erzeugt die Platzhalter-Sounds (synthetisch) als 16-bit-Mono-WAV.

    python3 tools/make_sounds.py        # schreibt nach sounds/

Die Dateien können später einfach durch echte Aufnahmen gleichen Namens
ersetzt werden. *_loop.wav werden im Spiel als Endlosschleife abgespielt.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "sounds")
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def env(n, attack, decay):
    tt = np.arange(n) / SR
    e = np.minimum(1.0, tt / max(attack, 1e-4)) * np.exp(-tt / decay)
    return e


def tone(freq, sec, decay, partials=((1, 1.0),)):
    tt = t(sec)
    x = sum(a * np.sin(2 * np.pi * freq * m * tt) for m, a in partials)
    return x * env(len(tt), 0.003, decay)


def mix(length_sec, *parts):
    out = np.zeros(int(SR * length_sec))
    for start, x in parts:
        i = int(start * SR)
        n = min(len(x), len(out) - i)
        out[i:i + n] += x[:n]
    return out


def make_loop(x, xfade_sec):
    """Nahtlose Schleife: das Ende wird in den Anfang überblendet."""
    n = int(xfade_sec * SR)
    body = x[:-n].copy()
    fade = np.linspace(0, 1, n)
    body[:n] = body[:n] * fade + x[-n:] * (1 - fade)
    return body


def save(name, x, peak=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print("wrote", name, f"{len(x) / SR:.2f}s")


def clack(sec=0.09, ring=1800.0):
    n = noise(sec)
    click = highpass(n, 1500) * env(len(n), 0.001, 0.012)
    body = tone(ring, sec, 0.02, ((1, 0.5), (2.7, 0.3)))
    return click + body


os.makedirs(OUT, exist_ok=True)

# --- Bauen / UI --------------------------------------------------------
thump = tone(110, 0.16, 0.05) * 1.2
save("place", mix(0.18, (0, clack(0.12, 1400) * 0.7), (0, thump), (0.035, clack(0.08, 2100) * 0.4)))
sweep_t = t(0.14)
sweep = np.sin(2 * np.pi * np.cumsum(np.linspace(620, 240, len(sweep_t))) / SR) * env(len(sweep_t), 0.004, 0.05)
save("undo", sweep, 0.6)
beep = lowpass(np.sign(np.sin(2 * np.pi * 170 * t(0.09))), 1200) * env(int(SR * 0.09), 0.004, 0.06)
save("error", mix(0.25, (0, beep), (0.13, beep)), 0.55)
save("click", highpass(noise(0.03), 2500) * env(int(SR * 0.03), 0.0005, 0.006), 0.5)
bell_p = ((1, 1.0), (2, 0.35), (3, 0.15))
save("closed", mix(0.9, (0.0, tone(523.3, 0.5, 0.18, bell_p)), (0.1, tone(659.3, 0.5, 0.18, bell_p)),
                   (0.2, tone(784.0, 0.5, 0.2, bell_p)), (0.3, tone(1046.5, 0.6, 0.3, bell_p))), 0.6)
save("save", mix(0.5, (0.0, tone(784.0, 0.3, 0.1, bell_p)), (0.12, tone(1046.5, 0.38, 0.14, bell_p))), 0.55)
save("load", mix(0.5, (0.0, tone(1046.5, 0.3, 0.1, bell_p)), (0.12, tone(784.0, 0.38, 0.14, bell_p))), 0.55)

# --- Fahren ---------------------------------------------------------------
# Glocke beim Abfahren (unharmonische Teiltöne)
save("bell", tone(988, 1.2, 0.35, ((1, 1.0), (2.76, 0.4), (5.4, 0.2), (8.9, 0.08))), 0.6)
# Rollgeräusch: tiefes Rumpeln + Schienenstöße (Schleife 2 s)
roll = lowpass(lowpass(noise(2.3), 160), 220) * 3.0
roll += lowpass(noise(2.3), 900) * 0.25
for k in range(8):  # Schienenstöße
    i = int((0.05 + k * 0.28) * SR)
    c = clack(0.06, 700) * 0.35
    roll[i:i + len(c)] += c[: len(roll) - i]
save("roll_loop", make_loop(roll, 0.3), 0.8)
# Fahrtwind: rauschen mit langsamer Modulation
wind_n = highpass(lowpass(noise(3.3), 2500), 300)
wind_n *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.7 * t(3.3))
save("wind_loop", make_loop(wind_n, 0.3), 0.7)
# Kettenlift: 8 Klacks pro Sekunde, exakt periodisch
chain = np.zeros(SR)
for k in range(8):
    c = clack(0.07, 2400) * (1.0 if k % 2 == 0 else 0.7)
    i = int(k * SR / 8)
    chain[i:i + len(c)] += c[: SR - i]
chain += lowpass(noise(1.0), 300) * 0.3
save("chain_loop", chain, 0.7)
# Bremse: Zischen
hiss = highpass(noise(0.9), 1800) * env(int(SR * 0.9), 0.04, 0.3)
save("brake", hiss, 0.6)

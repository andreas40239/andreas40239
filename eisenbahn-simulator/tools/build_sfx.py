#!/usr/bin/env python3
"""Bereitet die Geräusche des Spiels auf.

Quellen (tools/audio_src, alle CC0 – Joseph Sardin, BigSoundBank.com):
  0899  Bell of a level crossing      -> bell_loop.ogg  (Läutewerk)
  0226  Whistling train #2            -> whistle.ogg
  3316  Train whistle, foley #2       -> whistle2.ogg
  3015  Steam locomotive, stop        -> hiss.ogg
  3311  Steam engine, foley #2        -> chuff1-4.wav   (einzelne Dampfschläge)
  2727  Train car (Ausschnitt)        -> roll_loop.ogg  (Rollgeräusch)
Bremse, Aufprall und alle Bedienklänge werden synthetisiert.

Aufruf:  python3 tools/build_sfx.py     (benötigt numpy, scipy, ffmpeg)
"""
import os
import subprocess
import wave
import numpy as np
from scipy import signal

SR = 32000
HERE = os.path.dirname(__file__)
SRC = os.path.join(HERE, "audio_src")
OUT = os.path.join(HERE, "..", "assets", "audio", "sfx")
rng = np.random.default_rng(5)


def load(name):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", os.path.join(SRC, name), "-ac", "1", "-ar", str(SR),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def fade(x, fin=0.005, fout=0.05):
    x = x.copy()
    a = int(fin * SR)
    b = int(fout * SR)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b) ** 1.5
    return x


def norm(x, peak=0.9):
    return x * (peak / max(1e-9, np.max(np.abs(x))))


def save_wav(name, x):
    x = np.clip(x, -1, 1)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print("wrote", name, f"{len(x) / SR:.2f}s")


def save_ogg(name, x, q=5):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), os.path.join(OUT, name)], input=pcm, check=True)
    print("wrote", name, f"{len(x) / SR:.2f}s")


def envelope(x, win=0.005):
    n = int(win * SR)
    return np.sqrt(np.maximum(signal.convolve(x * x, np.ones(n) / n, mode="same"), 0.0))


def onsets(x, min_gap=0.3, thresh=0.35):
    """Zeitpunkte deutlicher Lautstärke-Anstiege."""
    env = envelope(x, 0.02)
    d = np.diff(env, prepend=env[0])
    d = signal.convolve(np.maximum(d, 0), np.ones(int(0.01 * SR)), mode="same")
    peaks, _ = signal.find_peaks(d, height=thresh * d.max(), distance=int(min_gap * SR))
    return peaks


# ------------------------------------------------------------------ Aufnahmen

def chuffs():
    x = load("3311.ogg")
    hp = signal.butter(2, 90, btype="high", fs=SR, output="sos")
    x = signal.sosfilt(hp, x)
    on = onsets(x, 0.35, 0.3)
    # vier kräftige, gut getrennte Schläge auswählen
    env = envelope(x, 0.03)
    cand = sorted(on, key=lambda i: -env[min(len(env) - 1, i + int(0.05 * SR))])[:10]
    cand = sorted(cand)[:4] if len(cand) >= 4 else list(on[:4])
    for k, i in enumerate(cand):
        a = max(0, i - int(0.03 * SR))
        seg = x[a:a + int(0.42 * SR)]
        save_wav(f"chuff{k + 1}.wav", norm(fade(seg, 0.012, 0.16), 0.85))


def whistles():
    x = load("0226.ogg")
    save_ogg("whistle.ogg", norm(fade(x[:int(4.2 * SR)], 0.01, 1.2), 0.9))
    y = load("3316.ogg")
    env = envelope(y, 0.02)
    start = max(0, int(np.argmax(env > 0.08 * env.max())) - int(0.02 * SR))
    save_ogg("whistle2.ogg", norm(fade(y[start:start + int(2.6 * SR)], 0.005, 0.5), 0.85))


def hiss():
    x = load("3015.ogg")
    seg = x[int(1.18 * SR):int(2.72 * SR)]
    save_ogg("hiss.ogg", norm(fade(seg, 0.08, 0.7), 0.7))


def roll_loop():
    x = load("2727_excerpt.ogg")
    hp = signal.butter(2, 50, btype="high", fs=SR, output="sos")
    x = signal.sosfilt(hp, x)[int(1.0 * SR):]
    n = int(6.0 * SR)
    xf = int(0.8 * SR)
    seg = x[:n + xf].copy()
    # Überblendung Ende -> Anfang für eine nahtlose Schleife
    w = np.linspace(0, 1, xf)
    seg[:xf] = seg[:xf] * np.sqrt(w) + seg[n:n + xf] * np.sqrt(1 - w)
    seg = seg[:n]
    # Lautstärke glätten, damit die Schleife nicht "pumpt"
    env = envelope(seg, 0.4)
    seg = seg / np.maximum(env, 0.3 * env.mean())
    # Schienenstöße (da-dam … da-dam) dazumischen
    click = np.zeros(n)
    bp = signal.butter(2, [180, 1400], btype="band", fs=SR, output="sos")
    for start in np.arange(0.0, 6.0, 0.75):
        for off, amp in ((0.0, 1.0), (0.16, 0.8)):
            i = int((start + off) * SR)
            ln = int(0.09 * SR)
            if i + ln < n:
                t = np.arange(ln) / SR
                burst = signal.sosfilt(bp, rng.standard_normal(ln)) * np.exp(-t * 45)
                click[i:i + ln] += burst * amp
    out = norm(seg, 0.5) + norm(click, 0.42)
    save_ogg("roll_loop.ogg", norm(out, 0.8), 4)


def bell_loop():
    """Läutewerk: einzelner Glockenschlag aus der Aufnahme, ruhig wiederholt (bim … bim … bim)."""
    x = load("0899.ogg")
    env = envelope(x, 0.003)
    d = np.diff(env, prepend=env[0])
    peaks, _ = signal.find_peaks(d, height=0.25 * d.max(), distance=int(0.03 * SR))
    last = peaks[-1]
    a = max(0, last - int(0.004 * SR))
    ding = fade(x[a:], 0.002, 0.25)
    ding = np.concatenate([ding, np.zeros(int(0.2 * SR))])
    gap = 0.46
    count = 4
    n = int(gap * count * SR)
    out = np.zeros(n)
    for k in range(count):
        i = int(k * gap * SR)
        seg = ding * (1.0 if k % 2 == 0 else 0.88)
        end = min(n, i + len(seg))
        out[i:end] += seg[:end - i]
        rest = seg[end - i:]
        if len(rest) > 0:          # Ausklang läuft über das Schleifenende in den Anfang
            out[:len(rest)] += rest[:n]
    save_ogg("bell_loop.ogg", norm(out, 0.85), 6)


# ------------------------------------------------------------------ Synthese

def tone(f, dur, decay, harm=(1.0,), vib=0.0):
    t = np.arange(int(dur * SR)) / SR
    out = np.zeros(len(t))
    for k, a in enumerate(harm, 1):
        out += a * np.sin(2 * np.pi * f * k * t * (1 + vib * np.sin(2 * np.pi * 6 * t)))
    return out * np.exp(-t * decay)


def noise(dur, lo, hi, decay):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sos = signal.butter(2, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, rng.standard_normal(n)) * np.exp(-t * decay)


def synth():
    # Gleis legen: dumpfer Schlag + Schotter
    place = norm(tone(150, 0.16, 28, (1, 0.4)), 0.8)
    grav = noise(0.16, 1200, 6000, 30)
    save_wav("place.wav", norm(fade(place + 0.35 * norm(grav), 0.002, 0.05), 0.8))
    # großes Bauteil: tiefer Schlag + metallischer Klang
    big = norm(tone(95, 0.35, 14, (1, 0.5, 0.2)), 1.0)
    clang = tone(620, 0.35, 16, (1, 0.0, 0.5, 0.0, 0.3)) + tone(930, 0.35, 20)
    g2 = np.pad(noise(0.25, 900, 5000, 18), (0, int(0.1 * SR)))
    save_wav("place_big.wav", norm(fade(big + 0.3 * norm(clang) + 0.3 * norm(g2), 0.002, 0.1), 0.85))
    # Abriss: Geröll
    er = noise(0.3, 300, 3500, 12)
    for i in range(5):
        j = int(rng.uniform(0.02, 0.2) * SR)
        b = noise(0.05, 500, 4000, 70)
        er[j:j + len(b)] += b * 1.5
    save_wav("erase.wav", norm(fade(er, 0.004, 0.12), 0.75))
    # Fehler: zwei tiefe, weiche Töne
    e1 = tone(196, 0.14, 12, (1, 0.3, 0.2))
    e2 = tone(156, 0.22, 10, (1, 0.3, 0.2))
    save_wav("error.wav", norm(fade(np.concatenate([e1, e2]), 0.004, 0.08), 0.6))
    # Klick
    save_wav("click.wav", norm(fade(tone(1150, 0.05, 70, (1, 0.3)) + 0.3 * noise(0.05, 2000, 8000, 120), 0.001, 0.02), 0.5))
    # Weiche umstellen: Hebel-Klack + Einrasten
    k1 = noise(0.06, 500, 3000, 60) + tone(320, 0.06, 50)
    k2 = noise(0.08, 300, 2200, 45) + tone(210, 0.08, 40)
    sw = np.concatenate([norm(k1), np.zeros(int(0.07 * SR)), norm(k2) * 1.1])
    save_wav("switch.wav", norm(fade(sw, 0.001, 0.03), 0.8))
    # Stern: heller Glockenton
    st = tone(1318, 0.5, 8, (1, 0.0, 0.3)) + 0.6 * tone(1976, 0.5, 10)
    save_wav("star.wav", norm(fade(st, 0.002, 0.2), 0.7))
    # Puffer berührt: dumpf
    bump = norm(tone(70, 0.3, 14, (1, 0.6))) + 0.5 * norm(noise(0.3, 150, 1200, 22))
    save_wav("bump.wav", norm(fade(bump, 0.002, 0.1), 0.85))
    # Unfall: Krachen, Scheppern, Ausrollen
    n = int(1.6 * SR)
    cr = np.zeros(n)
    base = norm(tone(55, 0.6, 7, (1, 0.7, 0.3))) + norm(noise(0.6, 100, 2500, 6))
    cr[:len(base)] += base
    for i in range(9):
        j = int(rng.uniform(0.03, 0.9) * SR)
        f = rng.uniform(400, 1900)
        c = tone(f, 0.3, rng.uniform(10, 25), (1, 0.0, 0.6, 0.0, 0.4)) * rng.uniform(0.2, 0.5)
        cr[j:j + len(c)] += c[:n - j]
    rumble = noise(1.6, 80, 900, 2.5)
    cr += 0.5 * norm(rumble)
    save_wav("crash.wav", norm(fade(np.tanh(cr * 1.5), 0.002, 0.5), 0.9))
    # Bremsenquietschen: mehrere schwankende hohe Töne + Rauschen, klingt langsam aus
    dur = 1.5
    t = np.arange(int(dur * SR)) / SR
    sq = np.zeros(len(t))
    for f0, a in ((2350, 1.0), (3120, 0.6), (4700, 0.3)):
        fm = f0 * (1 - 0.06 * t / dur) * (1 + 0.004 * np.sin(2 * np.pi * 9 * t + f0))
        sq += a * np.sin(2 * np.pi * np.cumsum(fm) / SR)
    trem = 0.75 + 0.25 * np.sin(2 * np.pi * 23 * t)
    env = np.minimum(1, t / 0.08) * np.clip((dur - t) / 0.7, 0, 1)
    air = noise(dur, 1500, 9000, 0.8)
    save_ogg("brake.ogg", norm((sq * trem * 0.5 + 0.35 * norm(air)) * env, 0.5), 5)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    chuffs()
    whistles()
    hiss()
    roll_loop()
    bell_loop()
    synth()

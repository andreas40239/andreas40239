#!/usr/bin/env python3
"""Erzeugt Soundeffekte und Ambient-Schleifen fuer Nachtkatze (GDD Abschnitt 11).

Alles synthetisiert, keine Samples. Die Klaenge sind bewusst einfach und
dienen als Platzhalter: laut GDD Abschnitt 15 koennen sie spaeter durch
lizenzfreie Aufnahmen ersetzt werden - gleiche Dateinamen genuegen.

Aufruf:  python3 nachtkatze/tools/sfx_erzeugen.py
Ergebnis: nachtkatze/assets/sfx/*.wav und nachtkatze/assets/ambient/*.wav

Ambient-Schleifen sind nahtlos: Ereignisse (Vogelrufe, Glocke, ...) werden
ueber das Ende hinaus an den Anfang gefaltet, Rauschflaechen werden
kreisfoermig gefiltert, sodass Anfang und Ende zusammenpassen.
"""
import math
import os
import random
import struct
import sys
import wave

sys.path.insert(0, os.path.dirname(__file__))
from musik_erzeugen import note, pluck  # noqa: E402

RATE = 22050
TAU = math.pi * 2.0
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")


# --- Grundbausteine -----------------------------------------------------------

def silence(seconds):
    return [0.0] * int(seconds * RATE)


def add(buffer, start, samples, gain=1.0, wrap=False):
    total = len(buffer)
    for i, value in enumerate(samples):
        index = start + i
        if wrap:
            index %= total
        elif index >= total:
            break
        buffer[index] += value * gain


def noise(seconds, seed):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(int(seconds * RATE))]


def envelope(samples, attack, decay_rate, release=0.01):
    """Kurzer Anschlag, exponentielles Abklingen, weicher Ausklang."""
    count = len(samples)
    rel = max(1, int(release * RATE))
    out = []
    for n, value in enumerate(samples):
        t = n / RATE
        gain = min(1.0, t / attack) if attack > 0 else 1.0
        gain *= math.exp(-t * decay_rate)
        if n > count - rel:
            gain *= (count - n) / rel
        out.append(value * gain)
    return out


def shape(samples, points):
    """Huellkurve aus (Zeit, Pegel)-Punkten, linear verbunden."""
    out = []
    for n, value in enumerate(samples):
        t = n / RATE
        level = points[-1][1]
        for (t0, a), (t1, b) in zip(points, points[1:]):
            if t0 <= t <= t1:
                level = a + (b - a) * ((t - t0) / (t1 - t0) if t1 > t0 else 1.0)
                break
        out.append(value * level)
    return out


def _coefficients(kind, freq, q):
    freq = max(20.0, min(freq, RATE * 0.45))
    w0 = TAU * freq / RATE
    cos_w = math.cos(w0)
    alpha = math.sin(w0) / (2.0 * q)
    if kind == "low":
        b0, b1, b2 = (1 - cos_w) / 2, 1 - cos_w, (1 - cos_w) / 2
    elif kind == "high":
        b0, b1, b2 = (1 + cos_w) / 2, -(1 + cos_w), (1 + cos_w) / 2
    else:  # band, 0 dB Spitze
        b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * cos_w, 1 - alpha
    return b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0


def biquad(samples, kind, freq, q=0.707, circular=False):
    """Biquad-Filter; freq darf eine Funktion der Zeit sein (Filterfahrt).
    circular=True filtert zweimal im Kreis - fuer nahtlose Schleifen."""
    x1 = x2 = y1 = y2 = 0.0
    varying = callable(freq)
    coeff = None if varying else _coefficients(kind, freq, q)
    out = [0.0] * len(samples)
    passes = 2 if circular else 1
    for _ in range(passes):
        for n, x in enumerate(samples):
            if varying and n % 32 == 0:
                coeff = _coefficients(kind, freq(n / RATE), q)
            b0, b1, b2, a1, a2 = coeff
            y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1 = x1, x
            y2, y1 = y1, y
            out[n] = y
    return out


def tone(seconds, freq, wave_kind="sine", harmonics=8, jitter=0.0, seed=1):
    """Oszillator mit gleitender Tonhoehe; freq darf eine Funktion der Zeit sein."""
    rng = random.Random(seed)
    phase = 0.0
    out = []
    for n in range(int(seconds * RATE)):
        t = n / RATE
        f = freq(t) if callable(freq) else freq
        if jitter:
            f *= 1.0 + rng.uniform(-jitter, jitter)
        phase = (phase + f / RATE) % 1.0
        if wave_kind == "sine":
            value = math.sin(TAU * phase)
        elif wave_kind == "saw":
            # bandbegrenzt aus Obertoenen, damit es nicht klirrt
            value = 0.0
            for k in range(1, harmonics + 1):
                if f * k > RATE * 0.45:
                    break
                value += math.sin(TAU * phase * k) / k
            value *= 0.6
        elif wave_kind == "square":
            value = 0.0
            for k in range(1, harmonics * 2, 2):
                if f * k > RATE * 0.45:
                    break
                value += math.sin(TAU * phase * k) / k
            value *= 0.8
        else:  # pulse - Motor
            value = math.exp(-phase * 9.0) * 2.0 - 0.22
        out.append(value)
    return out


def mix(*layers):
    length = max(len(layer) for layer, _ in layers)
    out = [0.0] * length
    for layer, gain in layers:
        for i, value in enumerate(layer):
            out[i] += value * gain
    return out


def lerp(a, b, t):
    return a + (b - a) * t


def contour(points):
    """Verlauf aus (Zeit, Wert)-Punkten, als Funktion der Zeit."""
    def value(t):
        if t <= points[0][0]:
            return points[0][1]
        for (t0, a), (t1, b) in zip(points, points[1:]):
            if t <= t1:
                return lerp(a, b, (t - t0) / (t1 - t0))
        return points[-1][1]
    return value


def voice(seconds, pitch, formants, seed, breath=0.08, jitter=0.004):
    """Stimme aus Saegezahn und zwei Formantfiltern (Miauen, Bellen, Jaulen).
    formants: Funktionen der Zeit fuer F1 und F2."""
    source = tone(seconds, pitch, "saw", harmonics=24, jitter=jitter, seed=seed)
    air = noise(seconds, seed + 1)
    source = [s + a * breath for s, a in zip(source, air)]
    f1 = biquad(source, "band", formants[0], q=5.0)
    f2 = biquad(source, "band", formants[1], q=7.0)
    return [a * 1.4 + b for a, b in zip(f1, f2)]


def normalize(buffer, peak_target):
    peak = max(abs(v) for v in buffer) or 1.0
    return [v * peak_target / peak for v in buffer]


def fade_edges(buffer, milliseconds=4.0):
    fade = max(1, int(RATE * milliseconds / 1000.0))
    for i in range(min(fade, len(buffer))):
        weight = i / fade
        buffer[i] *= weight
        buffer[-1 - i] *= weight
    return buffer


def write(folder, name, buffer, peak=0.9, loop=False):
    buffer = normalize(buffer, peak)
    if not loop:
        buffer = fade_edges(buffer)
    path = os.path.join(ROOT, folder, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    frames = bytearray()
    for value in buffer:
        frames += struct.pack("<h", int(max(-1.0, min(1.0, value)) * 32767))
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(bytes(frames))
    print("%-28s %5.2f s" % (folder + "/" + name, len(buffer) / RATE))


# --- Katze --------------------------------------------------------------------

def paw_step(seed):
    """Weicher Pfotenschritt: gedaempftes Tappen."""
    rng = random.Random(seed)
    tap = biquad(noise(0.09, seed), "low", 700 + rng.uniform(-120, 160), q=0.9)
    tap = envelope(tap, 0.004, 55.0)
    thump = envelope(tone(0.09, 105 + rng.uniform(-10, 10)), 0.002, 70.0)
    return mix((tap, 1.0), (thump, 0.35))


def scratch(seed):
    """Kratzen an der Regenrinne: drei, vier kurze Krallenstriche."""
    rng = random.Random(seed)
    out = silence(0.26)
    position = 0.0
    for i in range(rng.randint(3, 4)):
        length = rng.uniform(0.035, 0.06)
        centre = rng.uniform(2600, 4200)
        stroke = biquad(noise(length, seed * 10 + i), "band",
                        contour([(0, centre), (length, centre * 0.8)]), q=2.2)
        stroke = shape(stroke, [(0, 0), (0.004, 1), (length * 0.7, 0.6), (length, 0)])
        add(out, int(position * RATE), stroke, rng.uniform(0.6, 1.0))
        position += length + rng.uniform(0.01, 0.03)
    return out


def landing():
    body = biquad(noise(0.2, 5), "low", 520, q=0.8)
    body = envelope(body, 0.003, 28.0)
    thump = envelope(tone(0.2, contour([(0, 90), (0.15, 52)])), 0.002, 26.0)
    return mix((body, 0.8), (thump, 0.9))


def crunch():
    """Knuspern: unregelmaessige, kurze Knackser."""
    rng = random.Random(77)
    out = silence(0.5)
    position = 0.0
    while position < 0.42:
        length = rng.uniform(0.012, 0.028)
        grain = biquad(noise(length, rng.randint(0, 99999)), "band",
                       rng.uniform(1400, 3200), q=1.6)
        grain = envelope(grain, 0.001, rng.uniform(80, 160))
        add(out, int(position * RATE), grain, rng.uniform(0.4, 1.0))
        position += rng.uniform(0.03, 0.075)
    return out


def meow():
    """Kurzes Miauen bei Treffer: i - a - u mit steigender, dann fallender Tonhoehe."""
    seconds = 0.46
    pitch = contour([(0, 560), (0.14, 820), (0.3, 700), (seconds, 470)])
    f1 = contour([(0, 380), (0.12, 900), (0.3, 780), (seconds, 420)])
    f2 = contour([(0, 2300), (0.12, 1500), (0.3, 1200), (seconds, 850)])
    sound = voice(seconds, pitch, (f1, f2), seed=9)
    return shape(sound, [(0, 0), (0.035, 1.0), (0.3, 0.85), (seconds, 0.0)])


def purr():
    """Schnurren: tiefe Pulse um 26 Hz, im Atemrhythmus lauter und leiser."""
    seconds = 2.6
    out = silence(seconds)
    rng = random.Random(4)
    period = 1.0 / 26.0
    t = 0.0
    while t < seconds - 0.05:
        breath = 0.55 + 0.45 * math.sin(TAU * t / 1.3) ** 2
        grain = biquad(noise(0.03, rng.randint(0, 99999)), "low", 320, q=1.1)
        grain = envelope(grain, 0.003, 90.0)
        add(out, int(t * RATE), grain, breath)
        t += period * rng.uniform(0.94, 1.06)
    hum = [math.sin(TAU * 52 * n / RATE) * (0.5 + 0.5 * math.sin(TAU * 26 * n / RATE))
           for n in range(len(out))]
    out = mix((out, 1.0), (hum, 0.25))
    return shape(out, [(0, 0), (0.25, 1), (seconds - 0.5, 1), (seconds, 0)])


# --- Hunde --------------------------------------------------------------------

def bark(pitch_start, pitch_end, seconds, seed, formant_scale=1.0):
    pitch = contour([(0, pitch_start), (seconds * 0.35, pitch_start * 1.05), (seconds, pitch_end)])
    f1 = contour([(0, 700 * formant_scale), (seconds, 520 * formant_scale)])
    f2 = contour([(0, 1500 * formant_scale), (seconds, 1100 * formant_scale)])
    sound = voice(seconds, pitch, (f1, f2), seed, breath=0.35, jitter=0.02)
    return shape(sound, [(0, 0), (0.008, 1), (seconds * 0.4, 0.7), (seconds, 0)])


def yap():
    """Klaeffen des kleinen Hundes: zwei helle, kurze Laute."""
    out = silence(0.4)
    add(out, 0, bark(880, 640, 0.12, 21, 1.35))
    add(out, int(0.19 * RATE), bark(940, 700, 0.12, 22, 1.35), 0.9)
    return out


def growl():
    """Tiefes Knurren des grossen Hundes: rauer, zitternder Grundton."""
    seconds = 0.85
    rough = tone(seconds, contour([(0, 92), (0.4, 104), (seconds, 88)]), "saw",
                 harmonics=30, jitter=0.08, seed=31)
    tremble = [math.sin(TAU * 28 * n / RATE) * 0.35 + 0.65 for n in range(len(rough))]
    rough = [a * b for a, b in zip(rough, tremble)]
    body = biquad(rough, "band", 420, q=1.5)
    low = biquad(rough, "low", 260, q=0.8)
    sound = mix((body, 1.0), (low, 0.7))
    return shape(sound, [(0, 0), (0.12, 1), (0.6, 0.9), (seconds, 0)])


def woof():
    """Bellen: kurzes, abfallendes Wuff (fuer beide Hunde, Tonhoehe per Abspielrate)."""
    return bark(470, 260, 0.24, 41, 1.0)


# --- Revierkatzen -------------------------------------------------------------

def hiss():
    seconds = 0.7
    air = biquad(noise(seconds, 51), "high", 2600, q=0.7)
    edge = biquad(noise(seconds, 52), "band", 5200, q=1.8)
    sound = mix((air, 0.8), (edge, 0.9))
    # kurzes Spucken am Anfang
    return shape(sound, [(0, 0), (0.015, 1), (0.06, 0.55), (0.12, 0.8), (0.5, 0.65), (seconds, 0)])


def fight():
    """Kampfgeraeusch: Jaulen, Fauchen und Getuemmel durcheinander."""
    seconds = 0.6
    rng = random.Random(61)
    points = [(0, 650)]
    t = 0.0
    while t < seconds:
        t += 0.05
        points.append((t, rng.uniform(600, 1150)))
    pitch = contour(points)
    yowl = voice(seconds, pitch, (lambda _t: 850, lambda _t: 1500), seed=62, breath=0.25, jitter=0.03)
    yowl = shape(yowl, [(0, 0), (0.03, 1), (0.45, 0.8), (seconds, 0)])
    spit = shape(biquad(noise(seconds, 63), "high", 3000), [(0, 0), (0.01, 1), (0.1, 0.2), (0.3, 0.6), (seconds, 0)])
    scuffle = silence(seconds)
    for i in range(5):
        thud = envelope(biquad(noise(0.05, 64 + i), "low", 500), 0.002, 60)
        add(scuffle, int(rng.uniform(0.0, 0.5) * RATE), thud, rng.uniform(0.5, 1.0))
    return mix((yowl, 0.9), (spit, 0.4), (scuffle, 0.8))


# --- Autos --------------------------------------------------------------------

def engine_loop():
    """Motor als nahtlose 1-Sekunden-Schleife: ganzzahlige Schwingungen + Kreisfilter."""
    seconds = 1.0
    firing = tone(seconds, 56.0, "pulse")
    firing = biquad(firing, "low", 700, q=0.9, circular=True)
    second = tone(seconds, 112.0, "saw", harmonics=10)
    rumble = biquad(noise(seconds, 71), "low", 180, q=0.7, circular=True)
    return mix((firing, 0.8), (second, 0.18), (rumble, 0.5))


def horn():
    seconds = 0.5
    low = tone(seconds, 392.0, "square", harmonics=6)
    high = tone(seconds, 494.0, "square", harmonics=6)
    sound = biquad(mix((low, 0.6), (high, 0.5)), "low", 2200, q=0.8)
    return shape(sound, [(0, 0), (0.02, 1), (0.42, 1), (seconds, 0)])


# --- Oberflaeche --------------------------------------------------------------

def click():
    blip = envelope(tone(0.035, contour([(0, 1900), (0.035, 1500)])), 0.001, 140)
    tick = envelope(biquad(noise(0.035, 81), "high", 3000), 0.0005, 300)
    return mix((blip, 0.7), (tick, 0.4))


def jingle(notes, spacing, tail, decay):
    """Kurze Tonfolge mit dem Zupfinstrument der Musik."""
    out = silence(spacing * len(notes) + tail)
    for i, semitones in enumerate(notes):
        chord = semitones if isinstance(semitones, list) else [semitones]
        for s in chord:
            add(out, int(i * spacing * RATE), pluck(note(330.0, s), tail + 0.3, decay, 0.7), 0.7)
    return out


def level_complete():
    return jingle([0, 4, 7, 12, [0, 7, 12, 16]], 0.12, 1.1, 0.9975)


def game_over():
    return jingle([7, 3, 0, [-12, -5, 0]], 0.26, 1.0, 0.9965)


# --- Ambient ------------------------------------------------------------------

def bed(seconds, seed, cutoff, swell_period=None, swell_depth=0.0):
    """Leise Rauschflaeche, kreisfoermig gefiltert - fuer nahtlose Schleifen."""
    base = biquad(noise(seconds, seed), "low", cutoff, q=0.6, circular=True)
    if swell_period:
        count = len(base)
        cycles = max(1, round(seconds / swell_period))
        base = [v * (1.0 - swell_depth + swell_depth * (0.5 + 0.5 * math.sin(TAU * cycles * n / count)))
                for n, v in enumerate(base)]
    return base


def chirp(f_start, f_end, seconds, trill=0.0):
    sound = tone(seconds, contour([(0, f_start), (seconds, f_end)]))
    if trill:
        sound = [v * (0.55 + 0.45 * math.sin(TAU * trill * n / RATE)) for n, v in enumerate(sound)]
    return shape(sound, [(0, 0), (seconds * 0.15, 1), (seconds * 0.7, 0.8), (seconds, 0)])


def ambient_day(seconds=20.0):
    """Tag: Voegel und entfernter Verkehr."""
    rng = random.Random(101)
    out = bed(seconds, 102, 240, swell_period=5.0, swell_depth=0.7)
    out = [v * 0.9 for v in out]
    birds = [0.0] * len(out)
    t = 0.4
    while t < seconds:
        species = rng.randrange(3)
        if species == 0:      # Spatz: mehrere kurze Tschilp-Laute
            for k in range(rng.randint(2, 5)):
                f = rng.uniform(3200, 4200)
                add(birds, int((t + k * 0.13) * RATE), chirp(f, f * 1.25, 0.07), 0.5, wrap=True)
        elif species == 1:    # Pfiff abwaerts
            f = rng.uniform(2600, 3200)
            add(birds, int(t * RATE), chirp(f, f * 0.7, 0.32), 0.45, wrap=True)
        else:                 # Triller
            f = rng.uniform(3600, 4600)
            add(birds, int(t * RATE), chirp(f, f * 1.05, 0.45, trill=26), 0.35, wrap=True)
        t += rng.uniform(0.9, 2.2)
    return mix((out, 1.0), (birds, 0.6))


def church_bell(seconds, strike_gain=1.0):
    """Kirchenglocke: unharmonische Teiltoene mit langem, unterschiedlichem Ausklang."""
    base = 196.0
    partials = [(0.5, 0.5, 0.35), (1.0, 0.7, 0.55), (1.19, 0.45, 0.9), (1.5, 0.3, 1.1),
                (2.0, 0.55, 1.0), (2.51, 0.2, 1.6), (2.66, 0.18, 1.8), (3.01, 0.15, 2.2),
                (4.1, 0.1, 3.0)]
    out = [0.0] * int(seconds * RATE)
    for ratio, gain, decay in partials:
        f = base * ratio
        for n in range(len(out)):
            t = n / RATE
            out[n] += math.sin(TAU * f * t + ratio) * gain * math.exp(-t * decay)
    strike = envelope(biquad(noise(0.04, 103), "band", 1800, q=1.2), 0.001, 90)
    add(out, 0, strike, 0.6)
    out = biquad(out, "low", 2400, q=0.7)   # ferne Glocke, etwas gedaempft
    return [v * strike_gain for v in out]


def ambient_dusk(seconds=24.0):
    """Daemmerung: Schwalben und Kirchenglocke."""
    rng = random.Random(201)
    out = bed(seconds, 202, 160, swell_period=6.0, swell_depth=0.5)
    swallows = [0.0] * len(out)
    t = 0.3
    while t < seconds:
        # Schwarm: schnelles, hohes Zwitschern
        for k in range(rng.randint(3, 7)):
            f = rng.uniform(5200, 6800)
            add(swallows, int((t + k * rng.uniform(0.05, 0.09)) * RATE),
                chirp(f, f * rng.uniform(0.8, 1.2), rng.uniform(0.03, 0.06)), 0.45, wrap=True)
        t += rng.uniform(1.2, 3.0)
    bells = [0.0] * len(out)
    bell = church_bell(7.0)
    for k in range(3):
        add(bells, int((4.0 + k * 2.4) * RATE), bell, 0.55 - k * 0.08, wrap=True)
    return mix((out, 0.8), (swallows, 0.55), (bells, 0.55))


def cricket(seconds, carrier, rate, seed):
    rng = random.Random(seed)
    out = [0.0] * int(seconds * RATE)
    pulse = tone(0.016, carrier)
    pulse = shape(pulse, [(0, 0), (0.003, 1), (0.012, 0.7), (0.016, 0)])
    t = rng.uniform(0, 0.4)
    while t < seconds:
        for k in range(3):
            add(out, int((t + k * 0.026) * RATE), pulse, 1.0, wrap=True)
        t += rate * rng.uniform(0.93, 1.07)
    return out


def scooter(seconds, start, duration):
    """Ferner Motorroller: summender Zweitakter, der naeher kommt und wieder verschwindet."""
    out = [0.0] * int(seconds * RATE)
    pitch = contour([(0, 128), (duration * 0.45, 150), (duration * 0.55, 136), (duration, 118)])
    buzz = tone(duration, pitch, "saw", harmonics=14, jitter=0.01, seed=301)
    buzz = biquad(buzz, "low", 1100, q=0.8)
    buzz = shape(buzz, [(0, 0), (duration * 0.5, 1), (duration, 0)])
    add(out, int(start * RATE), buzz, 1.0, wrap=True)
    return out


def ambient_night(seconds=20.0):
    """Nacht: Grillen und ferner Motorroller."""
    out = bed(seconds, 302, 140)
    crickets = mix((cricket(seconds, 4300, 0.52, 303), 0.5),
                   (cricket(seconds, 4750, 0.61, 304), 0.35),
                   (cricket(seconds, 3900, 0.47, 305), 0.22))
    moped = scooter(seconds, 9.0, 7.0)
    return mix((out, 0.6), (crickets, 0.7), (moped, 0.22))


def main():
    for i in range(3):
        write("sfx", "pfote_%d.wav" % (i + 1), paw_step(11 + i), peak=0.6)
    for i in range(2):
        write("sfx", "kratzen_%d.wav" % (i + 1), scratch(21 + i), peak=0.55)
    write("sfx", "landung.wav", landing(), peak=0.75)
    write("sfx", "knuspern.wav", crunch(), peak=0.75)
    write("sfx", "miau.wav", meow(), peak=0.85)
    write("sfx", "schnurren.wav", purr(), peak=0.8)
    write("sfx", "klaeffen.wav", yap(), peak=0.8)
    write("sfx", "knurren.wav", growl(), peak=0.85)
    write("sfx", "bellen.wav", woof(), peak=0.85)
    write("sfx", "fauchen.wav", hiss(), peak=0.7)
    write("sfx", "kampf.wav", fight(), peak=0.8)
    write("sfx", "motor.wav", engine_loop(), peak=0.7, loop=True)
    write("sfx", "hupe.wav", horn(), peak=0.7)
    write("sfx", "klick.wav", click(), peak=0.6)
    write("sfx", "geschafft.wav", level_complete(), peak=0.85)
    write("sfx", "game_over.wav", game_over(), peak=0.8)
    write("ambient", "tag.wav", ambient_day(), peak=0.55, loop=True)
    write("ambient", "daemmerung.wav", ambient_dusk(), peak=0.55, loop=True)
    write("ambient", "nacht.wav", ambient_night(), peak=0.55, loop=True)


if __name__ == "__main__":
    main()

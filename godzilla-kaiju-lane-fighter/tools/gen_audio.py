#!/usr/bin/env python3
"""Generate all SFX and music for GODZILLA: KAIJU LANE FIGHTER.
Mono 22050 Hz 16-bit WAV (GDD performance mode spec)."""
import os, wave, math
import numpy as np

SR = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def save(name, data, folder="sfx"):
    data = np.clip(data, -1, 1)
    pcm = (data * 32000).astype(np.int16)
    path = os.path.join(ROOT, folder, name + ".wav")
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())


def t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def env(n, a=0.01, d=0.1, sustain=0.0, dur=None):
    """simple attack/decay envelope over n samples"""
    x = np.zeros(n)
    na, nd = int(a * SR), int(d * SR)
    na = min(na, n)
    x[:na] = np.linspace(0, 1, na)
    rest = n - na
    if rest > 0:
        x[na:] = np.maximum(sustain, np.exp(-np.linspace(0, 5, rest)) * (1 - sustain) + sustain)
    return x


def noise(dur):
    return np.random.uniform(-1, 1, int(SR * dur))


def lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def sweep(f0, f1, dur, shape="sine"):
    tt = t(dur)
    freq = np.linspace(f0, f1, len(tt))
    phase = np.cumsum(2 * np.pi * freq / SR)
    if shape == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1) - 1
    if shape == "square":
        return np.sign(np.sin(phase))
    return np.sin(phase)


def distort(x, g=3.0):
    return np.tanh(x * g)


# ---------------- SFX ----------------
def gen_sfx():
    np.random.seed(3)
    # tail whip: swoosh + crack (150ms)
    s = lowpass(noise(0.10), 0.25) * env(int(SR * 0.10), 0.01, 0.08)
    crack = noise(0.05) * env(int(SR * 0.05), 0.001, 0.03) * 1.2
    save("tail_whip", np.concatenate([s * 0.7, crack]))

    # breath charge: rising electrical hum
    x = sweep(80, 900, 0.9) * 0.4 + lowpass(noise(0.9), 0.5) * 0.15
    save("breath_charge", x * env(int(SR * 0.9), 0.05, 2.0, sustain=0.8))

    # breath fire: deep roar-noise + rumble
    n = int(SR * 0.7)
    x = lowpass(noise(0.7), 0.12) * 1.4 + np.sin(2 * np.pi * 95 * t(0.7)) * 0.5
    save("breath_fire", distort(x, 2.0) * env(n, 0.01, 0.6, sustain=0.5))

    # jump / land
    save("jump", sweep(300, 700, 0.15) * env(int(SR * 0.15), 0.005, 0.1) * 0.5)
    thud = np.sin(2 * np.pi * np.linspace(90, 40, int(SR * 0.25)) * t(0.25) / 0.25 * 0.25)
    save("land", (thud + lowpass(noise(0.25), 0.1) * 0.6) * env(int(SR * 0.25), 0.002, 0.2))

    # dash claw
    save("dash", sweep(500, 200, 0.12, "saw") * env(int(SR * 0.12), 0.005, 0.09) * 0.45)

    # grab / throw
    save("grab", lowpass(noise(0.12), 0.6) * env(int(SR * 0.12), 0.005, 0.08) * 0.8 + sweep(700, 200, 0.12) * 0.2 * env(int(SR * 0.12), 0.01, 0.1))
    wh = sweep(400, 900, 0.15) * 0.3 * env(int(SR * 0.15), 0.01, 0.12)
    crunch = lowpass(noise(0.15), 0.3) * env(int(SR * 0.15), 0.001, 0.1)
    save("throw", np.concatenate([wh, crunch]))

    # hit connect (melee lands)
    save("hit", (lowpass(noise(0.08), 0.35) + np.sin(2 * np.pi * 150 * t(0.08))) * env(int(SR * 0.08), 0.001, 0.06))

    # godzilla hurt: pitched-down roar
    x = sweep(150, 60, 0.5, "saw")
    save("gz_hurt", distort(x, 4.0) * env(int(SR * 0.5), 0.01, 0.4) * 0.8)

    # godzilla roar (level start / special)
    x = np.concatenate([sweep(90, 180, 0.35, "saw"), sweep(180, 70, 0.9, "saw")])
    x = distort(x + lowpass(noise(len(x) / SR), 0.2) * 0.3, 3.5)
    save("gz_roar", x * env(len(x), 0.03, 1.0, sustain=0.4))

    # nuclear pulse
    boom = np.sin(2 * np.pi * np.linspace(120, 35, int(SR * 0.6)) * t(0.6)) + lowpass(noise(0.6), 0.15) * 1.2
    save("pulse", distort(boom, 2.5) * env(int(SR * 0.6), 0.002, 0.5))

    # enemy deaths
    save("raptor_die", sweep(1200, 250, 0.25) * env(int(SR * 0.25), 0.005, 0.2) * 0.5 + lowpass(noise(0.25), 0.3) * env(int(SR * 0.25), 0.02, 0.15) * 0.5)
    save("ptera_die", sweep(1500, 500, 0.2, "square") * env(int(SR * 0.2), 0.005, 0.15) * 0.3)
    save("anky_die", (np.sin(2 * np.pi * 70 * t(0.35)) + lowpass(noise(0.35), 0.2)) * env(int(SR * 0.35), 0.002, 0.3) * 0.9)

    # boss roar / stomp / bite
    x = np.concatenate([sweep(60, 130, 0.4, "saw"), sweep(130, 45, 0.9, "saw")])
    save("boss_roar", distort(x, 5.0) * env(len(x), 0.02, 1.2, sustain=0.5))
    save("stomp", np.sin(2 * np.pi * np.linspace(70, 30, int(SR * 0.3)) * t(0.3)) * env(int(SR * 0.3), 0.002, 0.25) * 1.2)
    save("bite", (lowpass(noise(0.1), 0.4) + sweep(300, 100, 0.1)) * env(int(SR * 0.1), 0.002, 0.08))

    # UI + misc
    save("ui_click", sweep(900, 1300, 0.06, "square") * env(int(SR * 0.06), 0.002, 0.05) * 0.25)
    save("lane_switch", lowpass(noise(0.12), 0.4) * env(int(SR * 0.12), 0.02, 0.09) * 0.25)
    save("checkpoint", np.concatenate([sweep(660, 660, 0.09) * env(int(SR * 0.09), 0.005, 0.08),
                                       sweep(880, 880, 0.09) * env(int(SR * 0.09), 0.005, 0.08),
                                       sweep(1100, 1100, 0.15) * env(int(SR * 0.15), 0.005, 0.13)]) * 0.35)
    epg = np.concatenate([sweep(880, 880, 0.07), sweep(1174, 1174, 0.07), sweep(1568, 1568, 0.12)])
    save("ep_gain", epg * 0.3 * env(len(epg), 0.005, 0.22))
    # missiles/shell fire + explosion for boss projectiles
    save("shell", sweep(200, 900, 0.15) * env(int(SR * 0.15), 0.005, 0.1) * 0.4)
    save("explosion", (lowpass(noise(0.5), 0.2) * 1.3 + np.sin(2 * np.pi * 60 * t(0.5))) * env(int(SR * 0.5), 0.002, 0.4))


# ---------------- MUSIC ----------------
NOTE = {n: 440 * 2 ** ((i - 9) / 12) for i, n in enumerate(
    ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def freq(name):
    # e.g. "E2", "G#3"
    pitch, octave = name[:-1], int(name[-1])
    return NOTE[pitch] * 2 ** (octave - 4)


def synth_note(f, dur, shape="square", vol=0.2, decay=6.0):
    tt = t(dur)
    if shape == "square":
        x = np.sign(np.sin(2 * np.pi * f * tt))
    elif shape == "saw":
        x = 2 * ((f * tt) % 1) - 1
    elif shape == "tri":
        x = 2 * np.abs(2 * ((f * tt) % 1) - 1) - 1
    else:
        x = np.sin(2 * np.pi * f * tt)
    return x * vol * np.exp(-tt * decay / dur * dur) * env(len(tt), 0.005, dur)


def kick(dur=0.18):
    return np.sin(2 * np.pi * np.linspace(120, 40, int(SR * dur)) * t(dur)) * env(int(SR * dur), 0.001, dur * 0.9) * 0.9


def snare(dur=0.12):
    return lowpass(noise(dur), 0.6) * env(int(SR * dur), 0.001, dur * 0.8) * 0.5


def hat(dur=0.05):
    return (noise(dur) - lowpass(noise(dur), 0.5)) * env(int(SR * dur), 0.001, dur) * 0.2


def render(patterns, bpm, bars, beats_per_bar=4, subdiv=4):
    """patterns: list of (track_fn, steps) where steps is list over bar*subdiv*beats of
    None or (note, dur_steps). track_fn(note_or_None, dur_sec) -> samples."""
    step = 60 / bpm / subdiv
    total = int(SR * step * subdiv * beats_per_bar * bars) + SR
    out = np.zeros(total)
    nsteps = subdiv * beats_per_bar * bars
    for fn, steps in patterns:
        for i in range(nsteps):
            ev = steps[i % len(steps)]
            if ev is None:
                continue
            note, durst = ev
            smp = fn(note, durst * step)
            start = int(i * step * SR)
            end = min(total, start + len(smp))
            out[start:end] += smp[:end - start]
    return out[:int(SR * step * nsteps)]


def gen_music():
    np.random.seed(11)
    sq = lambda n, d: synth_note(freq(n), d, "square", 0.13, 3)
    lead = lambda n, d: synth_note(freq(n), d, "saw", 0.11, 2)
    bass = lambda n, d: synth_note(freq(n), d, "tri", 0.30, 1.5)
    drum = {"k": lambda n, d: kick(), "s": lambda n, d: snare(), "h": lambda n, d: hat()}
    D = lambda pat: (lambda n, d: drum[n](n, d), pat)

    # ---- Menu: D minor, 80 BPM, ominous drone + sparse melody ----
    drone_steps = []
    for bar in range(4):
        drone_steps += [("D2", 16)] + [None] * 15
    mel = ["D4", None, None, None, "F4", None, None, None, "E4", None, None, None, None, None, "A3", None,
           "D4", None, None, None, "C4", None, None, None, "D4", None, None, None, None, None, None, None]
    mel_steps = [(m, 3) if m else None for m in mel] * 2
    menu = render([(bass, drone_steps), (sq, mel_steps)], 80, 4)
    save("menu", menu * 0.8, "music")

    # ---- March/Arena: E minor, 100 BPM, driving ----
    bassline = ["E2", None, "E2", None, "G2", None, "E2", None, "A2", None, "A2", None, "B2", None, "D3", None]
    bass_steps = [(b, 2) if b else None for b in bassline] * 4
    kicks = ["k", None, None, None, "k", None, None, None, "k", None, None, None, "k", None, "s", None]
    kick_steps = [(k, 1) if k else None for k in kicks] * 4
    hats = [None, None, "h", None] * 16
    hat_steps = [(h, 1) if h else None for h in hats]
    arp = ["E4", "G4", "B4", "G4", "E4", "G4", "B4", "E5", "A4", "C5", "E5", "C5", "B4", "D5", "F#4", "B4"]
    arp_steps = [(a, 1) for a in arp] * 4
    march = render([(bass, bass_steps), D(kick_steps), D(hat_steps), (sq, arp_steps)], 100, 8)
    save("march", march * 0.85, "music")

    # ---- Boss: G minor, 140 BPM, relentless ----
    bassline = ["G2", "G2", None, "G2", "A#2", None, "G2", None, "C3", "C3", None, "C3", "D3", None, "F3", "D3"]
    bass_steps = [(b, 1) if b else None for b in bassline] * 4
    kicks = ["k", None, "k", None, "k", None, "k", None, "k", None, "k", "s", "k", None, "k", "s"]
    kick_steps = [(k, 1) if k else None for k in kicks] * 4
    leadline = ["G4", None, "A#4", "G4", "D5", None, "C5", "A#4", "C5", None, "D5", "F5", "D5", "C5", "A#4", "G4",
                "G4", None, "A#4", "G4", "F5", None, "D#5", "D5", "D#5", None, "D5", "C5", "A#4", "C5", "D5", None]
    lead_steps = [(m, 2) if m else None for m in leadline] * 2
    boss = render([(bass, bass_steps), D(kick_steps), (lead, lead_steps)], 140, 8)
    save("boss", boss * 0.85, "music")

    # ---- Victory sting: E major swell ----
    v = np.concatenate([synth_note(freq(n), 0.22, "square", 0.2, 2) for n in ["E4", "G#4", "B4", "E5"]])
    v = np.concatenate([v, synth_note(freq("E5"), 0.8, "saw", 0.25, 3) + synth_note(freq("B4"), 0.8, "square", 0.15, 3)])
    save("victory", v, "music")

    # ---- Game over: descending drone ----
    g = sweep(220, 55, 2.5, "saw") * env(int(SR * 2.5), 0.1, 2.2, sustain=0.3) * 0.4
    save("gameover", distort(g, 2.0), "music")


if __name__ == "__main__":
    os.makedirs(f"{ROOT}/sfx", exist_ok=True)
    os.makedirs(f"{ROOT}/music", exist_ok=True)
    gen_sfx()
    gen_music()
    print("audio OK")

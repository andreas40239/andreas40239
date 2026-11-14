#!/usr/bin/env python3
"""Erzeugt alle Texturen des Spiels prozedural (kachelbar, ohne Fremdmaterial).

Aufruf:  python3 tools/gen_textures.py
Ausgabe: assets/textures/*.png
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def fbm(n, beta=2.0, seed=0, lo=1, hi=None):
    """Kachelbares Rauschen über gefiltertes Spektrum (1/f^beta)."""
    r = np.random.default_rng(seed)
    f = np.fft.fft2(r.standard_normal((n, n)))
    fx = np.fft.fftfreq(n)[:, None] * n
    fy = np.fft.fftfreq(n)[None, :] * n
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1
    amp = 1.0 / k ** (beta / 2.0)
    amp[k < lo] = 0
    if hi:
        amp[k > hi] = 0
    amp[0, 0] = 0
    out = np.real(np.fft.ifft2(f * amp))
    out -= out.min()
    out /= out.max()
    return out


def save(name, arr):
    arr = np.clip(arr, 0, 1)
    Image.fromarray((arr * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, name), optimize=True)
    print("wrote", name, arr.shape)


def lerp(a, b, t):
    return a + (b - a) * t


def grass(n=512):
    """Helligkeits-Detailtextur für Wiesen (wird mit der Vertex-Farbe multipliziert)."""
    big = fbm(n, 2.6, 1, 1, 12)
    mid = fbm(n, 1.6, 2, 8, 60)
    fine = fbm(n, 0.6, 3, 40, 256)
    # kurze, gerichtete Halme
    blades = np.zeros((n, n))
    r = np.random.default_rng(4)
    for _ in range(5200):
        x, y = r.integers(0, n, 2)
        ln = r.integers(3, 8)
        dx = r.integers(-1, 2)
        v = r.uniform(-0.35, 0.5)
        for i in range(ln):
            blades[(y - i) % n, (x + (dx * i) // 3) % n] += v * (1 - i / ln)
    v = 0.80 + 0.16 * (big - 0.5) * 2 + 0.10 * (mid - 0.5) * 2 + 0.07 * (fine - 0.5) * 2 + 0.07 * np.clip(blades, -1, 1)
    # leichte Farbvariation: gelblich in hellen, bläulich in dunklen Bereichen
    rgb = np.stack([v * (1.0 + 0.05 * (big - 0.5)), v, v * (1.0 - 0.10 * (big - 0.5))], -1)
    save("grass.png", rgb)


def gravel(n=512):
    """Schotter: Voronoi-Steinchen mit Helligkeits- und Farbstreuung."""
    r = np.random.default_rng(11)
    cnt = 2600
    pts = r.uniform(0, n, (cnt, 2))
    tone = r.uniform(0.62, 1.0, cnt)
    warm = r.uniform(-0.05, 0.05, cnt)
    yy, xx = np.mgrid[0:n, 0:n]
    d1 = np.full((n, n), 1e9)
    d2 = np.full((n, n), 1e9)
    idx = np.zeros((n, n), dtype=np.int32)
    cell = 32
    # Rasterweise nur Punkte aus der Nachbarschaft prüfen (mit Umbruch -> kachelbar)
    grid = {}
    for i, (px, py) in enumerate(pts):
        grid.setdefault((int(px) // cell, int(py) // cell), []).append(i)
    gc = n // cell
    for gy in range(gc):
        for gx in range(gc):
            ys = slice(gy * cell, (gy + 1) * cell)
            xs = slice(gx * cell, (gx + 1) * cell)
            sx = xx[ys, xs].astype(np.float64)
            sy = yy[ys, xs].astype(np.float64)
            b1 = np.full(sx.shape, 1e9)
            b2 = np.full(sx.shape, 1e9)
            bi = np.zeros(sx.shape, dtype=np.int32)
            for oy in (-1, 0, 1):
                for ox in (-1, 0, 1):
                    for i in grid.get(((gx + ox) % gc, (gy + oy) % gc), []):
                        px, py = pts[i]
                        ddx = np.abs(sx - px)
                        ddx = np.minimum(ddx, n - ddx)
                        ddy = np.abs(sy - py)
                        ddy = np.minimum(ddy, n - ddy)
                        d = np.sqrt(ddx * ddx + ddy * ddy)
                        closer = d < b1
                        b2 = np.where(closer, b1, np.minimum(b2, d))
                        bi = np.where(closer, i, bi)
                        b1 = np.where(closer, d, b1)
            d1[ys, xs] = b1
            d2[ys, xs] = b2
            idx[ys, xs] = bi
    edge = np.clip((d2 - d1) / 3.0, 0, 1)          # 0 an Steinkanten
    dome = np.clip(1.0 - d1 / 7.0, 0, 1) * 0.18     # leichte Wölbung
    v = tone[idx] * (0.55 + 0.45 * edge) + dome
    v = 0.25 + 0.75 * v
    w = warm[idx]
    rgb = np.stack([v * (1 + w), v, v * (1 - w)], -1)
    save("gravel.png", rgb * 0.95)


def asphalt(n=256):
    fine = fbm(n, 0.3, 21, 30, 128)
    mid = fbm(n, 2.0, 22, 2, 20)
    r = np.random.default_rng(23)
    speck = (r.uniform(0, 1, (n, n)) > 0.985) * 0.25
    v = 0.86 + 0.12 * (fine - 0.5) * 2 + 0.06 * (mid - 0.5) * 2 + speck
    save("asphalt.png", np.stack([v, v, v * 1.02], -1))



def puff(n=128):
    """Weiche Rauchwolke (RGBA) für Dampf-Partikel."""
    yy, xx = np.mgrid[0:n, 0:n]
    cx = (xx - n / 2 + 0.5) / (n / 2)
    cy = (yy - n / 2 + 0.5) / (n / 2)
    rr = np.sqrt(cx * cx + cy * cy)
    lump = fbm(n, 2.2, 41, 2, 14)
    a = np.clip(1.0 - rr * (0.95 + 0.5 * (lump - 0.5)), 0, 1)
    a = a ** 1.4
    shade = 0.82 + 0.18 * np.clip(-cy * 0.8 + 0.5, 0, 1)
    rgba = np.stack([shade, shade, shade, a], -1)
    save("puff.png", rgba)


def water_noise(n=256):
    a = fbm(n, 2.2, 51, 2, 24)
    b = fbm(n, 1.8, 52, 4, 40)
    c = fbm(n, 2.0, 53, 1, 8)
    save("water_noise.png", np.stack([a, b, c], -1))




if __name__ == "__main__":
    grass()
    gravel()
    asphalt()
    puff()
    water_noise()

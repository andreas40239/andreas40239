#!/usr/bin/env python3
"""Procedural 2D asset generator for "Zombie in Athen".

Everything (textures, HUD icons, menu art, app icon) is drawn from scratch with
Pillow + numpy, so the output is licence-free.  The script is deterministic
(fixed seed, one independent random stream per asset).

Usage (from the project root):
    python3 tools/gen_graphics.py            # (re)generate everything
    python3 tools/gen_graphics.py icons      # only one group: textures | icons | ui
"""
import math
import os
import sys
import zlib

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

SEED = 40239
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
DIR_TEX = os.path.join(ASSETS, "textures")
DIR_ICO = os.path.join(ASSETS, "icons")
DIR_UI = os.path.join(ASSETS, "ui")

LANCZOS = Image.LANCZOS
BICUBIC = Image.BICUBIC

OUT = (16, 13, 22)  # dark outline colour of all icons


# --------------------------------------------------------------------------
# generic helpers
# --------------------------------------------------------------------------
def rng_for(name):
    """Independent deterministic random stream per asset."""
    return np.random.default_rng([SEED, zlib.crc32(name.encode("utf-8"))])


def smoothstep(e0, e1, x):
    t = np.clip((np.asarray(x, dtype=np.float32) - e0) / float(e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def norm01(a):
    lo, hi = float(a.min()), float(a.max())
    return (a - lo) / (hi - lo + 1e-9)


def vnoise(rng, h, w, cy, cx):
    """Periodic (tileable) value noise, cy x cx lattice cells over h x w px."""
    cy, cx = int(max(1, min(cy, h))), int(max(1, min(cx, w)))
    g = rng.random((cy, cx)).astype(np.float32)
    ys = (np.arange(h, dtype=np.float32) + 0.5) / h * cy
    xs = (np.arange(w, dtype=np.float32) + 0.5) / w * cx
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = (fy * fy * (3 - 2 * fy))[:, None]
    fx = (fx * fx * (3 - 2 * fx))[None, :]
    y0 %= cy
    x0 %= cx
    y1 = (y0 + 1) % cy
    x1 = (x0 + 1) % cx
    a = g[np.ix_(y0, x0)]
    b = g[np.ix_(y0, x1)]
    c = g[np.ix_(y1, x0)]
    d = g[np.ix_(y1, x1)]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(rng, h, w, cy, cx, octaves=4, gain=0.5):
    """Tileable fractal noise, normalised to 0..1."""
    out = np.zeros((h, w), np.float32)
    amp = 1.0
    for _ in range(octaves):
        out += amp * vnoise(rng, h, w, cy, cx)
        amp *= gain
        cy *= 2
        cx *= 2
    return norm01(out)


def lerp(a, b, t):
    """Blend two RGB colours with a 2D weight map -> (h, w, 3) float array."""
    a = np.asarray(a, np.float32)
    b = np.asarray(b, np.float32)
    return a + (b - a) * t[..., None]


def to_img(arr, mode="RGB"):
    return Image.fromarray(np.clip(arr + 0.5, 0, 255).astype(np.uint8), mode)


def down_tile(im, out):
    """Downsample a tileable image without breaking the seam (wrap padding)."""
    w = im.size[0]
    f = w // out
    pad = 8 * f
    a = np.asarray(im)
    a = np.pad(a, ((pad, pad), (pad, pad), (0, 0)), mode="wrap")
    big = Image.fromarray(a).resize(((w + 2 * pad) // f, (w + 2 * pad) // f), LANCZOS)
    p = pad // f
    return big.crop((p, p, p + out, p + out))


def save(im, folder, name):
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, name)
    im.save(path, optimize=True)
    return path


def chaikin(pts, n=3, closed=True):
    """Corner-cutting curve smoothing."""
    p = np.asarray(pts, dtype=np.float64)
    for _ in range(n):
        if closed:
            nxt = np.roll(p, -1, axis=0)
            q = 0.75 * p + 0.25 * nxt
            r = 0.25 * p + 0.75 * nxt
            p = np.stack([q, r], axis=1).reshape(-1, 2)
        else:
            a, b = p[:-1], p[1:]
            q = 0.75 * a + 0.25 * b
            r = 0.25 * a + 0.75 * b
            mid = np.stack([q, r], axis=1).reshape(-1, 2)
            p = np.vstack([p[:1], mid, p[-1:]])
    return [tuple(v) for v in p]


def dilate(alpha, px):
    """Round-ish dilation of an 'L' mask by ~px pixels (blur + threshold steps)."""
    steps = max(1, int(round(px / 3.0)))
    r = px / steps / 1.75
    a = alpha
    for _ in range(steps):
        a = a.filter(ImageFilter.GaussianBlur(r)).point(lambda v: 255 if v > 10 else 0)
    return a.filter(ImageFilter.GaussianBlur(0.8))


def add_outline(im, px, col=OUT, alpha=255):
    a = dilate(im.getchannel("A"), px)
    if alpha != 255:
        a = a.point(lambda v: v * alpha // 255)
    base = Image.new("RGBA", im.size, col + (0,))
    base.putalpha(a)
    base.alpha_composite(im)
    return base


class Cv:
    """Supersampled drawing canvas; all coordinates are in final-pixel units."""

    def __init__(self, w, h=None, ss=4, mode="RGBA"):
        self.w, self.h, self.ss, self.mode = w, h or w, ss, mode
        self.im = Image.new(mode, (self.w * ss, self.h * ss), 0 if mode == "L" else (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def sub(self, mode=None):
        return Cv(self.w, self.h, self.ss, mode or self.mode)

    def P(self, pts):
        s = self.ss
        return [(x * s, y * s) for x, y in pts]

    def poly(self, pts, fill):
        self.d.polygon(self.P(pts), fill=fill)

    def ell(self, cx, cy, rx, ry, fill):
        s = self.ss
        self.d.ellipse([(cx - rx) * s, (cy - ry) * s, (cx + rx) * s, (cy + ry) * s], fill=fill)

    def circ(self, cx, cy, r, fill):
        self.ell(cx, cy, r, r, fill)

    def rect(self, x0, y0, x1, y1, fill, r=0):
        s = self.ss
        box = [x0 * s, y0 * s, x1 * s, y1 * s]
        if r > 0:
            self.d.rounded_rectangle(box, radius=r * s, fill=fill)
        else:
            self.d.rectangle(box, fill=fill)

    def line(self, pts, fill, w, caps=True):
        s = self.ss
        self.d.line(self.P(pts), fill=fill, width=max(1, int(round(w * s))), joint="curve")
        if caps:
            ends = pts if len(pts) <= 12 else (pts[0], pts[-1])
            for (x, y) in ends:
                self.circ(x, y, w / 2.0, fill)

    def arc(self, cx, cy, r, a0, a1, fill, w, ry=None):
        ry = r if ry is None else ry
        n = max(8, int(abs(a1 - a0) / 4))
        pts = [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
                cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]
        self.line(pts, fill, w)

    def rot_ell(self, cx, cy, rx, ry, deg, fill):
        ca, sa = math.cos(math.radians(deg)), math.sin(math.radians(deg))
        pts = []
        for i in range(40):
            t = 2 * math.pi * i / 40
            x, y = rx * math.cos(t), ry * math.sin(t)
            pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
        self.poly(pts, fill)

    def comp(self, other):
        self.im.alpha_composite(other.im if isinstance(other, Cv) else other)

    def clip(self, mask, paint):
        """Composite `paint` (RGBA Cv) restricted to `mask` (L Cv)."""
        a = ImageChops.multiply(paint.im.getchannel("A"), mask.im)
        paint.im.putalpha(a)
        self.im.alpha_composite(paint.im)

    def erase(self, mask):
        a = ImageChops.subtract(self.im.getchannel("A"), mask.im)
        self.im.putalpha(a)
        self.d = ImageDraw.Draw(self.im)

    def rotate(self, deg, center=None):
        s = self.ss
        c = None if center is None else (center[0] * s, center[1] * s)
        self.im = self.im.rotate(deg, resample=BICUBIC, center=c)
        self.d = ImageDraw.Draw(self.im)

    def outline(self, w=5.0, col=OUT):
        self.im = add_outline(self.im, w * self.ss, col)
        self.d = ImageDraw.Draw(self.im)

    def finish(self, outline=5.0, col=OUT):
        im = self.im
        if outline:
            im = add_outline(im, outline * self.ss, col)
        return im.resize((self.w, self.h), LANCZOS)


def drop_pts(cx, cy, r, tip_h=2.1):
    """Teardrop polygon: round bottom centred on (cx, cy), tip above."""
    pts = [(cx, cy - r * tip_h)]
    for i in range(0, 41):
        a = math.radians(-35 + (250.0 * i / 40))
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def heart_pts(cx, cy, s, n=160):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((cx + x * s, cy + y * s))
    return pts


def star4(c, cx, cy, r, fill, inner=0.32):
    pts = []
    for i in range(8):
        a = math.pi / 4 * i - math.pi / 2
        rr = r if i % 2 == 0 else r * inner
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    c.poly(pts, fill)


# --------------------------------------------------------------------------
# textures (drawn at 512 px, wrapped-downsampled to 256 px)
# --------------------------------------------------------------------------
T = 512
TEX_OUT = 256


def _grid():
    yy, xx = np.mgrid[0:T, 0:T]
    return yy, xx


def tex_floor_wood():
    rng = rng_for("floor_wood")
    yy, xx = _grid()
    rh, pl = 64, 256                      # plank width / length in px (12.5 cm x 1 m... x2 ss)
    rows = T // rh
    offs = np.array([0, 96, 192, 48, 144, 232, 72, 168])
    row = yy // rh
    xo = (xx - offs[row]) % T
    pid = row * 2 + xo // pl
    npl = rows * 2
    tint = rng.uniform(-1, 1, npl)[pid].astype(np.float32)
    warm = rng.uniform(-1, 1, npl)[pid].astype(np.float32)
    sx = rng.integers(0, T, npl)[pid]
    sy = rng.integers(0, T, npl)[pid]
    g = fbm(rng, T, T, 72, 3, 4)          # long fibres along x
    g2 = fbm(rng, T, T, 10, 2, 3)
    gs = g[(yy + sy) % T, (xx + sx) % T]
    gw = g2[(yy + sy) % T, (xx + sx) % T]
    rings = 0.5 + 0.5 * np.sin(2 * np.pi * (gw * 5.0 + (yy % rh) / rh * 1.5))
    val = 0.55 * gs + 0.45 * rings
    col = lerp((140, 88, 48), (206, 150, 92), val)
    col *= (1.0 + 0.11 * tint)[..., None]
    col[..., 0] += 9 * warm
    col[..., 2] -= 7 * warm
    # fine fibre streaks
    fib = vnoise(rng, T, T, 256, 12)
    col *= (0.955 + 0.09 * fib)[..., None]
    # gaps + bevel
    dy = yy % rh
    dx = xo % pl
    gap = np.maximum(np.where((dy < 2) | (dy >= rh - 2), 1.0, 0.0),
                     np.where((dx < 2) | (dx >= pl - 2), 1.0, 0.0))
    hi = np.where((dy >= 2) & (dy < 5), 1.0, 0.0)
    lo = np.where((dy >= rh - 6) & (dy < rh - 2), 1.0, 0.0)
    col *= (1 + 0.07 * hi - 0.09 * lo)[..., None]
    col = col * (1 - gap[..., None]) + np.array([62, 38, 22], np.float32) * gap[..., None]
    return down_tile(to_img(col), TEX_OUT)


def _tile_bevel(yy, xx, ts, grout):
    """Returns (tile index y, x, grout mask, highlight, shadow) for a square tile grid."""
    ty, tx = yy // ts, xx // ts
    dy, dx = yy % ts, xx % ts
    h = grout / 2.0
    edge = np.minimum(np.minimum(dy, ts - 1 - dy), np.minimum(dx, ts - 1 - dx)).astype(np.float32)
    gmask = 1.0 - smoothstep(h - 1.0, h + 1.0, edge)
    hi = (((dy < h + 4) | (dx < h + 4)) & (edge >= h)).astype(np.float32)
    lo = (((dy > ts - 1 - h - 4) | (dx > ts - 1 - h - 4)) & (edge >= h)).astype(np.float32)
    return ty, tx, gmask, hi, lo


def tex_floor_bath():
    rng = rng_for("floor_bath")
    yy, xx = _grid()
    ts = 64
    n = T // ts
    ty, tx, gmask, hi, lo = _tile_bevel(yy, xx, ts, 7)
    kind = (rng.random((n, n)) < 0.42)
    # keep it a loose mosaic: light tiles + pale blue tiles
    shade = rng.uniform(-1, 1, (n, n))
    k = kind[ty, tx].astype(np.float32)
    s = shade[ty, tx].astype(np.float32)
    col = lerp((226, 236, 240), (158, 200, 226), k)
    col *= (1 + 0.035 * s)[..., None]
    # soft glossy gradient inside each tile
    gy = (yy % ts) / ts
    gx = (xx % ts) / ts
    col *= (1.03 - 0.06 * (0.6 * gy + 0.4 * gx))[..., None]
    col *= (1 + 0.05 * hi - 0.07 * lo)[..., None]
    mott = fbm(rng, T, T, 6, 6, 3)
    col *= (0.975 + 0.05 * mott)[..., None]
    grout = lerp((128, 140, 146), (150, 160, 162), fbm(rng, T, T, 24, 24, 2))
    col = col * (1 - gmask[..., None]) + grout * gmask[..., None]
    return down_tile(to_img(col), TEX_OUT)


def tex_floor_kitchen():
    rng = rng_for("floor_kitchen")
    yy, xx = _grid()
    ts = 64
    ty, tx, gmask, hi, lo = _tile_bevel(yy, xx, ts, 4)
    black = ((ty + tx) % 2 == 0).astype(np.float32)
    n = T // ts
    s = rng.uniform(-1, 1, (n, n))[ty, tx].astype(np.float32)
    wear = fbm(rng, T, T, 5, 5, 4)
    wear2 = fbm(rng, T, T, 20, 20, 3)
    cream = lerp((232, 220, 188), (202, 186, 152), smoothstep(0.45, 0.9, wear) * 0.7)
    dark = lerp((40, 40, 46), (78, 76, 76), smoothstep(0.5, 0.9, wear) * 0.6)
    col = cream * (1 - black[..., None]) + dark * black[..., None]
    col *= (1 + 0.04 * s)[..., None]
    col *= (0.95 + 0.10 * wear2)[..., None]
    col *= (1 + 0.05 * hi - 0.07 * lo)[..., None]
    im = to_img(col)
    # scratches (wrapped)
    d = ImageDraw.Draw(im, "RGBA")
    for _ in range(46):
        x, y = rng.uniform(0, T, 2)
        a = rng.uniform(0, math.pi)
        ln = rng.uniform(14, 60)
        x2, y2 = x + ln * math.cos(a), y + ln * math.sin(a)
        c = (150, 140, 120, int(rng.uniform(30, 70)))
        for ox in (-T, 0, T):
            for oy in (-T, 0, T):
                d.line([(x + ox, y + oy), (x2 + ox, y2 + oy)], fill=c, width=1)
    col = np.asarray(im).astype(np.float32)
    grout = np.array([104, 98, 88], np.float32)
    col = col * (1 - gmask[..., None]) + grout * gmask[..., None]
    return down_tile(to_img(col), TEX_OUT)


def tex_floor_hall():
    rng = rng_for("floor_hall")
    base = lerp((196, 180, 150), (210, 196, 166), fbm(rng, T, T, 6, 6, 4))
    im = to_img(base)
    d = ImageDraw.Draw(im)
    palette = [(238, 230, 208), (246, 242, 232), (150, 112, 80), (92, 88, 84), (168, 100, 70),
               (132, 142, 126), (204, 166, 98), (224, 206, 170), (116, 96, 84), (176, 170, 160)]
    weights = np.array([0.2, 0.16, 0.12, 0.1, 0.07, 0.06, 0.07, 0.12, 0.05, 0.05])
    chips = []
    for _ in range(1500):
        u = rng.random()
        r = 2.0 + 4.0 * u if rng.random() < 0.72 else 6.0 + 9.0 * u
        chips.append((r, rng.uniform(0, T), rng.uniform(0, T),
                      palette[int(rng.choice(len(palette), p=weights / weights.sum()))]))
    chips.sort(key=lambda c: -c[0])
    for r, cx, cy, colr in chips:
        nv = int(rng.integers(4, 8))
        a0 = rng.uniform(0, 2 * math.pi)
        sq = rng.uniform(0.55, 1.0)
        rot = rng.uniform(0, math.pi)
        pts = []
        for i in range(nv):
            a = a0 + 2 * math.pi * (i + rng.uniform(-0.25, 0.25)) / nv
            rr = r * rng.uniform(0.7, 1.0)
            x, y = rr * math.cos(a), rr * math.sin(a) * sq
            pts.append((x * math.cos(rot) - y * math.sin(rot), x * math.sin(rot) + y * math.cos(rot)))
        jit = rng.uniform(-10, 10)
        c = tuple(int(np.clip(v + jit, 0, 255)) for v in colr)
        for ox in (-T, 0, T):
            if cx + ox < -r - 2 or cx + ox > T + r + 2:
                continue
            for oy in (-T, 0, T):
                if cy + oy < -r - 2 or cy + oy > T + r + 2:
                    continue
                d.polygon([(cx + ox + x, cy + oy + y) for x, y in pts], fill=c)
    col = np.asarray(im).astype(np.float32)
    col *= (0.96 + 0.08 * fbm(rng, T, T, 4, 4, 3))[..., None]          # polish / wear clouds
    col += (rng.random((T, T, 1)).astype(np.float32) - 0.5) * 8
    return down_tile(to_img(col), TEX_OUT)


def tex_floor_carpet():
    rng = rng_for("floor_carpet")
    yy, xx = _grid()
    q = 4
    X = (xx // q) * q + q / 2.0
    Y = (yy // q) * q + q / 2.0
    P = 256.0
    dx = np.abs(((X / P) % 1.0) - 0.5) * 2
    dy = np.abs(((Y / P) % 1.0) - 0.5) * 2
    d = dx + dy
    ml = 64.0
    md = np.abs(((X / ml) % 1.0) - 0.5) * 2 + np.abs(((Y / ml) % 1.0) - 0.5) * 2
    RED, RED2, DARK = (134, 28, 32), (112, 20, 28), (64, 14, 20)
    CREAM, GOLD, NAVY = (216, 194, 148), (188, 144, 66), (36, 42, 76)
    col = np.zeros((T, T, 3), np.float32)

    def band(lo, hi, c):
        m = (d >= lo) & (d < hi)
        col[m] = c

    band(0.00, 0.10, CREAM)
    band(0.10, 0.22, NAVY)
    band(0.22, 0.32, GOLD)
    band(0.32, 0.80, RED)
    band(0.80, 0.86, CREAM)
    band(0.86, 0.96, DARK)
    band(0.96, 1.04, GOLD)
    band(1.04, 1.14, DARK)
    band(1.14, 1.20, CREAM)
    band(1.20, 1.78, RED2)
    band(1.78, 1.90, NAVY)
    band(1.90, 2.01, GOLD)
    # small diamond motifs inside the two red fields
    f1 = (d >= 0.40) & (d < 0.72)
    f2 = (d >= 1.28) & (d < 1.70)
    col[f1 & (md < 0.34)] = GOLD
    col[f1 & (md < 0.14)] = NAVY
    col[f2 & (md < 0.34)] = CREAM
    col[f2 & (md < 0.14)] = DARK
    # woven look
    knots = 1.0 + 0.055 * np.sin(2 * np.pi * yy / 8.0) + 0.04 * np.sin(2 * np.pi * xx / 8.0)
    col *= knots[..., None]
    col *= (0.90 + 0.20 * fbm(rng, T, T, 5, 5, 3))[..., None]
    col *= (0.93 + 0.14 * rng.random((T, T, 1)).astype(np.float32))
    return down_tile(to_img(col), TEX_OUT)


def tex_wall_plaster():
    rng = rng_for("wall_plaster")
    stain = fbm(rng, T, T, 3, 3, 5)
    damp = fbm(rng, T, T, 2, 4, 4)
    mott = fbm(rng, T, T, 28, 28, 3)
    col = lerp((232, 227, 212), (216, 207, 186), smoothstep(0.30, 0.95, stain))
    col = col * (1 - 0.07 * smoothstep(0.60, 0.95, damp))[..., None]
    col[..., 2] -= 5 * smoothstep(0.6, 0.95, damp)
    col *= (0.965 + 0.07 * mott)[..., None]
    # trowel strokes: soft elongated streaks
    strokes = fbm(rng, T, T, 40, 6, 2)
    col *= (0.975 + 0.05 * strokes)[..., None]
    col += (rng.random((T, T, 1)).astype(np.float32) - 0.5) * 7
    return down_tile(to_img(col), TEX_OUT)


def tex_wood_furniture():
    rng = rng_for("wood_furniture")
    yy, xx = _grid()
    warp = fbm(rng, T, T, 2, 3, 3)
    t = xx / T * 10.0 + warp * 2.0
    fr = t % 1.0
    ring = np.abs(fr - 0.5) * 2                      # 0..1 triangle wave
    ring = ring ** 1.6
    col = lerp((80, 47, 27), (126, 79, 46), ring)
    fib = vnoise(rng, T, T, 14, 200)
    col *= (0.90 + 0.20 * fib)[..., None]
    tone = fbm(rng, T, T, 2, 3, 3)
    col *= (0.92 + 0.16 * tone)[..., None]
    col[..., 0] += 8 * tone
    return down_tile(to_img(col), TEX_OUT)


def tex_fabric_bed():
    rng = rng_for("fabric_bed")
    yy, xx = _grid()
    p = 128
    u = xx % p
    blue = ((u >= 14) & (u < 62)) | ((u >= 78) & (u < 87)) | ((u >= 108) & (u < 117))
    b = blue.astype(np.float32)
    b = np.asarray(Image.fromarray((b * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.9)),
                   dtype=np.float32) / 255.0
    # blur does not wrap -> recompute the border columns from the periodic pattern
    b[:, :4] = b[:, p:p + 4]
    b[:, -4:] = b[:, p - 4:p]
    col = lerp((236, 238, 240), (46, 96, 176), b)
    weave = 0.5 + 0.5 * np.sin(2 * np.pi * xx / 8.0) * np.sin(2 * np.pi * yy / 8.0)
    col *= (0.95 + 0.07 * weave)[..., None]
    thread = vnoise(rng, T, T, 256, 256)
    col *= (0.965 + 0.07 * thread)[..., None]
    folds = fbm(rng, T, T, 3, 2, 3)
    col *= (0.88 + 0.20 * folds)[..., None]
    return down_tile(to_img(col), TEX_OUT)


TEXTURES = {
    "floor_wood.png": tex_floor_wood,
    "floor_bath.png": tex_floor_bath,
    "floor_kitchen.png": tex_floor_kitchen,
    "floor_hall.png": tex_floor_hall,
    "floor_carpet.png": tex_floor_carpet,
    "wall_plaster.png": tex_wall_plaster,
    "wood_furniture.png": tex_wood_furniture,
    "fabric_bed.png": tex_fabric_bed,
}


# --------------------------------------------------------------------------
# icons (192 px, drawn at 4x)
# --------------------------------------------------------------------------
IC = 192


def icon_freeze():
    c = Cv(IC)
    L, M, D = (232, 247, 255), (172, 218, 246), (112, 170, 226)
    # cuff
    c.rect(70, 150, 118, 178, D, r=7)
    c.rect(66, 146, 122, 160, M, r=6)
    # fingers
    fingers = [(52, 69, 52), (72, 89, 34), (92, 109, 38), (112, 128, 58)]
    for x0, x1, y0 in fingers:
        c.rect(x0, y0, x1, 122, L, r=8.4)
        c.rect(x1 - 5.5, y0 + 8, x1, 112, M, r=2.5)
    # thumb
    c.line([(60, 136), (36, 112), (28, 94)], L, 18)
    c.line([(34, 118), (26, 100)], M, 5)
    # palm
    c.rect(52, 96, 128, 156, L, r=20)
    m = c.sub("L")
    m.rect(52, 96, 128, 156, 255, r=20)
    p = c.sub()
    p.ell(104, 160, 44, 26, M + (255,))
    c.clip(m, p)
    c.d = ImageDraw.Draw(c.im)
    c.line(chaikin([(66, 126), (84, 134), (104, 128), (116, 114)], 3, closed=False), D, 4.2)
    c.line(chaikin([(74, 108), (88, 112), (102, 106)], 2, closed=False), D, 3.4)
    # ice sparkles
    star4(c, 158, 44, 17, L)
    star4(c, 164, 136, 11, L)
    star4(c, 26, 46, 12, L)
    return c.finish()


def icon_sneak():
    c = Cv(IC)
    L, M, D, W = (176, 240, 150), (116, 204, 112), (62, 148, 88), (238, 255, 226)
    # trouser leg
    c.poly([(46, 10), (90, 10), (95, 60), (51, 70)], D)
    c.poly([(48, 56), (95, 48), (97, 62), (50, 72)], M)
    # shoe on tiptoe (heel high in the air)
    foot = chaikin([(54, 66), (96, 60), (108, 90), (132, 116), (158, 130), (174, 146), (168, 162),
                    (128, 162), (94, 140), (58, 120), (42, 98), (48, 80)], 3)
    c.poly(foot, L)
    sole = chaikin([(44, 104), (60, 122), (94, 142), (126, 163), (166, 163)], 3, closed=False)
    c.line(sole, W, 7.5)
    c.line(chaikin([(104, 92), (120, 116), (116, 138)], 2, closed=False), M, 4.2)
    c.line([(96, 88), (109, 81)], M, 4.2)
    c.line([(103, 99), (117, 92)], M, 4.2)
    c.line(chaikin([(56, 80), (76, 76), (98, 72)], 2, closed=False), M, 4.2)
    # little lift arcs under the raised heel
    c.arc(128, 166, 50, 181, 204, W, 6)
    c.arc(128, 166, 70, 180, 199, W, 6)
    # "muted" sign: small speaker with a cross
    c.rect(118, 36, 131, 58, W, r=2)
    c.poly([(126, 38), (146, 22), (146, 72), (126, 56)], W)
    c.line([(158, 36), (178, 58)], W, 6.5)
    c.line([(178, 36), (158, 58)], W, 6.5)
    return c.finish()


def icon_hide():
    c = Cv(IC)
    A, AL, AD, AK = (255, 186, 52), (255, 214, 110), (214, 136, 28), (150, 88, 14)
    DK = (30, 20, 16)
    # feet, body, cornice
    c.rect(30, 156, 46, 174, AD, r=3)
    c.rect(124, 156, 140, 174, AD, r=3)
    c.rect(22, 28, 148, 164, AD, r=5)
    c.rect(16, 16, 154, 34, AL, r=5)
    # closed left door
    c.rect(29, 41, 83, 157, A, r=3)
    c.rect(36, 49, 76, 95, AD, r=3)
    c.rect(40, 53, 72, 91, A, r=2)
    c.rect(36, 103, 76, 149, AD, r=3)
    c.rect(40, 107, 72, 145, A, r=2)
    c.circ(77, 99, 4.2, AK)
    # open right half: dark interior with eyes
    c.rect(88, 41, 142, 157, DK, r=2)
    for ex in (103, 127):
        c.ell(ex, 86, 9.5, 11.5, (255, 255, 244))
        c.circ(ex - 2.5, 88, 5.0, (20, 16, 12))
        c.circ(ex - 4.2, 85.5, 1.7, (255, 255, 255))
    # swung-open right door (seen edge-on)
    c.poly([(142, 38), (172, 26), (172, 176), (142, 160)], AL)
    c.poly([(150, 48), (165, 42), (165, 160), (150, 150)], A)
    c.circ(148, 102, 3.6, AK)
    return c.finish()


def icon_unhide():
    c = Cv(IC)
    A, AL, AD, AK = (255, 186, 52), (255, 214, 110), (206, 128, 26), (150, 88, 14)
    DK = (30, 20, 16)
    # frame + dark opening
    c.rect(16, 14, 114, 176, AD, r=4)
    c.rect(27, 25, 103, 176, DK)
    # door leaf swung towards the viewer
    c.poly([(27, 25), (66, 40), (66, 186), (27, 176)], AL)
    c.poly([(33, 36), (60, 46), (60, 104), (33, 98)], A)
    c.poly([(33, 108), (60, 113), (60, 174), (33, 168)], A)
    c.circ(57, 112, 4.5, AK)
    c.outline(5)
    # arrow pointing out of the door
    a = c.sub()
    a.poly([(84, 86), (132, 86), (132, 62), (180, 100), (132, 138), (132, 114), (84, 114)], (255, 246, 206))
    a.poly([(84, 104), (132, 104), (132, 114), (84, 114)], (255, 214, 120))
    a.poly([(132, 114), (166, 111), (132, 138)], (255, 214, 120))
    a.outline(5)
    c.comp(a)
    return c.finish(outline=0)


def icon_bite():
    c = Cv(IC)
    LIP, LIP_L, IN = (196, 30, 42), (236, 78, 84), (46, 6, 14)
    TOO, TOO_S = (255, 250, 236), (214, 204, 180)
    cx, cy, rx, ry = 92.0, 80.0, 62.0, 42.0
    c.ell(cx, cy, rx + 17, ry + 17, LIP)
    # highlight on the upper lip
    m = c.sub("L")
    m.ell(cx, cy, rx + 17, ry + 17, 255)
    p = c.sub()
    p.ell(cx - 6, cy - 12, rx + 8, ry + 9, LIP_L + (255,))
    p.ell(cx, cy - 3, rx + 9, ry + 9, (0, 0, 0, 0))
    c.clip(m, p)
    c.d = ImageDraw.Draw(c.im)
    c.ell(cx, cy, rx, ry, IN)
    c.ell(cx, cy + 22, 34, 16, (120, 22, 40))          # tongue

    def edge(x, sign):
        v = max(0.0, 1.0 - (x / rx) ** 2)
        return cy + sign * ry * math.sqrt(v)

    def tooth(xc, w, ln, sign, lean=0.0):
        xa, xb = xc - w / 2, xc + w / 2
        ya, yb = edge(xa, sign) + sign * 3, edge(xb, sign) + sign * 3
        tip = (cx + xc + lean, cy + (edge(xc, sign) - cy) - sign * ln)
        c.poly([(cx + xa, ya), (cx + xb, yb), tip], TOO)
        c.poly([(cx + xc + w * 0.12, (ya + yb) / 2), (cx + xb, yb), tip], TOO_S)

    for xc, w, ln, lean in [(-50, 13, 14, 2), (-36, 15, 30, 2), (-20, 15, 21, 0), (-4, 15, 23, 0),
                            (12, 15, 21, 0), (28, 15, 31, -2), (43, 14, 17, -2), (54, 10, 10, -2)]:
        tooth(xc, w, ln, -1, lean)
    for xc, w, ln, lean in [(-46, 13, 13, 2), (-31, 15, 25, 1), (-14, 15, 18, 0), (20, 15, 19, 0),
                            (36, 15, 25, -1), (50, 12, 12, -2)]:
        tooth(xc, w, ln, 1, lean)
    c.outline(5)
    # blood drop
    b = c.sub()
    b.poly(drop_pts(148, 158, 16.5, 2.2), (238, 34, 46))
    b.ell(142, 160, 4.0, 6.5, (255, 170, 170))
    b.outline(5)
    c.comp(b)
    return c.finish(outline=0)


def icon_sprint():
    c = Cv(IC)
    O, OL, OD = (255, 146, 36), (255, 204, 112), (222, 104, 20)
    # speed lines
    for x0, x1, y in ((14, 70, 46), (6, 56, 78), (20, 52, 110)):
        c.line([(x0, y), (x1, y)], OL, 8.5)
    # back leg (darker), back arm
    c.line([(98, 110), (72, 126), (42, 126), (34, 136)], OD, 15)
    c.line([(118, 74), (146, 86), (168, 98)], OD, 12.5)
    # torso
    c.line([(124, 62), (98, 108)], O, 26)
    # front leg
    c.line([(100, 112), (128, 128), (120, 164), (138, 168)], O, 15)
    # front arm (zombie reach)
    c.line([(122, 64), (152, 60), (176, 68)], O, 12.5)
    # head
    c.circ(138, 34, 18, O)
    c.circ(145, 31, 3.6, OUT)
    return c.finish()


def icon_listen():
    c = Cv(IC)
    Y, YL, YD = (255, 218, 62), (255, 240, 150), (206, 150, 20)
    ear = chaikin([(96, 34), (126, 18), (158, 34), (170, 70), (160, 104), (146, 126), (142, 152),
                   (124, 172), (102, 164), (98, 142), (106, 120), (96, 100), (84, 66)], 3)
    c.poly(ear, Y)
    m = c.sub("L")
    m.poly(ear, 255)
    p = c.sub()
    p.ell(136, 60, 26, 30, YL + (255,))
    c.clip(m, p)
    c.d = ImageDraw.Draw(c.im)
    # helix + inner curl
    c.line(chaikin([(110, 116), (104, 86), (106, 58), (126, 42), (148, 54), (152, 84), (138, 108),
                    (126, 126), (124, 146)], 3, closed=False), YD, 7)
    c.line(chaikin([(120, 96), (120, 76), (132, 68), (138, 82), (130, 96)], 3, closed=False), YD, 6)
    # sound waves
    for r in (24, 44, 64):
        c.arc(84, 98, r, 140, 220, YL, 9)
    return c.finish()


def icon_garlic():
    c = Cv(IC)
    W, WS, PU, PUD = (248, 242, 228), (222, 208, 186), (206, 172, 226), (142, 100, 160)
    G = (132, 222, 96)
    # stink wisps
    for x0, ph, y0, y1 in ((24, 0.0, 52, 126), (168, 1.6, 44, 118), (142, 3.0, 14, 58)):
        pts = [(x0 + 7.5 * math.sin(ph + (y - y0) / 11.0), y) for y in np.linspace(y0, y1, 30)]
        c.line(pts, G, 7.5)
    # stem
    c.poly(chaikin([(88, 24), (104, 22), (106, 64), (86, 64)], 1), WS)
    body = chaikin([(96, 50), (118, 70), (148, 96), (156, 130), (136, 160), (96, 168), (56, 160),
                    (36, 130), (44, 96), (74, 70)], 3)
    c.poly(body, W)
    m = c.sub("L")
    m.poly(body, 255)
    p = c.sub()
    p.ell(52, 132, 22, 44, PU + (255,))
    p.ell(140, 132, 22, 44, PU + (255,))
    p.ell(66, 126, 22, 46, W + (255,))
    p.ell(126, 126, 22, 46, W + (255,))
    p.ell(96, 176, 46, 16, WS + (255,))
    c.clip(m, p)
    c.d = ImageDraw.Draw(c.im)
    # clove lines
    c.line(chaikin([(92, 60), (76, 90), (70, 128), (84, 164)], 3, closed=False), PUD, 4.5)
    c.line(chaikin([(100, 60), (116, 90), (122, 128), (108, 164)], 3, closed=False), PUD, 4.5)
    c.line(chaikin([(96, 76), (96, 120)], 1, closed=False), PU, 3.5)
    # roots
    for x0, x1 in ((86, 80), (96, 96), (106, 112)):
        c.line([(x0, 166), (x1, 178)], WS, 5)
    return c.finish()


def icon_souvlaki():
    c = Cv(IC)
    WOOD, WOOD_D = (226, 180, 108), (176, 128, 66)
    MEAT, MEAT_L, MEAT_D = (156, 86, 44), (196, 122, 66), (88, 44, 24)
    # skewer drawn horizontally, then rotated
    c.poly([(0, 91.5), (180, 91.5), (196, 96), (180, 100.5), (0, 100.5)], WOOD)
    c.rect(0, 97, 180, 100.5, WOOD_D)
    pieces = [("m", 36), ("g", 63), ("m", 90), ("r", 117), ("m", 144)]
    for kind, x in pieces:
        if kind == "m":
            c.rect(x - 19, 71, x + 19, 121, MEAT, r=9)
            c.rect(x - 15, 74, x + 15, 85, MEAT_L, r=5)
            c.line([(x - 10, 114), (x + 1, 93)], MEAT_D, 4.5)
            c.line([(x + 3, 114), (x + 14, 93)], MEAT_D, 4.5)
        elif kind == "g":
            c.rect(x - 7, 74, x + 7, 118, (106, 188, 72), r=6)
            c.rect(x - 4.5, 78, x + 0, 110, (160, 226, 110), r=2)
        else:
            c.rect(x - 7, 74, x + 7, 118, (226, 62, 48), r=6)
            c.rect(x - 4.5, 78, x + 0, 110, (255, 128, 104), r=2)
    c.rotate(34, center=(96, 96))
    # lemon wedge
    lx, ly, lr, rot = 150, 146, 31, math.radians(-28)

    def half(r, ox=0.0, oy=0.0):
        pts = []
        for i in range(0, 41):
            a = math.pi * i / 40
            x, y = r * math.cos(a) + ox, r * math.sin(a) + oy
            pts.append((lx + x * math.cos(rot) - y * math.sin(rot), ly + x * math.sin(rot) + y * math.cos(rot)))
        return pts

    c.poly(half(lr), (250, 206, 40))
    c.poly(half(lr - 6.5, 0, 2.5), (255, 246, 176))
    for i in (1, 2, 3):
        a = math.pi * i / 4
        x, y = (lr - 6) * math.cos(a), (lr - 6) * math.sin(a) + 2
        c.line([(lx - 2.5 * math.sin(rot), ly + 2.5 * math.cos(rot)),
                (lx + x * math.cos(rot) - y * math.sin(rot), ly + x * math.sin(rot) + y * math.cos(rot))],
               (250, 214, 70), 3.2)
    return c.finish()


def icon_melon():
    c = Cv(IC)
    ax, ay, R, half = 96.0, 14.0, 152.0, 33.0

    def sector(r, inset=0.0):
        pts = [(ax, ay + inset)]
        for i in range(0, 41):
            a = math.radians(90 - half + 2 * half * i / 40)
            pts.append((ax + r * math.cos(a), ay + r * math.sin(a)))
        return pts

    c.poly(sector(R), (38, 132, 58))
    c.poly(sector(R - 11), (214, 240, 176))
    c.poly(sector(R - 19), (236, 52, 66))
    # dark stripes on the rind
    for deg in (-26, -13, 0, 13, 26):
        a = math.radians(90 + deg)
        c.line([(ax + (R - 8.5) * math.cos(a), ay + (R - 8.5) * math.sin(a)),
                (ax + (R - 2.0) * math.cos(a), ay + (R - 2.0) * math.sin(a))], (18, 92, 44), 6)
    # flesh highlight
    m = c.sub("L")
    m.poly(sector(R - 19), 255)
    p = c.sub()
    p.poly([(ax, ay + 6), (ax - 16, ay + 60), (ax - 62, ay + 112), (ax - 80, ay + 112)], (255, 104, 110, 255))
    c.clip(m, p)
    c.d = ImageDraw.Draw(c.im)
    # seeds (teardrops pointing to the tip)
    for rad, degs in ((62, (-11, 11)), (92, (-19, 0, 19)), (119, (-23.5, -8, 8, 23.5))):
        for deg in degs:
            a = math.radians(90 + deg)
            sx, sy = ax + rad * math.cos(a), ay + rad * math.sin(a)
            ux, uy = math.cos(a), math.sin(a)
            px, py = -uy, ux
            pts = [(sx - ux * 9, sy - uy * 9)]
            for i in range(0, 21):
                t = math.radians(-90 + 180 * i / 20)
                pts.append((sx + ux * 5.5 * math.cos(t) * 1.0 + px * 5.2 * math.sin(t) + ux * 1.5,
                            sy + uy * 5.5 * math.cos(t) * 1.0 + py * 5.2 * math.sin(t) + uy * 1.5))
            c.poly(pts, (26, 16, 20))
    c.rotate(-9, center=(96, 96))
    return c.finish()


def icon_oil():
    c = Cv(IC)
    GL, GL_L, GL_D = (26, 94, 54), (60, 142, 80), (16, 66, 42)
    OIL, OIL_L, OIL_D = (214, 200, 50), (244, 234, 120), (176, 158, 30)
    CORK, CORK_D = (222, 174, 110), (170, 120, 66)
    LAB, LAB_S, LAB_G = (252, 244, 222), (226, 210, 176), (206, 160, 60)
    LEAF, LEAF_D, STEM = (132, 190, 88), (78, 138, 66), (128, 96, 56)
    OLV, OLV_L = (70, 52, 96), (128, 104, 160)
    bx = 60.0                                             # bottle axis

    def bottle(k, inset, fill):
        k.rect(bx - 38 + inset, 84, bx + 38 - inset, 178 - inset, fill, r=max(2, 12 - inset))
        k.ell(bx, 98, 38 - inset, 32 - inset, fill)
        k.rect(bx - 14 + inset, 34, bx + 14 - inset, 86, fill)

    # cork, glass
    c.rect(bx - 11, 10, bx + 11, 36, CORK, r=3)
    c.rect(bx - 11, 26, bx + 11, 36, CORK_D)
    c.rect(bx - 11, 10, bx - 4, 30, (240, 204, 148), r=3)
    bottle(c, 0, GL)
    c.rect(bx - 19, 30, bx + 19, 44, GL, r=5)             # lip ring
    c.rect(bx - 19, 30, bx + 19, 36, GL_L, r=3)
    # contents: empty glass above, golden-green oil below
    m = c.sub("L")
    bottle(m, 7, 255)
    p = c.sub()
    p.rect(0, 0, IC, 82, GL_L + (255,))
    p.rect(0, 82, IC, IC, OIL + (255,))
    p.rect(0, 82, IC, 88, OIL_L + (255,))
    p.rect(bx + 14, 88, IC, IC, OIL_D + (255,))           # shaded right side
    c.clip(m, p)
    c.d = ImageDraw.Draw(c.im)
    # glass shade (right) and highlight (left)
    c.line([(bx + 9, 48), (bx + 9, 74)], GL_D, 4)
    c.line([(bx - 8, 50), (bx - 8, 72)], (196, 240, 190), 4.5)
    c.line(chaikin([(bx - 12, 82), (bx - 24, 90), (bx - 27, 104)], 2, closed=False), (255, 250, 190), 5)
    # label with a little olive
    c.rect(bx - 38, 108, bx + 38, 158, LAB)
    c.rect(bx + 22, 108, bx + 38, 158, LAB_S)
    c.rect(bx - 38, 108, bx + 38, 113, LAB_G)
    c.rect(bx - 38, 153, bx + 38, 158, LAB_G)
    c.rot_ell(bx - 16, 127, 12, 5, -28, LEAF_D)
    c.rot_ell(bx + 14, 125, 12, 5, 24, LEAF_D)
    c.ell(bx, 136, 9, 11.5, (104, 150, 56))
    c.ell(bx - 3, 132, 2.6, 4, (190, 222, 120))
    c.line([(bx - 6, 164), (bx - 26, 164)], OIL_L, 4)
    # olive twig
    stem = chaikin([(109, 178), (123, 160), (137, 134), (147, 108), (159, 90)], 3, closed=False)
    for lx, ly, deg, col in ((121, 144, -62, LEAF), (145, 152, 14, LEAF_D), (131, 118, -74, LEAF_D),
                             (158, 128, 8, LEAF), (143, 94, -80, LEAF), (164, 104, -6, LEAF_D)):
        c.rot_ell(lx, ly, 15, 6.2, deg, col)
    c.line(stem, STEM, 5)
    c.rot_ell(163, 80, 14, 6, -52, LEAF)
    c.line([(134, 142), (138, 160)], STEM, 3.5)
    c.ell(139, 168, 9.5, 11.5, OLV)
    c.ell(136, 164, 2.8, 4, OLV_L)
    # oil drop
    c.poly(drop_pts(130, 58, 13.5, 2.2), OIL)
    c.ell(125, 60, 3.4, 5.5, (255, 250, 190))
    return c.finish()


def icon_frappe():
    c = Cv(IC)
    GLS, GLS_S = (226, 240, 250), (176, 204, 226)
    COF, COF_L, COF_D = (138, 78, 40), (186, 122, 68), (100, 54, 28)
    FOAM, FOAM_S, FOAM_L = (250, 234, 198), (228, 200, 152), (255, 250, 232)
    ICE, ICE_L, ICE_D = (214, 176, 134), (252, 240, 220), (168, 118, 78)
    ST, ST_W, ST_D = (48, 128, 226), (250, 250, 255), (30, 92, 180)
    gx = 76.0                                             # glass axis

    def glass(k, inset, fill, top=50.0, bot=178.0):
        t, b = 46.0 - inset, 33.0 - inset
        k.poly([(gx - t, top), (gx + t, top), (gx + b, bot - 8), (gx + b - 7, bot),
                (gx - b + 7, bot), (gx - b, bot - 8)], fill)

    # bendy straw (blue / white), sticking out behind the foam
    p0, p1, p2 = (gx + 12, 96.0), (gx + 44, 30.0), (gx + 84, 20.0)
    c.line([p0, p1, p2], ST, 13)
    for a, b, n in ((p0, p1, 9), (p1, p2, 5)):
        for i in range(1, n, 2):
            t0, t1 = i / float(n), (i + 0.5) / float(n)
            c.line([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0),
                    (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)], ST_W, 13, caps=False)
    c.circ(p2[0], p2[1], 3.6, ST_D)
    # glass with thick clear base
    glass(c, 0, GLS)
    c.rect(gx - 26, 166, gx + 26, 172, GLS_S, r=3)
    # contents
    m = c.sub("L")
    glass(m, 6, 255, top=40.0, bot=166.0)
    p = c.sub()
    p.rect(0, 0, IC, IC, COF + (255,))
    p.rect(0, 84, IC, 104, COF_L + (255,))                # milky zone under the foam
    p.rect(gx + 22, 84, IC, IC, COF_D + (255,))           # shaded right side
    for ix, iy, s, deg in ((gx - 13, 123, 14.0, 20), (gx + 9, 146, 12.5, -14)):
        cube = Cv(IC)
        cube.rect(ix - s, iy - s, ix + s, iy + s, ICE + (255,), r=4.5)
        cube.rect(ix - s + 3.5, iy - s + 3.5, ix + s - 9, iy - s + 9.5, ICE_L + (255,), r=2.5)
        cube.rect(ix + s - 6.5, iy - s + 6, ix + s - 2.5, iy + s - 5, ICE_D + (255,), r=2)
        cube.rotate(deg, center=(ix, iy))
        p.comp(cube)
    p.rect(0, 0, IC, 88, FOAM + (255,))
    for fx, fr in ((gx - 30, 9), (gx - 10, 12), (gx + 14, 10), (gx + 34, 11)):
        p.ell(fx, 88, fr, 7.5, FOAM + (255,))             # foam running down a little
    p.rect(gx + 24, 50, IC, 86, FOAM_S + (255,))
    c.clip(m, p)
    c.d = ImageDraw.Draw(c.im)
    # foam dome above the rim
    for fx, fy, fr in ((gx - 30, 48, 15), (gx - 8, 42, 18), (gx + 16, 44, 17), (gx + 33, 50, 13)):
        c.circ(fx, fy, fr, FOAM)
    c.rect(gx - 42, 46, gx + 42, 60, FOAM, r=6)
    c.line(chaikin([(gx - 34, 44), (gx - 22, 36), (gx - 8, 33)], 2, closed=False), FOAM_L, 5)
    for fx, fy, fr in ((gx - 20, 62, 3.6), (gx + 2, 70, 2.8), (gx - 30, 76, 2.4), (gx + 14, 58, 2.4)):
        c.circ(fx, fy, fr, FOAM_S)
    # glass highlight
    c.line([(gx - 33, 96), (gx - 28, 150)], (255, 255, 255), 4.5)
    # coffee beans
    for bxx, byy, deg in ((146, 160, -30), (163, 132, 38)):
        c.rot_ell(bxx, byy, 14.5, 10.5, deg, COF_D)
        ca, sa = math.cos(math.radians(deg)), math.sin(math.radians(deg))
        c.line(chaikin([(bxx - 10 * ca - 2 * sa, byy - 10 * sa + 2 * ca), (bxx + 2.5 * sa, byy - 2.5 * ca),
                        (bxx + 10 * ca - 2 * sa, byy + 10 * sa + 2 * ca)], 2, closed=False), COF_L, 3)
    return c.finish()


def icon_window():
    c = Cv(IC)
    O, OL, OD = (255, 146, 36), (255, 204, 112), (222, 104, 20)
    PANE, PANE_L, HOLE = (104, 28, 34), (160, 52, 48), (34, 8, 14)
    CR = (255, 240, 206)
    RED, RED_L, RED_D = (236, 48, 52), (255, 132, 112), (176, 22, 40)
    # frame, sash, sill
    c.rect(12, 10, 134, 156, OD, r=5)
    c.rect(19, 17, 127, 149, O, r=3)
    c.rect(19, 17, 127, 23, OL, r=3)
    panes = [(28, 27, 68, 79), (78, 27, 118, 79), (28, 89, 68, 141), (78, 89, 118, 141)]
    for x0, y0, x1, y1 in panes:
        c.rect(x0, y0, x1, y1, PANE, r=2)
    # glints on the intact panes
    for x0, y0, x1, y1 in panes[1:]:
        m = c.sub("L")
        m.rect(x0, y0, x1, y1, 255, r=2)
        p = c.sub()
        p.poly([(x0 + 4, y1), (x0 + 26, y0), (x0 + 38, y0), (x0 + 16, y1)], PANE_L + (255,))
        c.clip(m, p)
    c.d = ImageDraw.Draw(c.im)
    # smashed pane: jagged hole with cracks
    x0, y0, x1, y1 = panes[0]
    hx, hy = 47.0, 54.0
    m = c.sub("L")
    m.rect(x0, y0, x1, y1, 255, r=2)
    p = c.sub()
    for deg in (12, 62, 118, 166, 214, 262, 318):
        a = math.radians(deg)
        p.line([(hx, hy), (hx + 44 * math.cos(a), hy + 44 * math.sin(a))], CR + (255,), 2.6, caps=False)
    hole = []
    for i, r in enumerate((15, 7, 13, 6.5, 16, 7, 12, 6, 15, 7.5, 13, 6.5, 14, 7)):
        a = math.radians(12 + i * 360.0 / 14)
        hole.append((hx + r * math.cos(a), hy + r * math.sin(a)))
    p.poly([(hx + (x - hx) * 1.28, hy + (y - hy) * 1.28) for x, y in hole], CR + (255,))
    p.poly(hole, HOLE + (255,))
    c.clip(m, p)
    c.d = ImageDraw.Draw(c.im)
    c.rect(8, 152, 140, 168, OL, r=5)
    c.rect(8, 161, 140, 168, O, r=4)
    c.outline(5)
    # curved "next window" arrow
    a = c.sub()
    acx, acy, ar, aw = 126.0, 155.0, 37.0, 19.0

    def band(r_in, r_out, d0, d1):
        pts = []
        for i in range(0, 41):
            t = math.radians(d0 + (d1 - d0) * i / 40.0)
            pts.append((acx + r_out * math.cos(t), acy + r_out * math.sin(t)))
        for i in range(40, -1, -1):
            t = math.radians(d0 + (d1 - d0) * i / 40.0)
            pts.append((acx + r_in * math.cos(t), acy + r_in * math.sin(t)))
        return pts

    def head(r_c, hw, ln, deg):
        t = math.radians(deg)
        ex, ey = acx + r_c * math.cos(t), acy + r_c * math.sin(t)
        tx, ty = -math.sin(t), math.cos(t)
        return [(acx + (r_c - hw) * math.cos(t), acy + (r_c - hw) * math.sin(t)),
                (acx + (r_c + hw) * math.cos(t), acy + (r_c + hw) * math.sin(t)),
                (ex + tx * ln, ey + ty * ln)]

    d0, d1 = 172.0, 338.0
    a.poly(band(ar - aw / 2, ar + aw / 2, d0, d1), RED)
    a.circ(acx + ar * math.cos(math.radians(d0)), acy + ar * math.sin(math.radians(d0)), aw / 2, RED)
    a.poly(band(ar + aw / 2 - 6.5, ar + aw / 2, d0, d1), RED_L)
    a.poly(band(ar - aw / 2, ar - aw / 2 + 4.5, d0, d1), RED_D)
    a.poly(head(ar, 23, 34, d1), RED)
    a.outline(5)
    c.comp(a)
    return c.finish(outline=0)


def icon_heart_full():
    c = Cv(IC)
    s, cx, cy = 5.15, 96.0, 82.0
    pts = heart_pts(cx, cy, s)
    c.poly(pts, (190, 22, 44))
    m = c.sub("L")
    m.poly(pts, 255)
    p = c.sub()
    p.poly(heart_pts(cx - 5, cy - 6, s * 0.95), (236, 44, 62, 255))
    p.rot_ell(60, 58, 20, 11, -38, (255, 150, 160, 255))
    p.circ(44, 76, 5, (255, 150, 160, 255))
    c.clip(m, p)
    return c.finish()


def icon_heart_empty():
    c = Cv(IC)
    s, cx, cy = 5.15, 96.0, 82.0
    c.poly(heart_pts(cx, cy, s), (104, 108, 122))
    m = c.sub("L")
    m.poly(heart_pts(cx, cy, s), 255)
    p = c.sub()
    p.poly(heart_pts(cx + 5, cy + 6, s * 0.95), (0, 0, 0, 0))
    hl = c.sub()
    hl.poly(heart_pts(cx, cy, s), (136, 140, 154, 255))
    hl.poly(heart_pts(cx + 4, cy + 5, s * 0.96), (0, 0, 0, 0))
    c.clip(m, hl)
    c.d = ImageDraw.Draw(c.im)
    # hollow inside
    c.poly(heart_pts(cx, cy + 3.5, s * 0.70), (26, 26, 34, 150))
    # bite mark (upper right)
    b = c.sub("L")
    for bx, by, br in ((146, 16, 17), (168, 30, 18), (182, 56, 16)):
        b.circ(bx, by, br, 255)
    c.erase(b)
    return c.finish()


def icon_marker_oval():
    n = IC
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    d = np.hypot(xx - (n - 1) / 2.0, yy - (n - 1) / 2.0)
    r0 = 66.0
    core = np.exp(-((d - r0) / 6.5) ** 2)
    halo = np.exp(-np.abs(d - r0) / 15.0) * 0.50
    inner = 0.10 * smoothstep(0, r0, d) * (d < r0)
    a = np.clip(core + halo + inner, 0, 1) * (1.0 - smoothstep(84.0, 95.0, d))
    rgb = lerp((255, 236, 36), (255, 252, 190), np.clip(core, 0, 1) ** 2)
    out = np.dstack([rgb, a * 255.0])
    return to_img(out, "RGBA")


def icon_arrow():
    c = Cv(IC)
    c.poly([(96, 14), (168, 92), (122, 92), (122, 176), (70, 176), (70, 92), (24, 92)], (255, 255, 255))
    im = add_outline(c.im, 3.5 * c.ss, (10, 10, 16), alpha=170)
    return im.resize((IC, IC), LANCZOS)


ICONS = {
    "btn_freeze.png": icon_freeze,
    "btn_sneak.png": icon_sneak,
    "btn_hide.png": icon_hide,
    "btn_unhide.png": icon_unhide,
    "btn_bite.png": icon_bite,
    "btn_sprint.png": icon_sprint,
    "btn_listen.png": icon_listen,
    "item_garlic.png": icon_garlic,
    "item_souvlaki.png": icon_souvlaki,
    "item_melon.png": icon_melon,
    "heart_full.png": icon_heart_full,
    "heart_empty.png": icon_heart_empty,
    "marker_oval.png": icon_marker_oval,
    "arrow.png": icon_arrow,
    "item_oil.png": icon_oil,
    "item_frappe.png": icon_frappe,
    "btn_window.png": icon_window,
}


# --------------------------------------------------------------------------
# shared art pieces: Parthenon, zombie face, zombie hands
# --------------------------------------------------------------------------
def draw_parthenon(d, cx, by, w, k, lit, shade, dark, ncol=8):
    """Front view of the Parthenon. (cx, by) = bottom centre, w = width, k = px scale."""
    def R(x0, y0, x1, y1, f):
        d.rectangle([x0 * k, y0 * k, x1 * k, y1 * k], fill=f)

    step_h, col_h, ent_h, ped_h = w * 0.05, w * 0.33, w * 0.095, w * 0.135
    x0, x1 = cx - w / 2.0, cx + w / 2.0
    for i in range(3):
        ins = (2 - i) * w * 0.014
        R(x0 - ins - w * 0.01, by - (i + 1) * step_h / 3.0, x1 + ins + w * 0.01, by - i * step_h / 3.0,
          lit if i % 2 == 0 else shade)
    top = by - step_h
    R(x0 + w * 0.02, top - col_h, x1 - w * 0.02, top, dark)
    cw = w * 0.062
    gap = (w - cw) / (ncol - 1)
    for i in range(ncol):
        xc = x0 + cw / 2.0 + i * gap
        R(xc - cw / 2, top - col_h, xc + cw / 2, top, lit)
        R(xc - cw / 2, top - col_h, xc - cw * 0.12, top, shade)
        R(xc - cw * 0.72, top - col_h, xc + cw * 0.72, top - col_h + w * 0.016, lit)
    ey = top - col_h
    R(x0 - w * 0.012, ey - ent_h, x1 + w * 0.012, ey, lit)
    R(x0 - w * 0.012, ey - ent_h * 0.45, x1 + w * 0.012, ey - ent_h * 0.36, shade)
    py = ey - ent_h
    d.polygon([((x0 - w * 0.03) * k, py * k), ((x1 + w * 0.03) * k, py * k), (cx * k, (py - ped_h) * k)], fill=lit)
    d.polygon([((x0 + w * 0.09) * k, (py - w * 0.012) * k), ((x1 - w * 0.09) * k, (py - w * 0.012) * k),
               (cx * k, (py - ped_h + w * 0.03) * k)], fill=shade)


def render_zombie(size, cx, cy, s, ss=3, outline=None):
    """Zombie face as RGBA image (size x size). s = half head width in px."""
    c = Cv(size, ss=ss)

    def T(x, y):
        return (cx + x * s, cy + y * s)

    def TP(pts):
        return [T(x, y) for x, y in pts]

    SKIN, SKIN_D, SKIN_DD, SKIN_L = (128, 160, 112), (92, 126, 88), (62, 90, 66), (164, 194, 142)
    SOCK = (22, 30, 26)
    BLOOD, BLOOD_D = (204, 18, 30), (130, 10, 22)
    TOOTH, TOOTH_S = (240, 232, 200), (196, 184, 146)

    # ears
    c.ell(*T(-1.0, -0.02), 0.17 * s, 0.27 * s, SKIN_D)
    c.ell(*T(1.0, -0.02), 0.17 * s, 0.27 * s, SKIN_D)
    c.ell(*T(-1.02, -0.02), 0.08 * s, 0.15 * s, SKIN_DD)
    c.ell(*T(1.02, -0.02), 0.08 * s, 0.15 * s, SKIN_DD)
    nb = c.sub("L")                                   # torn right ear
    nb.circ(*T(1.17, -0.22), 0.09 * s, 255)
    c.erase(nb)
    # head
    head = chaikin(TP([(0.0, -1.27), (0.56, -1.19), (0.93, -0.80), (1.0, -0.26), (0.90, 0.26), (0.80, 0.72),
                       (0.50, 1.14), (0.0, 1.30), (-0.50, 1.14), (-0.80, 0.72), (-0.90, 0.26), (-1.0, -0.26),
                       (-0.93, -0.80), (-0.56, -1.19)]), 3)
    c.poly(head, SKIN)
    m = c.sub("L")
    m.poly(head, 255)
    p = c.sub()
    p.ell(*T(-0.12, -0.86), 0.62 * s, 0.26 * s, SKIN_L + (255,))                 # forehead light
    p.poly(chaikin(TP([(-1.02, -0.2), (-0.62, 0.22), (-0.50, 0.50), (-0.62, 1.0), (-0.9, 1.1), (-1.1, 0.4)]), 2),
           SKIN_D + (255,))                                                      # hollow cheeks
    p.poly(chaikin(TP([(1.02, -0.2), (0.62, 0.22), (0.50, 0.50), (0.62, 1.0), (0.9, 1.1), (1.1, 0.4)]), 2),
           SKIN_D + (255,))
    p.poly(chaikin(TP([(0.55, -1.3), (1.1, -1.0), (1.1, -0.3), (0.88, -0.42), (0.80, -0.86)]), 2),
           SKIN_D + (255,))                                                      # right temple shade
    p.ell(*T(0.0, 1.36), 0.6 * s, 0.2 * s, SKIN_D + (255,))                      # chin shade
    # head wound
    p.poly(chaikin(TP([(0.30, -1.30), (0.74, -1.12), (0.70, -0.86), (0.52, -0.80), (0.36, -0.96), (0.24, -1.02)]), 2),
           BLOOD_D + (255,))
    p.poly(chaikin(TP([(0.40, -1.20), (0.66, -1.08), (0.62, -0.92), (0.50, -0.90), (0.40, -1.02)]), 2),
           (226, 120, 130, 255))
    c.clip(m, p)
    c.d = ImageDraw.Draw(c.im)
    c.line(TP([(0.47, -1.13), (0.50, -0.93)]), BLOOD_D, 0.035 * s)
    c.line(TP([(0.56, -1.10), (0.58, -0.92)]), BLOOD_D, 0.035 * s)
    c.line(chaikin(TP([(0.56, -0.84), (0.60, -0.62), (0.57, -0.50)]), 2, closed=False), BLOOD, 0.07 * s)

    # forehead scar with stitches
    c.line(TP([(-0.62, -0.92), (-0.14, -0.70)]), SKIN_DD, 0.04 * s)
    for t in (0.15, 0.4, 0.65, 0.9):
        x, y = -0.62 + 0.48 * t, -0.92 + 0.22 * t
        c.line(TP([(x + 0.045, y - 0.10), (x - 0.045, y + 0.10)]), SKIN_DD, 0.035 * s)

    # eye sockets
    c.poly(chaikin(TP([(-0.82, -0.40), (-0.14, -0.14), (-0.13, 0.08), (-0.44, 0.20), (-0.78, 0.06)]), 2), SOCK)
    c.poly(chaikin(TP([(0.80, -0.36), (0.16, -0.14), (0.14, 0.06), (0.44, 0.17), (0.76, 0.05)]), 2), SOCK)
    # brows
    c.line(TP([(-0.88, -0.50), (-0.10, -0.20)]), SKIN_DD, 0.085 * s)
    c.line(TP([(0.86, -0.46), (0.12, -0.20)]), SKIN_DD, 0.085 * s)
    # glowing eyes (asymmetric)
    eyes = [(-0.46, -0.07, 0.165), (0.45, -0.07, 0.125)]
    for ex, ey, er in eyes:
        c.circ(*T(ex, ey), er * s, (255, 232, 96))
        c.circ(*T(ex, ey), er * s * 0.68, (255, 255, 214))
        c.circ(*T(ex + 0.01, ey + 0.01), er * s * 0.20, (70, 40, 0))
    # nose
    c.poly(TP([(-0.12, 0.36), (-0.035, 0.14), (-0.02, 0.38)]), SOCK)
    c.poly(TP([(0.12, 0.36), (0.035, 0.14), (0.02, 0.38)]), SOCK)
    c.line(chaikin(TP([(-0.09, -0.04), (-0.13, 0.16), (-0.17, 0.32)]), 2, closed=False), SKIN_D, 0.035 * s)

    # mouth
    mouth = chaikin(TP([(-0.62, 0.54), (-0.2, 0.50), (0.25, 0.51), (0.64, 0.50), (0.54, 0.84), (0.22, 1.02),
                        (-0.2, 1.04), (-0.54, 0.86)]), 2)
    c.poly(mouth, (44, 6, 12))
    mm = c.sub("L")
    mm.poly(mouth, 255)
    tp = c.sub()
    tp.ell(*T(0.0, 0.98), 0.3 * s, 0.14 * s, (120, 24, 36, 255))
    for x, w, h in ((-0.47, 0.13, 0.15), (-0.32, 0.14, 0.24), (-0.16, 0.15, 0.17), (0.0, 0.15, 0.19),
                    (0.16, 0.14, 0.15), (0.31, 0.14, 0.25), (0.46, 0.13, 0.13)):
        tp.poly(TP([(x - w / 2, 0.44), (x + w / 2, 0.44), (x + w * 0.36, 0.52 + h), (x, 0.55 + h),
                    (x - w * 0.36, 0.52 + h)]), TOOTH + (255,))
        tp.poly(TP([(x + w * 0.1, 0.44), (x + w / 2, 0.44), (x + w * 0.36, 0.52 + h), (x + w * 0.1, 0.54 + h)]),
                TOOTH_S + (255,))
    for x, w, h in ((-0.36, 0.13, 0.16), (-0.21, 0.13, 0.13), (0.08, 0.14, 0.17), (0.24, 0.13, 0.13),
                    (0.38, 0.12, 0.16)):
        yb = 1.06 - 0.55 * (x * x)
        tp.poly(TP([(x - w / 2, yb + 0.05), (x + w / 2, yb + 0.05), (x + w * 0.36, yb - h), (x, yb - h - 0.03),
                    (x - w * 0.36, yb - h)]), TOOTH + (255,))
    # blood on the teeth
    tp.poly(chaikin(TP([(-0.02, 0.40), (0.40, 0.40), (0.38, 0.60), (0.26, 0.66), (0.14, 0.56), (0.05, 0.62)]), 2),
            BLOOD + (255,))
    c.clip(mm, tp)
    c.d = ImageDraw.Draw(c.im)
    c.line(mouth + mouth[:1], SKIN_DD, 0.045 * s, caps=False)
    # blood running from the mouth
    c.line(chaikin(TP([(-0.50, 0.84), (-0.54, 1.02), (-0.50, 1.16)]), 2, closed=False), BLOOD, 0.085 * s)
    c.line(chaikin(TP([(0.14, 1.02), (0.16, 1.20), (0.13, 1.33)]), 2, closed=False), BLOOD, 0.095 * s)
    c.line(TP([(0.34, 0.97), (0.36, 1.10)]), BLOOD, 0.07 * s)
    c.line(chaikin(TP([(-0.15, 1.03), (0.0, 1.05), (0.3, 1.0), (0.5, 0.87)]), 2, closed=False), BLOOD, 0.06 * s)

    c.outline((outline if outline is not None else 0.055 * s))
    # eye glow on top
    g = c.sub()
    for ex, ey, er in eyes:
        g.circ(*T(ex, ey), er * s * 2.1, (255, 226, 70, 150))
    g.im = g.im.filter(ImageFilter.GaussianBlur(0.16 * s * ss))
    c.comp(g)
    c.d = ImageDraw.Draw(c.im)
    for ex, ey, er in eyes:
        c.circ(*T(ex, ey), er * s * 0.60, (255, 255, 224))
        c.circ(*T(ex + 0.01, ey + 0.01), er * s * 0.20, (70, 40, 0))
    return c.im.resize((size, size), LANCZOS)


def capsule(d, p0, r0, p1, r1, fill):
    d.ellipse([p0[0] - r0, p0[1] - r0, p0[0] + r0, p0[1] + r0], fill=fill)
    d.ellipse([p1[0] - r1, p1[1] - r1, p1[0] + r1, p1[1] + r1], fill=fill)
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    ln = math.hypot(dx, dy)
    if ln < 1e-6:
        return
    nx, ny = -dy / ln, dx / ln
    d.polygon([(p0[0] + nx * r0, p0[1] + ny * r0), (p1[0] + nx * r1, p1[1] + ny * r1),
               (p1[0] - nx * r1, p1[1] - ny * r1), (p0[0] - nx * r0, p0[1] - ny * r0)], fill=fill)


def draw_zombie_hand(d, rng, base, scale, ang_deg, mirror, fill=255):
    """Clawed hand silhouette reaching up. base = wrist position (px)."""
    segs = [((0, 520), 30, (0, 70), 21), ((0, 70), 23, (0, 6), 33), ((-22, 2), 17, (22, 2), 17)]
    fingers = [(-32, -2, -27, 92), (-11, -12, -8, 108), (11, -11, 7, 100), (31, -1, 25, 78)]
    for bx, by, a, ln in fingers:
        a += rng.uniform(-5, 5)
        sign = 1.0 if bx < 0 else -1.0
        p, r = (bx, by), 9.5
        for frac, r1 in ((0.42, 8.0), (0.32, 6.3), (0.27, 2.0)):
            l = ln * frac
            p1 = (p[0] + l * math.sin(math.radians(a)), p[1] - l * math.cos(math.radians(a)))
            segs.append((p, r, p1, r1))
            segs.append((p1, r1 + 1.6, p1, r1 + 1.6))          # knobbly joint
            p, r = p1, r1
            a += sign * rng.uniform(12, 30)
    p, r, a = (-26, 44), 13.0, -52.0
    for l, r1 in ((50, 9.5), (40, 2.5)):
        p1 = (p[0] + l * math.sin(math.radians(a)), p[1] - l * math.cos(math.radians(a)))
        segs.append((p, r, p1, r1))
        p, r = p1, r1
        a += 30
    ca, sa = math.cos(math.radians(ang_deg)), math.sin(math.radians(ang_deg))

    def tf(q):
        x, y = q
        if mirror:
            x = -x
        return (base[0] + scale * (x * ca - y * sa), base[1] + scale * (x * sa + y * ca))

    for p0, r0, p1, r1 in segs:
        capsule(d, tf(p0), r0 * scale, tf(p1), r1 * scale, fill)


# --------------------------------------------------------------------------
# UI: title background
# --------------------------------------------------------------------------
def ui_title_bg():
    rng = rng_for("title_bg")
    K = 2
    W, H = 1280 * K, 720 * K
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = xx / K, yy / K
    t = v / 720.0

    # --- sky ---------------------------------------------------------------
    sky = lerp((4, 6, 18), (17, 30, 60), smoothstep(0.0, 0.62, t))
    sky += (np.array([30, 54, 66], np.float32) - np.array([17, 30, 60], np.float32)) * smoothstep(0.42, 0.70, t)[..., None]
    mx, my, mr = 1016.0, 150.0, 86.0
    dm = np.hypot(u - mx, v - my)
    sky += np.array([52, 62, 78], np.float32) * np.exp(-dm / 190.0)[..., None]
    sky += np.array([70, 76, 80], np.float32) * np.exp(-((dm / (mr * 1.25)) ** 2))[..., None]
    # stars
    st = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(st)
    for _ in range(330):
        x, y = rng.uniform(0, W), rng.uniform(0, 430 * K)
        b = int(rng.uniform(70, 230) * (1 - 0.6 * y / (430 * K)))
        r = 1.0 if rng.random() < 0.82 else 1.9
        sd.ellipse([x - r, y - r, x + r, y + r], fill=b)
    st = st.filter(ImageFilter.GaussianBlur(0.9))
    star = np.asarray(st, np.float32) * 1.25 * (1 - np.exp(-dm / 150.0))
    sky += star[..., None] * np.array([0.9, 0.95, 1.0], np.float32)
    # moon
    tex = fbm(rng, 256, 256, 4, 4, 4)
    tex = np.asarray(Image.fromarray((tex * 255).astype(np.uint8)).resize((int(2 * mr * K), int(2 * mr * K)), BICUBIC),
                     np.float32) / 255.0
    mt = np.zeros((H, W), np.float32)
    x0, y0 = int((mx - mr) * K), int((my - mr) * K)
    mt[y0:y0 + tex.shape[0], x0:x0 + tex.shape[1]] = tex
    ma = np.clip((mr - dm) * K + 0.5, 0, 1)
    mcol = lerp((240, 238, 218), (178, 184, 180), smoothstep(0.46, 0.66, mt) * 0.9)
    mcol *= (1.0 - 0.20 * np.clip(dm / mr, 0, 1) ** 3)[..., None]
    sky = sky * (1 - ma[..., None]) + mcol * ma[..., None]
    # thin clouds
    cn = fbm(rng, H // 4, W // 4, 9, 4, 5)
    cn = np.asarray(Image.fromarray((cn * 255).astype(np.uint8)).resize((W, H), BICUBIC), np.float32) / 255.0
    ca = smoothstep(0.50, 0.82, cn)
    ca *= smoothstep(10, 110, v) * (1 - smoothstep(360, 480, v))
    calm = 1.0 - 0.65 * np.exp(-(((u - 640) / 360.0) ** 2 + ((v - 170) / 140.0) ** 2))
    ca *= 0.62 * calm
    ccol = np.array([34, 46, 74], np.float32) + np.array([150, 150, 132], np.float32) * np.exp(-dm / 240.0)[..., None]
    sky = sky * (1 - ca[..., None]) + ccol * ca[..., None]

    img = to_img(sky)
    d = ImageDraw.Draw(img)
    lights = Image.new("RGB", (W, H), (0, 0, 0))
    ld = ImageDraw.Draw(lights)

    def R(x0, y0, x1, y1, f, dd=None):
        (dd or d).rectangle([x0 * K, y0 * K, x1 * K, y1 * K], fill=f)

    def PG(pts, f, dd=None):
        (dd or d).polygon([(x * K, y * K) for x, y in pts], fill=f)

    def LN(pts, f, w, dd=None):
        (dd or d).line([(x * K, y * K) for x, y in pts], fill=f, width=max(1, int(round(w * K))))

    # --- distant ridge (Hymettus) -------------------------------------------
    ridge = [(0, 720)]
    for i in range(0, 65):
        x = i * 20.0
        y = 452 - 26 * math.sin(x / 260.0 + 0.6) - 14 * math.sin(x / 97.0 + 2.0) - 6 * math.sin(x / 41.0)
        ridge.append((x, y))
    ridge.append((1280, 720))
    PG(ridge, (17, 28, 52))

    # --- Acropolis hill ------------------------------------------------------
    HILL, WALL, WALL_L = (14, 21, 40), (30, 40, 62), (46, 58, 84)
    hill = [(250, 560), (300, 536), (352, 520), (398, 498), (430, 484), (452, 470), (468, 452), (480, 436),
            (848, 436), (858, 452), (880, 470), (912, 486), (950, 498), (1000, 516), (1050, 536), (1090, 560)]
    hill = [(x + rng.uniform(-4, 4), y + (rng.uniform(-4, 4) if 440 < y < 556 else 0)) for x, y in hill]
    PG(hill, HILL)
    # fortification wall under the plateau
    PG([(476, 437), (852, 437), (858, 462), (470, 462)], WALL)
    R(476, 436, 852, 439.5, WALL_L)
    for bx in range(492, 850, 34):
        R(bx, 440, bx + 2.5, 462, (22, 30, 50))
    # rocky slope strata
    for _ in range(26):
        x = rng.uniform(330, 1010)
        y = rng.uniform(470, 540)
        if abs(x - 665) / 400.0 + (540 - y) / 160.0 > 0.95:
            continue
        ln = rng.uniform(14, 44)
        LN([(x, y), (x + ln, y + rng.uniform(-3, 3))], (22, 31, 54), 1.5)
    # buildings on the rock
    LIT, SHD, DRK = (150, 164, 186), (88, 102, 130), (10, 14, 28)
    draw_parthenon(d, 690, 436, 172, K, LIT, SHD, DRK)
    # Erechtheion (small, left)
    R(556, 420, 592, 436, SHD)
    R(548, 424, 560, 436, DRK)
    for i in range(4):
        R(549 + i * 3.4, 424, 550.6 + i * 3.4, 436, LIT)
    R(546, 421, 594, 423.5, LIT)
    PG([(554, 420), (594, 420), (574, 413)], LIT)
    # Propylaea (far left)
    R(488, 424, 520, 436, DRK)
    for i in range(5):
        R(489 + i * 7.2, 423, 492 + i * 7.2, 436, LIT)
    R(486, 419, 523, 423, LIT)
    PG([(486, 419), (523, 419), (504.5, 412)], SHD)
    # cypress trees on the slope
    for cxp, cyp, hh in ((420, 500, 26), (436, 494, 20), (930, 500, 24), (958, 508, 18), (392, 512, 16)):
        PG([(cxp - 4, cyp), (cxp, cyp - hh), (cxp + 4, cyp)], (9, 14, 26))

    WIN_COLS = [(255, 208, 96), (255, 190, 72), (246, 222, 136), (255, 214, 110)]

    # --- far city band -------------------------------------------------------
    x = -10.0
    while x < 1290:
        w = rng.uniform(22, 54)
        top = rng.uniform(506, 548)
        if 380 < x < 960:
            top = rng.uniform(530, 560)
        col = (int(13 + rng.uniform(0, 5)), int(20 + rng.uniform(0, 6)), int(40 + rng.uniform(0, 8)))
        R(x, top, x + w, 720, col)
        if rng.random() < 0.3:
            R(x + w * 0.2, top - 5, x + w * 0.55, top, col)
        for wy in np.arange(top + 5, 610, 8.0):
            for wx in np.arange(x + 3, x + w - 4, 6.0):
                if rng.random() < 0.085:
                    cw = WIN_COLS[int(rng.integers(len(WIN_COLS)))]
                    R(wx, wy, wx + 2.6, wy + 3.4, cw)
                    R(wx, wy, wx + 2.6, wy + 3.4, cw, ld)
        x += w + rng.uniform(-2, 3)

    # --- fog pass 1 (between far city and near blocks) -----------------------
    def fog(img, strength, y_from, y_to, seed_shift):
        n = fbm(rng_for("fog%d" % seed_shift), H // 4, W // 4, 5, 3, 4)
        n = np.asarray(Image.fromarray((n * 255).astype(np.uint8)).resize((W, H), BICUBIC), np.float32) / 255.0
        a = smoothstep(y_from, y_to, v) * (0.45 + 0.9 * n) * strength
        a = np.clip(a, 0, 0.9)[..., None]
        arr = np.asarray(img).astype(np.float32)
        fc = np.array([78, 138, 62], np.float32)
        return to_img(arr * (1 - a) + fc * a)

    img = fog(img, 0.34, 480, 660, 1)
    d = ImageDraw.Draw(img)

    # --- rooftop props -------------------------------------------------------
    def antenna(xa, ya, hh, col):
        LN([(xa, ya), (xa, ya - hh)], col, 1.3)
        for i, wd in enumerate((11, 9, 7, 5)):
            yb = ya - hh + 3 + i * 4.5
            LN([(xa - wd, yb), (xa + wd, yb)], col, 1.1)
        LN([(xa - 6, ya - hh * 0.45), (xa + 9, ya - hh * 0.45 - 4)], col, 1.0)

    def solar(xs, ys, s, col, tank):
        PG([(xs, ys - 2 * s), (xs + 24 * s, ys - 17 * s), (xs + 26 * s, ys - 13.5 * s), (xs + 2 * s, ys + 1.0 * s)],
           (30, 42, 70))
        LN([(xs + 23 * s, ys - 13 * s), (xs + 23 * s, ys)], col, 1.2 * s)
        LN([(xs + 3 * s, ys - 1 * s), (xs + 3 * s, ys)], col, 1.2 * s)
        d.rounded_rectangle([(xs + 15 * s) * K, (ys - 26 * s) * K, (xs + 37 * s) * K, (ys - 16.5 * s) * K],
                            radius=4.5 * s * K, fill=tank)
        d.rounded_rectangle([(xs + 15 * s) * K, (ys - 22 * s) * K, (xs + 37 * s) * K, (ys - 16.5 * s) * K],
                            radius=3 * s * K, fill=col)

    def dish(xd, yd, s, col):
        LN([(xd, yd), (xd, yd - 9 * s)], col, 1.4)
        d.pieslice([(xd - 8 * s) * K, (yd - 20 * s) * K, (xd + 8 * s) * K, (yd - 4 * s) * K], 20, 200, fill=(34, 44, 68))

    def block(x0, x1, top, col, fh, lit_p, detail=1.0, figure=False):
        R(x0, top, x1, 730, col)
        R(x0, top, x1, 730, (0, 0, 0), ld)
        edge = tuple(min(255, int(c + 10)) for c in col)
        rail = tuple(min(255, int(c + 20)) for c in col)
        dark = tuple(max(0, int(c - 3)) for c in col)
        R(x0 - 2, top - 3, x1 + 2, top + 2, edge)                       # parapet
        R(x1 - 3, top, x1, 730, edge)                                   # moonlit right edge
        nwin = max(1, int((x1 - x0 - 8) / (26 * detail)))
        cellw = (x1 - x0 - 10) / nwin
        f = 0
        fig_done = not figure
        while top + 10 + f * fh < 726:
            fy = top + 10 + f * fh
            R(x0 - 3, fy + fh - 7, x1 + 3, fy + fh - 4.5, edge)          # balcony slab
            R(x0 - 2, fy + fh - 15, x1 + 2, fy + fh - 14, rail)          # railing
            for i in range(nwin):
                wx = x0 + 5 + i * cellw + cellw * 0.18
                ww = cellw * 0.64
                wy0, wy1 = fy + 3, fy + fh - 9
                if rng.random() < lit_p:
                    cw = WIN_COLS[int(rng.integers(len(WIN_COLS)))]
                    if rng.random() < 0.10:
                        cw = (150, 226, 120)                              # one sickly green room
                    R(wx, wy0, wx + ww, wy1, cw)
                    R(wx, wy0, wx + ww, wy1, cw, ld)
                    R(wx + ww * 0.47, wy0, wx + ww * 0.53, wy1, col)
                    if not fig_done and ww > 12 and fy < 620:
                        hx = wx + ww * 0.28
                        d.ellipse([(hx - 2.6) * K, (wy1 - 15) * K, (hx + 2.6) * K, (wy1 - 9.5) * K], fill=(8, 8, 10))
                        PG([(hx - 5, wy1), (hx - 4, wy1 - 9), (hx + 4, wy1 - 9), (hx + 5, wy1)], (8, 8, 10))
                        fig_done = True
                else:
                    R(wx, wy0, wx + ww, wy1, dark)
                    if rng.random() < 0.3:                                # closed shutters
                        for sy in np.arange(wy0 + 2, wy1 - 1, 3.2):
                            R(wx + 1, sy, wx + ww - 1, sy + 0.9, edge)
            f += 1

    # --- mid blocks ----------------------------------------------------------
    MID = (9, 13, 27)
    x = -20.0
    while x < 1290:
        w = rng.uniform(70, 130)
        cxm = x + w / 2
        top = rng.uniform(556, 600) if 380 < cxm < 930 else rng.uniform(500, 560)
        block(x, x + w, top, MID, 24, 0.07, detail=0.8)
        if rng.random() < 0.7:
            antenna(x + w * rng.uniform(0.2, 0.8), top - 3, rng.uniform(18, 30), MID)
        if rng.random() < 0.6:
            solar(x + w * rng.uniform(0.1, 0.55), top - 3, 0.75, MID, (58, 72, 100))
        if rng.random() < 0.5:
            R(x + w * 0.6, top - 12, x + w * 0.85, top - 2, MID)          # stair-head box
        x += w + rng.uniform(4, 14)

    # --- foreground blocks ---------------------------------------------------
    FG = (5, 7, 15)
    TANK = (72, 88, 116)
    fg_blocks = [(-30, 170, 478, True), (182, 330, 540, False), (342, 470, 596, False), (482, 640, 640, False),
                 (652, 800, 622, False), (812, 940, 590, False), (952, 1104, 528, False), (1116, 1310, 462, False)]
    for i, (bx0, bx1, top, fig) in enumerate(fg_blocks):
        block(bx0, bx1, top, FG, 36, 0.085, detail=1.0, figure=fig)
        wmid = (bx0 + bx1) / 2.0
        # stair-head box / water tank / antennas / solar heaters / dishes
        R(bx0 + 14, top - 20, bx0 + 52, top - 2, FG)
        R(bx0 + 12, top - 22, bx0 + 54, top - 19, (15, 19, 32))
        antenna(bx0 + 30 + rng.uniform(-6, 6), top - 21, rng.uniform(30, 44), FG)
        antenna(bx1 - 20 + rng.uniform(-8, 4), top - 3, rng.uniform(26, 40), FG)
        solar(wmid - 14 + rng.uniform(-10, 10), top - 3, 1.15, FG, TANK)
        if i % 2 == 0:
            solar(wmid + 34, top - 3, 1.0, FG, TANK)
        if i % 3 == 1:
            dish(bx1 - 44, top - 2, 1.0, FG)
        # hanging wires
        if i < len(fg_blocks) - 1:
            nx0, ntop = fg_blocks[i + 1][0], fg_blocks[i + 1][2]
            pts = []
            for j in range(13):
                tt = j / 12.0
                pts.append((bx1 - 20 + (nx0 + 30 - bx1 + 20) * tt,
                            (top - 30) + (ntop - 34 - top + 30) * tt + 14 * math.sin(math.pi * tt)))
            LN(pts, (10, 13, 24), 0.8)

    # --- window glow ---------------------------------------------------------
    arr = np.asarray(img).astype(np.float32)
    g1 = np.asarray(lights.filter(ImageFilter.GaussianBlur(5 * K)), np.float32)
    g2 = np.asarray(lights.filter(ImageFilter.GaussianBlur(16 * K)), np.float32)
    arr = arr + g1 * 0.45 + g2 * 0.32
    img = to_img(arr)

    # --- fog pass 2 (in front of the blocks, bottom) -------------------------
    img = fog(img, 0.46, 585, 730, 2)
    d = ImageDraw.Draw(img)

    # --- zombie hands in the bottom corners ----------------------------------
    hm = Image.new("L", (W, H), 0)
    hd = ImageDraw.Draw(hm)
    hrng = rng_for("hands")
    hands = [((84, 628), 1.26, 10, False), ((238, 690), 0.92, -6, True), ((372, 716), 0.66, 16, False),
             ((1190, 622), 1.30, -11, True), ((1040, 688), 0.95, 7, False), ((912, 718), 0.64, -15, True)]
    for (bx, by), sc, ang, mir in hands:
        draw_zombie_hand(hd, hrng, (bx * K, by * K), sc * K, ang, mir)
    rim = ImageChops.subtract(hm, ImageChops.offset(hm, -4, 3))           # thin moon-side rim light
    arr = np.asarray(img).astype(np.float32)
    a = np.asarray(hm, np.float32)[..., None] / 255.0
    r = np.asarray(rim.filter(ImageFilter.GaussianBlur(1.2)), np.float32)[..., None] / 255.0
    hand_col = np.array([4, 7, 6], np.float32)
    arr = arr * (1 - a) + hand_col * a
    arr = arr + r * np.array([52, 96, 50], np.float32) * 0.9
    # low fog licking over the wrists
    n = fbm(rng_for("fog3"), H // 4, W // 4, 4, 3, 3)
    n = np.asarray(Image.fromarray((n * 255).astype(np.uint8)).resize((W, H), BICUBIC), np.float32) / 255.0
    fa = (smoothstep(640, 730, v) * (0.25 + 0.6 * n) * 0.55)[..., None]
    arr = arr * (1 - fa) + np.array([62, 112, 52], np.float32) * fa

    # --- vignette + grain ----------------------------------------------------
    dv = np.hypot((u - 640) / 640.0, (v - 360) / 360.0)
    arr *= (1.0 - 0.62 * smoothstep(0.62, 1.42, dv))[..., None]
    arr += (rng.random((H, W, 1)).astype(np.float32) - 0.5) * 5.0
    return to_img(arr).resize((1280, 720), LANCZOS)


# --------------------------------------------------------------------------
# UI: app icons + HUD plates
# --------------------------------------------------------------------------
def _night_bg(n, moon_c, moon_r, rng, disc=True):
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    t = yy / n
    col = lerp((6, 8, 26), (22, 40, 76), smoothstep(0.0, 1.0, t))
    dm = np.hypot(xx - moon_c[0], yy - moon_c[1])
    col += np.array([64, 76, 90], np.float32) * np.exp(-np.maximum(dm - moon_r, 0) / (0.30 * n))[..., None]
    if disc:
        tex = fbm(rng, n, n, 5, 5, 4)
        ma = np.clip(moon_r - dm + 0.5, 0, 1)
        mc = lerp((246, 240, 204), (196, 196, 172), smoothstep(0.45, 0.68, tex) * 0.85)
        mc *= (1.0 - 0.22 * np.clip(dm / moon_r, 0, 1) ** 3)[..., None]
        col = col * (1 - ma[..., None]) + mc * ma[..., None]
    else:
        col += np.array([120, 124, 110], np.float32) * np.exp(-((dm / (moon_r * 0.9)) ** 2))[..., None]
    return col, dm


def ui_icon():
    rng = rng_for("icon")
    n = 512
    col, dm = _night_bg(n, (256, 232), 232, rng)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    col *= (1.0 - 0.35 * smoothstep(0.80, 1.45, np.hypot((xx - 256) / 256.0, (yy - 256) / 256.0)))[..., None]
    bg = to_img(col).convert("RGBA")
    # hill + tiny Parthenon silhouette (supersampled)
    k = 3
    sil = Image.new("RGBA", (n * k, n * k), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sil)
    DK = (9, 11, 24, 255)
    hill = [(0, 512), (0, 436), (18, 424), (40, 420), (132, 420), (160, 432), (210, 452), (300, 470), (400, 462),
            (470, 440), (512, 430), (512, 512)]
    sd.polygon([(x * k, y * k) for x, y in hill], fill=DK)
    draw_parthenon(sd, 84, 421, 112, k, DK, DK, (0, 0, 0, 0))
    # cut clear gaps between the columns so the silhouette reads at small sizes
    bg.alpha_composite(sil.resize((n, n), LANCZOS))
    face = render_zombie(n, 262, 262, 150, ss=3)
    bg.alpha_composite(face)
    return bg.convert("RGB")


def ui_icon_foreground():
    return render_zombie(432, 216, 214, 97, ss=4)


def ui_icon_background():
    rng = rng_for("icon_bg")
    n = 432
    col, dm = _night_bg(n, (216, 210), 150, rng)
    return to_img(col)


def ui_vignette():
    n = 512
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    c = (n - 1) / 2.0
    d = np.hypot((xx - c) / c, (yy - c) / c)
    a = np.clip((d - 0.52) / (1.36 - 0.52), 0, 1) ** 1.7 * 236.0
    out = np.zeros((n, n, 4), np.float32)
    out[..., 3] = a
    return to_img(out, "RGBA")


def _radial(n):
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    c = (n - 1) / 2.0
    return np.hypot(xx - c, yy - c)


def ui_button():
    n = 256
    d = _radial(n)
    yy = np.mgrid[0:n, 0:n][0].astype(np.float32)
    R = 122.0
    disc = np.clip(R - d + 0.5, 0, 1)
    rim = np.clip(1.0 - np.abs(d - (R - 4.5)) / 4.5, 0, 1) ** 0.8
    rim2 = np.clip(1.0 - np.abs(d - (R - 11.0)) / 2.0, 0, 1) * 0.25
    top = 1.0 - yy / n                                            # subtle top sheen
    rgb = np.zeros((n, n, 3), np.float32)
    rgb[...] = (14, 16, 24)
    rgb += np.array([22, 26, 36], np.float32) * (top[..., None] ** 2)
    rim_col = np.array([176, 190, 214], np.float32)
    w = np.clip(rim * (0.55 + 0.45 * top) + rim2, 0, 1)[..., None]
    rgb = rgb * (1 - w) + rim_col * w
    a = disc * (0.55 + 0.30 * np.clip(rim, 0, 1) + 0.08 * rim2)
    return to_img(np.dstack([rgb, np.clip(a, 0, 1) * 255.0]), "RGBA")


def ui_joystick_base():
    n = 256
    d = _radial(n)
    R = 122.0
    disc = np.clip(R - d + 0.5, 0, 1)
    ring = np.clip(1.0 - np.abs(d - (R - 7.0)) / 7.0, 0, 1) ** 0.7
    inner = np.clip(1.0 - np.abs(d - 58.0) / 1.6, 0, 1) * 0.35
    a = disc * (0.13 + 0.05 * (d / R) ** 2) + ring * 0.45 + inner * 0.3
    rgb = np.zeros((n, n, 3), np.float32)
    rgb[...] = (228, 236, 248)
    im = to_img(np.dstack([rgb, np.clip(a, 0, 1) * 255.0]), "RGBA")
    # four direction ticks
    k = 4
    tick = Image.new("RGBA", (n * k, n * k), (0, 0, 0, 0))
    td = ImageDraw.Draw(tick)
    c = n * k / 2.0
    for i in range(4):
        ang = math.pi / 2 * i
        ux, uy = math.cos(ang), math.sin(ang)
        px, py = -uy, ux
        r0, r1, hw = 100 * k, 86 * k, 11 * k
        td.polygon([(c + ux * r0, c + uy * r0), (c + ux * r1 + px * hw, c + uy * r1 + py * hw),
                    (c + ux * r1 - px * hw, c + uy * r1 - py * hw)], fill=(236, 242, 252, 120))
    im.alpha_composite(tick.resize((n, n), LANCZOS))
    return im


def ui_joystick_knob():
    n = 128
    d = _radial(n)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    R = 60.0
    disc = np.clip(R - d + 0.5, 0, 1)
    rim = np.clip(1.0 - np.abs(d - (R - 4.0)) / 4.0, 0, 1) ** 0.8
    hl = np.exp(-(((xx - 52) / 34.0) ** 2 + ((yy - 46) / 30.0) ** 2))
    a = disc * (0.50 + 0.14 * hl) + rim * 0.30
    rgb = np.zeros((n, n, 3), np.float32)
    rgb[...] = (224, 232, 246)
    rgb += np.array([31, 23, 9], np.float32) * hl[..., None]
    return to_img(np.dstack([rgb, np.clip(a, 0, 1) * 255.0]), "RGBA")


UI = {
    "title_bg.png": ui_title_bg,
    "icon.png": ui_icon,
    "icon_foreground.png": ui_icon_foreground,
    "icon_background.png": ui_icon_background,
    "vignette.png": ui_vignette,
    "button.png": ui_button,
    "joystick_base.png": ui_joystick_base,
    "joystick_knob.png": ui_joystick_knob,
}

# expected (size, mode) of every output, checked after generation
EXPECTED = {}
for _n in TEXTURES:
    EXPECTED[("textures", _n)] = ((256, 256), "RGB")
for _n in ICONS:
    EXPECTED[("icons", _n)] = ((192, 192), "RGBA")
EXPECTED.update({
    ("ui", "title_bg.png"): ((1280, 720), "RGB"),
    ("ui", "icon.png"): ((512, 512), "RGB"),
    ("ui", "icon_foreground.png"): ((432, 432), "RGBA"),
    ("ui", "icon_background.png"): ((432, 432), "RGB"),
    ("ui", "vignette.png"): ((512, 512), "RGBA"),
    ("ui", "button.png"): ((256, 256), "RGBA"),
    ("ui", "joystick_base.png"): ((256, 256), "RGBA"),
    ("ui", "joystick_knob.png"): ((128, 128), "RGBA"),
})

GROUPS = {"textures": (DIR_TEX, TEXTURES), "icons": (DIR_ICO, ICONS), "ui": (DIR_UI, UI)}


def main(argv):
    wanted = [a for a in argv if a in GROUPS] or list(GROUPS)
    ok = True
    for group in wanted:
        folder, table = GROUPS[group]
        for name, fn in table.items():
            im = fn()
            size, mode = EXPECTED[(group, name)]
            if im.mode != mode:
                im = im.convert(mode)
            save(im, folder, name)
            chk = Image.open(os.path.join(folder, name))
            good = (chk.size == size and chk.mode == mode)
            ok &= good
            print("%-4s assets/%s/%-22s %4dx%-4d %s" % ("ok" if good else "FAIL", group, name,
                                                         chk.size[0], chk.size[1], chk.mode))
    if not ok:
        print("ERROR: some files do not match the expected size/mode")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

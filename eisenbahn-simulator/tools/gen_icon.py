#!/usr/bin/env python3
"""Setzt App-Icon und Startbild aus dem freigestellten Lok-Rendering zusammen.

Das Rendering (tools/loco_render.png) entsteht mit:
  godot --path . -- --test=icon --shot=tools/loco_render.png
Aufruf:  python3 tools/gen_icon.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(__file__)
ROOT = os.path.join(HERE, "..")
loco = Image.open(os.path.join(HERE, "loco_render.png")).convert("RGBA")
loco = loco.crop(loco.getbbox())


def background(size):
    """Himmel mit sanften Hügeln."""
    s = size * 2
    im = Image.new("RGB", (s, s))
    px = im.load()
    top, bot = (64, 150, 226), (190, 228, 247)
    for y in range(s):
        k = y / (s - 1)
        c = tuple(int(top[i] + (bot[i] - top[i]) * k) for i in range(3))
        for x in range(s):
            px[x, y] = c
    d = ImageDraw.Draw(im)
    # Sonne und Wolken
    d.ellipse([s * 0.68, s * 0.1, s * 0.86, s * 0.28], fill=(255, 236, 160))
    for cx, cy, r in ((0.2, 0.2, 0.07), (0.27, 0.18, 0.09), (0.35, 0.21, 0.065)):
        d.ellipse([s * (cx - r), s * (cy - r * 0.6), s * (cx + r), s * (cy + r * 0.6)], fill=(255, 255, 255))
    d.ellipse([-s * 0.3, s * 0.6, s * 0.75, s * 1.5], fill=(118, 186, 88))
    d.ellipse([s * 0.3, s * 0.68, s * 1.4, s * 1.6], fill=(96, 168, 76))
    return im.resize((size, size), Image.LANCZOS).convert("RGBA")


def with_loco(bg, scale, dy=0.04):
    size = bg.size[0]
    w = int(size * scale)
    h = int(w * loco.size[1] / loco.size[0])
    lr = loco.resize((w, h), Image.LANCZOS)
    out = bg.copy()
    # weicher Schatten
    sh = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    mask = lr.split()[3].point(lambda a: int(a * 0.35))
    sh.paste((20, 40, 30, 255), ((size - w) // 2 + int(size * 0.012), (size - h) // 2 + int(size * (dy + 0.02))), mask)
    out = Image.alpha_composite(out, sh.filter(ImageFilter.GaussianBlur(size * 0.012)))
    out.alpha_composite(lr, ((size - w) // 2, (size - h) // 2 + int(size * dy)))
    return out


def rounded(im, radius_frac=0.22):
    size = im.size[0]
    m = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=int(size * 4 * radius_frac), fill=255)
    out = im.copy()
    out.putalpha(m.resize((size, size), Image.LANCZOS))
    return out


# Projekt-/Launcher-Icon
icon = rounded(with_loco(background(512), 0.86))
icon.save(os.path.join(ROOT, "icon.png"))
icon.resize((192, 192), Image.LANCZOS).save(os.path.join(ROOT, "assets", "ui", "icon_192.png"))
# Adaptive Icons (Android): Motiv in der sicheren Mitte
background(432).convert("RGB").save(os.path.join(ROOT, "assets", "ui", "icon_bg_432.png"))
fg = with_loco(Image.new("RGBA", (432, 432), (0, 0, 0, 0)), 0.56, 0.02)
fg.save(os.path.join(ROOT, "assets", "ui", "icon_fg_432.png"))

# Startbild: Lok + Schriftzug
W, H = 900, 620
sp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
lw = 430
lh = int(lw * loco.size[1] / loco.size[0])
sp.alpha_composite(loco.resize((lw, lh), Image.LANCZOS), ((W - lw) // 2, 10))
d = ImageDraw.Draw(sp)
font = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "Fredoka-Bold.ttf"), 112)
small = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "Fredoka-Medium.ttf"), 38)
title = "Gleis frei!"
tw = d.textlength(title, font=font)
d.text(((W - tw) / 2, lh + 4), title, font=font, fill=(255, 255, 255, 255), stroke_width=7, stroke_fill=(20, 50, 74, 255))
sub = "Der Eisenbahn-Simulator"
sw = d.textlength(sub, font=small)
d.text(((W - sw) / 2, lh + 140), sub, font=small, fill=(255, 233, 168, 255))
sp.save(os.path.join(ROOT, "assets", "ui", "splash.png"))
print("icons written")

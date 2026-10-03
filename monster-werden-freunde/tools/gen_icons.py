#!/usr/bin/env python3
"""Erzeugt App-Icons (Launcher, adaptive Icons) fuer Android und das Godot-Projekticon."""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "icons")
SS = 4  # Supersampling


def monster(draw, cx, cy, r):
    body = (91, 192, 235)
    dark = (40, 98, 140)
    # Fell-Kontur
    pts = []
    for i in range(72):
        a = i / 72 * math.tau
        rr = r * (1 + 0.05 * math.sin(a * 12))
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.96))
    draw.polygon(pts, fill=dark)
    pts2 = []
    for i in range(72):
        a = i / 72 * math.tau
        rr = r * 0.94 * (1 + 0.05 * math.sin(a * 12))
        pts2.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.96))
    draw.polygon(pts2, fill=body)
    # Bauch
    draw.ellipse((cx - r * 0.55, cy + r * 0.05, cx + r * 0.55, cy + r * 0.85), fill=(170, 225, 245))
    # Augen
    for sx in (-1, 1):
        ex, ey, er = cx + sx * r * 0.36, cy - r * 0.2, r * 0.26
        draw.ellipse((ex - er, ey - er, ex + er, ey + er), fill="white", outline=dark, width=int(r * 0.04))
        pr = er * 0.52
        draw.ellipse((ex - pr + r * 0.03, ey - pr + r * 0.03, ex + pr + r * 0.03, ey + pr + r * 0.03), fill=(30, 30, 50))
        hr = pr * 0.4
        draw.ellipse((ex - hr - pr * 0.2, ey - hr - pr * 0.4, ex + hr - pr * 0.2, ey + hr - pr * 0.4), fill="white")
    # Mund (offenes Laecheln)
    mw, my = r * 0.42, cy + r * 0.18
    draw.chord((cx - mw, my - mw * 0.7, cx + mw, my + mw * 0.9), 0, 180, fill=(150, 40, 60))
    draw.ellipse((cx - mw * 0.45, my + mw * 0.25, cx + mw * 0.45, my + mw * 0.85), fill=(255, 130, 150))
    # Wangen
    for sx in (-1, 1):
        bx, by, br = cx + sx * r * 0.66, cy + r * 0.12, r * 0.13
        draw.ellipse((bx - br, by - br * 0.7, bx + br, by + br * 0.7), fill=(255, 150, 170))


def heart(draw, cx, cy, s, fill):
    pts = []
    for i in range(80):
        t = i / 80 * math.tau
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((cx + x * s / 34, cy + y * s / 34))
    draw.polygon(pts, fill=fill)


def background(draw, size, rounded):
    for y in range(size):
        k = y / size
        col = (int(150 - 50 * k), int(220 - 40 * k), int(120 - 40 * k))
        draw.line([(0, y), (size, y)], fill=col)
    # Sonnenstrahlen
    cx, cy = size * 0.5, size * 0.42
    for i in range(12):
        a = i / 12 * math.tau
        p1 = (cx + math.cos(a - 0.12) * size, cy + math.sin(a - 0.12) * size)
        p2 = (cx + math.cos(a + 0.12) * size, cy + math.sin(a + 0.12) * size)
        draw.polygon([(cx, cy), p1, p2], fill=(170, 230, 135))


def render(size, with_bg, monster_scale, rounded=False):
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if with_bg:
        bg = Image.new("RGBA", (big, big))
        background(ImageDraw.Draw(bg), big, rounded)
        if rounded:
            mask = Image.new("L", (big, big), 0)
            ImageDraw.Draw(mask).rounded_rectangle((0, 0, big - 1, big - 1), radius=big * 0.22, fill=255)
            img.paste(bg, (0, 0), mask)
        else:
            img.paste(bg, (0, 0))
    if monster_scale > 0:
        r = big * monster_scale
        monster(d, big * 0.5, big * 0.54, r)
        heart(d, big * 0.5 + r * 0.85, big * 0.54 - r * 0.85, r * 0.55, (255, 90, 130))
    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    render(192, True, 0.30, rounded=True).save(os.path.join(OUT, "icon_192.png"))
    render(432, False, 0.20).save(os.path.join(OUT, "icon_fg_432.png"))
    render(432, True, 0.0).save(os.path.join(OUT, "icon_bg_432.png"))
    render(256, True, 0.30, rounded=True).save(os.path.join(ROOT, "icon.png"))
    print("Icons erzeugt in", OUT)


if __name__ == "__main__":
    main()

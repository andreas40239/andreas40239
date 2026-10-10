#!/usr/bin/env python3
"""Erzeugt die Sticker-Abzeichen (stickers/*.svg) und Tier-Symbole (icons/animal_*.svg)."""
import math
import os

BASE = os.path.join(os.path.dirname(__file__), "..")
W = 'fill="none" stroke="#ffffff" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"'
HEAD = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 96 96">'


def star(cx, cy, r, fill="#ffffff"):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append(f"{cx + rr * math.cos(a):.1f},{cy + rr * math.sin(a):.1f}")
    return f'<polygon fill="{fill}" points="{" ".join(pts)}"/>'


def gauge(angle_deg, stars):
    # Tacho: Bogen + Nadel; angle 0 = links, 180 = rechts
    a = math.radians(180 - angle_deg)
    nx, ny = 48 + 24 * math.cos(a), 54 - 24 * math.sin(a)
    s = f'<path {W} d="M18 54 A 30 30 0 0 1 78 54"/><path {W} d="M48 54 L{nx:.1f} {ny:.1f}"/>'
    s += '<circle cx="48" cy="54" r="5" fill="#ffffff"/>'
    xs = {1: [48], 2: [38, 58], 3: [30, 48, 66]}[stars]
    for x in xs:
        s += star(x, 74, 8)
    return s


STICKERS = {
    "ride": ("#F5A142", f'<path {W} d="M18 30 H78 V40 A8 8 0 0 0 78 56 V66 H18 V56 A8 8 0 0 0 18 40 Z"/><path stroke="#ffffff" stroke-width="5" stroke-dasharray="4 5" d="M40 32 V64"/>'),
    "lap": ("#4CB25E", f'<path {W} d="M70 40 A24 24 0 1 0 72 56"/><path {W} d="M60 38 L71 40 L74 28"/>'),
    "laps5": ("#2E9C8F", f'<path {W} d="M68 36 A22 22 0 1 0 70 52"/><path {W} d="M58 34 L69 36 L72 24"/>'
              + "".join(f'<circle cx="{24 + i * 12}" cy="78" r="4" fill="#ffffff"/>' for i in range(5))),
    "speed50": ("#C98A4B", gauge(50, 1)),
    "speed80": ("#8E9AA8", gauge(110, 2)),
    "speed100": ("#E2B227", gauge(170, 3)),
    "loop": ("#3F7FD8", f'<path {W} d="M10 70 H38 C 60 70 64 46 58 34 C 50 16 28 18 26 38 C 24 56 38 70 58 70 H86"/>'),
    "corkscrew": ("#8E5BD0", f'<path {W} d="M8 56 H18 C 30 56 30 24 44 24 C 58 24 58 68 44 68 C 30 68 36 34 52 34 C 66 34 66 56 78 56 H88"/>'),
    "splash": ("#4FA6E8", '<path fill="#ffffff" d="M30 52 Q34 30 40 22 Q44 38 38 52 Z M50 48 Q54 22 62 14 Q66 34 58 50 Z M68 54 Q74 40 80 38 Q78 50 72 56 Z"/>'
               + f'<path {W} d="M12 70 Q22 62 32 70 T52 70 T72 70 T88 70"/>'),
    "tunnel": ("#8A6A4A", f'<path {W} d="M14 76 V48 A34 34 0 0 1 82 48 V76"/><path {W} d="M30 76 V54 A18 18 0 0 1 66 54 V76"/>'),
    "booster": ("#E8603C", '<path fill="#ffffff" d="M48 10 C 62 22 64 44 60 62 H36 C 32 44 34 22 48 10 Z"/>'
                + '<circle cx="48" cy="34" r="6" fill="#E8603C"/>'
                + '<path fill="#ffffff" d="M36 52 L24 66 L36 64 Z M60 52 L72 66 L60 64 Z"/>'
                + '<path fill="#FFD27A" d="M40 66 L48 86 L56 66 Z"/>'),
    "high": ("#5A8F5A", f'<path {W} d="M10 76 L36 34 L48 52 L60 26 L86 76 Z"/><path {W} d="M60 26 V10 L74 15 L60 20"/>'),
    "airtime": ("#E06BA8", '<circle cx="48" cy="24" r="8" fill="#ffffff"/>'
                + f'<path {W} d="M48 34 V58 M48 40 L32 26 M48 40 L64 26 M48 58 L38 72 M48 58 L58 72"/>'
                + f'<path stroke="#ffffff" stroke-width="4" stroke-linecap="round" d="M20 84 H76"/>'),
    "backwards": ("#A3A33A", f'<path {W} d="M60 64 A16 16 0 1 1 60 63 M60 48 A8 8 0 1 1 59 48"/><path {W} d="M76 68 H20 Q14 68 14 60 V54 M14 54 L10 46 M14 54 L20 47"/>'),
}

for name, (color, body) in STICKERS.items():
    svg = (HEAD + f'<circle cx="48" cy="48" r="45" fill="{color}" stroke="#ffffff" stroke-width="3"/>'
           + f'<g transform="translate(9.6 9.6) scale(0.8)">{body}</g></svg>\n')
    open(os.path.join(BASE, "stickers", name + ".svg"), "w").write(svg)

# ---- Tier-Symbole (Profile) ------------------------------------------
EYE = lambda x, y, r=4: f'<circle cx="{x}" cy="{y}" r="{r}" fill="#1c1d20"/>'
ANIMALS = {
    "fox": '<path fill="#E8762B" d="M14 14 L36 30 L60 30 L82 14 L78 50 Q70 80 48 86 Q26 80 18 50 Z"/>'
           '<path fill="#ffffff" d="M24 54 Q34 58 48 76 Q62 58 72 54 Q68 74 48 86 Q28 74 24 54 Z"/>'
           '<path fill="#1c1d20" d="M43 72 H53 L48 78 Z"/>' + EYE(36, 50) + EYE(60, 50),
    "bear": '<circle cx="22" cy="24" r="12" fill="#8B5A3C"/><circle cx="74" cy="24" r="12" fill="#8B5A3C"/>'
            '<circle cx="48" cy="52" r="36" fill="#8B5A3C"/><ellipse cx="48" cy="64" rx="16" ry="12" fill="#D9B48F"/>'
            '<ellipse cx="48" cy="58" rx="6" ry="4" fill="#1c1d20"/>' + EYE(34, 44) + EYE(62, 44),
    "rabbit": '<ellipse cx="34" cy="22" rx="9" ry="22" fill="#E6E6E6"/><ellipse cx="62" cy="22" rx="9" ry="22" fill="#E6E6E6"/>'
              '<ellipse cx="34" cy="22" rx="4" ry="15" fill="#F2A7B8"/><ellipse cx="62" cy="22" rx="4" ry="15" fill="#F2A7B8"/>'
              '<circle cx="48" cy="60" r="30" fill="#E6E6E6"/><path fill="#F2A7B8" d="M43 64 H53 L48 70 Z"/>' + EYE(37, 54) + EYE(59, 54),
    "cat": '<path fill="#9AA0A8" d="M16 16 L38 32 L58 32 L80 16 L80 56 Q76 84 48 86 Q20 84 16 56 Z"/>'
           '<path stroke="#1c1d20" stroke-width="2.5" stroke-linecap="round" d="M14 62 L32 64 M14 70 L32 68 M82 62 L64 64 M82 70 L64 68"/>'
           '<path fill="#F2A7B8" d="M43 62 H53 L48 68 Z"/>' + '<ellipse cx="36" cy="50" rx="4" ry="6" fill="#1c1d20"/><ellipse cx="60" cy="50" rx="4" ry="6" fill="#1c1d20"/>',
    "frog": '<circle cx="28" cy="30" r="14" fill="#5DB04A"/><circle cx="68" cy="30" r="14" fill="#5DB04A"/>'
            '<ellipse cx="48" cy="60" rx="38" ry="28" fill="#5DB04A"/><circle cx="28" cy="30" r="8" fill="#ffffff"/>'
            '<circle cx="68" cy="30" r="8" fill="#ffffff"/>' + EYE(28, 30) + EYE(68, 30)
            + '<path fill="none" stroke="#1c1d20" stroke-width="3" stroke-linecap="round" d="M30 66 Q48 78 66 66"/>',
    "owl": '<path fill="#9C7650" d="M18 20 L30 30 H66 L78 20 L80 60 Q76 88 48 88 Q20 88 16 60 Z"/>'
           '<circle cx="35" cy="48" r="13" fill="#ffffff"/><circle cx="61" cy="48" r="13" fill="#ffffff"/>'
           + EYE(35, 48, 6) + EYE(61, 48, 6) + '<path fill="#F2B632" d="M43 58 H53 L48 68 Z"/>',
}
for name, body in ANIMALS.items():
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">' + body + "</svg>\n"
    open(os.path.join(BASE, "icons", f"animal_{name}.svg"), "w").write(svg)

# Sticker-Buch-Icon für die Bauansicht
open(os.path.join(BASE, "icons", "stickers.svg"), "w").write(
    '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">'
    '<rect x="14" y="12" width="68" height="74" rx="8" fill="none" stroke="#f2f2f2" stroke-width="7"/>'
    + star(48, 49, 20, "#F5C542") + "</svg>\n")
print("ok", len(STICKERS), "sticker,", len(ANIMALS), "tiere")

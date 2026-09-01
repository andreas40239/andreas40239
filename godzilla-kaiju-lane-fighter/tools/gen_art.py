#!/usr/bin/env python3
"""Generate all pixel-art assets for GODZILLA: KAIJU LANE FIGHTER.

Sprites are drawn at base resolution (per GDD sprite specs) and scaled 4x
in-engine with Nearest filtering. Every sprite gets a 1px black outline.
"""
import os, math, random
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")

# ---------- Palette (GDD 9.3) ----------
GZ_SKIN = (74, 103, 65, 255)        # 4a6741
GZ_SHADOW = (61, 82, 54, 255)       # 3d5236
FIN_GLOW = (94, 234, 212, 255)      # 5eead4
FIN_CORE = (45, 212, 191, 255)      # 2dd4bf
EYE = (251, 191, 36, 255)           # fbbf24
CLAW = (229, 231, 235, 255)         # e5e7eb
SKY_DARK = (13, 17, 23, 255)        # 0d1117
SKY_MID = (30, 41, 59, 255)         # 1e293b
FIRE_GLOW = (249, 115, 22, 255)     # f97316
FIRE_CORE = (234, 88, 12, 255)      # ea580c
RUBBLE = (55, 65, 81, 255)          # 374151
CONCRETE = (107, 114, 128, 255)     # 6b7280
DINO_GREEN = (15, 61, 15, 255)      # 0f3d0f
DINO_ACCENT = (34, 197, 94, 255)    # 22c55e
ENEMY_RED = (239, 68, 68, 255)      # ef4444
BLACK = (0, 0, 0, 255)
WHITE = (255, 255, 255, 255)


def new_sheet(frames, w, h):
    return Image.new("RGBA", (frames * w, h), (0, 0, 0, 0))


def outline(img):
    """Add 1px black outline around all opaque pixels."""
    w, h = img.size
    src = img.load()
    mask = [[src[x, y][3] > 10 for x in range(w)] for y in range(h)]
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if not mask[y][x]:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and mask[ny][nx]:
                        dst[x, y] = BLACK
                        break
    return out


def frame_draw(sheet, i, w):
    """Return (ImageDraw, x-offset) for frame i."""
    return ImageDraw.Draw(sheet), i * w


# ============================================================
# GODZILLA  (32x40 design in a 48x48 frame, facing right)
# ============================================================
GZ_FW, GZ_FH, GZ_FRAMES = 48, 48, 16

def draw_godzilla_frame(d, ox, pose):
    """pose keys: leg (0-3), tail (deg-ish -1..1), mouth (0/1/2), head_up,
    lean, arm ('idle','extend','up','block'), crouch"""
    lean = pose.get("lean", 0)
    crouch = pose.get("crouch", 0)
    ground = 46
    hipx, hipy = 20 + lean, 30 + crouch
    # tail: chain of circles going left & down from hips
    t = pose.get("tail", 0.0)
    tx, ty = hipx - 2, hipy + 2
    for s in range(7):
        r = 4 - s * 0.45
        tx -= 2.6
        ty += 1.2 - t * 1.6
        d.ellipse([ox + tx - r, ty - r, ox + tx + r, ty + r], fill=GZ_SHADOW)
    # legs
    leg = pose.get("leg", 0)
    offs = [(0, 0), (2, -2), (0, 0), (-2, -2)][leg % 4]
    if pose.get("jump"):
        d.rectangle([ox + hipx - 4, hipy + 4, ox + hipx + 1, hipy + 10], fill=GZ_SHADOW)
        d.rectangle([ox + hipx + 3, hipy + 4, ox + hipx + 8, hipy + 10], fill=GZ_SKIN)
    else:
        d.rectangle([ox + hipx - 4 + offs[0], hipy + 2, ox + hipx + 1 + offs[0], ground + offs[1]], fill=GZ_SHADOW)
        d.rectangle([ox + hipx + 3 - offs[0], hipy + 2, ox + hipx + 8 - offs[0], ground - offs[1]], fill=GZ_SKIN)
        # feet claws
        d.rectangle([ox + hipx - 4 + offs[0], ground - 2 + offs[1], ox + hipx - 2 + offs[0], ground + offs[1]], fill=CLAW)
        d.rectangle([ox + hipx + 7 - offs[0], ground - 2 - offs[1], ox + hipx + 9 - offs[0], ground - offs[1]], fill=CLAW)
    # body (chunky)
    chest = pose.get("chest", 0)
    d.ellipse([ox + hipx - 7, 14 + crouch - chest, ox + hipx + 9 + chest, hipy + 6], fill=GZ_SKIN)
    d.ellipse([ox + hipx - 7, 20 + crouch, ox + hipx + 4, hipy + 6], fill=GZ_SHADOW)
    # arms
    arm = pose.get("arm", "idle")
    ax, ay = hipx + 6, 22 + crouch
    if arm == "extend":
        d.rectangle([ox + ax, ay, ox + ax + 12, ay + 3], fill=GZ_SKIN)
        d.rectangle([ox + ax + 12, ay - 1, ox + ax + 14, ay + 4], fill=CLAW)
    elif arm == "up":
        d.rectangle([ox + ax, ay - 10, ox + ax + 3, ay + 2], fill=GZ_SKIN)
        d.rectangle([ox + ax, ay - 12, ox + ax + 3, ay - 10], fill=CLAW)
    elif arm == "block":
        d.rectangle([ox + ax - 2, ay - 2, ox + ax + 4, ay + 8], fill=GZ_SHADOW)
    else:
        d.rectangle([ox + ax, ay, ox + ax + 5, ay + 3], fill=GZ_SKIN)
        d.rectangle([ox + ax + 5, ay, ox + ax + 6, ay + 3], fill=CLAW)
    # head + snout
    hu = pose.get("head_up", 0)
    hx, hy = hipx + 8, 10 + crouch - hu
    d.ellipse([ox + hx - 4, hy - 4, ox + hx + 6, hy + 6], fill=GZ_SKIN)
    mouth = pose.get("mouth", 0)
    if mouth == 0:
        d.rectangle([ox + hx + 4, hy, ox + hx + 11, hy + 4], fill=GZ_SKIN)
    else:
        gap = 2 if mouth == 1 else 4
        d.rectangle([ox + hx + 4, hy - 1, ox + hx + 11, hy + 1], fill=GZ_SKIN)
        d.rectangle([ox + hx + 4, hy + 1 + gap, ox + hx + 10, hy + 3 + gap], fill=GZ_SHADOW)
        # teeth
        d.rectangle([ox + hx + 9, hy + 1, ox + hx + 10, hy + 2], fill=CLAW)
    d.point((ox + hx + 2, hy - 1), fill=EYE)
    d.point((ox + hx + 3, hy - 1), fill=EYE)


def draw_godzilla_fins(d, ox, pose):
    """Fins overlay in WHITE (tinted at runtime = the living HUD)."""
    crouch = pose.get("crouch", 0)
    lean = pose.get("lean", 0)
    hipx = 20 + lean
    # dorsal fins along the back (left side of body, going down the spine)
    spots = [(hipx + 3, 8 + crouch), (hipx - 2, 12 + crouch), (hipx - 6, 17 + crouch),
             (hipx - 8, 23 + crouch), (hipx - 9, 29 + crouch)]
    for i, (fx, fy) in enumerate(spots):
        s = 4 - abs(i - 2)  # biggest in middle
        s = max(2, s + 2)
        d.polygon([(ox + fx, fy), (ox + fx - s, fy + s), (ox + fx + s // 2 + 1, fy + s)], fill=WHITE)
    # small tail fins
    t = pose.get("tail", 0.0)
    tx, ty = hipx - 6, 33 + crouch
    for s in range(3):
        tx -= 5
        ty += 2 - t * 3
        d.polygon([(ox + tx, ty - 3), (ox + tx - 2, ty), (ox + tx + 2, ty)], fill=WHITE)


GZ_POSES = [
    {"chest": 0, "leg": 0},                                    # 0 idle a
    {"chest": 1, "leg": 0, "tail": 0.3},                       # 1 idle b
    {"leg": 0}, {"leg": 1}, {"leg": 2}, {"leg": 3},            # 2-5 walk
    {"tail": -0.8, "lean": -2},                                # 6 whip windup
    {"tail": 1.0, "lean": 2, "arm": "extend"},                 # 7 whip snap
    {"tail": 0.4},                                             # 8 whip recover
    {"jump": True, "crouch": -2, "arm": "up"},                 # 9 jump
    {"mouth": 1, "head_up": 3, "chest": 2},                    # 10 breath charge
    {"mouth": 2, "head_up": 2, "chest": 2, "lean": 1},         # 11 breath fire
    {"lean": -3, "crouch": 2, "mouth": 1},                     # 12 hurt
    {"arm": "extend", "lean": 2},                              # 13 grab
    {"arm": "up", "lean": 1, "mouth": 1},                      # 14 throw
    {"arm": "block", "crouch": 3, "lean": -2},                 # 15 block
]


def gen_godzilla():
    body = new_sheet(GZ_FRAMES, GZ_FW, GZ_FH)
    fins = new_sheet(GZ_FRAMES, GZ_FW, GZ_FH)
    for i, pose in enumerate(GZ_POSES):
        d, ox = frame_draw(body, i, GZ_FW)
        draw_godzilla_frame(d, ox, pose)
        d2, ox2 = frame_draw(fins, i, GZ_FW)
        draw_godzilla_fins(d2, ox2, pose)
    outline(body).save(f"{ROOT}/characters/godzilla.png")
    fins.save(f"{ROOT}/characters/godzilla_fins.png")


# ============================================================
# RAPTOR (24x24 design, 32x32 frame, facing left)
# ============================================================
def gen_raptor():
    FW = FH = 32
    sheet = new_sheet(4, FW, FH)
    for i in range(4):
        d, ox = frame_draw(sheet, i, FW)
        leap = i == 2
        hurt = i == 3
        ground = 30
        by = 18 if not leap else 14
        if hurt:
            by = 22
        # tail (to the right)
        for s in range(5):
            r = 3 - s * 0.4
            d.ellipse([ox + 18 + s * 2 - r, by + 1 - r, ox + 18 + s * 2 + r, by + 1 + r], fill=DINO_GREEN)
        # body
        d.ellipse([ox + 8, by - 4, ox + 20, by + 5], fill=DINO_GREEN)
        d.ellipse([ox + 8, by, ox + 16, by + 5], fill=(10, 45, 10, 255))
        # legs
        lo = (i % 2) * 2
        if leap:
            d.rectangle([ox + 10, by + 3, ox + 13, by + 8], fill=DINO_GREEN)
            d.rectangle([ox + 14, by + 3, ox + 17, by + 8], fill=DINO_GREEN)
        else:
            d.rectangle([ox + 10 + lo, by + 4, ox + 13 + lo, ground], fill=DINO_GREEN)
            d.rectangle([ox + 15 - lo, by + 4, ox + 18 - lo, ground], fill=(10, 45, 10, 255))
        # neck + head (left)
        d.rectangle([ox + 6, by - 8, ox + 10, by], fill=DINO_GREEN)
        d.ellipse([ox + 2, by - 11, ox + 10, by - 4], fill=DINO_GREEN)
        d.rectangle([ox + 0, by - 8, ox + 5, by - 6], fill=DINO_GREEN)  # snout
        d.point((ox + 4, by - 9), fill=ENEMY_RED)
        # accent stripe
        d.line([ox + 10, by - 4, ox + 18, by - 2], fill=DINO_ACCENT)
        # claw
        d.rectangle([ox + 11, ground if not leap else by + 8, ox + 12, (ground if not leap else by + 8) + 1], fill=CLAW)
    outline(sheet).save(f"{ROOT}/characters/raptor.png")


# ============================================================
# PTERANODON (28x20 design, 32x24 frame, facing left)
# ============================================================
def gen_pteranodon():
    FW, FH = 32, 24
    sheet = new_sheet(4, FW, FH)
    for i in range(4):
        d, ox = frame_draw(sheet, i, FW)
        up = i == 0
        dive = i == 2
        hurt = i == 3
        cy = 12
        # wings
        if dive:
            d.polygon([(ox + 8, cy), (ox + 26, cy - 4), (ox + 26, cy + 2)], fill=DINO_GREEN)
            d.polygon([(ox + 8, cy), (ox + 22, cy + 6), (ox + 14, cy + 2)], fill=(10, 45, 10, 255))
        else:
            wy = -7 if up else 6
            d.polygon([(ox + 10, cy), (ox + 26, cy + wy), (ox + 24, cy + 1)], fill=DINO_GREEN)
            d.polygon([(ox + 10, cy), (ox + 20, cy + wy // 2), (ox + 18, cy + 1)], fill=(10, 45, 10, 255))
        if hurt:
            cy = 16
        # body
        d.ellipse([ox + 6, cy - 3, ox + 16, cy + 3], fill=DINO_GREEN)
        # head crest + beak
        d.polygon([(ox + 6, cy - 2), (ox + 10, cy - 7), (ox + 12, cy - 2)], fill=DINO_ACCENT)
        d.polygon([(ox + 0, cy), (ox + 7, cy - 3), (ox + 7, cy + 1)], fill=CONCRETE)
        d.point((ox + 6, cy - 2), fill=ENEMY_RED)
    outline(sheet).save(f"{ROOT}/characters/pteranodon.png")


# ============================================================
# ANKYLOSAURUS (32x28 design, 40x32 frame, facing left)
# ============================================================
def gen_anky():
    FW, FH = 40, 32
    sheet = new_sheet(5, FW, FH)
    for i in range(5):
        d, ox = frame_draw(sheet, i, FW)
        spin = i in (2, 3)
        ground = 30
        by = 18
        # tail club (right side normally; during spin it swings to front-left)
        if spin:
            cx = 6 if i == 2 else 2
            d.line([ox + 14, by, ox + cx + 3, by + 2], fill=DINO_GREEN, width=3)
            d.ellipse([ox + cx - 3, by - 1, ox + cx + 4, by + 6], fill=CONCRETE)
        else:
            d.line([ox + 26, by, ox + 36, by - 2], fill=DINO_GREEN, width=3)
            d.ellipse([ox + 33, by - 5, ox + 40, by + 2], fill=CONCRETE)
        # body: wide armored dome
        d.ellipse([ox + 8, by - 8, ox + 30, by + 8], fill=DINO_GREEN)
        # armor plates
        for px in range(11, 28, 4):
            d.rectangle([ox + px, by - 7 + (px % 3), ox + px + 2, by - 5 + (px % 3)], fill=CONCRETE)
        # spikes
        for px in range(10, 30, 5):
            d.polygon([(ox + px, by - 8), (ox + px + 2, by - 11), (ox + px + 4, by - 8)], fill=DINO_ACCENT)
        # legs
        lo = (i % 2) * 2
        d.rectangle([ox + 10 + lo, by + 6, ox + 14 + lo, ground], fill=(10, 45, 10, 255))
        d.rectangle([ox + 24 - lo, by + 6, ox + 28 - lo, ground], fill=(10, 45, 10, 255))
        # head (left, low)
        if not spin:
            d.ellipse([ox + 2, by - 2, ox + 10, by + 5], fill=DINO_GREEN)
            d.point((ox + 4, by), fill=ENEMY_RED)
    outline(sheet).save(f"{ROOT}/characters/ankylosaurus.png")


# ============================================================
# TYRANNOKING boss (48x64 design, 64x72 frame, facing left)
# ============================================================
def gen_tyrannoking():
    FW, FH = 64, 72
    sheet = new_sheet(8, FW, FH)
    poses = ["idle_a", "idle_b", "bite_wind", "bite", "tail_wind", "tail_spin", "roar", "hurt"]
    for i, pose in enumerate(poses):
        d, ox = frame_draw(sheet, i, FW)
        ground = 70
        lean = {"bite": -6, "bite_wind": 3, "hurt": 5, "roar": 2}.get(pose, 0)
        hipx, hipy = 36 + lean, 44
        # tail (right side)
        tlift = 8 if pose == "tail_wind" else 0
        if pose == "tail_spin":
            # tail swung to front (left)
            for s in range(8):
                r = 6 - s * 0.5
                d.ellipse([ox + hipx - 4 - s * 4 - r, hipy - 6 - r, ox + hipx - 4 - s * 4 + r, hipy - 6 + r], fill=(90, 30, 30, 255))
        else:
            tx, ty = hipx + 4, hipy
            for s in range(8):
                r = 6 - s * 0.5
                tx += 3.4
                ty += 1.4 - tlift * 0.45
                d.ellipse([ox + tx - r, ty - r, ox + tx + r, ty + r], fill=(90, 30, 30, 255))
        # legs (massive)
        lo = (i % 2) * 2
        d.rectangle([ox + hipx - 10 + lo, hipy, ox + hipx - 2 + lo, ground], fill=(70, 22, 22, 255))
        d.rectangle([ox + hipx + 2 - lo, hipy, ox + hipx + 10 - lo, ground], fill=(110, 38, 38, 255))
        d.rectangle([ox + hipx - 10, ground - 3, ox + hipx - 6, ground], fill=CLAW)
        # body
        d.ellipse([ox + hipx - 14, 22, ox + hipx + 12, hipy + 8], fill=(110, 38, 38, 255))
        d.ellipse([ox + hipx - 14, 32, ox + hipx + 2, hipy + 8], fill=(90, 30, 30, 255))
        # dorsal spikes
        for sx in range(-12, 10, 5):
            d.polygon([(ox + hipx + sx, 24), (ox + hipx + sx + 2, 18), (ox + hipx + sx + 4, 24)], fill=ENEMY_RED)
        # tiny arms
        d.rectangle([ox + hipx - 14, 34, ox + hipx - 8, 37], fill=(110, 38, 38, 255))
        # neck + head (left)
        head_up = 6 if pose == "roar" else 0
        hx = hipx - 18 - (6 if pose == "bite" else 0)
        hy = 18 - head_up
        d.rectangle([ox + hx + 6, hy + 4, ox + hipx - 8, 30], fill=(110, 38, 38, 255))
        d.ellipse([ox + hx - 6, hy - 6, ox + hx + 12, hy + 10], fill=(110, 38, 38, 255))
        # jaws
        mouth = {"bite_wind": 5, "bite": 7, "roar": 8, "hurt": 3}.get(pose, 1)
        jaw_glow = ENEMY_RED if pose in ("bite_wind", "roar") else (70, 22, 22, 255)
        d.rectangle([ox + hx - 14, hy - 2, ox + hx, hy + 2], fill=(110, 38, 38, 255))       # upper snout
        d.rectangle([ox + hx - 12, hy + mouth, ox + hx, hy + mouth + 3], fill=jaw_glow)     # lower jaw
        # teeth
        for tx2 in range(-12, -2, 3):
            d.rectangle([ox + hx + tx2, hy + 2, ox + hx + tx2 + 1, hy + 4], fill=CLAW)
        d.point((ox + hx - 2, hy - 3), fill=EYE)
        d.point((ox + hx - 1, hy - 3), fill=EYE)
    outline(sheet).save(f"{ROOT}/characters/tyrannoking.png")


# ============================================================
# FX sheets
# ============================================================
def gen_fx():
    # atomic beam segment 16x8 (tiled horizontally in engine)
    img = Image.new("RGBA", (16, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 1, 15, 6], fill=FIN_GLOW)
    d.rectangle([0, 3, 15, 4], fill=WHITE)
    img.save(f"{ROOT}/fx/beam.png")
    # fireball 12x12
    img = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, 10, 10], fill=FIN_CORE)
    d.ellipse([3, 3, 8, 8], fill=WHITE)
    img.save(f"{ROOT}/fx/fireball.png")
    # explosion: 3 frames of 24x24
    sheet = new_sheet(3, 24, 24)
    for i in range(3):
        d, ox = frame_draw(sheet, i, 24)
        r = 5 + i * 4
        d.ellipse([ox + 12 - r, 12 - r, ox + 12 + r, 12 + r], fill=FIRE_GLOW if i < 2 else RUBBLE)
        if i < 2:
            d.ellipse([ox + 12 - r // 2, 12 - r // 2, ox + 12 + r // 2, 12 + r // 2], fill=WHITE if i == 0 else FIRE_CORE)
    sheet.save(f"{ROOT}/fx/explosion.png")
    # dust puff: 2 frames 16x16
    sheet = new_sheet(2, 16, 16)
    for i in range(2):
        d, ox = frame_draw(sheet, i, 16)
        for _ in range(6 + i * 3):
            x, y = random.randint(2, 13), random.randint(6 - i * 3, 13)
            d.ellipse([ox + x - 2, y - 2, ox + x + 2, y + 2], fill=(107, 114, 128, 160))
        random.seed(7 + i)
    sheet.save(f"{ROOT}/fx/dust.png")
    # shockwave ring 32x16
    img = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 4, 30, 14], outline=FIN_GLOW, width=2)
    img.save(f"{ROOT}/fx/shockwave.png")
    # missile/projectile shell 8x4
    img = Image.new("RGBA", (8, 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 6, 3], fill=ENEMY_RED)
    d.rectangle([6, 1, 7, 2], fill=FIRE_GLOW)
    img.save(f"{ROOT}/fx/shell.png")
    # white pixel
    Image.new("RGBA", (2, 2), WHITE).save(f"{ROOT}/fx/px.png")


# ============================================================
# BACKGROUNDS (3 themes) — each: sky 720x640, far 720x140,
# near 720x100, ground 720x80
# ============================================================
def vgrad(w, h, top, bottom):
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[k] + (bottom[k] - top[k]) * t) for k in range(3)) + (255,)
        for x in range(w):
            img.putpixel((x, y), c)
    return img


def gen_backgrounds():
    W = 720
    themes = {
        "beach": dict(sky_top=(28, 20, 48), sky_bot=(180, 80, 50), far=(25, 22, 40),
                      near=(50, 40, 45), ground=(120, 96, 60), ground2=(96, 76, 48)),
        "jungle": dict(sky_top=(10, 24, 18), sky_bot=(38, 70, 45), far=(14, 34, 22),
                       near=(24, 48, 30), ground=(46, 64, 36), ground2=(36, 50, 28)),
        "volcano": dict(sky_top=(13, 17, 23), sky_bot=(120, 35, 15), far=(30, 14, 12),
                        near=(55, 25, 18), ground=(60, 44, 40), ground2=(45, 32, 30)),
    }
    rng = random.Random(42)
    for name, th in themes.items():
        sky = vgrad(W, 640, th["sky_top"], th["sky_bot"])
        d = ImageDraw.Draw(sky)
        for _ in range(4):  # drifting clouds
            cx, cy = rng.randint(0, W), rng.randint(40, 200)
            for k in range(3):
                d.ellipse([cx + k * 14 - 16, cy - 6 + (k % 2) * 3, cx + k * 14 + 16, cy + 8],
                          fill=tuple(min(255, c + 18) for c in th["sky_top"]) + (140,))
        if name == "volcano":
            # ember glow spots
            for _ in range(40):
                x, y = rng.randint(0, W - 1), rng.randint(320, 630)
                d.point((x, y), fill=(249, 115, 22, rng.randint(60, 160)))
        sky.save(f"{ROOT}/backgrounds/{name}_sky.png")

        far = Image.new("RGBA", (W, 140), (0, 0, 0, 0))
        d = ImageDraw.Draw(far)
        x = 0
        while x < W:
            if name == "beach":
                bw, bh = rng.randint(30, 70), rng.randint(20, 60)  # dunes/rocks
                d.ellipse([x, 140 - bh, x + bw, 140 + bh], fill=th["far"] + (255,))
            elif name == "jungle":
                bw, bh = rng.randint(16, 40), rng.randint(40, 110)  # ruined pillars/trees
                d.rectangle([x, 140 - bh, x + bw, 140], fill=th["far"] + (255,))
                d.ellipse([x - 8, 140 - bh - 18, x + bw + 8, 140 - bh + 8], fill=(10, 26, 16, 255))
            else:
                bw, bh = rng.randint(24, 56), rng.randint(30, 120)  # jagged volcano rock + ruined towers
                d.polygon([(x, 140), (x + bw // 2, 140 - bh), (x + bw, 140)], fill=th["far"] + (255,))
                if rng.random() < 0.4:
                    d.rectangle([x + bw // 2, 140 - bh - 10, x + bw // 2 + 2, 140 - bh], fill=FIRE_GLOW)
            x += bw + rng.randint(4, 24)
        # tokyo-tower-ish silhouette once per theme
        tx = rng.randint(100, W - 160)
        d.polygon([(tx, 140), (tx + 24, 20), (tx + 48, 140)], outline=th["far"] + (255,))
        d.line([tx + 8, 100, tx + 40, 100], fill=th["far"] + (255,), width=3)
        far.save(f"{ROOT}/backgrounds/{name}_far.png")

        near = Image.new("RGBA", (W, 100), (0, 0, 0, 0))
        d = ImageDraw.Draw(near)
        x = 0
        while x < W:
            r = rng.random()
            y0 = rng.randint(60, 84)
            if r < 0.4:  # rubble mound
                d.ellipse([x, y0, x + rng.randint(20, 40), 100 + 10], fill=th["near"] + (255,))
            elif r < 0.7:  # broken wall
                w2, h2 = rng.randint(14, 30), rng.randint(16, 36)
                d.rectangle([x, 100 - h2, x + w2, 100], fill=th["near"] + (255,))
                d.rectangle([x + 3, 100 - h2 + 4, x + 7, 100 - h2 + 9], fill=th["sky_top"] + (255,))
            else:  # fire
                d.polygon([(x, 100), (x + 6, 78), (x + 12, 100)], fill=FIRE_GLOW)
                d.polygon([(x + 3, 100), (x + 6, 86), (x + 9, 100)], fill=FIRE_CORE)
            x += rng.randint(30, 80)
        near.save(f"{ROOT}/backgrounds/{name}_near.png")

        ground = Image.new("RGBA", (W, 80), th["ground"] + (255,))
        d = ImageDraw.Draw(ground)
        for _ in range(160):
            x, y = rng.randint(0, W - 4), rng.randint(0, 76)
            d.rectangle([x, y, x + rng.randint(1, 4), y + rng.randint(1, 2)], fill=th["ground2"] + (255,))
        d.rectangle([0, 0, W, 2], fill=tuple(min(255, c + 30) for c in th["ground"]) + (255,))
        ground.save(f"{ROOT}/backgrounds/{name}_ground.png")


# ============================================================
# UI: buttons, dpad, icon
# ============================================================
def gen_ui():
    def circle_btn(name, color, size=96):
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse([2, 2, size - 3, size - 3], fill=color + (110,), outline=color + (230,), width=3)
        img.save(f"{ROOT}/ui/{name}.png")
    circle_btn("btn_attack", (239, 68, 68))
    circle_btn("btn_jump", (59, 130, 246))
    circle_btn("btn_special", (168, 85, 247), 112)
    # d-pad
    size = 132
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    a = size // 3
    col = (200, 200, 210, 90)
    edge = (230, 230, 240, 200)
    d.rounded_rectangle([a, 2, 2 * a, size - 3], 8, fill=col, outline=edge, width=2)
    d.rounded_rectangle([2, a, size - 3, 2 * a], 8, fill=col, outline=edge, width=2)
    # arrows
    m = size // 2
    for (pts) in [[(m - 8, 20), (m + 8, 20), (m, 8)], [(m - 8, size - 20), (m + 8, size - 20), (m, size - 8)],
                  [(20, m - 8), (20, m + 8), (8, m)], [(size - 20, m - 8), (size - 20, m + 8), (size - 8, m)]]:
        d.polygon(pts, fill=edge)
    img.save(f"{ROOT}/ui/dpad.png")

    # app icon 512x512: godzilla frame scaled up on dark gradient
    icon = vgrad(512, 512, (13, 17, 23), (30, 41, 59)).convert("RGBA")
    gz = Image.open(f"{ROOT}/characters/godzilla.png").crop((0, 0, GZ_FW, GZ_FH))
    fins = Image.open(f"{ROOT}/characters/godzilla_fins.png").crop((0, 0, GZ_FW, GZ_FH))
    # tint fins teal
    tinted = Image.new("RGBA", fins.size, (0, 0, 0, 0))
    fp, tp = fins.load(), tinted.load()
    for y in range(fins.size[1]):
        for x in range(fins.size[0]):
            if fp[x, y][3] > 10:
                tp[x, y] = FIN_GLOW
    gz.alpha_composite(tinted)
    big = gz.resize((432, 432), Image.NEAREST)
    icon.alpha_composite(big, (40, 60))
    d = ImageDraw.Draw(icon)
    d.rectangle([0, 0, 511, 511], outline=(45, 212, 191, 255), width=8)
    icon.save(os.path.join(os.path.dirname(__file__), "..", "icon.png"))


if __name__ == "__main__":
    random.seed(7)
    os.makedirs(f"{ROOT}/characters", exist_ok=True)
    os.makedirs(f"{ROOT}/backgrounds", exist_ok=True)
    os.makedirs(f"{ROOT}/fx", exist_ok=True)
    os.makedirs(f"{ROOT}/ui", exist_ok=True)
    gen_godzilla()
    gen_raptor()
    gen_pteranodon()
    gen_anky()
    gen_tyrannoking()
    gen_fx()
    gen_backgrounds()
    gen_ui()
    print("art OK")

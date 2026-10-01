#!/usr/bin/env python3
"""Extra art for levels 4-8 + kid-friendly icons. Run after gen_art.py."""
import os, random
from PIL import Image, ImageDraw
from gen_art import (ROOT, new_sheet, outline, frame_draw, vgrad, BLACK, WHITE, CLAW, EYE,
                     ENEMY_RED, CONCRETE, RUBBLE, FIRE_GLOW, FIRE_CORE, FIN_GLOW, FIN_CORE,
                     DINO_GREEN, DINO_ACCENT)

TANK_METAL = (75, 85, 99, 255)      # 4b5563
TANK_DARK = (55, 62, 72, 255)
ARMY = (77, 92, 58, 255)
MECHA_BLUE = (30, 58, 95, 255)      # 1e3a5f
MECHA_SILVER = (148, 163, 184, 255)
MECHA_GLOW = (168, 85, 247, 255)    # a855f7


# ---------------- TANK (32x24 frame, facing left) ----------------
def gen_tank():
    FW, FH = 32, 24
    sheet = new_sheet(3, FW, FH)
    for i in range(3):
        d, ox = frame_draw(sheet, i, FW)
        y = 2 if i == 2 else 0
        # treads
        d.rounded_rectangle([ox + 3, 16 + y, ox + 29, 22], 3, fill=TANK_DARK)
        for wx in range(6, 28, 5):
            d.ellipse([ox + wx - 2, 17 + y, ox + wx + 2, 21], fill=TANK_METAL)
        # hull + turret
        d.polygon([(ox + 4, 16 + y), (ox + 7, 11 + y), (ox + 27, 11 + y), (ox + 29, 16 + y)], fill=ARMY)
        d.rounded_rectangle([ox + 11, 6 + y, ox + 23, 12 + y], 2, fill=ARMY)
        recoil = 2 if i == 1 else 0
        d.rectangle([ox + 0 + recoil, 8 + y, ox + 12, 10 + y], fill=TANK_METAL)  # barrel
        d.rectangle([ox + 16, 8 + y, ox + 18, 9 + y], fill=ENEMY_RED)  # lane-colored sensor
        if i == 1:
            d.ellipse([ox - 1, 6, ox + 5, 12], fill=FIRE_GLOW)
            d.ellipse([ox + 0, 7, ox + 3, 11], fill=WHITE)
    outline(sheet).save(f"{ROOT}/characters/tank.png")


# ---------------- HELICOPTER (32x24, facing left) ----------------
def gen_heli():
    FW, FH = 32, 24
    sheet = new_sheet(3, FW, FH)
    for i in range(3):
        d, ox = frame_draw(sheet, i, FW)
        # rotor
        if i == 0:
            d.rectangle([ox + 2, 2, ox + 28, 3], fill=MECHA_SILVER)
        else:
            d.rectangle([ox + 9, 2, ox + 21, 3], fill=MECHA_SILVER)
        d.rectangle([ox + 15, 3, ox + 16, 7], fill=TANK_DARK)
        # body
        d.ellipse([ox + 4, 7, ox + 20, 17], fill=ARMY)
        d.polygon([(ox + 18, 9), (ox + 30, 10), (ox + 30, 13), (ox + 18, 14)], fill=ARMY)  # tail boom
        d.rectangle([ox + 28, 6, ox + 30, 13], fill=ARMY)
        d.ellipse([ox + 5, 9, ox + 11, 13], fill=(125, 211, 252, 255))  # cockpit
        # skids + guns
        d.rectangle([ox + 6, 19, ox + 18, 20], fill=TANK_DARK)
        d.rectangle([ox + 8, 17, ox + 8, 19], fill=TANK_DARK)
        d.rectangle([ox + 16, 17, ox + 16, 19], fill=TANK_DARK)
        d.rectangle([ox + 1, 14, ox + 7, 15], fill=TANK_METAL)
        d.rectangle([ox + 12, 15, ox + 14, 16], fill=ENEMY_RED)
        if i == 2:
            d.line([ox + 6, 8, ox + 14, 16], fill=FIRE_GLOW)
    outline(sheet).save(f"{ROOT}/characters/helicopter.png")


# ---------------- JETPACK RAPTOR (32x32, facing left) ----------------
def gen_jetraptor():
    FW = FH = 32
    sheet = new_sheet(4, FW, FH)
    body = (60, 70, 40, 255)
    for i in range(4):
        d, ox = frame_draw(sheet, i, FW)
        by = 16 + (2 if i == 1 else 0) + (3 if i == 3 else 0)
        # flame
        fl = 6 if i % 2 == 0 else 9
        d.polygon([(ox + 19, by + 6), (ox + 23, by + 6), (ox + 21, by + 6 + fl)], fill=FIRE_GLOW)
        d.polygon([(ox + 20, by + 6), (ox + 22, by + 6), (ox + 21, by + 3 + fl)], fill=WHITE)
        # jetpack
        d.rounded_rectangle([ox + 17, by - 6, ox + 25, by + 6], 2, fill=TANK_METAL)
        # tail
        for s in range(5):
            r = 3 - s * 0.4
            d.ellipse([ox + 18 + s * 2 - r, by + 1 - r, ox + 18 + s * 2 + r, by + 1 + r], fill=body)
        d.ellipse([ox + 8, by - 4, ox + 20, by + 5], fill=body)
        # dangling legs
        d.rectangle([ox + 10, by + 3, ox + 12, by + 9], fill=body)
        d.rectangle([ox + 14, by + 3, ox + 16, by + 10], fill=body)
        if i == 2:  # dive pose: head lower
            by += 3
        d.rectangle([ox + 6, by - 8, ox + 10, by], fill=body)
        d.ellipse([ox + 2, by - 11, ox + 10, by - 4], fill=body)
        d.rectangle([ox + 0, by - 8, ox + 5, by - 6], fill=body)
        d.point((ox + 4, by - 9), fill=ENEMY_RED)
        d.line([ox + 10, by - 4, ox + 18, by - 2], fill=DINO_ACCENT)
    outline(sheet).save(f"{ROOT}/characters/jetraptor.png")


# ---------------- SUPER X (64x48, facing left) ----------------
def gen_superx():
    FW, FH = 64, 48
    sheet = new_sheet(4, FW, FH)
    hull = (100, 116, 139, 255)
    hull_dk = (71, 85, 105, 255)
    for i in range(4):
        d, ox = frame_draw(sheet, i, FW)
        # main saucer-battleship hull
        d.polygon([(ox + 2, 26), (ox + 14, 16), (ox + 54, 16), (ox + 62, 24), (ox + 56, 32), (ox + 10, 32)], fill=hull)
        d.polygon([(ox + 10, 32), (ox + 56, 32), (ox + 50, 37), (ox + 16, 37)], fill=hull_dk)
        # bridge
        d.rounded_rectangle([ox + 24, 8, ox + 44, 17], 3, fill=hull)
        d.rectangle([ox + 27, 10, ox + 41, 13], fill=(125, 211, 252, 255))
        # engines (glow)
        for ex in (48, 56):
            d.rectangle([ox + ex, 18, ox + ex + 4, 22], fill=FIRE_GLOW)
        # cadmium laser emitter at nose
        glow = ENEMY_RED if i == 2 else (180, 40, 40, 255)
        d.ellipse([ox + 0, 22, ox + 8, 30], fill=glow)
        if i == 2:
            d.ellipse([ox + 2, 24, ox + 6, 28], fill=WHITE)
        # missile bay
        if i == 1:
            d.rectangle([ox + 20, 32, ox + 44, 38], fill=BLACK)
            for mx in range(22, 44, 5):
                d.rectangle([ox + mx, 34, ox + mx + 2, 38], fill=FIRE_GLOW)
        # stripes
        d.line([ox + 14, 24, ox + 50, 24], fill=(251, 191, 36, 255))
        if i == 3:
            d.line([ox + 20, 18, ox + 30, 30], fill=FIRE_GLOW, width=2)
    outline(sheet).save(f"{ROOT}/characters/superx.png")


# ---------------- MECHAGODZILLA (64x72, facing left) ----------------
def gen_mecha():
    FW, FH = 64, 72
    sheet = new_sheet(8, FW, FH)
    # 0,1 idle | 2 chest missiles | 3 dash | 4 plasma breath | 5 eyes flash | 6 zero charge | 7 hurt
    for i in range(8):
        d, ox = frame_draw(sheet, i, FW)
        ground = 70
        lean = {3: -6, 7: 5, 4: -2}.get(i, 0)
        hx, hy = 30 + lean, 42
        # tail (right)
        for s in range(7):
            r = 5 - s * 0.5
            d.ellipse([ox + hx + 8 + s * 3.5 - r, hy + 6 + s * 1.3 - r, ox + hx + 8 + s * 3.5 + r, hy + 6 + s * 1.3 + r], fill=MECHA_BLUE)
        # legs
        lo = (i % 2) * 2
        d.rectangle([ox + hx - 8 + lo, hy + 4, ox + hx - 1 + lo, ground], fill=MECHA_BLUE)
        d.rectangle([ox + hx + 3 - lo, hy + 4, ox + hx + 10 - lo, ground], fill=MECHA_SILVER)
        d.rectangle([ox + hx - 9, ground - 3, ox + hx - 5, ground], fill=CLAW)
        # torso
        d.rounded_rectangle([ox + hx - 12, 20, ox + hx + 10, hy + 8], 5, fill=MECHA_SILVER)
        d.rectangle([ox + hx - 10, 26, ox + hx + 6, hy + 4], fill=MECHA_BLUE)
        # chest reactor / core
        core = {6: (125, 211, 252, 255), 2: FIRE_GLOW}.get(i, MECHA_GLOW)
        d.ellipse([ox + hx - 7, 28, ox + hx + 1, 36], fill=core)
        if i in (2, 6):
            d.ellipse([ox + hx - 5, 30, ox + hx - 1, 34], fill=WHITE)
        # dorsal spikes (silver)
        for sx in range(-8, 10, 4):
            d.polygon([(ox + hx + sx, 21), (ox + hx + sx + 2, 15), (ox + hx + sx + 4, 21)], fill=MECHA_SILVER)
        # arm
        arm_ext = 8 if i in (2, 3) else 0
        d.rectangle([ox + hx - 14 - arm_ext, 30, ox + hx - 8, 33], fill=MECHA_SILVER)
        d.rectangle([ox + hx - 16 - arm_ext, 29, ox + hx - 14 - arm_ext, 34], fill=CLAW)
        # head
        hd_x, hd_y = hx - 16, 14
        d.rounded_rectangle([ox + hd_x - 2, hd_y - 4, ox + hd_x + 12, hd_y + 6], 3, fill=MECHA_SILVER)
        d.rectangle([ox + hd_x - 10, hd_y - 1, ox + hd_x, hd_y + 4], fill=MECHA_SILVER)
        mouth = WHITE if i == 4 else MECHA_BLUE
        d.rectangle([ox + hd_x - 9, hd_y + 3, ox + hd_x - 1, hd_y + 5], fill=mouth)
        eye = (96, 165, 250, 255) if i == 5 else EYE
        d.rectangle([ox + hd_x + 1, hd_y - 2, ox + hd_x + 3, hd_y - 1], fill=eye)
        if i == 4:  # beam start glow
            d.ellipse([ox + hd_x - 16, hd_y, ox + hd_x - 8, hd_y + 8], fill=(224, 242, 254, 255))
        if i == 3:  # jet flames from back
            d.polygon([(ox + hx + 10, 24), (ox + hx + 20, 22), (ox + hx + 10, 30)], fill=FIRE_GLOW)
    outline(sheet).save(f"{ROOT}/characters/mechagodzilla.png")


# ---------------- FX extras ----------------
def gen_fx_ext():
    img = Image.new("RGBA", (12, 6), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 1, 9, 4], fill=MECHA_SILVER)
    d.polygon([(0, 2), (2, 0), (2, 5)], fill=ENEMY_RED)
    d.rectangle([10, 1, 11, 4], fill=FIRE_GLOW)
    outline(img).save(f"{ROOT}/fx/missile.png")
    # drone 12x8
    img = Image.new("RGBA", (12, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([2, 2, 10, 7], fill=TANK_METAL)
    d.rectangle([0, 1, 11, 1], fill=MECHA_SILVER)
    d.point((4, 4), fill=(34, 197, 94, 255))
    outline(img).save(f"{ROOT}/fx/drone.png")
    # hex shield 32x32
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(16, 1), (29, 8), (29, 24), (16, 31), (3, 24), (3, 8)]
    d.polygon(pts, fill=(94, 234, 212, 50), outline=(94, 234, 212, 220))
    d.line([(16, 1), (16, 31)], fill=(94, 234, 212, 90))
    d.line([(3, 8), (29, 24)], fill=(94, 234, 212, 90))
    d.line([(29, 8), (3, 24)], fill=(94, 234, 212, 90))
    img.save(f"{ROOT}/fx/shield.png")


# ---------------- KID-FRIENDLY ICONS (16x16, rendered 3-4x) ----------------
def icon(name, draw_fn, size=16):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(img))
    outline(img).save(f"{ROOT}/ui/icon_{name}.png")


def gen_icons():
    os.makedirs(f"{ROOT}/ui", exist_ok=True)
    # BREATH: blue atomic beam bursting from a fin
    def breath(d):
        d.polygon([(1, 13), (4, 6), (7, 13)], fill=FIN_CORE)
        d.polygon([(3, 13), (4, 9), (5, 13)], fill=WHITE)
        d.rectangle([6, 5, 15, 9], fill=FIN_GLOW)
        d.rectangle([6, 6, 15, 8], fill=WHITE)
        d.ellipse([4, 3, 10, 11], fill=FIN_GLOW)
        d.ellipse([6, 5, 8, 9], fill=WHITE)
    icon("breath", breath)
    # CLAWS: three red slashes
    def claws(d):
        for k in range(3):
            x = 3 + k * 4
            d.line([(x, 14), (x + 5, 1)], fill=ENEMY_RED, width=3)
            d.line([(x + 1, 13), (x + 5, 2)], fill=WHITE, width=1)
    icon("claws", claws)
    # HEALTH: big red heart
    def heart(d):
        d.ellipse([1, 2, 8, 9], fill=ENEMY_RED)
        d.ellipse([7, 2, 14, 9], fill=ENEMY_RED)
        d.polygon([(1, 6), (14, 6), (8, 14)], fill=ENEMY_RED)
        d.rectangle([3, 4, 4, 5], fill=WHITE)
    icon("health", heart)
    # SPEED: yellow lightning bolt
    def bolt(d):
        d.polygon([(9, 0), (2, 9), (7, 9), (5, 15), (13, 5), (8, 5), (11, 0)], fill=(250, 204, 21, 255))
        d.line([(9, 1), (4, 8)], fill=WHITE)
    icon("speed", bolt)
    # BLAST: purple nuclear burst
    def blast(d):
        for a in range(8):
            import math
            ang = a * math.pi / 4
            d.line([(8, 8), (8 + 7 * math.cos(ang), 8 + 7 * math.sin(ang))], fill=MECHA_GLOW, width=2)
        d.ellipse([3, 3, 12, 12], fill=MECHA_GLOW)
        d.ellipse([5, 5, 10, 10], fill=(233, 213, 255, 255))
        d.ellipse([7, 7, 8, 8], fill=WHITE)
    icon("blast", blast)
    # GEM (evolution point)
    def gem(d):
        d.polygon([(4, 2), (11, 2), (14, 6), (7.5, 14), (1, 6)], fill=(34, 211, 238, 255))
        d.polygon([(4, 2), (7.5, 6), (1, 6)], fill=(165, 243, 252, 255))
        d.polygon([(7.5, 6), (14, 6), (7.5, 14)], fill=(8, 145, 178, 255))
        d.point((5, 4), fill=WHITE)
    icon("gem", gem)
    # STAR full / empty
    import math
    def star_pts(cx, cy, r1, r2):
        pts = []
        for k in range(10):
            ang = -math.pi / 2 + k * math.pi / 5
            r = r1 if k % 2 == 0 else r2
            pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
        return pts
    icon("star", lambda d: (d.polygon(star_pts(8, 8.5, 7.5, 3.2), fill=(250, 204, 21, 255)), d.point((6, 6), fill=WHITE)))
    icon("star_empty", lambda d: d.polygon(star_pts(8, 8.5, 7.5, 3.2), fill=(51, 65, 85, 255)))
    # LOCK
    def lock(d):
        d.arc([4, 1, 11, 10], 180, 360, fill=MECHA_SILVER, width=2)
        d.rectangle([4, 5, 5, 8], fill=MECHA_SILVER)
        d.rectangle([10, 5, 11, 8], fill=MECHA_SILVER)
        d.rounded_rectangle([2, 7, 13, 15], 2, fill=(250, 204, 21, 255))
        d.rectangle([7, 10, 8, 12], fill=BLACK)
    icon("lock", lock)
    # CHECK mark
    icon("check", lambda d: d.line([(2, 8), (6, 12), (14, 3)], fill=(34, 197, 94, 255), width=3))
    # PLUS
    def plus(d):
        d.rectangle([6, 1, 9, 14], fill=WHITE)
        d.rectangle([1, 6, 14, 9], fill=WHITE)
    icon("plus", plus)
    # JUMP: big up arrow
    def jump(d):
        d.polygon([(8, 0), (15, 8), (11, 8), (11, 15), (5, 15), (5, 8), (1, 8)], fill=WHITE)
    icon("jump", jump)
    # HAND (finger hint for the training level)
    def hand(d):
        d.rounded_rectangle([5, 0, 9, 9], 2, fill=(255, 237, 213, 255))
        d.rounded_rectangle([3, 6, 13, 15], 3, fill=(255, 237, 213, 255))
        d.line([(7, 1), (7, 3)], fill=(250, 204, 170, 255))
    icon("hand", hand)
    # SKULL-ish boss marker (kaiju head)
    def boss(d):
        d.ellipse([2, 2, 13, 12], fill=ENEMY_RED)
        d.rectangle([4, 10, 11, 14], fill=ENEMY_RED)
        d.rectangle([4, 5, 6, 7], fill=BLACK)
        d.rectangle([9, 5, 11, 7], fill=BLACK)
        for x in (5, 7, 9):
            d.rectangle([x, 12, x, 14], fill=WHITE)
    icon("boss", boss)


# ---------------- NEW BACKGROUND THEMES ----------------
def gen_bg_ext():
    W = 720
    themes = {
        "caves": dict(sky_top=(8, 10, 24), sky_bot=(40, 30, 70), far=(30, 24, 56), near=(46, 38, 78),
                      ground=(58, 52, 80), ground2=(44, 40, 64), accent=(94, 234, 212, 255)),
        "base": dict(sky_top=(20, 40, 70), sky_bot=(150, 120, 90), far=(40, 50, 60), near=(60, 66, 70),
                     ground=(90, 92, 84), ground2=(70, 72, 66), accent=(239, 68, 68, 255)),
        "city": dict(sky_top=(20, 8, 8), sky_bot=(180, 70, 20), far=(30, 18, 18), near=(55, 30, 26),
                     ground=(70, 60, 58), ground2=(54, 46, 44), accent=(249, 115, 22, 255)),
        "lab": dict(sky_top=(6, 20, 20), sky_bot=(20, 60, 60), far=(14, 40, 42), near=(30, 60, 62),
                    ground=(52, 70, 72), ground2=(40, 54, 56), accent=(34, 197, 94, 255)),
        "silo": dict(sky_top=(8, 8, 18), sky_bot=(60, 30, 90), far=(24, 22, 40), near=(44, 40, 66),
                     ground=(64, 62, 76), ground2=(48, 46, 58), accent=(168, 85, 247, 255)),
    }
    rng = random.Random(99)
    for name, th in themes.items():
        sky = vgrad(W, 640, th["sky_top"], th["sky_bot"])
        d = ImageDraw.Draw(sky)
        if name == "caves":
            for x in range(0, W, 28):  # stalactites
                h = rng.randint(30, 110)
                d.polygon([(x, 0), (x + 14, h), (x + 28, 0)], fill=th["far"] + (255,))
        else:
            for _ in range(4):
                cx, cy = rng.randint(0, W), rng.randint(40, 200)
                for k in range(3):
                    d.ellipse([cx + k * 14 - 16, cy - 6 + (k % 2) * 3, cx + k * 14 + 16, cy + 8],
                              fill=tuple(min(255, c + 22) for c in th["sky_top"]) + (150,))
        for _ in range(30):
            d.point((rng.randint(0, W - 1), rng.randint(250, 630)), fill=th["accent"][:3] + (rng.randint(60, 150),))
        sky.save(f"{ROOT}/backgrounds/{name}_sky.png")

        far = Image.new("RGBA", (W, 140), (0, 0, 0, 0))
        d = ImageDraw.Draw(far)
        x = 0
        while x < W:
            bw, bh = rng.randint(22, 56), rng.randint(40, 125)
            col = th["far"] + (255,)
            if name == "caves":  # glowing crystals
                d.polygon([(x, 140), (x + bw // 2, 140 - bh), (x + bw, 140)], fill=col)
                d.polygon([(x + bw // 3, 140), (x + bw // 2, 140 - bh // 2), (x + 2 * bw // 3, 140)], fill=th["accent"])
            elif name == "base":  # hangars + radar towers
                if rng.random() < 0.5:
                    d.chord([x, 140 - bh // 2, x + bw * 2, 140 + bh // 2], 180, 360, fill=col)
                    bw *= 2
                else:
                    d.rectangle([x + bw // 2 - 2, 140 - bh, x + bw // 2 + 2, 140], fill=col)
                    d.ellipse([x + bw // 2 - 8, 140 - bh - 6, x + bw // 2 + 8, 140 - bh + 4], fill=col)
                    d.point((x + bw // 2, 140 - bh - 2), fill=th["accent"])
            elif name == "city":  # burning skyscrapers
                d.rectangle([x, 140 - bh, x + bw, 140], fill=col)
                for wy in range(140 - bh + 6, 136, 8):
                    for wx in range(x + 4, x + bw - 3, 7):
                        if rng.random() < 0.4:
                            d.rectangle([wx, wy, wx + 2, wy + 3], fill=FIRE_GLOW)
                if rng.random() < 0.4:
                    d.polygon([(x + 4, 140 - bh), (x + bw // 2, 140 - bh - 18), (x + bw - 4, 140 - bh)], fill=FIRE_GLOW)
            elif name == "lab":  # tanks + pipes
                d.rounded_rectangle([x, 140 - bh, x + bw, 140], 8, fill=col)
                d.rectangle([x + 5, 140 - bh + 10, x + bw - 5, 140 - bh + 30], fill=th["accent"][:3] + (120,))
                d.rectangle([x + bw, 140 - 30, x + bw + 14, 140 - 26], fill=col)
            else:  # silo: missile silos + gantries
                d.rectangle([x, 140 - bh, x + bw, 140], fill=col)
                d.ellipse([x, 140 - bh - 6, x + bw, 140 - bh + 6], fill=col)
                d.line([x + bw // 2, 140 - bh, x + bw // 2, 140], fill=th["accent"], width=1)
            x += bw + rng.randint(4, 22)
        far.save(f"{ROOT}/backgrounds/{name}_far.png")

        near = Image.new("RGBA", (W, 100), (0, 0, 0, 0))
        d = ImageDraw.Draw(near)
        x = 0
        while x < W:
            r = rng.random()
            if r < 0.45:
                d.ellipse([x, rng.randint(60, 84), x + rng.randint(20, 40), 110], fill=th["near"] + (255,))
            elif r < 0.75:
                w2, h2 = rng.randint(14, 30), rng.randint(16, 36)
                d.rectangle([x, 100 - h2, x + w2, 100], fill=th["near"] + (255,))
            else:
                d.polygon([(x, 100), (x + 6, 80), (x + 12, 100)], fill=th["accent"])
            x += rng.randint(30, 80)
        near.save(f"{ROOT}/backgrounds/{name}_near.png")

        ground = Image.new("RGBA", (W, 80), th["ground"] + (255,))
        d = ImageDraw.Draw(ground)
        for _ in range(160):
            gx, gy = rng.randint(0, W - 4), rng.randint(0, 76)
            d.rectangle([gx, gy, gx + rng.randint(1, 4), gy + rng.randint(1, 2)], fill=th["ground2"] + (255,))
        d.rectangle([0, 0, W, 2], fill=tuple(min(255, c + 30) for c in th["ground"]) + (255,))
        ground.save(f"{ROOT}/backgrounds/{name}_ground.png")


def gen_thumbs():
    """Small level-select previews for every theme."""
    for name in ["beach", "jungle", "volcano", "caves", "base", "city", "lab", "silo"]:
        sky = Image.open(f"{ROOT}/backgrounds/{name}_sky.png").crop((0, 140, 240, 340))
        far = Image.open(f"{ROOT}/backgrounds/{name}_far.png").crop((0, 0, 240, 140))
        ground = Image.open(f"{ROOT}/backgrounds/{name}_ground.png").crop((0, 0, 240, 40))
        img = sky.copy()
        img.alpha_composite(far, (0, 20))
        img.alpha_composite(ground, (0, 160))
        img.resize((120, 100), Image.NEAREST).save(f"{ROOT}/ui/thumb_{name}.png")


if __name__ == "__main__":
    random.seed(5)
    if os.environ.get("ICONS_ONLY") != "1":
        gen_tank()
        gen_heli()
        gen_jetraptor()
        gen_superx()
        gen_mecha()
        gen_fx_ext()
    gen_icons()
    if os.environ.get("ICONS_ONLY") != "1":
        gen_bg_ext()
        gen_thumbs()
    print("ext art OK")

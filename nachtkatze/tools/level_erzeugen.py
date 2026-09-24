#!/usr/bin/env python3
"""Erzeugt alle Levelszenen von Nachtkatze aus dem Asset-Kit (GDD Abschnitt 5, 6, 8).

- Level 0 (Tutorial) und die Graubox-Spielwiese
- Level 1-10 samt LevelData-Ressourcen und Levelkatalog

Jedes Level 1-10 wird vor dem Schreiben geprueft: Kletterzonen enden auf einer
Flaeche und sind frei, das Ziel ist erreichbar, und es gibt immer eine Route
ueber die Fassadenebene an den Hunden vorbei (GDD Abschnitt 5).

Aufruf:  python3 nachtkatze/tools/level_erzeugen.py
"""
import math
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

K = dict(GESCHOSS=0, BALKON=1, MARKISE_OFFEN=2, MARKISE_ZU=3, DACH=4, HAUS=5,
         SOLAR=6, SAT=7, ANTENNE=8, KLIMA=9, LATERNE=10, STROMMAST=11, LEITUNG=12,
         PARKAUTO=13, FAHRAUTO=14, ZAUN=15, ZAUN_LUECKE=16, TOR=17, KIEFER=18,
         ZYPRESSE=19, OLIVE=20, OLEANDER=21, KIRCHTURM=22, TANKSTELLE=23,
         GRAETE=24, FISCH=25, NAPF=26, STRASSE=27, MAUER=28, REGENRINNE=29)

def xform(x, y, z):
    return "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)" % (x, y, z)

def piece(name, parent, kind, x, y, z, tiles=1, solid=True, yaw=0.0):
    lines = ['[node name="%s" parent="%s" instance=ExtResource("piece")]' % (name, parent),
             xform(x, y, z), "kind = %d" % kind]
    if tiles != 1:
        lines.append("tiles = %d" % tiles)
    if not solid:
        lines.append("solid = false")
    if yaw:
        lines.append("yaw_degrees = %s" % yaw)
    return "\n".join(lines) + "\n"

def node(name, parent, res, x, y, z, props=()):
    lines = ['[node name="%s" parent="%s" instance=ExtResource("%s")]' % (name, parent, res),
             xform(x, y, z)] + list(props)
    return "\n".join(lines) + "\n"

def header(exts):
    out = ["[gd_scene load_steps=%d format=3]\n" % (len(exts) + 2)]
    for rid, typ, path in exts:
        out.append('[ext_resource type="%s" path="%s" id="%s"]' % (typ, path, rid))
    return "\n".join(out) + "\n"

ENV = '''
[sub_resource type="Environment" id="Environment_level"]
background_mode = 1
background_color = Color(0.42, 0.62, 0.85, 1)
ambient_light_source = 2
ambient_light_color = Color(0.6, 0.72, 0.88, 1)
ambient_light_energy = 0.55
tonemap_mode = 3
glow_intensity = 0.35
glow_bloom = 0.0
glow_hdr_threshold = 1.2
'''

EXTS = [
    ("level", "Script", "res://scripts/levels/level.gd"),
    ("piece", "PackedScene", "res://scenes/world/asset_piece.tscn"),
    ("climb", "PackedScene", "res://scenes/world/climb_zone.tscn"),
    ("ledge", "PackedScene", "res://scenes/world/ledge_zone.tscn"),
    ("food", "PackedScene", "res://scenes/items/collectible.tscn"),
    ("bowl", "PackedScene", "res://scenes/items/food_bowl.tscn"),
    ("dog", "PackedScene", "res://scenes/enemies/dog.tscn"),
    ("cat", "PackedScene", "res://scenes/enemies/territory_cat.tscn"),
    ("player", "PackedScene", "res://scenes/player/player.tscn"),
    ("hud", "PackedScene", "res://scenes/ui/hud.tscn"),
    ("camera", "Script", "res://scripts/player/follow_camera.gd"),
    ("parallax", "PackedScene", "res://scenes/world/parallax_background.tscn"),
]

def common_head(root_name, data_path, extra_exts=()):
    exts = [("data", "Resource", data_path)] + EXTS + list(extra_exts)
    out = header(exts) + ENV
    out += '''
[node name="%s" type="Node3D"]
script = ExtResource("level")
level_data = ExtResource("data")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_level")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.8779, 0.3733, -0.2999, -0, 0.6262, 0.7796, 0.4789, -0.6845, 0.5498, 0, 14, 0)
light_energy = 1.0

[node name="Welt" type="Node3D" parent="."]
''' % root_name
    return out

def tail(player_x, player_y, camera_offset="Vector3(0, 1, 7)"):
    return '''
[node name="Hintergrund" parent="." instance=ExtResource("parallax")]
target_path = NodePath("../Camera3D")

[node name="Player" parent="." instance=ExtResource("player")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, 0)

[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.4, 7)
fov = 45.0
near = 0.05
far = 200.0
script = ExtResource("camera")
target_path = NodePath("../Player")
offset = %s

[node name="HUD" parent="." instance=ExtResource("hud")]
''' % (player_x, player_y, camera_offset)



def build_tutorial():
    t = common_head("Level00Tutorial", "res://resources/levels/level_00.tres",
                    [("hint", "PackedScene", "res://scenes/world/tutorial_hint.tscn")])
    W = "Welt"
    t += piece("Strasse", W, K["STRASSE"], 20, 0, 0, tiles=13)
    t += piece("Gartenmauer", W, K["MAUER"], 6, 0, 0)
    # Haus A mit Balkon
    t += piece("FassadeAUnten", W, K["GESCHOSS"], 13, 0, -1, tiles=2, solid=False)
    t += piece("FassadeAOben", W, K["GESCHOSS"], 13, 3, -1, tiles=2, solid=False)
    t += piece("DachHausA", W, K["DACH"], 13, 6, 0, tiles=4)
    t += piece("BalkonA", W, K["BALKON"], 13, 3, 0, tiles=2)
    t += piece("MarkiseA", W, K["MARKISE_ZU"], 16.2, 2.2, -0.8, solid=False)
    # Haus B mit grossem Dach
    t += piece("FassadeBUnten", W, K["GESCHOSS"], 26, 0, -1, tiles=3, solid=False)
    t += piece("FassadeBOben", W, K["GESCHOSS"], 26, 3, -1, tiles=3, solid=False)
    t += piece("DachB", W, K["DACH"], 26, 6, 0, tiles=5)
    # Haus C und Zielhaus
    t += piece("FassadeCUnten", W, K["GESCHOSS"], 34.5, 0, -1, solid=False)
    t += piece("FassadeCOben", W, K["GESCHOSS"], 34.5, 3, -1, solid=False)
    t += piece("DachC", W, K["DACH"], 34.5, 6, 0, tiles=2)
    t += piece("FassadeZielUnten", W, K["GESCHOSS"], 39.5, 0, -1, tiles=2, solid=False)
    t += piece("FassadeZielOben", W, K["GESCHOSS"], 39.5, 3, -1, tiles=2, solid=False)
    t += piece("ZielBalkon", W, K["BALKON"], 39.5, 6, 0, tiles=2)
    # Zierde
    t += '\n[node name="Zierde" type="Node3D" parent="."]\n'
    Z = "Zierde"
    t += piece("Zypresse", Z, K["ZYPRESSE"], 2.5, 0, -2.4, solid=False)
    t += piece("Oleander", Z, K["OLEANDER"], 8.6, 0, -2.3, solid=False)
    t += piece("Olivenbaum", Z, K["OLIVE"], 18.5, 0, -2.6, solid=False)
    t += piece("Kiefer", Z, K["KIEFER"], 31.5, 0, -2.8, solid=False)
    t += piece("Laterne1", Z, K["LATERNE"], 9.5, 0, -2.2, solid=False)
    t += piece("Laterne2", Z, K["LATERNE"], 24, 0, -2.2, solid=False)
    t += piece("Laterne3", Z, K["LATERNE"], 37, 0, -2.2, solid=False)
    t += piece("Gartentor", Z, K["TOR"], 4.4, 0, -2.2, solid=False)
    t += piece("Zaun", Z, K["ZAUN"], 2.2, 0, -2.2, tiles=2, solid=False)
    t += piece("Solarkollektor", Z, K["SOLAR"], 23.5, 6, -0.7, solid=False)
    t += piece("Klimageraet", Z, K["KLIMA"], 25.6, 6, -0.9, solid=False)
    t += piece("Antenne", Z, K["ANTENNE"], 29.5, 6, -0.7, solid=False)
    t += piece("Satellitenschuessel", Z, K["SAT"], 21.8, 6, -0.8, solid=False)
    t += piece("Tankstelle", Z, K["TANKSTELLE"], 9, 0, -10, solid=False)
    t += piece("Einfamilienhaus", Z, K["HAUS"], 44, 0, -7, solid=False)
    t += piece("Strommast", Z, K["STROMMAST"], 33, 0, -2.6, solid=False)
    # Regenrinnen als sichtbare Kletterelemente
    t += piece("RegenrinneA", W, K["REGENRINNE"], 10.2, 0, -0.55, solid=False)
    t += piece("RegenrinneB", W, K["REGENRINNE"], 20.4, 0, -0.55, tiles=2, solid=False)
    # Kletterzonen
    t += '\n[node name="Kletterzonen" type="Node3D" parent="."]\n'
    t += node("Regenrinne1", "Kletterzonen", "climb", 10.2, 1.5, -0.4,
              ["height = 3.0", "exit_direction = 1", "exit_offset = Vector3(1.2, 0.45, 0)"])
    t += node("Regenrinne2", "Kletterzonen", "climb", 20.4, 3, -0.4,
              ["height = 6.0", "exit_direction = 1", "exit_offset = Vector3(1.2, 0.45, 0)"])
    # Kanten
    t += '\n[node name="Kanten" type="Node3D" parent="."]\n'
    t += node("KanteDachB", "Kanten", "ledge", 20.85, 5.85, 0,
              ["facing = -1", "size = Vector3(0.5, 0.7, 1)", "exit_offset = Vector3(0.75, 0.6, 0)"])
    t += node("KanteDachC", "Kanten", "ledge", 32.35, 5.85, 0,
              ["facing = -1", "size = Vector3(0.5, 0.7, 1)", "exit_offset = Vector3(0.75, 0.6, 0)"])
    t += node("KanteZiel", "Kanten", "ledge", 37.35, 5.85, 0,
              ["facing = -1", "size = Vector3(0.5, 0.7, 1)", "exit_offset = Vector3(0.75, 0.6, 0)"])
    # Hinweise
    t += '\n[node name="Hinweise" type="Node3D" parent="."]\n'
    for name, x, y, hint, size in [
            ("HinweisLaufen", 1.5, 1, 1, "Vector3(4, 3, 2)"),
            ("HinweisSpringen", 3.6, 1, 2, "Vector3(2.4, 3, 2)"),
            ("HinweisKlettern", 9.4, 1, 3, "Vector3(2.4, 3, 2)"),
            ("HinweisFressen", 11.8, 3.7, 4, "Vector3(2.2, 1.8, 2)"),
            ("HinweisVorsichtHund", 17, 1, 5, "Vector3(2.6, 3, 2)"),
            ("HinweisKletternDach", 20.2, 1, 3, "Vector3(2.4, 3, 2)"),
            ("HinweisVorsichtKatze", 22.4, 6.6, 5, "Vector3(2.4, 2, 2)"),
            ("HinweisSprungLuecke", 30.2, 6.6, 2, "Vector3(2.2, 2, 2)")]:
        t += node(name, "Hinweise", "hint", x, y, 0, ["hint = %d" % hint, "size = %s" % size])
    # Gegner
    t += '\n[node name="Gegner" type="Node3D" parent="."]\n'
    t += node("SchlafenderHund", "Gegner", "dog", 19, 0.4, 0,
              ["dog_size = 0", "start_sleeping = true", "passive = true", "patrol_distance = 0.0"])
    t += node("PassiveRevierkatze", "Gegner", "cat", 26, 6.3, 0,
              ["passive = true", "territory_half_width = 2.5", "patrol_speed = 1.4"])
    # Futter
    t += '\n[node name="Futter" type="Node3D" parent="."]\n'
    for i, (x, y) in enumerate([(8, 0.6), (12.5, 3.6), (14.2, 3.6), (23.5, 6.6), (34.5, 6.6)]):
        t += node("Graete%d" % (i + 1), "Futter", "food", x, y, 0, ["kind = 0"])
    t += node("Futternapf", ".", "bowl", 39.5, 6, 0)
    t += tail(0, 0.4)
    open(scene_file("level_00_tutorial.tscn"), "w").write(t)


def build_greybox():
    W, Z = "Welt", "Zierde"
    g = common_head("LevelGraubox", "res://resources/levels/level_greybox.tres",
                    [("car", "PackedScene", "res://scenes/enemies/car.tscn")])
    g += piece("Strasse", W, K["STRASSE"], 30, 0, 0, tiles=18)
    g += piece("Gartenmauer", W, K["MAUER"], 4, 0, 0)
    g += piece("GeparktesAuto", W, K["PARKAUTO"], 8.5, 0, 0)
    g += piece("ZaunUnten", W, K["ZAUN_LUECKE"], 13, 0, 0)
    g += piece("ZaunOben", W, K["ZAUN"], 13, 1.3, 0)
    # Block A
    g += piece("FassadeAUnten", W, K["GESCHOSS"], 22, 0, -1, tiles=3, solid=False)
    g += piece("FassadeAOben", W, K["GESCHOSS"], 22, 3, -1, tiles=3, solid=False)
    g += piece("BalkonA1", W, K["BALKON"], 18.8, 3, 0, tiles=2)
    g += piece("BalkonA2", W, K["BALKON"], 26, 3, 0, tiles=3)
    g += piece("DachA", W, K["DACH"], 22, 6, 0, tiles=6)
    g += piece("MarkiseA", W, K["MARKISE_ZU"], 16.8, 2.2, -0.8, solid=False)
    # Daecher B und C samt unterer Route
    g += piece("DachB", W, K["DACH"], 31.5, 6, 0, tiles=2)
    g += piece("DachC", W, K["DACH"], 39.7, 6, 0, tiles=3)
    g += piece("BalkonB", W, K["BALKON"], 32, 3, 0, tiles=2)
    g += piece("MarkiseB", W, K["MARKISE_OFFEN"], 35, 4.2, 0)
    g += piece("FassadeBCUnten", W, K["GESCHOSS"], 34, 0, -1, tiles=3, solid=False)
    g += piece("FassadeBCOben", W, K["GESCHOSS"], 34, 3, -1, tiles=3, solid=False)
    # Block B mit Ziel
    g += piece("FassadeZiel1", W, K["GESCHOSS"], 51, 0, -1, tiles=4, solid=False)
    g += piece("FassadeZiel2", W, K["GESCHOSS"], 51, 3, -1, tiles=4, solid=False)
    g += piece("FassadeZiel3", W, K["GESCHOSS"], 51, 6, -1, tiles=4, solid=False)
    g += piece("BalkonB1", W, K["BALKON"], 47, 6, 0, tiles=2)
    g += piece("BalkonB2", W, K["BALKON"], 53, 6, 0, tiles=2)
    g += piece("ZielBalkon", W, K["BALKON"], 57.2, 9, 0, tiles=2)
    g += piece("DachZiel", W, K["DACH"], 51, 9, 0, tiles=3, solid=False)
    # Zierde
    g += '\n[node name="Zierde" type="Node3D" parent="."]\n'
    g += piece("Zypresse1", Z, K["ZYPRESSE"], 2, 0, -2.5, solid=False)
    g += piece("Olivenbaum", Z, K["OLIVE"], 10.8, 0, -2.7, solid=False)
    g += piece("Oleander1", Z, K["OLEANDER"], 15, 0, -2.4, solid=False)
    g += piece("Kiefer", Z, K["KIEFER"], 30, 0, -3, solid=False)
    g += piece("Zypresse2", Z, K["ZYPRESSE"], 41, 0, -2.6, solid=False)
    g += piece("Oleander2", Z, K["OLEANDER"], 60, 0, -2.4, solid=False)
    g += piece("Laterne1", Z, K["LATERNE"], 6, 0, -2.2, solid=False)
    g += piece("Laterne2", Z, K["LATERNE"], 20, 0, -2.2, solid=False)
    g += piece("Laterne3", Z, K["LATERNE"], 36, 0, -2.2, solid=False)
    g += piece("Laterne4", Z, K["LATERNE"], 50, 0, -2.2, solid=False)
    g += piece("Strommast1", Z, K["STROMMAST"], 25, 0, -2.8, solid=False)
    g += piece("Strommast2", Z, K["STROMMAST"], 33, 0, -2.8, solid=False)
    g += piece("Leitung", Z, K["LEITUNG"], 29, 4.6, -2.8, solid=False)
    g += piece("Gartentor", Z, K["TOR"], 11.6, 0, -2.2, solid=False)
    g += piece("Solarkollektor", Z, K["SOLAR"], 19, 6, -0.7, solid=False)
    g += piece("Klimageraet", Z, K["KLIMA"], 24.5, 6, -0.9, solid=False)
    g += piece("Antenne", Z, K["ANTENNE"], 26.5, 6, -0.7, solid=False)
    g += piece("Satellitenschuessel", Z, K["SAT"], 38, 6, -0.8, solid=False)
    g += piece("Tankstelle", Z, K["TANKSTELLE"], 62, 0, -9, solid=False)
    g += piece("Einfamilienhaus", Z, K["HAUS"], 2, 0, -8, solid=False)
    # Regenrinnen als sichtbare Kletterelemente
    g += piece("RegenrinneA", W, K["REGENRINNE"], 16.4, 0, -0.55, solid=False)
    g += piece("RegenrinneB", W, K["REGENRINNE"], 28.6, 3, -0.55, solid=False)
    g += piece("RegenrinneC", W, K["REGENRINNE"], 44.6, 0, -0.55, tiles=2, solid=False)
    g += piece("RegenrinneD", W, K["REGENRINNE"], 54.6, 6, -0.55, solid=False)
    # Kletterzonen
    g += '\n[node name="Kletterzonen" type="Node3D" parent="."]\n'
    g += node("Regenrinne1", "Kletterzonen", "climb", 16.4, 1.5, -0.4,
              ["height = 3.0", "exit_direction = 1", "exit_offset = Vector3(1.2, 0.45, 0)"])
    g += node("Regenrinne2", "Kletterzonen", "climb", 28.6, 4.5, -0.4,
              ["height = 3.0", "exit_direction = -1", "exit_offset = Vector3(1.2, 0.45, 0)"])
    g += node("Regenrinne3", "Kletterzonen", "climb", 44.6, 3, -0.4,
              ["height = 6.0", "exit_direction = 1", "exit_offset = Vector3(1.2, 0.45, 0)"])
    g += node("Regenrinne4", "Kletterzonen", "climb", 54.6, 7.5, -0.4,
              ["height = 3.0", "exit_direction = 1", "exit_offset = Vector3(1.2, 0.45, 0)"])
    # Kanten
    g += '\n[node name="Kanten" type="Node3D" parent="."]\n'
    for name, x, y in [("KanteBalkonA2", 22.85, 2.85), ("KanteDachB", 29.35, 5.85),
                       ("KanteDachC", 36.55, 5.85), ("KanteBalkonB2", 50.85, 5.85)]:
        g += node(name, "Kanten", "ledge", x, y, 0,
                  ["facing = -1", "size = Vector3(0.5, 0.7, 1)",
                   "exit_offset = Vector3(0.75, 0.6, 0)"])
    # Gegner
    g += '\n[node name="Gegner" type="Node3D" parent="."]\n'
    g += node("KleinerHund", "Gegner", "dog", 43.5, 0.4, 0, ["dog_size = 0", "patrol_distance = 4.0"])
    g += node("GrosserHund", "Gegner", "dog", 31, 0.6, 0, ["dog_size = 1", "patrol_distance = 3.5"])
    g += node("Revierkatze", "Gegner", "cat", 38.8, 6.3, 0, ["territory_half_width = 2.0"])
    g += node("Auto", "Gegner", "car", 30, 0, 0,
              ["drive_direction = -1", "speed = 8.5", "pause_time = 9.0"])
    # Futter
    g += '\n[node name="Futter" type="Node3D" parent="."]\n'
    for i, (x, y, kind) in enumerate([(19, 3.6, 0), (26, 3.6, 0), (31, 3.6, 0), (47, 6.6, 0)]):
        g += node("Graete%d" % (i + 1), "Futter", "food", x, y, 0, ["kind = %d" % kind])
    g += node("GanzerFisch", "Futter", "food", 40.5, 6.7, 0, ["kind = 1"])
    g += node("Futternapf", ".", "bowl", 56.5, 9, 0)
    g += tail(0, 0.4)
    open(scene_file("level_greybox.tscn"), "w").write(g)


# =============================================================================
# Level 1-10 (Meilenstein 8)
# =============================================================================

FLOOR = 3.0
# Sprungphysik der Katze (scripts/player/player.gd)
RUN_SPEED = 4.0
AIR_TIME = 3.5 / RUN_SPEED
GRAVITY = 8.0 * 1.8 / (AIR_TIME * AIR_TIME)
JUMP_VELOCITY = 4.0 * 1.8 / AIR_TIME
## Sicherheitsabschlag fuer die Pruefung: Kinder ab 5 springen nicht perfekt.
JUMP_MARGIN = 0.85

TIME_NAMES = {0: "Tag", 1: "Daemmerung", 2: "Nacht"}
LAMP_COLOR = "Color(1, 0.6, 0.28, 1)"
GOAL_COLOR = "Color(1, 0.82, 0.5, 1)"


def num(value):
    value = round(float(value), 3)
    return ("%d" % value) if value == int(value) else ("%g" % value)


def sun_transform(dx, dy, dz, height=14):
    """Transform3D-Text fuer ein Richtungslicht, das in Richtung (dx, dy, dz) scheint.
    In .tscn steht die Basis zeilenweise: basis.z = (f2, f5, f8)."""
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    z = (-dx / length, -dy / length, -dz / length)
    up = (0.0, 1.0, 0.0)
    x = (up[1] * z[2] - up[2] * z[1], up[2] * z[0] - up[0] * z[2], up[0] * z[1] - up[1] * z[0])
    xl = math.sqrt(sum(c * c for c in x))
    x = tuple(c / xl for c in x)
    y = (z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0])
    values = [x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2]]
    return "Transform3D(%s, 0, %s, 0)" % (", ".join("%.4f" % v for v in values), height)


def jump_reach(dy):
    """Horizontale Reichweite eines Sprungs aus dem Lauf auf eine um dy hoehere Flaeche."""
    disc = JUMP_VELOCITY * JUMP_VELOCITY - 2.0 * GRAVITY * dy
    if disc < 0.0:
        return -1.0
    t = (JUMP_VELOCITY + math.sqrt(disc)) / GRAVITY
    return RUN_SPEED * t * JUMP_MARGIN


class LevelBuilder:
    """Baut ein Level aus Kit-Bauteilen und prueft es auf Spielbarkeit."""

    SECTIONS = ["Welt", "Zierde", "Kletterzonen", "Kanten", "Leitungen", "Gegner", "Futter",
                "Lichter"]

    def __init__(self, number, title, time_of_day, floors, food_density,
                 view_radius=0.0, sun=(0.30, -0.78, -0.55)):
        self.number = number
        self.title = title
        self.time = time_of_day
        self.floors = floors
        self.food_density = food_density
        self.view_radius = view_radius
        self.sun = sun
        self.parts = {section: [] for section in self.SECTIONS}
        self.used_names = set()
        self.platforms = []
        self.gutters = []
        self.ledges = []
        self.dogs = []
        self.cats = []
        self.cars = []
        self.foods = []
        self.lamp_lights = 0
        ## Feste Hindernisse auf der Fahrbahn (x0, x1, Name) - Autos fahren nicht hindurch.
        self.street_obstacles = []
        self.goal = None
        self.start_x = 0.5
        self.end_x = 0.0

    # --- Hilfen ---------------------------------------------------------------

    def unique(self, base):
        name, counter = base, 2
        while name in self.used_names:
            name = "%s%d" % (base, counter)
            counter += 1
        self.used_names.add(name)
        return name

    def add_piece(self, section, base, kind, x, y, z, tiles=1, solid=True, yaw=0.0):
        self.parts[section].append(piece(self.unique(base), section, K[kind], num(x), num(y),
                                         num(z), tiles, solid, num(yaw) if yaw else 0.0))

    def add_node(self, section, base, res, x, y, z, props=()):
        name = self.unique(base)
        self.parts[section].append(node(name, section, res, num(x), num(y), num(z), props))
        return name

    def platform(self, name, x0, x1, top, kind):
        self.platforms.append({"name": name, "x0": x0, "x1": x1, "y": top, "kind": kind})

    # --- Bauteile -------------------------------------------------------------

    def street(self, x0, x1):
        tiles = int(math.ceil((x1 - x0) / 4.0))
        self.add_piece("Welt", "Strasse", "STRASSE", x0 + tiles * 2.0, 0, 0, tiles=tiles)
        self.platform("Strasse", x0, x0 + tiles * 4.0, 0.0, "strasse")

    def boundary(self, x):
        """Einfamilienhaus als Levelrand - 3 m hoch, nicht zu ueberspringen."""
        self.add_piece("Welt", "Randhaus", "HAUS", x, 0, 0)
        self.street_obstacles.append((x - 2.5, x + 2.5, "Randhaus"))

    def facade(self, x0, tiles, floors, base="Fassade"):
        for floor in range(floors):
            self.add_piece("Welt", "%s%d" % (base, floor), "GESCHOSS", x0 + tiles * 2.0,
                           floor * FLOOR, -1, tiles=tiles, solid=False)

    def roof(self, x0, x1, top, props=True):
        modules = int(round((x1 - x0) / 2.0))
        self.add_piece("Welt", "Dach", "DACH", (x0 + x1) / 2.0, top, 0, tiles=modules)
        self.platform("Dach", x0, x1, top, "dach")
        if props:
            width = x1 - x0
            self.add_piece("Zierde", "Solarkollektor", "SOLAR", x0 + width * 0.2, top, -0.7,
                           solid=False)
            self.add_piece("Zierde", "Klimageraet", "KLIMA", x0 + width * 0.55, top, -0.9,
                           solid=False)
            if width >= 12:
                self.add_piece("Zierde", "Antenne", "ANTENNE", x0 + width * 0.8, top, -0.7,
                               solid=False)
            else:
                self.add_piece("Zierde", "Satellitenschuessel", "SAT", x0 + width * 0.8, top,
                               -0.8, solid=False)

    def balcony(self, xc, floor, tiles=2, awning=False):
        top = floor * FLOOR
        self.add_piece("Welt", "Balkon", "BALKON", xc, top, 0, tiles=tiles)
        self.platform("Balkon", xc - tiles, xc + tiles, top, "balkon")
        if awning:
            self.add_piece("Zierde", "Markise", "MARKISE_ZU", xc, top + 2.2, -0.8, solid=False)

    def awning(self, xc, y):
        self.add_piece("Welt", "MarkiseOffen", "MARKISE_OFFEN", xc, y, 0)
        self.platform("Markise", xc - 1.1, xc + 1.1, y + 0.32, "markise")

    def gutter(self, x, y0, y1, direction, visual=True):
        height = y1 - y0
        if visual:
            self.add_piece("Welt", "Regenrinne", "REGENRINNE", x, y0, -0.55,
                           tiles=int(round(height / FLOOR)), solid=False)
        self.add_node("Kletterzonen", "Kletterzone", "climb", x, y0 + height / 2.0, -0.4,
                      ["height = %s" % num(height), "exit_direction = %d" % direction,
                       "exit_offset = Vector3(1.2, 0.45, 0)"])
        self.gutters.append((x, y0, y1, direction))

    def ledge(self, edge_x, top, facing):
        x = edge_x - 0.15 if facing < 0 else edge_x + 0.15
        self.add_node("Kanten", "Kante", "ledge", x, top - 0.15, 0,
                      ["facing = %d" % facing, "size = Vector3(0.5, 0.7, 1)",
                       "exit_offset = Vector3(0.75, 0.6, 0)"])
        self.ledges.append((edge_x, top, facing))

    def fence(self, x, with_gap):
        """Zaun: mit Luecke schluepft nur die Katze durch (Hunde bleiben haengen).
        Der aufgesetzte Zaun macht ihn zu hoch zum Drueberspringen."""
        self.street_obstacles.append((x - 1.0, x + 1.0, "Zaun"))
        if with_gap:
            self.add_piece("Welt", "ZaunLuecke", "ZAUN_LUECKE", x, 0, 0)
            self.add_piece("Welt", "ZaunAufsatz", "ZAUN", x, 1.3, 0)
        else:
            self.add_piece("Welt", "Zaun", "ZAUN", x, 0, 0)

    def parked_car(self, x):
        self.add_piece("Welt", "GeparktesAuto", "PARKAUTO", x, 0, 0)
        self.street_obstacles.append((x - 1.8, x + 1.8, "geparktes Auto"))
        self.platform("GeparktesAuto", x - 1.8, x + 1.8, 1.4, "auto")

    def wall(self, x):
        self.add_piece("Welt", "Mauer", "MAUER", x, 0, 0)
        self.street_obstacles.append((x - 1.0, x + 1.0, "Mauer"))
        self.platform("Mauer", x - 1.0, x + 1.0, 0.55, "mauer")

    def lamp(self, x, light=False, z=-2.2):
        self.add_piece("Zierde", "Laterne", "LATERNE", x, 0, z, solid=False)
        if light and self.time != 0:
            self.lamp_lights += 1
            self.parts["Lichter"].append(
                '[node name="%s" type="OmniLight3D" parent="Lichter"]\n%s\n'
                'light_color = %s\nlight_energy = %s\nomni_range = 7.5\n'
                % (self.unique("Laternenlicht"), xform(num(x + 0.62), 2.85, num(z + 0.9)),
                   LAMP_COLOR, "2.2" if self.time == 2 else "1.4"))

    def deco(self, kind, x, y=0.0, z=-2.5, yaw=0.0):
        self.add_piece("Zierde", kind.capitalize(), kind, x, y, z, solid=False, yaw=yaw)

    def wire(self, x0, spans, height=4.6):
        """Strommasten mit durchhaengenden Leitungen zum Balancieren (ab Level 5).
        Am ersten Mast fuehrt eine Kletterzone hinauf."""
        for i in range(spans + 1):
            self.add_piece("Zierde", "Strommast", "STROMMAST", x0 + i * 8.0, 0, 0, solid=False)
            self.street_obstacles.append((x0 + i * 8.0 - 0.2, x0 + i * 8.0 + 0.2, "Strommast"))
        for i in range(spans):
            xc = x0 + 4.0 + i * 8.0
            self.add_piece("Zierde", "Leitung", "LEITUNG", xc, height, 0, solid=False)
            self.add_node("Leitungen", "Leitung", "wire", xc, height, 0)
        self.add_node("Kletterzonen", "Mast", "climb", x0, height / 2.0, -0.4,
                      ["height = %s" % num(height), "exit_direction = 1",
                       "exit_offset = Vector3(1.2, 0.45, 0)"])
        self.gutters.append((x0, 0.0, height, 1))
        # Fuer die Pruefung: Leitung als schmale Flaeche knapp unter der Aufhaengung.
        self.platform("Leitung", x0, x0 + spans * 8.0, height - 0.25, "leitung")

    # --- Gegner, Futter, Ziel ------------------------------------------------

    def dog(self, x, big=False, patrol=3.5):
        self.add_node("Gegner", "GrosserHund" if big else "KleinerHund", "dog", x,
                      0.6 if big else 0.4, 0,
                      ["dog_size = %d" % (1 if big else 0), "patrol_distance = %s" % num(patrol)])
        self.dogs.append((x, big, patrol))

    def cat(self, x, top, half_width=2.2):
        self.add_node("Gegner", "Revierkatze", "cat", x, top + 0.3, 0,
                      ["territory_half_width = %s" % num(half_width)])
        self.cats.append((x, top, half_width))

    def car(self, x_min, x_max, direction=-1, pause=9.0):
        self.add_node("Gegner", "Auto", "car", x_min, 0, 0,
                      ["drive_direction = %d" % direction, "speed = 8.5",
                       "pause_time = %s" % num(pause),
                       "street_min_x = %s" % num(x_min), "street_max_x = %s" % num(x_max)])
        self.cars.append((x_min, x_max))

    def food(self, x, top, whole=False):
        self.add_node("Futter", "GanzerFisch" if whole else "Graete", "food", x,
                      top + (0.7 if whole else 0.6), 0, ["kind = %d" % (1 if whole else 0)])
        self.foods.append((x, top, whole))

    def goal_balcony(self, xc, top):
        """Levelziel: Futternapf auf einem beleuchteten Balkon (GDD Abschnitt 5)."""
        self.add_piece("Welt", "ZielBalkon", "BALKON", xc, top, 0, tiles=2)
        self.platform("ZielBalkon", xc - 2.0, xc + 2.0, top, "ziel")
        # Laterne am Gelaender: der Balkon leuchtet auch tagsueber sichtbar.
        self.add_piece("Zierde", "ZielLaterne", "LATERNE", xc - 1.6, top, -0.9, solid=False)
        self.goal = (xc + 0.5, top)
        self.parts["Lichter"].append(
            '[node name="Ziellicht" type="OmniLight3D" parent="Lichter"]\n%s\n'
            'light_color = %s\nlight_energy = %s\nomni_range = 5.5\n'
            % (xform(num(xc + 0.5), num(top + 1.8), 1.2), GOAL_COLOR,
               "1.0" if self.time == 0 else "2.4"))

    # --- Bausteine ------------------------------------------------------------

    def start_area(self):
        """Linker Levelrand, Gartenmauer als erste Stufe."""
        self.boundary(-4.5)
        self.deco("ZYPRESSE", -1.0, z=-2.6)
        self.deco("OLEANDER", 3.0, z=-2.3, yaw=40)
        self.wall(5.0)
        self.lamp(2.2, light=True)

    def row_block(self, x0, tiles, floors, balconies, mid_gutters=(), roof_gutter=True,
                  roof_props=True, awnings=()):
        """Haeuserzeile: Fassade, Dach, Balkone. balconies = [(Geschoss, Mitte, Module)].
        mid_gutters = [(x, y0, y1, Richtung)], jeweils neben den Balkonen."""
        x1 = x0 + tiles * 4.0
        top = floors * FLOOR
        self.facade(x0, tiles, floors)
        self.roof(x0, x1, top, props=roof_props)
        for floor, xc, modules in balconies:
            self.balcony(xc, floor, modules, awning=(floor == floors - 1 and modules == 2))
        for x, y0, y1, direction in mid_gutters:
            self.gutter(x, y0, y1, direction)
        for xc, y in awnings:
            self.awning(xc, y)
        if roof_gutter:
            self.gutter(x0 - 0.6, 0.0, top, 1)
        self.ledge(x0, top, -1)
        return x1

    def tower(self, x0, floors, food_every=2, fish_floor=None):
        """Zielhaus: Zickzack-Balkone bis unters Dach, das Ziel auf der Dachterrasse.
        Links (L) und rechts (R) versetzte Balkone, dazwischen Regenrinnen."""
        top = floors * FLOOR
        self.facade(x0, 4, floors, base="Zielhaus")
        # Dach nur ueber dem linken Teil - rechts liegt die Dachterrasse mit dem Ziel.
        self.add_piece("Welt", "ZielhausDach", "DACH", x0 + 5.0, top, 0, tiles=5)
        self.platform("ZielhausDach", x0, x0 + 10.0, top, "dach")
        self.ledge(x0, top, -1)
        left, right = x0 + 5.0, x0 + 8.5
        # Das oberste Zickzack-Geschoss muss rechts liegen (dort geht es zum Ziel).
        side = "R" if (floors - 1) % 2 == 1 else "L"
        for floor in range(1, floors):
            y0, y1 = (floor - 1) * FLOOR, floor * FLOOR
            if side == "R":
                self.balcony(right, floor)
                self.gutter(x0 + 6.0, y0, y1, 1)
            else:
                self.balcony(left, floor)
                self.gutter(x0 + 7.6, y0, y1, -1)
            if floor % food_every == 0 or floor == floors - 1:
                self.food(right if side == "R" else left, y1,
                          whole=(fish_floor == floor))
            side = "L" if side == "R" else "R"
        self.gutter(x0 + 10.4, top - FLOOR, top, 1)
        self.goal_balcony(x0 + 13.0, top)
        self.add_piece("Zierde", "Klimageraet", "KLIMA", x0 + 3.0, top, -0.9, solid=False)
        self.add_piece("Zierde", "Solarkollektor", "SOLAR", x0 + 7.0, top, -0.7, solid=False)
        return x0 + 16.0

    def end_area(self, x):
        self.boundary(x + 4.5)
        self.deco("KIEFER", x + 1.5, z=-3.0)
        self.end_x = x + 7.0

    # --- Pruefung -------------------------------------------------------------

    def _split_street(self, danger):
        """Strasse in Abschnitte zerlegen; Abschnitte in Hundenaehe markieren."""
        result = []
        for p in self.platforms:
            if p["kind"] != "strasse":
                result.append(dict(p, danger=False))
                continue
            cuts = sorted({p["x0"], p["x1"]} | {c for a, b in danger for c in (a, b)
                                                 if p["x0"] < c < p["x1"]})
            for a, b in zip(cuts, cuts[1:]):
                middle = (a + b) / 2.0
                hot = any(lo <= middle <= hi for lo, hi in danger)
                result.append(dict(p, x0=a, x1=b, danger=hot))
        return result

    def _edges(self, platforms):
        ledge_at = {(round(e, 2), round(t, 2)) for e, t, _f in self.ledges}
        edges = {i: set() for i in range(len(platforms))}
        for i, p in enumerate(platforms):
            for j, q in enumerate(platforms):
                if i == j:
                    continue
                dy = q["y"] - p["y"]
                gap = max(q["x0"] - p["x1"], p["x0"] - q["x1"], 0.0)
                if gap <= 0.0:
                    if abs(dy) < 0.1:
                        edges[i].add(j)
                    elif dy < 0.0:
                        if q["x0"] < p["x0"] - 0.5 or q["x1"] > p["x1"] + 0.5:
                            edges[i].add(j)
                    elif p["x0"] < q["x0"] - 0.5 or p["x1"] > q["x1"] + 0.5:
                        near = q["x0"] if p["x0"] < q["x0"] - 0.5 else q["x1"]
                        limit = 2.1 if (round(near, 2), round(q["y"], 2)) in ledge_at else 1.6
                        if dy <= limit:
                            edges[i].add(j)
                    continue
                near = q["x0"] if q["x0"] >= p["x1"] else q["x1"]
                has_ledge = (round(near, 2), round(q["y"], 2)) in ledge_at
                effective = dy - 0.5 if has_ledge else dy
                if dy <= 0.0 or effective <= 1.6:
                    if gap <= jump_reach(dy if dy <= 0.0 else effective):
                        edges[i].add(j)
        for x, y0, y1, direction in self.gutters:
            exit_x = x + 1.2 * direction
            for i, p in enumerate(platforms):
                if abs(p["y"] - y0) < 0.35 and p["x0"] - 0.8 <= x <= p["x1"] + 0.8:
                    for j, q in enumerate(platforms):
                        if abs(q["y"] - y1) < 0.35 and q["x0"] + 0.1 <= exit_x <= q["x1"] - 0.1:
                            edges[i].add(j)
        return edges

    def _reachable(self, platforms, edges, start):
        seen, todo = {start}, [start]
        while todo:
            current = todo.pop()
            for nxt in edges[current]:
                if nxt not in seen and not platforms[nxt].get("blocked"):
                    seen.add(nxt)
                    todo.append(nxt)
        return seen

    def validate(self):
        problems = []
        # Kletterzonen: oben muss eine Flaeche sein, unterwegs darf nichts im Weg liegen.
        for x, y0, y1, direction in self.gutters:
            exit_x = x + 1.2 * direction
            if not any(abs(p["y"] - y1) < 0.35 and p["x0"] + 0.1 <= exit_x <= p["x1"] - 0.1
                       for p in self.platforms):
                problems.append("Kletterzone x=%s: oben keine Flaeche" % num(x))
            for p in self.platforms:
                if y0 + 0.1 < p["y"] < y1 - 0.1 and p["x0"] < x + 0.3 and p["x1"] > x - 0.3 \
                        and p["kind"] != "leitung":
                    problems.append("Kletterzone x=%s: %s im Weg (y=%s)"
                                    % (num(x), p["name"], num(p["y"])))
        # Fahrende Autos: ihr Abschnitt muss frei von festen Hindernissen sein.
        for x_min, x_max in self.cars:
            for a, b, what in self.street_obstacles:
                if a < x_max + 1.6 and b > x_min - 1.6:
                    problems.append("Auto %s-%s faehrt durch %s bei x=%s"
                                    % (num(x_min), num(x_max), what, num((a + b) / 2)))
        danger = [(x - patrol - 1.5, x + patrol + 1.5) for x, _big, patrol in self.dogs]
        platforms = self._split_street(danger)
        edges = self._edges(platforms)
        start = next(i for i, p in enumerate(platforms)
                     if p["kind"] == "strasse" and p["x0"] <= self.start_x <= p["x1"])
        goal = next(i for i, p in enumerate(platforms) if p["kind"] == "ziel")
        if goal not in self._reachable(platforms, edges, start):
            problems.append("Ziel nicht erreichbar")
        # GDD 5: immer eine Route ueber die Fassadenebene - an den Hunden vorbei,
        # ohne die Strasse in ihrer Naehe zu betreten.
        safe = [dict(p, blocked=p.get("danger", False)) for p in platforms]
        if goal not in self._reachable(safe, edges, start):
            problems.append("keine Fassadenroute an den Hunden vorbei")
        safe_balconies = [p for p in self.platforms if p["kind"] == "balkon"
                          and not any(abs(p["y"] - top) < 2.2 and p["x1"] > cx - hw
                                      and p["x0"] < cx + hw for cx, top, hw in self.cats)]
        if not safe_balconies:
            problems.append("kein sicherer Balkon")
        return problems

    def estimate_seconds(self):
        """Grobe Spielzeit: Weg, Klettern und je Gegner etwas Warten."""
        distance = self.goal[0] - self.start_x
        climb = self.goal[1]
        return distance / RUN_SPEED * 1.35 + climb / 2.0 * 1.6 + \
            (len(self.dogs) + len(self.cats) + len(self.cars)) * 1.2

    # --- Ausgabe --------------------------------------------------------------

    def scene_name(self):
        return "level_%02d.tscn" % self.number

    def data_name(self):
        return "level_%02d.tres" % self.number

    def write(self):
        problems = self.validate()
        if problems:
            raise SystemExit("Level %d: %s" % (self.number, "; ".join(problems)))
        root = "Level%02d" % self.number
        exts = [("data", "Resource", "res://resources/levels/%s" % self.data_name())] + EXTS + [
            ("car", "PackedScene", "res://scenes/enemies/car.tscn"),
            ("wire", "PackedScene", "res://scenes/world/balance_wire.tscn")]
        out = header(exts) + ENV
        out += '''
[node name="%s" type="Node3D"]
script = ExtResource("level")
level_data = ExtResource("data")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_level")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = %s
light_energy = 1.0
''' % (root, sun_transform(*self.sun))
        for section in self.SECTIONS:
            out += '\n[node name="%s" type="Node3D" parent="."]\n' % section
            for entry in self.parts[section]:
                out += entry
        out += node("Futternapf", ".", "bowl", num(self.goal[0]), num(self.goal[1]), 0)
        out += tail(num(self.start_x), 0.4)
        open(scene_file(self.scene_name()), "w").write(out)
        self.write_data()
        print("%-14s %-26s %-10s Gegner %d/%d/%d  Futter %d  ~%2.0f s  Laenge %3.0f m"
              % (self.scene_name(), self.title, TIME_NAMES[self.time],
                 len(self.dogs), len(self.cats), len(self.cars), len(self.foods),
                 self.estimate_seconds(), self.goal[0]))

    def write_data(self):
        small = sum(1 for _x, big, _p in self.dogs if not big)
        big = sum(1 for _x, big, _p in self.dogs if big)
        lines = [
            '[gd_resource type="Resource" script_class="LevelData" load_steps=2 format=3]', "",
            '[ext_resource type="Script" path="res://scripts/systems/level_data.gd" id="1_data"]',
            "", "[resource]", 'script = ExtResource("1_data")',
            'scene_path = "res://scenes/levels/%s"' % self.scene_name(),
            'display_name = "%d · %s"' % (self.number, self.title),
            "time_of_day = %d" % self.time, "max_health = 3", "start_health = 3",
            "no_fail = false", "small_dogs = %d" % small, "big_dogs = %d" % big,
            "territory_cats = %d" % len(self.cats), "cars = %d" % len(self.cars),
            "food_density = %s" % num(self.food_density),
            "view_radius = %s" % num(self.view_radius),
            "view_darkness = 0.78", ""]
        open(data_file(self.data_name()), "w").write("\n".join(lines))


def scene_file(name):
    return os.path.join(ROOT, "scenes", "levels", name)


def data_file(name):
    return os.path.join(ROOT, "resources", "levels", name)


# --- Die zehn Level (GDD Abschnitt 6) -----------------------------------------

DUSK_SUN = (0.62, -0.42, -0.66)
NIGHT_SUN = (-0.35, -0.72, -0.6)


def level_01():
    """Tag, 2 Stockwerke, 1 kleiner Hund, viel Futter. Neu: Hunde."""
    lv = LevelBuilder(1, "Erste Streifzüge", 0, 2, 1.5)
    lv.street(-8, 100)
    lv.start_area()
    # Block A: sichere Balkone vor dem ersten Hund
    x = lv.row_block(9, 3, 2, [(1, 11, 2), (1, 18, 3)], mid_gutters=[(14, 0, 3, 1)])
    lv.food(11, 3)
    lv.food(18.5, 3)
    lv.food(15, 6)
    lv.deco("OLIVE", 22, z=-2.7)
    # Block B: der Hund patrouilliert unten, oben fuehrt die Balkonroute vorbei
    x = lv.row_block(23, 4, 2, [(1, 26, 3), (1, 33, 2)], mid_gutters=[(30, 0, 3, 1)])
    lv.dog(31, patrol=3.5)
    lv.food(26.5, 3)
    lv.food(29.5, 0)            # mutig: direkt vor dem Hund
    lv.food(31, 6)
    lv.lamp(37.5)
    # Garten mit Zaun und geparktem Auto als Stufe
    lv.fence(42, with_gap=False)
    lv.deco("ZYPRESSE", 44, z=-2.5)
    lv.parked_car(49)
    lv.food(49, 1.4)
    # Zweite Haelfte: Springen von Balkon zu Balkon, Futter als Belohnung
    x = lv.row_block(55, 3, 2, [(1, 57, 2), (1, 64, 3)], mid_gutters=[(60, 0, 3, 1)])
    lv.food(57, 3)
    lv.food(64.5, 3)
    lv.food(61, 6)
    lv.deco("OLIVE", 69, z=-2.7)
    # Zielhaus: Klettern mit Futter als Belohnung
    x = lv.tower(71, 2)
    lv.end_area(x)
    lv.deco("OLEANDER", 45.5, z=-2.2, yaw=120)
    return lv


def level_02():
    """Tag, 2 Stockwerke, 2 kleine Hunde, viel Futter. Neu: Zaunluecken."""
    lv = LevelBuilder(2, "Durch die Zaunlücke", 0, 2, 1.5)
    lv.street(-8, 112)
    lv.start_area()
    x = lv.row_block(9, 3, 2, [(1, 11, 2), (1, 18, 3)], mid_gutters=[(14, 0, 3, 1)])
    lv.dog(17, patrol=3.0)
    lv.fence(23, with_gap=True)   # der Hund bleibt dahinter zurueck
    lv.food(11, 3)
    lv.food(19, 3)
    lv.food(16, 0)
    lv.food(15, 6)
    x = lv.row_block(26, 4, 2, [(1, 29, 3), (1, 36, 2)], mid_gutters=[(33, 0, 3, 1)])
    lv.dog(34, patrol=3.0)
    lv.fence(43, with_gap=True)
    lv.food(29.5, 3)
    lv.food(36, 3)
    lv.food(34, 6)
    lv.lamp(39.5)
    lv.deco("OLIVE", 46, z=-2.8)
    lv.parked_car(50)
    lv.food(50, 1.4)
    x = lv.row_block(56, 3, 2, [(1, 58, 2), (1, 65, 3)], mid_gutters=[(61, 0, 3, 1)])
    lv.food(58, 3)
    lv.food(65.5, 3)
    lv.deco("OLEANDER", 70.5, z=-2.3, yaw=70)
    x = lv.tower(72, 2)
    lv.end_area(x)
    return lv


def level_03():
    """Tag, 3 Stockwerke, 1 kleiner + 1 grosser Hund, 1 Revierkatze. Neu: Revierkatzen."""
    lv = LevelBuilder(3, "Revier über der Gasse", 0, 3, 1.0)
    lv.street(-8, 120)
    lv.start_area()
    x = lv.row_block(9, 3, 2, [(1, 11, 2), (1, 18, 3)], mid_gutters=[(14, 0, 3, 1)])
    lv.dog(18, patrol=3.0)
    lv.food(11, 3)
    lv.food(17, 0)
    x = lv.row_block(23, 4, 2, [(1, 26, 3), (1, 33, 2)], mid_gutters=[(30, 0, 3, 1)])
    lv.cat(31, 6, half_width=3.0)
    lv.food(31, 6, whole=True)     # mitten im Revier: mutige Route
    lv.fence(40.5, with_gap=True)
    lv.dog(50, big=True, patrol=2.5)
    lv.food(33.5, 3)
    lv.lamp(38.5)
    # Hoehere Zeile - der grosse Hund bewacht die Strasse davor
    x = lv.row_block(43, 3, 3, [(1, 45, 2), (1, 52, 3), (2, 49, 2)],
                     mid_gutters=[(48, 0, 3, 1), (46.6, 3, 6, 1)])
    lv.food(49, 6)
    lv.food(52.5, 3)
    lv.deco("KIEFER", 56.5, z=-3.0)
    lv.parked_car(61)
    lv.food(61, 1.4)
    x = lv.row_block(66, 3, 2, [(1, 68, 2), (1, 75, 3)], mid_gutters=[(71, 0, 3, 1)])
    lv.food(75.5, 3)
    x = lv.tower(82, 3)
    lv.end_area(x)
    return lv


def level_04():
    """Daemmerung, 3 Stockwerke, 2 Hunde, 1 Katze, 1 Auto. Neu: fahrende Autos."""
    lv = LevelBuilder(4, "Scheinwerfer im Abendrot", 1, 3, 1.0, sun=DUSK_SUN)
    lv.street(-8, 124)
    lv.start_area()
    # Freie Strasse: hier faehrt das Auto - Balkone als Ausweichroute
    x = lv.row_block(9, 4, 2, [(1, 12, 3), (1, 20, 3)], mid_gutters=[(16, 0, 3, 1)])
    lv.car(8, 23.5, direction=-1, pause=7.0)
    lv.food(12, 3)
    lv.food(20, 3)
    lv.food(22, 0)
    lv.lamp(24, light=True)
    lv.fence(26.5, with_gap=True)
    x = lv.row_block(29, 3, 3, [(1, 31, 2), (1, 38, 3), (2, 35, 2)],
                     mid_gutters=[(34, 0, 3, 1), (32.6, 3, 6, 1)])
    lv.dog(35, patrol=3.0)
    lv.cat(35, 9, half_width=3.0)
    lv.food(35, 6)
    lv.food(35, 9, whole=True)
    lv.fence(43, with_gap=True)
    x = lv.row_block(45, 3, 2, [(1, 47, 2), (1, 54, 3)], mid_gutters=[(50, 0, 3, 1)])
    lv.dog(52, big=True, patrol=3.0)
    lv.food(54, 3)
    lv.lamp(58.5, light=True)
    lv.deco("ZYPRESSE", 60, z=-2.6)
    lv.parked_car(63)
    lv.food(63, 1.4)
    x = lv.row_block(68, 3, 2, [(1, 70, 2), (1, 77, 3)], mid_gutters=[(73, 0, 3, 1)])
    lv.food(70, 3)
    x = lv.tower(84, 3)
    lv.lamp(x - 2, light=True)
    lv.end_area(x)
    return lv


def level_05():
    """Daemmerung, 3 Stockwerke, 2 Hunde, 2 Katzen, 1 Auto. Neu: Balancieren."""
    lv = LevelBuilder(5, "Auf dem Drahtseil", 1, 3, 1.0, sun=DUSK_SUN)
    lv.street(-8, 128)
    lv.start_area()
    x = lv.row_block(9, 3, 2, [(1, 11, 2), (1, 18, 3)], mid_gutters=[(14, 0, 3, 1)])
    lv.cat(15, 6, half_width=2.5)
    lv.food(11, 3)
    lv.food(18, 3)
    # Leitungen ueber der Hundestrasse - oben balancieren, unten bellen die Hunde
    lv.wire(22, 2)
    lv.dog(27, patrol=3.0)
    lv.dog(33, big=True, patrol=2.5)
    lv.food(26, 4.35)
    lv.food(34, 4.35)
    lv.food(30, 0)
    lv.lamp(29, light=True)
    x = lv.row_block(39, 3, 3, [(1, 41, 2), (1, 48, 3), (2, 45, 2)],
                     mid_gutters=[(44, 0, 3, 1), (42.6, 3, 6, 1)])
    lv.ledge(39, 3, -1)
    lv.cat(45, 9, half_width=2.8)
    lv.car(63.5, 80, direction=-1, pause=8.0)
    lv.food(45, 6, whole=True)
    lv.food(48.5, 3)
    lv.lamp(55, light=True)
    lv.deco("OLIVE", 57, z=-2.7)
    lv.parked_car(60)
    x = lv.row_block(66, 3, 2, [(1, 68, 2), (1, 75, 3)], mid_gutters=[(71, 0, 3, 1)])
    lv.food(68, 3)
    lv.food(75.5, 3)
    x = lv.tower(82, 3)
    lv.lamp(x - 2, light=True)
    lv.end_area(x)
    return lv


def level_06():
    """Daemmerung, 4 Stockwerke, 2 Hunde, 2 Katzen, 2 Autos. Neu: breitere Dachluecken."""
    lv = LevelBuilder(6, "Weite Sprünge", 1, 4, 1.0, sun=DUSK_SUN)
    lv.street(-8, 124)
    lv.start_area()
    x = lv.row_block(9, 3, 3, [(1, 11, 2), (1, 18, 3), (2, 15, 2)],
                     mid_gutters=[(14, 0, 3, 1), (12.6, 3, 6, 1)])
    lv.dog(16, patrol=3.0)
    lv.car(8, 22, direction=1, pause=9.0)
    lv.food(15, 6)
    lv.food(18, 3)
    # Dachluecke 2,6 m
    x = lv.row_block(23.6, 3, 3, [(1, 25.6, 2), (1, 32.6, 3), (2, 29.6, 2)],
                     mid_gutters=[(28.6, 0, 3, 1), (27.2, 3, 6, 1)])
    lv.cat(30, 9, half_width=3.0)
    lv.food(30, 9, whole=True)
    lv.food(29.6, 6)
    lv.lamp(37, light=True)
    # Dachluecke 3 m
    x = lv.row_block(38.6, 3, 3, [(1, 40.6, 2), (1, 47.6, 3), (2, 44.6, 2)],
                     mid_gutters=[(43.6, 0, 3, 1), (42.2, 3, 6, 1)])
    lv.cat(45, 9, half_width=3.0)
    lv.dog(45, big=True, patrol=3.0)
    lv.fence(52, with_gap=True)
    lv.food(47.6, 3)
    lv.food(44.6, 6)
    lv.parked_car(49.5)
    lv.food(49.5, 1.4)
    lv.car(55, 72, direction=-1, pause=7.5)
    lv.lamp(58, light=True)
    lv.deco("KIEFER", 60, z=-3.0)
    x = lv.tower(72, 4)
    lv.end_area(x)
    return lv


def level_07():
    """Nacht, 4 Stockwerke, 2 Hunde, 2 Katzen, 2 Autos. Neu: eingeschraenkte Sicht."""
    lv = LevelBuilder(7, "Laternen in der Nacht", 2, 4, 0.6, view_radius=0.36, sun=NIGHT_SUN)
    lv.street(-8, 124)
    lv.start_area()
    x = lv.row_block(9, 4, 3, [(1, 12, 3), (1, 20, 3), (2, 16, 2)],
                     mid_gutters=[(16, 0, 3, 1), (13.6, 3, 6, 1)])
    lv.dog(19, patrol=3.0)
    lv.car(8, 24.5, direction=-1, pause=8.0)
    lv.food(16, 6)
    lv.lamp(18, light=True)
    lv.lamp(26.5, light=True)
    x = lv.row_block(27.5, 3, 3, [(1, 29.5, 2), (1, 36.5, 3), (2, 33.5, 2)],
                     mid_gutters=[(32.5, 0, 3, 1), (31.1, 3, 6, 1)])
    lv.cat(33.5, 9, half_width=3.0)
    lv.dog(37, big=True, patrol=2.5)
    lv.food(36.5, 3)
    lv.wire(42, 1)
    lv.food(46, 4.35)
    x = lv.row_block(51.5, 3, 3, [(1, 53.5, 2), (1, 60.5, 3), (2, 57.5, 2)],
                     mid_gutters=[(56.5, 0, 3, 1), (55.1, 3, 6, 1)])
    lv.ledge(51.5, 3, -1)
    lv.cat(57.5, 9, half_width=2.8)
    lv.car(64, 80, direction=1, pause=8.0)
    lv.food(57.5, 6, whole=True)
    lv.lamp(70, light=True)
    lv.deco("ZYPRESSE", 72, z=-2.6)
    x = lv.tower(76, 4)
    lv.end_area(x)
    lv.deco("TANKSTELLE", 30, z=-10)
    return lv


def level_08():
    """Nacht, 4 Stockwerke, 3 Hunde, 2 Katzen, 2 Autos. Neu: kombinierte Gefahren."""
    lv = LevelBuilder(8, "Alles auf einmal", 2, 4, 0.6, view_radius=0.38, sun=NIGHT_SUN)
    lv.street(-8, 132)
    lv.start_area()
    # Hund und Auto auf demselben Strassenstueck
    x = lv.row_block(9, 4, 3, [(1, 12, 3), (1, 20, 3), (2, 16, 2)],
                     mid_gutters=[(16, 0, 3, 1), (13.6, 3, 6, 1)])
    lv.dog(19, patrol=3.0)
    lv.car(8, 24.5, direction=-1, pause=7.0)
    lv.cat(17, 9, half_width=3.5)
    lv.food(16, 6)
    lv.lamp(24, light=True)
    # Leitung ueber zwei Hunden
    lv.wire(26.5, 2)
    lv.dog(31, patrol=2.5)
    lv.dog(38, big=True, patrol=2.5)
    lv.food(34.5, 4.35)
    lv.lamp(35, light=True)
    x = lv.row_block(44, 3, 3, [(1, 46, 2), (1, 53, 3), (2, 50, 2)],
                     mid_gutters=[(49, 0, 3, 1), (47.6, 3, 6, 1)])
    lv.ledge(44, 3, -1)
    lv.cat(50, 9, half_width=3.0)
    lv.food(50, 9, whole=True)
    lv.food(53, 3)
    lv.parked_car(55)
    lv.food(55, 1.4)
    lv.car(58.5, 76, direction=1, pause=8.0)
    lv.lamp(66, light=True)
    lv.deco("OLIVE", 68, z=-2.8)
    x = lv.tower(78, 4)
    lv.end_area(x)
    lv.deco("TANKSTELLE", 58, z=-10)
    return lv


def level_09():
    """Nacht, 5 Stockwerke, 3 Hunde, 3 Katzen, 3 Autos. Neu: hohe Fassaden."""
    lv = LevelBuilder(9, "Hohe Fassaden", 2, 5, 0.6, view_radius=0.4, sun=NIGHT_SUN)
    lv.street(-8, 140)
    lv.start_area()
    x = lv.row_block(9, 4, 4, [(1, 12, 3), (1, 20, 3), (2, 16, 2), (3, 12, 3)],
                     mid_gutters=[(16, 0, 3, 1), (13.6, 3, 6, 1), (15.6, 6, 9, -1)])
    lv.dog(19, patrol=3.0)
    lv.car(8, 24.5, direction=-1, pause=8.0)
    lv.cat(17, 12, half_width=3.5)
    lv.food(16, 6)
    lv.food(12, 9)
    lv.lamp(24, light=True)
    x = lv.row_block(27.5, 3, 4, [(1, 29.5, 2), (1, 36.5, 3), (2, 33.5, 2)],
                     mid_gutters=[(32.5, 0, 3, 1), (31.1, 3, 6, 1)])
    lv.cat(33.5, 12, half_width=3.0)
    lv.dog(34, big=True, patrol=2.5)
    lv.food(33.5, 12, whole=True)
    lv.wire(42, 1)
    lv.dog(46, patrol=2.0)
    lv.car(52, 64, direction=1, pause=9.0)
    lv.food(46, 4.35)
    lv.lamp(47, light=True)
    x = lv.row_block(51.5, 3, 4, [(1, 53.5, 2), (1, 60.5, 3), (2, 57.5, 2)],
                     mid_gutters=[(56.5, 0, 3, 1), (55.1, 3, 6, 1)])
    lv.ledge(51.5, 3, -1)
    lv.cat(57.5, 12, half_width=2.8)
    lv.food(60.5, 3)
    lv.car(66, 90, direction=-1, pause=8.0)
    lv.lamp(72, light=True)
    lv.deco("KIEFER", 74, z=-3.0)
    x = lv.tower(80, 5, food_every=2)
    lv.end_area(x)
    lv.deco("TANKSTELLE", 40, z=-10)
    return lv


def level_10():
    """Nacht, 5 Stockwerke, 3 Hunde, 3 Katzen, 3 Autos. Finale: laengste Kletterpassage,
    Ziel mit Blick auf den Kirchturm."""
    lv = LevelBuilder(10, "Blick auf den Kirchturm", 2, 5, 0.6, view_radius=0.42,
                      sun=NIGHT_SUN)
    lv.street(-8, 148)
    lv.start_area()
    x = lv.row_block(9, 4, 3, [(1, 12, 3), (1, 20, 3), (2, 16, 2)],
                     mid_gutters=[(16, 0, 3, 1), (13.6, 3, 6, 1)])
    lv.dog(19, patrol=3.0)
    lv.car(8, 24.5, direction=-1, pause=7.5)
    lv.cat(17, 9, half_width=3.5)
    lv.food(16, 6)
    lv.lamp(24, light=True)
    lv.wire(26.5, 2)
    lv.dog(31, big=True, patrol=2.5)
    lv.dog(38, patrol=2.5)
    lv.food(30.5, 4.35)
    x = lv.row_block(44, 3, 4, [(1, 46, 2), (1, 53, 3), (2, 50, 2), (3, 46, 2)],
                     mid_gutters=[(49, 0, 3, 1), (47.6, 3, 6, 1), (48.6, 6, 9, -1)])
    lv.ledge(44, 3, -1)
    lv.cat(50, 12, half_width=3.0)
    lv.food(50, 12, whole=True)
    lv.food(46, 9)
    lv.car(57, 70, direction=1, pause=8.5)
    lv.lamp(62, light=True)
    # Zweite Haelfte: lange Kletterpassage ueber zwei Haeuser zum Ziel
    x = lv.row_block(60, 3, 4, [(1, 62, 2), (1, 69, 3), (2, 66, 2), (3, 62, 2)],
                     mid_gutters=[(65, 0, 3, 1), (63.6, 3, 6, 1), (64.6, 6, 9, -1)],
                     roof_gutter=False)
    lv.cat(66, 12, half_width=2.5)
    lv.food(66, 6)
    lv.food(62, 9)
    lv.car(74, 92, direction=-1, pause=9.0)
    x = lv.tower(76, 5)
    lv.end_area(x)
    # Blick auf den angestrahlten Kirchturm - rechts neben dem Zielhaus und
    # etwas hoeher am Hang, damit ihn nichts verdeckt.
    lv.add_piece("Zierde", "Kirchturm", "KIRCHTURM", 98.5, 3.5, -14, solid=False)
    lv.parts["Lichter"].append(
        '[node name="Turmlicht" type="OmniLight3D" parent="Lichter"]\n%s\n'
        'light_color = Color(1, 0.8, 0.52, 1)\nlight_energy = 4.0\nomni_range = 10.0\n'
        % xform(98.5, 12, -10))
    lv.deco("TANKSTELLE", 36, z=-10)
    return lv


LEVELS = [level_01, level_02, level_03, level_04, level_05, level_06, level_07, level_08,
          level_09, level_10]


def write_catalog(count):
    lines = ['[gd_resource type="Resource" script_class="LevelCatalog" load_steps=%d format=3]'
             % (count + 3), "",
             '[ext_resource type="Script" path="res://scripts/systems/level_catalog.gd" '
             'id="1_catalog"]',
             '[ext_resource type="Resource" path="res://resources/levels/level_00.tres" '
             'id="2_level00"]']
    ids = ['ExtResource("2_level00")']
    for number in range(1, count + 1):
        lines.append('[ext_resource type="Resource" path="res://resources/levels/level_%02d.tres"'
                     ' id="%d_level%02d"]' % (number, number + 2, number))
        ids.append('ExtResource("%d_level%02d")' % (number + 2, number))
    lines += ["", "[resource]", 'script = ExtResource("1_catalog")',
              "levels = Array[Resource]([%s])" % ", ".join(ids), ""]
    open(data_file("level_catalog.tres"), "w").write("\n".join(lines))


def main():
    build_tutorial()
    build_greybox()
    failed = []
    for make in LEVELS:
        try:
            make().write()
        except SystemExit as error:
            failed.append(str(error))
    for message in failed:
        print("FEHLER", message)
    if failed:
        sys.exit(1)
    write_catalog(len(LEVELS))
    print("Katalog: Tutorial + %d Level" % len(LEVELS))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Baut die ASCII-Karte des Levels und prueft die Erreichbarkeit.

Schreibt scripts/level1_data.gd und scripts/level2_data.gd
Legende:
  #  Wand            .  Boden          C  rissige Wand (Feuerschwert)
  ~  Wasser          F  Feuerduese     a/b/c  Eingangstor Boss 1/2/3
  A/B/G  Ausgangstor Boss 1/2/3        E  Portal (Ausgang)
  S  Start           f  Feuerschwert   i  Eisschwert   h  Herz-Kristall
  p  Heiltrank       v  Fledermaus     s  Schleim
  K  Schattenritter  O  Krake          M  Golem        D  Drache (Schleifen-Mitte)
  P  Saeule (Deko-Wand)  t  Fackel (Deko-Wand)
  I  Rutscheis       k  Schluessel     L  verschlossene Tuer
  W  Riesenspinne    Y  Eisgolem
"""
import sys
from collections import deque

import os

W = H = 0
g = []


def new_map(w, h):
    global W, H, g
    W, H = w, h
    g = [['#'] * W for _ in range(H)]


def rect(x0, y0, x1, y1, ch='.'):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = ch


def put(x, y, ch):
    g[y][x] = ch


def level1():
    new_map(64, 44)
    # --- 9: Startzone mit drehenden Scheiben ---------------------------------
    rect(8, 2, 21, 14)
    put(15, 8, 'S')
    rect(14, 15, 15, 15)            # Ausgang nach unten
    # Hauptgang
    rect(3, 16, 25, 17)
    # --- 3: Feuerschwert-Raum (links) ---------------------------------------
    rect(2, 18, 7, 24)
    put(4, 21, 'f')
    put(6, 23, 's')
    # Sackgasse rechts mit Trank
    rect(24, 18, 25, 25)
    rect(21, 24, 25, 25)
    put(21, 24, 'p')
    put(24, 21, 's')
    put(19, 16, 'v')
    # --- 4: Schattenritter-Arena --------------------------------------------
    rect(14, 18, 15, 18)
    put(14, 19, 'C'); put(15, 19, 'C')
    put(14, 20, 'a'); put(15, 20, 'a')
    rect(9, 21, 19, 29)
    put(15, 25, 'K')
    put(10, 30, 'A'); put(11, 30, 'A')
    # Gang zum Feuerfeld
    rect(3, 31, 11, 32)
    rect(3, 33, 4, 33)
    # geheimer Raum hinter rissiger Wand (vom Feuerschwert-Raum aus)
    put(4, 25, 'C'); put(5, 25, 'C')
    rect(3, 26, 6, 28)
    put(4, 27, 'p')
    # --- 6: Feuerfeld --------------------------------------------------------
    rect(3, 34, 5, 39)              # sicherer Absatz links
    rect(6, 34, 17, 39, 'F')
    rect(18, 34, 20, 39)            # sicherer Absatz rechts
    # --- 5: Krake ------------------------------------------------------------
    put(21, 36, 'b'); put(21, 37, 'b')
    rect(22, 31, 36, 42)
    rect(26, 34, 32, 39, '~')
    put(29, 36, 'O')
    put(37, 36, 'B'); put(37, 37, 'B')
    # --- 8: Herz-Kristall-Raum ----------------------------------------------
    rect(38, 36, 38, 37)
    rect(39, 34, 44, 40)
    put(42, 37, 'h')
    put(39, 33, 't'); put(44, 33, 't')
    # Gang nach oben (Zickzack) zum Eisschwert
    rect(41, 27, 42, 33)
    rect(36, 28, 40, 29)            # Sackgasse
    put(36, 28, 'v')
    rect(41, 26, 47, 27)
    rect(46, 19, 47, 25)
    put(43, 26, 'v')
    # --- 2: Eisschwert-Raum --------------------------------------------------
    rect(46, 18, 55, 24)
    put(51, 21, 'i')
    put(54, 19, 's')
    # Sackgasse vom Eisraum nach links oben
    rect(38, 18, 45, 19)
    rect(38, 14, 39, 17)
    put(38, 14, 'p')
    # --- 7: Golem ------------------------------------------------------------
    rect(53, 25, 54, 30)
    put(53, 31, 'c'); put(54, 31, 'c')
    rect(47, 32, 59, 42)
    put(53, 37, 'M')
    put(60, 32, 'G'); put(60, 33, 'G')   # Ausgangstor Golem
    # Gang rechts hoch zur Drachenhalle
    rect(61, 13, 62, 33)
    put(61, 28, 'v'); put(62, 20, 'v'); put(61, 16, 's')
    # --- 1: Drachenhalle -----------------------------------------------------
    rect(29, 2, 62, 11)
    rect(61, 12, 62, 12)
    put(30, 6, 'E')
    put(46, 6, 'D')
    for (px, py) in [(36, 4), (36, 9), (52, 4), (52, 9), (44, 2), (48, 11)]:
        put(px, py, 'P')
    return [''.join(r) for r in g]


def level2():
    """Die Eishoehle: Rutscheis, Schluessel und Tueren, Spinne und Eisgolem."""
    new_map(56, 40)
    # Startraum
    rect(2, 2, 9, 8)
    put(5, 5, 'S')
    put(8, 7, 'p')
    rect(10, 4, 17, 5)
    # Eishalle mit Saeulen - hinten liegt der erste Schluessel
    rect(18, 2, 33, 12, 'I')
    for (px, py) in [(21, 4), (24, 8), (27, 3), (29, 9), (22, 11), (31, 5), (26, 6), (30, 12)]:
        put(px, py, 'P')
    rect(31, 10, 33, 12)
    put(32, 11, 'k')
    put(25, 11, 'v')
    # Tuer + Spinnen-Arena
    put(34, 6, 'L'); put(34, 7, 'L')
    put(35, 6, 'a'); put(35, 7, 'a')
    rect(36, 2, 52, 12)
    put(44, 7, 'W')
    put(44, 13, 'A'); put(45, 13, 'A')
    rect(44, 14, 45, 18)
    # Labyrinth-Ring in der Mitte
    rect(26, 19, 54, 20)
    rect(26, 21, 27, 26)
    rect(53, 21, 54, 26)
    rect(26, 25, 54, 26)
    rect(34, 25, 46, 26, 'I')
    rect(36, 21, 37, 22)             # Sackgasse von oben
    rect(39, 22, 41, 23)             # Nische mit Herz
    put(40, 21, '.'); put(40, 22, 'h')
    rect(48, 27, 49, 31)             # Sackgasse mit Schluessel 2
    put(48, 31, 'k')
    put(49, 29, 's')
    put(31, 19, 'v'); put(50, 25, 'v'); put(53, 22, 's'); put(42, 26, 's')
    # geheimer Raum hinter rissiger Wand
    put(22, 20, 'C'); put(22, 19, '#')
    rect(23, 20, 25, 20)
    rect(18, 19, 21, 22)
    put(19, 21, 'p')
    # Weg nach unten zum Eisgolem
    rect(26, 27, 27, 32)
    rect(22, 31, 25, 32)
    put(21, 31, 'L'); put(21, 32, 'L')
    put(20, 31, 'b'); put(20, 32, 'b')
    rect(4, 28, 19, 38)
    put(11, 33, 'Y')
    for (px, py) in [(6, 30), (17, 30), (6, 36), (17, 36)]:
        put(px, py, 'P')
    put(8, 27, 'B'); put(9, 27, 'B')
    # Portalraum
    rect(4, 19, 14, 26)
    put(9, 21, 'E')
    put(5, 18, 't'); put(13, 18, 't')
    return [''.join(r) for r in g]


# --------------------------------------------------------------- Pruefung
def find(rows, ch):
    return [(x, y) for y in range(len(rows)) for x in range(len(rows[0])) if rows[y][x] == ch]


def reach(rows, start, passable):
    h, w = len(rows), len(rows[0])
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and rows[ny][nx] in passable:
                seen.add((nx, ny)); q.append((nx, ny))
    return seen


ok = True


def check(name, cond):
    global ok
    print(('OK   ' if cond else 'FAIL ') + name, file=sys.stderr)
    ok &= cond


BASE = set('.SfihpvsKOMDEIkWY') | {'a', 'b', 'c'}


def check_level1(rows):
    start = find(rows, 'S')[0]
    def r(*extra):
        return reach(rows, start, BASE | set(''.join(extra)))
    r0 = r()
    check('L1 Feuerschwert erreichbar', find(rows, 'f')[0] in r0)
    check('L1 Ritter ohne Feuer NICHT erreichbar', find(rows, 'K')[0] not in r0)
    check('L1 Ritter mit Feuer erreichbar', find(rows, 'K')[0] in r('C'))
    check('L1 Feuerfeld vor Ritter-Sieg gesperrt', (23, 36) not in r('C', 'F'))
    check('L1 Krake ohne Feuerfeld NICHT erreichbar', (23, 36) not in r('C', 'A'))
    r3 = r('C', 'A', 'F')
    check('L1 Krake erreichbar', (23, 36) in r3)
    check('L1 Herz vor Krake-Sieg gesperrt', find(rows, 'h')[0] not in r3)
    r4 = r('C', 'A', 'F', 'B')
    for ch in 'hiM':
        check('L1 ' + ch + ' erreichbar', find(rows, ch)[0] in r4)
    check('L1 Portal vor Golem-Sieg gesperrt', find(rows, 'E')[0] not in r4)
    check('L1 Portal erreichbar', find(rows, 'E')[0] in r('C', 'A', 'F', 'B', 'G'))


def check_level2(rows):
    start = find(rows, 'S')[0]
    def r(*extra):
        return reach(rows, start, BASE | set(''.join(extra)))
    k1, k2 = find(rows, 'k')
    r0 = r()
    check('L2 Schluessel 1 erreichbar', k1 in r0)
    check('L2 Spinne ohne Tuer NICHT erreichbar', find(rows, 'W')[0] not in r0)
    check('L2 Schluessel 2 vor Spinnen-Sieg gesperrt', k2 not in r('L', 'C'))
    # Tueren: L passierbar (Schluessel 1 benutzt), Spinne besiegt -> A
    r1 = r('L', 'A')
    check('L2 Spinne erreichbar', find(rows, 'W')[0] in r('L'))
    check('L2 Schluessel 2 erreichbar', k2 in r1)
    check('L2 Herz erreichbar', find(rows, 'h')[0] in r1)
    check('L2 Golem erreichbar', find(rows, 'Y')[0] in r1)
    check('L2 Portal vor Golem-Sieg gesperrt', find(rows, 'E')[0] not in r1)
    check('L2 Portal erreichbar', find(rows, 'E')[0] in r('L', 'A', 'B'))
    check('L2 Geheimraum nur mit Feuer', (19, 21) not in r1 and (19, 21) in r('L', 'A', 'C'))
    check('L2 genau 2 Tueren-Paare', len(find(rows, 'L')) == 4)


def write(path, rows, level):
    with open(path, 'w') as f:
        f.write('# Automatisch erzeugt von tools/build_map.py - Legende siehe dort.\n')
        f.write('extends RefCounted\n\n')
        f.write('const MAP := [\n')
        for row in rows:
            f.write('\t"%s",\n' % row)
        f.write(']\n')


if __name__ == '__main__':
    here = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'scripts')
    l1 = level1()
    check_level1(l1)
    l2 = level2()
    check_level2(l2)
    write(os.path.join(here, 'level1_data.gd'), l1, 1)
    write(os.path.join(here, 'level2_data.gd'), l2, 2)
    print('\n'.join(l2), file=sys.stderr)
    sys.exit(0 if ok else 1)

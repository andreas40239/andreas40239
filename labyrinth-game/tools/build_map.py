#!/usr/bin/env python3
"""Baut die ASCII-Karte des Levels und prueft die Erreichbarkeit.

Ausgabe: GDScript-Konstante fuer scripts/level_data.gd
Legende:
  #  Wand            .  Boden          C  rissige Wand (Feuerschwert)
  ~  Wasser          F  Feuerduese     a/b/c  Eingangstor Boss 1/2/3
  A/B/G  Ausgangstor Boss 1/2/3        E  Portal (Ausgang)
  S  Start           f  Feuerschwert   i  Eisschwert   h  Herz-Kristall
  p  Heiltrank       v  Fledermaus     s  Schleim
  K  Schattenritter  O  Krake          M  Golem        D  Drache (Schleifen-Mitte)
  P  Saeule (Deko-Wand)  t  Fackel (Deko-Wand)
"""
import sys
from collections import deque

W, H = 64, 44
g = [['#'] * W for _ in range(H)]


def rect(x0, y0, x1, y1, ch='.'):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = ch


def put(x, y, ch):
    g[y][x] = ch


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


rows = [''.join(r) for r in g]

# --------------------------------------------------------------- Pruefung
def find(ch):
    return [(x, y) for y in range(H) for x in range(W) if rows[y][x] == ch]


def reach(start, flags):
    passable = set('.SfihpvsKOMDEt') - {'t'}
    if 'fire' in flags: passable |= {'C'}
    passable |= {'a', 'b', 'c'}
    if 'k' in flags: passable |= {'A'}
    if 'o' in flags: passable |= {'B'}
    if 'g' in flags: passable |= {'G'}
    if 'firefield' in flags: passable |= {'F'}
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in seen and rows[ny][nx] in passable:
                seen.add((nx, ny)); q.append((nx, ny))
    return seen

start = find('S')[0]
ok = True
def check(name, cond):
    global ok
    print(('OK   ' if cond else 'FAIL ') + name, file=sys.stderr)
    ok &= cond

r0 = reach(start, set())
check('Feuerschwert erreichbar', find('f')[0] in r0)
check('Ritter ohne Feuer NICHT erreichbar', find('K')[0] not in r0)
r1 = reach(start, {'fire'})
check('Ritter mit Feuer erreichbar', find('K')[0] in r1)
check('Feuerfeld vor Ritter-Sieg gesperrt', (23, 36) not in reach(start, {'fire', 'firefield'}))
r2 = reach(start, {'fire', 'k'})
check('Krake ohne Feuerfeld NICHT erreichbar', (23, 36) not in r2)
r3 = reach(start, {'fire', 'k', 'firefield'})
check('Krake erreichbar', (23, 36) in r3)
check('Herz vor Krake-Sieg gesperrt', find('h')[0] not in r3)
r4 = reach(start, {'fire', 'k', 'firefield', 'o'})
for ch in 'hiM':
    check(ch + ' erreichbar', find(ch)[0] in r4)
check('Portal vor Golem-Sieg gesperrt', find('E')[0] not in r4)
r5 = reach(start, {'fire', 'k', 'firefield', 'o', 'g'})
check('Portal erreichbar', find('E')[0] in r5)

print('const MAP := [')
for r in rows:
    print('\t"%s",' % r)
print(']')
sys.exit(0 if ok else 1)

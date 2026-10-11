# Drachen-Labyrinth

Zwei Level, gebaut nach der Kinderzeichnung, als Godot-4.3-Projekt für Android (arm64).

## Startbildschirm
Titel mit kreisendem Drachen und eigener Titelmusik, zwei Levelkarten zum Antippen (mit Stern, wenn geschafft)
und ein Knopf für Ton an/aus. Im Spiel führt das Haus-Symbol oben rechts (zweimal tippen) zurück ins Menü.
Der Fortschritt wird auf dem Gerät gespeichert.

## Steuerung
* **Linke Bildschirmhälfte:** Finger ziehen = laufen (schwebender Joystick)
* **Rechte Bildschirmhälfte / roter Knopf:** der eine Aktionsknopf = Schwert schwingen
* Am PC: WASD/Pfeiltasten + Leertaste

## Level 1: Das Drachen-Labyrinth
| Nr. | Ort | Was passiert |
|-----|-----|--------------|
| 9 | Startzone | Du stehst in der Mitte von vier drehenden Labyrinth-Scheiben. Warte, bis die Lücken passen. |
| 3 | Feuerschwert | Links unten neben dem Gang. Zerschlägt rissige Wände (auch einen geheimen Raum mit Trank). |
| 4 | Zwischenboss Schattenritter | Stürmt auf dich zu. Läuft er gegen eine Wand, ist er betäubt und nimmt doppelten Schaden. |
| 6 | Feuer aus dem Boden | Alle Flammen gehen gemeinsam an (1 s) und aus (4 s), vorher flackern sie als Warnung. Wer beim Erlöschen losläuft, kommt heil hinüber. Eine Flamme kostet nur ein Herz, man muss nicht von vorn anfangen. |
| 5 | Zwischenboss Riesenkrake | Taucht am Beckenrand auf und spuckt Tinte. Nur aufgetaucht verwundbar. |
| 8 | Power-up Herz-Kristall | +2 maximale Herzen, alle Herzen aufgefüllt. |
| 2 | Eisschwert | Friert Gegner ein und behält die Feuerkraft. |
| 7 | Zwischenboss Steingolem | Nur mit Eis verwundbar. Sein Stampfen schleudert Felsen in alle Richtungen. |
| 1 | Endlos-Drache | Kreist ewig in einer liegenden Acht durch die Halle und spuckt Feuer. Ein Eisschwert-Treffer friert ihn kurz ein. Dahinter liegt das Portal, das alle drei Boss-Kristalle braucht. |

## Level 2: Die Eishöhle
Du startest mit dem Feuerschwert.
1. **Eishalle:** Auf dem Rutscheis schlitterst du weiter, wenn du loslässt. Um die Säulen herum liegt hinten der erste Schlüssel.
2. **Verschlossene Tür:** Läufst du mit einem Schlüssel dagegen, geht sie auf.
3. **Zwischenboss Riesenspinne:** Sie spinnt klebrige Netze, die nur bremsen und keinen Schaden machen, und ruft kleine Spinnen.
4. **Labyrinth-Ring:** Fledermäuse, Schleime, ein Herz-Kristall in einer Nische, ein Geheimraum hinter einer rissigen Wand
   und in einer Sackgasse der zweite Schlüssel.
5. **Zwischenboss Eisgolem:** Nur mit Feuer verwundbar. Er stampft Eisbrocken in alle Richtungen.
6. **Portal:** Es öffnet sich mit den zwei Kristallen der Bosse.

## Musik und Sounds
Alles in `audio/` wurde prozedural mit `tools/gen_audio.py` (numpy + ffmpeg) erzeugt:
* `music_dungeon.ogg`: düstere Dungeon-Musik in d-Moll, 72 BPM, mit Glocken, Herzschlag-Trommel und Wassertropfen
* `music_boss.ogg`: treibende Bosskampf-Musik in e-Moll, 150 BPM
* `music_victory.ogg`: Siegesfanfare
* `music_title.ogg`: Abenteuer-Thema für den Startbildschirm
* Waffengeräusche: `swing`, `swing_fire`, `swing_ice`, `hit`, `clank`, `wall_break`
* Monstergeräusche: `bat`, `slime`, `knight`, `octopus`, `ink`, `golem`, `slam`, `dragon`, `fire`, `monster_die`
* Level 2: `spider`, `web`, `key`
* Sonstiges: `pickup`, `powerup`, `crystal`, `hurt`, `death`, `gate`, `freeze`, `boss_defeat`, `denied`

Neu erzeugen: `python3 tools/gen_audio.py`

## Bauen
**Automatisch:** Der GitHub-Workflow `.github/workflows/labyrinth-android.yml` baut bei jedem Push eine signierte Debug-APK
(arm64-v8a) und lädt sie als Artefakt `drachen-labyrinth-apk` hoch.

**Von Hand:**
1. Godot 4.3 öffnen und dieses Verzeichnis als Projekt importieren.
2. *Editor → Export-Vorlagen verwalten* → Vorlagen für 4.3 installieren.
3. *Editoreinstellungen → Export → Android*: Android-SDK-Pfad und Debug-Keystore setzen.
4. *Projekt → Exportieren → Android* (nur `arm64-v8a` ist aktiv) → APK exportieren.

## Für Entwickler
* `tools/build_map.py` erzeugt `scripts/level1_data.gd` und `scripts/level2_data.gd` (ASCII-Karten) und prüft, dass jeder
  Abschnitt nur in der richtigen Reihenfolge erreichbar ist: `python3 tools/build_map.py`
* `scripts/levels.gd` beschreibt pro Level Bosse, Rätsel, Farben und Hinweise. Ein neues Level = neue Karte + neuer Eintrag.
* `tools/autotest.gd` spielt beide Level automatisch durch, inklusive eines Bots für die Scheiben und Prüfungen,
  dass das Feuerfeld kinderleicht ist: `godot --headless --script res://tools/autotest.gd`
* `tools/screenshots.gd` erstellt Screenshots aller Abschnitte.
* Grafik: alles wird per Code gezeichnet (`_draw`), es gibt keine Bilddateien.

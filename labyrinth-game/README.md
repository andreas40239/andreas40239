# Drachen-Labyrinth

Ein Level, gebaut nach der Kinderzeichnung, als Godot-4.3-Projekt für Android (arm64).

## Steuerung
* **Linke Bildschirmhälfte:** Finger ziehen = laufen (schwebender Joystick)
* **Rechte Bildschirmhälfte / roter Knopf:** der eine Aktionsknopf = Schwert schwingen
* Am PC: WASD/Pfeiltasten + Leertaste

## Der Weg durch das Level
| Nr. | Ort | Was passiert |
|-----|-----|--------------|
| 9 | Startzone | Du stehst in der Mitte von vier drehenden Labyrinth-Scheiben. Warte, bis die Lücken passen. |
| 3 | Feuerschwert | Links unten neben dem Gang. Zerschlägt rissige Wände (auch einen geheimen Raum mit Trank). |
| 4 | Zwischenboss Schattenritter | Stürmt auf dich zu. Läuft er gegen eine Wand, ist er betäubt und nimmt doppelten Schaden. |
| 6 | Feuer aus dem Boden | Die Düsen zünden in einem wandernden Rhythmus. Folge den Flammen, wenn sie erlöschen. |
| 5 | Zwischenboss Riesenkrake | Taucht am Beckenrand auf und spuckt Tinte. Nur aufgetaucht verwundbar. |
| 8 | Power-up Herz-Kristall | +2 maximale Herzen, alle Herzen aufgefüllt. |
| 2 | Eisschwert | Friert Gegner ein und behält die Feuerkraft. |
| 7 | Zwischenboss Steingolem | Nur mit Eis verwundbar. Sein Stampfen schleudert Felsen in alle Richtungen. |
| 1 | Endlos-Drache | Kreist ewig in einer liegenden Acht durch die Halle und spuckt Feuer. Ein Eisschwert-Treffer friert ihn kurz ein. Dahinter liegt das Portal, das alle drei Boss-Kristalle braucht. |

## Musik und Sounds
Alles in `audio/` wurde prozedural mit `tools/gen_audio.py` (numpy + ffmpeg) erzeugt:
* `music_dungeon.ogg`: düstere Dungeon-Musik in d-Moll, 72 BPM, mit Glocken, Herzschlag-Trommel und Wassertropfen
* `music_boss.ogg`: treibende Bosskampf-Musik in e-Moll, 150 BPM
* `music_victory.ogg`: Siegesfanfare
* Waffengeräusche: `swing`, `swing_fire`, `swing_ice`, `hit`, `clank`, `wall_break`
* Monstergeräusche: `bat`, `slime`, `knight`, `octopus`, `ink`, `golem`, `slam`, `dragon`, `fire`, `monster_die`
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
* `tools/build_map.py` erzeugt `scripts/level_data.gd` (ASCII-Karte) und prüft, dass jeder Abschnitt nur in der
  richtigen Reihenfolge erreichbar ist: `python3 tools/build_map.py > /dev/null`
* `tools/autotest.gd` spielt das Level automatisch durch, inklusive eines Bots, der die Scheiben und das Feuerfeld
  schafft: `godot --headless --script res://tools/autotest.gd`
* `tools/screenshots.gd` erstellt Screenshots aller Abschnitte.
* Grafik: alles wird per Code gezeichnet (`_draw`), es gibt keine Bilddateien.

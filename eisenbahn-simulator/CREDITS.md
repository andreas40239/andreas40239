# Quellen und Lizenzen

## Selbst erzeugt (für dieses Spiel)

| Was | Wie |
|---|---|
| 3D-Modelle (Lok, Wagen, Häuser, Kirche, Bäume, Gleise, Brücke, Bahnübergang, Bahnhof, Autos) | prozedural im Code: `scripts/mesh_kit.gd`, `scripts/models.gd`, `scripts/track_models.gd` |
| Texturen (Gras, Schotter, Asphalt, Wasser, Dampf) | `tools/gen_textures.py` |
| Symbole der Oberfläche (SVG), App-Icon, Startbild | `assets/ui/`, `tools/gen_icon.py` |
| Musik (Menü, Bauen, Fahren) und Erfolgs-Jingle | vollständig synthetisiert: `tools/gen_music.py` |
| Bedienklänge, Bremsenquietschen, Aufprall | synthetisiert: `tools/build_sfx.py` |

## Geräusche aus dem Internet

Alle Aufnahmen stammen von **Joseph Sardin – [BigSoundBank.com](https://bigsoundbank.com)** und stehen dort
unter **CC0 (Public Domain)**: frei verwendbar, auch kommerziell, ohne Pflicht zur Namensnennung.
Die Originaldateien liegen in `tools/audio_src/`, die Aufbereitung erledigt `tools/build_sfx.py`.

| Datei im Spiel | Original | Seite |
|---|---|---|
| `bell_loop.ogg` (Läutewerk am Bahnübergang) | Bell of a level crossing (Nr. 0899) | https://bigsoundbank.com/bell-of-a-level-crossing-s0899.html |
| `whistle.ogg` | Whistling train #2 (Nr. 0226) | https://bigsoundbank.com/whistling-train-2-s0226.html |
| `whistle2.ogg` | Train whistle, foley #2 (Nr. 3316) | https://bigsoundbank.com/train-whistle-foley-2-s3316.html |
| `hiss.ogg` (Dampf ablassen) | Steam locomotive, stop (Nr. 3015) | https://bigsoundbank.com/steam-locomotive-stop-s3015.html |
| `chuff1–4.wav` (Dampfschläge) | Steam engine, foley #2 (Nr. 3311) | https://bigsoundbank.com/steam-engine-foley-2-s3311.html |
| `roll_loop.ogg` (Rollgeräusch) | Train car (Nr. 2727, Ausschnitt) | https://bigsoundbank.com/train-car-s2727.html |

## Schrift

**Fredoka** – Copyright 2016 The Fredoka Project Authors, lizenziert unter der
SIL Open Font License 1.1 (siehe `assets/fonts/OFL.txt`).

## Engine

[Godot Engine](https://godotengine.org) 4.6 – MIT-Lizenz.

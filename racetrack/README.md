# Rennbahn-Baukasten (Godot 4.7.2, Android)

Greybox-Prototyp: Auf einem 24×24-Raster eine Rennstrecke bauen und sie danach
mit Gokart, Rennwagen (Ferrari-Stil) oder Monstertruck abfahren.

## Bedienung

**Editor**
- Teile werden an das offene Ende (gelber Pfeil) angehängt:
  Gerade, Booster, Rampe hoch/runter, Kurve eng (r=6 m), Kurve lang (r=18 m),
  Steilkurve (r=30 m, 30° Schräglage) – jeweils links/rechts.
- `Rückgängig`, `Alles löschen`, `Demo-Strecke`, `Übersicht`.
- Ein Finger ziehen = Kamera drehen, zwei Finger = Zoom.
- Endet die Strecke wieder am Start (gleiche Richtung, Bodenhöhe), ist sie
  geschlossen: Ein großes START/ZIEL-Banner erscheint und Runden werden gezählt.
- Die Strecke wird automatisch gespeichert.

**Fahren**
- Lenkrad links unten (drehen), großer GAS-Button rechts unten, BREMSE daneben
  (im Stand gedrückt halten = rückwärts).
- Die Banden sind fest; das Streckenende darf offen bleiben – dann geht es
  frei über das ganze Spielfeld. Endet die Strecke auf einer Rampe oder in einer
  Steilkurve, springt das Fahrzeug ab.
- Runde geschafft → Fanfare + Konfetti, Rundenzeit / Bestzeit.
- FPS-Anzeige oben rechts. Die 3D-Auflösung wird automatisch reduziert, falls
  die Bildrate unter ~42 FPS fällt (Ziel: nie unter 35).
- Desktop: Pfeiltasten/WASD, Leertaste = Bremse, R = Aufstellen, Esc = Editor.

## Eigene Musik

`music/song1.ogg … song3.ogg` sind generierte 60-Sekunden-Demos
(Techno mit Acid-Bass/Pads, Speedrock, Reggae). Eigene Songs einfach als
`music/song1.mp3`, `song2.mp3`, `song3.mp3` ablegen – MP3 hat Vorrang vor OGG.
Die Songs wechseln automatisch der Reihe nach.

## Technik

- Renderer: GL Compatibility (schnell auf Mobilgeräten), Physik: Jolt, 60 Hz.
- `scripts/track.gd` – Raster, Bauteile, Mittellinie (Höhe/Schräglage geglättet),
  Fahrbahn-/Banden-Mesh, einseitige Kollisionsdreiecke, Booster, Banner.
- `scripts/car.gd` – eigenes Raycast-Fahrzeug (Federung, Reibkreis,
  Antrieb, Booster, Ausrichten in der Luft).
- `scripts/car_models.gd`, `landscape.gd`, `game_camera.gd`,
  `touch_controls.gd`, `game_audio.gd`, `main.gd`.
- `tools/gen_audio.py` – Offline-Synthesizer für Musik und Sounds
  (`python3 tools/gen_audio.py`, benötigt numpy, scipy, ffmpeg).
- `tools/autotest.gd` / `tools/walltest.gd` – Headless-Fahrtests
  (`godot --headless --path . -s res://tools/autotest.gd`).

## APK bauen

Export-Preset „Android“ (arm64-v8a, Ziel-SDK 36 / Android 16):

```
godot --headless --path . --export-release "Android" build/rennbahn.apk
```

Signatur über `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD`.

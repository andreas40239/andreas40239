# Coaster Demo (Godot 4.3, Android arm64)

Greybox-Prototyp: Achterbahn in isometrischer Ansicht bauen und anschließend
selbst mitfahren. Alles besteht aus grauen Platzhalter-Formen – die richtigen
Grafik-Assets kommen später.

| Bauen | Fahren |
|---|---|
| ![Bauen](docs/bauen.png) | ![Fahren](docs/fahren.png) |

## Steuerung

**Baumodus**

| Geste | Wirkung |
|---|---|
| Tippen auf das **grüne Feld** (bzw. das Feld davor) | Teil geradeaus setzen (zuletzt gewählte Art: Gerade / Hoch / Runter) |
| Tippen auf ein **helles Seitenfeld** | Kurve links / rechts |
| 1 Finger ziehen | Ansicht verschieben |
| 2 Finger (Pinch) | Zoomen |
| Joystick (unten links) | Links/rechts: Ansicht drehen · hoch/runter: Blickwinkel kippen |
| Buttons unten | Links, Gerade, Rechts, Hoch, Runter, Zurück, Demo-Strecke, Neu, FAHREN |

Die Strecke startet an der Station. Führt man sie in Fahrtrichtung zurück in
die Station, ist sie **geschlossen** und der Wagen fährt endlos Runden. Offene
Strecken können auch getestet werden – die Fahrt endet dann am letzten Teil.
Kreuzungen sind erlaubt, wenn mindestens eine Höhenstufe Abstand dazwischen ist.

**Fahrmodus**: Joystick oder Wischen zum Umschauen, *Ansicht* wechselt
zwischen 1. und 3. Person, *Stopp* zurück zum Bauen.

Auf dem Desktop: Linksklick = Tippen/Verschieben, Mausrad = Zoom,
rechte Maustaste ziehen = Drehen.

## Fahrphysik (vereinfacht)

- Hangabtrieb `a = -g · dy/ds`, dazu Luftwiderstand und Rollreibung
- „Hoch“-Teile haben einen Kettenlift (min. 3 m/s)
- Die Station bremst/beschleunigt auf 4 m/s
- Antriebsreifen verhindern Stillstand (min. 1 m/s)

## Projektstruktur

```
project.godot          Projekteinstellungen (GL Compatibility, Querformat)
main.tscn              Hauptszene (baut Welt/UI per Code auf)
scripts/main.gd        Welt, UI, Eingabe (Tap/Pinch/Pan), Fahrmodus
scripts/track.gd       Raster-Strecke, Pfad-Berechnung, Greybox-Meshes
scripts/iso_camera.gd  Isometrische Orthogonal-Kamera
scripts/joystick.gd    Virtueller Touch-Joystick
tests/smoke_test.gd    Headless-Test (Bauen, Tap, Schließen, Fahrt)
tests/screenshots.gd   Rendert Kontroll-Screenshots
export_presets.cfg     Android-Export (nur arm64-v8a)
```

## Bauen & Testen

```bash
# Test (headless)
godot --headless --path coaster_demo -s res://tests/smoke_test.gd

# APK exportieren (Android-SDK + Debug-Keystore in den Editor-Einstellungen nötig)
godot --headless --path coaster_demo --export-debug "Android arm64" build/coaster_demo_arm64.apk
```

Der GitHub-Workflow `.github/workflows/coaster-android.yml` baut bei jedem
Push das APK und stellt es als Artefakt `coaster_demo_arm64` bereit.
Installation auf dem Handy: APK herunterladen, „Installation aus unbekannten
Quellen“ erlauben, öffnen.

## Nächste Schritte (Ideen)

- Echte Assets (Schienen, Wagen, Stützen, Umgebung) statt Greybox
- Mehr Teile: steile Abfahrten, Loopings, Kurven mit Neigung, Booster
- Mehrere Wagen, G-Kräfte-Anzeige, Speichern/Laden von Strecken

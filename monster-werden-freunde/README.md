# Monster werden Freunde

Gewaltfreies Tower-Defense-Spiel für Kinder von 6–8 Jahren, umgesetzt nach dem Game Design Document
(Konzeptversion 1.0). Engine: **Godot 4.4.1**, GDScript, 2D. Zielplattform: **Android arm64-v8a**,
Querformat, für Tablets und große Handys.

**APK zum Installieren:** [`../dist/MonsterWerdenFreunde.apk`](../dist/MonsterWerdenFreunde.apk)
(Release-Build, signiert, nur arm64-v8a, Android 5.0+, keine Berechtigungen, offline).

## Spielprinzip

Monster laufen über einen Pfad ins Dorf. Jedes hat **ein Bedürfnis** (Icon-Blase über dem Kopf +
Farbe + Animation). Passende Stationen senken `need_value`; bei 0 wird das Monster zum **Freund**,
läuft ins Dorf und bringt Sonnenpunkte. Wilde Monster im Dorf machen nur **Trubel (Chaos)**. Es gibt
keine HP, keinen Schaden, keinen Tod. Bei 10 Chaos endet das Level mit freundlichem „Nochmal“.

| Monster | Bedürfnis | Hilft |
|---|---|---|
| Knurri | Hunger (Apfel) | Keksstand |
| Matschi | schmutzig (Blase) | Seifenblasenmaschine |
| Tröpfli | traurig (Note) | Musikbox |
| Schlummi | müde (Mond) | Ruhe-Station |
| Flitzi | überdreht (Windrad) | Ventilator (bremst), Musikbox |

Bedienung: **+** auf der Wiese antippen → Stationskarte antippen. Station antippen → *Weiter*
(+20 % Reichweite) / *Stärker* (+25 % Wirkung) / *Verkaufen* (75 % zurück, bei teuren Stationen mit
„Sicher?“). Pause (Bauen bleibt möglich), 1x/2x (ab Level 3), Menü mit Musik- und Geräusche-Regler.

Enthalten (MVP laut GDD Kap. 17): 5 Level mit Tutorial (Welt 1 „Sonnental“), 5 Monster, 5 Stationen,
2 Upgrade-Stufen, lokale Speicherung (`user://save.json`, atomisch), Levelauswahl mit Sternen,
Deutsch, Querformat, kein Netzwerk, keine Werbung/Käufe.

## Projektstruktur

```
autoload/      GameState, SaveManager, AudioManager
data/          monsters/, stations/, levels/  (.tres - datengetrieben)
scenes/        main/, meta/ (Titel, Levelauswahl), game/, monster/, stations/, ui/
scripts/       data/ (Resource-Klassen), game/ (Game, WaveManager, BuildManager, Karte, Fx),
               monster/, stations/, ui/ (HUD, Widgets), art/ (Vektor-Zeichnungen), meta/, main/
art/, audio/   Schrift (Fredoka, OFL), Icons; Sounds + Musik (prozedural erzeugt)
tests/         Akzeptanztests, Balancing-Simulation, Screenshot-Werkzeug
tools/         Generatoren für Daten (.tres), Sounds und Icons
```

Alle Grafiken werden als Vektoren im Code gezeichnet (`scripts/art/`), alle Klänge mit
`tools/gen_audio.py` erzeugt – es gibt keine fremden Assets außer der Schrift Fredoka (SIL OFL).

## Abweichungen vom GDD (bewusst)

* **Balancing:** Mit den Startwerten aus Kap. 4 war kein Level schaffbar (ein Keksstand schafft
  ~18 Bedürfnispunkte/s, Welle 1 bringt ~55/s). Das GDD erlaubt Anpassungen nach Tests. Geändert:
  Takt Seifenblasen 0,45 s, Keksstand 0,6 s, Ventilator 0,55 s; Musikbox 14/7 pro s, Ruhe 16 pro s
  (Reichweite 140); Belohnungen 25–35; Schlummi 115/40 px/s; Flitzi 75/74 px/s; Startpunkte
  L4 = 460, L5 = 600. Die Simulation (`tests/Simulation.tscn`) gewinnt damit alle Level.
* **Karten:** statt `map_scene` enthält `LevelData` Pfadpunkte und Bauplätze (Kurven werden
  automatisch abgerundet).
* **Reichweite:** Stationen prüfen Abstände direkt statt über Area2D (einfacher, gleiches Verhalten).

## Bauen und Testen

```bash
godot --headless --path . --import                       # Import
godot --headless --path . -s tools/generate_data.gd      # .tres-Daten neu erzeugen
godot --headless --path . res://tests/TestRunner.tscn    # Akzeptanztests AT-01..AT-09
godot --headless --fixed-fps 60 --path . res://tests/Simulation.tscn   # Balancing-Bot
```

Android-Export (Godot 4.4.1 + Export-Templates, Android SDK mit build-tools, JDK 17+):

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/pfad/release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=<alias>
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<passwort>
godot --headless --path . --export-release "Android" ../dist/MonsterWerdenFreunde.apk
```

Die beiliegende APK ist mit einem eigens erzeugten Schlüssel signiert, der nicht im Repository
liegt. Für eine Veröffentlichung (z. B. Google Play) mit einem eigenen Schlüssel neu exportieren.

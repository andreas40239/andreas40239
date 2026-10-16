# Monster werden Freunde

Gewaltfreies Tower-Defense-Spiel für Kinder von 6–8 Jahren, umgesetzt nach dem Game Design Document
(Konzeptversion 1.0). Engine: **Godot 4.7.2**, GDScript, 2D. Zielplattform: **Android arm64-v8a**,
Querformat, für Tablets und große Handys.

Downloads (Version 1.2.0, versionCode 4):

* **APK zum Installieren:** [`../dist/MonsterWerdenFreunde.apk`](../dist/MonsterWerdenFreunde.apk)
* **App Bundle für Google Play:** [`../dist/MonsterWerdenFreunde.aab`](../dist/MonsterWerdenFreunde.aab)
* **Play-Store-Icon (512×512):** [`../dist/PlayStore_Icon_512.png`](../dist/PlayStore_Icon_512.png)

Beide Builds: Release, signiert, nur arm64-v8a, Android 7.0+ (minSdk 24), Ziel-API 36,
16-KB-Speicherseiten-tauglich, keine Berechtigungen, offline.

### Play Store

* Die AAB ist mit dem Upload-Schlüssel des Projekts signiert (nicht im Repository). Bei der
  ersten Veröffentlichung „Play App Signing“ aktivieren; Google signiert die ausgelieferten APKs.
* Ziel-API 36 und 16-KB-Seitenausrichtung der nativen Bibliotheken (Pflicht für neue Apps) sind
  erfüllt – deshalb wurde in 1.2.0 von Godot 4.4.1 auf 4.7.2 umgestellt.
* Inhaltseinstufung: Spiel ohne Gewalt, ohne Werbung, ohne Käufe, ohne Datenerhebung
  (Datensicherheit: „keine Daten erhoben/geteilt“). Zielgruppe Kinder → Richtlinie „Familien“ beachten.

### App-Icons

Die App-Icons sind vorgegebene Grafiken in `art/icons/`: `icon_192.png` (Launcher),
`icon_bg_432.png` / `icon_fg_432.png` (adaptives Icon), `icon_mono_432.png` (monochromes
Android-13-Icon, aus dem Vordergrund abgeleitet), `icon_store_512.png` (Play Store, auch `icon.png`).

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
| Elektro | leer (Batterie) | Batterieladen |
| Flügel | möchte fliegen (Flügel) | Flügelladen |
| Bibber | friert (Schneeflocke) | Kakaostand |
| Flocki | einsam (zwei Freunde) | Schneemann-Werkstatt |

Bedienung: **+** auf der Wiese antippen → Stationskarte antippen. Station antippen → *Weiter*
(+20 % Reichweite) / *Stärker* (+25 % Wirkung) / *Verkaufen* (75 % zurück, bei teuren Stationen mit
„Sicher?“). Pause (Bauen bleibt möglich), 1x/2x (ab Level 3), Menü mit Musik- und Geräusche-Regler.

Enthalten: **3 Welten mit je 5 Leveln** (15 Level), 9 Monster, 10 Stationen, 2 Upgrade-Stufen,
Welt- und Levelauswahl mit Sternen (eine Welt öffnet sich erst, wenn die vorherige geschafft ist),
lokale Speicherung (`user://save.json`, atomisch), **Sprachauswahl per Flagge: Deutsch, Englisch,
Griechisch**, Querformat, kein Netzwerk, keine Werbung/Käufe. Pro Level höchstens 5 Monstertypen
und höchstens 5 Stationen (wird beim Erzeugen der Daten und in den Tests geprüft).

### Welten (Version 1.1)

| Welt | Level | Neu |
|---|---|---|
| 1 Sonnental | 1–5 | Knurri, Matschi, Tröpfli, Flitzi, Schlummi |
| 2 Strand und Meer | 6–10 | **Elektro** (braucht Batterien – aufgeladen rennt es 3x so schnell ins Dorf), **Flügel** (bekommt im Flügelladen Flügel und fliegt dann direkt ins Dorf), **Disco** |
| 3 Schnee und Berge | 11–15 | **Bibber** (friert → Kakaostand), **Flocki** (ist einsam → Schneemann-Werkstatt) |

**Disco:** Die Monster in Reichweite bleiben stehen und tanzen eine Weile (2,5 s, mit „Stärker“
länger). Ihr Zustand ändert sich nicht – die Disco verschafft nur Zeit. Danach laufen sie
mindestens 3 s weiter, bevor sie wieder tanzen können (kein Dauer-Festhalten).

Jede Welt hat eigene Grafik (Wiese / Sand mit Meer und Palmen / Schnee mit Bergen und Tannen),
ein eigenes Dorf und eigene Musik.

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
`tools/gen_audio.py` erzeugt – es gibt keine fremden Assets außer den Schriften Fredoka und
M PLUS Rounded 1c (für Griechisch; beide SIL OFL).

**Übersetzungen:** Quelltexte sind Deutsch, Englisch und Griechisch stehen in
`scripts/i18n/Strings.gd` (Autoload `I18n` registriert sie beim TranslationServer). Ein Test prüft,
dass alle Monster-, Stations-, Level- und Tutorial-Texte übersetzt sind.

## Abweichungen vom GDD (bewusst)

* **Balancing:** Mit den Startwerten aus Kap. 4 war kein Level schaffbar (ein Keksstand schafft
  ~18 Bedürfnispunkte/s, Welle 1 bringt ~55/s). Das GDD erlaubt Anpassungen nach Tests. Geändert:
  Takt Seifenblasen 0,45 s, Keksstand 0,6 s, Ventilator 0,55 s; Musikbox 14/7 pro s, Ruhe 16 pro s
  (Reichweite 140); Belohnungen 25–35; Schlummi 115/40 px/s; Flitzi 75/74 px/s; Startpunkte
  L4 = 460, L5 = 600. Die Simulation (`tests/Simulation.tscn`) gewinnt damit alle 15 Level
  (sowohl „alles ausgeben“ als auch „sparsam bauen“).
* **Version 1.1.1:** Welt 2 ab Level 7 deutlich leichter: mehr Startpunkte (L7 540, L8 660,
  L9 640, L10 700), kleinere spätere Wellen (höchstens 10 Monster pro Welle, insgesamt 31–39
  statt 42–70 Monster pro Level), größere Abstände zwischen den Monstern und 11 s Pause
  zwischen den Wellen.
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

Android-Export (Godot 4.7.2 + Export-Templates, Android SDK mit platforms;android-36 und
build-tools 36.1.0, JDK 17+):

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/pfad/release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=<alias>
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<passwort>
godot --headless --path . --export-release "Android" ../dist/MonsterWerdenFreunde.apk
godot --headless --path . --export-release "Android AAB" ../dist/MonsterWerdenFreunde.aab
```

Für die AAB (Gradle-Build) einmal im Editor *Projekt → Android-Build-Vorlage installieren*
ausführen (legt den ignorierten Ordner `android/` an). Gradle lädt beim ersten Build Bibliotheken
von Google Maven und Maven Central.

Die beiliegende APK ist mit einem eigens erzeugten Schlüssel signiert, der nicht im Repository
liegt. Für eine Veröffentlichung (z. B. Google Play) mit einem eigenen Schlüssel neu exportieren.

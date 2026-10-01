# Schattengruft – Labyrinth-Dungeon (Prototyp v0.1)

Düsterer Dungeon-Crawler für Android (arm64) in 3/4-Ansicht: lila Steinmauern mit Säulen und orangefarbener Sandboden.

## Spielen

* **Android:** `app-release.apk` installieren (wird per GitHub Actions gebaut, siehe unten).
* **Browser (zum Testen):** `web/index.html` öffnen. Steuerung per Tastatur: WASD/Pfeile, `J` `K` `L` für die Aktionen, `1` `2` `3` zum Belegen, `M` für die Karte, `Esc` für Pause.

## Features

* **Steuerung:** virtueller Joystick links, drei frei belegbare Aktionstasten rechts (lange drücken oder über das Pausemenü belegen). Der Spieler bleibt immer in der Bildschirmmitte.
* **Labyrinth:** prozedural erzeugt (Backtracker + Schleifen + Säulenräume) und wird mit jeder Ebene größer und verwinkelter. Es wird erst beim Erkunden sichtbar (Sichtlinien-Nebel). Oben rechts gibt es eine Mini-Karte, antippen öffnet die große Karte.
* **Waffen:** Schwert (Schnitt), Axt (Wucht), Bogen (Stich, Fernkampf); jede bis Stufe 5 aufrüstbar.
* **Magie (über Stufenaufstiege):** Lähmung (Stufe 2), Feuerwand (Stufe 3), Eisregen (Stufe 5).
* **Monster mit Eigenschaften und Schwächen:**

| Monster | Eigenschaft | Schwäche |
|---|---|---|
| Schleim | teilt sich beim Tod | Feuer |
| Fledermaus | schnell, sprunghaft | Bogen |
| Skelett | setzt sich wieder zusammen (außer bei Axt oder Feuer) | Axt |
| Geist | schwebt durch Wände | Magie |
| Feuerkobold | wirft Feuerbälle, immun gegen Feuer | Eis |
| Steingolem | zäh, kaum zu lähmen | Eis & Axt |

* **Schatztruhen:** Herzen (auch Herzcontainer), Mana (auch Manakristalle), neue Waffen und Waffen-Upgrades.
* **Audio:** alles wird live per WebAudio synthetisiert, es gibt keine Audiodateien. Dazu gehören düstere Hintergrundmusik (D-Moll-Drone, Pads, Glocken, Herzschlag) sowie Sounds für Waffen, Magie, Schritte, jedes Monster und das Menü.

## Aufbau

```
web/        Spiel (HTML5 Canvas + JavaScript, keine Abhängigkeiten)
  js/data.js     Waffen, Zauber, Monsterdaten
  js/audio.js    Musik- und Sound-Synthese
  js/dungeon.js  Labyrinth-Generator
  js/render.js   Grafik (Wände, Boden, Figuren, Effekte)
  js/game.js     Spiellogik
  js/input.js    Touch/Tastatur + HUD + Mini-Karte
  js/ui.js       Menüs
android/    Schlanke WebView-App (Java, keine AndroidX), lädt web/ als Assets
```

## APK bauen

Voraussetzungen: JDK 17+ und das Android SDK (Platform 35).

```
cd schattengruft/android
./gradlew assembleRelease
# -> app/build/outputs/apk/release/app-release.apk
```

Die APK ist für den Prototyp mit dem Debug-Schlüssel signiert und lässt sich direkt installieren („Unbekannte Quellen“ erlauben).

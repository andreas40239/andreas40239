# 🌊 Tsunami Mauerbau (Godot 4)

Sammle Steine, Holz und Sand, verbessere deine Werkzeuge, kaufe Baumaschinen und
baue eine Mauer, die den Tsunami aufhält. Mit jedem Level wird die Welle höher.

## Starten
1. [Godot 4.3+](https://godotengine.org/download) installieren (Standard-Version, kein .NET nötig).
2. In Godot **Importieren** → `tsunami-game/project.godot` auswählen.
3. **F5** drücken (oder den Play-Knopf oben rechts im Editor).

## So wird gespielt
Jedes Level beginnt mit einem **Erdbeben**. Dann läuft ein **Countdown** bis zum Tsunami.

**Vor dem Tsunami (Countdown):**
| Aktion | Wie |
|---|---|
| Rohstoffe sammeln | Auf **Felsen** (Steine), **Wald** (Holz) oder **Sandhaufen** (Sand) tippen |
| Mauer bauen | Material wählen: **Holz** (billig, schwach), **Stein**, **Beton** (teuer, sehr stabil). Tasten 1/2/3 |
| Werkzeuge | Spitzhacke, Axt, Schaufel: mehr Ertrag pro Tipp |
| Baumaschinen | **Bagger** (Steine + Sand), **Holzernter** (Holz), **Betonmischer** (Beton aus Sand + Steinen), **Kran** (dickere Mauerschichten) |
| Schutz & Dorf | **Wellenbrecher** (−6 % Wellenhöhe je Stufe), **Schutzwald** (−4 % je Stufe), **Warnboje** (genauere Höhenmessung), zerstörte **Häuser wieder aufbauen** |
| Früher auslösen | **JETZT auslösen** (Taste P): Wer nicht abwartet, bekommt für die restlichen Sekunden einen Rohstoff-Bonus |

Die genaue Höhe der Welle kennt man vorher nicht. Hinweise gibt es trotzdem:
- Die Erdbebenstärke auf dem Seismographen.
- Ein roter Bereich zeigt die erwartete Höhe. Je besser die Warnboje, desto schmaler wird er.
- In den letzten 15 Sekunden zieht sich das Meer zurück, bei höheren Wellen weiter. In den letzten 10 Sekunden heult die Sirene.

**Während des Tsunamis:**
- Ab Level 2 kommen **mehrere Wellen** hintereinander.
- Beim Aufprall bekommt die Mauer **Risse**. Tippe schnell darauf, bevor der Ring abläuft, sonst bricht der Riss auf.
- **Treibgut** (Boote, Container, Baumstämme) reitet auf den Wellen. Tippst du darauf, wird es zerstört und du bekommst Rohstoffe. Erreicht es die Mauer, gibt es Schaden und einen neuen Riss.
- Die Mauer hat **Stabilität** (Balken oben). Fällt sie auf 0, gibt es einen **Mauerbruch**: Die oberen Schichten stürzen ein.
- Schwappt Wasser über die Mauer, werden **Häuser** weggespült, zuerst die direkt hinter der Mauer.

**Wertung:**
- 3 Sterne: Kein Haus verloren und die Mauer ist nicht gebrochen.
- 2 Sterne: Kein Haus verloren, aber die Mauer ist gebrochen.
- 1 Stern: Genau 1 Haus verloren.

Danach startet automatisch das nächste, höhere Level. Sind alle Häuser zerstört, heißt es **Game Over**.

## Technik
- Grafik: alles prozedural mit `_draw()` gezeichnet (Wellen, Wasserstand, Überflutung, Gischt-Partikel, animierte Maschinen)
- Sound: Meeresrauschen, Tsunami-Grollen und Motorbrummen der Baumaschinen werden live mit einem `AudioStreamGenerator` erzeugt, Audiodateien gibt es keine
- `scripts/main.gd`: Spiellogik, Kosten/Balancing, Benutzeroberfläche
- `scripts/world.gd`: Spielwelt und Tsunami-Ablauf (Rückzug → Wellen mit Rissen/Treibgut → Überflutung → Ablaufen)
- `scripts/ocean_audio.gd`: prozeduraler Sound

## Android (arm64)
Fertige APK: [`apk/TsunamiMauerbau-arm64.apk`](apk/TsunamiMauerbau-arm64.apk) (Android 5.0+, nur arm64-v8a, Querformat).

Installation: APK aufs Handy laden, öffnen und „Installation aus unbekannten Quellen“ für den Browser/Dateimanager erlauben.
Auf dem Handy wird getippt statt geklickt, Tastenkürzel braucht man dort nicht. Bei Aufprall und Mauerbruch vibriert das Handy.

Selbst exportieren: In Godot unter *Editor → Export-Vorlagen verwalten* die Vorlagen für 4.3 installieren, in den
Editor-Einstellungen Android-SDK und Debug-Keystore eintragen, dann *Projekt → Exportieren → Android* (Preset ist in
`export_presets.cfg` bereits angelegt). Den Release-Keystore kann man per Umgebungsvariablen
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD` übergeben.

# 🌊 Tsunami Mauerbau (Godot 4)

Sammle Steine, Holz und Sand, verbessere deine Werkzeuge, kaufe Baumaschinen und
baue eine Mauer, die den Tsunami aufhält. Mit jedem Level wird die Welle höher.

## Starten
1. [Godot 4.3+](https://godotengine.org/download) installieren (Standard-Version, kein .NET nötig).
2. In Godot **Importieren** → `tsunami-game/project.godot` auswählen.
3. **F5** drücken (oder den Play-Knopf oben rechts im Editor).

## So wird gespielt
| Aktion | Wie |
|---|---|
| Rohstoffe sammeln | Auf **Felsen** (Steine), **Wald** (Holz) oder **Sandhaufen** (Sand) klicken |
| Werkzeuge verbessern | Spitzhacke, Axt, Schaufel: mehr Ertrag pro Klick |
| Baumaschinen | **Bagger** (Steine + Sand automatisch), **Holzernter** (Holz automatisch), **Betonmischer** (macht Beton aus Sand + Steinen), **Kran** (höhere Mauerschichten pro Bauschritt) |
| Mauer bauen | Button „Mauer bauen“ oder Taste **B**. Ab 4 m Höhe wird zusätzlich Beton gebraucht. |
| Tsunami testen | **PLAY** oder Taste **P**: Das Meer zieht sich zurück, dann rollt die Welle an. |

Beim ersten Versuch eines Levels ist die Höhe des Tsunamis unbekannt („??? m“).
Nach dem Aufprall wird sie als rote Linie angezeigt. Ist die Mauer zu niedrig, wird das Land
überflutet und du baust weiter. Ist sie hoch genug, zerschellt die Welle an der Mauer.
Dann gibt es einen Bonus und das nächste Level startet automatisch.

## Technik
- Grafik: alles prozedural mit `_draw()` gezeichnet (Wellen, Wasserstand, Überflutung, Gischt-Partikel, animierte Maschinen)
- Sound: Meeresrauschen, Tsunami-Grollen und Motorbrummen der Baumaschinen werden live mit einem `AudioStreamGenerator` erzeugt, Audiodateien gibt es keine
- `scripts/main.gd`: Spiellogik, Kosten/Balancing, Benutzeroberfläche
- `scripts/world.gd`: Spielwelt und Tsunami-Ablauf (Rückzug → Anrollen → Aufprall/Überflutung → Ablaufen)
- `scripts/ocean_audio.gd`: prozeduraler Sound

## Android (arm64)
Fertige APK: [`apk/TsunamiMauerbau-arm64.apk`](apk/TsunamiMauerbau-arm64.apk) (Android 5.0+, nur arm64-v8a, Querformat).

Installation: APK aufs Handy laden, öffnen und „Installation aus unbekannten Quellen“ für den Browser/Dateimanager erlauben.
Auf dem Handy wird getippt statt geklickt; die Tastenkürzel B und P braucht man dort nicht.

Selbst exportieren: In Godot unter *Editor → Export-Vorlagen verwalten* die Vorlagen für 4.3 installieren, in den
Editor-Einstellungen Android-SDK und Debug-Keystore eintragen, dann *Projekt → Exportieren → Android* (Preset ist in
`export_presets.cfg` bereits angelegt). Den Release-Keystore kann man per Umgebungsvariablen
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD` übergeben.

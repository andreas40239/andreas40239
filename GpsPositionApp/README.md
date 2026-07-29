# GPS Position

Offline-fähige Android-App (Kotlin), die ausschließlich über den GPS-Sensor
(`LocationManager.GPS_PROVIDER`, kein Netzwerk, kein Google Play Services)
folgende Werte live anzeigt:

- **Position** als Breite/Länge im Format Grad° Minute' Sekunde" (z. B. `48° 51' 24.3" N`)
- **Fahrtrichtung** in Grad (0–360°) plus Himmelsrichtung, z. B. `137° (SO)`
- **Geschwindigkeit** in km/h

Die App funktioniert im Flugmodus, solange GPS/Standort separat aktiviert ist,
da nur der reine Satellitenempfang genutzt wird.

## Build & Installation

1. Projektordner `GpsPositionApp/` in Android Studio öffnen ("Open").
2. Android Studio synchronisiert Gradle automatisch und ergänzt fehlende
   Wrapper-Dateien (`gradle-wrapper.jar`) selbstständig. Falls stattdessen
   die Kommandozeile genutzt werden soll, einmalig lokal ausführen:
   ```
   gradle wrapper --gradle-version 8.7
   ```
3. Smartphone per USB anschließen (USB-Debugging aktivieren) und über
   "Run ▶" installieren, oder eine APK bauen:
   ```
   ./gradlew assembleDebug
   ```
   Die fertige APK liegt danach unter
   `app/build/outputs/apk/debug/app-debug.apk` und kann auch ohne Android
   Studio direkt per `adb install` auf das Gerät übertragen werden.

## Berechtigungen

Beim ersten Start fragt die App nach der Standortberechtigung
(`ACCESS_FINE_LOCATION`). Falls GPS im System deaktiviert ist, öffnet ein
Dialog direkt die Standort-Einstellungen.

## Hinweis zur Formatangabe

GPS-Koordinaten werden technisch in **Grad/Minuten/Sekunden** angegeben
(nicht Stunden – "Stunden" gehört zu astronomischen Koordinatensystemen).
Deshalb zeigt die App Breite/Länge im Grad-Minuten-Sekunden-Format an.

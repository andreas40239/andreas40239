# Lautstärke-Ampel (Android)

Native Android-App, die die Umgebungslautstärke über das Mikrofon misst und den
Bildschirm je nach dB-Pegel grün, gelb oder rot färbt. Umsetzung der Anforderungen
aus dem Dokument *„Anforderungen: Lautstärke-Ampel (Android App)“*.

## Fertige APK

`dist/lautstaerke-ampel-debug.apk` – mit dem Android-Debug-Key signiert und direkt
installierbar (kein Play Store nötig).

Installation auf dem Gerät:

1. APK auf das Android-Gerät kopieren (USB, Cloud-Speicher, E-Mail an sich selbst …).
2. Im Dateimanager öffnen und die Installation aus unbekannter Quelle für die
   verwendete App einmalig erlauben.
3. Beim ersten Start der Messung den Mikrofonzugriff erlauben.

Alternativ per ADB: `adb install -r dist/lautstaerke-ampel-debug.apk`

## Funktionsumfang

- Live-Messung über `AudioRecord` (44,1 kHz, Mono, PCM 16 Bit), Anzeige 10× pro Sekunde
- dB-Berechnung wie in der Web-Version: `20 * log10(RMS) + Kalibrierungs-Offset`
- Glättung über einen gleitenden Mittelwert der letzten 8 Fenster
- Hintergrundfarbe nach Schwellwerten: grün (ruhig) / gelb (erhöht) / rot (laut)
- Horizontale Pegelanzeige (30–100 dB) mit Markierungen für beide Schwellwerte
- Start/Stopp der Messung; der Bildschirm bleibt während der Messung an
- Einstellungen (ausklappbar): „Gelb ab (dB)“ = 55, „Rot ab (dB)“ = 65,
  „Kalibrierungs-Offset“ = 100 – gespeichert in SharedPreferences, wirken sofort
- Verständliche Fehlermeldung samt Direktlink in die App-Einstellungen, wenn der
  Mikrofonzugriff verweigert wurde
- Keine `INTERNET`-Berechtigung: die App läuft vollständig offline, Audiodaten
  werden nur lokal verarbeitet und nicht gespeichert

## Technik

- Kotlin, natives Android (kein WebView), Views + ViewBinding
- minSdk 26 (Android 8.0), targetSdk/compileSdk 35
- Einzige Berechtigung: `RECORD_AUDIO`

## Selbst bauen

Voraussetzungen: JDK 17+ und ein Android SDK (Platform 35, Build-Tools 35.0.0).
Pfad zum SDK in `local.properties` eintragen (`sdk.dir=/pfad/zum/android-sdk`)
oder `ANDROID_HOME` setzen.

```bash
./gradlew assembleDebug       # APK: app/build/outputs/apk/debug/app-debug.apk
./gradlew testDebugUnitTest   # Unit-Tests der Mess- und Schwellwertlogik
./gradlew lintDebug           # Android Lint
```

## Projektstruktur

| Datei | Inhalt |
| --- | --- |
| `app/src/main/java/.../MainActivity.kt` | UI, Zustandswechsel, Berechtigungen, Einstellungen |
| `app/src/main/java/.../AudioMeter.kt` | Aufnahme-Thread auf Basis von `AudioRecord` |
| `app/src/main/java/.../SoundLevel.kt` | Reine Rechenlogik (RMS, dB, Ampelzustand, Glättung) |
| `app/src/main/java/.../LevelBarView.kt` | Pegelbalken mit Schwellwert-Markierungen |
| `app/src/test/java/.../SoundLevelTest.kt` | Unit-Tests (10 Tests) |

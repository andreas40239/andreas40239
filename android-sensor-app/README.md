# SensorScope

Android-App (Kotlin + Jetpack Compose), die **alle Sensoren** ausliest, die
`SensorManager` auf dem jeweiligen Gerät meldet, plus eine dedizierte
Temperatur-Sektion für ein **Samsung Galaxy S24 Ultra**.

## Warum keine "Chip-Temperatur in °C"?

Das S24 Ultra besitzt **keinen** `TYPE_AMBIENT_TEMPERATURE`-Sensor (Umgebungstemperatur) –
die App erkennt das automatisch und zeigt das entsprechend an. Die exakte
SoC-/CPU-Temperatur ist für normale (Nicht-System-)Apps aus Sicherheitsgründen
grundsätzlich nicht zugänglich (nur über `HardwarePropertiesManager`, was
`android.permission.DEVICE_POWER` voraussetzt – ein System-Only-Permission).

Stattdessen zeigt die App die auf dem S24 Ultra tatsächlich verfügbaren,
echten Hitze-Signale:

- **Akku-Temperatur** – exakte °C, aus dem `BATTERY_CHANGED`-Broadcast
- **Thermal-Status** – Androids eigene Klassifikation (`PowerManager`, "Normal" … "Kritisch")
- **Thermal Headroom (10 s-Prognose)** – 0 = kühl, > 1 = Drosselung droht (API 29+)

Darunter listet die App **alle** vom Gerät gemeldeten Hardware-Sensoren live
(Beschleunigung, Gyroskop, Magnetfeld, Licht, Näherung, Barometer, Schwerkraft,
Rotationsvektoren, Schrittzähler, etc.) mit Live-Werten, Einheit und Hersteller.

## Build & Ausführen

Voraussetzung: Android Studio (Koala/Ladybug oder neuer) mit installiertem
Android SDK (compileSdk 34).

1. Ordner `android-sensor-app/` in Android Studio öffnen ("Open" → Projektordner wählen)
2. Gradle-Sync abwarten
3. S24 Ultra per USB anschließen (Entwickleroptionen + USB-Debugging aktiv)
4. Run ▶ auf das Gerät

Alternativ über die Kommandozeile (SDK muss lokal installiert und in
`local.properties`/`ANDROID_HOME` konfiguriert sein):

```bash
./gradlew installDebug
```

> Hinweis: Dieses Projekt wurde in einer Umgebung ohne installiertes Android
> SDK erstellt. Der Gradle-Wrapper ist vorhanden und geprüft, ein echter
> `assembleDebug`-Build (der das Android SDK benötigt) konnte hier aber nicht
> ausgeführt werden. Bitte beim ersten Öffnen in Android Studio einmal
> synchronisieren und bauen.

## Berechtigungen

- `BODY_SENSORS` wird nur für evtl. vorhandene Herzfrequenz-/Körpersensoren
  angefordert. Das S24 Ultra hat serienmäßig keinen Herzfrequenzsensor im
  Telefon selbst; die Berechtigung ist rein defensiv für andere Geräte/Zubehör.

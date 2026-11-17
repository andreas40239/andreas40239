# Zombie in Athen

Isometrisches Zombie-Versteckspiel in zufällig erzeugten Orten in Athen: Wohnung, große
Wohnung, Taverne und Schule.
Godot 4.5 (GDScript, Compatibility-Renderer / OpenGL ES 3), Zielplattform **Android arm64**,
Querformat, Touch-Steuerung. Zielgruppe ab ca. 16 Jahren.

Fertige Debug-APK: [`build/ZombieInAthen-debug.apk`](build/ZombieInAthen-debug.apk)
(`adb install -r build/ZombieInAthen-debug.apk` oder Datei aufs Handy kopieren und öffnen).

## Spielprinzip

Du wachst in einer Wohnung auf (Schlafzimmer, Bad mit Dusche, Küche, Flur und zwei weitere
Zimmer). Nach **30 Sekunden** brechen Zombies durch ein Fenster oder die Wohnungstür.

| | |
|---|---|
| **Zombies** | reagieren auf Bewegung (Sichtlinie) und Geräusche. Hören sie etwas, rennen sie 3 s in die Richtung. Nach einem Biss verharren sie 3 s. |
| **Rennen** | Menschen rennen immer – das macht Lärm. Nur mit **Leise** geht man langsam und lautlos. |
| **Stillstehen** | Button halten: Zombies sehen dich nicht. Die Zeit (10 s) läuft dabei ab. |
| **Verstecken** | Schrank (1 Platz), Tisch (1 Platz), Bett (2 Plätze). |
| **3 Bisse** | Du wirst selbst zum Zombie. |
| **Sieg** | Der letzte Mensch – oder der Zombie mit den meisten Bissen. |

### Upgrades (erscheinen zufällig, füllen immer die Lebensenergie auf)

* **Knoblauch** – 20 s stinken, Zombies halten Abstand.
* **Souvlaki** – 20 s schneller als jeder Zombie.
* **Wassermelone** – Button halten, Richtung ziehen, loslassen: alle Zombies rennen zur Melone.
* **Olivenöl** – Öl-Button legt eine Pfütze hinter dich. Zombies, die darüberlaufen, rutschen
  aus und liegen 2,5 s am Boden. Eine Pfütze hält 45 s oder drei Ausrutscher.
* **Frappé** – 20 s lang ist „Leise“ schneller als ein verfolgender Zombie, und die
  Stillsteh-Zeit ist wieder voll.

### Als Zombie

Alles erscheint in Rot-Tönen. Menschen sind nur sichtbar, wenn sie sich in Sichtlinie bewegen
(gelb pulsierend) oder Lärm machen (gelbes pulsierendes Oval im Spielfeld und auf der Karte).
Buttons: **Beißen**, **Rennen** (3 s, sobald ein Mensch Lärm gemacht hat) und **Horchen**
(still stehen, alle Menschen erscheinen als gelbes Oval).

## Orte

| Ort | Größe | Besonderheit | Zombies |
|---|---|---|---|
| Wohnung | 22 × 16 m, 6 Zimmer | das ursprüngliche Testlevel | 1 |
| Große Wohnung | 30 × 22 m, 11 Zimmer | zwei Flure mit Rundweg | 2 |
| Taverne | 28 × 18 m | großer Gastraum mit vielen Tischen, Küche, Vorrat | 2 |
| Schule | 34 × 24 m, 14 Räume | Klassenzimmer mit Pulten und Tafel, Spinde im Flur | 2 |

Allein wählst du den Ort nach „Allein spielen“, im Mehrspieler wählt ihn der Gastgeber in
der Lobby. Die Einstellungen stehen in `Cfg.LEVELS` ([`scripts/cfg.gd`](scripts/cfg.gd)).

## Meine Figur

Im Hauptmenü unter **Meine Figur**: Farbe (10), Frisur (7), Haarfarbe (8) und Hut (ohne,
Kappe, Strohhut, Fischermütze, Mütze, Spartaner-Helm, Lorbeerkranz, Krone, Kochmütze).
Die Auswahl wird gespeichert und im Mehrspieler an alle übertragen. Computerspieler bekommen
zufällige Frisuren und manchmal einen Hut. Als Zombie behält man Frisur und Hut.

## Mehrspieler im WLAN (ohne Server)

2 bis 6 Spieler, alle Handys im selben WLAN – oder ein Handy öffnet einen Hotspot und die
anderen wählen sich dort ein. Internet wird nicht gebraucht.

1. Alle tippen im Hauptmenü auf **Mehrspieler (WLAN)** und tragen ihren Namen ein.
2. Einer tippt **Spiel eröffnen** (Gastgeber). Sein Bildschirm zeigt die Adresse an.
3. Die anderen tippen **Spiel suchen** und wählen das gefundene Spiel. Erscheint es nicht
   (manche Netze blocken die Suche), die Adresse des Gastgebers eintippen.
4. Der Gastgeber wählt Ort und Start-Zombie und tippt **Starten**. Freie Plätze übernehmen
   Computerspieler.

**Ein Spieler startet als Zombie:** Ab zwei Spielern wird einer zufällig ausgelost (in der
Lobby auf „Computer“ umstellbar). Er wartet während der 30 Sekunden draußen, sieht schon in
Rot, kann mit **Fenster wechseln** aussuchen, wo er einbricht, und sieht rennende Menschen
als gelbes Oval – leise verstecken lohnt sich also. Auf Orten mit 2 Zombies kommt zusätzlich
ein Computer-Zombie.

Was man wissen sollte:

* Das Handy des Gastgebers rechnet das Spiel; die anderen schicken ihre Eingaben und zeigen an.
* Verlässt ein Mitspieler die Runde, übernimmt der Computer seine Figur.
  Verlässt der Gastgeber die Runde, ist sie für alle vorbei.
* Nach Spielende startet der Gastgeber mit **Nochmal spielen** eine neue Runde für alle.
* Pausieren geht im Mehrspieler nicht.
* In Gäste- oder öffentlichen WLANs sind Geräte oft voneinander abgeschottet – dann den
  Hotspot eines Handys nehmen.
* Technisch kennt jedes Handy alle Positionen; gegen Schummeln ist das nicht abgesichert.

## Steuerung

| Touch | Tastatur (Test am PC) |
|---|---|
| Joystick links | WASD / Pfeiltasten |
| Leise (an/aus) | Umschalt halten |
| Stillstehen (halten) | Leertaste |
| Verstecken / Raus | E |
| Melone (halten, ziehen, loslassen) | F (wirft in Blickrichtung) |
| Öl legen | – |
| Zombie: Beißen / Rennen / Horchen | Leertaste / Umschalt / Q |
| Pause | Esc |

## Testlevel

`Allein spielen` → **Wohnung**: **1 menschlicher Spieler, 3 Computerspieler, 1 Zombie**,
Wohnung 22 × 16 m mit 6 Räumen, jedes Mal neu erzeugt. Level-Einstellungen (`LEVELS`) und
Balancing-Werte stehen in [`scripts/cfg.gd`](scripts/cfg.gd).

## Festlegungen, wo die Vorgabe offen war

* **Sonnenaufgang:** Nach 5 Minuten Jagd endet das Spiel; alle dann noch lebenden Menschen
  gewinnen. Sonst endet es, sobald nur noch ein Mensch übrig ist.
* **Stillstehen:** Das 10-s-Budget erholt sich langsam (0,5 s pro Sekunde); ist es ganz leer,
  ist der Button 3 s gesperrt. Ohne Button ist ein stehender Mensch aus der Nähe (3,5 m)
  noch zu erkennen, schleichend bis 8 m, rennend bis 12 m.
* **Verstecke sind nicht absolut sicher:** Zombies schnüffeln gelegentlich 1,6 s an einem
  Versteck (Warnung im HUD, Herzschlag) und beißen dann zu – rechtzeitig „Raus“ drücken.
  Wer beim Verstecken gesehen wird, wird sofort gesucht.
* **Horchen** zeigt alle Menschen außer denen, die gerade per Button stillstehen.
* **Nach einem Biss** ist der Mensch 3 s unverwundbar (passend zur 3-s-Starre des Zombies).
* KI-Zombies haben ein Blickfeld von 220°, man kann also hinter ihnen vorbeischleichen.

## Projekt öffnen und starten

1. [Godot 4.5.x](https://godotengine.org/download) installieren, `project.godot` importieren.
2. F5 startet das Hauptmenü.

Startparameter für Tests (nach `--`): `--game` (Menü überspringen), `--seed=N`,
`--autoplay` (KI steuert den Spieler), `--as-zombie`, `--fast=N` (Zeitraffer),
`--prep=SEK`, `--match=SEK`, `--shots=ORDNER` (Screenshots), `--debug`.
`--level=0..3` (Ort), `--look=FARBE,FRISUR,HAARFARBE,HUT`, `--overview=METER` (ganzer Ort im Bild).
Netzwerk: `--host=N` (eröffnen, bei N Spielern starten), `--join=ADRESSE` oder `--join=auto`
(Spielsuche), `--name=NAME`, `--zombie-computer`.

## Android-APK bauen

```bash
tools/build_android.sh        # schreibt build/ZombieInAthen-debug.apk
```

Voraussetzungen stehen im Skript (Godot-Export-Templates 4.5.x, Android-SDK mit
build-tools, JDK 17+, Debug-Keystore). Das Export-Preset „Android arm64“ liegt in
`export_presets.cfg` (nur `arm64-v8a`, ohne Gradle, Paket `com.zombieinathen.game`).

## Tests

```bash
xvfb-run -a -s "-screen 0 1280x720x24" tools/run_tests.sh   # Linux ohne Bildschirm
tools/run_tests.sh                                          # mit Bildschirm
```

* `tests/gen_test.gd` – Generator für alle vier Orte über 120–300 Seeds (Erreichbarkeit, Verstecke)
* `tests/items_test.gd` – Olivenöl, Frappé, Ausrutschen, Fensterwechsel des wartenden Zombies
* komplette KI-Matches im Zeitraffer ohne Skriptfehler
* Netzwerkrunde: Gastgeber und zwei Mitspieler als eigene Prozesse auf einem Rechner
  (einer findet das Spiel über die Suche); alle müssen dieselbe Abschlusstabelle melden
* `tests/touch_test.gd` – simulierte Finger: Joystick, Multitouch, Buttons der Menschen, Melonenwurf, Öl

## Aufbau

```
scripts/
  cfg.gd               Balancing-Konstanten
  game_state.gd        Autoload: Level-Konfiguration, Startparameter
  apartment_gen.gd     Grundriss: Flure, Räume je Thema, Wände, Türen, Fenster, Möbel (nur Daten)
  apartment_builder.gd 3D-Aufbau aus Quadern, Licht, Kollision, Verstecke
  mesh_batch.gd        fasst Quader je Raum zu wenigen Meshes zusammen
  nav.gd               A*-Wegfindung und Sichtlinien auf dem Zellraster
  character.gd         Spielfigur (Mensch/Zombie): Bewegung, Zustände, Schritte, Lärm
  char_model.gd        Klötzchen-Figur mit Frisuren, Hüten und prozeduraler Animation
  brain.gd, human_ai.gd, zombie_ai.gd   KI
  hiding_spot.gd, pickup.gd, props.gd   Verstecke, Upgrades, kleine 3D-Objekte
  game.gd              Spielablauf: Phasen, Bisse, Geräusche, Upgrades, Zombie-Sicht, Ende
  hud.gd               Joystick, Buttons, Leben, Timer, Minimap, Ansagen, Endbildschirm
  sfx.gd               Autoload: Soundeffekte, Herzschlag, Musik-Überblendung
  net.gd               Autoload: WLAN-Mehrspieler (ENet, Spielsuche per UDP-Rundruf, RPCs)
  main_menu.gd         Hauptmenü und Mehrspieler-Lobby
shaders/zombie_vision.gdshader   Rot-Sicht (Gelb bleibt erhalten)
tools/gen_audio.py     erzeugt alle Sounds und die Musik
tools/gen_graphics.py  erzeugt Texturen, Icons, Titelbild, App-Icon
```

## Assets und Lizenzen

Alle Grafiken und Sounds sind **selbst erzeugt** und frei von Fremdrechten:

* **3D:** Wohnung, Möbel, Figuren und Upgrades entstehen zur Laufzeit aus Grundformen.
* **2D** (`assets/textures`, `assets/icons`, `assets/ui`): `tools/gen_graphics.py` (Pillow/numpy).
* **Audio** (`assets/audio`): `tools/gen_audio.py` (numpy/scipy, rein synthetisch) –
  Schritte, schlurfende Zombie-Schritte, Glasbruch, Tür, Zombie-Stöhnen/-Schrei/-Biss,
  Upgrades (auch Öl, Ausrutschen, Frappé), Verstecken, Herzschlag, Verwandlung, Jingles sowie zwei nahtlos schleifende
  Musikstücke in D-Hijaz mit Bouzouki-Klang (ruhig und Verfolgung).
* **Schrift:** [Creepster](https://fonts.google.com/specimen/Creepster) von Font Diner,
  SIL Open Font License 1.1 (`assets/fonts/OFL-Creepster.txt`).

## Bekannte Grenzen

* Die APK wurde gebaut und statisch geprüft (arm64-v8a, signiert), aber **noch nicht auf einem
  echten Gerät gestartet**; Performance und Lautstärke-Mix bitte dort prüfen.
* Die Sounds wurden nur messtechnisch geprüft (Pegel, Länge, Schleifenpunkte), nicht abgehört.
* Auf den großen Orten gibt es mehr Lichter und Möbel; wie flüssig sie auf älteren Handys
  laufen, ist ungeprüft.
* Der Mehrspielermodus wurde nur mit mehreren Spielinstanzen auf einem Rechner getestet,
  **nicht in einem echten WLAN zwischen Handys**. Offen sind dort vor allem: funktioniert die
  Spielsuche auf den Geräten, und wie flüssig fühlt sich die eigene Figur an (sie bewegt sich
  erst, wenn der Gastgeber geantwortet hat).
* Mehrspieler nur im lokalen Netz, nicht über das Internet. Später beitreten geht nicht.
* Netzwerk-Port: UDP 24642 (Spiel) und 24643 (Suche).

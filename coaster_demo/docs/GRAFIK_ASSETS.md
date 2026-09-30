# Coaster Demo – Grafik-Asset-Beschreibung

Dieses Dokument beschreibt alle Grafiken, die die heutigen grauen Platzhalter
(Greybox) ersetzen sollen. Es ist so geschrieben, dass du es direkt an ein
3D-/Bild-Generierungswerkzeug oder eine Grafikerin weitergeben kannst. Jede
Asset-Beschreibung enthält Maße, Ausrichtung, Budget und einen englischen
Prompt als Vorlage für KI-Generatoren.

---

## 1. Technische Rahmenbedingungen

| Punkt | Vorgabe |
|---|---|
| Engine | Godot 4.3, Renderer „GL Compatibility“ (OpenGL ES 3.0) |
| Zielgeräte | Android arm64; Minimum Samsung Galaxy Tab S6, Ziel 60 fps |
| 3D-Format | **glTF 2.0 binär (`.glb`)**, eine Datei pro Asset |
| Einheiten | **1 Einheit = 1 Meter** |
| Achsen | **Y nach oben, −Z = vorne** (Fahrtrichtung), +X = rechts |
| Materialien | PBR Metallic/Roughness; möglichst **1 Material pro Asset** |
| Texturen | PNG, Kantenlänge Zweierpotenz, **max. 1024 px** (Umgebung 512 px reicht meist) |
| Atlas | Kleine Props teilen sich bevorzugt **eine** Atlas-Textur |
| Transparenz | Nur Wasser, Glas und Blätter (Alpha-Scissor statt Alpha-Blend wo möglich) |
| Normal-Maps | Optional, nur wo sie viel bringen (Schienen, Stationsdach) |
| Schatten | Objekte sollen mit einer einzigen Richtungslicht-Schattenquelle gut aussehen |
| Draw Calls | Heute 100–220 pro Frame; neue Assets sollen das nicht deutlich erhöhen |

**Polygon-Budgets (Dreiecke):**

| Kategorie | Budget |
|---|---|
| Zugwagen | 1.500–3.000 pro Wagen |
| Fahrgast | 300–600 (inkl. Arme) |
| Station | 3.000–6.000 |
| Baum | 150–600 |
| Kleine Props (Bank, Laterne, Zaun) | 50–300 |
| Schwelle / Stützenteil | 12–80 (werden hundertfach instanziert) |

---

## 2. Stil-Leitfaden

- **Stil:** „stylized low-poly“, freundlich und aufgeräumt, leicht spielzeughaft,
  klare Silhouetten. Keine fotorealistischen Texturen und kein Schmutz. Sanfte
  Farbverläufe oder einfarbige Flächen mit dezenter Kantenbetonung.
- **Lesbarkeit von oben:** Das Spiel wird meist in isometrischer Ansicht
  (≈ 35° von oben) gebaut. Alles muss auch klein und von schräg oben klar
  erkennbar sein. Dächer und Oberseiten sind wichtiger als Unterseiten.
- **Beleuchtung:** Sonnenlicht von schräg oben, dazu weiches Umgebungslicht.
  Keine eingebackenen Schatten in die Texturen, höchstens leichtes Ambient Occlusion.
- **Farbpalette** (Vorschlag, kann angepasst werden):

| Rolle | Farbe | Hex |
|---|---|---|
| Himmel | Hellblau | `#9ECCF5` |
| Gras außerhalb des Baufelds | Sattes Grasgrün | `#54A03D` |
| Baufeld (Pflaster) | Warmes Hellgrau | `#B9B4AA` |
| Schienen | Signalrot | `#D8433A` |
| Schienen (alternativ) | Sonnengelb | `#F2B632` |
| Stützen | Weiß-Grau | `#E6E6E3` |
| Zug Hauptfarbe | Königsblau | `#2F5DB8` |
| Zug Akzent | Weiß / Chrom | `#F2F2F2` |
| Booster | Orange | `#F5A142` |
| Bremse | Rot | `#E0574A` |
| Wasser | Türkisblau | `#4FA6E8` |
| UI-Grün (Aktion) | Grün | `#4CB25E` |

---

## 3. Spielwelt und Maße

- Das Baufeld ist ein Raster aus **24 × 24 Zellen**, jede Zelle ist **4 × 4 m**
  groß (gesamt 96 × 96 m).
- Eine **Höhenstufe** ist **2 m** hoch; die Strecke kann bis 8 Stufen (16 m)
  hoch gebaut werden, Inversionen ragen bis 22 m.
- Die Station steht fest auf den Zellen (6,12)–(8,12), also 12 m lang in Richtung +X.
- **Die Schienen werden im Spiel prozedural entlang der Fahrlinie erzeugt.**
  Für die Strecke werden deshalb keine fertigen Kurven-Modelle gebraucht,
  sondern **Querschnitte (Profile), kachelbare Texturen und kleine
  Einzelteile**, die das Spiel entlang der Strecke verteilt (siehe 4.1).

### Referenzmaße der Fahrlinie (lokales Koordinatensystem der Schiene)

```
   x = -0.55 m              x = 0               x = +0.55 m
       (O)------------------+------------------(O)     Laufschienen Ø 0,12 m, y = +0,15 m
        \_______ Schwelle 1,4 m breit, y ≈ 0,05 m ______/
                          [###]                         Rückenrohr 0,3 × 0,3 m, y = -0,15 m

   y = 0 ist die Fahrlinie; +y ist die Schienen-Normale (zeigt im Looping nach innen)
```

---

## 4. Asset-Liste

### 4.1 Strecke

#### 4.1.1 Schienenprofil – `track_profile.svg` oder als Maßangabe
- **Was:** 2D-Querschnitt, den das Spiel entlang der Strecke extrudiert:
  zwei runde Laufschienen (Ø 0,12 m bei x = ±0,55 m, y = +0,15 m) und ein
  Rückenrohr (Ø 0,3 m oder eckig 0,3 × 0,3 m bei y = −0,15 m).
- **Lieferung:** Maßzeichnung oder Liste von 2D-Punkten, 8–12 Punkte pro Rohr.
- **Material:** `track_rail.png` – kachelbare Metalltextur, 256 × 256 px,
  lackiert in der Schienenfarbe, leichter Glanz, feine Schweißnähte alle ~1 m.
- **Prompt:** *“Seamless tileable texture of glossy painted red steel roller coaster tube, subtle weld seams, clean stylized look, 256x256, no dirt.”*

#### 4.1.2 Schwelle – `track_tie.glb`
- **Maße:** 1,4 m breit (x), 0,08 m hoch (y), 0,25 m tief (z); Pivot in der Mitte.
- **Einsatz:** alle 0,8 m entlang der Strecke, an der Schienen-Normale ausgerichtet.
- **Budget:** ≤ 40 Dreiecke, nutzt die Stützen-/Schienentextur.
- **Aussehen:** flacher Stahlträger, der beide Schienen mit dem Rückenrohr verbindet (von der Seite leichtes „Y“ oder „U“).
- **Prompt:** *“Low-poly steel crosstie connecting two roller coaster rails to a central spine tube, stylized, game asset.”*

#### 4.1.3 Stütze – `support_foot.glb`, `support_shaft.glb`, `support_cap.glb`
- **Warum 3 Teile:** Stützen werden im Spiel in der Höhe gestreckt (0,3 m bis ~16 m).
  Der Schaft darf sich strecken, Fuß und Kopf nicht.
- **Fuß:** Betonsockel, 0,8 × 0,3 × 0,8 m, Pivot unten Mitte.
- **Schaft:** Rundrohr Ø 0,3 m, **genau 1 m hoch**, in Y kachelbar (UV in Y 0→1), Pivot unten.
- **Kopf:** Gabel/Sattel, der das Rückenrohr trägt, 0,6 × 0,4 × 0,4 m, Pivot unten.
- **Farbe:** Weiß-Grau, Fuß betongrau.
- **Prompt:** *“Modular roller coaster support column kit: concrete footing, 1 m tileable steel tube segment, saddle-shaped top bracket; stylized low-poly, white-grey paint.”*

#### 4.1.4 Kettenlift – `lift_chain.png`
- **Was:** Kettenstreifen zwischen den Schienen auf „Hoch“-/„Steil hoch“-Teilen.
- **Lieferung:** kachelbare Textur 64 × 256 px (Kette in Längsrichtung), wird im Spiel per UV animiert.
- **Prompt:** *“Seamless vertical strip texture of a roller coaster lift chain, dark steel links, stylized, 64x256.”*

#### 4.1.5 Booster – `booster_fin.glb`
- **Was:** Linearmotor-Flosse bzw. Antriebsrad-Paar zwischen den Schienen; 5 Stück pro 4-m-Teil.
- **Maße:** 0,18 m breit, 0,25 m hoch, 0,5 m lang; Pivot unten Mitte.
- **Farbe:** Orange mit dunklem Metall, optional leicht leuchtende Kante (Emission).
- **Prompt:** *“Small low-poly linear induction motor fin for a launch coaster, orange and dark steel, glowing edge, game asset.”*

#### 4.1.6 Bremse – `brake_fin.glb`
- **Was:** Bremsschwert; 2 Reihen × 4 Stück pro 4-m-Teil (x = ±0,25 m).
- **Maße:** 0,06 m dick, 0,3 m hoch, 0,8 m lang; Pivot unten Mitte.
- **Farbe:** Rot mit Kupfer-/Messing-Belag.
- **Prompt:** *“Low-poly roller coaster magnetic brake fin, red metal with copper plates, stylized game asset.”*

#### 4.1.7 Tunnel – `tunnel_segment.glb`, `tunnel_portal.glb`
- **Segment:** 4 m lang (z), innen 3,5 m breit und 3,3 m hoch, Außenmaß ca. 5,5 × 4,5 m;
  oben begrünter Erdhügel. Muss sich nahtlos aneinanderreihen lassen.
- **Portal:** Eingangsfassade (Steinbogen oder Holzportal) für Anfang und Ende,
  0,5 m tief, gleicher Innenquerschnitt.
- **Pivot:** Mitte der Fahrlinie am Boden, −Z = Fahrtrichtung.
- **Prompt:** *“Stylized low-poly tunnel segment for a roller coaster, 4 m long, grassy mound on top, stone arch portal variant, tileable ends, game asset.”*

#### 4.1.8 Wasser-Splash – `splash_pool.glb`, `water.png`, `splash_drop.png`
- **Becken:** 5 × 4 m, Beckenrand 0,3 m breit und 0,6 m hoch, Wasserspiegel 0,2 m über der Fahrlinie.
- **Wasser:** eigenes Material, halbtransparent türkis, animierbare Normal-Map `water_normal.png` 256 × 256.
- **Tropfen:** Partikel-Sprite `splash_drop.png` 64 × 64 px, weiß-blau, weicher Rand, Alpha.
- **Prompt:** *“Stylized low-poly water splash pool for a roller coaster, 5x4 m, stone rim, turquoise translucent water.”*

#### 4.1.9 Station – `station.glb`
- **Maße:** Bahnsteig 12 m lang (x), 2 m breit, 0,5 m hoch, liegt auf der −Z-Seite
  neben dem Gleis. Das Dach überspannt Gleis und Bahnsteig (ca. 12 × 3,5 m, Traufhöhe 3,2 m).
- **Details:** Eingangstor mit Schild „COASTER“, Warteschlangen-Geländer, Drehkreuz,
  kleines Bedienerhäuschen, Dachstützen. Der Gleisbereich bleibt frei (1,6 m breit, 2,5 m hoch).
- **Pivot:** Mitte des Stationsgleises auf Fahrlinienhöhe (y = 0), −Z zeigt zum Bahnsteig.
- **Prompt:** *“Stylized low-poly amusement park roller coaster station, 12 m long platform, colorful canopy roof, queue railings, entrance arch with sign, friendly toy-like style.”*

### 4.2 Zug

#### 4.2.1 Wagen – `car_front.glb`, `car_middle.glb`
- **Maße:** 2,3 m lang (z), 1,5 m breit (x), Wanne 0,5 m hoch; Oberkante der Seitenwand ~1,1 m.
- **Pivot:** auf der Fahrlinie (Schienenmitte, y = 0) in der Wagenmitte. **−Z = vorne.**
- **Fahrgestell:** Radgestelle bei z = ±0,9 m unter der Wanne (Räder umgreifen die Schienen bei x = ±0,55 m).
- **Sitze:** 2 Reihen (z = −0,45 m vorne, z = +0,6 m hinten), je 2 Plätze (x = ±0,36 m).
  Sitzfläche auf y ≈ 0,75 m, Lehnen bis max. 1,2 m (sonst verdecken sie die Sicht in der Ego-Perspektive).
- **Bügel:** Schoßbügel je Sitz, optional als eigenes Mesh (`lap_bar.glb`), Drehpunkt vorne an der Sitzkante.
- **Frontwagen:** zusätzliche Nase/Bugverkleidung bis z = −1,55 m, **max. 0,9 m hoch** (Sicht nach vorn!).
  Optional Scheinwerfer oder Gesicht/Logo.
- **Mittelwagen:** vorne Kupplung (0,3 × 0,2 × 0,5 m bei z = −1,3 m).
- **Wagenabstand im Zug:** 2,7 m (Mitte zu Mitte).
- **Budget:** 1.500–3.000 Dreiecke, 1 Material, Textur 512 × 512.
- **Prompt:** *“Stylized low-poly roller coaster car, 2 rows of 2 seats, royal blue with white stripes, chrome lap bars, visible wheel bogies, front car with rounded nose, game asset, -Z forward.”*

#### 4.2.2 Fahrgäste – `rider_01.glb` … `rider_06.glb`
- **Haltung:** sitzend, Hände am Bügel.
- **Maße:** Hüfte (Pivot) auf Sitzhöhe; Oberkörper ~0,5 m, Kopf-Oberkante ~0,95 m über dem Pivot
  (Augenhöhe im Wagen gesamt ≈ 1,7 m über der Fahrlinie).
- **Arme:** separates Mesh oder 2 Knochen mit **Drehpunkt an der Schulter 0,6 m über dem Pivot**.
  Das Spiel dreht die Arme um die X-Achse von 60° (am Bügel) bis 165° (hochgerissen).
- **Varianten:** 6 Personen (verschiedene Haar- und Kleidungsfarben, Kinder/Erwachsene über Skalierung 0,85–1,0).
- **Mimik:** optional 2 Gesichts-Texturen (normal / jubelnd), wird bei hochgerissenen Armen umgeschaltet.
- **Budget:** 300–600 Dreiecke, gemeinsamer Atlas 512 × 512 für alle Varianten.
- **Prompt:** *“Stylized low-poly seated amusement park rider, arms as separate mesh pivoting at shoulders, cheerful cartoon face, 6 color variants sharing one texture atlas, game asset.”*

### 4.3 Umgebung

#### 4.3.1 Boden
- **Baufeld:** `ground_plaza.png`, kachelbar, 512 × 512 px = **eine 4-m-Zelle**, helles Pflaster
  mit sehr dezenter Fugenlinie am Zellrand (das Raster muss erkennbar, aber ruhig sein).
- **Umland:** `ground_grass.png`, kachelbar, 512 × 512 px für ca. 8 × 8 m, sattes Grasgrün mit leichter Variation.
- **Übergang:** optional `ground_edge.png` (Bordstein), 512 × 128 px, kachelbar.
- **Prompt:** *“Seamless stylized paving stone texture, light warm grey, subtle grid seams at the edges, 512x512, top-down.”* / *“Seamless stylized lush grass texture, top-down, 512x512.”*

#### 4.3.2 Himmel – `sky_panorama.png`
- Equirektangular 2048 × 1024 px, hellblau mit ein paar weichen Kumuluswolken,
  Horizont leicht aufgehellt, keine Sonne eingemalt (die Sonne kommt vom Licht).
- **Prompt:** *“Equirectangular 2:1 stylized sky panorama, light blue, soft fluffy cumulus clouds, bright horizon, no sun disk.”*

#### 4.3.3 Bäume und Pflanzen – `tree_round_01..03.glb`, `tree_pine_01..02.glb`, `bush_01..02.glb`
- **Höhen:** Laubbäume 4–7 m, Nadelbäume 5–8 m, Büsche 0,8–1,5 m. Pivot unten Mitte.
- **Budget:** 150–600 Dreiecke, alle Pflanzen teilen einen Atlas 512 × 512.
- **Prompt:** *“Stylized low-poly trees set for a theme park: round deciduous and pine trees, soft gradient colors, shared texture atlas.”*

#### 4.3.4 Park-Props – `bench.glb`, `lamp.glb`, `fence_2m.glb`, `kiosk.glb`, `balloon_stand.glb`, `rock_01..03.glb`
- **Maße:** Bank 1,6 m; Laterne 3 m; Zaunelement **2 m** (kachelbar); Kiosk 3 × 3 m; Felsen 0,5–2 m.
- Werden rund um das Baufeld verteilt (außerhalb der 96 × 96 m).
- **Budget:** 50–600 Dreiecke, gemeinsamer Atlas.
- **Prompt:** *“Stylized low-poly theme park props: bench, street lamp, 2 m fence section, ice cream kiosk, balloon stand, rocks; bright friendly colors, shared atlas.”*

### 4.4 Effekte
- `splash_drop.png` – siehe 4.1.8.
- `spark.png` – 32 × 32 px, gelb-weißer Funke für Bremsen (optional).
- `dust_puff.png` – 64 × 64 px, weiche Wolke für das Setzen von Streckenteilen (optional).

### 4.5 Bedienoberfläche

#### 4.5.1 Icons – `icons/*.svg`
- **Format:** SVG, Zeichenfläche **96 × 96**, weiße Linien (`#F2F2F2`), Strichstärke 7,
  runde Enden. Akzentfarben: Grün `#9FD29A`, Orange `#F5A142`, Rot `#E0574A`, Blau `#6FB2F0`.
  Die Icons liegen auf dunkelgrauen, abgerundeten Buttons.
- **Die Dateinamen müssen gleich bleiben** – dann ersetzt eine neue Datei das alte Icon ohne Code-Änderung.

| Datei | Bedeutung |
|---|---|
| `straight.svg` | Gerade |
| `left.svg`, `right.svg` | Kurve links/rechts |
| `bank_left.svg`, `bank_right.svg` | Schrägkurve links/rechts |
| `wide_left.svg`, `wide_right.svg` | Weite Kurve links/rechts |
| `up.svg`, `down.svg` | Hoch / Runter |
| `steep_up.svg`, `steep_down.svg` | Steile Auffahrt / Abfahrt |
| `loop.svg` | Looping |
| `corkscrew.svg` | Korkenzieher |
| `booster.svg`, `brake.svg` | Booster / Bremse |
| `tunnel.svg`, `splash.svg` | Tunnel / Wasser-Splash |
| `cat_turns.svg`, `cat_height.svg`, `cat_special.svg` | Kategorie-Reiter Kurven / Höhe / Spezial |
| `undo.svg` | Zurücknehmen |
| `play.svg` | Fahren (dunkel auf grünem Rund-Button) |
| `stop.svg`, `view.svg` | Fahrt beenden / Kamera wechseln |
| `demo.svg` | Demo-Strecke |
| `new.svg` | Neue Strecke / Löschen |
| `save.svg`, `load.svg` | Speichern / Laden |
| `sound_on.svg`, `sound_off.svg` | Ton an/aus |
| `close.svg` | Schließen |
| `continue.svg`, `plus.svg`, `help.svg` | Startbildschirm: Weiterbauen / Neue Strecke / Tutorial |

#### 4.5.2 App-Icon – `icon.svg` bzw. PNGs
- `icon.svg` 128 × 128 (wird im Spiel als Logo verwendet).
- Android: `icon_512.png` (512 × 512), adaptives Icon `icon_foreground.png` und
  `icon_background.png` (je 432 × 432, Motiv im inneren 66-%-Kreis).
- **Motiv:** stilisierte Achterbahn-Silhouette mit Looping und kleinem Zug, Himmelblau-Hintergrund.
- **Prompt:** *“App icon, stylized roller coaster silhouette with a loop and a tiny blue train, light blue sky background, bold simple shapes, flat design.”*

#### 4.5.3 Titel-Logo – `title_logo.png`
- 1024 × 320 px, transparenter Hintergrund, Schriftzug **„COASTER DEMO“**
  (oder späterer Spielname) in dicker, runder Schrift, eine Schiene schwingt durch die Buchstaben.
- Wird auf dem Startbildschirm über dem Menü auf dunklem Panel angezeigt → helle Farben.
- **Prompt:** *“Game title logo ‘COASTER DEMO’, bold rounded letters, a red roller coaster track swooping through the text with a small loop, transparent background, playful, high contrast for dark UI.”*

#### 4.5.4 Schrift (optional)
- Empfehlung: eine runde, gut lesbare Schrift mit freier Lizenz (OFL), z. B.
  **Nunito** oder **Baloo 2**, als `.ttf`, inkl. deutscher Umlaute.

---

## 5. Liefer-Struktur

```
coaster_demo/
├── assets/
│   ├── models/        *.glb   (track_tie, support_*, station, car_*, rider_*, tree_*, …)
│   ├── textures/      *.png   (track_rail, lift_chain, ground_*, water*, sky_panorama, atlanten)
│   └── fx/            *.png   (splash_drop, spark, dust_puff)
├── icons/             *.svg   (gleiche Namen wie heute → ersetzen)
├── icon.svg / title_logo.png
└── fonts/             *.ttf
```

## 6. Checkliste pro Asset

- [ ] Maße in Metern wie angegeben, Pivot an der beschriebenen Stelle
- [ ] Y oben, −Z vorne, Transformationen „applied“ (Skalierung 1, keine Rotation)
- [ ] Budget eingehalten, ein Material (oder gemeinsamer Atlas)
- [ ] Texturen als PNG, Zweierpotenz, ≤ 1024 px
- [ ] In isometrischer Ansicht von oben klar lesbar
- [ ] Dateiname wie in dieser Liste

## 7. Hinweise für die spätere Einbindung (Code-Stellen)

| Asset | Wird heute erzeugt in |
|---|---|
| Schienen, Schwellen, Stützen | `scripts/track.gd` → `_build_rails()`, `_build_ties_and_supports()` |
| Station | `scripts/track.gd` → `_build_station()` |
| Booster, Bremse, Tunnel, Splash | `scripts/track.gd` → `_build_special_deco()` |
| Zug, Fahrgäste | `scripts/train.gd` |
| Boden, Himmel, Umgebung | `scripts/main.gd` → `_setup_world()` |
| Wasser-Partikel | `scripts/main.gd` → `_splash()` |
| Icons, Logo | `icons/`, `icon.svg`, `scripts/title_screen.gd` |

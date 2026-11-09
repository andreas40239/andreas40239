# Tiefenherr

Ein Dungeon-Management-Spiel für **Windows 11**, gebaut mit **Godot 4.3** (Forward+/Vulkan).
Grabe dich durch den Fels, baue Räume, locke Kreaturen an und verteidige dein Dungeon-Herz gegen sechs Heldenwellen.

Alle Grafiken (Texturen, Modelle, Licht- und Partikeleffekte) und alle Sounds (Effekte, Ambient-Musik, dynamische Kampftrommeln) werden **prozedural zur Laufzeit erzeugt**. Es werden keine externen Assets benötigt.

## Spielen

**Variante A – fertige .exe (empfohlen):**
Bei jedem Push baut GitHub Actions automatisch einen Windows-Build.
Im Repository unter **Actions → „Tiefenherr Windows-Build“ → neuester Lauf → Artifacts → `Tiefenherr-Windows`** herunterladen, entpacken und `Tiefenherr.exe` starten.

**Variante B – im Godot-Editor:**
1. [Godot 4.3 (Standard, nicht .NET)](https://godotengine.org/download/archive/4.3-stable/) für Windows herunterladen.
2. Godot starten → *Importieren* → `tiefenherr/project.godot` wählen → **F5**.
3. Eigener Export: *Projekt → Exportieren → Windows Desktop* (Export-Vorlagen über *Editor → Export-Vorlagen verwalten* installieren).

## Steuerung

| Aktion | Eingabe |
|---|---|
| Kamera bewegen | WASD / Pfeiltasten / Bildschirmrand (Shift = schneller) |
| Zoomen | Mausrad (zoomt zum Mauszeiger) |
| Drehen / Neigen | Q / E oder mittlere Maustaste gedrückt ziehen |
| Zum Dungeon-Herz | Leertaste oder H |
| Kreaturen auswählen | Linksklick / Rahmen ziehen (Shift = hinzufügen, Strg+A = alle) |
| Bewegen / Angreifen | Rechtsklick auf Boden bzw. Feind (auch auf der Minimap) |
| Graben markieren | Fels mit Linksklick ziehen (oder Werkzeug **F**); Start auf Markierung oder Shift entfernt |
| Räume bauen | **1** Schatzkammer · **2** Hort · **3** Pilzfarm · **4** Übungsraum, dann Fläche ziehen |
| Räume verkaufen | **X** |
| Zauber | **C** Wichtel beschwören · **V** Blitzschlag · **B** Heilwelle |
| Werkzeug abbrechen | Rechtsklick oder Esc |
| Taktische Pause | **P** (Befehle und Bauen bleiben möglich) |
| Spieltempo | **+ / -** (1x, 2x, 3x) |
| Nächste Welle sofort | **N** |
| Hilfe / Menü | **F1** / **Esc** |

## Spielablauf

1. **Graben:** Grubenwichtel bauen markierte Felsen ab, liefern Gold (Goldadern, unerschöpfliche Edelsteine) ins Herz bzw. die Schatzkammer, beanspruchen Boden und befestigen Wände.
2. **Portal:** Grabe einen Tunnel zum lila Portal. Sobald angrenzender Boden beansprucht ist, gehört es dir.
3. **Kreaturen anlocken:**
   - Hort + Pilzfarm → *Moderwurm*
   - Hort ≥ 4 Felder → *Nachtmahr*
   - Übungsraum ≥ 4 Felder → *Glutkobold* (Fernkampf)
   - Übungsraum ≥ 9 + Schatzkammer ≥ 9 → *Hornbestie*
4. **Versorgen:** Kreaturen schlafen im Hort (1 Platz pro Feld), essen in der Pilzfarm, trainieren im Übungsraum (kostet Gold) und wollen alle 3 Minuten ihren Lohn. Unzufriedene Kreaturen gehen.
5. **Verteidigen:** Helden (Ritter, Bogenschützinnen, heilende Priester, Zwergengräber) kommen aus dem hellen Tor und graben sich notfalls durch den Fels. Befestigte Wände halten sie deutlich länger auf. Überstehe 6 Wellen.

## Optionen

Lautstärke (Gesamt, Musik, Effekte), Vollbild, Randscrollen und Grafikqualität:

- **Niedrig:** ohne SSAO und Schatten
- **Mittel:** SSAO, Schatten, 2x MSAA
- **Hoch:** zusätzlich volumetrischer Nebel, 4x MSAA
- **Ultra:** zusätzlich SSIL und TAA

Für eine aktuelle Ryzen-CPU mit Radeon-Grafik ist **Hoch** voreingestellt. Einstellungen werden in `%APPDATA%\Godot\app_userdata\Tiefenherr\settings.cfg` gespeichert.

## Projektstruktur

```
tiefenherr/
├── project.godot          Projekt (Forward+, Autoload Sfx)
├── export_presets.cfg     Windows-Exportvorlage (x86_64)
├── scenes/main.tscn
└── scripts/
    ├── main.gd            Spiellogik, Eingabe, Jobs, Wirtschaft, Wellen, Zauber, Optionen
    ├── world.gd           Karte, Pfadfindung (A*), prozedurale Texturen, Beleuchtung, Effekte
    ├── unit.gd            KI für Wichtel, Kreaturen und Helden
    ├── models.gd          prozedurale 3D-Modelle, Lebensbalken-Shader
    ├── projectile.gd      Geschosse
    ├── camera_rig.gd      RTS-Kamera
    ├── hud.gd             Oberfläche, Minimap, Menüs
    ├── sfx.gd             Audiosynthese (SFX, Musik, Hall, Kompressor)
    └── defs.gd            Spielwerte und Tabellen
```

Automatischer Test ohne Grafik (simuliert ein Spiel im Zeitraffer):
`godot --headless --path tiefenherr --fixed-fps 60 -- --autotest`

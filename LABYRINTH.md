# 🏰 Labyrinth-Abenteuer

Ein Prototyp als **einzelne HTML-Datei**: [`labyrinth-abenteuer.html`](labyrinth-abenteuer.html).
Keine Installation, kein Server, keine Internetverbindung nötig — die Datei enthält alles.

## Auf dem Android-Tablet testen

Die Datei auf das Tablet kopieren (USB, Cloud, E-Mail an sich selbst) und mit Chrome öffnen.
Am besten über das Chrome-Menü **„Zum Startbildschirm hinzufügen"** ablegen: dann startet das
Spiel ohne Adressleiste im Vollbild.

Am PC genügt ein Doppelklick auf die Datei. Dort funktionieren zusätzlich die Pfeiltasten
bzw. `W A S D` zum Laufen, `Leertaste` für das Schwert und `M` für Magie.

## Spielprinzip

Finde in jedem Labyrinth die Tür 🚪. Zu Beginn ist alles dunkel; die Gänge werden sichtbar,
sobald du in ihre Nähe kommst. Der Umriss des Spielfelds ist von Anfang an angedeutet, damit
du die Größe des Levels einschätzen kannst.

- **Steuerkreuz** — antippen für einen Schritt, gedrückt halten, um weiterzulaufen.
- **⚔️ Schwert** — trifft alle Monster auf den vier Nachbarfeldern. Man kann auch einfach in
  ein Monster hineinlaufen, das löst denselben Angriff aus.
- **✨ Magie** — trifft alle entdeckten Monster im Umkreis von 3 Feldern und macht knapp
  doppelten Schaden. Kostet 10 Mana, das sich langsam von selbst wieder auflädt.
- **❤️ Herzen** — erscheinen zufällig auf bereits aufgedeckten Feldern und heilen 30 % der
  maximalen Lebenspunkte.

## Levels

| Labyrinth-Level | Größe | Besonderheit |
|---|---|---|
| 1–5 | fest, passt komplett auf den Bildschirm | Monster stehen still |
| ab 5 | — | entdeckte Monster bewegen sich und verfolgen dich |
| ab 6 | wächst pro Level weiter | die Kamera folgt der Figur |

Monster werden pro Level zahlreicher, zäher und stärker: Spinne 🕷️, Fledermaus 🦇,
Schlange 🐍, Geist 👻, Oger 👹 und schließlich Drache 🐉.

Im Hochformat wird das Labyrinth mitgedreht, damit es den Bildschirm gut ausfüllt.

## Heldenstufen und Sterne

Besiegte Monster und geschaffte Level geben Erfahrungspunkte. Jede Heldenstufe bringt
**2 Sterne ⭐**, die über den Stern-Knopf oben rechts verteilt werden:

| Eigenschaft | Wirkung pro Stern |
|---|---|
| ❤️ Lebenspunkte | +10 maximale Lebenspunkte |
| ⚔️ Angriffsschaden | +2 Schaden pro Treffer |
| 🔮 Mana | +10 maximales Mana |
| 🛡️ Rüstung | −1 erlittener Schaden pro Treffer |

Solange noch Sterne offen sind, pulsiert der Knopf und zeigt ihre Anzahl an.
Während das Fenster offen ist, pausiert das Spiel.

## Bekannte Grenzen des Prototyps

- Der Spielstand wird **nicht gespeichert** — beim Neuladen der Seite beginnt alles von vorn.
- Nach einer Niederlage wird dasselbe Labyrinth neu erzeugt; Heldenstufe und Sterne bleiben erhalten.
- Grafik und Ton sind bewusst minimal (Emojis und kurze Töne), damit die Datei allein lauffähig bleibt.

# Design-Dokument: "Eidechsen-Spiel" (Arbeitstitel)

**Plattform:** Android (Mobile)
**Engine:** Godot 4.x
**Ausrichtung:** Landscape (Querformat)
**Zielgruppe:** Familienprojekt (Vater & Sohn), kindgerecht
**Monetarisierung:** Keine (kostenlos, keine Werbung, keine In-App-Käufe)

---

## 1. Spielkonzept

Der Spieler steuert eine kleine Eidechse an einem Sandstrand. Ziel ist es, Insekten zu fressen,
zu wachsen, sich dabei vor Fressfeinden (Vögeln und größeren Tieren) in Sicherheit zu bringen
und im Verlauf des Spiels von einer winzigen, verletzlichen Eidechse zu einem großen,
gepanzerten/geflügelten Tier zu werden, das selbst zur Gefahr für andere wird.

**Kern-Fantasie:** "Vom Gejagten zum Jäger" – Wachstum durch Vorsicht und Geschicklichkeit.

---

## 2. Spielmodi

1. **Story-Modus:** Feste Abfolge von 10+ Wachstumsstufen (Leveln) mit ansteigender
   Schwierigkeit, neuen Gegnertypen, wachsender Karte und visuellen Veränderungen der Eidechse.
2. **Endlos-Modus:** Nach Abschluss des Story-Modus schaltet sich ein Endlos-Modus frei
   (Highscore-Prinzip), in dem Wachstum, Kartengröße und Gegnerdichte unbegrenzt weiter skalieren.

---

## 3. Core Loop

1. Eidechse läuft über den Sand, sucht Insekten.
2. Insekten werden durch Drüberlaufen gefressen → Sättigungsanzeige steigt.
3. Vögel und gefährliche Tiere patrouillieren sichtbar auf der Karte – Spieler muss ausweichen
   oder sich rechtzeitig verstecken.
4. Ist die Eidechse satt genug, kehrt sie zum Bau zurück, legt sich kurz hin und wächst
   (Level-Up): neue Größe, neue Farbe, ab bestimmten Leveln Stacheln oder kleine Flügel.
5. Mit jedem Level-Up wächst die Karte um einen weiteren Bereich.
6. Wiederholung mit steigender Schwierigkeit, bis Story-Modus abgeschlossen ist → Endlos-Modus.

**Game Over:** Wird die Eidechse gefressen, wird sie zurück in den Bau versetzt. Kein
Levelverlust, kein Fortschrittsverlust – nur ein Rückschlag im aktuellen Streckenabschnitt
(Frustfreiheit für junge Spieler).

---

## 4. Steuerung

- **Dynamisches Touch-Pad:** Kein fest positionierter Joystick. Bei jeder neuen Berührung des
  Displays wird die Berührungsposition als neuer Mittelpunkt/Offset für die Steuerung
  festgelegt. Bewegung des Fingers relativ zu diesem Punkt steuert Richtung (hoch/runter/
  links/rechts, vermutlich als normalisierter 2D-Vektor für analoge Bewegung).
- Keine weiteren Steuerelemente nötig (Fressen = Drüberlaufen, kein separater Button).

---

## 5. Wachstum & Progression

- **10+ kleine Wachstumsstufen** im Story-Modus für feine Progression.
- Jede Stufe verändert sichtbar:
  - Größe der Eidechse
  - Farbgebung/Muster
  - Ab mittleren/höheren Leveln: Stacheln oder kleine Flügel als visuelles Merkmal
- Level-Up-Trigger: Ausreichend Sättigung erreicht **und** Rückkehr zum Bau.
- Mit jedem Level-Up wächst die begehbare Kartenfläche um einen neuen Bereich.

*Offene Frage für die Umsetzung: Genaue Sättigungs-Schwellenwerte pro Level sowie exakte
visuelle Abstufungen (Konzeptkunst) werden im Zuge der Asset-Erstellung festgelegt.*

---

## 6. Gegner & Fressregeln

Große Vielfalt an Tieren/Insekten von Beginn an gewünscht. Vorschlag für Kategorien:

| Kategorie | Beispiele | Verhalten | Fressregel |
|---|---|---|---|
| Beute-Insekten | Ameisen, Käfer, Grillen, Spinnen | Bewegen sich zufällig/fliehend | Werden von der Eidechse ab Level 1 gefressen (Drüberlaufen) |
| Gleichrangige Tiere | Andere Eidechsen, Krabben | Patrouillieren, meiden sich ggf. gegenseitig | Nur fressbar, wenn Eidechsen-Level höher als Gegner-Level |
| Vögel | Möwen, kleine Strandvögel | Patrouillieren sichtbar, ggf. Sturzflug-Angriff | **Immer gefährlich**, unabhängig vom Level (bis auf evtl. Ausnahme auf sehr hohen Leveln, offen) |
| Sonstige Gefahren | z. B. Krebse mit Scheren, nachtaktive Tiere | Patrouillieren, ggf. nur nachts aktiv | **Immer gefährlich**, unabhängig vom Level |

**Grundregel:** Höheres Level frisst niedrigeres Level – mit Ausnahme fest definierter,
immer gefährlicher Tiere (z. B. Vögel), die unabhängig von der Levelstufe eine Bedrohung
bleiben.

*Offene Frage: Exakte Liste und Anzahl der Tierarten (Ziel: „große Vielfalt“) wird in einer
separaten Content-Liste vor Produktionsbeginn festgelegt, damit Claude Code eine klare
Datenbasis (z. B. als Godot-Resource/JSON) erhält.*

---

## 7. Karte

- Startet klein, wächst gekoppelt an Spieler-Level (bei jedem Level-Up neuer Kartenbereich).
- Enthält: offene Sandflächen, Sträucher (mit Frucht-Powerups), Verstecke/Bau, variierendes
  Gelände für spätere Levelabschnitte (Ziel: visuelle Abwechslung über 10+ Stufen).
- Perspektive: Pseudo-3D / isometrisch, schräg von oben.

---

## 8. Powerups (Früchte)

- Befinden sich in Sträuchern auf der Karte.
- Wirkung:
  - **Temporärer Boost** (z. B. Geschwindigkeit – genaue Boost-Art in Abstimmung mit
    Claude Code während der Umsetzung weiter spezifizierbar)
  - **Sofortige Sättigung** (füllt die Sättigungsanzeige spürbar auf)

---

## 9. Tag/Nacht-Zyklus

- Zyklischer Wechsel zwischen Tag und Nacht während einer Spielsession.
- Beeinflusst Gameplay: nachts andere/zusätzliche Gefahren aktiv (z. B. nachtaktive Tiere,
  ggf. andere Vogelverhalten).
- *Offene Frage: Zyklusdauer (z. B. X Minuten Tag / Y Minuten Nacht) und genaue
  nachtspezifische Gegner werden in der Content-Liste ergänzt.*

---

## 10. Speicherstand

- Fortschritt wird lokal auf dem Gerät gespeichert (Godot: `user://` Speicherpfad).
- Gespeichert werden mindestens: aktuelles Level, Story-Fortschritt vs. Endlos-Modus-Status,
  ggf. Highscore im Endlos-Modus.

---

## 11. Grafik & Art-Style

- Cartoonig, niedlich, kindgerecht.
- Einfache 2D-Sprites/Pixelart, selbst gezeichnet oder KI-generiert.
- Pseudo-3D/isometrische Darstellung der Spielwelt.

---

## 12. Audio

- Hintergrundmusik: passend zu Strand-/Naturthema, freundlich, ggf. mit Tag/Nacht-Variation.
- Soundeffekte für: Level-Up, Fressen, Krabbeln/Laufen, Vogel-Sturzflug/Warnsound,
  Frucht-Powerup-Aufnahme, Gefressen-werden/Reset.

---

## 13. UI/UX

- Kein Tutorial – Spieler soll die Mechaniken selbst entdecken.
- Minimale HUD-Elemente vorgesehen: Sättigungsanzeige, aktuelles Level, ggf. Tag/Nacht-Anzeige.
- *Offene Frage: Exaktes HUD-Layout wird in der technischen Umsetzung mit Claude Code
  iterativ entworfen.*

---

## 14. Technische Hinweise für Claude Code

- Engine: Godot 4.x, Zielplattform Android.
- Empfohlene Projektstruktur: Szenen für Spielwelt, Eidechse (Player-Controller mit
  dynamischem Touch-Input), Gegner-KI (State Machine: patrouillieren/fliehen/jagen),
  Kartenwachstum-Manager, Level-/Progressions-Manager, Save-System (`user://`), Audio-Manager.
- Gegner- und Frucht-Daten idealerweise als Godot-Resources oder JSON, um spätere
  Erweiterung der Vielfalt ohne Code-Änderungen zu erleichtern.
- Dynamische Touch-Steuerung: Offset-Punkt bei `touch_down`-Event neu setzen, Bewegungsvektor
  aus Differenz zwischen aktueller Fingerposition und Offset berechnen, normalisieren.

---

## 15. Offene Punkte (vor Produktionsstart zu klären)

- Vollständige Liste aller Tier-/Insektenarten mit Level-Zuordnung
- Exakte Sättigungs-Schwellenwerte pro Level-Up
- Genaue Boost-Wirkung der Powerup-Früchte (welche Fähigkeit wird geboostet?)
- Tag/Nacht-Zyklusdauer und nachtspezifische Gegner im Detail
- Ausnahmeregeln bei sehr hohem Eidechsen-Level gegenüber "immer gefährlichen" Tieren (z. B. Vögel)

# Nachtkatze – Anforderungen an Grafik-Assets

Stand: 2026-09-22

Die Assets ersetzen ein prozedurales Low-Poly-Kit, das bereits im Spiel steht. Wer sie baut, muss drei Dinge treffen: das Maßraster (1 Einheit = 1 m, Module zu 2 und 4 m), den Pivot je Bauteiltyp und den Farbweg über Vertex-Farben statt Texturen.

## Technische Eckdaten

Zielplattform ist ein Android-Handy im Querformat; das Spiel nutzt den Mobile-Renderer von Godot, also Vulkan. Alles, was hier steht, ist bereits im Projekt so eingestellt.

| Punkt | Vorgabe |
| --- | --- |
| Engine | Godot 4.3, Renderer "Mobile" |
| Lieferformat | glTF 2.0 binär (.glb), ein Bauteil je Datei |
| Maßstab | 1 Einheit = 1 Meter, Objektskalierung exakt 1,0 |
| Achsen | Y oben, −Z nach vorn (Blender: "Y up, −Z forward" beim Export) |
| Spielebene | Die Katze bewegt sich auf z = 0; Bauteile dürfen die Ebene z = −0,2 bis +0,2 nicht verbauen |
| Auflösung | 1280 × 720 als Bezug, gestreckt auf die Gerätebreite |
| Kamera | Seitlich, feste Ausrichtung, 45° Sichtfeld, 7 m Abstand — sichtbar sind rund 5,8 m Höhe und 10 m Breite |
| Schatten | Keine. Es gibt kein Schlagschatten-Rendering; nichts einbacken |
| Texturen | Keine – Farbe liegt auf den Eckpunkten (siehe Farbe und Material) |

Der sichtbare Ausschnitt ist der wichtigste Wert: ein Bauteil von 4 m Breite füllt knapp die halbe Bildbreite. Details unter etwa 5 cm sind auf dem Handy nicht mehr zu erkennen und kosten nur Polygone.

## Raster und Ursprung

Levels werden aus Modulen zusammengesetzt, die nahtlos aneinanderstoßen. Ein Modul muss deshalb exakt seine Nennbreite haben – nicht 3,98 m, nicht 4,02 m – und der Ursprung muss genau dort liegen, wo das Spiel ihn absetzt.

Geschosshöhe ist 3,00 m. Fassaden werden geschossweise gestapelt, Balkone und Dächer in 2-m-Schritten gereiht.

| Bauteiltyp | Modulbreite | Ursprung (Pivot) | Richtung |
| --- | --- | --- | --- |
| Geschoss-Segment | 4,00 m | Mitte der Standfläche, Fassadenfront auf z = 0 | seitlich kacheln |
| Balkonband | 2,00 m | Mitte der **Oberkante** der Platte | seitlich kacheln |
| Dachabschluss | 2,00 m | Mitte der **Oberkante** der Platte | seitlich kacheln |
| Straßen-Segment | 4,00 m | Mitte der **Fahrbahnoberfläche** | seitlich kacheln |
| Zaun, Zaun mit Lücke | 2,00 m | Mitte am Fuß | seitlich kacheln |
| Mauerstück | 2,00 m | Mitte am Fuß | seitlich kacheln |
| Regenrinne | 3,00 m Höhe | Fuß des Rohres | **nach oben** stapeln |
| Alles Übrige | frei | Mitte am Fuß | Einzelstück |

Warum die Oberkante bei Balkon und Dach: Das Spiel setzt eine Plattform auf die Höhe, auf der die Katze stehen soll. Liegt der Pivot unten, sinkt jede Platte um ihre Dicke ein und alle geprüften Sprunghöhen stimmen nicht mehr.

Bei seitlich kachelbaren Teilen müssen linke und rechte Schnittkante deckungsgleich sein: gleiche Höhen, gleiche Tiefen, keine überstehenden Zierelemente an der Modulgrenze. Überstände gehören in die Modulmitte.

## Geometrie

Das bestehende Kit liegt bei 24 bis 250 Dreiecken je Bauteil, zusammen 3170 für alle 30 Teile. Die neuen Assets dürfen deutlich feiner sein, aber nicht beliebig.

| Gruppe | Budget je Bauteil | Beispiel heute |
| --- | --- | --- |
| Kleinteile (Futter, Dachaufbauten) | bis 300 Dreiecke | Klimagerät 48 |
| Modulteile (Fassade, Balkon, Dach, Straße) | bis 400 Dreiecke | Geschoss-Segment 96 |
| Große Einzelstücke (Autos, Bäume, Zaun) | bis 800 Dreiecke | Zaun 180 |
| Landmarken (Kirchturm, Tankstelle) | bis 1500 Dreiecke | Kirchturm 250 |
| Ganzes Level sichtbar | unter 60 000 Dreiecke | — |

Modulteile zählen doppelt: ein Geschoss-Segment steht im Level bis zu sechsmal nebeneinander und dreimal übereinander.

Regeln für die Netze:

- **Harte Kanten überall.** Der Stil lebt von flachen Flächen; jede Fläche bekommt ihre eigene Normale. Keine weichen Übergänge, kein Smoothing über Kanten hinweg.
- **Nur Dreiecke**, beim Export trianguliert. Keine n-Gons, keine doppelten Eckpunkte, keine losen Kanten.
- **Außen ist außen.** Normalen zeigen nach außen, Flächen sind im Uhrzeigersinn gewickelt (Godots Vorderseiten-Konvention). Nach innen gedrehte Flächen bleiben im Spiel schwarz – genau daran ist das prozedurale Kit schon einmal gescheitert.
- **Keine Innenräume.** Was der Spieler nie sieht, wird nicht modelliert: Rückseiten von Fassaden, Unterseiten von Dächern nur als einfache Fläche.
- **Keine Modifikatoren im Export**, alles angewandt; keine Armaturen, keine Formschlüssel, außer bei den animierten Figuren.
- **Kein LOD nötig.** Die Kamera hat festen Abstand, es gibt nur eine Entfernungsstufe.

## Farbe und Material

Das Spiel hat **keine Texturen**. Farbe liegt auf den Eckpunkten, und alle Bauteile teilen sich ein einziges Material mit einem Toon-Shader. Das ist der Grund, warum die Levels auf dem Handy in einem Rutsch gezeichnet werden können – dieser Weg sollte erhalten bleiben.

**So sind Farben anzulegen**

- Jeder Eckpunkt trägt seine Farbe im COLOR-Attribut, als **sRGB** angelegt – also so, wie sie im Farbwähler aussieht. Der Shader rechnet selbst nach Linear um.
- **Der Alphakanal ist keine Transparenz, sondern Leuchtstärke.** 0,0 = normale Fläche. 0,8 bis 1,6 = leuchtet (Fenster, Laternenglas, Scheinwerfer, Leuchtband der Tankstelle). Werte über 2,0 verbrennen die Farbe zu Weiß.
- Keine Transparenz, kein Alpha-Blending, keine Durchsichtigkeit. Fenster sind leuchtende Flächen, keine Scheiben.
- Vorsicht bei dunklen Farben: das Tonemapping drückt niedrige Werte stark. Unter etwa 0,25 sRGB wird jede Fläche schwarz. Vegetation liegt deshalb bei 0,20–0,44 statt beim "Schwarzgrün" aus dem Design-Dokument – das Dunkle kommt aus der Nachtbeleuchtung.

**Beleuchtung**

Es gibt genau eine Sonne je Level und wenige Punktlichter (maximal sechs). Der Shader stuft das Sonnenlicht in drei harte Helligkeitsstufen, die dunkelste liegt bei 30 %. Nichts einbacken: keine Ambient Occlusion, keine Lightmaps, keine gemalten Schatten.

## Spielmaße, die die Form binden

Einige Maße sind nicht Geschmackssache, sondern Spielmechanik. Wer sie verändert, macht Levels unspielbar.

| Maß | Wert | Warum |
| --- | --- | --- |
| Katze | 0,55 m hoch, 0,40 m breit | passt durch die Zaunlücke |
| Sprunghöhe | 1,80 m | begrenzt, was erreichbar ist |
| Sprungweite aus dem Lauf | 3,50 m | Dachlücken liegen bei 1,5 bis 3,2 m |
| Geschosshöhe | 3,00 m | Stapelmaß aller Fassaden |
| Zaunlücke unten | 0,62 m lichte Höhe | Katze passt durch, kleinster Hund (0,75 m) nicht |
| Geparktes Auto | 1,40 m hoch | Katze springt drauf (unter 1,80 m) |
| Fahrendes Auto | 0,68 m Schadenshöhe | Katze springt bei richtigem Timing darüber |
| Kleiner Hund | 0,75 m hoch | darf nicht durch die Zaunlücke passen |
| Großer Hund | 1,15 m hoch | — |

Kollision kommt nicht aus dem Netz, sondern aus einfachen Kästen, die im Spiel definiert sind. Die Assets müssen sie nur nicht Lügen strafen:

- **Was die Katze trägt** (Balkonband, Dachabschluss, Straße, Markise, Mauer, geparktes Auto), braucht oben eine ebene, waagrechte Fläche über die volle Modulbreite. Keine Wellen, keine Stufen, keine Zierleisten auf der Lauflinie.
- **Geländer und Attika** stehen vor der Spielebene bei z = +1,1 und haben bewusst keine Kollision – die Katze läuft dahinter. Sie dürfen die Sicht auf die Katze nicht verdecken: höchstens 0,95 m hoch, luftig, keine geschlossenen Brüstungen.
- **Zierbauteile** (Pflanzen, Dachaufbauten, Laternen) stehen bei z = −2,2 oder tiefer und haben nie Kollision.
- **Der Vordergrund bleibt leer.** Nichts vor z = +0,2 außer den genannten Geländern.

## Lieferung

Eine Datei je Bauteil, glTF 2.0 binär (.glb). Godot importiert das direkt; .blend, .fbx oder .obj bitte nicht.

Dateinamen in Kleinbuchstaben, ohne Umlaute, mit Unterstrich – genau die Schlüssel aus der Bauteilliste, zum Beispiel `geschoss_segment.glb`, `zaun_mit_luecke.glb`, `regenrinne.glb`.

Im .glb genau ein Wurzelobjekt mit demselben Namen wie die Datei. Keine Kameras, keine Lichter, keine leeren Hilfsobjekte, keine Sammlungen. Transformation der Wurzel: Position 0/0/0, Rotation 0, Skalierung 1.

Was nicht mitgeliefert wird:

- Keine Kollisionsnetze; die Kästen stehen im Spiel.
- Keine Materialien mit PBR-Karten, keine eingebetteten Texturen.
- Keine Animationen für Kulisse. Animiert werden nur Katze, Hunde und Revierkatzen – dafür kommt eine eigene Liste, sobald die Kulisse steht.

Dazu bitte eine kurze Textdatei je Lieferung mit Bauteilname, Außenmaßen in Metern und Dreieckszahl. Damit sehe ich Abweichungen vor dem Einbau.

## Abnahme

Die Funktionsprüfung im Projekt läuft heute über 120 Punkte. Für Assets greifen diese, und sie laufen bei jedem Einbau automatisch:

- Jedes Bauteil hat Flächen und plausible Außenmaße (0,08 m bis 40 m Diagonale).
- Die Normalen zeigen nach außen – gemessen als Anteil der Eckpunkte, deren Normale vom Mittelpunkt wegzeigt; unter 50 % fällt das Teil durch.
- Das Geschoss-Segment ist 3,00 m hoch (Toleranz 0,35 m).
- Die Zaunlücke liegt zwischen 0,55 m und 0,75 m.
- Balkonband und Markise tragen die Katze, Pflanzen haben keine Kollision.
- Jede Kletterzone hat ein sichtbares Rohr an derselben Stelle.
- Alle Kletterzonen beider Levels führen tatsächlich bis nach oben – die Katze klettert sie im Test hoch.
- Die Dachlücken messen 1,50 m und 3,20 m.

Toleranz für Modulmaße: **± 1 cm**. Alles darüber zeigt sich als Spalt zwischen zwei Modulen oder als Stufe in der Lauflinie.

## Bauteilliste

Die 30 Bauteile, die heute im Spiel stehen, mit ihren tatsächlichen Maßen. Breite × Höhe × Tiefe in Metern, gemessen am bestehenden Netz. Wo eine Modulbreite steht, ist sie verbindlich; die übrigen Maße sind Richtwerte, an denen die Levels ausgerichtet sind.

| Bauteil | Dateiname | B × H × T | Modul | Trägt die Katze |
| --- | --- | --- | --- | --- |
| Geschoss-Segment | geschoss_segment | 4,10 × 3,00 × 2,10 | 4 m | ja |
| Balkonband | balkonband | 2,00 × 1,17 × 2,40 | 2 m | ja |
| Dachabschluss | dachabschluss | 2,00 × 0,66 × 2,44 | 2 m | ja |
| Straßen-Segment | strassen_segment | 4,00 × 0,42 × 6,00 | 4 m | ja |
| Mauerstück | mauerstueck | 2,10 × 0,57 × 0,80 | 2 m | ja |
| Zaun | zaun | 2,10 × 1,30 × 0,10 | 2 m | ja |
| Zaun mit Lücke | zaun_mit_luecke | 2,10 × 1,30 × 0,10 | 2 m | ja |
| Regenrinne | regenrinne | 0,20 × 3,05 × 0,40 | 3 m hoch | nein |
| Markise offen | markise_offen | 2,30 × 0,43 × 1,20 | — | ja |
| Markise geschlossen | markise_geschlossen | 2,30 × 0,30 × 0,38 | — | nein |
| Einfamilienhaus | einfamilienhaus | 5,60 × 4,10 × 5,10 | — | ja |
| Solarkollektor | solarkollektor | 1,60 × 1,02 × 1,24 | — | nein |
| Satellitenschüssel | satellitenschuessel | 1,00 × 1,47 × 0,95 | — | nein |
| Antenne | antenne | 0,70 × 1,85 × 0,30 | — | nein |
| Klimagerät | klimageraet | 0,75 × 0,55 × 0,43 | — | nein |
| Laterne | laterne | 0,93 × 3,32 × 0,28 | — | nein |
| Strommast | strommast | 1,60 × 5,00 × 0,28 | — | nein |
| Stromleitung | stromleitung | 8,01 × 0,55 × 0,05 | 8 m Spannweite | nein |
| Geparktes Auto | geparktes_auto | 3,60 × 1,27 × 1,78 | — | ja |
| Fahrendes Auto | fahrendes_auto | 3,22 × 0,92 × 1,78 | — | nein |
| Gartentor | gartentor | 1,20 × 1,51 × 0,08 | — | ja |
| Kiefer | kiefer | 2,42 × 3,13 × 2,46 | — | nein |
| Zypresse | zypresse | 1,07 × 4,40 × 1,08 | — | nein |
| Olivenbaum | olivenbaum | 2,15 × 2,20 × 1,65 | — | nein |
| Oleanderbusch | oleanderbusch | 1,38 × 1,04 × 1,06 | — | nein |
| Kirchturm | kirchturm | 3,20 × 14,90 × 3,12 | — | ja |
| Tankstelle | tankstelle | 6,14 × 3,64 × 4,10 | — | ja |
| Fischgräte | fischgraete | 0,66 × 0,18 × 0,09 | — | nein |
| Ganzer Fisch | ganzer_fisch | 0,75 × 0,30 × 0,14 | — | nein |
| Futternapf | futternapf | 0,56 × 0,18 × 0,56 | — | nein |

Farblich orientiert sich das Kit an einem mediterranen Wohnviertel in griechischem Stil: warmer Putz in Ocker und Bernstein, rote Ziegel, verzinktes Metall, schwarzgrüne Vegetation, als einziger kühler Akzent das grüne Leuchtband der Tankstelle. Die Spielerkatze ist rotgetigert und trägt eine Farbe, die sonst nirgends vorkommt – Kulisse darf ihr nicht ins Gehege kommen.

Die bestehenden Bauteile lassen sich als Formvorlage ansehen: Das Projekt hat ein Werkzeug, das alle 30 beschriftet nebeneinander aufstellt und als Bild ausgibt.

## Vorschlag: erst ein einzelnes Bauteil

Bevor das ganze Kit gebaut wird, sollte **nur das Geschoss-Segment** gezeichnet werden. An diesem einen Teil hängt alles, was schiefgehen kann: Maßstab, Pivot, Modulbreite, Vertex-Farben, Leuchtalpha, Normalenrichtung und der Toon-Shader.

Warum ausgerechnet dieses Teil:

- Es ist **kachelbar**, zeigt also sofort, ob Modulbreite und Schnittkanten stimmen.
- Es hat **Fenster mit Leuchtalpha** – damit lässt sich der ungewohnte Farbweg prüfen.
- Es hat **Kollision** und trägt die Fassade, an der die Katze klettert.
- Es steht in beiden Levels am häufigsten; ein Fehler darin fällt 20-mal auf.

Ablauf:

1. Ein `geschoss_segment.glb` nach dieser Spezifikation.
2. Ich baue es ein, stelle drei Module nebeneinander und zwei übereinander und lasse die Funktionsprüfung laufen. Dauer: rund eine Stunde.
3. Ich schicke Screenshots aus dem Spiel zurück, dazu eine Liste der Abweichungen – gemessen, nicht geschätzt.
4. Erst wenn dieses Teil sitzt, geht die volle Bauteilliste in Auftrag.

Was dieser Umweg spart: Fällt zum Beispiel der Pivot des Balkonbands an die Unterkante statt an die Oberkante, sind 30 Teile falsch und müssen neu exportiert werden. Am Probestück kostet derselbe Fehler eine Nachricht.

Falls es schneller gehen soll, wäre die zweite Stufe eine kleine Gruppe: Geschoss-Segment, Balkonband, Dachabschluss und Straßen-Segment. Mit diesen vier steht ein ganzes Haus samt Straße – genug, um den Stil im Spiel zu beurteilen, bevor Pflanzen, Fahrzeuge und Landmarken entstehen.

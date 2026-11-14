class_name Levels
extends RefCounted
## Level-Definitionen als ASCII-Karten.
##
## Legende:
##   .  Wiese            ~  Wasser (nur Brücken)
##   T  Nadelbäume       t  Laubbäume          R  Felsen
##   H  Haus             K  Kirche
##   -  Straße West-Ost  |  Straße Nord-Süd    +  Kreuzung
##   =  Straßenbrücke West-Ost über Wasser     !  Straßenbrücke Nord-Süd
##   S  Startbahnhof-Gleisfeld                 s  Bahnsteig/Gebäude (reserviert)
##   G  Zielbahnhof-Gleisfeld                  g  Bahnsteig/Gebäude (reserviert)
##
## start_exit: Richtung, in die der Zug den Startbahnhof verlässt.
## goal_open:  Seite, von der aus der Zielbahnhof angefahren wird.

const LIST: Array[Dictionary] = [
	{
		"name": "Wiesental",
		"title": "Level 1 · Wiesental",
		"intro": "Verbinde den Startbahnhof Grünau mit dem Zielbahnhof Seeblick.\nBaue zuerst beide Bahnhöfe auf den markierten Feldern, verlege dann Gleise – über den Bach hilft nur eine Brücke.",
		"start_name": "Grünau",
		"goal_name": "Seeblick",
		"start_exit": G.E,
		"goal_open": G.W,
		"cars": 0,
		"map": [
			"..T....~....T.",
			".sss...~..t...",
			".SSS...~....H.",
			".......~......",
			"..H..t.~...T..",
			"......~~......",
			".t..H.~...ggg.",
			"......~...GGG.",
			"...T..~.t.....",
			"......~......T",
		],
	},
	{
		"name": "Zwei Straßen",
		"title": "Level 2 · Zwei Straßen",
		"intro": "Zwei Straßen kreuzen deinen Weg. Auf Straßen lassen sich nur Bahnübergänge bauen – die Schranken schließen sich, sobald dein Zug kommt.",
		"start_name": "Lindenhof",
		"goal_name": "Mühlbach",
		"start_exit": G.E,
		"goal_open": G.W,
		"cars": 5,
		"map": [
			"sss.~.T...|..t.H",
			"SSS.~..H..|.H...",
			"....~.....|.....",
			".t.H~~..t.|..T..",
			"..H..~.H..|.H..t",
			".....~....|.....",
			"-----=----+-----",
			".T.H.~.H..|.t.H.",
			"....~~..H.|.....",
			".H..~..t..|.GGG.",
			"....~.....|.ggg.",
			"..t.~..T.H|.....",
		],
	},
	{
		"name": "Kleinstadt",
		"title": "Level 3 · Kleinstadt",
		"intro": "Dichte Bebauung, drei Straßen und ein breiter Fluss: Finde einen Weg durch die Stadt zum Zielbahnhof – und behalte das Budget im Blick.",
		"start_name": "Altstadt",
		"goal_name": "Hafen",
		"start_exit": G.E,
		"goal_open": G.W,
		"cars": 9,
		"map": [
			"TT..H..|..~~..T..H.T",
			".sss...|.H~~.....H..",
			".SSS.H.|...~~..T....",
			".....H.|.H..~.HH..T.",
			"-------+----=-------",
			".H.T...|.t..~..H.H..",
			"...HH..|.H..~~...H..",
			".T...H.|HH...~.T....",
			"...H...|...H.~..HH..",
			".H...T.|..T..~......",
			"-------+-----=------",
			"..T.H..|.H...~.ggg..",
			".....t.|...T.~.GGG.T",
			".T..H..|.H...~~.....",
		],
	},
]


static func count() -> int:
	return LIST.size()

class_name Defs
extends RefCounted
## Zentrale Spielkonstanten und Datentabellen.

const W := 56
const H := 56
const TILE := 2.0
const WALL_H := 2.6

enum T { BEDROCK, ROCK, GOLD, GEM, FLOOR, WALL, HEART, PORTAL, GATE }
enum R { NONE, TREASURY, LAIR, FARM, TRAINING }

const HEART_CAP := 2000
const TREASURY_CAP := 600
const IMP_CARRY := 300
const START_GOLD := 1500
const START_MANA := 300.0
const MANA_MAX := 2000.0
const HEART_HP := 3000.0
const FIRST_WAVE := 330.0
const WAVE_GAP := 230.0

const ROOM_INFO := {
	R.TREASURY: {"name": "Schatzkammer", "short": "Schatz", "cost": 50, "key": "1", "color": Color(0.95, 0.75, 0.2),
		"desc": "Lagert Gold (600 pro Feld).\n9+ Felder locken zusammen mit\neinem Übungsraum Hornbestien an."},
	R.LAIR: {"name": "Hort", "short": "Hort", "cost": 40, "key": "2", "color": Color(0.6, 0.42, 0.25),
		"desc": "Schlafplatz für 1 Kreatur pro Feld.\nKreaturen heilen sich hier."},
	R.FARM: {"name": "Pilzfarm", "short": "Pilze", "cost": 60, "key": "3", "color": Color(0.3, 0.85, 0.7),
		"desc": "Leuchtpilze als Nahrung.\nHort + Pilzfarm locken Moderwürmer an."},
	R.TRAINING: {"name": "Übungsraum", "short": "Training", "cost": 90, "key": "4", "color": Color(0.85, 0.35, 0.25),
		"desc": "Kreaturen trainieren und steigen auf\n(kostet laufend Gold).\n4+ Felder locken Glutkobolde an."},
}

const SPELL_INFO := {
	"imp": {"name": "Wichtel beschwören", "short": "Wichtel", "key": "C", "desc": "Erschafft einen Grubenwicht\nauf eigenem Boden."},
	"bolt": {"name": "Blitzschlag", "short": "Blitz", "key": "V", "cost": 200, "desc": "Schwerer Flächenschaden an Feinden."},
	"heal": {"name": "Heilwelle", "short": "Heilung", "key": "B", "cost": 150, "desc": "Heilt eigene Kreaturen im Umkreis."},
}

# range = Angriffsreichweite in Feldern, speed = Felder pro Sekunde
const UNITS := {
	"imp": {"name": "Grubenwicht", "hp": 70.0, "dmg": 4.0, "range": 1.2, "cd": 0.8, "speed": 3.4, "wage": 0, "team": 1, "bar": 1.25},
	"worm": {"name": "Moderwurm", "hp": 150.0, "dmg": 10.0, "range": 1.3, "cd": 1.1, "speed": 2.2, "wage": 40, "team": 1, "bar": 1.3},
	"bat": {"name": "Nachtmahr", "hp": 95.0, "dmg": 8.0, "range": 1.4, "cd": 0.6, "speed": 4.4, "wage": 55, "team": 1, "fly": 1.0, "bar": 2.4},
	"kobold": {"name": "Glutkobold", "hp": 115.0, "dmg": 13.0, "range": 5.0, "cd": 1.6, "speed": 2.8, "wage": 75, "team": 1, "ranged": true, "bar": 1.6},
	"brute": {"name": "Hornbestie", "hp": 340.0, "dmg": 26.0, "range": 1.5, "cd": 1.5, "speed": 2.0, "wage": 160, "team": 1, "bar": 2.4},
	"knight": {"name": "Ritter", "hp": 240.0, "dmg": 17.0, "range": 1.4, "cd": 1.2, "speed": 2.3, "team": 2, "bar": 2.0},
	"archer": {"name": "Bogenschützin", "hp": 120.0, "dmg": 11.0, "range": 5.5, "cd": 1.4, "speed": 2.6, "team": 2, "ranged": true, "bar": 1.9},
	"priest": {"name": "Priester", "hp": 110.0, "dmg": 6.0, "range": 4.5, "cd": 1.6, "speed": 2.3, "team": 2, "ranged": true, "healer": true, "bar": 1.9},
	"dwarf": {"name": "Zwergengräber", "hp": 180.0, "dmg": 12.0, "range": 1.3, "cd": 1.0, "speed": 2.5, "team": 2, "digger": 3.0, "bar": 1.5},
}

const WAVES := [
	["knight", "archer"],
	["knight", "knight", "archer", "dwarf"],
	["knight", "knight", "archer", "archer", "priest", "dwarf"],
	["knight", "knight", "knight", "archer", "archer", "priest", "dwarf", "dwarf"],
	["knight", "knight", "knight", "knight", "archer", "archer", "archer", "priest", "priest", "dwarf"],
	["knight", "knight", "knight", "knight", "knight", "archer", "archer", "archer", "priest", "priest", "dwarf", "dwarf"],
]

static func tile_hp(ty: int) -> float:
	match ty:
		T.ROCK: return 5.0
		T.GOLD: return 12.0
		T.WALL: return 12.0
		T.GEM: return 1.0e9
	return 0.0

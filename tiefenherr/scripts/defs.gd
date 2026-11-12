class_name Defs
extends RefCounted
## Zentrale Spielkonstanten und Datentabellen.

const W := 56
const H := 56
const TILE := 2.0
const WALL_H := 2.6

enum T { BEDROCK, ROCK, GOLD, GEM, FLOOR, WALL, HEART, PORTAL, GATE }
enum R { NONE, TREASURY, LAIR, FARM, TRAINING }

const HEART_CAP := 3000
const TREASURY_CAP := 600
const IMP_CARRY := 300
const MANA_MAX := 2000.0
const HEART_HP := 3000.0

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
	"paladin": {"name": "Paladin", "hp": 720.0, "dmg": 34.0, "range": 1.7, "cd": 1.3, "speed": 2.1, "team": 2, "bar": 2.8},
	"dwarf": {"name": "Zwergengräber", "hp": 180.0, "dmg": 12.0, "range": 1.3, "cd": 1.0, "speed": 2.5, "team": 2, "digger": 3.0, "bar": 1.5},
}

const TRAP_INFO := {
	"spike": {"name": "Bodenstachel", "key": "5", "gold": 150, "mana": 40, "cd": 2.5, "dmg": 45.0, "radius": 0.75, "wall": false,
		"desc": "Stacheln schießen aus dem Boden, sobald\nein Feind das Feld betritt."},
	"wallspike": {"name": "Wandstachel", "key": "6", "gold": 200, "mana": 50, "cd": 2.2, "dmg": 38.0, "radius": 1.25, "wall": true,
		"desc": "Wird in eine befestigte Wand gebaut und\ntrifft Feinde auf den Nachbarfeldern."},
	"fire": {"name": "Feuerfalle", "key": "7", "gold": 350, "mana": 120, "cd": 6.0, "dmg": 75.0, "radius": 1.7, "wall": false,
		"desc": "Flammenstoß mit Flächenschaden\nrund um die Falle."},
	"poison": {"name": "Giftregen", "key": "8", "gold": 400, "mana": 150, "cd": 13.0, "dmg": 16.0, "radius": 2.1, "wall": false,
		"desc": "Giftwolke, die 6 Sekunden lang alle\nFeinde im Umkreis verätzt."},
}

const WAVE_KEYS := {"k": "knight", "a": "archer", "p": "priest", "d": "dwarf", "P": "paladin"}

# gold = Rausch-Schwelle für Goldadern (kleiner = mehr Gold), cave = Schwelle für Höhlen
const LEVELS := [
	{"name": "Erste Grabung", "desc": "Ein ruhiger Anfang: viel Gold, wenige Helden.",
		"seed": 101, "heart": Vector2i(10, 10), "portals": [Vector2i(24, 12)], "gates": [Vector2i(46, 46)],
		"gems": [Vector2i(9, 24)], "gold": 0.38, "cave": 0.52, "start_gold": 2000, "start_mana": 300.0,
		"first_wave": 420.0, "gap": 260.0, "hero_lvl": 0,
		"waves": ["k1", "k1 a1", "k2 a1", "k2 a1 d1"]},
	{"name": "Goldfieber", "desc": "Zwei Portale und reiche Adern – aber die Helden werden mehr.",
		"seed": 202, "heart": Vector2i(10, 10), "portals": [Vector2i(24, 12), Vector2i(29, 31)], "gates": [Vector2i(46, 46)],
		"gems": [Vector2i(9, 24)], "gold": 0.45, "cave": 0.52, "start_gold": 1500, "start_mana": 300.0,
		"first_wave": 330.0, "gap": 230.0, "hero_lvl": 0,
		"waves": ["k1 a1", "k2 a1 d1", "k2 a2 p1 d1", "k3 a2 p1 d2", "k4 a3 p2 d1", "k5 a3 p2 d2"]},
	{"name": "Zwei Tore", "desc": "Dein Herz liegt in der Mitte. Die Helden kommen von zwei Seiten.",
		"seed": 303, "heart": Vector2i(28, 28), "portals": [Vector2i(40, 20), Vector2i(16, 37)], "gates": [Vector2i(7, 7), Vector2i(48, 48)],
		"gems": [Vector2i(28, 42)], "gold": 0.44, "cave": 0.54, "start_gold": 2000, "start_mana": 400.0,
		"first_wave": 330.0, "gap": 230.0, "hero_lvl": 0,
		"waves": ["k2 a1", "k2 a2 d1", "k3 a2 p1 d1", "k3 a3 p1 d2", "k4 a3 p2 d2", "k5 a4 p2 d2"]},
	{"name": "Karges Land", "desc": "Kaum Gold im Fels. Nur die Edelsteinadern halten dein Reich am Leben.",
		"seed": 404, "heart": Vector2i(12, 44), "portals": [Vector2i(26, 44)], "gates": [Vector2i(46, 9)],
		"gems": [Vector2i(12, 30), Vector2i(30, 34)], "gold": 0.66, "cave": 0.5, "start_gold": 2500, "start_mana": 400.0,
		"first_wave": 360.0, "gap": 240.0, "hero_lvl": 0,
		"waves": ["k2 a1", "k2 a2 d1", "k3 a2 p1", "k3 a3 p1 d2", "k4 a3 p2 d2", "k5 a3 p2 d2", "k6 a4 p2 d2"]},
	{"name": "Die Zwergenminen", "desc": "Zwergengräber wühlen sich aus zwei Stollen direkt zu dir durch.",
		"seed": 505, "heart": Vector2i(28, 10), "portals": [Vector2i(14, 12), Vector2i(42, 12)], "gates": [Vector2i(8, 48), Vector2i(48, 48)],
		"gems": [Vector2i(28, 24)], "gold": 0.46, "cave": 0.44, "start_gold": 2000, "start_mana": 500.0,
		"first_wave": 300.0, "gap": 210.0, "hero_lvl": 0,
		"waves": ["d3", "d3 k1", "d4 k2 a1", "d4 k2 a2 p1", "d5 k3 a2 p1", "d6 k3 a3 p2", "d6 k5 a3 p2"]},
	{"name": "Belagerung", "desc": "Acht Wellen in rascher Folge. Baue Fallen – du wirst sie brauchen.",
		"seed": 606, "heart": Vector2i(10, 45), "portals": [Vector2i(24, 44), Vector2i(12, 30)], "gates": [Vector2i(46, 9)],
		"gems": [Vector2i(22, 32)], "gold": 0.42, "cave": 0.52, "start_gold": 2800, "start_mana": 600.0,
		"first_wave": 270.0, "gap": 150.0, "hero_lvl": 1,
		"waves": ["k2 a1", "k2 a2 d1", "k3 a2 p1", "k3 a3 p1 d2", "k4 a3 p2 d1", "k4 a4 p2 d2", "k5 a4 p2 d2", "k6 a4 p3 d2 P1"]},
	{"name": "Der Lichtbringer", "desc": "Drei Tore, zehn Wellen und Paladine. Das Finale.",
		"seed": 707, "heart": Vector2i(28, 30), "portals": [Vector2i(28, 44), Vector2i(14, 26), Vector2i(42, 26)],
		"gates": [Vector2i(7, 7), Vector2i(48, 7), Vector2i(28, 50)],
		"gems": [Vector2i(20, 38), Vector2i(36, 38)], "gold": 0.42, "cave": 0.54, "start_gold": 2800, "start_mana": 800.0,
		"first_wave": 300.0, "gap": 190.0, "hero_lvl": 1,
		"waves": ["k2 a2", "k3 a2 d1", "k3 a2 p1 d2", "k4 a3 p1 d2", "k4 a3 p2 d2 P1", "k5 a4 p2 d2", "k5 a4 p2 d3 P1",
			"k6 a4 p3 d3 P1", "k6 a5 p3 d3 P2", "k8 a5 p3 d3 P3"]},
]

# Wird über Szenen-Neuladen hinweg gehalten
static var next_level := 0
static var pending_load := ""
static var autostart := false


static func parse_wave(spec: String) -> Array:
	var out := []
	for part in spec.split(" ", false):
		var kind: String = WAVE_KEYS[part.substr(0, 1)]
		for i in int(part.substr(1)):
			out.append(kind)
	out.shuffle()
	return out


static func tile_hp(ty: int) -> float:
	match ty:
		T.ROCK: return 5.0
		T.GOLD: return 12.0
		T.WALL: return 12.0
		T.GEM: return 1.0e9
	return 0.0

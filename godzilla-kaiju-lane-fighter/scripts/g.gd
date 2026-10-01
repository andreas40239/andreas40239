class_name G
## Shared constants + level definitions.

const LANE_Y := [260.0, 350.0, 440.0]  # 0=high, 1=mid, 2=ground
const LANE_HIGH := 0
const LANE_MID := 1
const LANE_GROUND := 2

const PLAY_LEFT := 40.0
const PLAY_RIGHT := 312.0

const SCROLL_SPEED := 46.0   # march auto-scroll (px/s)

const COL_FIN := Color("5eead4")
const COL_FIN_DIM := Color(0.23, 0.45, 0.42)
const COL_HP := Color("ef4444")
const COL_METER := Color("3b82f6")
const COL_TEXT := Color(0.92, 0.94, 0.96)

## Lane tint hints (GDD 2.2): warm ground, neutral mid, cool high.
const LANE_TINT := [Color(0.62, 0.72, 0.95, 0.10), Color(0.8, 0.8, 0.8, 0.06), Color(0.95, 0.72, 0.45, 0.10)]

const SCORE := {"raptor": 100, "ptera": 150, "anky": 300, "tank": 250, "heli": 250,
	"jetraptor": 150, "proto": 800, "trex": 1000, "boss": 2000}

## Enemy base stats (GDD 5)
const ENEMY := {
	"raptor": {"hp": 20.0, "dmg": 4.0, "speed": 95.0, "lane": LANE_GROUND},
	"ptera": {"hp": 15.0, "dmg": 6.0, "speed": 80.0, "lane": LANE_HIGH},
	"anky": {"hp": 60.0, "dmg": 7.0, "speed": 14.0, "lane": LANE_GROUND},
	"tank": {"hp": 50.0, "dmg": 8.0, "speed": 45.0, "lane": LANE_GROUND},
	"heli": {"hp": 32.0, "dmg": 6.0, "speed": 70.0, "lane": LANE_MID},
	"jetraptor": {"hp": 18.0, "dmg": 6.0, "speed": 110.0, "lane": LANE_HIGH},
	"proto": {"hp": 150.0, "dmg": 10.0, "speed": 80.0, "lane": LANE_MID},
}

const BOSS_HP := {"tyrannoking": 420.0, "trex": 150.0, "superx": 480.0, "mecha": 600.0}

static func march(dist: float, spawn: Array, rate: float) -> Dictionary:
	return {"type": "march", "dist": dist, "spawn": spawn, "rate": rate}

static func arena(waves: Array) -> Dictionary:
	return {"type": "arena", "waves": waves}

## Level definitions (GDD 7). Arena waves are lists of [kind, from_left].
static var LEVELS := {
	0: {
		"name": "TRAINING", "theme": "beach", "training": true,
		"story": "", "segments": [{"type": "training"}],
	},
	1: {
		"name": "PRIMEVAL SHORES", "theme": "beach",
		"story": "Dawn breaks over the ancient coast.\n\nSomething colossal rises from\nthe waves. The pack hunters\nsmell an intruder.\n\nTeach them who is KING.",
		"segments": [
			march(700.0, ["raptor"], 3.2),
			arena([[["raptor", false], ["raptor", false]], [["raptor", false], ["raptor", true], ["raptor", false]]]),
			march(700.0, ["raptor"], 2.4),
			arena([[["raptor", false], ["raptor", true], ["raptor", false]], [["raptor", false], ["raptor", false], ["raptor", true], ["raptor", false]]]),
		],
	},
	2: {
		"name": "JUNGLE RUINS", "theme": "jungle",
		"story": "Deep in the overgrown temple\ncity, wings blot out the sun.\n\nArmored tails crack the stone.\n\nSwat the sky. Break the shell.",
		"segments": [
			march(650.0, ["raptor", "ptera"], 3.0),
			arena([[["ptera", false], ["raptor", false]], [["anky", false], ["ptera", false]]]),
			march(650.0, ["ptera", "raptor"], 2.4),
			arena([[["anky", false], ["raptor", true], ["ptera", false]], [["anky", false], ["anky", true], ["ptera", false]]]),
		],
	},
	3: {
		"name": "THE TYRANT'S THRONE", "theme": "volcano", "boss_name": "TYRANNOKING",
		"story": "The volcanic caldera glows\nblood-red.\n\nHere rules TYRANNOKING -\ndevourer of titans.\n\nOnly one apex predator\nleaves this crater.",
		"segments": [march(520.0, ["raptor"], 2.8), {"type": "boss", "boss": "tyrannoking"}],
	},
	4: {
		"name": "CRETACEOUS CAVERNS", "theme": "caves",
		"story": "Glowing crystals light the\ncaves below the island.\n\nTwo young T-Rex brothers\nguard the tunnels.\n\nDodge their bites!",
		"segments": [
			march(600.0, ["raptor", "ptera"], 2.6),
			arena([[["raptor", false], ["raptor", true]], [["trex", false]]]),
			march(600.0, ["ptera", "raptor", "anky"], 2.4),
			arena([[["raptor", false], ["ptera", true]], [["trex", false], ["raptor", true]], [["trex", false]]]),
		],
	},
	5: {
		"name": "FIRST CONTACT", "theme": "base",
		"story": "The humans have noticed you.\n\nTanks roll across the beach.\nHelicopters fill the sky.\n\nTail-whip their missiles\nright back at them!",
		"segments": [
			march(650.0, ["tank", "raptor"], 3.0),
			arena([[["tank", false], ["heli", false]], [["heli", false], ["tank", true]]]),
			march(650.0, ["heli", "tank"], 2.8),
			arena([[["tank", false], ["tank", true], ["heli", false]], [["heli", false], ["heli", true], ["tank", false]]]),
		],
	},
	6: {
		"name": "SKIES OF FIRE", "theme": "city", "boss_name": "SUPER X",
		"story": "The city burns.\n\nAbove the flames hovers the\nSUPER X - a flying fortress\nbuilt to stop you.\n\nWatch its colors.\nRed means LASER!",
		"segments": [march(520.0, ["heli", "tank"], 2.8), {"type": "boss", "boss": "superx"}],
	},
	7: {
		"name": "THE HYBRID WAR", "theme": "lab",
		"story": "In a secret lab, scientists\nput jetpacks on raptors.\n\nAnd they built a metal\ncopy of YOU.\n\nBreak its shield with your\nfull-power breath!",
		"segments": [
			march(650.0, ["jetraptor", "tank"], 2.6),
			arena([[["jetraptor", false], ["tank", false]], [["proto", false]]]),
			march(600.0, ["jetraptor", "heli", "tank"], 2.4),
			arena([[["proto", false], ["jetraptor", true]], [["tank", false], ["heli", true], ["jetraptor", false]]]),
		],
	},
	8: {
		"name": "FINAL PROTOCOL", "theme": "silo", "boss_name": "MECHAGODZILLA",
		"story": "Deep in the missile silo\nwaits MECHAGODZILLA.\n\nEverything you can do,\nit can do better.\n\nProve you are the\nKING OF THE MONSTERS!",
		"segments": [march(520.0, ["jetraptor", "tank", "raptor"], 2.4), {"type": "boss", "boss": "mecha"}],
	},
}

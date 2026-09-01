class_name G
## Shared constants + level definitions.

const LANE_Y := [260.0, 350.0, 440.0]  # 0=high, 1=mid, 2=ground
const LANE_HIGH := 0
const LANE_MID := 1
const LANE_GROUND := 2

const PLAY_LEFT := 28.0
const PLAY_RIGHT := 332.0

const SCROLL_SPEED := 46.0   # march auto-scroll (px/s)

const COL_FIN := Color("5eead4")
const COL_FIN_DIM := Color(0.23, 0.45, 0.42)
const COL_HP := Color("ef4444")
const COL_METER := Color("3b82f6")
const COL_TEXT := Color(0.92, 0.94, 0.96)

## Lane tint hints (GDD 2.2): warm ground, neutral mid, cool high.
const LANE_TINT := [Color(0.62, 0.72, 0.95, 0.10), Color(0.8, 0.8, 0.8, 0.06), Color(0.95, 0.72, 0.45, 0.10)]

const SCORE := {"raptor": 100, "ptera": 150, "anky": 300, "boss": 2000}

## Enemy base stats (GDD 5.1)
const ENEMY := {
	"raptor": {"hp": 20.0, "dmg": 4.0, "speed": 95.0, "lane": LANE_GROUND},
	"ptera": {"hp": 15.0, "dmg": 6.0, "speed": 80.0, "lane": LANE_HIGH},
	"anky": {"hp": 60.0, "dmg": 7.0, "speed": 14.0, "lane": LANE_GROUND},
}

const BOSS_HP := 420.0

## Level definitions (MVP: levels 1-3, GDD 7 / 12.2).
## march: dist (world px) + spawn table; arena: waves of [kind, from_left]
const LEVELS := {
	1: {
		"name": "PRIMEVAL SHORES", "theme": "beach",
		"story": "Dawn breaks over the ancient coast.\n\nSomething colossal rises from\nthe waves. The primeval island\nstirs — its pack hunters smell\nan intruder.\n\nTeach them who is KING.",
		"segments": [
			{"type": "march", "dist": 700.0, "spawn": ["raptor"], "rate": 3.2},
			{"type": "arena", "waves": [[["raptor", false], ["raptor", false]],
				[["raptor", false], ["raptor", true], ["raptor", false]]]},
			{"type": "march", "dist": 700.0, "spawn": ["raptor"], "rate": 2.4},
			{"type": "arena", "waves": [[["raptor", false], ["raptor", true], ["raptor", false]],
				[["raptor", false], ["raptor", false], ["raptor", true], ["raptor", false]]]},
		],
	},
	2: {
		"name": "JUNGLE RUINS", "theme": "jungle",
		"story": "Deep in the overgrown temple\ncity, wings blot out the sun.\n\nArmored tails crack the ancient\nstone. The sky and the ground\nboth want you dead.\n\nSwat the sky. Break the shell.",
		"segments": [
			{"type": "march", "dist": 650.0, "spawn": ["raptor", "ptera"], "rate": 3.0},
			{"type": "arena", "waves": [[["ptera", false], ["raptor", false]],
				[["anky", false], ["ptera", false]]]},
			{"type": "march", "dist": 650.0, "spawn": ["ptera", "raptor"], "rate": 2.4},
			{"type": "arena", "waves": [[["anky", false], ["raptor", true], ["ptera", false]],
				[["anky", false], ["anky", true], ["ptera", false]]]},
		],
	},
	3: {
		"name": "THE TYRANT'S THRONE", "theme": "volcano",
		"story": "The volcanic caldera glows\nblood-red.\n\nHere rules TYRANNOKING —\nmutated alpha of the island,\ndevourer of titans.\n\nOnly one apex predator\nleaves this crater.",
		"segments": [
			{"type": "march", "dist": 520.0, "spawn": ["raptor"], "rate": 2.8},
			{"type": "boss"},
		],
	},
}

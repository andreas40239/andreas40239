extends Node
## Persistent game state: progress, Evolution Points, upgrades, save/load.

const SAVE_PATH := "user://save.cfg"

## EP granted on first-time completion of each level (GDD 7).
const LEVEL_EP := {1: 1, 2: 2, 3: 3}

## Tier 1 upgrades (MVP scope, GDD 8.2 / 12.2). Cost: 1 EP each.
const UPGRADES := {
	"capacitors": {"name": "Dorsal Capacitors", "tree": "Atomic Power",
		"desc": "Atomic meter max +25%. Fins glow brighter.", "color": Color("2dd4bf")},
	"claws": {"name": "Sharpened Claws", "tree": "Primal Combat",
		"desc": "Melee damage +20%. Wider tail whip.", "color": Color("ef4444")},
	"scales": {"name": "Thick Scales", "tree": "Hide & Healing",
		"desc": "Max HP +30%. Bulkier hide.", "color": Color("22c55e")},
	"reflexes": {"name": "Reflexes", "tree": "Kaiju Agility",
		"desc": "Lane switch 30% faster. Longer enemy tells.", "color": Color("a855f7")},
}

var unlocked_level := 1
var ep := 0
var upgrades := {}          # id -> true
var completed := {}         # level (int) -> true
var high_score := 0
var mercy_deaths := {}      # level -> death count (mercy mode after 5)

var current_level := 1      # level being launched
var last_score := 0
var last_ep_gain := 0

func _ready() -> void:
	load_game()

func has_upg(id: String) -> bool:
	return upgrades.get(id, false)

func max_hp() -> float:
	return 100.0 * (1.3 if has_upg("scales") else 1.0)

func max_meter() -> float:
	return 100.0 * (1.25 if has_upg("capacitors") else 1.0)

func melee_mult() -> float:
	return 1.2 if has_upg("claws") else 1.0

func lane_switch_time() -> float:
	return 0.3 / (1.3 if has_upg("reflexes") else 1.0)

func tell_bonus() -> float:
	return 0.15 if has_upg("reflexes") else 0.0

func mercy_active(level: int) -> bool:
	return mercy_deaths.get(level, 0) >= 5

func add_death(level: int) -> void:
	mercy_deaths[level] = mercy_deaths.get(level, 0) + 1

func buy_upgrade(id: String) -> bool:
	if ep <= 0 or has_upg(id):
		return false
	ep -= 1
	upgrades[id] = true
	save_game()
	return true

func complete_level(level: int, score: int) -> void:
	last_score = score
	high_score = max(high_score, score)
	last_ep_gain = 0
	if not completed.get(level, false):
		completed[level] = true
		last_ep_gain = LEVEL_EP.get(level, 1)
		ep += last_ep_gain
	unlocked_level = max(unlocked_level, min(level + 1, 3))
	save_game()

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save", "unlocked_level", unlocked_level)
	cfg.set_value("save", "ep", ep)
	cfg.set_value("save", "upgrades", upgrades.keys())
	cfg.set_value("save", "completed", completed.keys())
	cfg.set_value("save", "high_score", high_score)
	cfg.save(SAVE_PATH)

func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	unlocked_level = cfg.get_value("save", "unlocked_level", 1)
	ep = cfg.get_value("save", "ep", 0)
	upgrades.clear()
	for id in cfg.get_value("save", "upgrades", []):
		upgrades[id] = true
	completed.clear()
	for lv in cfg.get_value("save", "completed", []):
		completed[int(lv)] = true
	high_score = cfg.get_value("save", "high_score", 0)

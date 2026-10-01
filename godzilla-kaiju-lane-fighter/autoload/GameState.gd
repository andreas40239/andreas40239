extends Node
## Persistent game state: progress, Evolution Points (gems), upgrades, save/load.

const SAVE_PATH := "user://save.cfg"
const MAX_LEVEL := 8
const MAX_UPGRADE := 5

## Gems for the FIRST clear of each level (GDD 7). Replays always give 1.
const LEVEL_EP := {1: 1, 2: 2, 3: 3, 4: 2, 5: 2, 6: 3, 7: 3, 8: 5}

## Five power trees, 5 stars each, 1 gem per star. Icons so kids can read them.
const UPGRADES := {
	"breath": {"name": "FIRE", "icon": "breath", "color": Color("2dd4bf"),
		"tip": "Bigger atomic breath + more blue energy"},
	"claws": {"name": "CLAWS", "icon": "claws", "color": Color("ef4444"),
		"tip": "Tail and claws hit harder"},
	"health": {"name": "HEALTH", "icon": "health", "color": Color("f43f5e"),
		"tip": "More hearts, enemies hurt less"},
	"speed": {"name": "SPEED", "icon": "speed", "color": Color("facc15"),
		"tip": "Walk and jump lanes faster"},
	"blast": {"name": "BLAST", "icon": "blast", "color": Color("a855f7"),
		"tip": "Purple nuke button is stronger and faster"},
}
const OLD_IDS := {"capacitors": "breath", "claws": "claws", "scales": "health", "reflexes": "speed"}

var unlocked_level := 1
var ep := 0
var upgrades := {}          # id -> level (0..5)
var completed := {}         # level (int) -> true
var high_score := 0
var mercy_deaths := {}      # level -> death count (mercy mode after 5)

var current_level := 1
var last_score := 0
var last_ep_gain := 0

func _ready() -> void:
	load_game()

func lvl(id: String) -> int:
	return int(upgrades.get(id, 0))

func max_hp() -> float:
	return 100.0 * (1.0 + 0.12 * lvl("health"))

func damage_taken_mult() -> float:
	return 1.0 - 0.05 * lvl("health")

func max_meter() -> float:
	return 100.0 * (1.0 + 0.12 * lvl("breath"))

func breath_mult() -> float:
	return 1.0 + 0.15 * lvl("breath")

func melee_mult() -> float:
	return 1.0 + 0.12 * lvl("claws")

func whip_bonus() -> float:
	return 3.0 * lvl("claws")

func walk_mult() -> float:
	return 1.0 + 0.08 * lvl("speed")

func lane_switch_time() -> float:
	return 0.3 / (1.0 + 0.1 * lvl("speed"))

func tell_bonus() -> float:
	return 0.04 * lvl("speed")

func pulse_cooldown() -> float:
	return 10.0 - 1.2 * lvl("blast")

func pulse_damage() -> float:
	return 30.0 + 8.0 * lvl("blast")

func mercy_active(level: int) -> bool:
	return mercy_deaths.get(level, 0) >= 5

func add_death(level: int) -> void:
	mercy_deaths[level] = mercy_deaths.get(level, 0) + 1

func can_buy(id: String) -> bool:
	return ep > 0 and lvl(id) < MAX_UPGRADE

func buy_upgrade(id: String) -> bool:
	if not can_buy(id):
		return false
	ep -= 1
	upgrades[id] = lvl(id) + 1
	save_game()
	return true

func complete_level(level: int, score: int) -> void:
	last_score = score
	high_score = max(high_score, score)
	if not completed.get(level, false):
		completed[level] = true
		last_ep_gain = LEVEL_EP.get(level, 1)
	else:
		last_ep_gain = 1
	ep += last_ep_gain
	unlocked_level = max(unlocked_level, min(level + 1, MAX_LEVEL))
	save_game()

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save", "version", 2)
	cfg.set_value("save", "unlocked_level", unlocked_level)
	cfg.set_value("save", "ep", ep)
	cfg.set_value("save", "upgrades", upgrades)
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
	var raw = cfg.get_value("save", "upgrades", {})
	if raw is Array:  # v1 save: list of owned tier-1 ids
		for id in raw:
			if OLD_IDS.has(id):
				upgrades[OLD_IDS[id]] = 1
	elif raw is Dictionary:
		for id in raw:
			upgrades[id] = clampi(int(raw[id]), 0, MAX_UPGRADE)
	completed.clear()
	for lv in cfg.get_value("save", "completed", []):
		completed[int(lv)] = true
	high_score = cfg.get_value("save", "high_score", 0)

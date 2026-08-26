# Global game state, profiles and save system (autoload "G").
extends Node

const SAVE_PATH := "user://tinytankwars.save"
const SAVE_PASS := "ttw-kids-2026"

var settings := {
	"sfx": 1.0,
	"music": 0.8,
	"ui": 0.8,
	"muted": false,
	"haptics": true,
	"shake": true,
	"wind_off": false,
	"timer_on": false,   # default OFF - relaxed for young kids
}

var unlocked_level := 1
# One profile per human seat (P1..P4): upgrade points and owned upgrades.
var seats := []

# Current match configuration.
var match_humans := 1
var match_level := 1

const UPGRADES := {
	"boom":   {"name": "Bigger Boom",  "desc": "+15% explosion size", "max": 5, "cost": 2, "unlock": 1},
	"shells": {"name": "Heavy Shells", "desc": "+20% damage",         "max": 5, "cost": 2, "unlock": 1},
	"multi":  {"name": "Multi-Shot",   "desc": "+1 ball per shot",    "max": 3, "cost": 4, "unlock": 1},
	"cover":  {"name": "Iron Cover",   "desc": "Blocks 1 direct hit", "max": 1, "cost": 6, "unlock": 20},
}

func _ready() -> void:
	randomize()
	_default_seats()
	load_game()

func _default_seats() -> void:
	seats = []
	for i in range(4):
		seats.append({"points": 0, "boom": 0, "shells": 0, "multi": 0, "cover": 0})

func seat(i: int) -> Dictionary:
	return seats[clampi(i, 0, 3)]

func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "unlocked", unlocked_level)
	cf.set_value("game", "seats", seats)
	cf.set_value("game", "settings", settings)
	cf.save_encrypted_pass(SAVE_PATH, SAVE_PASS)

func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load_encrypted_pass(SAVE_PATH, SAVE_PASS) != OK:
		return
	unlocked_level = cf.get_value("game", "unlocked", 1)
	var s: Array = cf.get_value("game", "seats", [])
	if s.size() == 4:
		seats = s
	var st: Dictionary = cf.get_value("game", "settings", {})
	for k in st.keys():
		settings[k] = st[k]

func reset_progress() -> void:
	unlocked_level = 1
	_default_seats()
	save_game()

# --- Balance helpers -------------------------------------------------

func blast_radius(seat_idx: int, is_human: bool) -> float:
	var lv := 0
	if is_human:
		lv = int(seat(seat_idx)["boom"])
	return 40.0 * (1.0 + 0.15 * lv)

func base_damage(seat_idx: int, is_human: bool) -> float:
	var lv := 0
	if is_human:
		lv = int(seat(seat_idx)["shells"])
	return 25.0 * (1.0 + 0.20 * lv)

func shot_count(seat_idx: int, is_human: bool) -> int:
	if is_human:
		return 1 + int(seat(seat_idx)["multi"])
	return 1

func has_cover(seat_idx: int, is_human: bool) -> bool:
	return is_human and int(seat(seat_idx)["cover"]) > 0

# Wind rules per GDD section 6.
func roll_wind(level: int) -> float:
	if level <= 10 or settings["wind_off"]:
		return 0.0
	return float(randi_range(-30, 30))

func wind_changes_mid_level(level: int) -> bool:
	return level >= 21

# AI tier per level (includes the suggested "Semi-Rookie" bridge tier at 8-10).
func ai_tier(level: int, ai_index: int) -> int:
	if level <= 7:
		return 0        # Rookie
	if level <= 10:
		return 1        # Semi-Rookie
	if level <= 15:
		return 2        # Cadet
	if level <= 20:
		return 2 if ai_index % 2 == 0 else 3  # Cadet -> Veteran mix
	return 3            # Veteran
